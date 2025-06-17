'use client';

import { useConnectModal, useAccountModal, useChainModal } from '@tomo-inc/tomo-evm-kit'; // Changed from RainbowKit
import { useAccount, useDisconnect } from 'wagmi';

export function WalletConnection() {
  const { openConnectModal } = useConnectModal();
  const { openAccountModal } = useAccountModal();
  const { openChainModal } = useChainModal();
  const { address, isConnected } = useAccount();
  const { disconnect } = useDisconnect();

  // If wallet is connected, show account info
  if (isConnected && address) {
    return (
      <div className="flex items-center space-x-2">
        <button
          onClick={openChainModal}
          className="px-3 py-2 text-sm bg-gray-100 hover:bg-gray-200 rounded-md transition-colors"
        >
          Switch Network
        </button>
        <button
          onClick={openAccountModal}
          className="px-4 py-2 text-sm bg-blue-600 hover:bg-blue-700 text-white rounded-md transition-colors"
        >
          {address.slice(0, 6)}...{address.slice(-4)}
        </button>
      </div>
    );
  }

  // If not connected, show connect button
  return (
    <button
      onClick={openConnectModal}
      className="px-4 py-2 text-sm bg-blue-600 hover:bg-blue-700 text-white rounded-md transition-colors"
    >
      Connect Wallet
    </button>
  );
}
