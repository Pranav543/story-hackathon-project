'use client';

import { getDefaultConfig } from '@rainbow-me/rainbowkit';

const storyTestnet = {
  id: 1315, // Updated chain ID
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
  appName: 'IP Collateral Lending',
  projectId: '8d7e154eca3c014701f5380d7ba35073', // Get from WalletConnect
  chains: [storyTestnet],
  ssr: true,
});

