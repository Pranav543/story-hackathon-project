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
        destinationChainId = 100000013, // Story
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
        destinationChainId = 100000013,
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
