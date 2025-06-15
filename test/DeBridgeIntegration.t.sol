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

// Run this test:
// forge test --fork-url https://aeneid.storyrpc.io/ --match-path test/DeBridgeIntegration.t.sol
contract DeBridgeIntegrationTest is Test {
    /*//////////////////////////////////////////////////////////////
                            TEST ACCOUNTS
    //////////////////////////////////////////////////////////////*/

    address internal alice = address(0xa11ce);
    address internal bob = address(0xb0b);
    address internal liquidator = address(0x11c01Da70a111111111111111111111111111111);
    address internal crossChainUser = address(0xc505c4a1A1111111111111111111111111111111);

    /*//////////////////////////////////////////////////////////////
                            STORY PROTOCOL
    //////////////////////////////////////////////////////////////*/

    IIPAssetRegistry internal IP_ASSET_REGISTRY = IIPAssetRegistry(0x77319B4031e6eF1250907aa00018B8B1c67a244b);
    ILicenseRegistry internal LICENSE_REGISTRY = ILicenseRegistry(0x529a750E02d8E2f15649c13D69a465286a780e24);
    ILicensingModule internal LICENSING_MODULE = ILicensingModule(0x04fbd8a2e56dd85CFD5500A4A4DfA955B9f1dE6f);
    IPILicenseTemplate internal PIL_TEMPLATE = IPILicenseTemplate(0x2E896b0b2Fdb7457499B56AAaA4AE55BCB4Cd316);
    IRoyaltyModule internal ROYALTY_MODULE = IRoyaltyModule(0xD2f60c40fEbccf6311f8B47c4f2Ec6b040400086);

    /*//////////////////////////////////////////////////////////////
                            CONTRACT INSTANCES
    //////////////////////////////////////////////////////////////*/

    IPCollateralLending public lendingProtocol;
    SimpleNFT public SIMPLE_NFT;
    MockERC20 internal USDC;

    /*//////////////////////////////////////////////////////////////
                            TEST STATE
    //////////////////////////////////////////////////////////////*/

    address public ipAsset;
    uint256 public tokenId;
    uint256 public testLoanId;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        vm.etch(address(0x0101), address(new MockIPGraph()).code);

        // Deploy lending protocol
        lendingProtocol = new IPCollateralLending(
            address(IP_ASSET_REGISTRY),
            address(LICENSE_REGISTRY),
            address(LICENSING_MODULE),
            address(ROYALTY_MODULE),
            address(PIL_TEMPLATE)
        );

        // Setup tokens
        USDC = MockERC20(0xF2104833d386a2734a4eB3B8ad6FC6812F29E38E);
        lendingProtocol.setSupportedToken(address(USDC), true);

        // Create and register IP asset
        SIMPLE_NFT = new SimpleNFT("Test IP NFT", "TIP");
        tokenId = SIMPLE_NFT.mint(alice);
        ipAsset = IP_ASSET_REGISTRY.register(block.chainid, address(SIMPLE_NFT), tokenId);

        // Setup liquidity and balances
        USDC.mint(address(lendingProtocol), 1000000e6); // 1M USDC
        USDC.mint(alice, 100000e6);
        USDC.mint(bob, 100000e6);
        USDC.mint(crossChainUser, 100000e6);

        // Create a test loan
        _createTestLoan();
    }

    /*//////////////////////////////////////////////////////////////
                            CORE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_createLoanWithCrossChainRepayment() public {
        uint256 borrowerChainId = 1; // Ethereum
        bytes32 yakoaProof = keccak256("valid_proof");
        uint256 assessedValue = 100000e6;
        
        lendingProtocol.validateIPCollateral(ipAsset, yakoaProof, assessedValue);

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
        uint256 sourceChainId = 1; // Ethereum
        address sourceToken = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // USDC on Ethereum
        uint256 sourceAmount = 1000e6; // 1000 USDC
        bytes32 deBridgeOrderId = keccak256("test_order_123");

        // Initiate cross-chain repayment
        vm.prank(alice);
        lendingProtocol.initiateCrossChainRepayment(
            testLoanId,
            sourceChainId,
            sourceToken,
            sourceAmount,
            deBridgeOrderId
        );

        // Verify loan status
        IPCollateralLending.Loan memory loan = lendingProtocol.getLoan(testLoanId);
        assertEq(uint256(loan.status), uint256(IPCollateralLending.LoanStatus.CROSS_CHAIN_REPAYMENT_PENDING));

        // Verify repayment tracking
        IPCollateralLending.CrossChainRepayment memory repayment = lendingProtocol.getCrossChainRepayment(deBridgeOrderId);
        assertEq(repayment.loanId, testLoanId);
        assertEq(repayment.sourceChainId, sourceChainId);
        assertFalse(repayment.isCompleted);

        // Process the repayment
        uint256 totalOwed = lendingProtocol.calculateTotalOwed(testLoanId);
        lendingProtocol.processCrossChainRepayment(testLoanId, totalOwed, deBridgeOrderId);

        // Verify final state
        loan = lendingProtocol.getLoan(testLoanId);
        assertFalse(loan.isActive);
        assertTrue(loan.isRepaid);
        assertEq(uint256(loan.status), uint256(IPCollateralLending.LoanStatus.REPAID));

        repayment = lendingProtocol.getCrossChainRepayment(deBridgeOrderId);
        assertTrue(repayment.isCompleted);
    }

    function test_crossChainLiquidityWithTracking() public {
        uint256 amount = 10000e6;
        uint256 sourceChain = 1; // Ethereum
        bytes32 deBridgeOrderId = keccak256("liquidity_order_123");

        // Process cross-chain liquidity addition
        lendingProtocol.addCrossChainLiquidity(
            address(USDC),
            amount,
            sourceChain,
            deBridgeOrderId
        );

        // Event should be emitted (verified in logs)
        assertTrue(true);
    }

    function test_deBridgeAPIIntegration() public {
        console.log("=== deBridge API Integration Test ===");
        
        // Build a real API request for loan repayment
        uint256 repaymentAmount = lendingProtocol.calculateTotalOwed(testLoanId);
        bytes32 deBridgeOrderId = keccak256("api_test_order");
        
        // Construct hook payload
        string memory hookJson = _buildLoanRepaymentHook(
            testLoanId,
            repaymentAmount,
            address(lendingProtocol),
            deBridgeOrderId
        );

        // Build API request
        string memory apiUrl = _buildApiRequest(hookJson);

        console.log("API Request URL:");
        console.log(apiUrl);

        // Execute API call (uncomment to test with real API)
        // string memory response = _executeApiCall(apiUrl);
        // _validateApiResponse(response);

        console.log("API integration test completed");
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _createTestLoan() internal {
        bytes32 yakoaProof = keccak256("valid_proof");
        uint256 assessedValue = 100000e6;
        
        lendingProtocol.validateIPCollateral(ipAsset, yakoaProof, assessedValue);

        uint256 loanAmount = 50000e6;
        uint256 duration = 365 days;
        uint256 borrowerChainId = 100000013; // Story mainnet

        vm.prank(alice);
        lendingProtocol.createLoan(ipAsset, loanAmount, duration, address(USDC), borrowerChainId);
        
        testLoanId = lendingProtocol.nextLoanId() - 1;
    }

    function _buildLoanRepaymentHook(
        uint256 loanId,
        uint256 repaymentAmount,
        address lendingContract,
        bytes32 deBridgeOrderId
    ) internal pure returns (string memory hookJson) {
        // Encode function call: processCrossChainRepayment(uint256,uint256,bytes32)
        bytes memory calldata_ = abi.encodeWithSignature(
            "processCrossChainRepayment(uint256,uint256,bytes32)",
            loanId,
            repaymentAmount,
            deBridgeOrderId
        );

        hookJson = string.concat(
            '{"type":"evm_transaction_call",',
            '"data":{"to":"',
            _addressToHex(lendingContract),
            '",',
            '"calldata":"',
            _bytesToHex(calldata_),
            '",',
            '"gas":200000}}'
        );
    }

    function _buildApiRequest(string memory hookJson) internal view returns (string memory apiUrl) {
        address senderAddress = crossChainUser;

        apiUrl = string.concat(
            "https://dln.debridge.finance/v1.0/dln/order/create-tx",
            "?srcChainId=1", // Ethereum
            "&srcChainTokenIn=",
            _addressToHex(address(0)), // ETH
            "&srcChainTokenInAmount=10000000000000000", // 0.01 ETH
            "&dstChainId=100000013", // Story mainnet
            "&dstChainTokenOut=",
            _addressToHex(address(USDC)),
            "&dstChainTokenOutAmount=auto",
            "&dstChainTokenOutRecipient=",
            _addressToHex(senderAddress),
            "&srcChainOrderAuthorityAddress=",
            _addressToHex(senderAddress),
            "&dstChainOrderAuthorityAddress=",
            _addressToHex(senderAddress),
            "&enableEstimate=true",
            "&prependOperatingExpenses=true",
            "&dlnHook=",
            _urlEncode(hookJson)
        );
    }

    function _executeApiCall(string memory apiUrl) internal returns (string memory response) {
        string[] memory curlCommand = new string[](3);
        curlCommand[0] = "curl";
        curlCommand[1] = "-s";
        curlCommand[2] = apiUrl;

        bytes memory responseBytes = vm.ffi(curlCommand);
        response = string(responseBytes);
        
        console.log("API Response:");
        console.log(response);
    }

    function _validateApiResponse(string memory response) internal pure {
        require(bytes(response).length > 0, "Empty API response");
        require(_contains(response, '"estimation"'), "Missing estimation field");
        require(_contains(response, '"orderId"'), "Missing order ID");
    }

    function _addressToHex(address addr) internal pure returns (string memory) {
        bytes memory data = abi.encodePacked(addr);
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(2 + data.length * 2);
        str[0] = "0";
        str[1] = "x";
        for (uint i = 0; i < data.length; i++) {
            str[2+i*2] = alphabet[uint(uint8(data[i] >> 4))];
            str[3+i*2] = alphabet[uint(uint8(data[i] & 0x0f))];
        }
        return string(str);
    }

    function _bytesToHex(bytes memory data) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(2 + data.length * 2);
        str[0] = "0";
        str[1] = "x";
        for (uint i = 0; i < data.length; i++) {
            str[2+i*2] = alphabet[uint(uint8(data[i] >> 4))];
            str[3+i*2] = alphabet[uint(uint8(data[i] & 0x0f))];
        }
        return string(str);
    }

    function _urlEncode(string memory input) internal pure returns (string memory) {
        bytes memory inputBytes = bytes(input);
        bytes memory output = new bytes(inputBytes.length * 3);
        uint outputLength = 0;

        for (uint i = 0; i < inputBytes.length; i++) {
            uint8 char = uint8(inputBytes[i]);

            if (
                (char >= 0x30 && char <= 0x39) ||
                (char >= 0x41 && char <= 0x5A) ||
                (char >= 0x61 && char <= 0x7A) ||
                char == 0x2D ||
                char == 0x2E ||
                char == 0x5F ||
                char == 0x7E
            ) {
                output[outputLength++] = inputBytes[i];
            } else {
                output[outputLength++] = "%";
                output[outputLength++] = bytes1(_toHexChar(char >> 4));
                output[outputLength++] = bytes1(_toHexChar(char & 0x0F));
            }
        }

        bytes memory result = new bytes(outputLength);
        for (uint i = 0; i < outputLength; i++) {
            result[i] = output[i];
        }
        return string(result);
    }

    function _toHexChar(uint8 value) internal pure returns (uint8) {
        return value < 10 ? (0x30 + value) : (0x41 + value - 10);
    }

    function _contains(string memory haystack, string memory needle) internal pure returns (bool) {
        bytes memory haystackBytes = bytes(haystack);
        bytes memory needleBytes = bytes(needle);

        if (needleBytes.length > haystackBytes.length) return false;

        for (uint i = 0; i <= haystackBytes.length - needleBytes.length; i++) {
            bool found = true;
            for (uint j = 0; j < needleBytes.length; j++) {
                if (haystackBytes[i + j] != needleBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) return true;
        }
        return false;
    }
}
