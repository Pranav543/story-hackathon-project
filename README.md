# IP Collateral Lending Protocol

## Step-by-Step Frontend Setup

### 1. Environment Configuration

Create `.env.local` file in the frontend root:
```bash
# Wallet Connect Project ID (get from https://cloud.walletconnect.com)
NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=your_wallet_connect_project_id

# Your deployed contract addresses (from backend deployment)
NEXT_PUBLIC_LENDING_CONTRACT=0xE4b121AD75466CF79a8975725CDD26C703740005
NEXT_PUBLIC_STORY_USDC_CONTRACT=0x8B91bc1451cE991C3CE01dd24944FcEcbecAEE36

# Story Protocol Configuration
NEXT_PUBLIC_STORY_RPC_URL=https://aeneid.storyrpc.io
NEXT_PUBLIC_STORY_CHAIN_ID=1315

# For local testing with forked networks
NEXT_PUBLIC_LOCAL_STORY_RPC=http://127.0.0.1:8545
NEXT_PUBLIC_LOCAL_ETH_RPC=http://127.0.0.1:8546
```

### 2. Install Dependencies

```bash
# Navigate to frontend directory
cd ip-lending-frontend

# Install all dependencies
npm install

# Or with yarn
yarn install

# Verify Story SDK installation
npm list @story-protocol/core-sdk
```

## 3. Running the Frontend

### 1. Development Mode (Local Testing)

**Prerequisites: Ensure your forked networks are running**
```bash
# Terminal 1: Story fork
anvil --fork-url https://mainnet.storyrpc.io --port 8545 --chain-id 1514 --balance 1000

# Terminal 2: Ethereum fork (optional)
anvil --fork-url https://mainnet.infura.io/v3/YOUR_KEY --port 8546 --chain-id 1 --balance 1000
```

**Start the frontend:**
```bash
# In the frontend directory
npm run dev

# Or with yarn
yarn dev

```

###  Network Switching

Test switching between networks:
```bash
# The frontend should handle:
# - Story Protocol (testnet/mainnet)
# - Story Local (forked network)
# - Ethereum Local (for cross-chain demo)
```

## Frontend Components Overview

### Main Components

1. **StorySDKFlow.tsx**: Core lending flow
   - IP asset creation using Story SDK
   - Yakoa verification process
   - Loan creation with IP collateral
   - Transaction management

2. **WalletConnection.tsx**: Wallet integration
   - RainbowKit wallet connect button
   - Network switching
   - Account management

3. **LocalCrossChainDemo.tsx**: Demo component
   - Cross-chain lending simulation
   - Royalty management demo
   - Complete flow visualization



## Step-by-Step Testing Guide

### 1. Network Setup

Start two forked networks in separate terminals:

**Terminal 1: Story Protocol Fork**
```bash
# Fork Story mainnet to localhost:8545
anvil --fork-url https://rpc.storyrpc.io --port 8545 --chain-id 1514 --balance 1000 --accounts 10

```

**Terminal 2: Ethereum Fork**
```bash
# Fork Ethereum mainnet to localhost:8546
anvil --fork-url https://mainnet.infura.io/v3/YOUR_INFURA_KEY --port 8546 --chain-id 1 --balance 1000 --accounts 10
```

### 2. Contract Deployment

**Deploy to Story Fork (Terminal 3):**
```bash
# Deploy IPCollateralLending contract to Story fork
forge script script/DeployStoryFork.s.sol --rpc-url http://127.0.0.1:8545 --broadcast -vvv

```

**Deploy to Ethereum Fork:**
```bash
# Set the Story contract address from previous deployment
export STORY_LENDING_CONTRACT=0xE4b121AD75466CF79a8975725CDD26C703740005

# Deploy CrossChainLender contract to Ethereum fork
forge script script/DeployEthereumFork.s.sol --rpc-url http://127.0.0.1:8546 --broadcast -vvv

```

### 3. Test Execution

#### Core Protocol Tests
```bash
# Test basic IP collateral lending functionality
forge test --match-path test/IPCollateralLending.t.sol --fork-url http://127.0.0.1:8545 -vvv

```

#### Cross-Chain Integration Tests
```bash
# Test cross-chain lending and repayment
forge test --match-path test/DeBridgeIntegration.t.sol --fork-url http://127.0.0.1:8545 -vvv

```

#### Complete Demo Test
```bash
# Run the comprehensive demo using deployed contracts
forge test --match-test test_CompleteStoryProtocolFlow --match-contract LocalAnvilDemo --rpc-url http://127.0.0.1:8545 -vvv

```


**Run All Tests:**
```bash
# Execute complete test suite
forge test --fork-url http://127.0.0.1:8545 -vvv
```

## Note: deBridge Testnet Limitations

**Important**: deBridge currently does not support testnets, so cross-chain operations are demonstrated via local forked network emulation. The smart contracts and tests are fully implemented with real deBridge mainnet addresses, but frontend cross-chain interactions are simulated locally.

**What's Fully Functional:**
- ✅ Complete backend implementation with deBridge integration
- ✅ Comprehensive test suite using forked networks
- ✅ Story Protocol integration with live contracts


**What's Simulated:**
- ⚠️ Live cross-chain transactions (demonstrated locally)
- ⚠️ Real-time deBridge message passing (simulated)


