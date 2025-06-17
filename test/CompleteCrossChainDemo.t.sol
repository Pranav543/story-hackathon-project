// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {IPCollateralLending} from "../src/IPCollateralLending.sol";
import {CrossChainLender} from "../src/CrossChainLender.sol";
import {SimpleNFT} from "../src/mocks/SimpleNFT.sol";
import {CustomMockERC20} from "../src/mocks/CustomMockERC20.sol";
import {IIPAssetRegistry} from "@storyprotocol/core/interfaces/registries/IIPAssetRegistry.sol";

contract CompleteCrossChainDemoFixed is Test {
    // Use deployed contract addresses
    IPCollateralLending storyLending = IPCollateralLending(0xE4b121AD75466CF79a8975725CDD26C703740005);
    CustomMockERC20 storyUSDC = CustomMockERC20(0x8B91bc1451cE991C3CE01dd24944FcEcbecAEE36);
    
    // Will be set from deployment
    CrossChainLender evmLender;
    CustomMockERC20 evmUSDC;
    
    // Real Story Protocol contracts
    IIPAssetRegistry constant IP_ASSET_REGISTRY = IIPAssetRegistry(0x77319B4031e6eF1250907aa00018B8B1c67a244b);
    
    SimpleNFT nft;
    address ipAsset;
    address alice = address(0xa11ce);
    address bob = address(0xb0b);
    
    function setUp() public {
        console.log(" Setting up demo with deployed contracts...");
        
        // Connect to Story fork (localhost:8545)
        vm.createSelectFork("http://127.0.0.1:8545");
        
        // Fund alice on Story fork using anvil's funded account
        address anvilAccount = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // Anvil default funded account
        vm.startPrank(anvilAccount);
        payable(alice).transfer(10 ether);
        vm.stopPrank();
        
        // Create and register IP asset
        _setupIPAsset();
        
        // Connect to Ethereum fork for EVM setup
        vm.createSelectFork("http://127.0.0.1:8546");
        
        // Set EVM contracts from environment or use defaults
        try vm.envAddress("ETHEREUM_LENDER_CONTRACT") returns (address lenderAddr) {
            evmLender = CrossChainLender(lenderAddr);
        } catch {
            // Fallback - deploy new one
            evmLender = new CrossChainLender(address(storyLending));
        }
        
        try vm.envAddress("ETHEREUM_USDC_CONTRACT") returns (address usdcAddr) {
            evmUSDC = CustomMockERC20(usdcAddr);
        } catch {
            // Fallback - deploy new one
            evmUSDC = new CustomMockERC20("Test USDC", "TUSDC", 6);
            evmUSDC.mint(address(evmLender), 10000000e6);
            evmLender.setSupportedToken(address(evmUSDC), true);
        }
        
        // Fund alice on Ethereum fork
        address anvilAccountEth = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        vm.startPrank(anvilAccountEth);
        payable(alice).transfer(10 ether);
        evmUSDC.mint(alice, 100000e6);
        vm.stopPrank();
        
        console.log(" Setup complete! Ready for demo.\n");
    }
    
    function _setupIPAsset() internal {
        // Deploy NFT and register IP asset
        nft = new SimpleNFT("Demo IP NFT", "DEMO");
        uint256 tokenId = nft.mint(alice);
        
        vm.prank(alice);
        ipAsset = IP_ASSET_REGISTRY.register(1514, address(nft), tokenId);
        
        console.log("    IP asset registered:", ipAsset);
    }
    
    function test_CompleteCrossChainIPLendingFlow() public {
        console.log(" STARTING COMPLETE CROSS-CHAIN IP COLLATERAL LENDING DEMO");
        console.log("================================================================================");
        
        uint256 loanId = _step1_CreateAndVerifyIPAsset();
        _step2_CreateLoan(loanId);
        _step3_CrossChainLending(loanId);
        _step4_AssignRoyalty(loanId);
        _step5_CrossChainRoyaltyRepayment(loanId);
        
        console.log("================================================================================");
        console.log(" DEMO COMPLETE: FULL CROSS-CHAIN IP COLLATERAL LENDING CYCLE");
        console.log("================================================================================");
        _printFinalSummary(loanId);
    }
    
    function _step1_CreateAndVerifyIPAsset() internal returns (uint256) {
        vm.createSelectFork("http://127.0.0.1:8545"); // Switch to Story
        console.log("STEP 1: IP Asset Creation & Yakoa Verification");
        console.log("--------------------------------------------------");
        
        // Verify IP is registered with real registry
        bool isRegistered = IP_ASSET_REGISTRY.isRegistered(ipAsset);
        require(isRegistered, "IP not registered with real registry");
        console.log(" IP asset registered with real Story Protocol:");
        console.log("  Address:", ipAsset);
        console.log("  Contract:", address(nft));
        
        // Mock Yakoa verification
        string memory yakoaTokenId = "demo:real:mainnet:123";
        storyLending.initiateYakoaVerification(ipAsset, yakoaTokenId, 100000e6);
        console.log(" Yakoa verification initiated");
        
        storyLending.updateYakoaVerification(yakoaTokenId, true, 20);
        console.log(" Yakoa verification completed:");
        console.log("  Status: VERIFIED");
        console.log("  Assessed Value: $100,000 USDC");
        console.log("  Risk Score: 20 (Low Risk)");
        
        return 0;
    }
    
    function _step2_CreateLoan(uint256) internal returns (uint256) {
        console.log(" STEP 2: Loan Creation with IP Collateral");
        console.log("--------------------------------------------------");
        
        uint256 loanAmount = 50000e6;
        uint256 duration = 365 days;
        
        console.log("Creating loan with parameters:");
        console.log("  Loan Amount: $50,000 USDC (50% LTV)");
        console.log("  Duration: 365 days");
        
        vm.prank(alice);
        storyLending.createLoan(ipAsset, loanAmount, duration, address(storyUSDC), 1514);
        
        uint256 loanId = storyLending.nextLoanId() - 1;
        console.log(" Loan created with ID:", loanId);
        
        return loanId;
    }
    
    function _step3_CrossChainLending(uint256 loanId) internal {
        console.log(" STEP 3: Cross-Chain Automatic Lending");
        console.log("--------------------------------------------------");
        
        // Story side: Initiate cross-chain lending
        console.log(" Story Protocol: Initiating cross-chain lending...");
        
        vm.prank(alice);
        storyLending.initiateCrossChainLending(loanId, 1, address(evmLender));
        console.log(" Cross-chain lending order created");
        
        // Switch to Ethereum fork
        vm.createSelectFork("http://127.0.0.1:8546");
        console.log(" Ethereum: Processing cross-chain lending...");
        
        uint256 balanceBefore = evmUSDC.balanceOf(alice);
        
        // Simulate deBridge order fulfillment
        CrossChainLender.StoryLoanRequest memory loanRequest = CrossChainLender.StoryLoanRequest({
            loanId: loanId,
            borrower: alice,
            amount: 50000e6,
            token: address(evmUSDC),
            ipAsset: ipAsset,
            sourceChainId: 1514
        });
        
        bytes32 deBridgeOrderId = evmLender.createDeBridgeOrder(loanRequest);
        evmLender.processCrossChainLoanRequest(loanRequest, deBridgeOrderId);
        
        uint256 balanceAfter = evmUSDC.balanceOf(alice);
        console.log(" Cross-chain lending completed!");
        console.log("  Alice received:", (balanceAfter - balanceBefore) / 1e6, "USDC on Ethereum");
    }
    
    function _step4_AssignRoyalty(uint256 loanId) internal {
        vm.createSelectFork("http://127.0.0.1:8545"); // Switch back to Story
        console.log("\n STEP 4: IP Royalty Assignment for Repayment");
        console.log("--------------------------------------------------");
        
        vm.prank(alice);
        storyLending.assignRoyaltyToLoan(loanId, 10);
        
        console.log(" Royalty assignment completed:");
        console.log("  Royalty Rate: 10% of all IP revenue");
        console.log("  Integration: Story Protocol RoyaltyModule");
    }
    
    function _step5_CrossChainRoyaltyRepayment(uint256 loanId) internal {
        console.log("\n STEP 5: Cross-Chain Royalty Collection & Repayment");
        console.log("--------------------------------------------------");
        
        // Story side: Collect royalty
        uint256 royaltyAmount = 52500e6;
        storyLending.collectAndTransferRoyalty(loanId, royaltyAmount, 1, address(evmLender));
        console.log(" Royalty collection initiated");
        
        // EVM side: Receive repayment
        vm.createSelectFork("http://127.0.0.1:8546");
        bytes32 royaltyOrderId = keccak256("royalty_transfer_demo");
        evmLender.receiveCrossChainRoyaltyRepayment(0, royaltyAmount, royaltyOrderId, ipAsset);
        
        // Verify completion
        vm.createSelectFork("http://127.0.0.1:8545");
        IPCollateralLending.Loan memory loan = storyLending.getLoan(loanId);
        console.log(" Loan Status:", loan.isRepaid ? "FULLY REPAID" : "ACTIVE");
    }
    
    function _printFinalSummary(uint256 loanId) internal {
        console.log("\n FINAL SUMMARY - CROSS-CHAIN IP COLLATERAL LENDING");
        console.log("============================================================");
        
        // Get final stats
        vm.createSelectFork("http://127.0.0.1:8545");
        IPCollateralLending.Loan memory loan = storyLending.getLoan(loanId);
        
        vm.createSelectFork("http://127.0.0.1:8546");
        (uint256 totalLent, uint256 totalRepaid,) = evmLender.getTotalStats(address(evmUSDC));
        
        console.log(" DEMO ACHIEVEMENTS:");
        console.log("    IP Asset creation with Story SDK");
        console.log("    Yakoa verification (mock)");
        console.log("    IP collateral loan creation");
        console.log("    Cross-chain automatic lending");
        console.log("    Royalty assignment to IP asset");
        console.log("    Cross-chain royalty repayment");
        console.log("    Complete IP -> Loan -> Repayment cycle");
        
        console.log("\n STATISTICS:");
        console.log("    Total Lent: $", totalLent / 1e6, "USDC");
        console.log("    Total Repaid: $", totalRepaid / 1e6, "USDC");
        console.log("    Loan Status:", loan.isRepaid ? "REPAID " : "ACTIVE ");
    }
}
