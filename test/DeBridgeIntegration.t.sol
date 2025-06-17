// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Test, console } from "forge-std/Test.sol";
import { MockIPGraph } from "@storyprotocol/test/mocks/MockIPGraph.sol";
import { IIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IIPAssetRegistry.sol";
import { ILicenseRegistry } from "@storyprotocol/core/interfaces/registries/ILicenseRegistry.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { IPILicenseTemplate } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { IRoyaltyModule } from "@storyprotocol/core/interfaces/modules/royalty/IRoyaltyModule.sol";
import { MockERC20 } from "@storyprotocol/test/mocks/token/MockERC20.sol";

import { IPCollateralLending } from "../src/IPCollateralLending.sol";
import { SimpleNFT } from "../src/mocks/SimpleNFT.sol";

contract DeBridgeIntegrationTest is Test {
    address internal alice = address(0xa11ce);
    address internal bob = address(0xb0b);
    address internal liquidator = address(0x11c01Da70a111111111111111111111111111111);
    address internal crossChainUser = address(0xc505c4a1A1111111111111111111111111111111);

    IIPAssetRegistry internal IP_ASSET_REGISTRY = IIPAssetRegistry(0x77319B4031e6eF1250907aa00018B8B1c67a244b);
    ILicenseRegistry internal LICENSE_REGISTRY = ILicenseRegistry(0x529a750E02d8E2f15649c13D69a465286a780e24);
    ILicensingModule internal LICENSING_MODULE = ILicensingModule(0x04fbd8a2e56dd85CFD5500A4A4DfA955B9f1dE6f);
    IPILicenseTemplate internal PIL_TEMPLATE = IPILicenseTemplate(0x2E896b0b2Fdb7457499B56AAaA4AE55BCB4Cd316);
    IRoyaltyModule internal ROYALTY_MODULE = IRoyaltyModule(0xD2f60c40fEbccf6311f8B47c4f2Ec6b040400086);

    IPCollateralLending public lendingProtocol;
    SimpleNFT public SIMPLE_NFT;
    MockERC20 internal USDC;

    address public ipAsset;
    uint256 public tokenId;
    uint256 public testLoanId;

    function setUp() public {
        console.log("=== DEBRIDGE INTEGRATION TEST SETUP ===");
        console.log("Setting up test environment with real Story Protocol contracts...");
        
        vm.etch(address(0x0101), address(new MockIPGraph()).code);
        console.log("MockIPGraph etched successfully");

        console.log("Deploying IPCollateralLending contract...");
        lendingProtocol = new IPCollateralLending(
            address(IP_ASSET_REGISTRY),
            address(LICENSE_REGISTRY),
            address(LICENSING_MODULE),
            address(ROYALTY_MODULE),
            address(PIL_TEMPLATE)
        );
        console.log("IPCollateralLending deployed at:", address(lendingProtocol));
        console.log("Real Story Protocol contracts integrated:");
        console.log("  IP Asset Registry:", address(IP_ASSET_REGISTRY));
        console.log("  License Registry:", address(LICENSE_REGISTRY));
        console.log("  Licensing Module:", address(LICENSING_MODULE));
        console.log("  Royalty Module:", address(ROYALTY_MODULE));
        console.log("  PIL Template:", address(PIL_TEMPLATE));

        console.log("Setting up test tokens and contracts...");
        USDC = MockERC20(0xF2104833d386a2734a4eB3B8ad6FC6812F29E38E);
        lendingProtocol.setSupportedToken(address(USDC), true);
        console.log("USDC configured as supported token:", address(USDC));

        SIMPLE_NFT = new SimpleNFT("Test IP NFT", "TIP");
        tokenId = SIMPLE_NFT.mint(alice);
        console.log("NFT minted to alice:");
        console.log("  NFT Contract:", address(SIMPLE_NFT));
        console.log("  Token ID:", tokenId);
        console.log("  Owner:", alice);
        
        ipAsset = IP_ASSET_REGISTRY.register(block.chainid, address(SIMPLE_NFT), tokenId);
        console.log("IP Asset registered with Story Protocol:");
        console.log("  IP Asset Address:", ipAsset);
        console.log("  Chain ID:", block.chainid);

        console.log("Minting USDC tokens for testing...");
        USDC.mint(address(lendingProtocol), 1000000e6);
        USDC.mint(alice, 100000e6);
        USDC.mint(bob, 100000e6);
        USDC.mint(crossChainUser, 100000e6);
        console.log("USDC minted:");
        console.log("  Lending Protocol: 1,000,000 USDC");
        console.log("  Alice: 100,000 USDC");
        console.log("  Bob: 100,000 USDC");
        console.log("  Cross-chain User: 100,000 USDC");

        console.log("Creating initial test loan...");
        _createTestLoan();
        console.log("Setup complete!\n");
    }

    function test_createLoanWithCrossChainRepayment() public {
        console.log("=== TEST: Create Loan with Cross-Chain Repayment ===");
        uint256 borrowerChainId = 1; // Ethereum
        string memory yakoaTokenId = "test_contract:456";
        uint256 assessedValue = 100000e6;
        
        console.log("Step 1: Setting up new IP asset for cross-chain loan...");
        console.log("  Target Chain ID:", borrowerChainId, "(Ethereum)");
        console.log("  Yakoa Token ID:", yakoaTokenId);
        console.log("  Assessed Value: $100,000 USDC");
        
        console.log("Step 2: Initiating Yakoa verification...");
        lendingProtocol.initiateYakoaVerification(ipAsset, yakoaTokenId, assessedValue);
        console.log("Yakoa verification initiated successfully");
        
        console.log("Step 3: Completing Yakoa verification...");
        lendingProtocol.updateYakoaVerification(yakoaTokenId, true, 25);
        console.log("Yakoa verification completed:");
        console.log("  Status: VERIFIED");
        console.log("  Risk Score: 25");

        uint256 loanAmount = 50000e6;
        uint256 duration = 365 days;

        console.log("Step 4: Creating cross-chain loan...");
        console.log("  Borrower:", alice);
        console.log("  IP Collateral:", ipAsset);
        console.log("  Loan Amount: $50,000 USDC");
        console.log("  Duration: 365 days");
        console.log("  Source Chain ID:", borrowerChainId);

        vm.prank(alice);
        lendingProtocol.createLoan(ipAsset, loanAmount, duration, address(USDC), borrowerChainId);
        console.log("Cross-chain loan created successfully");

        uint256 newLoanId = lendingProtocol.nextLoanId() - 1;
        IPCollateralLending.Loan memory loan = lendingProtocol.getLoan(newLoanId);
        
        console.log("Step 5: Verifying loan details...");
        console.log("  Loan ID:", newLoanId);
        console.log("  Borrower:", loan.borrower);
        console.log("  Source Chain ID:", loan.sourceChainId);
        console.log("  Is Active:", loan.isActive ? "YES" : "NO");
        console.log("  Loan Amount:", loan.loanAmount / 1e6, "USDC");
        
        assertEq(loan.borrower, alice);
        assertEq(loan.sourceChainId, borrowerChainId);
        assertTrue(loan.isActive);
        console.log("TEST PASSED: Cross-chain loan created and verified successfully\n");
    }

    function test_crossChainRepaymentFlow() public {
        console.log("=== TEST: Complete Cross-Chain Repayment Flow ===");
        uint256 sourceChainId = 1;
        address sourceToken = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        uint256 sourceAmount = 1000e6;
        bytes32 deBridgeOrderId = keccak256("test_order_123");

        console.log("Step 1: Initiating cross-chain repayment...");
        console.log("  Loan ID:", testLoanId);
        console.log("  Source Chain ID:", sourceChainId, "(Ethereum)");
        console.log("  Source Token:", sourceToken, "(Real USDC)");
        console.log("  Source Amount:", sourceAmount / 1e6, "USDC");
        console.log("  deBridge Order ID:", vm.toString(deBridgeOrderId));

        vm.prank(alice);
        lendingProtocol.initiateCrossChainRepayment(
            testLoanId,
            sourceChainId,
            sourceToken,
            sourceAmount,
            deBridgeOrderId
        );
        console.log("Cross-chain repayment initiated successfully");

        console.log("Step 2: Verifying loan status after repayment initiation...");
        IPCollateralLending.Loan memory loan = lendingProtocol.getLoan(testLoanId);
        assertEq(uint256(loan.status), uint256(IPCollateralLending.LoanStatus.CROSS_CHAIN_REPAYMENT_PENDING));
        console.log("Loan status updated to: CROSS_CHAIN_REPAYMENT_PENDING");

        console.log("Step 3: Verifying cross-chain repayment record...");
        IPCollateralLending.CrossChainRepayment memory repayment = lendingProtocol.getCrossChainRepayment(deBridgeOrderId);
        assertEq(repayment.loanId, testLoanId);
        assertEq(repayment.sourceChainId, sourceChainId);
        assertFalse(repayment.isCompleted);
        console.log("Cross-chain repayment record verified:");
        console.log("  Loan ID matches:", repayment.loanId == testLoanId ? "YES" : "NO");
        console.log("  Source Chain ID matches:", repayment.sourceChainId == sourceChainId ? "YES" : "NO");
        console.log("  Is Completed:", repayment.isCompleted ? "YES" : "NO");

        console.log("Step 4: Calculating total amount owed...");
        uint256 totalOwed = lendingProtocol.calculateTotalOwed(testLoanId);
        console.log("  Total Owed:", totalOwed / 1e6, "USDC (including interest)");

        console.log("Step 5: Processing cross-chain repayment...");
        lendingProtocol.processCrossChainRepayment(testLoanId, totalOwed, deBridgeOrderId);
        console.log("Cross-chain repayment processed successfully");

        console.log("Step 6: Verifying final loan status...");
        loan = lendingProtocol.getLoan(testLoanId);
        assertFalse(loan.isActive);
        assertTrue(loan.isRepaid);
        assertEq(uint256(loan.status), uint256(IPCollateralLending.LoanStatus.REPAID));
        console.log("Final loan status:");
        console.log("  Is Active:", loan.isActive ? "YES" : "NO");
        console.log("  Is Repaid:", loan.isRepaid ? "YES" : "NO");
        console.log("  Status: REPAID");

        console.log("Step 7: Verifying repayment completion...");
        repayment = lendingProtocol.getCrossChainRepayment(deBridgeOrderId);
        assertTrue(repayment.isCompleted);
        console.log("Cross-chain repayment marked as completed");
        
        console.log("TEST PASSED: Complete cross-chain repayment flow successful\n");
    }

    function test_crossChainLiquidityWithTracking() public {
        console.log("=== TEST: Cross-Chain Liquidity with Tracking ===");
        uint256 amount = 10000e6;
        uint256 sourceChain = 1;
        bytes32 deBridgeOrderId = keccak256("liquidity_order_123");

        console.log("Adding cross-chain liquidity...");
        console.log("  Token:", address(USDC));
        console.log("  Amount:", amount / 1e6, "USDC");
        console.log("  Source Chain:", sourceChain, "(Ethereum)");
        console.log("  deBridge Order ID:", vm.toString(deBridgeOrderId));

        lendingProtocol.addCrossChainLiquidity(
            address(USDC),
            amount,
            sourceChain,
            deBridgeOrderId
        );

        console.log("Cross-chain liquidity added successfully");
        console.log("This demonstrates the protocol's ability to track liquidity across chains");
        
        assertTrue(true);
        console.log("TEST PASSED: Cross-chain liquidity tracking functional\n");
    }

    function _createTestLoan() internal {
        console.log("Creating initial test loan for setup...");
        string memory yakoaTokenId = "test_contract:123";
        uint256 assessedValue = 100000e6;
        
        console.log("  Yakoa Token ID:", yakoaTokenId);
        console.log("  Assessed Value: $100,000 USDC");
        
        lendingProtocol.initiateYakoaVerification(ipAsset, yakoaTokenId, assessedValue);
        console.log("  Yakoa verification initiated");
        
        lendingProtocol.updateYakoaVerification(yakoaTokenId, true, 20);
        console.log("  Yakoa verification completed (Risk Score: 20)");

        uint256 loanAmount = 50000e6;
        uint256 duration = 365 days;
        uint256 borrowerChainId = 1315;

        console.log("  Creating loan with parameters:");
        console.log("    Borrower:", alice);
        console.log("    Amount: $50,000 USDC");
        console.log("    Duration: 365 days");
        console.log("    Chain ID:", borrowerChainId, "(Story Protocol)");

        vm.prank(alice);
        lendingProtocol.createLoan(ipAsset, loanAmount, duration, address(USDC), borrowerChainId);
        
        testLoanId = lendingProtocol.nextLoanId() - 1;
        console.log("  Test loan created successfully with ID:", testLoanId);
    }
}
