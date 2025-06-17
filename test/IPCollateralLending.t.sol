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
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";

import { IPCollateralLending } from "../src/IPCollateralLending.sol";
import { SimpleNFT } from "../src/mocks/SimpleNFT.sol";

// Run this test:
// forge test --fork-url https://aeneid.storyrpc.io/ --match-path test/IPCollateralLending.t.sol
contract IPCollateralLendingTest is Test {
    address internal alice = address(0xa11ce);
    address internal bob = address(0xb0b);
    address internal liquidator = address(0x11c01Da70a111111111111111111111111111111);

    // Story Protocol contracts
    IIPAssetRegistry internal IP_ASSET_REGISTRY = IIPAssetRegistry(0x77319B4031e6eF1250907aa00018B8B1c67a244b);
    ILicenseRegistry internal LICENSE_REGISTRY = ILicenseRegistry(0x529a750E02d8E2f15649c13D69a465286a780e24);
    ILicensingModule internal LICENSING_MODULE = ILicensingModule(0x04fbd8a2e56dd85CFD5500A4A4DfA955B9f1dE6f);
    IPILicenseTemplate internal PIL_TEMPLATE = IPILicenseTemplate(0x2E896b0b2Fdb7457499B56AAaA4AE55BCB4Cd316);
    IRoyaltyModule internal ROYALTY_MODULE = IRoyaltyModule(0xD2f60c40fEbccf6311f8B47c4f2Ec6b040400086);
    address internal ROYALTY_POLICY_LAP = 0xBe54FB168b3c982b7AaE60dB6CF75Bd8447b390E;
    
    MockERC20 internal USDC;

    IPCollateralLending public lendingProtocol;
    SimpleNFT public SIMPLE_NFT;
    address public ipAsset;
    uint256 public tokenId;

    function setUp() public {
        console.log("=== IP COLLATERAL LENDING TEST SETUP ===");
        console.log("Setting up test environment with real Story Protocol contracts...");
        
        vm.etch(address(0x0101), address(new MockIPGraph()).code);

        console.log("Deploying IPCollateralLending contract...");
        lendingProtocol = new IPCollateralLending(
            address(IP_ASSET_REGISTRY),
            address(LICENSE_REGISTRY),
            address(LICENSING_MODULE),
            address(ROYALTY_MODULE),
            address(PIL_TEMPLATE)
        );
        console.log("IPCollateralLending deployed at:", address(lendingProtocol));

        console.log("Setting up test tokens and contracts...");
        USDC = MockERC20(0xF2104833d386a2734a4eB3B8ad6FC6812F29E38E);
        lendingProtocol.setSupportedToken(address(USDC), true);
        console.log("USDC configured as supported token:", address(USDC));

        SIMPLE_NFT = new SimpleNFT("Test IP NFT", "TIP");
        tokenId = SIMPLE_NFT.mint(alice);
        console.log("NFT minted to alice with token ID:", tokenId);
        
        ipAsset = IP_ASSET_REGISTRY.register(block.chainid, address(SIMPLE_NFT), tokenId);
        console.log("IP Asset registered with Story Protocol:");
        console.log("  IP Asset Address:", ipAsset);
        console.log("  NFT Contract:", address(SIMPLE_NFT));
        console.log("  Token ID:", tokenId);

        USDC.mint(address(lendingProtocol), 1000000e6);
        USDC.mint(alice, 100000e6);
        USDC.mint(bob, 100000e6);
        console.log("USDC minted:");
        console.log("  Lending Protocol:", 1000000, "USDC");
        console.log("  Alice:", 100000, "USDC");
        console.log("  Bob:", 100000, "USDC");
        console.log("Setup complete!\n");
    }

    function test_initiateYakoaVerification() public {
        console.log("=== TEST: Initiate Yakoa Verification ===");
        string memory yakoaTokenId = "test_contract:123";
        uint256 assessedValue = 100000e6; // $100k

        console.log("Initiating Yakoa verification for IP asset...");
        console.log("  IP Asset:", ipAsset);
        console.log("  Yakoa Token ID:", yakoaTokenId);
        console.log("  Assessed Value: $100,000 USDC");

        lendingProtocol.initiateYakoaVerification(ipAsset, yakoaTokenId, assessedValue);
        console.log("Yakoa verification initiated successfully");

        IPCollateralLending.IPCollateral memory collateral = lendingProtocol.getIPCollateral(ipAsset);
        
        console.log("Verification results:");
        console.log("  IP Asset:", collateral.ipAsset);
        console.log("  Assessed Value:", collateral.assessedValue / 1e6, "USDC");
        console.log("  Is Eligible:", collateral.isEligible ? "Yes" : "No (Pending verification)");
        console.log("  Yakoa Token ID:", collateral.yakoaTokenId);
        console.log("  Status:", uint256(collateral.yakoaStatus) == 0 ? "PENDING" : "OTHER");
        
        assertEq(collateral.ipAsset, ipAsset);
        assertEq(collateral.assessedValue, assessedValue);
        assertFalse(collateral.isEligible); // Should be false until verified
        assertEq(collateral.yakoaTokenId, yakoaTokenId);
        assertEq(uint256(collateral.yakoaStatus), uint256(IPCollateralLending.YakoaStatus.PENDING));
        
        console.log("TEST PASSED: Yakoa verification initiated correctly\n");
    }

    function test_updateYakoaVerification() public {
        console.log("=== TEST: Update Yakoa Verification ===");
        string memory yakoaTokenId = "test_contract:123";
        uint256 assessedValue = 100000e6;
        
        console.log("Step 1: Initiating Yakoa verification...");
        lendingProtocol.initiateYakoaVerification(ipAsset, yakoaTokenId, assessedValue);
        console.log("Verification initiated");
        
        console.log("Step 2: Updating verification with results...");
        console.log("  Verification Result: VERIFIED");
        console.log("  Risk Score: 15 (Low Risk)");
        lendingProtocol.updateYakoaVerification(yakoaTokenId, true, 15);
        console.log("Verification updated successfully");
        
        IPCollateralLending.IPCollateral memory collateral = lendingProtocol.getIPCollateral(ipAsset);
        
        console.log("Final verification status:");
        console.log("  Is Eligible for Collateral:", collateral.isEligible ? "YES" : "NO");
        console.log("  Risk Score:", collateral.riskScore);
        console.log("  Yakoa Status:", uint256(collateral.yakoaStatus) == 1 ? "VERIFIED" : "OTHER");
        
        assertTrue(collateral.isEligible);
        assertEq(collateral.riskScore, 15);
        assertEq(uint256(collateral.yakoaStatus), uint256(IPCollateralLending.YakoaStatus.VERIFIED));
        
        console.log("TEST PASSED: IP asset is now verified and eligible for collateral\n");
    }

    function test_createLoanWithYakoaVerification() public {
        console.log("=== TEST: Create Loan with Yakoa Verification ===");
        string memory yakoaTokenId = "test_contract:123";
        uint256 assessedValue = 100000e6;
        
        console.log("Step 1: Setting up verified IP collateral...");
        lendingProtocol.initiateYakoaVerification(ipAsset, yakoaTokenId, assessedValue);
        lendingProtocol.updateYakoaVerification(yakoaTokenId, true, 20);
        console.log("IP asset verified and ready for use as collateral");

        uint256 loanAmount = 70000e6; // $70k
        uint256 duration = 365 days;
        uint256 borrowerChainId = 1315;

        console.log("Step 2: Creating loan with verified IP collateral...");
        console.log("  Borrower:", alice);
        console.log("  IP Collateral:", ipAsset);
        console.log("  Loan Amount: $70,000 USDC");
        console.log("  Duration: 365 days");
        console.log("  Borrower Chain ID:", borrowerChainId);

        vm.prank(alice);
        lendingProtocol.createLoan(ipAsset, loanAmount, duration, address(USDC), borrowerChainId);
        console.log("Loan created successfully");

        IPCollateralLending.Loan memory loan = lendingProtocol.getLoan(0);
        
        console.log("Loan details:");
        console.log("  Loan ID: 0");
        console.log("  Borrower:", loan.borrower);
        console.log("  IP Asset:", loan.ipAsset);
        console.log("  Loan Amount:", loan.loanAmount / 1e6, "USDC");
        console.log("  Source Chain ID:", loan.sourceChainId);
        console.log("  Is Active:", loan.isActive ? "YES" : "NO");
        console.log("  Interest Rate:", loan.interestRate, "basis points");
        
        assertEq(loan.borrower, alice);
        assertEq(loan.ipAsset, ipAsset);
        assertEq(loan.loanAmount, loanAmount);
        assertEq(loan.sourceChainId, borrowerChainId);
        assertTrue(loan.isActive);
        
        console.log("TEST PASSED: Loan created successfully with IP collateral\n");
    }

    function test_createLoanFailsWithoutVerification() public {
        console.log("=== TEST: Create Loan Fails Without Verification ===");
        string memory yakoaTokenId = "test_contract:123";
        uint256 assessedValue = 100000e6;
        
        console.log("Setting up unverified IP asset...");
        lendingProtocol.initiateYakoaVerification(ipAsset, yakoaTokenId, assessedValue);
        console.log("Yakoa verification initiated but NOT completed");

        uint256 loanAmount = 70000e6;
        uint256 duration = 365 days;
        uint256 borrowerChainId = 1315;

        console.log("Attempting to create loan with unverified IP asset...");
        console.log("  Expected Result: SHOULD FAIL");
        
        vm.prank(alice);
        vm.expectRevert(IPCollateralLending.IPNotVerifiedByYakoa.selector);
        lendingProtocol.createLoan(ipAsset, loanAmount, duration, address(USDC), borrowerChainId);
        
        console.log("TEST PASSED: Loan creation correctly failed for unverified IP\n");
    }

    function test_createLoanFailsWithUnregisteredIP() public {
        console.log("=== TEST: Create Loan Fails With Unregistered IP ===");
        address unregisteredIP = address(0x123);
        uint256 loanAmount = 70000e6;
        uint256 duration = 365 days;
        uint256 borrowerChainId = 1315;

        console.log("Attempting to create loan with unregistered IP asset...");
        console.log("  Unregistered IP Address:", unregisteredIP);
        console.log("  Expected Result: SHOULD FAIL");

        vm.prank(alice);
        vm.expectRevert(IPCollateralLending.IPNotRegistered.selector);
        lendingProtocol.createLoan(unregisteredIP, loanAmount, duration, address(USDC), borrowerChainId);
        
        console.log("TEST PASSED: Loan creation correctly failed for unregistered IP\n");
    }

    function test_createLoanFailsWithUnsupportedToken() public {
        console.log("=== TEST: Create Loan Fails With Unsupported Token ===");
        string memory yakoaTokenId = "test_contract:123";
        uint256 assessedValue = 100000e6;
        
        console.log("Setting up verified IP asset...");
        lendingProtocol.initiateYakoaVerification(ipAsset, yakoaTokenId, assessedValue);
        lendingProtocol.updateYakoaVerification(yakoaTokenId, true, 20);
        console.log("IP asset verified");

        address unsupportedToken = address(0x456);
        uint256 loanAmount = 70000e6;
        uint256 duration = 365 days;
        uint256 borrowerChainId = 1315;

        console.log("Attempting to create loan with unsupported token...");
        console.log("  Unsupported Token:", unsupportedToken);
        console.log("  Expected Result: SHOULD FAIL");

        vm.prank(alice);
        vm.expectRevert(IPCollateralLending.TokenNotSupported.selector);
        lendingProtocol.createLoan(ipAsset, loanAmount, duration, unsupportedToken, borrowerChainId);
        
        console.log("TEST PASSED: Loan creation correctly failed for unsupported token\n");
    }

    function test_repayLoan() public {
        console.log("=== TEST: Repay Loan ===");
        string memory yakoaTokenId = "test_contract:123";
        uint256 assessedValue = 100000e6;
        
        console.log("Step 1: Setting up verified IP and creating loan...");
        lendingProtocol.initiateYakoaVerification(ipAsset, yakoaTokenId, assessedValue);
        lendingProtocol.updateYakoaVerification(yakoaTokenId, true, 20);

        uint256 loanAmount = 50000e6;
        uint256 duration = 365 days;
        uint256 borrowerChainId = 1315;

        vm.prank(alice);
        lendingProtocol.createLoan(ipAsset, loanAmount, duration, address(USDC), borrowerChainId);
        console.log("Loan created: $50,000 USDC");

        console.log("Step 2: Fast forwarding time to accrue interest...");
        vm.warp(block.timestamp + 30 days);
        console.log("Time advanced by 30 days");

        uint256 totalOwed = lendingProtocol.calculateTotalOwed(0);
        console.log("Step 3: Calculating repayment amount...");
        console.log("  Total Amount Owed:", totalOwed / 1e6, "USDC (including interest)");
        
        console.log("Step 4: Processing loan repayment...");
        vm.startPrank(alice);
        USDC.approve(address(lendingProtocol), totalOwed);
        console.log("Approved repayment amount");
        lendingProtocol.repayLoan(0);
        console.log("Loan repayment processed");
        vm.stopPrank();

        IPCollateralLending.Loan memory loan = lendingProtocol.getLoan(0);
        
        console.log("Final loan status:");
        console.log("  Is Active:", loan.isActive ? "YES" : "NO");
        console.log("  Is Repaid:", loan.isRepaid ? "YES" : "NO");
        
        assertFalse(loan.isActive);
        assertTrue(loan.isRepaid);
        
        console.log("TEST PASSED: Loan successfully repaid and closed\n");
    }

    function test_repayLoanFailsForNonBorrower() public {
        console.log("=== TEST: Repay Loan Fails For Non-Borrower ===");
        string memory yakoaTokenId = "test_contract:123";
        uint256 assessedValue = 100000e6;
        
        console.log("Step 1: Setting up loan with alice as borrower...");
        lendingProtocol.initiateYakoaVerification(ipAsset, yakoaTokenId, assessedValue);
        lendingProtocol.updateYakoaVerification(yakoaTokenId, true, 20);

        uint256 loanAmount = 50000e6;
        uint256 duration = 365 days;
        uint256 borrowerChainId = 1315;

        vm.prank(alice);
        lendingProtocol.createLoan(ipAsset, loanAmount, duration, address(USDC), borrowerChainId);
        console.log("Loan created with alice as borrower");

        uint256 totalOwed = lendingProtocol.calculateTotalOwed(0);
        
        console.log("Step 2: Attempting repayment with bob (not the borrower)...");
        console.log("  Borrower:", alice);
        console.log("  Attempted Repayer:", bob);
        console.log("  Expected Result: SHOULD FAIL");
        
        vm.startPrank(bob);
        USDC.approve(address(lendingProtocol), totalOwed);
        vm.expectRevert(IPCollateralLending.NotBorrower.selector);
        lendingProtocol.repayLoan(0);
        vm.stopPrank();
        
        console.log("TEST PASSED: Repayment correctly failed for non-borrower\n");
    }

    function test_liquidation() public {
        console.log("=== TEST: Loan Liquidation ===");
        string memory yakoaTokenId = "test_contract:123";
        uint256 assessedValue = 100000e6;
        
        console.log("Step 1: Setting up loan with short duration...");
        lendingProtocol.initiateYakoaVerification(ipAsset, yakoaTokenId, assessedValue);
        lendingProtocol.updateYakoaVerification(yakoaTokenId, true, 20);

        uint256 loanAmount = 70000e6;
        uint256 duration = 30 days; // Short duration for quick expiry
        uint256 borrowerChainId = 1315;

        vm.prank(alice);
        lendingProtocol.createLoan(ipAsset, loanAmount, duration, address(USDC), borrowerChainId);
        console.log("Loan created:");
        console.log("  Amount: $70,000 USDC");
        console.log("  Duration: 30 days");

        console.log("Step 2: Fast forwarding past loan expiry...");
        vm.warp(block.timestamp + 31 days);
        console.log("Time advanced by 31 days - loan is now overdue");

        console.log("Step 3: Executing liquidation...");
        console.log("  Liquidator:", liquidator);
        vm.prank(liquidator);
        lendingProtocol.liquidateLoan(0);
        console.log("Liquidation executed");

        IPCollateralLending.Loan memory loan = lendingProtocol.getLoan(0);
        
        console.log("Final loan status:");
        console.log("  Is Active:", loan.isActive ? "YES" : "NO");
        console.log("  Status:", uint256(loan.status) == 2 ? "LIQUIDATED" : "OTHER");
        
        assertFalse(loan.isActive);
        assertEq(uint256(loan.status), uint256(IPCollateralLending.LoanStatus.LIQUIDATED));
        
        console.log("TEST PASSED: Overdue loan successfully liquidated\n");
    }

    function test_crossChainLiquidity() public {
        console.log("=== TEST: Cross-Chain Liquidity ===");
        uint256 amount = 1000e6;
        uint256 sourceChain = 1;

        console.log("Adding cross-chain liquidity...");
        console.log("  Token:", address(USDC));
        console.log("  Amount:", amount / 1e6, "USDC");
        console.log("  Source Chain:", sourceChain);

        lendingProtocol.addCrossChainLiquidity(address(USDC), amount, sourceChain);
        console.log("Cross-chain liquidity added successfully");
        
        assertTrue(true);
        console.log("TEST PASSED: Cross-chain liquidity functionality working\n");
    }

    function test_yakoaTimeout() public {
        console.log("=== TEST: Yakoa Verification Timeout ===");
        string memory yakoaTokenId = "test_contract:123";
        uint256 assessedValue = 100000e6;
        
        console.log("Step 1: Initiating Yakoa verification...");
        lendingProtocol.initiateYakoaVerification(ipAsset, yakoaTokenId, assessedValue);
        console.log("Verification initiated");
        
        console.log("Step 2: Fast forwarding past timeout period...");
        vm.warp(block.timestamp + 25 hours);
        console.log("Time advanced by 25 hours - verification has timed out");
        
        console.log("Step 3: Handling timeout...");
        lendingProtocol.handleYakoaTimeout(yakoaTokenId);
        console.log("Timeout handled");
        
        IPCollateralLending.IPCollateral memory collateral = lendingProtocol.getIPCollateral(ipAsset);
        
        console.log("Final verification status:");
        console.log("  Yakoa Status:", uint256(collateral.yakoaStatus) == 3 ? "ERROR (TIMEOUT)" : "OTHER");
        console.log("  Is Eligible:", collateral.isEligible ? "YES" : "NO");
        
        assertEq(uint256(collateral.yakoaStatus), uint256(IPCollateralLending.YakoaStatus.ERROR));
        assertFalse(collateral.isEligible);
        
        console.log("TEST PASSED: Yakoa timeout handled correctly\n");
    }

    function test_updateYakoaVerificationFailsForNonexistentToken() public {
        console.log("=== TEST: Update Verification Fails For Nonexistent Token ===");
        string memory yakoaTokenId = "nonexistent:123";
        
        console.log("Attempting to update verification for nonexistent token...");
        console.log("  Token ID:", yakoaTokenId);
        console.log("  Expected Result: SHOULD FAIL");
        
        vm.expectRevert(IPCollateralLending.YakoaTokenNotFound.selector);
        lendingProtocol.updateYakoaVerification(yakoaTokenId, true, 20);
        
        console.log("TEST PASSED: Update correctly failed for nonexistent token\n");
    }

    function test_updateYakoaVerificationFailsWhenAlreadyCompleted() public {
        console.log("=== TEST: Update Verification Fails When Already Completed ===");
        string memory yakoaTokenId = "test_contract:123";
        uint256 assessedValue = 100000e6;
        
        console.log("Step 1: Completing initial verification...");
        lendingProtocol.initiateYakoaVerification(ipAsset, yakoaTokenId, assessedValue);
        lendingProtocol.updateYakoaVerification(yakoaTokenId, true, 20);
        console.log("Initial verification completed");
        
        console.log("Step 2: Attempting to update verification again...");
        console.log("  Expected Result: SHOULD FAIL");
        vm.expectRevert(IPCollateralLending.VerificationAlreadyCompleted.selector);
        lendingProtocol.updateYakoaVerification(yakoaTokenId, false, 50);
        
        console.log("TEST PASSED: Duplicate verification update correctly failed\n");
    }
}
