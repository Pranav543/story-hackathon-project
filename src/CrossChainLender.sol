// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title CrossChainLender
 * @notice EVM lender that automatically funds loans created on Story Protocol
 */
contract CrossChainLender is Ownable, ReentrancyGuard {
    struct LendingOrder {
        uint256 storyLoanId;
        address borrower;
        uint256 amount;
        address token;
        bool funded;
        bool repaid;
        uint256 timestamp;
        bytes32 deBridgeOrderId;
        address ipAsset;
        uint256 sourceChainId;
    }

    struct StoryLoanRequest {
        uint256 loanId;
        address borrower;
        uint256 amount;
        address token;
        address ipAsset;
        uint256 sourceChainId;
    }

    mapping(uint256 => LendingOrder) public orders;
    mapping(bytes32 => uint256) public deBridgeOrderToLocalOrder;
    mapping(address => bool) public supportedTokens;
    mapping(address => uint256) public totalLent;
    mapping(address => uint256) public totalRepaid;
    
    uint256 public nextOrderId;
    address public storyLendingContract;
    uint256 public constant STORY_CHAIN_ID = 1514; // Story mainnet
    
    // deBridge contracts (real addresses)
    address public constant DLN_SOURCE = 0xeF4fB24aD0916217251F553c0596F8Edc630EB66;
    address public constant DLN_DESTINATION = 0xE7351Fd770A37282b91D153Ee690B63579D6dd7f;

    event CrossChainLoanFunded(
        uint256 indexed orderId,
        uint256 indexed storyLoanId,
        address indexed borrower,
        uint256 amount,
        address token,
        address ipAsset,
        bytes32 deBridgeOrderId
    );

    event CrossChainRepaymentReceived(
        uint256 indexed orderId,
        uint256 amount,
        bytes32 deBridgeOrderId
    );

    event DeBridgeOrderCreated(
        bytes32 indexed orderId,
        uint256 amount,
        address borrower,
        uint256 targetChain
    );

    constructor(address _storyLendingContract) Ownable(msg.sender) {
        storyLendingContract = _storyLendingContract;
    }

    /**
     * @notice Processes cross-chain loan request (simulates deBridge fulfillment)
     * @param loanRequest The loan request from Story Protocol
     */
    function processCrossChainLoanRequest(
        StoryLoanRequest calldata loanRequest,
        bytes32 deBridgeOrderId
    ) external nonReentrant {
        require(supportedTokens[loanRequest.token], "Token not supported");
        require(IERC20(loanRequest.token).balanceOf(address(this)) >= loanRequest.amount, "Insufficient liquidity");

        uint256 orderId = nextOrderId++;
        
        orders[orderId] = LendingOrder({
            storyLoanId: loanRequest.loanId,
            borrower: loanRequest.borrower,
            amount: loanRequest.amount,
            token: loanRequest.token,
            funded: true,
            repaid: false,
            timestamp: block.timestamp,
            deBridgeOrderId: deBridgeOrderId,
            ipAsset: loanRequest.ipAsset,
            sourceChainId: loanRequest.sourceChainId
        });

        deBridgeOrderToLocalOrder[deBridgeOrderId] = orderId;

        // Transfer funds to borrower
        IERC20(loanRequest.token).transfer(loanRequest.borrower, loanRequest.amount);
        totalLent[loanRequest.token] += loanRequest.amount;

        emit CrossChainLoanFunded(
            orderId,
            loanRequest.loanId,
            loanRequest.borrower,
            loanRequest.amount,
            loanRequest.token,
            loanRequest.ipAsset,
            deBridgeOrderId
        );
    }

    /**
     * @notice Receives cross-chain royalty repayment
     * @param orderId The lending order ID
     * @param repaymentAmount Amount being repaid
     * @param deBridgeOrderId deBridge order ID for tracking
     * @param ipAsset IP asset used as collateral
     */
    function receiveCrossChainRoyaltyRepayment(
        uint256 orderId,
        uint256 repaymentAmount,
        bytes32 deBridgeOrderId,
        address ipAsset
    ) external nonReentrant {
        LendingOrder storage order = orders[orderId];
        require(order.funded, "Order not found or not funded");
        require(!order.repaid, "Already repaid");
        require(order.ipAsset == ipAsset, "IP asset mismatch");

        order.repaid = true;
        totalRepaid[order.token] += repaymentAmount;

        emit CrossChainRepaymentReceived(orderId, repaymentAmount, deBridgeOrderId);
    }

    /**
     * @notice Simulates deBridge order creation
     */
    function createDeBridgeOrder(
        StoryLoanRequest calldata loanRequest
    ) external returns (bytes32) {
        bytes32 orderId = keccak256(abi.encodePacked(
            loanRequest.loanId,
            loanRequest.borrower,
            block.timestamp
        ));

        emit DeBridgeOrderCreated(orderId, loanRequest.amount, loanRequest.borrower, STORY_CHAIN_ID);
        
        return orderId;
    }

    function addLiquidity(address token, uint256 amount) external onlyOwner {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
    }

    function setSupportedToken(address token, bool supported) external onlyOwner {
        supportedTokens[token] = supported;
    }

    function getOrder(uint256 orderId) external view returns (LendingOrder memory) {
        return orders[orderId];
    }

    function getLiquidity(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function getTotalStats(address token) external view returns (uint256 lent, uint256 repaid, uint256 outstanding) {
        lent = totalLent[token];
        repaid = totalRepaid[token];
        outstanding = lent - repaid;
    }
}
