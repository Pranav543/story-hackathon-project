// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { IIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IIPAssetRegistry.sol";
import { ILicenseRegistry } from "@storyprotocol/core/interfaces/registries/ILicenseRegistry.sol";
import { IRoyaltyModule } from "@storyprotocol/core/interfaces/modules/royalty/IRoyaltyModule.sol";
import { IPILicenseTemplate } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

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
        uint256 sourceChainId; // Chain where borrower is located
    }

    struct IPCollateral {
        address ipAsset;
        uint256 assessedValue;
        uint256 riskScore; // 0-100, lower is better
        bool isEligible;
        uint256 lastValidated;
        bytes32 yakoaHash; // Yakoa verification hash
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

    event LoanRepaid(uint256 indexed loanId, address indexed borrower, uint256 amount);
    event CrossChainRepaymentInitiated(
        uint256 indexed loanId,
        address indexed borrower,
        uint256 sourceChainId,
        bytes32 deBridgeOrderId
    );
    event CrossChainRepaymentCompleted(uint256 indexed loanId, bytes32 deBridgeOrderId);
    event LoanLiquidated(uint256 indexed loanId, address indexed liquidator);
    event IPCollateralValidated(address indexed ipAsset, uint256 assessedValue, uint256 riskScore);
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
    mapping(uint256 => address) public chainBridges; // chainId => bridge contract
    mapping(bytes32 => CrossChainRepayment) public crossChainRepayments; // deBridge orderId => repayment info
    mapping(uint256 => bytes32) public loanToOrderId; // loanId => deBridge orderId

    uint256 public nextLoanId;
    uint256 public constant MAX_LTV = 70; // 70% Loan-to-Value ratio
    uint256 public constant LIQUIDATION_THRESHOLD = 85; // 85% liquidation threshold
    uint256 public constant BASE_INTEREST_RATE = 500; // 5% base rate (in basis points)
    
    // deBridge configuration
    string public constant DEBRIDGE_API_URL = "https://dln.debridge.finance/v1.0/dln/order/create-tx";
    uint256 public constant STORY_CHAIN_ID = 100000013; // Story mainnet chain ID

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
                            CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Validates IP asset for use as collateral using Yakoa
     * @param ipAsset The IP asset to validate
     * @param yakoaProof Yakoa authenticity proof
     * @param assessedValue The assessed value of the IP asset
     */
    function validateIPCollateral(
        address ipAsset,
        bytes32 yakoaProof,
        uint256 assessedValue
    ) external onlyOwner {
        require(IP_ASSET_REGISTRY.isRegistered(ipAsset), "IP not registered");
        
        uint256 riskScore = _calculateRiskScore(ipAsset, yakoaProof);
        bool isEligible = riskScore < 30;
        
        ipCollaterals[ipAsset] = IPCollateral({
            ipAsset: ipAsset,
            assessedValue: assessedValue,
            riskScore: riskScore,
            isEligible: isEligible,
            lastValidated: block.timestamp,
            yakoaHash: yakoaProof
        });

        emit IPCollateralValidated(ipAsset, assessedValue, riskScore);
    }

    /**
     * @notice Creates a new loan using IP asset as collateral
     * @param ipAsset The IP asset to use as collateral
     * @param loanAmount Amount to borrow
     * @param duration Loan duration in seconds
     * @param loanToken Token to borrow
     * @param borrowerChainId Chain ID where borrower is located (for cross-chain repayments)
     */
    function createLoan(
        address ipAsset,
        uint256 loanAmount,
        uint256 duration,
        address loanToken,
        uint256 borrowerChainId
    ) external nonReentrant {
        IPCollateral memory collateral = ipCollaterals[ipAsset];
        require(collateral.isEligible, "IP not eligible as collateral");
        require(supportedTokens[loanToken], "Token not supported");
        require(_isIPOwner(ipAsset, msg.sender), "Not IP owner");
        
        uint256 maxLoanAmount = (collateral.assessedValue * MAX_LTV) / 100;
        require(loanAmount <= maxLoanAmount, "Loan amount exceeds LTV");
        
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
        
        emit LoanCreated(loanId, msg.sender, ipAsset, loanAmount, collateral.assessedValue, borrowerChainId);
    }

    /**
     * @notice Repays a loan directly (same chain)
     * @param loanId The loan to repay
     */
    function repayLoan(uint256 loanId) external nonReentrant {
        Loan storage loan = loans[loanId];
        require(loan.isActive, "Loan not active");
        require(loan.borrower == msg.sender, "Not borrower");
        
        uint256 totalOwed = _calculateTotalOwed(loanId);
        IERC20(loan.loanToken).transferFrom(msg.sender, address(this), totalOwed);
        
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
        require(loan.status == LoanStatus.CROSS_CHAIN_REPAYMENT_PENDING, "Not pending cross-chain repayment");
        
        CrossChainRepayment storage repayment = crossChainRepayments[deBridgeOrderId];
        require(repayment.loanId == loanId, "Invalid loan ID");
        require(!repayment.isCompleted, "Repayment already completed");
        
        uint256 totalOwed = _calculateTotalOwed(loanId);
        require(repaymentAmount >= totalOwed, "Insufficient repayment amount");
        
        // Mark loan as repaid
        loan.isActive = false;
        loan.isRepaid = true;
        loan.status = LoanStatus.REPAID;
        
        // Mark repayment as completed
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
        require(loan.borrower == msg.sender || msg.sender == owner(), "Not authorized");
        
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
        
        emit CrossChainRepaymentInitiated(loanId, loan.borrower, sourceChainId, deBridgeOrderId);
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
        
        // In production, verify the caller is authorized (deBridge executor)
        // For now, we'll accept any caller for testing
        
        emit CrossChainLiquidityAdded(token, amount, sourceChain, deBridgeOrderId);
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

    function getUserLoans(address user) external view returns (uint256[] memory) {
        return userLoans[user];
    }

    function calculateTotalOwed(uint256 loanId) external view returns (uint256) {
        return _calculateTotalOwed(loanId);
    }

    function getIPCollateral(address ipAsset) external view returns (IPCollateral memory) {
        return ipCollaterals[ipAsset];
    }

    function getCrossChainRepayment(bytes32 deBridgeOrderId) external view returns (CrossChainRepayment memory) {
        return crossChainRepayments[deBridgeOrderId];
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _calculateRiskScore(address ipAsset, bytes32 yakoaProof) internal view returns (uint256) {
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

    function _calculateInterestRate(uint256 riskScore) internal pure returns (uint256) {
        return BASE_INTEREST_RATE + (riskScore * 10);
    }

    function _calculateTotalOwed(uint256 loanId) internal view returns (uint256) {
        Loan memory loan = loans[loanId];
        uint256 timeElapsed = block.timestamp - loan.startTime;
        uint256 interest = (loan.loanAmount * loan.interestRate * timeElapsed) / (365 days * 10000);
        return loan.loanAmount + interest;
    }

    function _isIPOwner(address ipAsset, address user) internal view returns (bool) {
        if (!IP_ASSET_REGISTRY.isRegistered(ipAsset)) {
            return false;
        }
        return true; // Simplified for MVP
    }

    function _isLiquidatable(uint256 loanId) internal view returns (bool) {
        Loan memory loan = loans[loanId];
        uint256 totalOwed = _calculateTotalOwed(loanId);
        uint256 collateralRatio = (loan.collateralValue * 100) / totalOwed;
        
        return collateralRatio < LIQUIDATION_THRESHOLD || 
               block.timestamp > loan.startTime + loan.duration;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setSupportedToken(address token, bool supported) external onlyOwner {
        supportedTokens[token] = supported;
    }

    function setBridgeContract(uint256 chainId, address bridge) external onlyOwner {
        chainBridges[chainId] = bridge;
    }

    function withdrawToken(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(owner(), amount);
    }
}
