Okay great now smart contract is working and the current test suits is also working. Now we will integrate Debridge completely end to end. Below are the required latest Debridge docs:

deBridge Hooks is a core feature of the DLN protocol that allows users, protocols, and market makers to attach arbitrary on-chain actions to the orders that would get executed upon their fulfillment.

The DLN protocol allows users to place cross-chain orders with an arbitrary on-chain action attached as an inseparable part of it, enabling cryptographically signed operations to be performed on the destination chain upon order fulfillment.

An action itself — called a hook — is a raw destination chain-specific data, that represents either an instruction (or a set of instructions) to be executed on Solana, or a hook enriched with a custom payload, or even a transaction call to be executed on a EVM-based chain. A hook can perform actions of any complexity, including operations on the outcome of the order. This effectively enriches the interactions between users and protocols, enabling cross-chain communications that were not possible before. A few possible use cases:

asset distribution: one can place a cross-chain order that buys an asset and immediately distributes it across a set of addresses;

blockchain abstraction: a dApp can place a cross-chain order that buys an asset and deposits it onto the staking protocol on behalf of a signing user;

user onboarding: a service can place a cross-chain order (from a user's familiar blockchain to a blockchain a user has not tried before) that buys a stable coin and tops up user's wallet with a small amount of native blockchain currency to enable the user to start submitting transactions right away;

action triggers: a cross-chain order could trigger conditional actions that emit events, change state, even to prevent an order from being filled;

and anything else you might thought about!

Additionally, a hook is bundled with a bunch of properties (hook metadata) that define hook behavior.

Information passed through hooks is non-authenticated by default, so you can't know who was the real sender unless you pass an authenticated signature in the hook itself, and verify the signature in the called program/smart contract.

In case you need to authenticate a smart contract as a sender, you must use the deBridge messaging protocol.

Hooks are a part of an order
Orders are identified by deterministic order ID, and the hash of the hook's raw data is essentially a part of this ID (see the last two fields of the deterministic order ID reference), so once a user signs-off an order with a hook, he eventually makes a cryptographic confirmation that he is willing to sell input asset for output asset AND execute a specific action along with the output asset on the destination chain.

The proper execution of the hook during order fulfillment is guaranteed by DlnDestination — the DLN smart contract responsible for filling orders, which ensures that the given hook along with other properties of the order actually matches the given order ID. This means that trying to spoof a hook would lead to a different ID of a non-existent order, so the solver is compelled to pass specific hook data, otherwise, he won't be able to unlock liquidity in the source chain upon fulfillment.

Hooks are trustless
DLN is an open market, so anyone can place arbitrary orders (even non-profitable, or having fake hooks), and anyone with available liquidity can be a solver and fill any open order. The  DlnDestination smart contract simply ensures that the requested amount is provided in full and further forwarded either to the recipient or to a hook's target (via the DlnExternalCallAdapter smart contract). This means that a hook's target should be designed with an assumption that anyone can place and fill arbitrary orders with arbitrary hooks, and thus never expose permissions only on the fact that the caller is a trusted DLN contract because the DLN contract here is only an intermediary, not a guard.

Hooks atomicity
Even though hooks are an inseparable part of DLN orders, their execution scenario is a matter of hook configuration. 

Hooks can be success-required and optional-success:

success-required hooks ARE REQUIRED to finish successfully. If the hook gets reverted, the entire transaction gets reverted as well, which is guaranteed by the DLN smart contract. 

optional-success hooks ARE ALLOWED to fail. In the event of failure, the DLN smart contract would send the order's outcome further to the fallback address specified as a part of a hook envelope.

Hooks can be atomic and non-atomic: 

atomic hooks ARE REQUIRED to be executed atomically along with the order fulfillment. In other words, the order with such a hook is either filled and the hook is executed, or not at all. Mind that if the hook is an success-required hook and it fails, the entire order would not get filled, and the order's authority would need to cancel the order. 

If the hook is a success-optional hook and its' execution fails, then the order would get filled, and the order's outcome would get sent further to the fallback address specified as a part of a hook envelope.

non-atomic hooks ARE ALLOWED (but not required) to be executed later, which is up to the solver who fills the order. If the solver fills the order but does not execute a hook, the order is marked is filled, but its outcome is stored securely in the DLN intermediary contract along with the hook, waiting until anyone (an arbitrary third party, like a solver) initiates a transaction to execute the hook, OR until the trusted authority of an order on the destination chain cancels the hook to receive the order's outcome in full.

Smart contracts on the EVM-based chains support all the options above. Smart contracts on Solana only support non-atomic success-required hooks due to the limitations of the chain.

Hook cancellation policy
Even though hooks are an indivisible part of orders placed onto DLN, their execution and cancellation flow may vary.

Atomic hooks are executed along with an order fulfillment, so they either succeed, or silently fail (if they are optional-success hooks), or revert and prevent the order from getting filled (if they are success-required hooks). In the worst-case scenario, when they get reverted, the assigned authority of an order in the destination chain may only cancel the entire order.

Non-atomic hooks are allowed to be executed later in a separate transaction after an order gets filled. In this case, the hook (along with the outcome of an order) remains pending execution in the intermediary smart contract, and the trusted authority of an order on the destination chain may cancel the hook and receive the order's outcome in full.

Who pays for hook execution?
Submitting a transaction to execute a hook implies paying a transaction fee. The deBridge Hooks engine provides two distinct ways to incentivize solvers and other trustless third parties to submit transactions to execute hooks.

The most straightforward way to cover hook execution is to lay the cost in the spread of an order: say, there is an order to sell 105 USDC on Solana and buy 100 USDC on Ethereum with a hook that deposits the bought amount to the LP: in this case, the difference between sell amount and buy amount (5 USDC) must cover all the fees and costs, including the cost of this hook execution. This is the preferred approach for atomic hooks that target EVM-based chains because in this case, the hook is part of the execution flow of a transaction that fills the order. 

Additionally, hook metadata may explicitly define a reward that the deBridge Hooks engine contract should cut off from the order's outcome (before the outcome is transferred to a hook) in favor of a solver who pays for a transaction: for example, there could be an order to sell 106 USDC on Ethereum, buy 101 USDC on Solana with a hook that deposits exactly 100 USDC to the LP and leaves 1 USDC as a reward. This approach works for non-atomic hooks, and the smart contract guarantees that a solver would get exactly the specified amount of the outcome.

The DLN API simplifies a hook's cost estimation by automatically simulating transactions upon order creation.

Common pitfalls
A common source of frustration is a blockchain where a hook is expected to run: hooks are built for destination chains. For example, an order that sells SOL on Solana and buys ETH on Ethereum would get placed on Solana with the hook data encoded specifically for EVM, and vice versa.

Atomic success-required hooks that get reverted would prevent their orders from getting fulfilled, causing users' funds to stuck, which would require users to initiate a cancellation procedure. This increases friction and worsens the overall user experience, so it is advised to carefully test hooks, and estimate potential fulfillments before placing orders with such hooks in production. The API takes the burden of proper hook data validation, encoding, and hook simulation, ensuring that an order can get filled on the destination chain. 

Examples
Order from Ethereum to Solana with a non-atomic hook

Order from Ethereum to Polygon with an atomic success-required hook

Availability
deBridge Hooks are available on all supported blockchains. Hooks can be encoded programmatically while interacting directly with smart contracts or passed to the DLN API via a simple high-level interface.


Market and Limit Orders
The main trade-off of the deBridge Liquidity Network design is that order execution is not guaranteed in advance, just as it is not guaranteed by classical bridges based on liquidity pools, where a transaction may fail in the destination chain if slippage exceeds the slippage tolerance specified by the sender.

With the deBridge Liquidity Network Protocol, a transaction can’t fail on the destination chain. An order is either fulfilled or not fulfilled, and if it’s not fulfilled, it means there is no taker willing to take the order. This may happen due to the following reasons:

The order doesn’t generate sufficient profit for a taker. In this case, it’s a limit order that will be fulfilled as soon as market conditions will make it profitable

The order bears certain systemic risks. The advantage of the deBridge Liquidity Network Protocol is that it allows risks to be dynamically priced. Takers may not be willing to fulfill orders coming from chains where exploit or ecosystem-level hacks have happened. In this case, takers will expect a bigger premium laid into the spread of the order so that additional risks are compensated

Users can place orders to exchange any assets at any price, but if the order premium covers all overhead costs for takers and brings them a profit, they are economically incentivized to fulfill the order as fast as possible. In this case, this is a market order that will be settled shortly.

To facilitate the creation of market orders, deBridge provides a Quick Start Guide. Any integrator or an app can query the API in order to retrieve the recommended price for the order for their users and secure its immediate execution. The quote recommended by the API lays in a spread that includes a 4bps incentive for takers and covers overhead costs such as gas.

Joining the deBridge Liquidity Network Protocol as a Solver
Solvers perform active on-chain liquidity management by fulfilling limit orders created through DLN.

Check this Github Repository to learn more about how to get started as a Solver in DLN: https://github.com/debridge-finance/dln-taker

Solvers don't need to lock liquidity into pools, they always maintain ownership over their funds and have the sole ability to fulfill limit orders they deem profitable.

Minimization of volatility risks for Solvers
To minimize price fluctuation risks for takers, all transactions formed through DLN API automatically route any swap through the paired asset (USDC or ETH). For example, if the user wants to exchange a token (e.g. AAVE on Ethereum) for another volatile token (e.g. Matic on Polygon), then DLN API will form the transaction data where AAVE is pre-swapped into USDC, and a USDC->Matic DLN order is created in the same transaction.


On the destination chain, solvers may hold USDC or ETH on a balance sheet of their on-chain addresses and swap their asset into the token requested in the order (e.g. MATIC), and fulfill it in the same transaction. When DlnDestination.sendUnlock() is called, the solver will receive the same paired asset (e.g. USDC) on the source chain, avoiding any price fluctuations of volatile assets.


Integration Guidelines
Integration Overview
There are several ways to integrate deBridge into your dApp, wallet, or protocol, depending on the specific use case. This section provides a high-level overview of the available integration methods: API, Widget, and Smart Contracts.

DeBridge API
Recommended for most production-grade integrations
→ Learn more about the API

The DeBridge API is the most robust and flexible integration method, abstracting away the complexities of cross-chain trading, smart contract interactions, and blockchain infrastructure. It provides RESTful endpoints to quote, create, and manage trades throughout their lifecycle. This improves transaction success rates and user experience, while reducing engineering overhead.

Recommended if integrators:

Want full control over the UX/UI

Are building custom workflows or high-frequency trading logic

Need integration with backend infrastructure

Are targeting mobile-native or non-browser environments

Use cases:
Coming soon: examples such as exchange aggregators, non-custodial wallets, yield platforms, etc.

DeBridge Widget
Best for rapid integration and prototyping
→ Learn more about the Widget

The DeBridge Widget enables any web-based project to offer cross-chain swaps in minutes. It’s a pre-built UI component embeddable via iframe, fully customizable with themes, chains, tokens, and more. It also supports JavaScript-based event listeners and method calls for deeper interaction.

Recommended if integrators:

Want a fast time-to-market with minimal development effort

Don’t need custom UX or transaction logic

Are building a frontend-heavy app, or integrating within a website or mobile WebView

Want to prototype or test before deeper integration

Use cases:
Coming soon: examples such as token swap pages, DeFi frontends, portfolio dashboards, etc.

Smart Contract Integration (DLN Protocol)
Best for advanced and trustless DeFi integrations
→ Learn more about the DLN Protocol Smart Contracts

The DeBridge Liquidity Network (DLN) Protocol enables direct interaction with on-chain smart contracts to place and fulfill cross-chain limit orders. Developers can work directly with DlnSource and DlnDestination contracts for advanced decentralized workflows. This provides maximum flexibility, trustless execution, and fine-grained control.

Recommended if integrators:

Need a fully decentralized integration with no off-chain components

Are building a protocol-level feature (e.g., DEX, bridge aggregator)

Want to operate as a solver or liquidity provider

Need deterministic on-chain behavior and verifiability

Interacting with the API
This document contains an overview of the deBridge Liquidity Network API endpoints, giving readers an expedited understanding of how to get quotes, place, track and manage limit orders.

The DLN API provides developers an effortless way to interact with the DLN protocol and trade across chains in seconds with deep liquidity, limit orders, and protection against slippage and MEV. The API takes the burden off of building complex and sometimes painful interactions with blockchain RPCs and smart contracts by providing a complete set of RESTful endpoints, sufficient to quote, create, and manage trades during their whole lifecycle.

The DLN API resides at the domain name dln.debridge.finance

The DLN API Swagger could be found at https://dln.debridge.finance/v1.0

Additionally, a JSON representation of the API can be found here: dln.debridge.finance/v1.0-json


Creating an Order
The create-tx endpoint is intended to be used for both estimating and constructing order transactions. There are detailed breakdowns of parameters and the response fields.

We do recommend reading deeper into these articles, but if you want to get up and running, have a look at the quick start section. 

Swagger specs of create-tx can be found here.

Paired Quote and Transaction
The create-tx ednpoint is intentionally dual-purpose:

It estimates a realistic, market-aware outcome (estimation)

It constructs a ready-to-sign transaction (tx) whenever the call includes the necessary wallet data

This design intentionally removes the distinction between “get quote” and “build transaction” that exists in typical single-chain swap APIs.

A detailed parameter reference & field-by-field response breakdown lives in the API Parameters, API Response, and Estimation-Only sub-pages, while Swagger specs for create-tx can be explored here. For a hands-on walk-through, see the Quick Start section of the docs.

Why Quote and Transaction Are Paired
DLN works with intent-based orders that traverse two independent blockchains, two swaps, and several off-chain actors (API, solvers, validators). An accurate quote must already account for:

Source-chain liquidity and gas

Destination-chain liquidity and gas

A solver’s operating expenses and target margin

Short-term market volatility during the time the order is in flight

Generating that quote is the most computationally expensive step; producing the transaction payload afterwards is trivial. A “lightweight quote” would be misleading and would cause orders to be ignored by solvers.

How the `create-tx` Endpoint Behaves
Scenario
Returned fields
Typical use-case
All required fields present
(wallet connected, amounts known)

estimation and tx

Production trade flow

Wallet address missing
(connect-wallet screen, fiat on-ramp flow)

estimation only

Pre-trade previews, fiat on-ramp flows

If dstChainTokenOutRecipient, srcChainOrderAuthorityAddress, or dstChainOrderAuthorityAddress are absent, the API withholds tx. Recipient and authorities parameters are required for creating the transaction. Replay the same call once addresses are known to receive the full response pair.

Do Not Replay the Quote Into a Second Call
Passing the returned srcChainTokenInAmount and dstChainTokenOutAmount back to create-tx forces the endpoint into limit-order quoting strategy (both amounts fixed). Limit orders can drive solver profit negative, so they are typically ignored—use the original quote + transaction pair and let the user sign immediately.

Replay-and-fixing the amounts:

Converts a healthy market order into a potentially unattractive limit order

Slashes the fulfillment probability

Placing limit orders is fine but they can end up being unprofitable and remain unfilled. If more than ~30 seconds have passed, request a fresh quote-plus-transaction pair instead of re-using stale numbers. Profitable market orders are filled within seconds; unprofitable ones linger until they become profitable or the user cancels them.

Timing Guarantees
Quotes remain solvent if the paired transaction is signed and broadcast within ~30 seconds. Beyond that window:

Gas cost or price movements may exceed the solver’s margin.

Solvers will skip the order; users must cancel and retry.

For ERC-20 flows with prependOperatingExpenses=true, approve a slightly higher allowance (≈ +30 %) or approve infinity to avoid a second approval if operating expenses drift upward while the user is signing.

Example — Estimation and Full Pair
Copy
// 1. Preview (wallet not yet connected)
const preview = await fetch(
  '/dln/order/create-tx?srcChainId=56&srcChainTokenIn=<token_in_address>&srcChainTokenInAmount=1000000&' +
  'dstChainId=43114&dstChainTokenOut=<token_out_address>&dstChainTokenOutAmount=auto'
).then(data => data.json());

// preview.estimation is present; preview.tx is undefined.

// 2. User connects wallet; replay with authority/recipient addresses
const full = await fetch(
  '/dln/order/create-tx?srcChainId=56&srcChainTokenIn=<token_in_address>&srcChainTokenInAmount=1000000&' +
  'dstChainId=43114&dstChainTokenOut=<token_out_address>&dstChainTokenOutAmount=auto&' +
  'dstChainTokenOutRecipient=<user_address>&srcChainOrderAuthorityAddress=<user_address>&' +
  'dstChainOrderAuthorityAddress=<user_address>'
).then(data => data.json());

// full.estimation and full.tx are now present.
// Sign full.tx within 30 s for >99.9 % fill probability.
Key Takeaways
One endpoint, one response—never separate quote retrieval from transaction generation.

The estimate/transaction pair maximizes fulfillment probability by eliminating UI-induced latency.

When wallet addresses are unknown, call create-tx for estimation only, then repeat once addresses are set.

Re-using quoted amounts in a second request reduces the likelihood of order fulfillment and should be avoided.

Following this pattern ensures that orders hit the network with fresh spreads, remain attractive to solvers, and settle cross-chain in seconds.

Quick Start
Disclaimer

The provided code is available as-is, with no assurances of functionality. We are not liable for any damages that may result from its execution.

Overview
This repository serves as a practical resource for integrators aiming to get started with hands-on examples of using the DeBridge Liqudity Network protocol via API.

More details on submitting chain-specific orders can be found here.

EVM
Included is a comprehensive TypeScript script demonstrating the transfer of 0.1 USDC from Polygon to Arbitrum. The script outlines all necessary steps for completing a cross-chain swap between the two networks. It also includes examples for executing the approve function on ERC-20 tokens and showcases various deBridge API integrations.

API Parameters
0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045Below is a succinct breakdown of the parameters used in the create-tx API endpoint. Detailed descriptions and usage examples are provided in dedicated subpages.

Directional Parameters
These parameters define the origin and destination of the transaction, including the assets being sold on the source chain and the assets being purchased on the destination chain.

Parameter
Example value
Description
srcChainId

56

The internal chainId of the supported source chain. 

srcChainTokenIn

0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d

Input asset address (what the user sells)

dstChainId

43114

The internal chainId of the supported destination chain.

dstChainTokenOut

0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7

Output asset address (what the user buys)

Offer Parameters
These parameters specify the amounts of tokens to be sold and received. The API can also be configured to automatically determine the output amount to ensure a reasonably profitable market order.

Parameter
Example value
Description
srcChainTokenInAmount

100000000000000000000 

 or

auto 

The amount of input token the user is selling, with decimals. It can be set to auto as well, but make sure to set the amount of output token in that case.

dstChainTokenOutAmount

auto 

or

100000000000000000000 

The amount of output token the user is buying. It is recommended to let the API calculate the reasonable outcome by setting this parameter to auto, otherwise you are risking the created order being ignored by solvers and stuck until cancelled.

prependOperatingExpense

true

Recommended for better user experience. Moves the calculated amount of operating expenses out of the spread and adds it on top the amount of input token.

Authorities and recipient address
These optional parameters define which entities are authorized to cancel or modify the order, as well as the recipient of the funds upon fulfillment. Typically, user wallet addresses are used.

These parameters are optional, making it possible to use the create-tx endpoint even before a wallet address is available—e.g., before a user connects a wallet in a dApp. However, in such cases, the API will not return a transaction payload that can be signed and submitted to the blockchain.

Ensure that the address specified for dstChainOrderAuthorityAddress is accessible to the user. Otherwise, the order and its associated funds may become permanently inaccessible if the user cannot cancel it.

Estimation-Only
The create-tx endpoint is designed for both estimation and transaction construction. It can be safely called without specifying authority or recipient addresses when a wallet address is not yet available—for example, during early stages of interaction in a dApp. In such cases, the endpoint can still be used to suggest input or output token amounts.

Once the wallet address becomes available, the same create-tx request can be repeated with the necessary parameters to retrieve a full transaction call.

To maintain solver profitability and ensure the order remains valid upon submission, it is recommended to allow the API to compute a reasonable output amount. This is achieved by setting the dstChainTokenOutAmount parameter to auto in both the estimation and transaction calls.

Additionally, orders should be submitted within 30 seconds of retrieving the transaction from the API. This expiration window helps ensure the order remains profitable for solvers at the time of on-chain placement.

prependOperatingExpenses
The end-user implications of `prependOperatingExpenses`.

The prependOperatingExpenses setting is a boolean. It is recommended to enable this option:

Copy
prependOperatingExpenses = true
Enabled (prependOperatingExpenses=true)
When enabled, operating expenses are calculated separately from the spread and added on top of the input token amount, making all fees fully transparent. This approach helps clarify exactly what is being paid in fees.

For example, swapping 100 USDC on Arbitrum for 100 USDC on Polygon in our application displays a small fee (just over $0.03), shown above the red line in the figure below. This represents the solver's operating expenses.


DeBridge app trading view, demonstrating prependOperatingExpenses=true
ERC20 Approval: The total amount (including operating expenses) must be approved using the approve function. This value is provided in response.estimation.srcChainTokenIn.amount.

Buffer Recommendations: Estimates may need to be refreshed if there is a delay between generating the response and submitting response.tx. Updated operating expenses might require a new approval. Additional guidance is available in this article.

Fulfillment Likelihood: When response.tx is signed and submitted within 30 seconds, the probability of successful execution is over 99.9%.

Disabled (prependOperatingExpenses=false)
When disabled, response.estimation.srcChainTokenIn.amount equals the srcChainTokenInAmount specified in the original create-tx request. In this case, operating expenses are subtracted directly from the spread between the input value and response.estimation.dstChainTokenOut.

Both modes produce the same execution outcome, but enabling prependOperatingExpenses typically provides a clearer breakdown of the fee structure for end users.

API Response
Detailed descriptions of the `create-tx` API response structure.

There are several sections to a create-tx response. You can see a full, real-world API response example here. They are:

estimation contains gas and fee-related estimates used in the transaction planning process.

This response field is always present. Represents the structure of what the user wants to sell on the source chain.

Field name
Type
Description
address 

string

Source chain input asset address - what the user is trying to sell on the source chain.

chainId 

integer

Source chain id.

decimals 

integer

Source chain input asset decimals. 

name 

string

Source chain input asset name.

symbol 

string

Source chain input asset symbol.

amount 

string

Source chain input asset amount, taking the decimals into account.

It will be different from the srcChainTokenInAmount if the request had prepended operating expenses. If it had, this will be the amount to use in the approve call.

approximateOperatingExpense 

string

Solver's operating expense for this swap.

mutatedWithOperatingExpense 

boolean

Signifies if the request had prepended operating expenses.

approximateUsdValue 

integer

Approximate USD value of the source chain input assets. Informative purposes only - not for real-time trading.

originApproximateUsdValue

integer

Approximate USD value of the source chain input assets. Informative purposes only - not for real-time trading. 

This response field is only present if the source chain input assets were not reserve assets.

Field name
Type
Description
address 

string

Source chain output asset address - what the source chain input asset was swapped for in the pre-swap.

This asset will be used for cross-chain settlement, and what the solver fulfilling the order will receive. This is also the asset that the user will receive if the order is cancelled.

chainId 

integer

Source chain id.

decimals 

integer

Source chain output asset decimals. 

name 

string

Source chain output asset name.

symbol 

string

Source chain output asset symbol.

amount 

string

Source chain output asset amount, taking the decimals into account.

maxRefundAmount

string

Solver's operating expense for this swap.

approximateUsdValue 

integer

Approximate USD value of the input assets. Informative purposes only - not for real-time trading.

This response field is always present. Represents the structure of what the user wants to buy on the destination chain.

Field name
Type
Description
address 

string

Destination chain output asset address - what the user wants to receive when the order is fulfilled.

chainId 

integer

Destination chain id.

decimals 

integer

Destination chain output asset decimals. 

name 

string

Destination chain output asset name.

symbol 

string

Destination chain output asset symbol.

amount 

string

Destination chain output asset amount, taking the decimals into account.

recommendedAmount

string

Destination chain output asset amount, taking the decimals into account.

approximateUsdValue

integer

recommendedApproximateUsdValue

integer

An array describing the cost components associated with the trade. Possible entry types include: 

PreSwap 

PreSwapEstimatedSlippage 

DlnProtocolFee

TakerMargin

EstimatedOperatingExpenses

AfterSwap

AfterSwapEstimatedSlippage

tx

data is the data that must be signed and submitted. It contains all necessary information to initiate a cross-chain order, including cases involving non-reserve assets.  It is either a calldata (for EVM-based chains) or a serialized transaction (for Solana)

to is a destination address for the transaction. Acts as the spender in the approve call for ERC-20 tokens. Applicable to EVM source chains only. 

value is a flat fee in the source chain's native currency charged by the DLN protocol. Applicable to EVM source chains only.

prependedOperatingExpenseCost is the estimated operating cost added to the transaction, adjusted for token decimals. Present only if the request was made with prependOperatingExpenses enabled.  

order is an object containing details required to facilitate the cross-chain trade.

approximateFulfillmentDelay

 Estimated delay, in seconds, for the order to be fulfilled.

salt 

Randomized value used to ensure uniqueness in the order hash.

metadata 

Additional contextual information about the order.

orderId

A deterministic identifier for the order. The same ID is used on both source and destination chains and can be used to track order status.

fixFee 

Flat fee charged in the source chain's native currency. This matches tx.value for EVM-based chains. 

userPoints

The number of deBridge points that the user will get for this trade.

integratorPoints 

The number of deBridge points that the integrator will get for this trade.


JSON Example
If we take a look at request below, where we are trading 1000 ARB on Arbitrum for Matic on Polygon, it will produce the following JSON response.

{
  "estimation": {
    "srcChainTokenIn": {
      "address": "0x912ce59144191c1204e64559fe8253a0e49e6548",
      "chainId": 42161,
      "decimals": 18,
      "name": "Arbitrum",
      "symbol": "ARB",
      "amount": "1000097362178910640486",
      "approximateOperatingExpense": "97362178910640486",
      "mutatedWithOperatingExpense": true,
      "approximateUsdValue": 337.491121850529,
      "originApproximateUsdValue": 337.458266178442
    },
    "srcChainTokenOut": {
      "address": "0xaf88d065e77c8cc2239327c5edb3a432268e5831",
      "chainId": 42161,
      "decimals": 6,
      "name": "USD Coin",
      "symbol": "USDC",
      "amount": "336778910",
      "maxRefundAmount": "1182866",
      "approximateUsdValue": 336.77891
    },
    "dstChainTokenOut": {
      "address": "0x0000000000000000000000000000000000000000",
      "chainId": 137,
      "decimals": 18,
      "name": "Polygon",
      "symbol": "MATIC",
      "amount": "1414379129275580318365",
      "recommendedAmount": "1414379129275580318365",
      "maxTheoreticalAmount": "1427196423556434769924",
      "approximateUsdValue": 334.305266698456,
      "recommendedApproximateUsdValue": 334.305266698456,
      "maxTheoreticalApproximateUsdValue": 337.334786078531
    },
    "costsDetails": [
      {
        "chain": "42161",
        "tokenIn": "0x912ce59144191c1204e64559fe8253a0e49e6548",
        "tokenOut": "0xaf88d065e77c8cc2239327c5edb3a432268e5831",
        "amountIn": "1000097362178910640486",
        "amountOut": "337961776",
        "type": "PreSwap"
      },
      {
        "chain": "42161",
        "tokenIn": "0xaf88d065e77c8cc2239327c5edb3a432268e5831",
        "tokenOut": "0xaf88d065e77c8cc2239327c5edb3a432268e5831",
        "amountIn": "337961776",
        "amountOut": "336778910",
        "type": "PreSwapEstimatedSlippage",
        "payload": {
          "feeAmount": "1182866",
          "feeBps": "35",
          "estimatedVolatilityBps": "35"
        }
      },
      {
        "chain": "42161",
        "tokenIn": "0xaf88d065e77c8cc2239327c5edb3a432268e5831",
        "tokenOut": "0xaf88d065e77c8cc2239327c5edb3a432268e5831",
        "amountIn": "336778910",
        "amountOut": "336644199",
        "type": "DlnProtocolFee",
        "payload": {
          "feeAmount": "134711",
          "feeBps": "4",
          "feeApproximateUsdValue": "0.134711"
        }
      },
      {
        "chain": "137",
        "tokenIn": "0x3c499c542cef5e3811e1192ce70d8cc03d5c3359",
        "tokenOut": "0x3c499c542cef5e3811e1192ce70d8cc03d5c3359",
        "amountIn": "336644199",
        "amountOut": "336509542",
        "type": "TakerMargin",
        "payload": {
          "feeAmount": "134657",
          "feeBps": "4"
        }
      },
      {
        "chain": "137",
        "tokenIn": "0x3c499c542cef5e3811e1192ce70d8cc03d5c3359",
        "tokenOut": "0x3c499c542cef5e3811e1192ce70d8cc03d5c3359",
        "amountIn": "336509542",
        "amountOut": "336476680",
        "type": "EstimatedOperatingExpenses",
        "payload": {
          "feeAmount": "32862"
        }
      },
      {
        "chain": "137",
        "tokenIn": "0x3c499c542cef5e3811e1192ce70d8cc03d5c3359",
        "tokenOut": "0x0000000000000000000000000000000000000000",
        "amountIn": "336476680",
        "amountOut": "1422201236073987248230",
        "type": "AfterSwap",
        "payload": {
          "amountOutBeforeCorrection": "1422201236073987248230"
        }
      },
      {
        "chain": "137",
        "tokenIn": "0x0000000000000000000000000000000000000000",
        "tokenOut": "0x0000000000000000000000000000000000000000",
        "amountIn": "1422201236073987248230",
        "amountOut": "1414379129275580318365",
        "type": "AfterSwapEstimatedSlippage",
        "payload": {
          "feeAmount": "7822106798406929865",
          "feeBps": "55",
          "estimatedVolatilityBps": "55"
        }
      }
    ],
    "recommendedSlippage": 0.9
  },
  "tx": {
    "value": "1000000000000000",
    "data": "0x4d8160ba000000000000000000000000912ce59144191c1204e64559fe8253a0e49e654800000000000000000000000000000000000000000000003637239428a726d96600000000000000000000000000000000000000000000000000000000000001400000000000000000000000006131b5fae19ea4f9d964eac0408e4408b66337b50000000000000000000000000000000000000000000000000000000000000160000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e5831000000000000000000000000000000000000000000000000000000001412d69e00000000000000000000000055a8f5cce1d53d9ff84ec0962882b447e5914db8000000000000000000000000ef4fb24ad0916217251f553c0596f8edc630eb660000000000000000000000000000000000000000000000000000000000000940000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007a4e21fd0e90000000000000000000000000000000000000000000000000000000000000020000000000000000000000000c7d3ab410d49b664d03fe5b1038852ac852b1b29000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000002a000000000000000000000000000000000000000000000000000000000000004e000000000000000000000000000000000000000000000000000000000000001c402020000003d0200000011d53ec50bc8f54b9357fbfe2a7de034fc00f8b3000000000000000d8dc8e50a29c9b65e0100000000000000000000000000000000000000000a0000002e020000006f38e884725a116c9c7fbf208e79fe8828a2595f010100000000000000000000000000000001000276a40a020000003d020000006ce9bc2d8093d32adde4695a4530b96558388f7e0000000000000028a95aaf1e7d5d23080100000000000000000000000000000000000000000a0000006102000000b1026b8e7276e7ac75410f1fcbbe21796e8f7526af88d065e77c8cc2239327c5edb3a432268e5831010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010009046d15912ce59144191c1204e64559fe8253a0e49e6548af88d065e77c8cc2239327c5edb3a432268e5831663dc15d3c1ac63ff12e45ab68fea3f0a883c25100000000000000000000000068151dea000000540000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001510000000000000000000000001424e3304f82e73edb06d29ff62c91ec8f5ff06571bdeb2900000000000000000000000000000000000000000000000000000000000000000000000000000000912ce59144191c1204e64559fe8253a0e49e6548000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e5831000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000001a000000000000000000000000000000000000000000000000000000000000001e00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000663dc15d3c1ac63ff12e45ab68fea3f0a883c25100000000000000000000000000000000000000000000003637239428a726d966000000000000000000000000000000000000000000000000000000001412d69d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000c7d3ab410d49b664d03fe5b1038852ac852b1b29000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000003637239428a726d96600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002707b22536f75726365223a2264654272696467652d346663642d396531662d393161373561343166333562222c22416d6f756e74496e555344223a223333382e3534393433323535393439343835222c22416d6f756e744f7574555344223a223333382e3436323735373036353236383134222c22526566657272616c223a22222c22466c616773223a302c22416d6f756e744f7574223a22333337393631373736222c2254696d657374616d70223a313734363231333137382c22526f7574654944223a2264356636393531372d343162362d346237632d616435302d623032663132313261373130222c22496e74656772697479496e666f223a7b224b65794944223a2231222c225369676e6174757265223a22634552725149787330784b50584d3670726d4c484f4e553757324b762b365839646a6c4b385a6972746361762b66617a744c46646e33775a2f6c5277317533487a4d5649554d7a65507a567476303663782b386742754174594651714f626e6159624d6d6b7774786e6848346b4a336c3278544f733134457639585735386b54757069496c48494f7a565479644f4a693838707238746c753534757353514b55453142707353356a35456651415577303137626271384b557670496943346f685050506b66514d33457a4c575a3362427976504367646e6442332f4444597433544e5970525262474e36476e623375664a682f5a696e4f3749666d49587576625a5046316a335a2f77327a333655774d495866732f334142333376774d5a6d4d4f2b7747774637696c5a7a3770783865646336695a5939672b5368735852354a37794f4e467072773674495831652b674757464637513d3d227d7d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000424b930370100000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000196926a90a000000000000000000000000000000000000000000000000000000000000003600000000000000000000000000000000000000000000000000000000000007c3d000000000000000000000000000000000000000000000000000000000000038000000000000000000000000000000000000000000000000000000000000003a0000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e5831000000000000000000000000000000000000000000000000000000001412d69e000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000004cac74145fd542829d000000000000000000000000000000000000000000000000000000000000008900000000000000000000000000000000000000000000000000000000000001a000000000000000000000000055a8f5cce1d53d9ff84ec0962882b447e5914db800000000000000000000000000000000000000000000000000000000000001e000000000000000000000000000000000000000000000000000000000000002200000000000000000000000000000000000000000000000000000000000000260000000000000000000000000000000000000000000000000000000000000028000000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001455a8f5cce1d53d9ff84ec0962882b447e5914db8000000000000000000000000000000000000000000000000000000000000000000000000000000000000001455a8f5cce1d53d9ff84ec0962882b447e5914db80000000000000000000000000000000000000000000000000000000000000000000000000000000000000014555ce236c0220695b68341bc48c68d52210cc35b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000042010100000066d986c862e659010000000000000000000000009d8242d55f1474ac4c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
    "to": "0x663DC15D3C1aC63ff12E45Ab68FeA3F0a883C251"
  },
  "prependedOperatingExpenseCost": "97362178910640486",
  "order": {
    "approximateFulfillmentDelay": 3,
    "salt": 1746213179552,
    "metadata": "0x010100000066d986c862e659010000000000000000000000009d8242d55f1474ac4c0000000000000000000000000000000000000000000000000000000000000000"
  },
  "orderId": "0x19499ede9b21fa5cc0ce5f74a155482576ff7d85b51863fb5231dbf648300b6a",
  "fixFee": "1000000000000000",
  "userPoints": 198.47,
  "integratorPoints": 49.62
}

Refreshing Estimates
It is recommended that transactions returned by the create-tx API be signed and submitted within 30 seconds. When response.tx is submitted within this window, the likelihood of successful order execution exceeds 99.9%.

There is no explicit time-to-live (TTL) on the transaction itself—that is, the period between receiving the create-tx API response and submitting it on-chain. Transactions may remain valid for extended periods, especially when no pre-order-swap is involved or when the pre-order-swap is between stablecoins.

Handling Operating Expense Fluctuations 
When the prependOperatingExpenses parameter is enabled, special attention must be paid to how token approval amounts are set. If the allowance exactly matches response.estimation.srcChainTokenIn.amount and there is a delay—typically more than a minute—before submitting response.tx, operating expenses may increase. In this case, the estimate should be refreshed. If the updated expense exceeds the approved amount, an additional approval step is required, degrading the experience.

To prevent this, it is recommended to set the token allowance to infinity. When a finite allowance is required, it is advisable to include a buffer—commonly around 30%—to absorb any increase in gas costs or execution fees between approval and submission.

Copy
const { approximateOperatingExpense } = response.estimation.srcChainTokenIn;
const approveAmount = srcChainTokenInAmount + approximateOperatingExpense * 1.3;
This ensures that the approved amount remains sufficient, even if costs rise slightly before the transaction is broadcast.

Quoting Strategies
Quoting strategies supported by DLN, explaining how source and destination amounts are configured for each strategy, with guidance on when to use each.

DLN supports multiple quoting strategies that allow users to control how much is spent on the source chain and how much is received on the destination chain. Each strategy is expressed by how the srcChainTokenInAmount and dstChainTokenOutAmount fields are set in the order input. 

Below is an overview of all currently supported quoting strategies.

Market Order
Copy
const orderInput: deBridgeOrderInput = {
    ...,
    srcChainTokenInAmount: "<fixed_amount>",
    dstChainTokenOutAmount: "auto",
    ...
}
This is the default and most commonly used quoting strategy. It specifies an exact source amount to be transferred, while allowing the protocol to calculate the best possible amount to be received on the destination chain based on current market conditions and solver competition.

Recommended for most standard transfers

srcChainTokenInAmount must be set to a concrete numeric value

dstChainTokenOutAmount must be set to "auto"

Market Order with Full Balance Utilization
Copy
const orderInput: deBridgeOrderInput = {
    ...,
    srcChainTokenInAmount: "max",
    dstChainTokenOutAmount: "auto",
    ...
}
This strategy attempts to spend the full wallet balance of the source token. It is useful when the intention is to "empty" the source wallet of a given asset, such as in account abstraction flows, automated batch processing, or non-custodial smart wallets.

srcChainTokenInAmount must be set to max

dstChainTokenOutAmount must be set to "auto"

Reverse Market Order
Copy
const orderInput: deBridgeOrderInput = {
    ...,
    srcChainTokenInAmount: "auto",
    dstChainTokenOutAmount: "<fixed_amount>",
    ...
}
This strategy specifies a desired amount to be received on the estination chain, and allows the protocol to determine how much must be spent on the source chain to fulfill the request. It is commonly used in cases where a precise destination amount is required, such as payments or on-chain contract interactions.

`srcChainTokenInAmount` must be set to "auto"

dstChainTokenOutAmount must be set to a concrete numeric value

Limit Order (Not Recommended)
Copy
const orderInput: deBridgeOrderInput = {
    ...,
    srcChainTokenInAmount: "<fixed_amount>",
    dstChainTokenOutAmount: "<fixed_amount>",
    ...
}
This strategy attempts to enforce both the source amount to be sent and the destination amount to be received. It effectively functions as a limit order, and will only be fulfilled if a solver is willing to match both values.

High likelihood of non-fulfillment if the order is unattractive to solvers

Not recommended for production usage

Both srcChainTokenInAmount and dstChainTokenOutAmount must be concrete values

Example: Order Input Structure
All quoting strategies use the same order input interface, with key fields adjusted per strategy:

Copy
  const arbUsdcAddress = "0xaf88d065e77c8cc2239327c5edb3a432268e5831";
  const bnbUsdcAddress = "0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d";
  const usdcDecimals = 18; // BNB USDC has 6 decimals
  const amountToSend = "0.01"; // The amount of USDC to send

  const amountInAtomicUnit = ethers.parseUnits(amountToSend, usdcDecimals);

  const orderInput: deBridgeOrderInput = {
    srcChainId: '56', // BNB Chain Id
    srcChainTokenIn: bnbUsdcAddress,
    srcChainTokenInAmount: amountInAtomicUnit.toString(),
    dstChainTokenOutAmount: "auto",
    dstChainId: '42161', // Arbitrum Chain Id
    dstChainTokenOut: arbUsdcAddress,
    dstChainTokenOutRecipient: wallet.address,
    account: wallet.address,
    srcChainOrderAuthorityAddress: wallet.address,
    dstChainOrderAuthorityAddress: wallet.address,
    referralCode: 31805 // Optional
    // ... Other optional parameters
  };
Choosing a Stratrgy
Use Case
Recommended Strategy
Standard transfer with known input

Market Order

Full wallet balance transfer

Market Order with Full Balance

Target fixed destination output

Reverse Market Order

Exact 1-to-1 trade with specific terms

Limit Order (not recommended)


Monitoring Orders
Once an order has been successfully created on-chain, its state can be monitored using several available methods, depending on the use case. For a full overview of order states and their transitions, refer to the Order States documentation. 

Key Completion States
Orders progress through multiple internal states. However, from the perspective of the end-user experience, the following states indicate successful completion:

Fulfilled 

SentUnlock 

ClaimedUnlock

Any of these states can be treated as successfully completed final state for application-level logic.

Quick Start
Base URL:https://stats-api.dln.trade 

Full endpoint reference:  Swagger and Redoc

Examples: See the implementation examples in this GitHub repository.

Querying Orders
By Wallet Address
The POST /api/Orders/filteredList endpoint retrieves the current state and historical data for all orders associated with a wallet address. This endpoint is also used to populate the trade history view in deExplorer, which can serve as a reference implementation. Pagination is supported via skip and take parameters.

Example: Fetching Completed Orders for a Wallet
Copy
const URL = 'https://stats-api.dln.trade/api/Orders/filteredList';

const requestBody = {
  orderStates: ['Fulfilled', 'SentUnlock', 'ClaimedUnlock' ],
  externalCallStates: ['NoExtCall'],
  skip: 0,
  take: 10,
  maker: '0x441bc84aa07a71426f4d9a40bc40ac7183d124b9',
};

const data = await post(URL, requestBody);
Example: Filtering Completed Orders by Destination Chain (e.g. HyperEVM)
Copy
const requestBody = {
    giveChainIds: [],
    takeChainIds: [100000022], // HyperEVM Chain Id
    orderStates: ['Fulfilled', 'SentUnlock', 'ClaimedUnlock' ],
    externalCallStates: ['NoExtCall'],
    skip: 0,
    take: 10,
    maker: '0x441bc84aa07a71426f4d9a40bc40ac7183d124b9',
  };
By Transaction Hash
For inspecting a specific order, the GET /api/Orders/creationTxHash/{hash}  endpoint returns full order details as shown on the deExplorer order page.

Example:

https://stats-api.dln.trade/api/Orders/creationTxHash/0x3fe11542154f53dcf3134eacb30ea5ca586c9e134c223e56bbe1893862469bc5

If multiple orders were created in a single transaction, this endpoint returns data only for the first order.

Multiple orders created in the same transaction
In cases where multiple orders are created in a single transaction, retrieve all order IDs using GET /api/Transaction/{hash}/orderIds .

For example, the transaction0x40ee524d5bb9c4ecd8e55d23c66c5465a3f137be7ae24df366c3fd06daf7de7e has been submitted to the BNB Chain. Calling the endpoint:

https://stats-api.dln.trade/api/Transaction/0x40ee524d5bb9c4ecd8e55d23c66c5465a3f137be7ae24df366c3fd06daf7de7e/orderIds

The response is an array, even if the transaction resulted in only one order:

Copy
{
    "orderIds": [
        "0x9ee6c3d0aa68a7504e619b02df7c71539d0ce10e27f593bf8604b62e51955a01"
    ]
}
An array instead of a single orderId is returned because a top-level transaction may perform several calls to DLN, thus leading to multiple orders being created.

Example:
Copy
export async function getOrderIdByTransactionHash(txHash: string) {
  const URL = `https://stats-api.dln.trade/api/Transaction/${txHash}/orderIds`;

  const response = await fetch(URL);
  
  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(
      `Failed to get orderIds by transaction hash: ${response.statusText}. ${errorText}`,
    );
  }

  const data = await response.json();

  if (data.error) {
    throw new Error(`DeBridge API Error: ${data.error}`);
  }

  return data;
}
By orderId
The orderId is a deterministic identifier returned in the create-tx response or retrievable via the transaction hash. 

An order state can be monitored directly by using GET /api/Orders/{orderId} .

Example:

https://stats-api.dln.trade/api/Orders/0x9ee6c3d0aa68a7504e619b02df7c71539d0ce10e27f593bf8604b62e51955a01

Response:

Copy
{
    "status": "ClaimedUnlock"
}
Example:
Copy
export async function getOrderStatusByOrderId(orderId: string) {
  const URL = `https://stats-api.dln.trade/api/Orders/${orderId}`

  const response = await fetch(URL);
  
  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(
      `Failed to get order status by orderId: ${response.statusText}. ${errorText}`,
    );
  }

  const data = await response.json();

  if (data.error) {
    throw new Error(`DeBridge API Error: ${data.error}`);
  }

  return data;
}
Affiliate Fee Settlement
If set during order creation, the affiliate fee is automatically transferred to the affiliateFeeRecipient once the order reaches the ClaimedUnlock status.

Order States
Order states explained. Order lifecycle state-machine diagram.

In the figure below, the order states are represented in a state-machine diagram, with the actions that trigger each state transition. 


Order states, state-machine diagram
According to the DLN API, an order must be in one of these states:

State
Description
Created

An order placed by a user on the DLN is pending fulfillment.

Fulfilled

The order on the destination chain has been completed by a solver. The full amount of the requested assets has been successfully transferred to the dstChainTokenOutRecipient

SentUnlock

After fulfilling the order, the solver initiates the unlock procedure on the destination chain. A cross-chain message is sent via DMP to unlock the input assets locked on the source chain.

ClaimedUnlock

The unlock process is finalized, and the solver receives the input assets. The affiliate fee is directed to the affiliateFeeRecipient on the source chain. 

OrderCancelled

The dstChainOrderAuthorityAddress has started the cancellation process on the destination chain. 

SentOrderCancel

A cross-chain message is sent via DMP from the destination to the source chain. It unlocks the input assets on the source chain to be claimed by the srcAllowedCancelBeneficiary.

ClaimedOrderCancel

The source chain input assets have been claimed by the srcAllowedCancelBeneficiary. The cancel procedure is finalized.

If an order is either in Fulfilled, SentUnlock, or ClaimedUnlock states, it can be displayed as fulfilled for the end-user.

Integrating deBridge hooks
The DLN API provides a convenient high-level interface to attach hooks to orders upon requesting an order creation transaction. The API takes the burden of proper hook data validation, encoding, cost estimation, and simulation, ensuring that an order would get filled on the destination chain and there is no technical inconsistencies that may prevent it. This is especially important for atomic success-required hooks, as an error during such hook execution would prevent an order from getting filled, and an order's authority would need to initiate a cancellation procedure from the destination chain, which increases friction and worsens UX. 

To specify the hook, use the dlnHook parameter of the create-tx endpoint. The value for this parameter must be a JSON in a specific format that describes the hook for the given destination chain. Depending on the destination chain, different templates are available.

Serialized instructions hook for Solana
To set the hook to be executed upon filling order on Solana (dstChainId=7565164), the following template should be used:

Copy
{ type: "solana_serialized_instructions"; data: "0x..." }
where data is represented as a versioned transaction with one or more instructions. Thus, only non-atomic success-required hooks are supported.

To craft a proper versioned transaction, use the guide: Creating Hook data for Solana

Transaction call hook for EVM
To easily attach an atomic success-required hook that executes an arbitrary transaction call via the default Universal hook, the DLN API provides a simple shortcut for that:

Copy
{
  type: "evm_transaction_call";
  data: {
    "to": "0x...",
    "calldata": "0x...",
    "gas": 0
  }
}
The data.to and data.calldata properties represent the transaction call that should be made, as explained in the Universal hook section. The gas property must be specified if:

the underlying call handles errors gracefully, which leads to underestimation of gas (see our investigation on this)

the transaction call can't be estimated currently, which leads to inability of the DLN API to properly estimate transaction costs. 

The following snippet produces a dlnHook parameter that results a hook to deposit 0.1 USDC to AAVE on behalf of 0xc31dcE63f4B284Cf3bFb93A278F970204409747f:

Copy
const query = new URLSearchParams({
  // other parameters were omitted for clarity
  dstChainId: 137,
  dstChainTokenOut: '0x3c499c542cef5e3811e1192ce70d8cc03d5c3359',
  dstChainTokenOutAmount: '100000',
  dlnHook: JSON.stringify({
    type: "evm_transaction_call";
    data: {
      "to": "0x794a61358D6845594F94dc1DB02A252b5b4814aD",
      "calldata": "0x617ba0370000000000000000000000003c499c542cef5e3811e1192ce70d8cc03d5c335900000000000000000000000000000000000000000000000000000000000186a0000000000000000000000000c31dce63f4b284cf3bfb93a278f970204409747f0000000000000000000000000000000000000000000000000000000000000000",
      "gas": 0
    }
  })
})
This simple shortcut would be transparently converted by the DLN API to a hook with the following properties:

Copy
{
    fallbackAddress: dstChainTokenOutRecipient,
    target: '0x0000000000000000000000000000000000000000',
    reward: 0,
    isNonAtomic: false,
    isSuccessRequired: true,
    targetPayload: {
        to: dlnHook.data.to,
        callData: dlnHook.calldata.data,
        gas: dlnHook.data.gas
    }
}
Arbitrary hook for EVM
To provide a complete customization of a hook, the DLN API offers a template that fully replicates the HookDataV1 struct:

Copy
{
  "type": "evm_hook_data_v1",
  "data": {
    "fallbackAddress": "0x...",
    "target": "0x...",
    "reward": "0",
    "isNonAtomic": boolean,
    "isSuccessRequired": boolean,
    "targetPayload": "0x"
  }
}
The DLN API would encode it and inject into an order.

Hook validity considerations
To ensure best and frictionless user experience, the DLN API would refuse to return a transaction to create an order if it is impossible to fulfill an order with the given hook.

The hook is attached to the order during order's placement on the source chain, however actual fulfillment occurs on the destination chain. If the attached hook is success-required and exits unsuccessfully upon fulfillment, it prevents the entire order from getting filled. This would necessitate an order's authority to initiate a cancellation procedure from the destination chain, which increases friction and worsens UX. 

To prevent this, the DLN API constructs a potential transaction to fulfill the order to be created, and simulates this transaction internally to ensure that the order to be created could actually be filled. If such simulation causes an error, that points to the problem within the hook, the API would refuse to return a transaction, but would return an error with details instead, so you can debug the potential fulfillment transaction to find a pitfalls in the hook:

Copy
{
    "errorId": "HOOK_FAILED",
    "errorPayload": {
        "potentialFulfillOrderTxSimulation": {
            "simulationInput": {
                "chainId": number,
                "blockNumber": number,
                "tx": {
                    "from": string,
                    "to": string,
                    "data": string,
                    "value"?: string
                },
            },

            "simulationError": {
                "errorName": string,
                "data": string,
            }
        }
    }
}
Submitting an Order Creation Transaction
The transaction call retrieved from the DLN API must be signed by a user how is willing to sell the asset, and then broadcasted to the source chain.

EVM-based blockchains
The tx object has the following structure and is ready to be signed and broadcasted:

Copy
{
    "estimation": { ... }
    
    "tx": {
        "data": "0xfbe16ca70000000000000000000000000000000[...truncated...]",
        "to": "0xeF4fB24aD0916217251F553c0596F8Edc630EB66",
        "value": "5000000000000000",
    },
}
Field names from the tx object speak for themselves:

the to is the field the transaction should be sent to, and typically you should expect the address of one of the smart contracts responsible for forwarding;

the data is the contents of the transaction, containing instructions related to swaps planned on the source or (and) on the destination chains, bridging settings, etc;

the value is the amount of native blockchain currency that must be sent along with the transaction.

However, there are a few things you must consider:

First, the value is always positive, even if the input token is an ERC-20 token. This is because the underlying DLN protocol takes a fixed amount in the native currency, so the API always includes it as the transaction value. In the above example, the value equals the current fixed fee, which is 0.005 BNB on the BNB Chain.

Second, in case the input token is an ERC-20 token, a user needs to give approval to the smart contract address specified in the tx.to field prior to submitting this transaction so it can transfer them on the behalf of the sender. This can be typically done by calling either approve() or increaseAllowance() method of the smart contract which implements the token you are willing to swap. Approve at least the amount that has been specified as the estimation.srcChainTokenIn.amount response property.

Other than that, the transaction is ready to be signed by a user and broadcasted to the blockchain. It is also worth mentioning that the given transaction data can be used as a part of another transaction: a dApp can bypass the given to, data and value to your smart contract, and make a low-level call. There is even possible to create multiple transactions for different orders, and perform several low-level calls.

The affiliate fee is paid only after the order gets fulfilled, and the taker requests order unlock during the unlock procedure.

Solana
For DLN trades coming from Solana the tx object returned by DLN API has only one field data which is hex-encoded VersionedTransaction

To convert the hex-encoded string into VersionedTransaction decode hex to buffer using any library and call VersionedTransaction.deserialize(decoded).

Make sure you properly set transaction priority fees based on the current load of the Solana network. Refer to one of these guides to learn more about how to estimate tx fee parameters: 
- Triton guide
- Helius guide

More info about sending versioned transactions here.

Example:

Copy
import { VersionedTransaction, Connection, clusterApiUrl, Keypair } from "@solana/web3.js";

function encodeNumberToArrayLE(num: number, arraySize: number): Uint8Array {
  const result = new Uint8Array(arraySize);
  for (let i = 0; i < arraySize; i++) {
    result[i] = Number(num & 0xff);
    num >>= 8;
  }

  return result;
}

function updatePriorityFee(tx: VersionedTransaction, computeUnitPrice: number, computeUnitLimit?: number) {
  const computeBudgetOfset = 1;
  const computeUnitPriceData = tx.message.compiledInstructions[1].data;
  const encodedPrice = encodeNumberToArrayLE(computeUnitPrice, 8);
  for (let i = 0; i < encodedPrice.length; i++) {
    computeUnitPriceData[i + computeBudgetOfset] = encodedPrice[i];
  }

  if (computeUnitLimit) {
    const computeUnitLimitData = tx.message.compiledInstructions[0].data;
    const encodedLimit = encodeNumberToArrayLE(computeUnitLimit, 4);
    for (let i = 0; i < encodedLimit.length; i++) {
      computeUnitLimitData[i + computeBudgetOfset] = encodedLimit[i];
    }
  }
}

const wallet = new Keypair(); // your actual wallet here
const connection = new Connection(clusterApiUrl("mainnet-beta")); // your actual connection here
const tx = VersionedTransaction.deserialize(Buffer.from(tx.data.slice(2), "hex"));

// make sure to set correct CU price & limit for the best UX 
updatePriorityFee(tx, NEW_CU_PRICE, NEW_CU_LIMIT);
const { blockhash } = await connection.getLatestBlockhash();
tx.message.recentBlockhash = blockhash; // Update blockhash!
tx.sign([wallet]); // Sign the tx with wallet
connection.sendTransaction(tx);

Cancelling the Order
It can be the case that the given order remains unfulfilled for a prolonged period of time. The reason for this may be that the order became unprofitable, and no one is willing to fulfill it. In this case, the order must be cancelled to unlock the input amount of funds.

The only way to cancel the order is to initiate the cancellation procedure it was intended to be fulfilled on (the dstChainId parameter). During the cancellation process, the order is marked as cancelled (to prevent further fulfillment) and a cross-chain message is sent through the deBridge cross-chain messaging infrastructure to the DLN contract on the source chain to unlock the given funds. The funds locked on the source chain are returned in full including affiliate and protocol fees.

The cancellation procedure can only be initiated by the dstChainOrderAuthorityAddress in a separate transaction on the destination chain. Such transaction can be requested by calling the /v1.0/dln/order/:id/cancel-tx endpoint:

https://dln.debridge.finance/v1.0/dln/order/0x9ee6c3d0aa68a7504e619b02df7c71539d0ce10e27f593bf8604b62e51955a01/cancel-tx

This gives the response with the transaction data ready to be signed and broadcasted to the destination chain:

Copy
{ 
    "tx": {
        "data": "0xd38d96260000000000000000000000000000000[...truncated...]",
        "to": "0xe7351fd770a37282b91d153ee690b63579d6dd7f",
        "value": "35957750149468810",
        ,
        "chainId": 43114
    }
},
Several considerations:

the transaction can be submitted only to the chain where the order has been intended to be fulfilled on

the transaction call would be accepted only if made by the dstChainOrderAuthorityAddress specified during the given order creation

the funds locked on the source chain upon order created are returned to the srcChainOrderAuthorityAddress specified during the given order creation

the value for the transaction is always positive needed to cover:

the deBridge cross-chain messaging protocol fee (measured in the blockchain native currency where the message is being sent from) to make a cancellation message accepted. Consider looking at the details on retrieving the deBridge protocol fee;

a small amount to cover the gas on the source chain, which gives an incentive to keepers for the successful claim of the cross-chain message on the source chain. In other words, this is a prepayment for potential gas expenses, that will be transferred by the protocol.


Interacting with smart contracts
The deBridge Liquidity Network Protocol is an on-chain system of smart contracts where users place their cross-chain limit orders, giving a specific amount of input token on the source chain (giveAmount of the giveToken on the giveChain) and specifying the outcome they are willing to take on the destination chain (takeAmount of the takeToken on the takeChain). 

The given amount is being locked by the DlnSource smart contract on the source chain and anyone with enough liquidity (called Solvers) can attempt to fulfill the order by calling the DlnDestination smart contract on the destination chain supplying the requested amount of tokens the user is willing to take. After the order is fulfilled, the supplied amount is immediately transferred to the recipient specified by the user, and a cross-chain message is sent to the source chain via the deBridge infrastructure to unlock the funds, effectively completing the order.Getting ready to make on-chain calls

The DLN Protocol consists of two contracts: the DlnSource contract responsible for order placement, and the DlnDestination contract responsible for order fulfillment.

Currently, both contracts are deployed on the supported blockchains effectively allowing anyone to place orders in any direction. Contract addresses and ABIs can be found here: Trusted Smart Contracts

Placing orders
Estimating the order
First, decide which tokens you are willing to sell on the source chain and which tokens you are willing to buy on the destination chain. Say, you're selling 1 wBTC on Ethereum and buying a reasonable amount of DOGE on BNB.

The deBridge Liquidity Network Protocol is completely asset-agnostic, meaning that you can place an order giving wBTC or WETH, or any other asset. However, solvers mainly hold USDC and ETH on their wallets' balance and execute only the orders where the input token is either a USDC token or a native ETH. Thus, for a quick fulfillment of the order placed in the deBridge Liquidity Network Protocol, it's recommended to pre-swap your input token to any of these reserve-ready tokens before placing an order.

On the other hand, DLN is an open market, so anyone can become a solver and execute orders with custom input tokens or profitability.

Let's assume you've swapped your 1 wBTC to 25,000 USDC which will be then used upon order creation.

Second, calculate the reasonable amount of tokens you are willing to receive on the destination chain upon order fulfillment according to the current market condition and the protocol fees. Simply speaking, give at least 4 bps (DLN protocol fee) + 4 bps (Taker's incentive) = 8 bps + $6 (expected gas expenses taken by the taker to fulfill the order). This amount is laid in as a spread of the limit order, or margin between input and output tokens. Getting back to the example, the math below gives us a reasonable amount of DOGE we are willing to take:

Copy

Copy
25,000 * (10,000 - 8) / 10,000 - 6 = 24,974 DOGE

(10,000 is a basis point denominator, see https://en.wikipedia.org/wiki/Basis_point)
Third, make sure you have enough Ether to cover the protocol fee, which is being taken by DlnSource smart contract for order creation. You are advised to query DlnSource.globalFixedNativeFee() function to retrieve this value. For example, the globalFixedNativeFee value for the Ethereum blockchain would be 1000000000000000, which resolves to 0.001 ETH.

Placing order on-chain
To place an order,

set USDC token approval to allow the DlnSource contract spend tokens on your behalf,

call the DlnSource.createOrder() method:

Copy

Copy
function createOrder(
    OrderCreation calldata _orderCreation,
    bytes calldata _affiliateFee,
    uint32 _referralCode,
    bytes calldata _permitEnvelope
) external payable returns (bytes32 orderId);
Preparing an OrderCreation struct

OrderCreation has the following structure:

Copy
struct OrderCreation {
    // the address of the ERC-20 token you are giving; 
    // use the zero address to indicate you are giving a native blockchain token (ether, matic, etc).
    address giveTokenAddress;
    
    // the amount of tokens you are giving
    uint256 giveAmount;
    
    // the address of the ERC-20 token you are willing to take on the destination chain
    bytes takeTokenAddress;
    
    // the amount of tokens you are willing to take on the destination chain
    uint256 takeAmount;
    
    // the ID of the chain where an order should be fulfilled. 
    // Use the list of supported chains mentioned above
    uint256 takeChainId;
    
    // the address on the destination chain where the funds 
    // should be sent to upon order fulfillment
    bytes receiverDst;
    
    // the address on the source (current) chain who is allowed to patch the order 
    // giving more input tokens and thus making the order more attractive to takers, just in case
    address givePatchAuthoritySrc;
    
    // the address on the destination chain who is allowed to patch the order 
    // decreasing the take amount and thus making the order more attractive to takers, just in case
    bytes orderAuthorityAddressDst;
    
    // an optional address restricting anyone in the open market from fulfilling 
    // this order but the given address. This can be useful if you are creating a order
    //  for a specific taker. By default, set to empty bytes array (0x)
    bytes allowedTakerDst;              // *optional
    
    // set to an empty bytes array (0x)
    bytes externalCall;                 // N/A, *optional
    
    // an optional address on the source (current) chain where the given input tokens 
    // would be transferred to in case order cancellation is initiated by the orderAuthorityAddressDst 
    // on the destination chain. This property can be safely set to an empty bytes array (0x): 
    // in this case, tokens would be transferred to the arbitrary address specified 
    // by the orderAuthorityAddressDst upon order cancellation
    bytes allowedCancelBeneficiarySrc;  // *optional
}
Preparing other arguments

Subsequent arguments of the createOrder() function can be safely omitted by specifying default values:

_affiliateFee can be set to empty bytes array (0x); this argument allows you to ask the protocol to keep the given amount as an affiliate fee in favor of affiliate beneficiary and release it whenever an order is completely fulfilled. This is useful if you built a protocol and place orders on behalf of your users. To do so, concat the address and the amount into a single bytes array, whose length is expected to be exactly 52 bytes.

_referralCode can be set to zero (0); it is an invitation code to identify your transaction. If you don't have it, you can get one by pressing the INVITE FRIENDS button at app.debridge.finance. Governance may thank you later for being an early builder.

_permitEnvelope can be set to empty bytes array (0x); it allows you to use an EIP-2612-compliant signed approval so you don't have to give a prior spending approval to allow the DlnSource contract to spend tokens on your behalf. This argument accepts amount + deadline + signature as a single bytes array

Making a call

Once all arguments are prepared, you are ready to make the call. Make sure you supply the exact amount of native blockchain currency to the value to cover the DLN protocol fee (globalFixedNativeFee).

Copy
// preparing an order
OrderCreation memory orderCreation;
orderCreation.giveTokenAddress = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;    // USDC
orderCreation.giveAmount = 25000000000;                                         // 25,000 USDC
orderCreation.takeTokenAddress = abi.encodePacked(0xba2ae424d960c26247dd6c32edc70b295c744c43);
orderCreation.takeAmount = 2497400000000;                                       // 249,740 DOGE
orderCreation.takeChainId = 56;                                                 // BNB Chain
orderCreation.receiverDst = abi.encodePacked(0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045);
orderCreation.givePatchAuthoritySrc = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
orderCreation.orderAuthorityAddressDst = abi.encodePacked(0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045);
orderCreation.allowedTakerDst = "";
orderCreation.externalCall = "";
orderCreation.allowedCancelBeneficiarySrc = "";

// getting the protocol fee
uint protocolFee = DlnSource(dlnSourceAddress).globalFixedNativeFee();

// giving approval
IERC20(orderCreation.giveTokenAddress).approve(dlnSourceAddress, orderCreation.giveAmount);

// placing an order
bytes32 orderId = DlnSource(dlnSourceAddress).createOrder{value: protocolFee}(
    orderCreation,
    "",
    0,
    ""
);
Whenever the call to DlnSource.createOrder() succeeded, it would return the orderId which can be used to track, cancel and fulfill the order.

Additionally, the CreatedOrder event is emitted:

Copy
event CreatedOrder(
    Order order,
    bytes32 orderId,
    bytes affiliateFee,
    uint256 nativeFixFee,
    uint256 percentFee,
    uint32 referralCode
);
which contains an Order structure that is important to know to be able to fulfill or cancel this order.

Tracking order status
There is no way to know the order status on the chain where the order was placed. You need to switch to the chain it is intended to be fulfilled on (the takeChainId property of the order).

You have two options to programmatically find whenever an order has been fulfilled or cancelled on the destination chain (not the chain where you placed it): either by querying the DlnDestination.takeOrders() getter method, or by capturing the FulfilledOrder() and SentOrderCancel() events emitted by the DlnDestination contract.

The DlnDestination.takeOrders() getter method is defined as follows:

Copy
function takeOrders(bytes32 orderId)
    external
    view
    returns (
        uint8 status,
        address takerAddress,
        uint256 giveChainId
    );
returns the status property which indicates:

status=0: the given order is neither fulfilled nor cancelled,

status=1: the given order is successfully fulfilled (funds sent to the given receiver)

status=2: unlock procedure has been initiated upon fulfillment to unlock the given funds on the source chain, as per taker request

status=3: cancel procedure has been initiated to unlock the given funds on the source chain, as per order's orderAuthorityAddressDst request

Alternatively, you can capture events emitted by the DlnDestination contact:

Copy
event FulfilledOrder(Order order, bytes32 orderId, address sender, address unlockAuthority);
event SentOrderCancel(Order order, bytes32 orderId, bytes cancelBeneficiary, bytes32 submissionId);
The FulfilledOrder event is emitted whenever the order has been successfully fulfilled.

The SentOrderCancel event is emitted whenever the cancel procedure has been initiated, as per order's orderAuthorityAddressDst request.

Canceling order
The only way to cancel the order is to initiate the cancellation procedure on the chain it was intended to be fulfilled on (the takeChainId property of the order). During the cancellation process, the order is marked as cancelled (to prevent further fulfillment) and a cross-chain message is sent through the deBridge cross-chain messaging infrastructure to the DlnSource contract on the source chain to unlock the given funds. The funds locked on the source chain are returned in full including affiliate and protocol fees.

To initiate the cancellation procedure, call the DlnDestination.sendEvmOrderCancel() method on the destination chain as follows:

Copy
function sendEvmOrderCancel(
    Order memory _order,
    address _cancelBeneficiary,
    uint256 _executionFee
) external payable;
mind that only an orderAuthorityAddressDst address specified during the order creation is allowed to perform this call for the given order;

you need to cover the deBridge cross-chain messaging protocol fee (measured in the blockchain native currency where the message is being sent from) to make a cancellation message accepted. Consider looking at the details on retrieving the deBridge protocol fee;

for the _order argument, use the Order structure obtained from the CreatedOrder() upon order creation;

for the _cancelBeneficiary argument, use the address you'd like the given funds to be unlocked to on the source chain. Whenever the allowedCancelBeneficiarySrc has been explicitly provided upon order creation, you are only allowed to use that value;

for the _executionFee argument, specify the amount of native blockchain currency (in addition to the deBridge protocol fee) to provide an incentive to keepers for the successful claim of the cross-chain message on the destination chain. In other words, this is a prepayment for potential gas expenses on the destination chain, that will be transferred by the protocol. Otherwise, you'd need to find the cross-chain transaction in the deExplorer and claim it manually. Consider understanding how the cross-chain call is handled.

Finally, you are ready to initiate a cancellation procedure:

Copy
uint protocolFee = IDebridgeGate(DlnDestination(dlnDestinationAddress).deBridgeGate())
    .globalFixedNativeFee();
uint executionFee = 30000000000000000; // e.g. 0.03 BNB ≈ $10
DlnDestination(dlnDestinationAddress).sendEvmOrderCancel{value: protocolFee + executionFee}(
    order,
    0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045,
    executionFee
);


Filling orders
We are going to release a reference documentation for fulfilling orders placed on the deBridge Liquidity Network Protocol soon. Until this, please look at the documentation on dln-taker — our open source service for solvers that automates order estimation and fulfillment.


okay above were all the requited docs. Now below is test suit file for your reference which integrates story and debride

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title deBridge + Story Protocol Integration Test
 * @author Story Protocol Team
 * @notice Demonstrates cross-chain royalty payments using deBridge DLN and Story Protocol
 * @dev This integration enables users to pay IP asset royalties from any supported blockchain
 *      to Story mainnet using deBridge as the cross-chain bridge infrastructure.
 *
 * INTEGRATION OVERVIEW:
 * ├── Source Chain (e.g., Ethereum): User initiates payment with ETH
 * ├── deBridge DLN: Swaps ETH → WIP and bridges to Story mainnet
 * ├── Auto-Approval: deBridge approves WIP to RoyaltyModule
 * └── Hook Execution: Direct call to RoyaltyModule.payRoyaltyOnBehalf()
 *
 * KEY FEATURES:
 * • Automatic token approval via deBridge
 * • Direct contract calls for maximum efficiency
 * • Production-ready API integration
 * • Real Story Protocol mainnet addresses
 *
 * SUPPORTED NETWORKS:
 * • Source: Ethereum mainnet (chainId: 1)
 * • Destination: Story mainnet (chainId: 1315)
 * • Bridge: ETH → WIP token
 */

// Run this test:
// forge test --fork-url https://aeneid.storyrpc.io/ --match-path test/6_DebridgeHook.t.sol
import { Test, console } from "forge-std/Test.sol";
import { HexUtils } from "./utils/HexUtils.sol";
import { StringUtils } from "./utils/StringUtils.sol";

/**
 * @notice Minimal interface for Story Protocol RoyaltyModule
 * @dev Only includes the payRoyaltyOnBehalf function needed for cross-chain payments
 */
interface IRoyaltyModule {
    /**
     * @notice Pay royalties on behalf of an IP asset
     * @param receiverIpId The IP asset receiving royalties
     * @param payerIpId The IP asset paying royalties (0x0 for external payers)
     * @param token The payment token address
     * @param amount The payment amount
     */
    function payRoyaltyOnBehalf(address receiverIpId, address payerIpId, address token, uint256 amount) external;
}

/**
 * @title Cross-Chain Royalty Payment Integration Test
 * @notice Tests the complete flow of paying Story Protocol royalties via deBridge
 */
contract DebridgeStoryIntegrationTest is Test {
    using HexUtils for bytes;
    using HexUtils for address;
    using StringUtils for string;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Story Protocol RoyaltyModule on Story mainnet
    address public constant ROYALTY_MODULE = 0xD2f60c40fEbccf6311f8B47c4f2Ec6b040400086;

    /// @notice WIP (Wrapped IP) token on Story mainnet
    address public constant WIP_TOKEN = 0x1514000000000000000000000000000000000000;

    /// @notice deBridge API endpoint for order creation
    string public constant DEBRIDGE_API = "https://dln.debridge.finance/v1.0/dln/order/create-tx";

    uint256 public constant PAYMENT_AMOUNT = 1e18; // 1 WIP token

    /*//////////////////////////////////////////////////////////////
                              MAIN TEST
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Tests the complete cross-chain royalty payment flow
     * @dev Demonstrates API integration and validates successful hook parsing
     */
    function test_crossChainRoyaltyPayment() public {
        // Build hook payload for direct RoyaltyModule call
        string memory dlnHookJson = _buildRoyaltyPaymentHook();

        // Create deBridge API request
        string memory apiUrl = _buildApiRequest(dlnHookJson);

        // Execute API call and validate response
        string memory response = _executeApiCall(apiUrl);
        _validateApiResponse(response);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructs the deBridge hook payload for royalty payment
     * @return dlnHookJson The JSON-encoded hook payload
     */
    function _buildRoyaltyPaymentHook() internal pure returns (string memory dlnHookJson) {
        // Payment configuration
        address ipAssetId = 0xB1D831271A68Db5c18c8F0B69327446f7C8D0A42; // Example IP asset

        // Encode the direct RoyaltyModule call
        // Note: deBridge ExternalCallExecutor automatically approves tokens before execution
        bytes memory calldata_ = abi.encodeCall(
            IRoyaltyModule.payRoyaltyOnBehalf,
            (
                ipAssetId, // IP asset receiving royalties
                address(0), // External payer (0x0)
                WIP_TOKEN, // Payment token (WIP)
                PAYMENT_AMOUNT // Payment amount
            )
        );

        // Construct deBridge hook JSON
        dlnHookJson = string.concat(
            '{"type":"evm_transaction_call",',
            '"data":{"to":"',
            _addressToHex(ROYALTY_MODULE),
            '",',
            '"calldata":"',
            calldata_.toHexString(),
            '",',
            '"gas":0}}'
        );
    }

    /**
     * @notice Builds the complete deBridge API request URL
     * @param dlnHookJson The hook payload to include in the request
     * @return apiUrl The complete API request URL
     */
    function _buildApiRequest(string memory dlnHookJson) internal pure returns (string memory apiUrl) {
        address senderAddress = 0xcf0a36dEC06E90263288100C11CF69828338E826; // Example sender

        apiUrl = string.concat(
            DEBRIDGE_API,
            "?srcChainId=1", // Ethereum mainnet
            "&srcChainTokenIn=",
            _addressToHex(address(0)), // ETH (native token)
            "&srcChainTokenInAmount=auto", // 0.01 ETH
            "&dstChainId=1315", // Story mainnet
            "&dstChainTokenOut=",
            _addressToHex(WIP_TOKEN), // WIP token
            "&dstChainTokenOutAmount=",
            StringUtils.toString(PAYMENT_AMOUNT),
            "&dstChainTokenOutRecipient=",
            _addressToHex(senderAddress),
            "&senderAddress=",
            _addressToHex(senderAddress),
            "&srcChainOrderAuthorityAddress=",
            _addressToHex(senderAddress),
            "&dstChainOrderAuthorityAddress=",
            _addressToHex(senderAddress),
            "&enableEstimate=true", // Enable simulation
            "&prependOperatingExpenses=true",
            "&dlnHook=",
            _urlEncode(dlnHookJson) // URL-encoded hook
        );
    }

    /**
     * @notice Executes the API call to deBridge
     * @param apiUrl The API request URL
     * @return response The API response
     */
    function _executeApiCall(string memory apiUrl) internal returns (string memory response) {
        // Log API request for debugging
        console.log("deBridge API Request:");
        console.log(apiUrl);
        console.log("");

        // Execute HTTP request via Foundry's ffi
        string[] memory curlCommand = new string[](3);
        curlCommand[0] = "curl";
        curlCommand[1] = "-s";
        curlCommand[2] = apiUrl;

        bytes memory responseBytes = vm.ffi(curlCommand);
        response = string(responseBytes);

        // Log API response for debugging
        console.log("deBridge API Response:");
        console.log(response);
        console.log("");
    }

    /**
     * @notice Validates the deBridge API response
     * @param response The API response to validate
     */
    function _validateApiResponse(string memory response) internal pure {
        require(bytes(response).length > 0, "Empty API response");

        // Validate successful response
        require(_contains(response, '"estimation"'), "Missing estimation field");
        require(_contains(response, '"tx"'), "Missing transaction field");
        require(_contains(response, '"orderId"'), "Missing order ID");
        require(_contains(response, '"dstChainTokenOut"'), "Missing destination token info");

        // Verify hook integration
        require(
            _contains(response, "d2577f3b"), // payRoyaltyOnBehalf selector
            "Hook not properly integrated in transaction"
        );

        // Verify WIP token configuration
        require(
            _contains(_toLower(response), _toLower(_addressToHex(WIP_TOKEN))),
            "WIP token address not found in response"
        );
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Converts address to hex string
     */
    function _addressToHex(address addr) internal pure returns (string memory) {
        return abi.encodePacked(addr).toHexString();
    }

    /**
     * @notice Converts string to lowercase
     */
    function _toLower(string memory str) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        for (uint i = 0; i < strBytes.length; i++) {
            if (strBytes[i] >= 0x41 && strBytes[i] <= 0x5A) {
                strBytes[i] = bytes1(uint8(strBytes[i]) + 32);
            }
        }
        return string(strBytes);
    }

    /**
     * @notice Checks if string contains substring
     */
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

    /**
     * @notice URL encodes a string for API requests
     */
    function _urlEncode(string memory input) internal pure returns (string memory) {
        bytes memory inputBytes = bytes(input);
        bytes memory output = new bytes(inputBytes.length * 3);
        uint outputLength = 0;

        for (uint i = 0; i < inputBytes.length; i++) {
            uint8 char = uint8(inputBytes[i]);

            // Characters that don't need encoding: A-Z, a-z, 0-9, -, ., _, ~
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
                // URL encode the character
                output[outputLength++] = "%";
                output[outputLength++] = bytes1(_toHexChar(char >> 4));
                output[outputLength++] = bytes1(_toHexChar(char & 0x0F));
            }
        }

        // Trim output to actual length
        bytes memory result = new bytes(outputLength);
        for (uint i = 0; i < outputLength; i++) {
            result[i] = output[i];
        }
        return string(result);
    }

    /**
     * @notice Converts hex digit to character
     */
    function _toHexChar(uint8 value) internal pure returns (uint8) {
        return value < 10 ? (0x30 + value) : (0x41 + value - 10);
    }
}



Now below are the latest IPCollateralLending.sol

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
    }

    struct IPCollateral {
        address ipAsset;
        uint256 assessedValue;
        uint256 riskScore; // 0-100, lower is better
        bool isEligible;
        uint256 lastValidated;
        bytes32 yakoaHash; // Yakoa verification hash
    }

    enum LoanStatus {
        PENDING,
        ACTIVE,
        REPAID,
        LIQUIDATED,
        DEFAULTED
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event LoanCreated(
        uint256 indexed loanId,
        address indexed borrower,
        address indexed ipAsset,
        uint256 loanAmount,
        uint256 collateralValue
    );

    event LoanRepaid(uint256 indexed loanId, address indexed borrower, uint256 amount);
    event LoanLiquidated(uint256 indexed loanId, address indexed liquidator);
    event IPCollateralValidated(address indexed ipAsset, uint256 assessedValue, uint256 riskScore);
    event CrossChainLiquidityAdded(address indexed token, uint256 amount, uint256 sourceChain);

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

    uint256 public nextLoanId;
    uint256 public constant MAX_LTV = 70; // 70% Loan-to-Value ratio
    uint256 public constant LIQUIDATION_THRESHOLD = 85; // 85% liquidation threshold
    uint256 public constant BASE_INTEREST_RATE = 500; // 5% base rate (in basis points)

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
        // Verify IP asset is registered on Story
        require(IP_ASSET_REGISTRY.isRegistered(ipAsset), "IP not registered");
        
        // Calculate risk score based on various factors
        uint256 riskScore = _calculateRiskScore(ipAsset, yakoaProof);
        
        // Only accept low-risk IP (score < 30)
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
     */
    function createLoan(
        address ipAsset,
        uint256 loanAmount,
        uint256 duration,
        address loanToken
    ) external nonReentrant {
        IPCollateral memory collateral = ipCollaterals[ipAsset];
        require(collateral.isEligible, "IP not eligible as collateral");
        require(supportedTokens[loanToken], "Token not supported");
        
        // Check ownership of IP asset
        require(_isIPOwner(ipAsset, msg.sender), "Not IP owner");
        
        // Calculate max loan amount (70% LTV)
        uint256 maxLoanAmount = (collateral.assessedValue * MAX_LTV) / 100;
        require(loanAmount <= maxLoanAmount, "Loan amount exceeds LTV");
        
        // Calculate interest rate based on risk
        uint256 interestRate = _calculateInterestRate(collateral.riskScore);
        
        // Create loan
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
            status: LoanStatus.ACTIVE
        });
        
        userLoans[msg.sender].push(loanId);
        
        // Transfer loan amount to borrower
        IERC20(loanToken).transfer(msg.sender, loanAmount);
        
        emit LoanCreated(loanId, msg.sender, ipAsset, loanAmount, collateral.assessedValue);
    }

    /**
     * @notice Repays a loan
     * @param loanId The loan to repay
     */
    function repayLoan(uint256 loanId) external nonReentrant {
        Loan storage loan = loans[loanId];
        require(loan.isActive, "Loan not active");
        require(loan.borrower == msg.sender, "Not borrower");
        
        uint256 totalOwed = _calculateTotalOwed(loanId);
        
        // Transfer repayment from borrower
        IERC20(loan.loanToken).transferFrom(msg.sender, address(this), totalOwed);
        
        // Mark loan as repaid
        loan.isActive = false;
        loan.isRepaid = true;
        loan.status = LoanStatus.REPAID;
        
        emit LoanRepaid(loanId, msg.sender, totalOwed);
    }

    /**
     * @notice Liquidates an underwater loan
     * @param loanId The loan to liquidate
     */
    function liquidateLoan(uint256 loanId) external nonReentrant {
        Loan storage loan = loans[loanId];
        require(loan.isActive, "Loan not active");
        require(_isLiquidatable(loanId), "Loan not liquidatable");
        
        // Mark as liquidated (IP transfer would happen here in production)
        loan.isActive = false;
        loan.status = LoanStatus.LIQUIDATED;
        
        emit LoanLiquidated(loanId, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                        CROSS-CHAIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds liquidity from another chain via deBridge
     * @param token Token address
     * @param amount Amount to add
     * @param sourceChain Source chain ID
     */
    function addCrossChainLiquidity(
        address token,
        uint256 amount,
        uint256 sourceChain
    ) external {
        require(supportedTokens[token], "Token not supported");
        
        // In production, this would integrate with deBridge contracts
        // For now, we emit an event to track cross-chain operations
        
        emit CrossChainLiquidityAdded(token, amount, sourceChain);
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

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _calculateRiskScore(address ipAsset, bytes32 yakoaProof) internal view returns (uint256) {
        uint256 baseScore = 20; // Base risk score
        
        // Check if IP has license terms (lower risk)
        if (LICENSE_REGISTRY.getAttachedLicenseTermsCount(ipAsset) > 0) {
            baseScore -= 5;
        }
        
        // Check if IP has derivatives (lower risk - proven valuable)
        if (LICENSE_REGISTRY.hasDerivativeIps(ipAsset)) {
            baseScore -= 5;
        }
        
        // Yakoa authenticity check reduces score
        if (yakoaProof != bytes32(0)) {
            baseScore -= 10;
        }
        
        return baseScore;
    }

    function _calculateInterestRate(uint256 riskScore) internal pure returns (uint256) {
        // Base rate + risk premium
        return BASE_INTEREST_RATE + (riskScore * 10); // 0.1% per risk point
    }

    function _calculateTotalOwed(uint256 loanId) internal view returns (uint256) {
        Loan memory loan = loans[loanId];
        uint256 timeElapsed = block.timestamp - loan.startTime;
        uint256 interest = (loan.loanAmount * loan.interestRate * timeElapsed) / (365 days * 10000);
        return loan.loanAmount + interest;
    }

    function _isIPOwner(address ipAsset, address user) internal view returns (bool) {
    // For now, we'll use a simplified ownership check
    // In production, you would implement proper ownership verification
    // This could involve checking the IP Asset's Account or using other registry functions
    
    // Try to check if the ipAsset exists and the user has rights to it
    // Since we don't have direct access to the underlying NFT info,
    // we'll implement a basic check
    
    // Check if the IP Asset is registered
    if (!IP_ASSET_REGISTRY.isRegistered(ipAsset)) {
        return false;
    }
    
    // For MVP purposes, we'll return true if the IP is registered
    // In production, you would need to implement proper ownership verification
    // This could involve:
    // 1. Checking if the user is the owner of the underlying NFT
    // 2. Checking if the user has permission to use the IP as collateral
    // 3. Using the IP Asset's account ownership
    
    return true;
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


and below is latest test cases file

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
    address internal liquidator = address(0x11c01da70a000000000000000000000000000000);

    // Story Protocol contracts
    IIPAssetRegistry internal IP_ASSET_REGISTRY = IIPAssetRegistry(0x77319B4031e6eF1250907aa00018B8B1c67a244b);
    ILicenseRegistry internal LICENSE_REGISTRY = ILicenseRegistry(0x529a750E02d8E2f15649c13D69a465286a780e24);
    ILicensingModule internal LICENSING_MODULE = ILicensingModule(0x04fbd8a2e56dd85CFD5500A4A4DfA955B9f1dE6f);
    IPILicenseTemplate internal PIL_TEMPLATE = IPILicenseTemplate(0x2E896b0b2Fdb7457499B56AAaA4AE55BCB4Cd316);
    IRoyaltyModule internal ROYALTY_MODULE = IRoyaltyModule(0xD2f60c40fEbccf6311f8B47c4f2Ec6b040400086);
    address internal ROYALTY_POLICY_LAP = 0xBe54FB168b3c982b7AaE60dB6CF75Bd8447b390E;
    
    // Use existing deployed MockERC20
    MockERC20 internal USDC;

    IPCollateralLending public lendingProtocol;
    SimpleNFT public SIMPLE_NFT;
    address public ipAsset;
    uint256 public tokenId;

    function setUp() public {
        // Mock IPGraph for testing
        vm.etch(address(0x0101), address(new MockIPGraph()).code);

        // Deploy lending protocol
        lendingProtocol = new IPCollateralLending(
            address(IP_ASSET_REGISTRY),
            address(LICENSE_REGISTRY),
            address(LICENSING_MODULE),
            address(ROYALTY_MODULE),
            address(PIL_TEMPLATE)
        );

        // Use existing deployed MockERC20 instead of creating new one
        USDC = MockERC20(0xF2104833d386a2734a4eB3B8ad6FC6812F29E38E);
        lendingProtocol.setSupportedToken(address(USDC), true);

        // Create and register IP asset
        SIMPLE_NFT = new SimpleNFT("Test IP NFT", "TIP");
        tokenId = SIMPLE_NFT.mint(alice);
        ipAsset = IP_ASSET_REGISTRY.register(block.chainid, address(SIMPLE_NFT), tokenId);

        // Add some liquidity to lending protocol
        USDC.mint(address(lendingProtocol), 1000000e6); // 1M USDC

        // Mint USDC to users for repayments
        USDC.mint(alice, 100000e6);
        USDC.mint(bob, 100000e6);
    }

    function test_validateIPCollateral() public {
        bytes32 yakoaProof = keccak256("valid_proof");
        uint256 assessedValue = 100000e6; // $100k

        lendingProtocol.validateIPCollateral(ipAsset, yakoaProof, assessedValue);

        IPCollateralLending.IPCollateral memory collateral = lendingProtocol.getIPCollateral(ipAsset);
        
        assertEq(collateral.ipAsset, ipAsset);
        assertEq(collateral.assessedValue, assessedValue);
        assertTrue(collateral.isEligible);
        assertEq(collateral.yakoaHash, yakoaProof);
        assertTrue(collateral.riskScore < 30); // Should be low risk
    }

    function test_createLoan() public {
        // First validate the IP as collateral
        bytes32 yakoaProof = keccak256("valid_proof");
        uint256 assessedValue = 100000e6; // $100k
        lendingProtocol.validateIPCollateral(ipAsset, yakoaProof, assessedValue);

        // Create loan for 70% LTV
        uint256 loanAmount = 70000e6; // $70k
        uint256 duration = 365 days;

        vm.prank(alice);
        lendingProtocol.createLoan(ipAsset, loanAmount, duration, address(USDC));

        // Verify loan was created
        IPCollateralLending.Loan memory loan = lendingProtocol.getLoan(0);
        assertEq(loan.borrower, alice);
        assertEq(loan.ipAsset, ipAsset);
        assertEq(loan.loanAmount, loanAmount);
        assertTrue(loan.isActive);
    }

    function test_repayLoan() public {
        // Setup loan
        bytes32 yakoaProof = keccak256("valid_proof");
        uint256 assessedValue = 100000e6;
        lendingProtocol.validateIPCollateral(ipAsset, yakoaProof, assessedValue);

        uint256 loanAmount = 50000e6;
        uint256 duration = 365 days;

        vm.prank(alice);
        lendingProtocol.createLoan(ipAsset, loanAmount, duration, address(USDC));

        // Fast forward time to accrue interest
        vm.warp(block.timestamp + 30 days);

        // Calculate total owed and approve
        uint256 totalOwed = lendingProtocol.calculateTotalOwed(0);
        
        vm.startPrank(alice);
        USDC.approve(address(lendingProtocol), totalOwed);
        lendingProtocol.repayLoan(0);
        vm.stopPrank();

        // Verify loan is repaid
        IPCollateralLending.Loan memory loan = lendingProtocol.getLoan(0);
        assertFalse(loan.isActive);
        assertTrue(loan.isRepaid);
    }

    function test_liquidation() public {
        // Setup loan with high LTV
        bytes32 yakoaProof = keccak256("valid_proof");
        uint256 assessedValue = 100000e6;
        lendingProtocol.validateIPCollateral(ipAsset, yakoaProof, assessedValue);

        uint256 loanAmount = 70000e6;
        uint256 duration = 30 days; // Short duration

        vm.prank(alice);
        lendingProtocol.createLoan(ipAsset, loanAmount, duration, address(USDC));

        // Fast forward past loan duration
        vm.warp(block.timestamp + 31 days);

        // Liquidate loan
        vm.prank(liquidator);
        lendingProtocol.liquidateLoan(0);

        // Verify loan is liquidated
        IPCollateralLending.Loan memory loan = lendingProtocol.getLoan(0);
        assertFalse(loan.isActive);
        assertEq(uint256(loan.status), uint256(IPCollateralLending.LoanStatus.LIQUIDATED));
    }

    function test_crossChainLiquidity() public {
        // Test cross-chain liquidity addition
        uint256 amount = 1000e6;
        uint256 sourceChain = 1; // Ethereum

        lendingProtocol.addCrossChainLiquidity(address(USDC), amount, sourceChain);
        
        // In production, this would verify actual cross-chain bridge integration
        // For now, we just test the function doesn't revert
        assertTrue(true);
    }
}



I want you to now completely integrate debridge on the backend site and also write a comprehensive test suit for it. If you need any more info please ask for it.


