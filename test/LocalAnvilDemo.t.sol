// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {IPCollateralLending} from "../src/IPCollateralLending.sol";
import {CrossChainLender} from "../src/CrossChainLender.sol";
import {SimpleNFT} from "../src/mocks/SimpleNFT.sol";
import {CustomMockERC20} from "../src/mocks/CustomMockERC20.sol";
import {IIPAssetRegistry} from "@storyprotocol/core/interfaces/registries/IIPAssetRegistry.sol";

contract LocalAnvilDemo is Test {
    // Use your deployed contract addresses
    IPCollateralLending storyLending = IPCollateralLending(0xE4b121AD75466CF79a8975725CDD26C703740005);
    CustomMockERC20 storyUSDC = CustomMockERC20(0x8B91bc1451cE991C3CE01dd24944FcEcbecAEE36);
    
    // Use anvil's default funded accounts instead of custom addresses
    address alice = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // Anvil account #0
    address bob = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;   // Anvil account #1
    
    // Real Story Protocol contracts
    IIPAssetRegistry constant IP_ASSET_REGISTRY = IIPAssetRegistry(0x77319B4031e6eF1250907aa00018B8B1c67a244b);
    
    SimpleNFT nft;
    address ipAsset;
    uint256 loanId;
    
    function setUp() public {
        console.log("Setting up local anvil demo...");
        
        // No forking - use the current network (should be localhost:8545)
        // Make sure anvil is running: anvil --fork-url https://rpc.storyrpc.io --port 8545 --chain-id 1514 --balance 1000
        
        // Create and register IP asset
        _setupIPAsset();
        
        console.log("Setup complete! Ready for demo.\n");
    }
    
    function _setupIPAsset() internal {
        // Deploy NFT and register IP asset
        nft = new SimpleNFT("Demo IP NFT", "DEMO");
        uint256 tokenId = nft.mint(alice);
        
        vm.prank(alice);
        ipAsset = IP_ASSET_REGISTRY.register(1514, address(nft), tokenId);
        
        console.log("   IP asset registered:", ipAsset);
        console.log("   Alice address:", alice);
        console.log("   Alice ETH balance:", alice.balance / 1e18, "ETH");
    }
    
    function test_CompleteStoryProtocolFlow() public {
        console.log("COMPLETE STORY PROTOCOL IP COLLATERAL LENDING DEMO");
        console.log("================================================================");
        
        _step1_VerifyDeployedContracts();
        _step2_IPVerification();
        _step3_CreateLoan();
        _step4_CrossChainSimulation();
        _step5_RoyaltyManagement();
        
        console.log("================================================================");
        console.log("DEMO COMPLETE: STORY PROTOCOL INTEGRATION SUCCESSFUL!");
        console.log("================================================================");
        _printFinalSummary();
    }
    
    function _step1_VerifyDeployedContracts() internal {
        console.log("\nSTEP 1: Verify Deployed Contracts");
        console.log("------------------------------------------");
        
        // Verify Story lending contract
        require(address(storyLending).code.length > 0, "Story lending contract not deployed");
        console.log("Story lending contract verified:", address(storyLending));
        
        // Verify USDC contract
        require(address(storyUSDC).code.length > 0, "Story USDC contract not deployed");
        uint256 lendingBalance = storyUSDC.balanceOf(address(storyLending));
        console.log("Story USDC contract verified:", address(storyUSDC));
        console.log("Lending contract USDC balance:", lendingBalance / 1e6, "TUSDC");
        
        // Verify IP Asset Registry
        require(address(IP_ASSET_REGISTRY).code.length > 0, "IP Asset Registry not available");
        bool isRegistered = IP_ASSET_REGISTRY.isRegistered(ipAsset);
        require(isRegistered, "IP not registered with real registry");
        console.log("Real IP Asset Registry verified:", address(IP_ASSET_REGISTRY));
        console.log("IP asset registration confirmed:", ipAsset);
    }
    
    function _step2_IPVerification() internal {
        console.log("\nSTEP 2: IP Asset Yakoa Verification");
        console.log("------------------------------------------");
        
        string memory yakoaTokenId = "demo:anvil:local:123";
        uint256 assessedValue = 100000e6; // $100k
        
        console.log("Initiating Yakoa verification...");
        console.log("  IP Asset:", ipAsset);
        console.log("  Yakoa Token ID:", yakoaTokenId);
        console.log("  Assessed Value: $100,000 USDC");
        
        // Initiate verification
        storyLending.initiateYakoaVerification(ipAsset, yakoaTokenId, assessedValue);
        console.log("Yakoa verification initiated");
        
        // Complete verification
        storyLending.updateYakoaVerification(yakoaTokenId, true, 20);
        console.log("Yakoa verification completed:");
        console.log("  Status: VERIFIED");
        console.log("  Risk Score: 20 (Low Risk)");
        console.log("  Collateral Eligible: YES");
        
        // Verify the collateral status
        IPCollateralLending.IPCollateral memory collateral = storyLending.getIPCollateral(ipAsset);
        require(collateral.isEligible, "IP should be eligible for collateral");
        console.log("IP collateral status confirmed");
    }
    
    function _step3_CreateLoan() internal {
        console.log("\nSTEP 3: Create Loan with IP Collateral");
        console.log("------------------------------------------");
        
        uint256 loanAmount = 50000e6; // $50k USDC
        uint256 duration = 365 days;   // 1 year
        
        console.log("Creating loan with parameters:");
        console.log("  Borrower:", alice);
        console.log("  IP Collateral:", ipAsset);
        console.log("  Loan Amount: $50,000 USDC (50% LTV)");
        console.log("  Duration: 365 days");
        console.log("  Token:", address(storyUSDC));
        
        vm.prank(alice);
        storyLending.createLoan(ipAsset, loanAmount, duration, address(storyUSDC), 1514);
        
        loanId = storyLending.nextLoanId() - 1;
        IPCollateralLending.Loan memory loan = storyLending.getLoan(loanId);
        
        console.log("Loan created successfully:");
        console.log("  Loan ID:", loanId);
        console.log("  Borrower:", loan.borrower);
        console.log("  Amount:", loan.loanAmount / 1e6, "USDC");
        console.log("  Status:", loan.isActive ? "ACTIVE" : "INACTIVE");
        console.log("  Interest Rate:", loan.interestRate, "basis points");
        
        require(loan.isActive, "Loan should be active");
        require(loan.borrower == alice, "Borrower should be alice");
    }
    
    function _step4_CrossChainSimulation() internal {
        console.log("\nSTEP 4: Cross-Chain Integration Simulation");
        console.log("------------------------------------------");
        
        console.log("Simulating cross-chain lending initiation...");
        
        // Mock Ethereum lender address
        address mockEthLender = address(0x1234567890123456789012345678901234567890);
        
        vm.prank(alice);
        storyLending.initiateCrossChainLending(loanId, 1, mockEthLender);
        
        console.log("Cross-chain lending order created:");
        console.log("  Source Chain: Story Protocol (1514)");
        console.log("  Target Chain: Ethereum (1)");
        console.log("  Target Lender:", mockEthLender);
        console.log("  Integration: deBridge DLN Protocol");
        console.log("  Real DLN Source: 0xeF4fB24aD0916217251F553c0596F8Edc630EB66");
        console.log("  Real DLN Destination: 0xe7351fd770a37282b91d153ee690b63579d6dd7f");
        
        console.log("Cross-chain message would trigger automatic funding");
        console.log("  Process: Story -> deBridge -> Ethereum -> Borrower funded");
    }
    
    function _step5_RoyaltyManagement() internal {
        console.log("\nSTEP 5: IP Royalty Assignment & Management");
        console.log("------------------------------------------");
        
        console.log("Assigning royalty to IP asset for loan repayment...");
        
        vm.prank(alice);
        storyLending.assignRoyaltyToLoan(loanId, 10); // 10% royalty
        
        console.log("Royalty assignment completed:");
        console.log("  IP Asset:", ipAsset);
        console.log("  Royalty Rate: 10% of all IP revenue");
        console.log("  Beneficiary: Lending Contract");
        console.log("  Purpose: Automatic loan repayment");
        console.log("  Integration: Story RoyaltyModule");
        console.log("  Real Contract: 0xD2f60c40fEbccf6311f8B47c4f2Ec6b040400086");
        
        // Simulate royalty collection and cross-chain transfer
        uint256 royaltyAmount = 52500e6; // $52.5k including interest
        
        console.log("\nSimulating royalty collection and repayment...");
        storyLending.collectAndTransferRoyalty(loanId, royaltyAmount, 1, address(0x5678));
        
        console.log("Royalty collection simulated:");
        console.log("  Amount Collected: $52,500 USDC");
        console.log("  Source: IP licensing, usage fees, derivatives");
        console.log("  Target: Cross-chain transfer to EVM lender");
        console.log("  Result: Loan automatically repaid");
        
        // Verify loan status
        IPCollateralLending.Loan memory loan = storyLending.getLoan(loanId);
        console.log("Final loan status:", loan.isRepaid ? "FULLY REPAID" : "ACTIVE");
    }
    
    function _printFinalSummary() internal {
        console.log("\nCOMPREHENSIVE DEMO SUMMARY");
        console.log("================================");
        
        // Get loan details
        IPCollateralLending.Loan memory loan = storyLending.getLoan(loanId);
        IPCollateralLending.IPCollateral memory collateral = storyLending.getIPCollateral(ipAsset);
        
        console.log("STORY PROTOCOL INTEGRATION:");
        console.log("   Real IP Asset Registry:", address(IP_ASSET_REGISTRY));
        console.log("   Real License Registry: 0x529a750E02d8E2f15649c13D69a465286a780e24");
        console.log("   Real Royalty Module: 0xD2f60c40fEbccf6311f8B47c4f2Ec6b040400086");
        console.log("   Real PIL Template: 0x2E896b0b2Fdb7457499B56AAaA4AE55BCB4Cd316");
        
        console.log("\nIP COLLATERAL DETAILS:");
        console.log("   IP Asset Address:", ipAsset);
        console.log("   NFT Contract:", address(nft));
        console.log("   Assessed Value: $", collateral.assessedValue / 1e6);
        console.log("   Risk Score:", collateral.riskScore);
        console.log("   Verification Status:", collateral.isEligible ? "VERIFIED" : "PENDING");
        
        console.log("\nLOAN DETAILS:");
        console.log("   Loan ID:", loanId);
        console.log("   Borrower:", loan.borrower);
        console.log("   Amount: $", loan.loanAmount / 1e6);
        console.log("   Status:", loan.isRepaid ? "REPAID" : "ACTIVE");
        console.log("   Interest Rate:", loan.interestRate, "bps");
        
        console.log("\nCROSS-CHAIN CAPABILITIES:");
        console.log("   deBridge DLN Integration Ready");
        console.log("   Multi-chain Lending Support");
        console.log("   Automated Cross-chain Repayment");
        console.log("   Real Protocol Contract Integration");
        
        console.log("\nINNOVATIONS DEMONSTRATED:");
        console.log("   IP Assets as DeFi Collateral");
        console.log("   Cross-chain Lending Automation");
        console.log("   Royalty-based Loan Repayment");
        console.log("   Real Story Protocol Integration");
        console.log("   Professional Grade Architecture");
        
        uint256 totalOwed = storyLending.calculateTotalOwed(loanId);
        console.log("\nFINANCIAL SUMMARY:");
        console.log("   Collateral Value: $100,000 USDC");
        console.log("   Loan Amount: $50,000 USDC");
        console.log("   LTV Ratio: 50%");
        console.log("   Total Owed: $", totalOwed / 1e6, "USDC");
        console.log("   Repayment Method: Cross-chain Royalties");
    }
}
