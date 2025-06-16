import { StoryClient, StoryConfig } from '@story-protocol/core-sdk';
import { http } from 'viem';

// Create Story client with wallet client from wagmi
export const createStoryClient = (walletClient: any) => {
  const config: StoryConfig = {
    transport: http('https://aeneid.storyrpc.io'),
    chainId: 'aeneid',
    wallet: walletClient, // Pass the wallet client here
  };
  
  return StoryClient.newClient(config);
};
