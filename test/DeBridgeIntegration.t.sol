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
        USDC.mint(crossChainUser, 100000e6);

        _createTestLoan();
    }

    function test_createLoanWithCrossChainRepayment() public {
        uint256 borrowerChainId = 1; // Ethereum
        string memory yakoaTokenId = "test_contract:456";
        uint256 assessedValue = 100000e6;
        
        lendingProtocol.initiateYakoaVerification(ipAsset, yakoaTokenId, assessedValue);
        lendingProtocol.updateYakoaVerification(yakoaTokenId, true, 25);

        uint256 loanAmount = 50000e6;
        uint256 duration = 365 days;

        vm.prank(alice);
        lendingProtocol.createLoan(ipAsset, loanAmount, duration, address(USDC), borrowerChainId);

        uint256 newLoanId = lendingProtocol.nextLoanId() - 1;
        IPCollateralLending.Loan memory loan = lendingProtocol.getLoan(newLoanId);
        
        assertEq(loan.borrower, alice);
        assertEq(loan.sourceChainId, borrowerChainId);
        assertTrue(loan.isActive);
    }

    function test_crossChainRepaymentFlow() public {
        uint256 sourceChainId = 1;
        address sourceToken = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        uint256 sourceAmount = 1000e6;
        bytes32 deBridgeOrderId = keccak256("test_order_123");

        vm.prank(alice);
        lendingProtocol.initiateCrossChainRepayment(
            testLoanId,
            sourceChainId,
            sourceToken,
            sourceAmount,
            deBridgeOrderId
        );

        IPCollateralLending.Loan memory loan = lendingProtocol.getLoan(testLoanId);
        assertEq(uint256(loan.status), uint256(IPCollateralLending.LoanStatus.CROSS_CHAIN_REPAYMENT_PENDING));

        IPCollateralLending.CrossChainRepayment memory repayment = lendingProtocol.getCrossChainRepayment(deBridgeOrderId);
        assertEq(repayment.loanId, testLoanId);
        assertEq(repayment.sourceChainId, sourceChainId);
        assertFalse(repayment.isCompleted);

        uint256 totalOwed = lendingProtocol.calculateTotalOwed(testLoanId);
        lendingProtocol.processCrossChainRepayment(testLoanId, totalOwed, deBridgeOrderId);

        loan = lendingProtocol.getLoan(testLoanId);
        assertFalse(loan.isActive);
        assertTrue(loan.isRepaid);
        assertEq(uint256(loan.status), uint256(IPCollateralLending.LoanStatus.REPAID));

        repayment = lendingProtocol.getCrossChainRepayment(deBridgeOrderId);
        assertTrue(repayment.isCompleted);
    }

    function test_crossChainLiquidityWithTracking() public {
        uint256 amount = 10000e6;
        uint256 sourceChain = 1;
        bytes32 deBridgeOrderId = keccak256("liquidity_order_123");

        lendingProtocol.addCrossChainLiquidity(
            address(USDC),
            amount,
            sourceChain,
            deBridgeOrderId
        );

        assertTrue(true);
    }

    function _createTestLoan() internal {
        string memory yakoaTokenId = "test_contract:123";
        uint256 assessedValue = 100000e6;
        
        lendingProtocol.initiateYakoaVerification(ipAsset, yakoaTokenId, assessedValue);
        lendingProtocol.updateYakoaVerification(yakoaTokenId, true, 20);

        uint256 loanAmount = 50000e6;
        uint256 duration = 365 days;
        uint256 borrowerChainId = 1315;

        vm.prank(alice);
        lendingProtocol.createLoan(ipAsset, loanAmount, duration, address(USDC), borrowerChainId);
        
        testLoanId = lendingProtocol.nextLoanId() - 1;
    }
}
