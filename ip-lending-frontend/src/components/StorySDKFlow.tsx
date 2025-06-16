'use client';

import { useState, useEffect } from 'react';
import { useAccount, useWriteContract, useWaitForTransactionReceipt, useWalletClient, useReadContract } from 'wagmi';
import { parseUnits } from 'viem';
import { createStoryClient } from '@/lib/storyClient';
import { CONTRACTS, STORY_CONTRACTS } from '@/lib/contracts';

export function StorySDKFlow() {
  const { address, isConnected } = useAccount();
  const { data: walletClient, isLoading: isWalletLoading } = useWalletClient();
  const [currentStep, setCurrentStep] = useState<'mint' | 'verify' | 'loan' | 'repay'>('mint');
  const [isLoading, setIsLoading] = useState(false);
  const [verificationCompleted, setVerificationCompleted] = useState(false);
  const [debugInfo, setDebugInfo] = useState<any>({});
  
  // State for tracking progress
  const [ipAssetData, setIpAssetData] = useState<{
    ipId: string;
    tokenId: string;
    txHash: string;
    tokenContract: string;
  } | null>(null);
  
  const [loanId, setLoanId] = useState<string>('');
  
  const { writeContract, data: hash, error, isPending, reset } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });

  // Check if IP asset is registered using the registry
  const { data: isIPRegistered, refetch: refetchRegistration } = useReadContract({
    address: STORY_CONTRACTS.IP_ASSET_REGISTRY as `0x${string}`,
    abi: [{
      "type": "function",
      "name": "isRegistered",
      "inputs": [{"name": "id", "type": "address"}],
      "outputs": [{"name": "", "type": "bool"}],
      "stateMutability": "view"
    }],
    functionName: 'isRegistered',
    args: ipAssetData ? [ipAssetData.ipId as `0x${string}`] : undefined,
  });

  // Get the calculated IP ID for verification
  const { data: calculatedIPId } = useReadContract({
    address: STORY_CONTRACTS.IP_ASSET_REGISTRY as `0x${string}`,
    abi: [{
      "type": "function",
      "name": "ipId",
      "inputs": [
        {"name": "chainId", "type": "uint256"},
        {"name": "tokenContract", "type": "address"},
        {"name": "tokenId", "type": "uint256"}
      ],
      "outputs": [{"name": "", "type": "address"}],
      "stateMutability": "view"
    }],
    functionName: 'ipId',
    args: ipAssetData ? [
      BigInt(1315), // Story testnet chain ID
      ipAssetData.tokenContract as `0x${string}`,
      BigInt(ipAssetData.tokenId)
    ] : undefined,
  });

  // Reset error when changing steps
  useEffect(() => {
    reset();
  }, [currentStep, reset]);

  // Update debug info when IP asset data changes
  useEffect(() => {
    if (ipAssetData) {
      setDebugInfo({
        ipAssetData,
        isIPRegistered,
        calculatedIPId,
        registrationMatch: calculatedIPId === ipAssetData.ipId
      });
    }
  }, [ipAssetData, isIPRegistered, calculatedIPId]);

  // Step 1: Mint NFT and Register IP using Story SDK
  const handleMintAndRegisterIP = async () => {
    if (!isConnected || !address || !walletClient) {
      alert('Please connect your wallet and wait for it to load');
      return;
    }

    setIsLoading(true);
    try {
      const client = createStoryClient(walletClient);
      
      console.log('Creating IP asset with Story SDK...');
      
      // Use Story's public collection for simplicity
      const response = await client.ipAsset.mintAndRegisterIp({
        spgNftContract: "0xc32A8a0FF3beDDDa58393d022aF433e78739FAbc", // Story's public collection
        ipMetadata: {
          ipMetadataURI: "https://ipfs.io/ipfs/QmZHfQdFA2cb3ASdmeGS5K6rZjz65osUddYMURDx21bT73",
          ipMetadataHash: "0x0000000000000000000000000000000000000000000000000000000000000000",
          nftMetadataURI: "https://ipfs.io/ipfs/QmRL5PcK66J1mbtTZSw1nwVqrGxt98onStx6LgeHTDbEey",
          nftMetadataHash: "0x0000000000000000000000000000000000000000000000000000000000000000",
        },
      });

      console.log('IP Asset created:', response);
      
      setIpAssetData({
        ipId: response.ipId!,
        tokenId: response.tokenId!.toString(),
        txHash: response.txHash!,
        tokenContract: "0xc32A8a0FF3beDDDa58393d022aF433e78739FAbc" // Store the contract address
      });
      
      // Wait a moment for registration to be confirmed
      setTimeout(() => {
        refetchRegistration();
        setCurrentStep('verify');
      }, 2000);
      
    } catch (error) {
      console.error('Error minting IP:', error);
      alert(`Error creating IP asset: ${error instanceof Error ? error.message : 'Unknown error'}`);
    } finally {
      setIsLoading(false);
    }
  };

  // Manual IP registration check
  const handleCheckRegistration = async () => {
    if (!ipAssetData) return;
    
    setIsLoading(true);
    try {
      await refetchRegistration();
      console.log('Registration check completed');
    } catch (error) {
      console.error('Error checking registration:', error);
    } finally {
      setIsLoading(false);
    }
  };

  // Step 2: Mock Yakoa Verification
  const handleYakoaVerification = async () => {
    if (!ipAssetData || !address) return;

    // Check if IP is registered before proceeding
    if (!isIPRegistered) {
      alert('IP asset is not registered yet. Please wait and check registration status.');
      return;
    }

    setIsLoading(true);
    reset(); // Clear any previous errors
    
    try {
      const yakoaTokenId = `demo:${ipAssetData.tokenId}:${Date.now()}`;
      const assessedValue = parseUnits('100000', 6); // $100k USDC

      console.log('Initiating Yakoa verification:', {
        ipAsset: ipAssetData.ipId,
        yakoaTokenId,
        assessedValue: assessedValue.toString(),
        isRegistered: isIPRegistered
      });

      // Ensure contract address is set
      if (!CONTRACTS.IP_LENDING.address || CONTRACTS.IP_LENDING.address === "0xYourDeployedContractAddress") {
        throw new Error('Lending contract address not configured. Please set NEXT_PUBLIC_LENDING_CONTRACT environment variable.');
      }

      // Initiate Yakoa verification
      await writeContract({
        address: CONTRACTS.IP_LENDING.address as `0x${string}`,
        abi: CONTRACTS.IP_LENDING.abi,
        functionName: 'initiateYakoaVerification',
        args: [
          ipAssetData.ipId as `0x${string}`,
          yakoaTokenId,
          assessedValue
        ],
      });
      
    } catch (error) {
      console.error('Error initiating verification:', error);
      setIsLoading(false);
      
      if (error instanceof Error) {
        if (error.message.includes('contract address not configured')) {
          alert('Contract not configured. Please deploy your lending contract and set the address.');
        } else {
          alert(`Error initiating verification: ${error.message}`);
        }
      } else {
        alert('Unknown error occurred during verification');
      }
    }
  };

  // Complete Yakoa verification after initiation
  const handleCompleteVerification = async () => {
    if (!ipAssetData || verificationCompleted) return;

    try {
      const yakoaTokenId = `demo:${ipAssetData.tokenId}:${Date.now()}`;
      
      console.log('Completing Yakoa verification:', {
        yakoaTokenId,
        isVerified: true,
        riskScore: 20
      });

      await writeContract({
        address: CONTRACTS.IP_LENDING.address as `0x${string}`,
        abi: CONTRACTS.IP_LENDING.abi,
        functionName: 'updateYakoaVerification',
        args: [
          yakoaTokenId,
          true, // isVerified
          BigInt(20) // low risk score
        ],
      });
      
      setVerificationCompleted(true);
    } catch (error) {
      console.error('Error completing verification:', error);
      alert(`Error completing verification: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  };

  // Step 3: Create Loan
  const handleCreateLoan = async () => {
    if (!ipAssetData) return;

    setIsLoading(true);
    reset();
    
    try {
      const loanAmount = parseUnits('50000', 6); // 50k USDC
      const duration = 365 * 24 * 60 * 60; // 1 year in seconds

      console.log('Creating loan:', {
        ipAsset: ipAssetData.ipId,
        loanAmount: loanAmount.toString(),
        duration,
        loanToken: CONTRACTS.USDC.address,
        borrowerChainId: 1315
      });

      await writeContract({
        address: CONTRACTS.IP_LENDING.address as `0x${string}`,
        abi: CONTRACTS.IP_LENDING.abi,
        functionName: 'createLoan',
        args: [
          ipAssetData.ipId as `0x${string}`,
          loanAmount,
          BigInt(duration),
          CONTRACTS.USDC.address as `0x${string}`,
          BigInt(1315) // Story testnet chain ID
        ],
      });
      
    } catch (error) {
      console.error('Error creating loan:', error);
      setIsLoading(false);
      alert(`Error creating loan: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  };

  // Handle successful transactions
  useEffect(() => {
    if (isSuccess && currentStep === 'verify' && !verificationCompleted) {
      setIsLoading(false);
      // Auto-complete verification after successful initiation
      setTimeout(() => {
        handleCompleteVerification();
      }, 2000);
    } else if (isSuccess && currentStep === 'verify' && verificationCompleted) {
      setCurrentStep('loan');
      setIsLoading(false);
    } else if (isSuccess && currentStep === 'loan') {
      // Mock getting loan ID (in real app, parse from transaction logs)
      setLoanId('0');
      setCurrentStep('repay');
      setIsLoading(false);
    }
  }, [isSuccess, currentStep, verificationCompleted]);

  if (!isConnected) {
    return (
      <div className="max-w-md mx-auto p-6 bg-white rounded-lg shadow-md">
        <h2 className="text-2xl font-bold mb-4 text-gray-900">Connect Wallet</h2>
        <p className="text-gray-600">Please connect your wallet to start the IP lending flow.</p>
      </div>
    );
  }

  if (isWalletLoading) {
    return (
      <div className="max-w-md mx-auto p-6 bg-white rounded-lg shadow-md">
        <h2 className="text-2xl font-bold mb-4 text-gray-900">Loading Wallet...</h2>
        <p className="text-gray-600">Please wait while we connect to your wallet.</p>
      </div>
    );
  }

  if (!walletClient) {
    return (
      <div className="max-w-md mx-auto p-6 bg-white rounded-lg shadow-md">
        <h2 className="text-2xl font-bold mb-4 text-gray-900">Wallet Error</h2>
        <p className="text-gray-600">Unable to connect to wallet. Please refresh and try again.</p>
      </div>
    );
  }

  return (
    <div className="max-w-4xl mx-auto p-6">
      <h2 className="text-3xl font-bold mb-6 text-gray-900">IP Collateral Lending Flow</h2>
      <p className="text-gray-600 mb-8">Complete end-to-end flow: Story SDK → Yakoa (Mock) → Lending → deBridge</p>
      
      {/* Contract Status */}
      <div className="mb-6 p-4 bg-yellow-50 rounded-lg border border-yellow-200">
        <p className="text-sm text-yellow-800">
          <strong>Contract Status:</strong> {
            CONTRACTS.IP_LENDING.address === "0xYourDeployedContractAddress" 
              ? '⚠️ Not configured - Please deploy your contract and set NEXT_PUBLIC_LENDING_CONTRACT'
              : `✓ Configured: ${CONTRACTS.IP_LENDING.address}`
          }
        </p>
      </div>

      {/* Debug Information */}
      {ipAssetData && (
        <div className="mb-6 p-4 bg-blue-50 rounded-lg border border-blue-200">
          <h3 className="font-semibold text-blue-900 mb-2">Debug Information</h3>
          <div className="text-sm text-blue-800 space-y-1">
            <div><strong>IP Asset ID:</strong> {ipAssetData.ipId}</div>
            <div><strong>Token Contract:</strong> {ipAssetData.tokenContract}</div>
            <div><strong>Token ID:</strong> {ipAssetData.tokenId}</div>
            <div><strong>Calculated IP ID:</strong> {calculatedIPId || 'Loading...'}</div>
            <div><strong>Is Registered:</strong> {
              isIPRegistered === undefined ? 'Checking...' : 
              isIPRegistered ? '✅ Yes' : '❌ No'
            }</div>
            <div><strong>ID Match:</strong> {
              calculatedIPId === ipAssetData.ipId ? '✅ Match' : '❌ Mismatch'
            }</div>
          </div>
          <button
            onClick={handleCheckRegistration}
            disabled={isLoading}
            className="mt-2 px-3 py-1 bg-blue-100 text-blue-800 rounded text-sm hover:bg-blue-200"
          >
            {isLoading ? 'Checking...' : 'Refresh Registration Status'}
          </button>
        </div>
      )}
      
      {/* Progress Steps */}
      <div className="flex items-center mb-8 space-x-4">
        {[
          { id: 'mint', label: 'Create IP Asset', done: !!ipAssetData },
          { id: 'verify', label: 'Verify IP (Mock)', done: verificationCompleted },
          { id: 'loan', label: 'Create Loan', done: currentStep === 'repay' },
          { id: 'repay', label: 'Cross-Chain Repay', done: false }
        ].map((step, index) => (
          <div key={step.id} className="flex items-center">
            <div className={`w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium ${
              step.done ? 'bg-green-500 text-white' :
              currentStep === step.id ? 'bg-blue-500 text-white' :
              'bg-gray-300 text-gray-600'
            }`}>
              {step.done ? '✓' : index + 1}
            </div>
            <span className={`ml-2 ${step.done || currentStep === step.id ? 'text-gray-900' : 'text-gray-500'}`}>
              {step.label}
            </span>
            {index < 3 && <div className="ml-4 w-8 h-1 bg-gray-200"></div>}
          </div>
        ))}
      </div>

      <div className="bg-white p-6 rounded-lg shadow-md">
        
        {/* Step 1: Create IP Asset */}
        {currentStep === 'mint' && (
          <div>
            <h3 className="text-xl font-semibold mb-4">Step 1: Create IP Asset with Story SDK</h3>
            <p className="text-gray-600 mb-4">
              This will mint an NFT and register it as an IP asset on Story Protocol in one transaction.
            </p>
            <div className="bg-blue-50 p-4 rounded-lg mb-4">
              <p className="text-sm text-blue-700">
                <strong>Using:</strong> Story SDK's mintAndRegisterIp function
                <br />
                <strong>Collection:</strong> Story's public SPG collection (0xc32A8a0FF3beDDDa58393d022aF433e78739FAbc)
                <br />
                <strong>Wallet:</strong> Connected ✓
                <br />
                <strong>Result:</strong> You'll get an IP Asset ID ready for collateral use
              </p>
            </div>
            <button
              onClick={handleMintAndRegisterIP}
              disabled={isLoading || !walletClient}
              className="bg-blue-600 text-white py-3 px-6 rounded-md hover:bg-blue-700 disabled:opacity-50"
            >
              {isLoading ? 'Creating IP Asset...' : 'Create IP Asset with Story SDK'}
            </button>
          </div>
        )}

        {/* Step 2: Yakoa Verification */}
        {currentStep === 'verify' && ipAssetData && (
          <div>
            <h3 className="text-xl font-semibold mb-4">Step 2: Yakoa Verification (Mock)</h3>
            <div className="bg-green-50 p-4 rounded-lg mb-4">
              <p className="text-sm text-green-700">
                <strong>✓ IP Asset Created!</strong>
                <br />
                <strong>IP Asset ID:</strong> {ipAssetData.ipId}
                <br />
                <strong>Token ID:</strong> {ipAssetData.tokenId}
                <br />
                <strong>Transaction:</strong> {ipAssetData.txHash}
              </p>
            </div>

            {/* Registration Status */}
            <div className={`p-4 rounded-lg mb-4 ${
              isIPRegistered ? 'bg-green-50 border border-green-200' : 'bg-red-50 border border-red-200'
            }`}>
              <p className={`text-sm ${isIPRegistered ? 'text-green-700' : 'text-red-700'}`}>
                <strong>Registration Status:</strong> {
                  isIPRegistered === undefined ? '🔄 Checking...' :
                  isIPRegistered ? '✅ Registered and Ready' :
                  '❌ Not registered - Please wait or check again'
                }
              </p>
            </div>
            
            <p className="text-gray-600 mb-4">
              Mock Yakoa verification to assess IP value and risk score.
            </p>
            
            {!verificationCompleted && (
              <button
                onClick={handleYakoaVerification}
                disabled={
                  isLoading || 
                  isPending || 
                  isConfirming || 
                  !isIPRegistered ||
                  CONTRACTS.IP_LENDING.address === "0xYourDeployedContractAddress"
                }
                className="bg-orange-600 text-white py-3 px-6 rounded-md hover:bg-orange-700 disabled:opacity-50"
              >
                {isLoading || isPending || isConfirming ? 'Verifying...' : 
                 !isIPRegistered ? 'Waiting for Registration...' :
                 'Start Yakoa Verification (Mock)'}
              </button>
            )}
            
            {(isSuccess || verificationCompleted) && (
              <div className="mt-4 p-4 bg-green-50 rounded-lg">
                <p className="text-green-800 font-medium">✓ Verification completed successfully!</p>
                <p className="text-sm text-green-600 mt-1">IP asset is now eligible for loan creation.</p>
              </div>
            )}
          </div>
        )}

        {/* Step 3: Create Loan */}
        {currentStep === 'loan' && ipAssetData && verificationCompleted && (
          <div>
            <h3 className="text-xl font-semibold mb-4">Step 3: Create Loan</h3>
            <div className="bg-green-50 p-4 rounded-lg mb-4">
              <p className="text-sm text-green-700">
                <strong>✓ IP Verified!</strong>
                <br />
                <strong>IP Asset ID:</strong> {ipAssetData.ipId}
                <br />
                <strong>Assessed Value:</strong> $100,000 USDC
                <br />
                <strong>Risk Score:</strong> 20 (Low Risk)
                <br />
                <strong>Status:</strong> Eligible for Collateral
              </p>
            </div>
            <div className="bg-blue-50 p-4 rounded-lg mb-4">
              <p className="text-sm text-blue-700">
                <strong>Loan Terms:</strong>
                <br />
                Amount: $50,000 USDC (50% LTV)
                <br />
                Duration: 1 Year
                <br />
                Collateral: {ipAssetData.ipId}
              </p>
            </div>
            <button
              onClick={handleCreateLoan}
              disabled={isLoading || isPending || isConfirming}
              className="bg-green-600 text-white py-3 px-6 rounded-md hover:bg-green-700 disabled:opacity-50"
            >
              {isLoading || isPending || isConfirming ? 'Creating Loan...' : 'Create Loan'}
            </button>
          </div>
        )}

        {/* Step 4: Cross-Chain Repayment */}
        {currentStep === 'repay' && loanId && ipAssetData && (
          <div>
            <h3 className="text-xl font-semibold mb-4">Step 4: Cross-Chain Repayment</h3>
            <div className="bg-green-50 p-4 rounded-lg mb-4">
              <p className="text-sm text-green-700">
                <strong>✓ Loan Created!</strong>
                <br />
                <strong>Loan ID:</strong> {loanId}
                <br />
                <strong>Amount:</strong> $50,000 USDC
                <br />
                <strong>IP Collateral:</strong> {ipAssetData.ipId}
                <br />
                <strong>Status:</strong> Active
              </p>
            </div>
            <div className="bg-purple-50 p-4 rounded-lg mb-4">
              <p className="text-sm text-purple-700">
                <strong>✓ Complete Flow Successful!</strong>
                <br />
                You have successfully:
                <br />
                1. ✓ Created IP Asset with Story SDK
                <br />
                2. ✓ Completed Yakoa Verification (Mock)
                <br />
                3. ✓ Created Loan with IP as Collateral
                <br />
                4. → Ready for Cross-Chain Repayment Testing
              </p>
            </div>
          </div>
        )}

        {/* Error Display */}
        {error && (
          <div className="mt-4 p-4 bg-red-50 text-red-700 rounded-md">
            <div className="font-semibold">Error:</div>
            <div className="text-sm whitespace-pre-wrap">{error.message}</div>
            <button
              onClick={() => reset()}
              className="mt-2 px-3 py-1 bg-red-100 text-red-800 rounded text-sm hover:bg-red-200"
            >
              Clear Error
            </button>
          </div>
        )}

        {/* Success Messages */}
        {isSuccess && !error && (
          <div className="mt-4 p-4 bg-green-50 text-green-700 rounded-md">
            <div className="font-semibold">✓ Transaction Successful!</div>
            <div className="text-sm">
              {currentStep === 'verify' && !verificationCompleted ? 'Verification initiated, completing...' : 'Moving to next step...'}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
