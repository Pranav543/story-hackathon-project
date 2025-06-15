'use client';

import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { http, createStorage, cookieStorage } from 'wagmi';
import { defineChain } from 'viem';

// ✅ Enhanced Story Testnet Configuration with ENS disabled
export const storyTestnet = defineChain({
  id: 1315,
  name: 'Story Aeneid Testnet',
  nativeCurrency: {
    decimals: 18,
    name: 'IP',
    symbol: 'IP',
  },
  rpcUrls: {
    default: {
      http: ['https://aeneid.storyrpc.io'],
    },
  },
  blockExplorers: {
    default: {
      name: 'Story Explorer',
      url: 'https://aeneid.storyscan.io',
    },
  },
  testnet: true,
  // ✅ Explicitly disable ENS for this network
  contracts: {
    // No ENS contracts defined - this prevents ENS resolution attempts
  },
});

export const config = getDefaultConfig({
  appName: 'IP Collateral Lending Protocol',
  projectId: process.env.NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID!,
  chains: [storyTestnet],
  ssr: true,
  storage: createStorage({
    storage: cookieStorage,
  }),
  transports: {
    [storyTestnet.id]: http(),
  },
});
