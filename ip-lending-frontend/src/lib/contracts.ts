export const CONTRACTS = {
  IP_LENDING: {
    address: process.env.NEXT_PUBLIC_LENDING_CONTRACT,
    abi: [
      {
        type: "function",
        name: "createLoan",
        inputs: [
          {name: "ipAsset", type: "address"},
          {name: "loanAmount", type: "uint256"},
          {name: "duration", type: "uint256"},
          {name: "loanToken", type: "address"},
          {name: "borrowerChainId", type: "uint256"}
        ],
        outputs: [],
        stateMutability: "nonpayable"
      },
      {
        type: "function",
        name: "initiateYakoaVerification",
        inputs: [
          {name: "ipAsset", type: "address"},
          {name: "yakoaTokenId", type: "string"},
          {name: "assessedValue", type: "uint256"}
        ],
        outputs: [],
        stateMutability: "nonpayable"
      },
      {
        type: "function",
        name: "updateYakoaVerification",
        inputs: [
          {name: "yakoaTokenId", type: "string"},
          {name: "isVerified", type: "bool"},
          {name: "riskScore", type: "uint256"}
        ],
        outputs: [],
        stateMutability: "nonpayable"
      }
    ] as const
  },
  USDC: {
    address: "0xF2104833d386a2734a4eB3B8ad6FC6812F29E38E",
    abi: [] as const
  }
};

export const STORY_CONTRACTS = {
  IP_ASSET_REGISTRY: "0x77319B4031e6eF1250907aa00018B8B1c67a244b"
};
