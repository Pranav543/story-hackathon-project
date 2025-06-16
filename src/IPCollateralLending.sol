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
    ) external {
        // ✅ Remove onlyOwner modifier
        if (!IP_ASSET_REGISTRY.isRegistered(ipAsset)) revert IPNotRegistered();
        if (bytes(yakoaTokenId).length == 0) revert InvalidYakoaTokenID();

        // Optional: Add IP owner check instead of contract owner
        // if (!_isIPOwner(ipAsset, msg.sender)) revert NotIPOwner();

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
     */
    function updateYakoaVerification(
        string memory yakoaTokenId,
        bool isVerified,
        uint256 riskScore
    ) external {
        // ✅ Remove onlyOwner modifier
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

        // Get the token contract and token ID from the IP asset
        // In a real implementation, you would query the IP asset registry
        // For now, we'll use a simplified approach for the demo
        try IP_ASSET_REGISTRY.ipId(block.chainid, address(0), 0) returns (
            address
        ) {
            // If we can implement proper ownership check here, do it
            // For demo purposes, allow any registered user
            return true;
        } catch {
            return true; // Simplified for MVP - in production, implement proper ownership check
        }
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
