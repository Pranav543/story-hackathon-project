'use client';

import { WalletConnection } from '@/components/WalletConnection';
import { StorySDKFlow } from '@/components/StorySDKFlow';

export default function Home() {
  return (
    <div className="min-h-screen bg-gray-50">
      <header className="bg-white shadow-sm">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <h1 className="text-xl font-bold text-gray-900">
              IP Collateral Lending Protocol
            </h1>
            <WalletConnection />
          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        <StorySDKFlow />
      </main>

      <div className="fixed bottom-4 right-4 bg-green-600 text-white px-4 py-2 rounded-lg shadow-lg">
        <div className="flex items-center space-x-2">
          <div className="w-2 h-2 bg-white rounded-full animate-pulse"></div>
          <span className="text-sm">Story + deBridge Ready</span>
        </div>
      </div>
    </div>
  );
}
