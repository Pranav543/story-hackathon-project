// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
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
        vm.etch(address(0x0101), address(new MockIPGraph()).code);

        lendingProtocol = new IPCollateralLending(
            address(IP_ASSET_REGISTRY),
            address(LICENSE_REGISTRY),
            address(LICENSING_MODULE),
            address(ROYALTY_MODULE),
            address(PIL_TEMPLATE)
        );

        USDC = MockERC20(0xF2104833d386a2734a4eB3B8ad6FC6812F29E38E);
        lendingProtocol.setSupportedToken(address(USDC), true);

        SIMPLE_NFT = new SimpleNFT("Test IP NFT", "TIP");
        tokenId = SIMPLE_NFT.mint(alice);
        ipAsset = IP_ASSET_REGISTRY.register(block.chainid, address(SIMPLE_NFT), tokenId);

        USDC.mint(address(lendingProtocol), 1000000e6);
        USDC.mint(alice, 100000e6);
        USDC.mint(bob, 100000e6);
    }

    function test_initiateYakoaVerification() public {
        string memory yakoaTokenId = "test_contract:123";
        uint256 assessedValue = 100000e6; // $100k

        lendingProtocol.initiateYakoaVerification(ipAsset, yakoaTokenId, assessedValue);

        IPCollateralLending.IPCollateral memory collateral = lendingProtocol.getIPCollateral(ipAsset);
        
        assertEq(collateral.ipAsset, ipAsset);
        assertEq(collateral.assessedValue, assessedValue);
        assertFalse(collateral.isEligible); // Should be false until verified
        assertEq(collateral.yakoaTokenId, yakoaTokenId);
        assertEq(uint256(collateral.yakoaStatus), uint256(IPCollateralLending.YakoaStatus.PENDING));
    }

    function test_updateYakoaVerification() public {
        string memory yakoaTokenId = "test_contract:123";
        uint256 assessedValue = 100000e6;
        
        // First initiate verification
        lendingProtocol.initiateYakoaVerification(ipAsset, yakoaTokenId, assessedValue);
        
        // Then update with verification result
        lendingProtocol.updateYakoaVerification(yakoaTokenId, true, 15); // Verified with low risk
        
        IPCollateralLending.IPCollateral memory collateral = lendingProtocol.getIPCollateral(ipAsset);
        assertTrue(collateral.isEligible);
        assertEq(collateral.riskScore, 15);
        assertEq(uint256(collateral.yakoaStatus), uint256(IPCollateralLending.YakoaStatus.VERIFIED));
    }

    function test_createLoanWithYakoaVerification() public {
        string memory yakoaTokenId = "test_contract:123";
        uint256 assessedValue = 100000e6;
        
        // Initiate and complete verification
        lendingProtocol.initiateYakoaVerification(ipAsset, yakoaTokenId, assessedValue);
        lendingProtocol.updateYakoaVerification(yakoaTokenId, true, 20); // Verified

        uint256 loanAmount = 70000e6; // $70k
        uint256 duration = 365 days;
        uint256 borrowerChainId = 100000013;

        vm.prank(alice);
        lendingProtocol.createLoan(ipAsset, loanAmount, duration, address(USDC), borrowerChainId);

        IPCollateralLending.Loan memory loan = lendingProtocol.getLoan(0);
        assertEq(loan.borrower, alice);
        assertEq(loan.ipAsset, ipAsset);
        assertEq(loan.loanAmount, loanAmount);
        assertEq(loan.sourceChainId, borrowerChainId);
        assertTrue(loan.isActive);
    }

    function test_createLoanFailsWithoutVerification() public {
        string memory yakoaTokenId = "test_contract:123";
        uint256 assessedValue = 100000e6;
        
        // Only initiate verification, don't complete it
        lendingProtocol.initiateYakoaVerification(ipAsset, yakoaTokenId, assessedValue);

        uint256 loanAmount = 70000e6;
        uint256 duration = 365 days;
        uint256 borrowerChainId = 100000013;

        vm.prank(alice);
        // Now expect the custom error instead of string
        vm.expectRevert(IPCollateralLending.IPNotVerifiedByYakoa.selector);
        lendingProtocol.createLoan(ipAsset, loanAmount, duration, address(USDC), borrowerChainId);
    }

    function test_createLoanFailsWithUnregisteredIP() public {
        address unregisteredIP = address(0x123);
        uint256 loanAmount = 70000e6;
        uint256 duration = 365 days;
        uint256 borrowerChainId = 100000013;

        vm.prank(alice);
        vm.expectRevert(IPCollateralLending.IPNotRegistered.selector);
        lendingProtocol.createLoan(unregisteredIP, loanAmount, duration, address(USDC), borrowerChainId);
    }

    function test_createLoanFailsWithUnsupportedToken() public {
        string memory yakoaTokenId = "test_contract:123";
        uint256 assessedValue = 100000e6;
        
        lendingProtocol.initiateYakoaVerification(ipAsset, yakoaTokenId, assessedValue);
        lendingProtocol.updateYakoaVerification(yakoaTokenId, true, 20);

        address unsupportedToken = address(0x456);
        uint256 loanAmount = 70000e6;
        uint256 duration = 365 days;
        uint256 borrowerChainId = 100000013;

        vm.prank(alice);
        vm.expectRevert(IPCollateralLending.TokenNotSupported.selector);
        lendingProtocol.createLoan(ipAsset, loanAmount, duration, unsupportedToken, borrowerChainId);
    }

    function test_repayLoan() public {
        // Setup verified IP and loan
        string memory yakoaTokenId = "test_contract:123";
        uint256 assessedValue = 100000e6;
        
        lendingProtocol.initiateYakoaVerification(ipAsset, yakoaTokenId, assessedValue);
        lendingProtocol.updateYakoaVerification(yakoaTokenId, true, 20);

        uint256 loanAmount = 50000e6;
        uint256 duration = 365 days;
        uint256 borrowerChainId = 100000013;

        vm.prank(alice);
        lendingProtocol.createLoan(ipAsset, loanAmount, duration, address(USDC), borrowerChainId);

        vm.warp(block.timestamp + 30 days);

        uint256 totalOwed = lendingProtocol.calculateTotalOwed(0);
        
        vm.startPrank(alice);
        USDC.approve(address(lendingProtocol), totalOwed);
        lendingProtocol.repayLoan(0);
        vm.stopPrank();

        IPCollateralLending.Loan memory loan = lendingProtocol.getLoan(0);
        assertFalse(loan.isActive);
        assertTrue(loan.isRepaid);
    }

    function test_repayLoanFailsForNonBorrower() public {
        // Setup verified IP and loan
        string memory yakoaTokenId = "test_contract:123";
        uint256 assessedValue = 100000e6;
        
        lendingProtocol.initiateYakoaVerification(ipAsset, yakoaTokenId, assessedValue);
        lendingProtocol.updateYakoaVerification(yakoaTokenId, true, 20);

        uint256 loanAmount = 50000e6;
        uint256 duration = 365 days;
        uint256 borrowerChainId = 100000013;

        vm.prank(alice);
        lendingProtocol.createLoan(ipAsset, loanAmount, duration, address(USDC), borrowerChainId);

        uint256 totalOwed = lendingProtocol.calculateTotalOwed(0);
        
        vm.startPrank(bob); // Different user trying to repay
        USDC.approve(address(lendingProtocol), totalOwed);
        vm.expectRevert(IPCollateralLending.NotBorrower.selector);
        lendingProtocol.repayLoan(0);
        vm.stopPrank();
    }

    function test_liquidation() public {
        // Setup verified IP and loan
        string memory yakoaTokenId = "test_contract:123";
        uint256 assessedValue = 100000e6;
        
        lendingProtocol.initiateYakoaVerification(ipAsset, yakoaTokenId, assessedValue);
        lendingProtocol.updateYakoaVerification(yakoaTokenId, true, 20);

        uint256 loanAmount = 70000e6;
        uint256 duration = 30 days;
        uint256 borrowerChainId = 100000013;

        vm.prank(alice);
        lendingProtocol.createLoan(ipAsset, loanAmount, duration, address(USDC), borrowerChainId);

        vm.warp(block.timestamp + 31 days);

        vm.prank(liquidator);
        lendingProtocol.liquidateLoan(0);

        IPCollateralLending.Loan memory loan = lendingProtocol.getLoan(0);
        assertFalse(loan.isActive);
        assertEq(uint256(loan.status), uint256(IPCollateralLending.LoanStatus.LIQUIDATED));
    }

    function test_crossChainLiquidity() public {
        uint256 amount = 1000e6;
        uint256 sourceChain = 1;

        lendingProtocol.addCrossChainLiquidity(address(USDC), amount, sourceChain);
        assertTrue(true);
    }

    function test_yakoaTimeout() public {
        string memory yakoaTokenId = "test_contract:123";
        uint256 assessedValue = 100000e6;
        
        lendingProtocol.initiateYakoaVerification(ipAsset, yakoaTokenId, assessedValue);
        
        // Fast forward past timeout
        vm.warp(block.timestamp + 25 hours);
        
        lendingProtocol.handleYakoaTimeout(yakoaTokenId);
        
        IPCollateralLending.IPCollateral memory collateral = lendingProtocol.getIPCollateral(ipAsset);
        assertEq(uint256(collateral.yakoaStatus), uint256(IPCollateralLending.YakoaStatus.ERROR));
        assertFalse(collateral.isEligible);
    }

    function test_updateYakoaVerificationFailsForNonexistentToken() public {
        string memory yakoaTokenId = "nonexistent:123";
        
        vm.expectRevert(IPCollateralLending.YakoaTokenNotFound.selector);
        lendingProtocol.updateYakoaVerification(yakoaTokenId, true, 20);
    }

    function test_updateYakoaVerificationFailsWhenAlreadyCompleted() public {
        string memory yakoaTokenId = "test_contract:123";
        uint256 assessedValue = 100000e6;
        
        lendingProtocol.initiateYakoaVerification(ipAsset, yakoaTokenId, assessedValue);
        lendingProtocol.updateYakoaVerification(yakoaTokenId, true, 20);
        
        // Try to update again
        vm.expectRevert(IPCollateralLending.VerificationAlreadyCompleted.selector);
        lendingProtocol.updateYakoaVerification(yakoaTokenId, false, 50);
    }
}
