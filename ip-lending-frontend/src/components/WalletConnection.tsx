'use client';

import { ConnectButton } from '@rainbow-me/rainbowkit';

export function WalletConnection() {
  return (
    <div className="flex justify-end p-4">
      <ConnectButton />
    </div>
  );
}
