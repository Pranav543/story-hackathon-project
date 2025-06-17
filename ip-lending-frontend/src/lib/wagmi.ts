'use client';

import { getDefaultConfig } from '@tomo-inc/tomo-evm-kit'; // Changed from RainbowKit

const storyTestnet = {
  id: 1315,
  name: 'Story Aeneid Testnet',
  nativeCurrency: {
    decimals: 18,
    name: 'Story',
    symbol: 'STORY',
  },
  rpcUrls: {
    default: {
      http: ['https://aeneid.storyrpc.io/'],
    },
  },
  blockExplorers: {
    default: { name: 'Story Explorer', url: 'https://explorer.aeneid.storyrpc.io/' },
  },
} as const;

export const config = getDefaultConfig({
  clientId: process.env.NEXT_PUBLIC_TOMO_CLIENT_ID || '', // Added for Tomo
  appName: 'IP Collateral Lending',
  projectId: process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID || '8d7e154eca3c014701f5380d7ba35073',
  chains: [storyTestnet],
  ssr: true,
});
