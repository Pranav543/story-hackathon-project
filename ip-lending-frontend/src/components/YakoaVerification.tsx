'use client';

import { useState } from 'react';
import { useAccount, useWriteContract } from 'wagmi';
import { CONTRACTS } from '@/lib/contracts';

export function YakoaVerification() {
  const { address } = useAccount();
  const [formData, setFormData] = useState({
    ipAsset: '',
    yakoaTokenId: '',
    assessedValue: ''
  });
  const [isLoading, setIsLoading] = useState(false);

  const { writeContract } = useWriteContract();

  const handleInitiateVerification = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!address) return;

    setIsLoading(true);
    try {
      await writeContract({
        address: CONTRACTS.IP_LENDING.address as `0x${string}`,
        abi: CONTRACTS.IP_LENDING.abi,
        functionName: 'initiateYakoaVerification',
        args: [
          formData.ipAsset as `0x${string}`,
          formData.yakoaTokenId,
          BigInt(formData.assessedValue)
        ],
      });
    } catch (error) {
      console.error('Error initiating verification:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const handleUpdateVerification = async (isVerified: boolean, riskScore: number) => {
    if (!address) return;

    try {
      await writeContract({
        address: CONTRACTS.IP_LENDING.address as `0x${string}`,
        abi: CONTRACTS.IP_LENDING.abi,
        functionName: 'updateYakoaVerification',
        args: [
          formData.yakoaTokenId,
          isVerified,
          BigInt(riskScore)
        ],
      });
    } catch (error) {
      console.error('Error updating verification:', error);
    }
  };

  return (
    <div className="max-w-md mx-auto p-6 bg-white rounded-lg shadow-md">
      <h2 className="text-2xl font-bold mb-6">Yakoa IP Verification</h2>
      
      <form onSubmit={handleInitiateVerification} className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            IP Asset Address
          </label>
          <input
            type="text"
            value={formData.ipAsset}
            onChange={(e) => setFormData({...formData, ipAsset: e.target.value})}
            className="w-full p-3 border border-gray-300 rounded-md"
            placeholder="0x..."
            required
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Yakoa Token ID
          </label>
          <input
            type="text"
            value={formData.yakoaTokenId}
            onChange={(e) => setFormData({...formData, yakoaTokenId: e.target.value})}
            className="w-full p-3 border border-gray-300 rounded-md"
            placeholder="contract:token_id"
            required
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Assessed Value (USD)
          </label>
          <input
            type="number"
            value={formData.assessedValue}
            onChange={(e) => setFormData({...formData, assessedValue: e.target.value})}
            className="w-full p-3 border border-gray-300 rounded-md"
            placeholder="100000"
            required
          />
        </div>

        <button
          type="submit"
          disabled={!address || isLoading}
          className="w-full bg-purple-600 text-white py-3 px-4 rounded-md hover:bg-purple-700 disabled:opacity-50"
        >
          {isLoading ? 'Initiating...' : 'Initiate Verification'}
        </button>
      </form>

      {formData.yakoaTokenId && (
        <div className="mt-6 space-y-2">
          <h3 className="font-medium">Update Verification Result:</h3>
          <div className="flex space-x-2">
            <button
              onClick={() => handleUpdateVerification(true, 20)}
              className="flex-1 bg-green-600 text-white py-2 px-4 rounded-md hover:bg-green-700"
            >
              Verify (Low Risk)
            </button>
            <button
              onClick={() => handleUpdateVerification(false, 80)}
              className="flex-1 bg-red-600 text-white py-2 px-4 rounded-md hover:bg-red-700"
            >
              Reject (High Risk)
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
