'use client';

import { useEffect, useState } from 'react';
import { useAccount, usePublicClient, useWalletClient } from 'wagmi';
import { ethers } from 'ethers';
import { CONTRACT_ABI, CONTRACT_ADDRESSES, IP_ASSET_REGISTRY_ABI, ERC20_ABI } from '@/lib/contracts';

export function useContracts() {
  const { address } = useAccount();
  const publicClient = usePublicClient();
  const { data: walletClient } = useWalletClient();
  
  const [contracts, setContracts] = useState<{
    lendingContract?: ethers.Contract;
    ipAssetRegistry?: ethers.Contract;
    usdcContract?: ethers.Contract;
    signer?: ethers.Signer;
    provider?: ethers.Provider;
  }>({});

  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (typeof window === 'undefined') return;
    
    if (!walletClient || !publicClient) {
      setContracts({});
      return;
    }

    const setupContracts = async () => {
      setIsLoading(true);
      setError(null);
      
      try {
        console.log('🔧 Setting up contracts with ENS disabled...');
        
        // ✅ Create provider with ENS disabled for Story network
        const provider = new ethers.BrowserProvider(walletClient.transport, {
          chainId: 1315,
          name: 'story-testnet',
          // ✅ Disable ENS for Story network
          ensAddress: null,
        });

        const signer = await provider.getSigner();

        // ✅ Create contracts with explicit address validation
        const lendingContract = new ethers.Contract(
          ethers.getAddress(CONTRACT_ADDRESSES.LENDING_PROTOCOL), // ✅ Explicit address validation
          CONTRACT_ABI,
          signer
        );

        const ipAssetRegistry = new ethers.Contract(
          ethers.getAddress(CONTRACT_ADDRESSES.IP_ASSET_REGISTRY), // ✅ Explicit address validation
          IP_ASSET_REGISTRY_ABI,
          signer
        );

        const usdcContract = new ethers.Contract(
          ethers.getAddress(CONTRACT_ADDRESSES.USDC), // ✅ Explicit address validation
          ERC20_ABI,
          signer
        );

        // ✅ Test contract connectivity
        try {
          await lendingContract.owner();
          console.log('✅ Contracts connected successfully with ENS disabled');
        } catch (contractError) {
          console.warn('⚠️ Contract connectivity test failed:', contractError);
        }

        setContracts({
          lendingContract,
          ipAssetRegistry,
          usdcContract,
          signer,
          provider,
        });
      } catch (error) {
        console.error('❌ Error setting up contracts:', error);
        setError(error instanceof Error ? error.message : 'Failed to setup contracts');
      } finally {
        setIsLoading(false);
      }
    };

    setupContracts();
  }, [walletClient, publicClient]);

  return { ...contracts, isLoading, error };
}
