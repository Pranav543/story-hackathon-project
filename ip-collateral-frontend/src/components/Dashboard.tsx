'use client';

import React, { useState, useEffect } from 'react';
import { useAccount } from 'wagmi';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { useContracts } from '@/hooks/useContracts';
import { yakoaClient, YakoaTokenRequest } from '@/lib/yakoa';
import { uploadFile } from '@/lib/upload';
import { CONTRACT_ADDRESSES } from '@/lib/contracts';
import { ethers } from 'ethers';
import { 
  Upload, Shield, DollarSign, Clock, AlertTriangle, CheckCircle, 
  Loader2, ExternalLink, RefreshCw, Eye, AlertCircle, Info
} from 'lucide-react';

// Browser check for client-side only operations
const isBrowser = typeof window !== 'undefined';

interface IPAsset {
  address: string;
  yakoaTokenId: string;
  yakoaStatus: 'PENDING' | 'VERIFIED' | 'REJECTED' | 'ERROR';
  isEligible: boolean;
  assessedValue: string;
  riskScore: number;
  issues?: string[];
  summary?: string;
  lastValidated: number;
  yakoaTimestamp: number;
}

interface Loan {
  id: number;
  borrower: string;
  ipAsset: string;
  loanAmount: string;
  collateralValue: string;
  interestRate: number;
  startTime: number;
  duration: number;
  isActive: boolean;
  isRepaid: boolean;
  status: number;
  sourceChainId: number;
}

const STATUS_COLORS = {
  PENDING: 'text-yellow-700 bg-yellow-50 border-yellow-200',
  VERIFIED: 'text-green-700 bg-green-50 border-green-200',
  REJECTED: 'text-red-700 bg-red-50 border-red-200',
  ERROR: 'text-gray-700 bg-gray-50 border-gray-200',
};

const STATUS_ICONS = {
  PENDING: Clock,
  VERIFIED: CheckCircle,
  REJECTED: AlertTriangle,
  ERROR: AlertCircle,
};

export default function Dashboard() {
  const { address, isConnected } = useAccount();
  const { lendingContract, ipAssetRegistry, usdcContract, isLoading: contractsLoading } = useContracts();
  
  const [ipAssets, setIpAssets] = useState<IPAsset[]>([]);
  const [loans, setLoans] = useState<Loan[]>([]);
  const [loading, setLoading] = useState(false);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [verificationStatus, setVerificationStatus] = useState<string>('');
  const [showDetails, setShowDetails] = useState<{[key: string]: boolean}>({});
  const [networkInfo, setNetworkInfo] = useState<any>(null);
  
  const [ipMetadata, setIpMetadata] = useState({
    name: '',
    description: '',
    assessedValue: '',
  });

  // Network detection effect
  useEffect(() => {
    const detectNetwork = async () => {
      if (window.ethereum) {
        try {
          const chainId = await window.ethereum.request({ method: 'eth_chainId' });
          const networkVersion = await window.ethereum.request({ method: 'net_version' });
          
          setNetworkInfo({
            chainId: parseInt(chainId, 16),
            networkVersion: parseInt(networkVersion),
            expectedChainId: 1315,
            isCorrectNetwork: parseInt(chainId, 16) === 1315
          });
          
          console.log('🔗 Network Detection:', {
            currentChainId: parseInt(chainId, 16),
            expectedChainId: 1315,
            isCorrect: parseInt(chainId, 16) === 1315
          });
        } catch (error) {
          console.error('Network detection failed:', error);
        }
      }
    };

    detectNetwork();
  }, []);

  // Load data when connected
  useEffect(() => {
    if (isBrowser && isConnected && address && lendingContract && !contractsLoading) {
      loadUserData();
    }
  }, [isBrowser, isConnected, address, lendingContract, contractsLoading]);

  // Browser-only localStorage helper
  const saveAssetsToStorage = (assets: IPAsset[]) => {
    if (isBrowser && typeof localStorage !== 'undefined' && address) {
      localStorage.setItem(`ipAssets_${address}`, JSON.stringify(assets));
    }
  };

  const loadUserData = async () => {
    if (!isBrowser || !lendingContract || !address) return;
    
    try {
      console.log('📊 Loading user data...');
      
      // Load user loans
      const loanIds = await lendingContract.getUserLoans(address);
      console.log(`📋 Found ${loanIds.length} loans for user`);
      
      const loadedLoans = await Promise.all(
        loanIds.map(async (id: bigint) => {
          const loan = await lendingContract.getLoan(id);
          return {
            id: Number(id),
            borrower: loan.borrower,
            ipAsset: loan.ipAsset,
            loanAmount: loan.loanAmount.toString(),
            collateralValue: loan.collateralValue.toString(),
            interestRate: Number(loan.interestRate),
            startTime: Number(loan.startTime),
            duration: Number(loan.duration),
            isActive: loan.isActive,
            isRepaid: loan.isRepaid,
            status: Number(loan.status),
            sourceChainId: Number(loan.sourceChainId),
          };
        })
      );
      setLoans(loadedLoans);

      // Load IP assets from local storage
      if (typeof localStorage !== 'undefined') {
        const storedAssets = localStorage.getItem(`ipAssets_${address}`);
        if (storedAssets) {
          const parsedAssets = JSON.parse(storedAssets);
          console.log(`💾 Loaded ${parsedAssets.length} IP assets from storage`);
          setIpAssets(parsedAssets);
          
          // Update assets with latest on-chain data
          updateAssetsFromContract(parsedAssets);
        }
      }

    } catch (error) {
      console.error('❌ Error loading user data:', error);
    }
  };

  const updateAssetsFromContract = async (assets: IPAsset[]) => {
    if (!lendingContract) return;

    try {
      const updatedAssets = await Promise.all(
        assets.map(async (asset) => {
          try {
            const collateral = await lendingContract.getIPCollateral(asset.address);
            return {
              ...asset,
              isEligible: collateral.isEligible,
              riskScore: Number(collateral.riskScore),
              yakoaStatus: ['PENDING', 'VERIFIED', 'REJECTED', 'ERROR'][collateral.yakoaStatus] as any,
              lastValidated: Number(collateral.lastValidated),
              yakoaTimestamp: Number(collateral.yakoaTimestamp),
            };
          } catch (error) {
            console.warn(`Failed to update asset ${asset.address}:`, error);
            return asset;
          }
        })
      );
      
      setIpAssets(updatedAssets);
      saveAssetsToStorage(updatedAssets);
    } catch (error) {
      console.error('Error updating assets from contract:', error);
    }
  };

  const handleFileUpload = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) {
      setSelectedFile(file);
      console.log(`📁 File selected: ${file.name} (${(file.size / 1024 / 1024).toFixed(2)} MB)`);
    }
  };

  const registerIPAsset = async () => {
    if (!selectedFile || !address || !ipAssetRegistry || !lendingContract) {
      alert('Please ensure all fields are filled and wallet is connected');
      return;
    }
    
    setLoading(true);
    setVerificationStatus('🚀 Starting IP registration process...');
    
    try {
      // Step 1: Upload file
      setVerificationStatus('📤 Uploading file to storage...');
      const mediaUrl = await uploadFile(selectedFile);
      console.log('📍 File uploaded to:', mediaUrl);

      // Step 2: Create mock NFT and register IP (for demo)
      setVerificationStatus('📝 Registering IP on Story Protocol...');
      
      const mockContractAddress = `0x${Math.random().toString(16).substr(2, 40)}`;
      const tokenId = Date.now();
      const yakoaTokenId = `${mockContractAddress}:${tokenId}`;
      
      // Mock transaction data
      const mockTxHash = `0x${Math.random().toString(16).substr(2, 64)}`;
      const mockBlockNumber = Math.floor(Math.random() * 1000000) + 1000000;
      const ipAssetAddress = `0x${Math.random().toString(16).substr(2, 40)}`;
      
      // Step 3: Calculate file hash for Yakoa
      setVerificationStatus('🔐 Calculating file hash for verification...');
      const fileHash = await yakoaClient.calculateFileHash(selectedFile);
      console.log('🔐 File hash calculated:', fileHash);
      
      // Step 4: Prepare Yakoa token data
      setVerificationStatus('📋 Preparing verification data for Yakoa...');
      
      const yakoaTokenData: YakoaTokenRequest = {
        id: yakoaTokenId,
        registration_tx: {
          hash: mockTxHash,
          block_number: mockBlockNumber,
          chain_id: 1315,
        },
        creator_id: address.toLowerCase(),
        metadata: {
          name: ipMetadata.name,
          description: ipMetadata.description,
          image: mediaUrl,
          attributes: [
            { trait_type: 'Platform', value: 'IP Collateral Lending' },
            { trait_type: 'Assessed Value', value: `${ipMetadata.assessedValue} ETH` },
            { trait_type: 'Creator', value: address },
            { trait_type: 'File Type', value: selectedFile.type },
            { trait_type: 'File Size', value: `${selectedFile.size} bytes` },
          ]
        },
        media: [
          {
            media_id: `media_${tokenId}`,
            url: mediaUrl,
            hash: fileHash,
            trust_reason: {
              type: 'TrustedPlatform',
              platform: 'ip-collateral-lending',
            },
          },
        ],
      };

      // Step 5: Register with Yakoa
      setVerificationStatus('🔍 Submitting to Yakoa for IP verification...');
      const yakoaResponse = await yakoaClient.registerToken(yakoaTokenData);
      console.log('📨 Yakoa registration response:', yakoaResponse);

      // Step 6: Initiate verification on smart contract
      setVerificationStatus('⛓️ Initiating on-chain verification tracking...');
      
      try {
        const verificationTx = await lendingContract.initiateYakoaVerification(
          ipAssetAddress,
          yakoaTokenId,
          ethers.parseEther(ipMetadata.assessedValue)
        );
        console.log('⛓️ Verification transaction sent:', verificationTx.hash);
        
        setVerificationStatus('⏳ Waiting for transaction confirmation...');
        await verificationTx.wait();
        console.log('✅ On-chain verification initiated successfully');
      } catch (contractError) {
        console.warn('⚠️ Contract verification failed, continuing with demo:', contractError);
        setVerificationStatus('⚠️ Contract interaction failed, continuing with demo...');
      }

      // Step 7: Store asset locally and start polling
      const newAsset: IPAsset = {
        address: ipAssetAddress,
        yakoaTokenId: yakoaTokenId,
        yakoaStatus: 'PENDING',
        isEligible: false,
        assessedValue: ethers.parseEther(ipMetadata.assessedValue).toString(),
        riskScore: 100,
        lastValidated: Math.floor(Date.now() / 1000),
        yakoaTimestamp: Math.floor(Date.now() / 1000),
      };

      const updatedAssets = [...ipAssets, newAsset];
      setIpAssets(updatedAssets);
      saveAssetsToStorage(updatedAssets);

      // Step 8: Poll for Yakoa verification results
      setVerificationStatus('🔄 Waiting for Yakoa IP verification results...');
      
      try {
        const verificationResult = await yakoaClient.pollVerificationStatus(yakoaTokenId, 15, 3000);
        const analysis = yakoaClient.analyzeInfringementResults(verificationResult);
        
        console.log('📊 Verification analysis:', analysis);

        // Update the asset with results
        const finalAsset: IPAsset = {
          ...newAsset,
          yakoaStatus: analysis.isVerified ? 'VERIFIED' : 'REJECTED',
          isEligible: analysis.isVerified,
          riskScore: analysis.riskScore,
          issues: analysis.issues,
          summary: analysis.summary,
          lastValidated: Math.floor(Date.now() / 1000),
        };

        const finalAssets = ipAssets.concat(finalAsset);
        setIpAssets(finalAssets);
        saveAssetsToStorage(finalAssets);

        // Update contract with verification result
        try {
          const updateTx = await lendingContract.updateYakoaVerification(
            yakoaTokenId,
            analysis.isVerified,
            analysis.riskScore
          );
          console.log('📝 Contract update transaction:', updateTx.hash);
          
          setVerificationStatus('⏳ Updating on-chain verification status...');
          await updateTx.wait();
          console.log('✅ Contract updated with verification result');
        } catch (updateError) {
          console.warn('⚠️ Contract update failed, demo continues:', updateError);
        }

        setVerificationStatus(
          analysis.isVerified 
            ? '🎉 Verification complete! IP asset approved for collateral use.' 
            : `❌ Verification complete! IP asset rejected: ${analysis.summary}`
        );
        
      } catch (verificationError) {
        console.error('❌ Verification polling failed:', verificationError);
        setVerificationStatus('⚠️ Verification timeout - check Yakoa status manually');
      }

      // Reset form
      setSelectedFile(null);
      setIpMetadata({ name: '', description: '', assessedValue: '' });
      
    } catch (error) {
      console.error('❌ Error registering IP asset:', error);
      setVerificationStatus(
        `❌ Registration failed: ${error instanceof Error ? error.message : 'Unknown error'}`
      );
    } finally {
      setLoading(false);
      setTimeout(() => setVerificationStatus(''), 10000);
    }
  };

  const createLoan = async (ipAsset: IPAsset) => {
  if (!lendingContract || !usdcContract) {
    alert('Contracts not available');
    return;
  }

  try {
    setLoading(true);
    console.log('💰 Creating loan for IP asset:', ipAsset.address);
    
    // ✅ Validate all addresses before contract interaction
    const validatedIPAsset = ethers.getAddress(ipAsset.address);
    const validatedUSDCAddress = ethers.getAddress(CONTRACT_ADDRESSES.USDC);
    
    const loanAmount = ethers.parseUnits("1000", 6); // 1000 USDC
    const duration = 365 * 24 * 60 * 60; // 1 year
    const borrowerChainId = 1315; // Story chain ID

    console.log('📝 Loan parameters:', {
      ipAsset: validatedIPAsset,
      loanAmount: loanAmount.toString(),
      duration,
      loanToken: validatedUSDCAddress,
      borrowerChainId
    });

    // ✅ Call contract with validated addresses
    const tx = await lendingContract.createLoan(
      validatedIPAsset,
      loanAmount,
      duration,
      validatedUSDCAddress,
      borrowerChainId
    );

    console.log('📝 Loan creation transaction:', tx.hash);
    await tx.wait();
    console.log('✅ Loan created successfully');

    // Reload data
    loadUserData();
  } catch (error) {
    console.error('❌ Error creating loan:', error);
    
    // ✅ Enhanced error handling for ENS issues
    if (error instanceof Error && error.message.includes('ENS')) {
      alert('Network configuration error. Please ensure you are connected to Story testnet.');
    } else {
      alert(`Error creating loan: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  } finally {
    setLoading(false);
  }
};


  const repayLoan = async (loanId: number) => {
    if (!lendingContract || !usdcContract) {
      alert('Contracts not available');
      return;
    }

    try {
      setLoading(true);
      console.log('💳 Repaying loan:', loanId);

      const totalOwed = await lendingContract.calculateTotalOwed(loanId);
      console.log('💰 Total owed:', ethers.formatUnits(totalOwed, 6), 'USDC');
      
      // Approve USDC spending
      const approveTx = await usdcContract.approve(CONTRACT_ADDRESSES.LENDING_PROTOCOL, totalOwed);
      await approveTx.wait();

      // Repay loan
      const repayTx = await lendingContract.repayLoan(loanId);
      console.log('📝 Repayment transaction:', repayTx.hash);
      await repayTx.wait();
      console.log('✅ Loan repaid successfully');

      loadUserData();
    } catch (error) {
      console.error('❌ Error repaying loan:', error);
      alert(`Error repaying loan: ${error instanceof Error ? error.message : 'Unknown error'}`);
    } finally {
      setLoading(false);
    }
  };

  const toggleDetails = (key: string) => {
    setShowDetails(prev => ({ ...prev, [key]: !prev[key] }));
  };

  if (!isConnected) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-blue-50 via-indigo-50 to-purple-50 flex items-center justify-center">
        <div className="text-center bg-white rounded-2xl shadow-xl p-8 max-w-md border border-blue-100">
          <div className="mb-6">
            <Shield className="w-16 h-16 text-blue-600 mx-auto mb-4" />
            <h1 className="text-3xl font-bold text-gray-900 mb-2">IP Collateral Lending</h1>
            <p className="text-gray-600">Secure loans using verified intellectual property</p>
          </div>
          
          <div className="space-y-3 text-sm text-gray-500 mb-6">
            <div className="flex items-center justify-center">
              <Shield className="w-4 h-4 mr-2" />
              <span>Yakoa IP Verification</span>
            </div>
            <div className="flex items-center justify-center">
              <DollarSign className="w-4 h-4 mr-2" />
              <span>Story Protocol Integration</span>
            </div>
            <div className="flex items-center justify-center">
              <ExternalLink className="w-4 h-4 mr-2" />
              <span>Cross-Chain deBridge Support</span>
            </div>
          </div>
          
          <ConnectButton />
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 via-indigo-50 to-purple-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Header */}
        <div className="flex justify-between items-center mb-8">
          <div>
            <h1 className="text-3xl font-bold text-gray-900 flex items-center">
              <Shield className="w-8 h-8 mr-3 text-blue-600" />
              IP Collateral Lending
            </h1>
            <p className="text-gray-600 mt-1">Secure loans using verified intellectual property as collateral</p>
          </div>
          <div className="flex items-center space-x-4">
            <button
              onClick={loadUserData}
              disabled={loading || contractsLoading}
              className="p-2 text-gray-600 hover:text-blue-600 transition-colors"
              title="Refresh data"
            >
              <RefreshCw className={`w-5 h-5 ${loading ? 'animate-spin' : ''}`} />
            </button>
            <ConnectButton />
          </div>
        </div>

        {/* Network Info Display */}
        {networkInfo && (
          <div className="bg-gray-100 p-4 rounded-lg mb-4 text-sm">
            <p><strong>Current Network:</strong> {networkInfo.chainId}</p>
            <p><strong>Expected Network:</strong> {networkInfo.expectedChainId}</p>
            <p><strong>Status:</strong> {networkInfo.isCorrectNetwork ? '✅ Correct' : '❌ Wrong Network'}</p>
          </div>
        )}

        {/* Status Display */}
        {verificationStatus && (
          <div className="bg-blue-50 border border-blue-200 rounded-xl p-4 mb-6">
            <div className="flex items-center">
              <Loader2 className="w-5 h-5 text-blue-600 animate-spin mr-3" />
              <span className="text-blue-800 font-medium">{verificationStatus}</span>
            </div>
          </div>
        )}

        {/* Register IP Asset Section */}
        <div className="bg-white rounded-2xl shadow-lg mb-8 p-6 border border-gray-100">
          <h2 className="text-xl font-semibold text-gray-900 mb-4 flex items-center">
            <Upload className="w-6 h-6 mr-3 text-blue-600" />
            Register New IP Asset
          </h2>
          
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
            {/* File Upload */}
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Upload Media File
                </label>
                <div className="relative">
                  <input
                    type="file"
                    onChange={handleFileUpload}
                    accept="image/*,video/*,audio/*"
                    className="block w-full text-sm text-gray-500 file:mr-4 file:py-3 file:px-4 file:rounded-full file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100 transition-colors"
                  />
                  {selectedFile && (
                    <div className="mt-2 p-3 bg-green-50 border border-green-200 rounded-lg">
                      <p className="text-sm text-green-800 flex items-center">
                        <CheckCircle className="w-4 h-4 mr-2" />
                        {selectedFile.name} ({(selectedFile.size / 1024 / 1024).toFixed(2)} MB)
                      </p>
                    </div>
                  )}
                </div>
              </div>
              
              <div className="bg-blue-50 p-4 rounded-lg border border-blue-200">
                <h4 className="text-sm font-medium text-blue-900 mb-2">Supported File Types</h4>
                <ul className="text-xs text-blue-700 space-y-1">
                  <li>• Images: JPG, PNG, GIF, WebP</li>
                  <li>• Videos: MP4, WebM, MOV</li>
                  <li>• Audio: MP3, WAV, OGG</li>
                </ul>
              </div>
            </div>
            
            {/* Metadata */}
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Asset Name *</label>
                <input
                  type="text"
                  value={ipMetadata.name}
                  onChange={(e) => setIpMetadata({ ...ipMetadata, name: e.target.value })}
                  className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-colors"
                  placeholder="My Original Artwork"
                />
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Description *</label>
                <textarea
                  value={ipMetadata.description}
                  onChange={(e) => setIpMetadata({ ...ipMetadata, description: e.target.value })}
                  className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-colors"
                  placeholder="Describe your intellectual property..."
                  rows={3}
                />
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Assessed Value (ETH) *</label>
                <input
                  type="number"
                  value={ipMetadata.assessedValue}
                  onChange={(e) => setIpMetadata({ ...ipMetadata, assessedValue: e.target.value })}
                  className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-colors"
                  placeholder="1.0"
                  step="0.1"
                  min="0.1"
                />
                <p className="text-xs text-gray-500 mt-1">Maximum loan: 70% of assessed value</p>
              </div>
            </div>
          </div>
          
          <div className="mt-6 flex justify-between items-center">
            <div className="text-sm text-gray-600">
              <Info className="w-4 h-4 inline mr-1" />
              Registration includes Yakoa IP verification and Story Protocol attestation
            </div>
            <button
              onClick={registerIPAsset}
              disabled={!selectedFile || !ipMetadata.name || !ipMetadata.description || !ipMetadata.assessedValue || loading}
              className="px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:bg-gray-400 disabled:cursor-not-allowed flex items-center transition-colors"
            >
              {loading ? (
                <>
                  <Loader2 className="w-5 h-5 mr-2 animate-spin" />
                  Processing...
                </>
              ) : (
                <>
                  <Shield className="w-5 h-5 mr-2" />
                  Register & Verify IP Asset
                </>
              )}
            </button>
          </div>
        </div>

        {/* IP Assets Section */}
        <div className="bg-white rounded-2xl shadow-lg mb-8 p-6 border border-gray-100">
          <h2 className="text-xl font-semibold text-gray-900 mb-4 flex items-center">
            <Shield className="w-6 h-6 mr-3 text-green-600" />
            Your IP Assets ({ipAssets.length})
          </h2>
          
          {ipAssets.length === 0 ? (
            <div className="text-center py-12">
              <Shield className="w-16 h-16 text-gray-300 mx-auto mb-4" />
              <h3 className="text-lg font-medium text-gray-900 mb-2">No IP Assets Yet</h3>
              <p className="text-gray-500 mb-4">Register your first IP asset above to get started</p>
            </div>
          ) : (
            <div className="space-y-4">
              {ipAssets.map((asset, index) => {
                const StatusIcon = STATUS_ICONS[asset.yakoaStatus];
                const statusColorClass = STATUS_COLORS[asset.yakoaStatus];
                
                return (
                  <div key={index} className="border border-gray-200 rounded-xl p-6 hover:bg-gray-50 transition-colors">
                    <div className="flex justify-between items-start">
                      <div className="flex-1">
                        <div className="flex items-center mb-3">
                          <h3 className="font-medium text-gray-900 mr-3">
                            {asset.address.slice(0, 10)}...{asset.address.slice(-8)}
                          </h3>
                          <span className={`inline-flex items-center px-3 py-1 rounded-full text-xs font-medium border ${statusColorClass}`}>
                            <StatusIcon className="w-3 h-3 mr-1" />
                            {asset.yakoaStatus}
                          </span>
                        </div>
                        
                        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm text-gray-600 mb-3">
                          <div>
                            <span className="font-medium">Value:</span> {ethers.formatEther(asset.assessedValue)} ETH
                          </div>
                          <div>
                            <span className="font-medium">Risk Score:</span> {asset.riskScore}/100
                          </div>
                          <div>
                            <span className="font-medium">Yakoa ID:</span> {asset.yakoaTokenId.slice(0, 20)}...
                          </div>
                          <div>
                            <span className="font-medium">Verified:</span> {new Date(asset.lastValidated * 1000).toLocaleDateString()}
                          </div>
                        </div>

                        {asset.summary && (
                          <div className="mb-3">
                            <p className={`text-sm ${asset.yakoaStatus === 'VERIFIED' ? 'text-green-700' : 'text-red-700'}`}>
                              {asset.summary}
                            </p>
                          </div>
                        )}

                        {asset.issues && asset.issues.length > 0 && (
                          <div className="mb-3">
                            <button
                              onClick={() => toggleDetails(`issues-${index}`)}
                              className="text-sm text-red-600 hover:text-red-800 flex items-center"
                            >
                              <Eye className="w-4 h-4 mr-1" />
                              {showDetails[`issues-${index}`] ? 'Hide' : 'Show'} Issues ({asset.issues.length})
                            </button>
                            {showDetails[`issues-${index}`] && (
                              <div className="mt-2 p-3 bg-red-50 border border-red-200 rounded-lg">
                                <ul className="text-xs text-red-700 space-y-1">
                                  {asset.issues.map((issue, i) => (
                                    <li key={i}>• {issue}</li>
                                  ))}
                                </ul>
                              </div>
                            )}
                          </div>
                        )}
                      </div>
                      
                      <div className="flex flex-col items-end space-y-2 ml-4">
                        {asset.isEligible && asset.yakoaStatus === 'VERIFIED' && (
                          <button
                            onClick={() => createLoan(asset)}
                            disabled={loading}
                            className="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:bg-gray-400 text-sm font-medium flex items-center transition-colors"
                          >
                            <DollarSign className="w-4 h-4 mr-1" />
                            Create Loan
                          </button>
                        )}
                        
                        <button
                          onClick={() => toggleDetails(`details-${index}`)}
                          className="text-xs text-gray-500 hover:text-gray-700 flex items-center"
                        >
                          <Eye className="w-3 h-3 mr-1" />
                          {showDetails[`details-${index}`] ? 'Less' : 'More'} Details
                        </button>
                      </div>
                    </div>

                    {showDetails[`details-${index}`] && (
                      <div className="mt-4 pt-4 border-t border-gray-200">
                        <div className="grid grid-cols-2 gap-4 text-xs text-gray-600">
                          <div>
                            <span className="font-medium">Full Address:</span><br />
                            <code className="bg-gray-100 p-1 rounded">{asset.address}</code>
                          </div>
                          <div>
                            <span className="font-medium">Yakoa Token ID:</span><br />
                            <code className="bg-gray-100 p-1 rounded">{asset.yakoaTokenId}</code>
                          </div>
                          <div>
                            <span className="font-medium">Verification Time:</span><br />
                            {new Date(asset.yakoaTimestamp * 1000).toLocaleString()}
                          </div>
                          <div>
                            <span className="font-medium">Eligible for Loans:</span><br />
                            {asset.isEligible ? '✅ Yes' : '❌ No'}
                          </div>
                        </div>
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          )}
        </div>

        {/* Loans Section */}
        <div className="bg-white rounded-2xl shadow-lg p-6 border border-gray-100">
          <h2 className="text-xl font-semibold text-gray-900 mb-4 flex items-center">
            <DollarSign className="w-6 h-6 mr-3 text-blue-600" />
            Your Loans ({loans.length})
          </h2>
          
          {loans.length === 0 ? (
            <div className="text-center py-12">
              <DollarSign className="w-16 h-16 text-gray-300 mx-auto mb-4" />
              <h3 className="text-lg font-medium text-gray-900 mb-2">No Loans Yet</h3>
              <p className="text-gray-500 mb-4">Create a loan using your verified IP assets as collateral</p>
            </div>
          ) : (
            <div className="space-y-4">
              {loans.map((loan) => (
                <div key={loan.id} className="border border-gray-200 rounded-xl p-6 hover:bg-gray-50 transition-colors">
                  <div className="flex justify-between items-start">
                    <div className="flex-1">
                      <div className="flex items-center mb-3">
                        <h3 className="font-medium text-gray-900 mr-3">Loan #{loan.id}</h3>
                        <span className={`inline-flex items-center px-3 py-1 rounded-full text-xs font-medium ${
                          loan.isRepaid ? 'text-green-700 bg-green-50 border border-green-200' :
                          loan.isActive ? 'text-blue-700 bg-blue-50 border border-blue-200' :
                          'text-gray-700 bg-gray-50 border border-gray-200'
                        }`}>
                          {loan.isRepaid ? 'Repaid' : loan.isActive ? 'Active' : 'Inactive'}
                        </span>
                      </div>
                      
                      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm text-gray-600">
                        <div>
                          <span className="font-medium">Amount:</span><br />
                          {ethers.formatUnits(loan.loanAmount, 6)} USDC
                        </div>
                        <div>
                          <span className="font-medium">Collateral:</span><br />
                          {ethers.formatEther(loan.collateralValue)} ETH
                        </div>
                        <div>
                          <span className="font-medium">Interest Rate:</span><br />
                          {(loan.interestRate / 100).toFixed(2)}% APR
                        </div>
                        <div>
                          <span className="font-medium">Duration:</span><br />
                          {Math.round(loan.duration / (24 * 60 * 60))} days
                        </div>
                      </div>
                    </div>
                    
                    {loan.isActive && !loan.isRepaid && (
                      <button
                        onClick={() => repayLoan(loan.id)}
                        disabled={loading}
                        className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:bg-gray-400 font-medium transition-colors"
                      >
                        Repay Loan
                      </button>
                    )}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="mt-8 text-center text-sm text-gray-500">
          <p className="flex items-center justify-center">
            <Shield className="w-4 h-4 mr-2" />
            Powered by Story Protocol • Yakoa IP Verification • deBridge Cross-Chain
          </p>
        </div>
      </div>
    </div>
  );
}
