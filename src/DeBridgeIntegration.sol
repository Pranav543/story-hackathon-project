// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

/**
 * @title DeBridge Integration Helper
 * @notice Helper contract for constructing deBridge hook payloads and API interactions
 */
library DeBridgeIntegration {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct LoanRepaymentHook {
        uint256 loanId;
        uint256 repaymentAmount;
        address lendingContract;
        bytes32 expectedOrderId;
    }

    struct LiquidityHook {
        address token;
        uint256 amount;
        uint256 sourceChain;
        address lendingContract;
    }

    /*//////////////////////////////////////////////////////////////
                            HOOK CONSTRUCTION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructs deBridge hook for cross-chain loan repayment
     * @param loanId The loan ID to repay
     * @param repaymentAmount The amount to repay
     * @param lendingContract The lending contract address
     * @param deBridgeOrderId The expected deBridge order ID
     * @return hookJson JSON-encoded hook payload
     */
    function buildLoanRepaymentHook(
        uint256 loanId,
        uint256 repaymentAmount,
        address lendingContract,
        bytes32 deBridgeOrderId
    ) internal pure returns (string memory hookJson) {
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

    /**
     * @notice Constructs deBridge hook for cross-chain liquidity provision
     * @param token The token address
     * @param amount The amount
     * @param sourceChain The source chain ID
     * @param lendingContract The lending contract address
     * @param deBridgeOrderId The deBridge order ID
     * @return hookJson JSON-encoded hook payload
     */
    function buildLiquidityProvisionHook(
        address token,
        uint256 amount,
        uint256 sourceChain,
        address lendingContract,
        bytes32 deBridgeOrderId
    ) internal pure returns (string memory hookJson) {
        bytes memory calldata_ = abi.encodeWithSignature(
            "processCrossChainLiquidity(address,uint256,uint256,bytes32)",
            token,
            amount,
            sourceChain,
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
            '"gas":150000}}'
        );
    }

    /**
     * @notice Constructs API request URL for deBridge order creation
     * @param srcChainId Source chain ID
     * @param srcToken Source token address
     * @param srcAmount Source amount or "auto"
     * @param dstChainId Destination chain ID
     * @param dstToken Destination token address
     * @param dstAmount Destination amount or "auto"
     * @param recipient Recipient address
     * @param authority Authority address
     * @param hookJson Hook payload JSON
     * @return apiUrl Complete API request URL
     */
    function buildApiRequest(
        uint256 srcChainId,
        address srcToken,
        string memory srcAmount,
        uint256 dstChainId,
        address dstToken,
        string memory dstAmount,
        address recipient,
        address authority,
        string memory hookJson
    ) internal pure returns (string memory apiUrl) {
        string memory baseUrl = "https://dln.debridge.finance/v1.0/dln/order/create-tx";
        
        apiUrl = string.concat(
            baseUrl,
            "?srcChainId=", _uintToString(srcChainId),
            "&srcChainTokenIn=", _addressToHex(srcToken),
            "&srcChainTokenInAmount=", srcAmount,
            "&dstChainId=", _uintToString(dstChainId),
            "&dstChainTokenOut=", _addressToHex(dstToken),
            "&dstChainTokenOutAmount=", dstAmount,
            "&dstChainTokenOutRecipient=", _addressToHex(recipient),
            "&srcChainOrderAuthorityAddress=", _addressToHex(authority),
            "&dstChainOrderAuthorityAddress=", _addressToHex(authority),
            "&enableEstimate=true",
            "&prependOperatingExpenses=true",
            "&dlnHook=", _urlEncode(hookJson)
        );
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _addressToHex(address addr) internal pure returns (string memory) {
        return _bytesToHex(abi.encodePacked(addr));
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

    function _uintToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        
        return string(buffer);
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
}
