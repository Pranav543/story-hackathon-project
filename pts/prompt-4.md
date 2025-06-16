This is the description for my hackathon project: 
IP Collateral Lending Protocol
Built a comprehensive DeFi lending platform that uses verified intellectual property as collateral:

🛡️ Core Innovation
Yakoa IP Verification: Real-time infringement detection & authenticity scoring

Story Protocol Integration: IP asset registration, licensing & royalty management

deBridge Cross-Chain: Multi-chain loan repayments & liquidity provision

🏗️ Technical Stack
Smart Contract: Solidity lending protocol with custom errors & risk-based pricing

Frontend: Next.js dashboard with MetaMask integration & real-time status tracking

APIs: Yakoa verification, Story Protocol attestation, deBridge hooks

💰 Key Features
Upload media → Yakoa screens for IP conflicts → Story registers asset → Risk scoring determines loan eligibility

70% LTV ratio, automated liquidation, cross-chain repayments


I have completed the backend side of things only frontend is remaining. But I want to do this in a modular way and first integrate basic functionality of the protocol like only story and debridge related things. I want to use next js for front end and you can use other standard library as necessary. UI is not my biggest focus functionality is my focus though so UI should be visually appealing but should not be too complicated and you have liberty to make decisions to make sure that basic functionality works 


Below is my backend codebase:

script/DeBridgeAPIExample.js

/**
 * @title deBridge API Integration Example
 * @notice Demonstrates complete API integration for cross-chain loan repayments
 */

const axios = require('axios');

class DeBridgeAPIClient {
    constructor() {
        this.baseUrl = 'https://dln.debridge.finance/v1.0/dln/order';
        this.statsUrl = 'https://stats-api.dln.trade/api';
    }

    /**
     * Creates a cross-chain loan repayment order
     */
    async createLoanRepaymentOrder({
        loanId,
        repaymentAmount,
        lendingContract,
        borrower,
        sourceChainId = 1, // Ethereum
        destinationChainId = 1315, // Story
        sourceToken = '0x0000000000000000000000000000000000000000', // ETH
        destinationToken = '0xF2104833d386a2734a4eB3B8ad6FC6812F29E38E', // USDC on Story
        sourceAmount = 'auto'
    }) {
        try {
            // Build hook payload
            const hookPayload = this.buildLoanRepaymentHook(
                loanId,
                repaymentAmount,
                lendingContract
            );

            // Build API request
            const params = new URLSearchParams({
                srcChainId: sourceChainId.toString(),
                srcChainTokenIn: sourceToken,
                srcChainTokenInAmount: sourceAmount,
                dstChainId: destinationChainId.toString(),
                dstChainTokenOut: destinationToken,
                dstChainTokenOutAmount: repaymentAmount.toString(),
                dstChainTokenOutRecipient: lendingContract,
                srcChainOrderAuthorityAddress: borrower,
                dstChainOrderAuthorityAddress: borrower,
                enableEstimate: 'true',
                prependOperatingExpenses: 'true',
                dlnHook: JSON.stringify(hookPayload)
            });

            const response = await axios.get(`${this.baseUrl}/create-tx?${params}`);
            
            console.log('✅ deBridge order created successfully');
            console.log('Order ID:', response.data.orderId);
            console.log('Transaction data:', response.data.tx);
            
            return response.data;
        } catch (error) {
            console.error('❌ Failed to create deBridge order:', error.response?.data || error.message);
            throw error;
        }
    }

    /**
     * Creates a cross-chain liquidity provision order
     */
    async createLiquidityOrder({
        amount,
        sourceChainId,
        destinationChainId = 1315,
        lendingContract,
        provider,
        sourceToken,
        destinationToken
    }) {
        try {
            const hookPayload = this.buildLiquidityProvisionHook(
                destinationToken,
                amount,
                sourceChainId,
                lendingContract
            );

            const params = new URLSearchParams({
                srcChainId: sourceChainId.toString(),
                srcChainTokenIn: sourceToken,
                srcChainTokenInAmount: amount.toString(),
                dstChainId: destinationChainId.toString(),
                dstChainTokenOut: destinationToken,
                dstChainTokenOutAmount: 'auto',
                dstChainTokenOutRecipient: lendingContract,
                srcChainOrderAuthorityAddress: provider,
                dstChainOrderAuthorityAddress: provider,
                enableEstimate: 'true',
                prependOperatingExpenses: 'true',
                dlnHook: JSON.stringify(hookPayload)
            });

            const response = await axios.get(`${this.baseUrl}/create-tx?${params}`);
            
            console.log('✅ Liquidity order created successfully');
            return response.data;
        } catch (error) {
            console.error('❌ Failed to create liquidity order:', error.response?.data || error.message);
            throw error;
        }
    }

    /**
     * Monitors order status
     */
    async monitorOrder(orderId) {
        try {
            const response = await axios.get(`${this.statsUrl}/Orders/${orderId}`);
            console.log(`Order ${orderId} status:`, response.data.status);
            return response.data;
        } catch (error) {
            console.error('Failed to monitor order:', error.message);
            throw error;
        }
    }

    /**
     * Builds loan repayment hook payload
     */
    buildLoanRepaymentHook(loanId, repaymentAmount, lendingContract) {
        // Encode function call: processCrossChainRepayment(uint256,uint256,bytes32)
        const functionSignature = '0x12345678'; // Replace with actual function selector
        
        const calldata = functionSignature + 
            this.padHex(loanId.toString(16), 64) +
            this.padHex(repaymentAmount.toString(16), 64) +
            this.padHex('0', 64); // placeholder for orderId

        return {
            type: "evm_transaction_call",
            data: {
                to: lendingContract,
                calldata: calldata,
                gas: 200000
            }
        };
    }

    /**
     * Builds liquidity provision hook payload
     */
    buildLiquidityProvisionHook(token, amount, sourceChain, lendingContract) {
        const functionSignature = '0x87654321'; // Replace with actual function selector
        
        const calldata = functionSignature +
            this.padHex(token.slice(2), 64) +
            this.padHex(amount.toString(16), 64) +
            this.padHex(sourceChain.toString(16), 64) +
            this.padHex('0', 64); // placeholder for orderId

        return {
            type: "evm_transaction_call",
            data: {
                to: lendingContract,
                calldata: calldata,
                gas: 150000
            }
        };
    }

    /**
     * Helper function to pad hex strings
     */
    padHex(hex, length) {
        return hex.padStart(length, '0');
    }
}

// Example usage
async function main() {
    const client = new DeBridgeAPIClient();
    
    // Example: Create cross-chain loan repayment order
    try {
        const order = await client.createLoanRepaymentOrder({
            loanId: 1,
            repaymentAmount: '50000000000', // 50k USDC (6 decimals)
            lendingContract: '0xYourLendingContractAddress',
            borrower: '0xBorrowerAddress',
            sourceAmount: '10000000000000000' // 0.01 ETH
        });

        console.log('Order created:', order.orderId);
        
        // Monitor order status
        setInterval(async () => {
            const status = await client.monitorOrder(order.orderId);
            if (['Fulfilled', 'SentUnlock', 'ClaimedUnlock'].includes(status.status)) {
                console.log('✅ Order completed successfully');
                process.exit(0);
            }
        }, 5000);
        
    } catch (error) {
        console.error('Failed to create order:', error);
    }
}

// Uncomment to run
// main().catch(console.error);

module.exports = DeBridgeAPIClient;

script/Deploy.s.sol

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Script, console } from "forge-std/Script.sol";
import { IPCollateralLending } from "../src/IPCollateralLending.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Story Protocol contract addresses (testnet)
        address ipAssetRegistry = 0x77319B4031e6eF1250907aa00018B8B1c67a244b;
        address licenseRegistry = 0x529a750E02d8E2f15649c13D69a465286a780e24;
        address licensingModule = 0x04fbd8a2e56dd85CFD5500A4A4DfA955B9f1dE6f;
        address royaltyModule = 0xD2f60c40fEbccf6311f8B47c4f2Ec6b040400086;
        address pilTemplate = 0x2E896b0b2Fdb7457499B56AAaA4AE55BCB4Cd316;

        console.log("Deploying IPCollateralLending...");
        
        IPCollateralLending lendingProtocol = new IPCollateralLending(
            ipAssetRegistry,
            licenseRegistry,
            licensingModule,
            royaltyModule,
            pilTemplate
        );

        console.log("IPCollateralLending deployed at:", address(lendingProtocol));
        
        // Setup supported tokens
        console.log("Setting up supported tokens...");
        lendingProtocol.setSupportedToken(0xF2104833d386a2734a4eB3B8ad6FC6812F29E38E, true); // USDC
        
        console.log("Deployment completed successfully!");
        console.log("Contract Address:", address(lendingProtocol));
        console.log("Owner:", lendingProtocol.owner());

        vm.stopBroadcast();
    }
}

src/mocks/SimpleNFT.sol

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract SimpleNFT is ERC721, Ownable {
    uint256 public nextTokenId;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) Ownable(msg.sender) {}

    function mint(address to) public onlyOwner returns (uint256) {
        uint256 tokenId = nextTokenId++;
        _mint(to, tokenId);
        return tokenId;
    }
}

src/DeBridgeIntegration.sol

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

src/IPCollateralLending.sol

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {IIPAssetRegistry} from "@storyprotocol/core/interfaces/registries/IIPAssetRegistry.sol";
import {ILicenseRegistry} from "@storyprotocol/core/interfaces/registries/ILicenseRegistry.sol";
import {IRoyaltyModule} from "@storyprotocol/core/interfaces/modules/royalty/IRoyaltyModule.sol";
import {IPILicenseTemplate} from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";
import {ILicensingModule} from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract IPCollateralLending is ReentrancyGuard, Ownable {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct Loan {
        address borrower;
        address ipAsset;
        uint256 collateralValue;
        uint256 loanAmount;
        uint256 interestRate;
        uint256 startTime;
        uint256 duration;
        address loanToken;
        bool isActive;
        bool isRepaid;
        LoanStatus status;
        uint256 sourceChainId;
    }

    struct IPCollateral {
        address ipAsset;
        uint256 assessedValue;
        uint256 riskScore;
        bool isEligible;
        uint256 lastValidated;
        bytes32 yakoaHash;
        string yakoaTokenId;
        YakoaStatus yakoaStatus;
        uint256 yakoaTimestamp;
    }

    struct CrossChainRepayment {
        uint256 loanId;
        address borrower;
        uint256 sourceChainId;
        address sourceToken;
        uint256 sourceAmount;
        bytes32 deBridgeOrderId;
        uint256 timestamp;
        bool isCompleted;
    }

    enum LoanStatus {
        PENDING,
        ACTIVE,
        REPAID,
        LIQUIDATED,
        DEFAULTED,
        CROSS_CHAIN_REPAYMENT_PENDING
    }

    enum YakoaStatus {
        PENDING,
        VERIFIED,
        REJECTED,
        ERROR
    }

    /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
//////////////////////////////////////////////////////////////*/

    error IPNotRegistered();
    error IPNotVerifiedByYakoa();
    error IPNotEligibleAsCollateral();
    error TokenNotSupported();
    error NotIPOwner();
    error LoanAmountExceedsLTV();
    error LoanNotActive();
    error NotBorrower();
    error NotAuthorized();
    error LoanNotLiquidatable();
    error YakoaTokenNotFound();
    error VerificationAlreadyCompleted();
    error VerificationNotTimedOut();
    error InsufficientRepaymentAmount();
    error RepaymentAlreadyCompleted();
    error InvalidLoanID();
    error InvalidYakoaTokenID();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event LoanCreated(
        uint256 indexed loanId,
        address indexed borrower,
        address indexed ipAsset,
        uint256 loanAmount,
        uint256 collateralValue,
        uint256 sourceChainId
    );

    event LoanRepaid(
        uint256 indexed loanId,
        address indexed borrower,
        uint256 amount
    );
    event CrossChainRepaymentInitiated(
        uint256 indexed loanId,
        address indexed borrower,
        uint256 sourceChainId,
        bytes32 deBridgeOrderId
    );
    event CrossChainRepaymentCompleted(
        uint256 indexed loanId,
        bytes32 deBridgeOrderId
    );
    event LoanLiquidated(uint256 indexed loanId, address indexed liquidator);
    event IPCollateralValidated(
        address indexed ipAsset,
        uint256 assessedValue,
        uint256 riskScore,
        string yakoaTokenId
    );
    event YakoaVerificationStarted(
        address indexed ipAsset,
        string yakoaTokenId
    );
    event YakoaVerificationCompleted(
        address indexed ipAsset,
        string yakoaTokenId,
        YakoaStatus status,
        bool isEligible
    );
    event CrossChainLiquidityAdded(
        address indexed token,
        uint256 amount,
        uint256 sourceChain,
        bytes32 deBridgeOrderId
    );

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    // Story Protocol contracts
    IIPAssetRegistry public immutable IP_ASSET_REGISTRY;
    ILicenseRegistry public immutable LICENSE_REGISTRY;
    ILicensingModule public immutable LICENSING_MODULE;
    IRoyaltyModule public immutable ROYALTY_MODULE;
    IPILicenseTemplate public immutable PIL_TEMPLATE;

    // Core protocol state
    mapping(uint256 => Loan) public loans;
    mapping(address => IPCollateral) public ipCollaterals;
    mapping(address => uint256[]) public userLoans;
    mapping(address => bool) public supportedTokens;
    mapping(uint256 => address) public chainBridges;
    mapping(bytes32 => CrossChainRepayment) public crossChainRepayments;
    mapping(uint256 => bytes32) public loanToOrderId;
    mapping(string => address) public yakoaTokenToIpAsset;

    uint256 public nextLoanId;
    uint256 public constant MAX_LTV = 70;
    uint256 public constant LIQUIDATION_THRESHOLD = 85;
    uint256 public constant BASE_INTEREST_RATE = 500;

    // Yakoa configuration
    string public constant YAKOA_NETWORK = "story";
    uint256 public constant YAKOA_VERIFICATION_TIMEOUT = 24 hours;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _ipAssetRegistry,
        address _licenseRegistry,
        address _licensingModule,
        address _royaltyModule,
        address _pilTemplate
    ) Ownable(msg.sender) {
        IP_ASSET_REGISTRY = IIPAssetRegistry(_ipAssetRegistry);
        LICENSE_REGISTRY = ILicenseRegistry(_licenseRegistry);
        LICENSING_MODULE = ILicensingModule(_licensingModule);
        ROYALTY_MODULE = IRoyaltyModule(_royaltyModule);
        PIL_TEMPLATE = IPILicenseTemplate(_pilTemplate);
    }

    /*//////////////////////////////////////////////////////////////
                            YAKOA INTEGRATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initiates Yakoa verification for an IP asset
     * @param ipAsset The IP asset to verify
     * @param yakoaTokenId The Yakoa token identifier from frontend
     * @param assessedValue The assessed value of the IP asset
     */
    function initiateYakoaVerification(
        address ipAsset,
        string memory yakoaTokenId,
        uint256 assessedValue
    ) external onlyOwner {
        if (!IP_ASSET_REGISTRY.isRegistered(ipAsset)) revert IPNotRegistered();
        if (bytes(yakoaTokenId).length == 0) revert InvalidYakoaTokenID();

        ipCollaterals[ipAsset] = IPCollateral({
            ipAsset: ipAsset,
            assessedValue: assessedValue,
            riskScore: 100,
            isEligible: false,
            lastValidated: block.timestamp,
            yakoaHash: keccak256(abi.encodePacked(yakoaTokenId)),
            yakoaTokenId: yakoaTokenId,
            yakoaStatus: YakoaStatus.PENDING,
            yakoaTimestamp: block.timestamp
        });

        yakoaTokenToIpAsset[yakoaTokenId] = ipAsset;

        emit YakoaVerificationStarted(ipAsset, yakoaTokenId);
    }

    /**
     * @notice Updates the result of Yakoa verification
     * @param yakoaTokenId The Yakoa token identifier
     * @param isVerified Whether the content passed Yakoa verification
     * @param riskScore The calculated risk score (0-100)
     */
    function updateYakoaVerification(
        string memory yakoaTokenId,
        bool isVerified,
        uint256 riskScore
    ) external onlyOwner {
        address ipAsset = yakoaTokenToIpAsset[yakoaTokenId];
        if (ipAsset == address(0)) revert YakoaTokenNotFound();

        IPCollateral storage collateral = ipCollaterals[ipAsset];
        if (collateral.yakoaStatus != YakoaStatus.PENDING)
            revert VerificationAlreadyCompleted();

        if (isVerified && riskScore < 30) {
            collateral.yakoaStatus = YakoaStatus.VERIFIED;
            collateral.isEligible = true;
            collateral.riskScore = riskScore;
        } else {
            collateral.yakoaStatus = YakoaStatus.REJECTED;
            collateral.isEligible = false;
            collateral.riskScore = riskScore;
        }

        collateral.lastValidated = block.timestamp;

        emit YakoaVerificationCompleted(
            ipAsset,
            yakoaTokenId,
            collateral.yakoaStatus,
            collateral.isEligible
        );
        emit IPCollateralValidated(
            ipAsset,
            collateral.assessedValue,
            collateral.riskScore,
            yakoaTokenId
        );
    }

    /**
     * @notice Handles Yakoa verification timeout
     * @param yakoaTokenId The Yakoa token identifier that timed out
     */
    function handleYakoaTimeout(string memory yakoaTokenId) external onlyOwner {
        address ipAsset = yakoaTokenToIpAsset[yakoaTokenId];
        require(ipAsset != address(0), "Yakoa token not found");

        IPCollateral storage collateral = ipCollaterals[ipAsset];
        require(
            collateral.yakoaStatus == YakoaStatus.PENDING,
            "Verification already completed"
        );
        require(
            block.timestamp >
                collateral.yakoaTimestamp + YAKOA_VERIFICATION_TIMEOUT,
            "Verification not timed out yet"
        );

        collateral.yakoaStatus = YakoaStatus.ERROR;
        collateral.isEligible = false;

        emit YakoaVerificationCompleted(
            ipAsset,
            yakoaTokenId,
            YakoaStatus.ERROR,
            false
        );
    }

    /*//////////////////////////////////////////////////////////////
                            CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates a new loan using IP asset as collateral
     * @param ipAsset The IP asset to use as collateral
     * @param loanAmount Amount to borrow
     * @param duration Loan duration in seconds
     * @param loanToken Token to borrow
     * @param borrowerChainId Chain ID where borrower is located
     */
    /**
     * @notice Creates a new loan using IP asset as collateral
     * @param ipAsset The IP asset to use as collateral
     * @param loanAmount Amount to borrow
     * @param duration Loan duration in seconds
     * @param loanToken Token to borrow
     * @param borrowerChainId Chain ID where borrower is located
     */
    function createLoan(
        address ipAsset,
        uint256 loanAmount,
        uint256 duration,
        address loanToken,
        uint256 borrowerChainId
    ) external nonReentrant {
        IPCollateral memory collateral = ipCollaterals[ipAsset];

        // Check if IP asset is registered first
        if (!IP_ASSET_REGISTRY.isRegistered(ipAsset)) revert IPNotRegistered();

        // Check Yakoa verification status first (more specific error)
        if (collateral.yakoaStatus != YakoaStatus.VERIFIED)
            revert IPNotVerifiedByYakoa();

        // Then check if eligible (this should be true if verified, but keeping as separate check)
        if (!collateral.isEligible) revert IPNotEligibleAsCollateral();

        // Check other requirements
        if (!supportedTokens[loanToken]) revert TokenNotSupported();
        if (!_isIPOwner(ipAsset, msg.sender)) revert NotIPOwner();

        uint256 maxLoanAmount = (collateral.assessedValue * MAX_LTV) / 100;
        if (loanAmount > maxLoanAmount) revert LoanAmountExceedsLTV();

        uint256 interestRate = _calculateInterestRate(collateral.riskScore);

        uint256 loanId = nextLoanId++;
        loans[loanId] = Loan({
            borrower: msg.sender,
            ipAsset: ipAsset,
            collateralValue: collateral.assessedValue,
            loanAmount: loanAmount,
            interestRate: interestRate,
            startTime: block.timestamp,
            duration: duration,
            loanToken: loanToken,
            isActive: true,
            isRepaid: false,
            status: LoanStatus.ACTIVE,
            sourceChainId: borrowerChainId
        });

        userLoans[msg.sender].push(loanId);
        IERC20(loanToken).transfer(msg.sender, loanAmount);

        emit LoanCreated(
            loanId,
            msg.sender,
            ipAsset,
            loanAmount,
            collateral.assessedValue,
            borrowerChainId
        );
    }

    /**
     * @notice Repays a loan directly (same chain)
     * @param loanId The loan to repay
     */
    function repayLoan(uint256 loanId) external nonReentrant {
        Loan storage loan = loans[loanId];
        if (!loan.isActive) revert LoanNotActive();
        if (loan.borrower != msg.sender) revert NotBorrower();

        uint256 totalOwed = _calculateTotalOwed(loanId);
        IERC20(loan.loanToken).transferFrom(
            msg.sender,
            address(this),
            totalOwed
        );

        loan.isActive = false;
        loan.isRepaid = true;
        loan.status = LoanStatus.REPAID;

        emit LoanRepaid(loanId, msg.sender, totalOwed);
    }

    /**
     * @notice Processes cross-chain loan repayment via deBridge hook
     * @dev This function is called by deBridge when a cross-chain repayment order is fulfilled
     * @param loanId The loan being repaid
     * @param repaymentAmount The amount being repaid
     * @param deBridgeOrderId The deBridge order ID for tracking
     */
    function processCrossChainRepayment(
        uint256 loanId,
        uint256 repaymentAmount,
        bytes32 deBridgeOrderId
    ) external nonReentrant {
        Loan storage loan = loans[loanId];
        require(loan.isActive, "Loan not active");
        require(
            loan.status == LoanStatus.CROSS_CHAIN_REPAYMENT_PENDING,
            "Not pending cross-chain repayment"
        );

        CrossChainRepayment storage repayment = crossChainRepayments[
            deBridgeOrderId
        ];
        require(repayment.loanId == loanId, "Invalid loan ID");
        require(!repayment.isCompleted, "Repayment already completed");

        uint256 totalOwed = _calculateTotalOwed(loanId);
        require(repaymentAmount >= totalOwed, "Insufficient repayment amount");

        loan.isActive = false;
        loan.isRepaid = true;
        loan.status = LoanStatus.REPAID;

        repayment.isCompleted = true;

        emit CrossChainRepaymentCompleted(loanId, deBridgeOrderId);
        emit LoanRepaid(loanId, loan.borrower, repaymentAmount);
    }

    /**
     * @notice Initiates cross-chain repayment tracking
     * @dev Called when a cross-chain repayment order is created via deBridge
     * @param loanId The loan being repaid
     * @param sourceChainId Chain where payment originates
     * @param sourceToken Token being used for payment on source chain
     * @param sourceAmount Amount being paid on source chain
     * @param deBridgeOrderId The deBridge order ID
     */
    function initiateCrossChainRepayment(
        uint256 loanId,
        uint256 sourceChainId,
        address sourceToken,
        uint256 sourceAmount,
        bytes32 deBridgeOrderId
    ) external {
        Loan storage loan = loans[loanId];
        require(loan.isActive, "Loan not active");
        require(
            loan.borrower == msg.sender || msg.sender == owner(),
            "Not authorized"
        );

        loan.status = LoanStatus.CROSS_CHAIN_REPAYMENT_PENDING;
        loanToOrderId[loanId] = deBridgeOrderId;

        crossChainRepayments[deBridgeOrderId] = CrossChainRepayment({
            loanId: loanId,
            borrower: loan.borrower,
            sourceChainId: sourceChainId,
            sourceToken: sourceToken,
            sourceAmount: sourceAmount,
            deBridgeOrderId: deBridgeOrderId,
            timestamp: block.timestamp,
            isCompleted: false
        });

        emit CrossChainRepaymentInitiated(
            loanId,
            loan.borrower,
            sourceChainId,
            deBridgeOrderId
        );
    }

    /**
     * @notice Liquidates an underwater loan
     * @param loanId The loan to liquidate
     */
    function liquidateLoan(uint256 loanId) external nonReentrant {
        Loan storage loan = loans[loanId];
        require(loan.isActive, "Loan not active");
        require(_isLiquidatable(loanId), "Loan not liquidatable");

        loan.isActive = false;
        loan.status = LoanStatus.LIQUIDATED;

        emit LoanLiquidated(loanId, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                        CROSS-CHAIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Processes cross-chain liquidity addition via deBridge hook
     * @param token Token address
     * @param amount Amount added
     * @param sourceChain Source chain ID
     * @param deBridgeOrderId deBridge order ID for tracking
     */
    function addCrossChainLiquidity(
        address token,
        uint256 amount,
        uint256 sourceChain,
        bytes32 deBridgeOrderId
    ) external nonReentrant {
        require(supportedTokens[token], "Token not supported");

        emit CrossChainLiquidityAdded(
            token,
            amount,
            sourceChain,
            deBridgeOrderId
        );
    }

    /**
     * @notice Legacy function for testing - adds liquidity without deBridge tracking
     * @param token Token address
     * @param amount Amount added
     * @param sourceChain Source chain ID
     */
    function addCrossChainLiquidity(
        address token,
        uint256 amount,
        uint256 sourceChain
    ) external {
        require(supportedTokens[token], "Token not supported");

        emit CrossChainLiquidityAdded(token, amount, sourceChain, bytes32(0));
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getLoan(uint256 loanId) external view returns (Loan memory) {
        return loans[loanId];
    }

    function getUserLoans(
        address user
    ) external view returns (uint256[] memory) {
        return userLoans[user];
    }

    function calculateTotalOwed(
        uint256 loanId
    ) external view returns (uint256) {
        return _calculateTotalOwed(loanId);
    }

    function getIPCollateral(
        address ipAsset
    ) external view returns (IPCollateral memory) {
        return ipCollaterals[ipAsset];
    }

    function getCrossChainRepayment(
        bytes32 deBridgeOrderId
    ) external view returns (CrossChainRepayment memory) {
        return crossChainRepayments[deBridgeOrderId];
    }

    function getYakoaStatus(
        string memory yakoaTokenId
    ) external view returns (address ipAsset, YakoaStatus status) {
        ipAsset = yakoaTokenToIpAsset[yakoaTokenId];
        if (ipAsset != address(0)) {
            status = ipCollaterals[ipAsset].yakoaStatus;
        }
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _calculateRiskScore(
        address ipAsset,
        bytes32 yakoaProof
    ) internal view returns (uint256) {
        uint256 baseScore = 20;

        if (LICENSE_REGISTRY.getAttachedLicenseTermsCount(ipAsset) > 0) {
            baseScore -= 5;
        }

        if (LICENSE_REGISTRY.hasDerivativeIps(ipAsset)) {
            baseScore -= 5;
        }

        if (yakoaProof != bytes32(0)) {
            baseScore -= 10;
        }

        return baseScore;
    }

    function _calculateInterestRate(
        uint256 riskScore
    ) internal pure returns (uint256) {
        return BASE_INTEREST_RATE + (riskScore * 10);
    }

    function _calculateTotalOwed(
        uint256 loanId
    ) internal view returns (uint256) {
        Loan memory loan = loans[loanId];
        uint256 timeElapsed = block.timestamp - loan.startTime;
        uint256 interest = (loan.loanAmount * loan.interestRate * timeElapsed) /
            (365 days * 10000);
        return loan.loanAmount + interest;
    }

    function _isIPOwner(
        address ipAsset,
        address user
    ) internal view returns (bool) {
        if (!IP_ASSET_REGISTRY.isRegistered(ipAsset)) {
            return false;
        }
        return true; // Simplified for MVP
    }

    function _isLiquidatable(uint256 loanId) internal view returns (bool) {
        Loan memory loan = loans[loanId];
        uint256 totalOwed = _calculateTotalOwed(loanId);
        uint256 collateralRatio = (loan.collateralValue * 100) / totalOwed;

        return
            collateralRatio < LIQUIDATION_THRESHOLD ||
            block.timestamp > loan.startTime + loan.duration;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setSupportedToken(
        address token,
        bool supported
    ) external onlyOwner {
        supportedTokens[token] = supported;
    }

    function setBridgeContract(
        uint256 chainId,
        address bridge
    ) external onlyOwner {
        chainBridges[chainId] = bridge;
    }

    function withdrawToken(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(owner(), amount);
    }
}

test/DeBridgeIntegration.t.sol

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

test/IPCollateralLending.t.sol

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
        uint256 borrowerChainId = 1315;

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
        uint256 borrowerChainId = 1315;

        vm.prank(alice);
        // Now expect the custom error instead of string
        vm.expectRevert(IPCollateralLending.IPNotVerifiedByYakoa.selector);
        lendingProtocol.createLoan(ipAsset, loanAmount, duration, address(USDC), borrowerChainId);
    }

    function test_createLoanFailsWithUnregisteredIP() public {
        address unregisteredIP = address(0x123);
        uint256 loanAmount = 70000e6;
        uint256 duration = 365 days;
        uint256 borrowerChainId = 1315;

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
        uint256 borrowerChainId = 1315;

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
        uint256 borrowerChainId = 1315;

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
        uint256 borrowerChainId = 1315;

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
        uint256 borrowerChainId = 1315;

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

foundry.toml

[profile.default]
out = 'out'
libs = ['node_modules', 'lib']
cache_path = 'forge-cache'
gas_reports = ["*"]
optimizer = true
optimizer_runs = 20000
test = 'test'
solc = '0.8.26'
fs_permissions = [
    { access = 'read', path = './out' }, 
    { access = 'read-write', path = './deploy-out' },
    { access = 'read', path = './' }
]
evm_version = 'cancun'
remappings = [
    '@openzeppelin/=node_modules/@openzeppelin/',
    '@storyprotocol/core/=node_modules/@story-protocol/protocol-core/contracts/',
    '@storyprotocol/periphery/=node_modules/@story-protocol/protocol-periphery/contracts/',
    'erc6551/=node_modules/erc6551/',
    'forge-std/=node_modules/forge-std/src/',
    'ds-test/=node_modules/ds-test/src/',
    '@storyprotocol/test/=node_modules/@story-protocol/protocol-core/test/foundry/',
    '@solady/=node_modules/solady/'
]

[rpc_endpoints]
story_testnet = "${RPC_URL}"
story_mainnet = "${STORY_MAINNET_RPC}"

below are the latest links for documentation of story and debridge respectively
https://docs.story.foundation/
https://docs.debridge.finance/


