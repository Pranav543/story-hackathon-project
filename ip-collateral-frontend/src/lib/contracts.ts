import { ethers } from 'ethers';

// ✅ Validate and format contract addresses
const validateAddress = (address: string): string => {
  try {
    return ethers.getAddress(address);
  } catch (error) {
    throw new Error(`Invalid contract address: ${address}`);
  }
};

export const CONTRACT_ADDRESSES = {
  LENDING_PROTOCOL: validateAddress(process.env.NEXT_PUBLIC_CONTRACT_ADDRESS as string),
  USDC: validateAddress(process.env.NEXT_PUBLIC_USDC_ADDRESS as string),
  IP_ASSET_REGISTRY: validateAddress(process.env.NEXT_PUBLIC_IP_ASSET_REGISTRY as string),
};

// ✅ Main lending contract ABI
export const CONTRACT_ABI = [
  // Yakoa integration functions
  "function initiateYakoaVerification(address ipAsset, string memory yakoaTokenId, uint256 assessedValue) external",
  "function updateYakoaVerification(string memory yakoaTokenId, bool isVerified, uint256 riskScore) external",
  "function handleYakoaTimeout(string memory yakoaTokenId) external",
  
  // Core lending functions
  "function createLoan(address ipAsset, uint256 loanAmount, uint256 duration, address loanToken, uint256 borrowerChainId) external",
  "function repayLoan(uint256 loanId) external",
  "function liquidateLoan(uint256 loanId) external",
  
  // Cross-chain functions
  "function initiateCrossChainRepayment(uint256 loanId, uint256 sourceChainId, address sourceToken, uint256 sourceAmount, bytes32 deBridgeOrderId) external",
  "function processCrossChainRepayment(uint256 loanId, uint256 repaymentAmount, bytes32 deBridgeOrderId) external",
  "function addCrossChainLiquidity(address token, uint256 amount, uint256 sourceChain) external",
  "function addCrossChainLiquidity(address token, uint256 amount, uint256 sourceChain, bytes32 deBridgeOrderId) external",
  
  // View functions
  "function getIPCollateral(address ipAsset) external view returns (tuple(address ipAsset, uint256 assessedValue, uint256 riskScore, bool isEligible, uint256 lastValidated, bytes32 yakoaHash, string yakoaTokenId, uint8 yakoaStatus, uint256 yakoaTimestamp))",
  "function getLoan(uint256 loanId) external view returns (tuple(address borrower, address ipAsset, uint256 collateralValue, uint256 loanAmount, uint256 interestRate, uint256 startTime, uint256 duration, address loanToken, bool isActive, bool isRepaid, uint8 status, uint256 sourceChainId))",
  "function getUserLoans(address user) external view returns (uint256[])",
  "function calculateTotalOwed(uint256 loanId) external view returns (uint256)",
  "function getYakoaStatus(string memory yakoaTokenId) external view returns (address ipAsset, uint8 status)",
  "function getCrossChainRepayment(bytes32 deBridgeOrderId) external view returns (tuple(uint256 loanId, address borrower, uint256 sourceChainId, address sourceToken, uint256 sourceAmount, bytes32 deBridgeOrderId, uint256 timestamp, bool isCompleted))",
  "function nextLoanId() external view returns (uint256)",
  
  // Admin functions
  "function setSupportedToken(address token, bool supported) external",
  "function owner() external view returns (address)",
  
  // Events
  "event YakoaVerificationStarted(address indexed ipAsset, string yakoaTokenId)",
  "event YakoaVerificationCompleted(address indexed ipAsset, string yakoaTokenId, uint8 status, bool isEligible)",
  "event LoanCreated(uint256 indexed loanId, address indexed borrower, address indexed ipAsset, uint256 loanAmount, uint256 collateralValue, uint256 sourceChainId)",
  "event LoanRepaid(uint256 indexed loanId, address indexed borrower, uint256 amount)",
  "event CrossChainRepaymentInitiated(uint256 indexed loanId, address indexed borrower, uint256 sourceChainId, bytes32 deBridgeOrderId)",
  "event CrossChainLiquidityAdded(address indexed token, uint256 amount, uint256 sourceChain, bytes32 deBridgeOrderId)",
];

// ✅ IP Asset Registry ABI (MISSING EXPORT - NOW ADDED)
export const IP_ASSET_REGISTRY_ABI = [
  "function register(uint256 chainId, address tokenContract, uint256 tokenId) external returns (address)",
  "function isRegistered(address ipAsset) external view returns (bool)",
  "function ipAssetTokens(address ipAsset) external view returns (uint256 chainId, address tokenContract, uint256 tokenId)",
];

// ✅ ERC20 ABI (MISSING EXPORT - NOW ADDED)
export const ERC20_ABI = [
  "function approve(address spender, uint256 amount) external returns (bool)",
  "function transfer(address to, uint256 amount) external returns (bool)",
  "function transferFrom(address from, address to, uint256 amount) external returns (bool)",
  "function balanceOf(address owner) external view returns (uint256)",
  "function allowance(address owner, address spender) external view returns (uint256)",
  "function decimals() external view returns (uint8)",
  "function symbol() external view returns (string)",
  "function name() external view returns (string)",
  "function mint(address to, uint256 amount) external", // For test tokens
];

// ✅ Simple NFT ABI for testing
export const SIMPLE_NFT_ABI = [
  "function mint(address to) external returns (uint256)",
  "function ownerOf(uint256 tokenId) external view returns (address)",
  "function approve(address to, uint256 tokenId) external",
  "function name() external view returns (string)",
  "function symbol() external view returns (string)",
  "function tokenURI(uint256 tokenId) external view returns (string)",
];

// ✅ Helper function to create contracts with ENS disabled
export const createContract = (
  address: string,
  abi: any[],
  signerOrProvider: ethers.Signer | ethers.Provider
): ethers.Contract => {
  const validatedAddress = ethers.getAddress(address);
  return new ethers.Contract(validatedAddress, abi, signerOrProvider);
};
