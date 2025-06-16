Okay Now I would like to first build the smart contract side of things for IP Collateral Lending Protocol. I would like you to build it using Foundry. We will first only focus on the core functionality of the protocol which is the Lending and Cross Chain Bridging Part. So first I will give you all the latest Story Docs and also example of Story with Debridge. 

Story Docs:

# Smart Contract Guide

> For smart contract developers who wish to build on top of Story directly.

In this section, we will briefly go over the protocol contracts and then guide you through how to start building on top of the protocol. If you haven't yet familiarized yourself with the overall architecture, we recommend first going over the [Architecture Overview](/concepts/overview) section.

## Smart Contract Tutorial

<Card title="Completed Code" href="https://github.com/storyprotocol/story-protocol-boilerplate" icon="thumbs-up">
  Skip the tutorial and view the completed code. Follow the README instructions
  to run the tests, or go to the `/test` folder to view all of the example
  contracts.
</Card>

**If you want to set things up from scratch**, then continue with the following tutorials, starting with the [Setup Your Own Project](/developers/smart-contracts-guide/setup) step.

## Our Smart Contracts

As of the current version, our Proof-of-Creativity Protocol is compatible with all EVM chains and is written as a set of Smart Contracts in Solidity. There are two repositories that you may interact with as a developer:

* [Story Protocol Core](https://github.com/storyprotocol/protocol-core-v1) - This repository contains the core protocol logic, consisting of a thin IP registry (the [IP Asset Registry](/concepts/registry/ip-asset-registry)), a set of [Modules](/concepts/modules/overview) defining logic around [Licensing](/concepts/licensing-module/overview), [Royalty](/concepts/royalty-module/overview), [Dispute](/concepts/dispute-module/overview), metadata, and a module manager for administering module and user access control.
* [Story Protocol Periphery](https://github.com/storyprotocol/protocol-periphery-v1)- Whereas the core contracts deal with the underlying protocol logic, the periphery contracts deal with protocol extensions that greatly increase UX and simplify IPA management. This is mostly handled through the [SPG](/concepts/spg/overview).

## Deploy & Verify Contracts on Story

<Note>
  The approach to deploy & verify contracts comes from the [Blockscout official
  documentation](https://docs.blockscout.com/developer-support/verifying-a-smart-contract/foundry-verification).
</Note>

Verify a contract with Blockscout right after deployment (make sure you add "/api/" to the end of the Blockscout homepage explorer URL):

```shell
forge create \
  --rpc-url <rpc_https_endpoint> \
  --private-key $PRIVATE_KEY \
  <contract_file>:<contract_name> \
  --verify \
  --verifier blockscout \
  --verifier-url <blockscout_homepage_explorer_url>/api/
```

Or if using foundry scripts:

```shell
forge script <script_file> \
  --rpc-url <rpc_https_endpoint> \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --verifier blockscout \
  --verifier-url <blockscout_homepage_explorer_url>/api/
```

<Warning>
  Do not use RANDAO for pseudo-randomness, instead use onchain VRF (Pyth or Gelato). Currently, RANDAO value is set as the parent block hash and thus is not random for X-1 block.
</Warning>

# Setup

> Set up your development environment for Story smart contracts.

In this guide, we will show you how to setup the Story smart contract development environment in just a few minutes.

## Prerequisites

* [Install Foundry](https://book.getfoundry.sh/getting-started/installation)
* [Install yarn](https://classic.yarnpkg.com/lang/en/docs/install/)

## Creating a Project

1. Run `foundryup` to automatically install the latest stable version of the precompiled binaries: forge, cast, anvil, and chisel
2. Run the following command in a new directory: `forge init`. This will create a `foundry.toml` and example project files in the project root. By default, forge init will also initialize a new git repository.
3. Initialize a new yarn project: `yarn init`. Alternatively, you can use `npm init` or `pnpm init`.
4. Open up your root-level `foundry.toml` file (located in the top directory of your project) and replace it with this:

```toml
[profile.default]
out = 'out'
libs = ['node_modules', 'lib']
cache_path  = 'forge-cache'
gas_reports = ["*"]
optimizer = true
optimizer_runs = 20000
test = 'test'
solc = '0.8.26'
fs_permissions = [{ access = 'read', path = './out' }, { access = 'read-write', path = './deploy-out' }]
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
```

5. Remove the example contract files: `rm src/Counter.sol script/Counter.s.sol test/Counter.t.sol`

## Installing Dependencies

Now, we are ready to start installing our dependencies. To incorporate the Story Protocol core and periphery modules, run the following to have them added to your `package.json`. We will also install `openzeppelin` and `erc6551` as a dependency for the contract and test.

```bash
# note: you can run them one-by-one, or all at once
yarn add @story-protocol/protocol-core@https://github.com/storyprotocol/protocol-core-v1
yarn add @story-protocol/protocol-periphery@https://github.com/storyprotocol/protocol-periphery-v1
yarn add @openzeppelin/contracts
yarn add @openzeppelin/contracts-upgradeable
yarn add erc6551
yarn add solady
```

Additionally, for working with Foundry's test kit, we also recommend adding the following `devDependencies`:

```bash
yarn add -D https://github.com/dapphub/ds-test
yarn add -D github:foundry-rs/forge-std#v1.7.6
```

Now we are ready to build a simple test registration contract!

# Register an IP Asset

> Learn how to Register an NFT as an IP Asset in Solidity.

<Card title="Completed Code" href="https://github.com/storyprotocol/story-protocol-boilerplate/blob/main/test/0_IPARegistrar.t.sol" icon="thumbs-up">
  Follow the completed code all the way through.
</Card>

Let's say you have some off-chain IP (ex. a book, a character, a drawing, etc). In order to register that IP on Story, you first need to mint an NFT. This NFT is the **ownership** over the IP. Then you **register** that NFT on Story, turning it into an [IP Asset](/concepts/ip-asset/overview). The below tutorial will walk you through how to do this.

## Prerequisites

There are a few steps you have to complete before you can start the tutorial.

1. Complete the [Setup Your Own Project](/developers/smart-contracts-guide/setup)

## Before We Start

There are two scenarios:

1. You already have a **custom** ERC-721 NFT contract and can mint from it
2. You want to create an [SPG (Periphery)](/concepts/spg/overview) NFT contract to do minting for you

## Scenario #1: You already have a custom ERC-721 NFT contract and can mint from it

If you already have an NFT minted, or you want to register IP using a custom-built ERC-721 contract, this is the section for you.

As you can see below, the registration process is relatively straightforward. We use `SimpleNFT` as an example, but you can replace it with your own ERC-721 contract.

All you have to do is call `register` on the [IP Asset Registry](/concepts/registry/ip-asset-registry) with:

* `chainid` - you can simply use `block.chainid`
* `tokenContract` - the address of your NFT collection
* `tokenId` - your NFT's ID

Let's create a test file under `test/0_IPARegistrar.t.sol` to see it work and verify the results:

<Note>
  **Contract Addresses**

  We have filled in the addresses from the Story contracts for you. However you can also find the addresses for them here: [Deployed Smart Contracts](/developers/deployed-smart-contracts)

  You can view the `SimpleNFT` contract we're using to test [here](https://github.com/storyprotocol/story-protocol-boilerplate/blob/main/src/mocks/SimpleNFT.sol).
</Note>

<Info>
  You can view the `SimpleNFT` contract we're using to test [here](https://github.com/storyprotocol/story-protocol-boilerplate/blob/main/src/mocks/SimpleNFT.sol).
</Info>

```solidity test/0_IPARegistrar.t.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { IIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IIPAssetRegistry.sol";

// your own ERC-721 NFT contract
import { SimpleNFT } from "../src/mocks/SimpleNFT.sol";

// Run this test:
// forge test --fork-url https://aeneid.storyrpc.io/ --match-path test/0_IPARegistrar.t.sol
contract IPARegistrarTest is Test {
    address internal alice = address(0xa11ce);

    // For addresses, see https://docs.story.foundation/developers/deployed-smart-contracts
    // Protocol Core - IPAssetRegistry
    IIPAssetRegistry internal IP_ASSET_REGISTRY = IIPAssetRegistry(0x77319B4031e6eF1250907aa00018B8B1c67a244b);

    SimpleNFT public SIMPLE_NFT;

    function setUp() public {
        // Create a new Simple NFT collection
        SIMPLE_NFT = new SimpleNFT("Simple IP NFT", "SIM");
    }

    /// @notice Mint an NFT and then register it as an IP Asset.
    function test_register() public {
        uint256 expectedTokenId = SIMPLE_NFT.nextTokenId();
        address expectedIpId = IP_ASSET_REGISTRY.ipId(block.chainid, address(SIMPLE_NFT), expectedTokenId);

        uint256 tokenId = SIMPLE_NFT.mint(alice);
        address ipId = IP_ASSET_REGISTRY.register(block.chainid, address(SIMPLE_NFT), tokenId);

        assertEq(tokenId, expectedTokenId);
        assertEq(ipId, expectedIpId);
        assertEq(SIMPLE_NFT.ownerOf(tokenId), alice);
    }
}
```

## Scenario #2: You want to create an SPG NFT contract to do minting for you

If you don't have your own custom NFT contract, this is the section for you.

To achieve this, we will be using the [SPG](/concepts/spg/overview), which is a utility contract that allows us to combine multiple transactions into one. In this case, we'll be using the SPG's `mintAndRegisterIp` function which combines both minting an NFT and registering it as an IP Asset.

In order to use `mintAndRegisterIp`, we first have to create a new `SPGNFT` collection. We can do this simply by calling `createCollection` on the `StoryProtocolGateway` contract. Or, if you want to create your own `SPGNFT` for some reason, you can implement the [ISPGNFT](https://github.com/storyprotocol/protocol-periphery-v1/blob/main/contracts/interfaces/ISPGNFT.sol) contract interface. Follow the example below to see example parameters you can use to initialize a new SPGNFT.

Once you have your own SPGNFT, all you have to do is call `mintAndRegisterIp` with:

* `spgNftContract` - the address of your SPGNFT contract
* `recipient` - the address of who will receive the NFT and thus be the owner of the newly registered IP. *Note: remember that registering IP on Story is permissionless, so you can register an IP for someone else (by paying for the transaction) yet they can still be the owner of that IP Asset.*
* `ipMetadata` - the metadata associated with your NFT & IP. See [this](/concepts/ip-asset/overview#nft-vs-ip-metadata) section to better understand setting NFT & IP metadata.

1. Run `touch test/0_IPARegistrar.t.sol` to create a test file under `test/0_IPARegistrar.t.sol`. Then, paste in the following code:

<Note>
  **Contract Addresses**

  We have filled in the addresses from the Story contracts for you. However you can also find the addresses for them here: [Deployed Smart Contracts](/developers/deployed-smart-contracts)
</Note>

```solidity test/0_IPARegistrar.t.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { IIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IIPAssetRegistry.sol";
import { ISPGNFT } from "@storyprotocol/periphery/interfaces/ISPGNFT.sol";
import { IRegistrationWorkflows } from "@storyprotocol/periphery/interfaces/workflows/IRegistrationWorkflows.sol";
import { WorkflowStructs } from "@storyprotocol/periphery/lib/WorkflowStructs.sol";

// Run this test:
// forge test --fork-url https://aeneid.storyrpc.io/ --match-path test/0_IPARegistrar.t.sol
contract IPARegistrarTest is Test {
    address internal alice = address(0xa11ce);

    // For addresses, see https://docs.story.foundation/developers/deployed-smart-contracts
    // Protocol Core - IPAssetRegistry
    IIPAssetRegistry internal IP_ASSET_REGISTRY = IIPAssetRegistry(0x77319B4031e6eF1250907aa00018B8B1c67a244b);
    // Protocol Periphery - RegistrationWorkflows
    IRegistrationWorkflows internal REGISTRATION_WORKFLOWS =
        IRegistrationWorkflows(0xbe39E1C756e921BD25DF86e7AAa31106d1eb0424);

    ISPGNFT public SPG_NFT;

    function setUp() public {
        // Create a new NFT collection via SPG
        SPG_NFT = ISPGNFT(
            REGISTRATION_WORKFLOWS.createCollection(
                ISPGNFT.InitParams({
                    name: "Test Collection",
                    symbol: "TEST",
                    baseURI: "",
                    contractURI: "",
                    maxSupply: 100,
                    mintFee: 0,
                    mintFeeToken: address(0),
                    mintFeeRecipient: address(this),
                    owner: address(this),
                    mintOpen: true,
                    isPublicMinting: false
                })
            )
        );
    }

    /// @notice Mint an NFT and register it in the same call via the Story Protocol Gateway.
    /// @dev Requires the collection address that is passed into the `mintAndRegisterIp` function
    /// to be created via SPG (createCollection), as done above. Or, a contract that
    /// implements the `ISPGNFT` interface.
    function test_mintAndRegisterIp() public {
        uint256 expectedTokenId = SPG_NFT.totalSupply() + 1;
        address expectedIpId = IP_ASSET_REGISTRY.ipId(block.chainid, address(SPG_NFT), expectedTokenId);

        // Note: The caller of this function must be the owner of the SPG NFT Collection.
        // In this case, the owner of the SPG NFT Collection is the contract itself
        // because it deployed it in the `setup` function.
        // We can make `alice` the recipient of the NFT though, which makes her the
        // owner of not only the NFT, but therefore the IP Asset.
        (address ipId, uint256 tokenId) = REGISTRATION_WORKFLOWS.mintAndRegisterIp(
            address(SPG_NFT),
            alice,
            WorkflowStructs.IPMetadata({
                ipMetadataURI: "https://ipfs.io/ipfs/QmZHfQdFA2cb3ASdmeGS5K6rZjz65osUddYMURDx21bT73",
                ipMetadataHash: keccak256(
                    abi.encodePacked(
                        "{'title':'My IP Asset','description':'This is a test IP asset','createdAt':'','creators':[]}"
                    )
                ),
                nftMetadataURI: "https://ipfs.io/ipfs/QmRL5PcK66J1mbtTZSw1nwVqrGxt98onStx6LgeHTDbEey",
                nftMetadataHash: keccak256(
                    abi.encodePacked(
                        "{'name':'Test NFT','description':'This is a test NFT','image':'https://picsum.photos/200'}"
                    )
                )
            }),
            true
        );

        assertEq(ipId, expectedIpId);
        assertEq(tokenId, expectedTokenId);
        assertEq(SPG_NFT.ownerOf(tokenId), alice);
    }
}
```

## Run the Test and Verify the Results

2. Run `forge build`. If everything is successful, the command should successfully compile.

3. Now run the test by executing the following command:

```bash
forge test --fork-url https://aeneid.storyrpc.io/ --match-path test/0_IPARegistrar.t.sol
```

## Add License Terms to IP

Congratulations, you registered an IP!

<Card title="Completed Code" href="https://github.com/storyprotocol/story-protocol-boilerplate/blob/main/test/0_IPARegistrar.t.sol" icon="thumbs-up">
  Follow the completed code all the way through.
</Card>

Now that your IP is registered, you can create and attach [License Terms](/concepts/licensing-module/license-terms) to it. This will allow others to mint a license and use your IP, restricted by the terms.

We will go over this on the next page.

# Register License Terms

> Learn how to create new License Terms in Solidity.

<Card title="Completed Code" href="https://github.com/storyprotocol/story-protocol-boilerplate/blob/main/test/1_LicenseTerms.t.sol" icon="thumbs-up">
  Follow the completed code all the way through.
</Card>

[License Terms](/concepts/licensing-module/license-terms) are a configurable set of values that define restrictions on licenses minted from your IP that have those terms. For example, "If you mint this license, you must share 50% of your revenue with me." You can view the full set of terms in [PIL Terms](/concepts/programmable-ip-license/pil-terms).

## Prerequisites

There are a few steps you have to complete before you can start the tutorial.

1. Complete the [Setup Your Own Project](/developers/smart-contracts-guide/setup)

## Before We Start

It's important to know that if **License Terms already exist for the identical set of parameters you intend to create, it is unnecessary to create it again**. License Terms are protocol-wide, so you can use existing License Terms by its `licenseTermsId`.

## Register License Terms

You can view the full set of terms in [PIL Terms](/concepts/programmable-ip-license/pil-terms).

Let's create a test file under `test/1_LicenseTerms.t.sol` to see it work and verify the results:

<Note>
  **Contract Addresses**

  We have filled in the addresses from the Story contracts for you. However you can also find the addresses for them here: [Deployed Smart Contracts](/developers/deployed-smart-contracts)
</Note>

```solidity test/1_LicenseTerms.t.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { IPILicenseTemplate } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";

// Run this test:
// forge test --fork-url https://aeneid.storyrpc.io/ --match-path test/1_LicenseTerms.t.sol
contract LicenseTermsTest is Test {
    address internal alice = address(0xa11ce);

    // For addresses, see https://docs.story.foundation/developers/deployed-smart-contracts
    // Protocol Core - PILicenseTemplate
    IPILicenseTemplate internal PIL_TEMPLATE = IPILicenseTemplate(0x2E896b0b2Fdb7457499B56AAaA4AE55BCB4Cd316);
    // Protocol Core - RoyaltyPolicyLAP
    address internal ROYALTY_POLICY_LAP = 0xBe54FB168b3c982b7AaE60dB6CF75Bd8447b390E;
    // Revenue Token - MERC20
    address internal MERC20 = 0xF2104833d386a2734a4eB3B8ad6FC6812F29E38E;

    function setUp() public {}

    /// @notice Registers new PIL Terms. Anyone can register PIL Terms.
    function test_registerPILTerms() public {
        PILTerms memory pilTerms = PILTerms({
            transferable: true,
            royaltyPolicy: ROYALTY_POLICY_LAP,
            defaultMintingFee: 0,
            expiration: 0,
            commercialUse: true,
            commercialAttribution: true,
            commercializerChecker: address(0),
            commercializerCheckerData: "",
            commercialRevShare: 0,
            commercialRevCeiling: 0,
            derivativesAllowed: true,
            derivativesAttribution: true,
            derivativesApproval: true,
            derivativesReciprocal: true,
            derivativeRevCeiling: 0,
            currency: MERC20,
            uri: ""
        });
        uint256 licenseTermsId = PIL_TEMPLATE.registerLicenseTerms(pilTerms);

        uint256 selectedLicenseTermsId = PIL_TEMPLATE.getLicenseTermsId(pilTerms);
        assertEq(licenseTermsId, selectedLicenseTermsId);
    }
}
```

### PIL Flavors

As you see above, you have to choose between a lot of terms.

We have convenience functions to help you register new terms. We have created [PIL Flavors](/concepts/programmable-ip-license/pil-flavors), which are pre-configured popular combinations of License Terms to help you decide what terms to use. You can view those PIL Flavors and then register terms using the following convenience functions:

<CardGroup cols={2}>
  <Card title="Non-Commercial Social Remixing" href="/concepts/programmable-ip-license/pil-flavors#non-commercial-social-remixing" icon="file">
    Free remixing with attribution. No commercialization.
  </Card>

  <Card title="Commercial Use" href="/concepts/programmable-ip-license/pil-flavors#commercial-use" icon="file">
    Pay to use the license with attribution, but don't have to share revenue.
  </Card>

  <Card title="Commercial Remix" href="/concepts/programmable-ip-license/pil-flavors#commercial-remix" icon="file">
    Pay to use the license with attribution and pay % of revenue earned.
  </Card>

  <Card title="Creative Commons Attribution" href="/concepts/programmable-ip-license/pil-flavors#creative-commons-attribution" icon="file">
    Free remixing and commercial use with attribution.
  </Card>
</CardGroup>

For example:

```solidity Solidity
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";

PILTerms memory pilTerms = PILFlavors.commercialRemix({
  mintingFee: 0,
  commercialRevShare: 5 * 10 ** 6, // 5% rev share
  royaltyPolicy: ROYALTY_POLICY_LAP,
  currencyToken: MERC20
});
```

## Test Your Code!

Run `forge build`. If everything is successful, the command should successfully compile.

Now run the test by executing the following command:

```bash
forge test --fork-url https://aeneid.storyrpc.io/ --match-path test/1_LicenseTerms.t.sol
```

## Attach Terms to Your IP

Congratulations, you created new license terms!

<Card title="Completed Code" href="https://github.com/storyprotocol/story-protocol-boilerplate/blob/main/test/1_LicenseTerms.t.sol" icon="thumbs-up">
  Follow the completed code all the way through.
</Card>

Now that you have registered new license terms, we can attach them to an IP Asset. This will allow others to mint a license and use your IP, restricted by the terms.

We will go over this on the next page.

# Attach Terms to an IPA

> Learn how to attach License Terms to an IP Asset in Solidity.

<Card title="Completed Code" href="https://github.com/storyprotocol/story-protocol-boilerplate/blob/main/test/2_AttachTerms.t.sol" icon="thumbs-up">
  Follow the completed code all the way through.
</Card>

This section demonstrates how to attach [License Terms](/concepts/licensing-module/license-terms) to an [IP Asset](/concepts/ip-asset/overview). By attaching terms, users can publicly mint [License Tokens](/concepts/licensing-module/license-token) (the on-chain "license") with those terms from the IP.

## Prerequisites

There are a few steps you have to complete before you can start the tutorial.

1. Complete the [Setup Your Own Project](/developers/smart-contracts-guide/setup)
2. Create License Terms and have a `licenseTermsId`. You can do that by following the [previous page](/developers/smart-contracts-guide/register-terms).

## Attach License Terms

Now that we have created terms and have the associated `licenseTermsId`, we can attach them to an existing IP Asset.

Let's create a test file under `test/2_AttachTerms.t.sol` to see it work and verify the results:

<Note>
  **Contract Addresses**

  We have filled in the addresses from the Story contracts for you. However you can also find the addresses for them here: [Deployed Smart Contracts](/developers/deployed-smart-contracts)
</Note>

```solidity test/2_AttachTerms.t.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
// for testing purposes only
import { MockIPGraph } from "@storyprotocol/test/mocks/MockIPGraph.sol";
import { IIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IIPAssetRegistry.sol";
import { ILicenseRegistry } from "@storyprotocol/core/interfaces/registries/ILicenseRegistry.sol";
import { IPILicenseTemplate } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";
import { PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";

import { SimpleNFT } from "../src/mocks/SimpleNFT.sol";

// Run this test:
// forge test --fork-url https://aeneid.storyrpc.io/ --match-path test/2_AttachTerms.t.sol
contract AttachTermsTest is Test {
    address internal alice = address(0xa11ce);

    // For addresses, see https://docs.story.foundation/developers/deployed-smart-contracts
    // Protocol Core - IPAssetRegistry
    IIPAssetRegistry internal IP_ASSET_REGISTRY = IIPAssetRegistry(0x77319B4031e6eF1250907aa00018B8B1c67a244b);
    // Protocol Core - LicenseRegistry
    ILicenseRegistry internal LICENSE_REGISTRY = ILicenseRegistry(0x529a750E02d8E2f15649c13D69a465286a780e24);
    // Protocol Core - LicensingModule
    ILicensingModule internal LICENSING_MODULE = ILicensingModule(0x04fbd8a2e56dd85CFD5500A4A4DfA955B9f1dE6f);
    // Protocol Core - PILicenseTemplate
    IPILicenseTemplate internal PIL_TEMPLATE = IPILicenseTemplate(0x2E896b0b2Fdb7457499B56AAaA4AE55BCB4Cd316);
    // Protocol Core - RoyaltyPolicyLAP
    address internal ROYALTY_POLICY_LAP = 0xBe54FB168b3c982b7AaE60dB6CF75Bd8447b390E;
    // Revenue Token - MERC20
    address internal MERC20 = 0xF2104833d386a2734a4eB3B8ad6FC6812F29E38E;

    SimpleNFT public SIMPLE_NFT;
    uint256 public tokenId;
    address public ipId;
    uint256 public licenseTermsId;

    function setUp() public {
        // this is only for testing purposes
        // due to our IPGraph precompile not being
        // deployed on the fork
        vm.etch(address(0x0101), address(new MockIPGraph()).code);

        SIMPLE_NFT = new SimpleNFT("Simple IP NFT", "SIM");
        tokenId = SIMPLE_NFT.mint(alice);
        ipId = IP_ASSET_REGISTRY.register(block.chainid, address(SIMPLE_NFT), tokenId);

        // Register random Commercial Remix terms so we can attach them later
        licenseTermsId = PIL_TEMPLATE.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 10 * 10 ** 6, // 10%
                royaltyPolicy: ROYALTY_POLICY_LAP,
                currencyToken: MERC20
            })
        );
    }

    /// @notice Attaches license terms to an IP Asset.
    /// @dev Only the owner of an IP Asset can attach license terms to it.
    /// So in this case, alice has to be the caller of the function because
    /// she owns the NFT associated with the IP Asset.
    function test_attachLicenseTerms() public {
        vm.prank(alice);
        LICENSING_MODULE.attachLicenseTerms(ipId, address(PIL_TEMPLATE), licenseTermsId);

        assertTrue(LICENSE_REGISTRY.hasIpAttachedLicenseTerms(ipId, address(PIL_TEMPLATE), licenseTermsId));
        assertEq(LICENSE_REGISTRY.getAttachedLicenseTermsCount(ipId), 1);
        (address licenseTemplate, uint256 attachedLicenseTermsId) = LICENSE_REGISTRY.getAttachedLicenseTerms({
            ipId: ipId,
            index: 0
        });
        assertEq(licenseTemplate, address(PIL_TEMPLATE));
        assertEq(attachedLicenseTermsId, licenseTermsId);
    }
}
```

## Test Your Code!

Run `forge build`. If everything is successful, the command should successfully compile.

Now run the test by executing the following command:

```bash
forge test --fork-url https://aeneid.storyrpc.io/ --match-path test/2_AttachTerms.t.sol
```

## Mint a License

Congratulations, you attached terms to an IPA!

<Card title="Completed Code" href="https://github.com/storyprotocol/story-protocol-boilerplate/blob/main/test/2_AttachTerms.t.sol" icon="thumbs-up">
  Follow the completed code all the way through.
</Card>

Now that we have attached License Terms to our IP, the next step is minting a License Token, which we'll go over on the next page.

# Mint a License Token

> Learn how to mint a License Token from an IPA in Solidity.

<Card title="Completed Code" href="https://github.com/storyprotocol/story-protocol-boilerplate/blob/main/test/3_LicenseToken.t.sol" icon="thumbs-up">
  Follow the completed code all the way through.
</Card>

This section demonstrates how to mint a [License Token](/concepts/licensing-module/license-token) from an [IP Asset](/concepts/ip-asset/overview). You can only mint a License Token from an IP Asset if the IP Asset has [License Terms](/concepts/licensing-module/license-terms) attached to it. A License Token is minted as an ERC-721.

There are two reasons you'd mint a License Token:

1. To hold the license and be able to use the underlying IP Asset as the license described (for ex. "Can use commercially as long as you provide proper attribution and share 5% of your revenue)
2. Use the license token to link another IP Asset as a derivative of it. *Note though that, as you'll see later, some SDK functions don't require you to explicitly mint a license token first in order to register a derivative, and will actually handle it for you behind the scenes.*

## Prerequisites

There are a few steps you have to complete before you can start the tutorial.

1. Complete the [Setup Your Own Project](/developers/smart-contracts-guide/setup)
2. An IP Asset has License Terms attached to it. You can learn how to do that [here](/developers/smart-contracts-guide/attach-terms)

## Mint License

Let's say that IP Asset (`ipId = 0x01`) has License Terms (`licenseTermdId = 10`) attached to it. We want to mint 2 License Tokens with those terms to a specific wallet address (`0x02`).

<Warning>
  **Paid Licenses**

  Be mindful that some IP Assets may have license terms attached that require the user minting the license to pay a `mintingFee`.
</Warning>

Let's create a test file under `test/3_LicenseToken.t.sol` to see it work and verify the results:

<Note>
  **Contract Addresses**

  We have filled in the addresses from the Story contracts for you. However you can also find the addresses for them here: [Deployed Smart Contracts](/developers/deployed-smart-contracts)
</Note>

```solidity test/3_LicenseToken.t.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
// for testing purposes only
import { MockIPGraph } from "@storyprotocol/test/mocks/MockIPGraph.sol";
import { IIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IIPAssetRegistry.sol";
import { IPILicenseTemplate } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { ILicenseToken } from "@storyprotocol/core/interfaces/ILicenseToken.sol";
import { RoyaltyPolicyLAP } from "@storyprotocol/core/modules/royalty/policies/LAP/RoyaltyPolicyLAP.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";
import { PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";

import { SimpleNFT } from "../src/mocks/SimpleNFT.sol";

// Run this test:
// forge test --fork-url https://aeneid.storyrpc.io/ --match-path test/3_LicenseToken.t.sol
contract LicenseTokenTest is Test {
    address internal alice = address(0xa11ce);
    address internal bob = address(0xb0b);

    // For addresses, see https://docs.story.foundation/developers/deployed-smart-contracts
    // Protocol Core - IPAssetRegistry
    IIPAssetRegistry internal IP_ASSET_REGISTRY = IIPAssetRegistry(0x77319B4031e6eF1250907aa00018B8B1c67a244b);
    // Protocol Core - LicensingModule
    ILicensingModule internal LICENSING_MODULE = ILicensingModule(0x04fbd8a2e56dd85CFD5500A4A4DfA955B9f1dE6f);
    // Protocol Core - PILicenseTemplate
    IPILicenseTemplate internal PIL_TEMPLATE = IPILicenseTemplate(0x2E896b0b2Fdb7457499B56AAaA4AE55BCB4Cd316);
    // Protocol Core - RoyaltyPolicyLAP
    address internal ROYALTY_POLICY_LAP = 0xBe54FB168b3c982b7AaE60dB6CF75Bd8447b390E;
    // Protocol Core - LicenseToken
    ILicenseToken internal LICENSE_TOKEN = ILicenseToken(0xFe3838BFb30B34170F00030B52eA4893d8aAC6bC);
    // Revenue Token - MERC20
    address internal MERC20 = 0xF2104833d386a2734a4eB3B8ad6FC6812F29E38E;

    SimpleNFT public SIMPLE_NFT;
    uint256 public tokenId;
    address public ipId;
    uint256 public licenseTermsId;

    function setUp() public {
        // this is only for testing purposes
        // due to our IPGraph precompile not being
        // deployed on the fork
        vm.etch(address(0x0101), address(new MockIPGraph()).code);

        SIMPLE_NFT = new SimpleNFT("Simple IP NFT", "SIM");
        tokenId = SIMPLE_NFT.mint(alice);
        ipId = IP_ASSET_REGISTRY.register(block.chainid, address(SIMPLE_NFT), tokenId);

        licenseTermsId = PIL_TEMPLATE.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 10 * 10 ** 6, // 10%
                royaltyPolicy: ROYALTY_POLICY_LAP,
                currencyToken: MERC20
            })
        );

        vm.prank(alice);
        LICENSING_MODULE.attachLicenseTerms(ipId, address(PIL_TEMPLATE), licenseTermsId);
    }

    /// @notice Mints license tokens for an IP Asset.
    /// Anyone can mint a license token.
    function test_mintLicenseToken() public {
        uint256 startLicenseTokenId = LICENSING_MODULE.mintLicenseTokens({
            licensorIpId: ipId,
            licenseTemplate: address(PIL_TEMPLATE),
            licenseTermsId: licenseTermsId,
            amount: 2,
            receiver: bob,
            royaltyContext: "", // for PIL, royaltyContext is empty string
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        assertEq(LICENSE_TOKEN.ownerOf(startLicenseTokenId), bob);
        assertEq(LICENSE_TOKEN.ownerOf(startLicenseTokenId + 1), bob);
    }
}
```

## Test Your Code!

Run `forge build`. If everything is successful, the command should successfully compile.

Now run the test by executing the following command:

```bash
forge test --fork-url https://aeneid.storyrpc.io/ --match-path test/3_LicenseToken.t.sol
```

## Register a Derivative

<Card title="Completed Code" href="https://github.com/storyprotocol/story-protocol-boilerplate/blob/main/test/3_LicenseToken.t.sol" icon="thumbs-up">
  Follow the completed code all the way through.
</Card>

Now that we have minted a License Token, we can hold it or use it to link an IP Asset as a derivative. We will go over that on the next page.

# Register a Derivative

> Learn how to register a derivative/remix IP Asset as a child of another in Solidity.

<Card title="Completed Code" href="https://github.com/storyprotocol/story-protocol-boilerplate/blob/main/test/4_IPARemix.t.sol" icon="thumbs-up">
  All of this page is covered in this working code example.
</Card>

Once a [License Token](/concepts/licensing-module/license-token) has been minted from an IP Asset, the owner of that token (an ERC-721 NFT) can burn it to register their own IP Asset as a derivative of the IP Asset associated with the License Token.

## Prerequisites

There are a few steps you have to complete before you can start the tutorial.

1. Complete the [Setup Your Own Project](/developers/smart-contracts-guide/setup)
2. Have a minted License Token. You can learn how to do that [here](/developers/smart-contracts-guide/mint-license)

## Register as Derivative

Let's create a test file under `test/4_IPARemix.t.sol` to see it work and verify the results:

<Note>
  **Contract Addresses**

  We have filled in the addresses from the Story contracts for you. However you can also find the addresses for them here: [Deployed Smart Contracts](/developers/deployed-smart-contracts)
</Note>

```solidity test/4_IPARemix.t.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
// for testing purposes only
import { MockIPGraph } from "@storyprotocol/test/mocks/MockIPGraph.sol";
import { IIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IIPAssetRegistry.sol";
import { ILicenseRegistry } from "@storyprotocol/core/interfaces/registries/ILicenseRegistry.sol";
import { IPILicenseTemplate } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";
import { PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";

import { SimpleNFT } from "../src/mocks/SimpleNFT.sol";

// Run this test:
// forge test --fork-url https://aeneid.storyrpc.io/ --match-path test/4_IPARemix.t.sol
contract IPARemixTest is Test {
    address internal alice = address(0xa11ce);
    address internal bob = address(0xb0b);

    // For addresses, see https://docs.story.foundation/developers/deployed-smart-contracts
    // Protocol Core - IPAssetRegistry
    IIPAssetRegistry internal IP_ASSET_REGISTRY = IIPAssetRegistry(0x77319B4031e6eF1250907aa00018B8B1c67a244b);
    // Protocol Core - LicenseRegistry
    ILicenseRegistry internal LICENSE_REGISTRY = ILicenseRegistry(0x529a750E02d8E2f15649c13D69a465286a780e24);
    // Protocol Core - LicensingModule
    ILicensingModule internal LICENSING_MODULE = ILicensingModule(0x04fbd8a2e56dd85CFD5500A4A4DfA955B9f1dE6f);
    // Protocol Core - PILicenseTemplate
    IPILicenseTemplate internal PIL_TEMPLATE = IPILicenseTemplate(0x2E896b0b2Fdb7457499B56AAaA4AE55BCB4Cd316);
    // Protocol Core - RoyaltyPolicyLAP
    address internal ROYALTY_POLICY_LAP = 0xBe54FB168b3c982b7AaE60dB6CF75Bd8447b390E;
    // Revenue Token - MERC20
    address internal MERC20 = 0xF2104833d386a2734a4eB3B8ad6FC6812F29E38E;

    SimpleNFT public SIMPLE_NFT;
    uint256 public tokenId;
    address public ipId;
    uint256 public licenseTermsId;
    uint256 public startLicenseTokenId;

    function setUp() public {
        // this is only for testing purposes
        // due to our IPGraph precompile not being
        // deployed on the fork
        vm.etch(address(0x0101), address(new MockIPGraph()).code);

        SIMPLE_NFT = new SimpleNFT("Simple IP NFT", "SIM");
        tokenId = SIMPLE_NFT.mint(alice);
        ipId = IP_ASSET_REGISTRY.register(block.chainid, address(SIMPLE_NFT), tokenId);

        licenseTermsId = PIL_TEMPLATE.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 10 * 10 ** 6, // 10%
                royaltyPolicy: ROYALTY_POLICY_LAP,
                currencyToken: MERC20
            })
        );

        vm.prank(alice);
        LICENSING_MODULE.attachLicenseTerms(ipId, address(PIL_TEMPLATE), licenseTermsId);
        startLicenseTokenId = LICENSING_MODULE.mintLicenseTokens({
            licensorIpId: ipId,
            licenseTemplate: address(PIL_TEMPLATE),
            licenseTermsId: licenseTermsId,
            amount: 2,
            receiver: bob,
            royaltyContext: "", // for PIL, royaltyContext is empty string
            maxMintingFee: 0,
            maxRevenueShare: 0
        });
    }

    /// @notice Mints an NFT to be registered as IP, and then
    /// linked as a derivative of alice's asset using the
    /// minted license token.
    function test_registerDerivativeWithLicenseTokens() public {
        // First we mint an NFT and register it as an IP Asset,
        // owned by Bob.
        uint256 childTokenId = SIMPLE_NFT.mint(bob);
        address childIpId = IP_ASSET_REGISTRY.register(block.chainid, address(SIMPLE_NFT), childTokenId);

        uint256[] memory licenseTokenIds = new uint256[](1);
        licenseTokenIds[0] = startLicenseTokenId;

        // Bob uses the License Token he has from Alice's IP
        // to register his IP as a derivative of Alice's IP.
        vm.prank(bob);
        LICENSING_MODULE.registerDerivativeWithLicenseTokens({
            childIpId: childIpId,
            licenseTokenIds: licenseTokenIds,
            royaltyContext: "", // empty for PIL
            maxRts: 0
        });

        assertTrue(LICENSE_REGISTRY.hasDerivativeIps(ipId));
        assertTrue(LICENSE_REGISTRY.isParentIp(ipId, childIpId));
        assertTrue(LICENSE_REGISTRY.isDerivativeIp(childIpId));
        assertEq(LICENSE_REGISTRY.getParentIpCount(childIpId), 1);
        assertEq(LICENSE_REGISTRY.getDerivativeIpCount(ipId), 1);
        assertEq(LICENSE_REGISTRY.getParentIp({ childIpId: childIpId, index: 0 }), ipId);
        assertEq(LICENSE_REGISTRY.getDerivativeIp({ parentIpId: ipId, index: 0 }), childIpId);
    }
}
```

## Test Your Code!

Run `forge build`. If everything is successful, the command should successfully compile.

Now run the test by executing the following command:

```bash
forge test --fork-url https://aeneid.storyrpc.io/ --match-path test/4_IPARemix.t.sol
```

## Paying and Claiming Revenue

Congratulations, you registered a derivative IP Asset!

<Card title="Completed Code" href="https://github.com/storyprotocol/story-protocol-boilerplate/blob/main/test/4_IPARemix.t.sol" icon="thumbs-up">
  All of this page is covered in this working code example.
</Card>

Now that we have established parent-child IP relationships, we can begin to explore payments and automated revenue share based on the license terms. We'll cover that in the upcoming pages.


# Pay & Claim Revenue

> Learn how to pay an IP Asset and claim revenue in Solidity.

<Card title="Completed Code" href="https://github.com/storyprotocol/story-protocol-boilerplate/blob/main/test/5_Royalty.t.sol" icon="thumbs-up">
  Follow the completed code all the way through.
</Card>

This section demonstrates how to pay an IP Asset. There are a few reasons you would do this:

1. You simply want to "tip" an IP
2. You have to because your license terms with an ancestor IP require you to forward a certain % of payment

In either scenario, you would use the below `payRoyaltyOnBehalf` function. When this happens, the [Royalty Module](/concepts/royalty-module/overview) automatically handles the different payment flows such that parent IP Assets who have negotiated a certain `commercialRevShare` with the IPA being paid can claim their due share.

## Prerequisites

There are a few steps you have to complete before you can start the tutorial.

1. Complete the [Setup Your Own Project](/developers/smart-contracts-guide/setup)
2. Have a basic understanding of the [Royalty Module](/concepts/royalty-module/overview)
3. A child IPA and a parent IPA, for which their license terms have a commercial revenue share to make this example work

## Before We Start

You can pay an IP Asset using the `payRoyaltyOnBehalf` function from the [Royalty Module](/concepts/royalty-module/overview).

You will be paying the IP Asset with [MockERC20](https://aeneid.storyscan.io/address/0xF2104833d386a2734a4eB3B8ad6FC6812F29E38E). Usually you would pay with \$WIP, but because we need to mint some tokens to test, we will use MockERC20.

To help with the following scenarios, let's say we have a parent IP Asset that has negotiated a 50% `commercialRevShare` with its child IP Asset.

### Whitelisted Revenue Tokens

Only tokens that are whitelisted by our protocol can be used as payment ("revenue") tokens. MockERC20 is one of those tokens. To see that list, go [here](/developers/deployed-smart-contracts#whitelisted-revenue-tokens).

## Paying an IP Asset

We can pay an IP Asset like so:

```solidity Solidity
ROYALTY_MODULE.payRoyaltyOnBehalf(childIpId, address(0), address(MERC20), 10);
```

This will send 10 \$MERC20 to the `childIpId`'s [IP Royalty Vault](/concepts/royalty-module/ip-royalty-vault). From there, the child can claim revenue. In the next section, you'll see a working version of this.

<Warning>
  **Important: Approving the Royalty Module**

  Before you call `payRoyaltyOnBehalf`, you have to approve the royalty module to spend the tokens for you. In the section below, you will see that we call `MERC20.approve(address(ROYALTY_MODULE), 10);` or else it will not work.
</Warning>

## Claim Revenue

When payments are made, they eventually end up in an IP Asset's [IP Royalty Vault](/concepts/royalty-module/ip-royalty-vault). From here, they are claimed/transferred to whoever owns the Royalty Tokens associated with it, which represent a % of revenue share for a given IP Asset's IP Royalty Vault.

The IP Account (the smart contract that represents the [IP Asset](/concepts/ip-asset/overview)) is what holds 100% of the Royalty Tokens when it's first registered. So usually, it indeed holds most of the Royalty Tokens.

Let's create a test file under `test/5_Royalty.t.sol` to see it work and verify the results:

<Note>
  **Contract Addresses**

  We have filled in the addresses from the Story contracts for you. However you can also find the addresses for them here: [Deployed Smart Contracts](/developers/deployed-smart-contracts)
</Note>

```solidity test/5_Royalty.t.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
// for testing purposes only
import { MockIPGraph } from "@storyprotocol/test/mocks/MockIPGraph.sol";
import { IPAssetRegistry } from "@storyprotocol/core/registries/IPAssetRegistry.sol";
import { LicenseRegistry } from "@storyprotocol/core/registries/LicenseRegistry.sol";
import { PILicenseTemplate } from "@storyprotocol/core/modules/licensing/PILicenseTemplate.sol";
import { RoyaltyPolicyLAP } from "@storyprotocol/core/modules/royalty/policies/LAP/RoyaltyPolicyLAP.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";
import { PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { LicensingModule } from "@storyprotocol/core/modules/licensing/LicensingModule.sol";
import { LicenseToken } from "@storyprotocol/core/LicenseToken.sol";
import { RoyaltyWorkflows } from "@storyprotocol/periphery/workflows/RoyaltyWorkflows.sol";
import { RoyaltyModule } from "@storyprotocol/core/modules/royalty/RoyaltyModule.sol";
import { MockERC20 } from "@storyprotocol/test/mocks/token/MockERC20.sol";

import { SimpleNFT } from "../src/mocks/SimpleNFT.sol";

// Run this test:
// forge test --fork-url https://aeneid.storyrpc.io/ --match-path test/5_Royalty.t.sol
contract RoyaltyTest is Test {
    address internal alice = address(0xa11ce);
    address internal bob = address(0xb0b);

    // For addresses, see https://docs.story.foundation/developers/deployed-smart-contracts
    // Protocol Core - IPAssetRegistry
    IPAssetRegistry internal IP_ASSET_REGISTRY = IPAssetRegistry(0x77319B4031e6eF1250907aa00018B8B1c67a244b);
    // Protocol Core - LicenseRegistry
    LicenseRegistry internal LICENSE_REGISTRY = LicenseRegistry(0x529a750E02d8E2f15649c13D69a465286a780e24);
    // Protocol Core - LicensingModule
    LicensingModule internal LICENSING_MODULE = LicensingModule(0x04fbd8a2e56dd85CFD5500A4A4DfA955B9f1dE6f);
    // Protocol Core - PILicenseTemplate
    PILicenseTemplate internal PIL_TEMPLATE = PILicenseTemplate(0x2E896b0b2Fdb7457499B56AAaA4AE55BCB4Cd316);
    // Protocol Core - RoyaltyPolicyLAP
    RoyaltyPolicyLAP internal ROYALTY_POLICY_LAP = RoyaltyPolicyLAP(0xBe54FB168b3c982b7AaE60dB6CF75Bd8447b390E);
    // Protocol Core - LicenseToken
    LicenseToken internal LICENSE_TOKEN = LicenseToken(0xFe3838BFb30B34170F00030B52eA4893d8aAC6bC);
    // Protocol Core - RoyaltyModule
    RoyaltyModule internal ROYALTY_MODULE = RoyaltyModule(0xD2f60c40fEbccf6311f8B47c4f2Ec6b040400086);
    // Protocol Periphery - RoyaltyWorkflows
    RoyaltyWorkflows internal ROYALTY_WORKFLOWS = RoyaltyWorkflows(0x9515faE61E0c0447C6AC6dEe5628A2097aFE1890);
    // Mock - MERC20
    MockERC20 internal MERC20 = MockERC20(0xF2104833d386a2734a4eB3B8ad6FC6812F29E38E);

    SimpleNFT public SIMPLE_NFT;
    uint256 public tokenId;
    address public ipId;
    uint256 public licenseTermsId;
    uint256 public startLicenseTokenId;
    address public childIpId;

    function setUp() public {
        // this is only for testing purposes
        // due to our IPGraph precompile not being
        // deployed on the fork
        vm.etch(address(0x0101), address(new MockIPGraph()).code);

        SIMPLE_NFT = new SimpleNFT("Simple IP NFT", "SIM");
        tokenId = SIMPLE_NFT.mint(alice);
        ipId = IP_ASSET_REGISTRY.register(block.chainid, address(SIMPLE_NFT), tokenId);

        licenseTermsId = PIL_TEMPLATE.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 10 * 10 ** 6, // 10%
                royaltyPolicy: address(ROYALTY_POLICY_LAP),
                currencyToken: address(MERC20)
            })
        );

        vm.prank(alice);
        LICENSING_MODULE.attachLicenseTerms(ipId, address(PIL_TEMPLATE), licenseTermsId);
        startLicenseTokenId = LICENSING_MODULE.mintLicenseTokens({
            licensorIpId: ipId,
            licenseTemplate: address(PIL_TEMPLATE),
            licenseTermsId: licenseTermsId,
            amount: 2,
            receiver: bob,
            royaltyContext: "", // for PIL, royaltyContext is empty string
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        // Registers a child IP (owned by Bob) as a derivative of Alice's IP.
        uint256 childTokenId = SIMPLE_NFT.mint(bob);
        childIpId = IP_ASSET_REGISTRY.register(block.chainid, address(SIMPLE_NFT), childTokenId);

        uint256[] memory licenseTokenIds = new uint256[](1);
        licenseTokenIds[0] = startLicenseTokenId;

        vm.prank(bob);
        LICENSING_MODULE.registerDerivativeWithLicenseTokens({
            childIpId: childIpId,
            licenseTokenIds: licenseTokenIds,
            royaltyContext: "", // empty for PIL
            maxRts: 0
        });
    }

    /// @notice Pays MERC20 to Bob's IP. Some of this MERC20 is then claimable
    /// by Alice's IP.
    /// @dev In this case, this contract will act as the 3rd party paying MERC20
    /// to Bob (the child IP).
    function test_claimAllRevenue() public {
        // ADMIN SETUP
        // We mint 100 MERC20 to this contract so it has some money to pay.
        MERC20.mint(address(this), 100);
        // We have to approve the Royalty Module to spend MERC20 on our behalf, which
        // it will do using `payRoyaltyOnBehalf`.
        MERC20.approve(address(ROYALTY_MODULE), 10);

        // This contract pays 10 MERC20 to Bob's IP.
        ROYALTY_MODULE.payRoyaltyOnBehalf(childIpId, address(0), address(MERC20), 10);

        // Now that Bob's IP has been paid, Alice can claim her share (1 MERC20, which
        // is 10% as specified in the license terms)
        address[] memory childIpIds = new address[](1);
        address[] memory royaltyPolicies = new address[](1);
        address[] memory currencyTokens = new address[](1);
        childIpIds[0] = childIpId;
        royaltyPolicies[0] = address(ROYALTY_POLICY_LAP);
        currencyTokens[0] = address(MERC20);

        uint256[] memory amountsClaimed = ROYALTY_WORKFLOWS.claimAllRevenue({
            ancestorIpId: ipId,
            claimer: ipId,
            childIpIds: childIpIds,
            royaltyPolicies: royaltyPolicies,
            currencyTokens: currencyTokens
        });

        // Check that 1 MERC20 was claimed by Alice's IP Account
        assertEq(amountsClaimed[0], 1);
        // Check that Alice's IP Account now has 1 MERC20 in its balance.
        assertEq(MERC20.balanceOf(ipId), 1);
        // Check that Bob's IP now has 9 MERC20 in its Royalty Vault, which it
        // can claim to its IP Account at a later point if he wants.
        assertEq(MERC20.balanceOf(ROYALTY_MODULE.ipRoyaltyVaults(childIpId)), 9);
    }
}
```

## Test Your Code!

Run `forge build`. If everything is successful, the command should successfully compile.

Now run the test by executing the following command:

```bash
forge test --fork-url https://aeneid.storyrpc.io/ --match-path test/5_Royalty.t.sol
```

## Dispute an IP

Congratulations, you claimed revenue using the [Royalty Module](/concepts/royalty-module/overview)!

<Card title="Completed Code" href="https://github.com/storyprotocol/story-protocol-boilerplate/blob/main/test/5_Royalty.t.sol" icon="thumbs-up">
  Follow the completed code all the way through.
</Card>

Now what happens if an IP Asset doesn't pay their due share? We can dispute the IP on-chain, which we will cover on the next page.

<Warning>Coming soon!</Warning>


# Using an Example

> Combine all of our tutorials together in a practical example.

<CardGroup cols={2}>
  <Card title="Completed Code" href="https://github.com/storyprotocol/story-protocol-boilerplate/blob/main/src/Example.sol" icon="thumbs-up">
    See the completed code.
  </Card>

  <Card title="Video Walkthrough" href="https://www.youtube.com/watch?v=X421IuZENqM" icon="video">
    Check out a video walkthrough of this tutorial!
  </Card>
</CardGroup>

# Writing the Smart Contract

Now that we have walked through each of the individual steps, let's try to write, deploy, and verify our own smart contract.

## Register IPA, Register License Terms, and Attach to IPA

In this first section, we will combine a few of the tutorials into one. We will create a function named `mintAndRegisterAndCreateTermsAndAttach` that allows you to mint & register a new IP Asset, register new License Terms, and attach those terms to an IP Asset. It will also accept a `receiver` field to be the owner of the new IP Asset.

### Prerequisites

* Complete [Register an IP Asset](/developers/smart-contracts-guide/register-ip-asset)
* Complete [Register License Terms](/developers/smart-contracts-guide/register-terms)
* Complete [Attach Terms to an IPA](/developers/smart-contracts-guide/attach-terms)

### Writing our Contract

Create a new file under `./src/Example.sol` and paste the following:

<Note>
  **Contract Addresses**

  In order to get the contract addresses to pass in the constructor, go to [Deployed Smart Contracts](/developers/deployed-smart-contracts).
</Note>

```solidity src/Example.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { IIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IIPAssetRegistry.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { IPILicenseTemplate } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";

import { SimpleNFT } from "./mocks/SimpleNFT.sol";

import { ERC721Holder } from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

/// @notice An example contract that demonstrates how to mint an NFT, register it as an IP Asset,
/// attach license terms to it, mint a license token from it, and register it as a derivative of the parent.
contract Example is ERC721Holder {
  IIPAssetRegistry public immutable IP_ASSET_REGISTRY;
  ILicensingModule public immutable LICENSING_MODULE;
  IPILicenseTemplate public immutable PIL_TEMPLATE;
  address public immutable ROYALTY_POLICY_LAP;
  address public immutable WIP;
  SimpleNFT public immutable SIMPLE_NFT;

  constructor(
    address ipAssetRegistry,
    address licensingModule,
    address pilTemplate,
    address royaltyPolicyLAP,
    address wip
  ) {
    IP_ASSET_REGISTRY = IIPAssetRegistry(ipAssetRegistry);
    LICENSING_MODULE = ILicensingModule(licensingModule);
    PIL_TEMPLATE = IPILicenseTemplate(pilTemplate);
    ROYALTY_POLICY_LAP = royaltyPolicyLAP;
    WIP = wip;
    // Create a new Simple NFT collection
    SIMPLE_NFT = new SimpleNFT("Simple IP NFT", "SIM");
  }

  /// @notice Mint an NFT, register it as an IP Asset, and attach License Terms to it.
  /// @param receiver The address that will receive the NFT/IPA.
  /// @return tokenId The token ID of the NFT representing ownership of the IPA.
  /// @return ipId The address of the IP Account.
  /// @return licenseTermsId The ID of the license terms.
  function mintAndRegisterAndCreateTermsAndAttach(
    address receiver
  ) external returns (uint256 tokenId, address ipId, uint256 licenseTermsId) {
    // We mint to this contract so that it has permissions
    // to attach license terms to the IP Asset.
    // We will later transfer it to the intended `receiver`
    tokenId = SIMPLE_NFT.mint(address(this));
    ipId = IP_ASSET_REGISTRY.register(block.chainid, address(SIMPLE_NFT), tokenId);

    // register license terms so we can attach them later
    licenseTermsId = PIL_TEMPLATE.registerLicenseTerms(
      PILFlavors.commercialRemix({
        mintingFee: 0,
        commercialRevShare: 10 * 10 ** 6, // 10%
        royaltyPolicy: ROYALTY_POLICY_LAP,
        currencyToken: WIP
      })
    );

    // attach the license terms to the IP Asset
    LICENSING_MODULE.attachLicenseTerms(ipId, address(PIL_TEMPLATE), licenseTermsId);

    // transfer the NFT to the receiver so it owns the IPA
    SIMPLE_NFT.transferFrom(address(this), receiver, tokenId);
  }
}
```

## Mint a License Token and Register as Derivative

In this next section, we will combine a few of the later tutorials into one. We will create a function named `mintLicenseTokenAndRegisterDerivative` that allows a potentially different user to register their own "child" (derivative) IP Asset, mint a License Token from the "parent" (root) IP Asset, and register their child IPA as a derivative of the parent IPA. It will accept a few parameters:

1. `parentIpId`: the `ipId` of the parent IPA
2. `licenseTermsId`: the id of the License Terms you want to mint a License Token for
3. `receiver`: the owner of the child IPA

### Prerequisites

* Complete [Mint a License Token](/developers/smart-contracts-guide/mint-license)
* Complete [Register a Derivative](/developers/smart-contracts-guide/register-derivative)

### Writing our Contract

In your `Example.sol` contract, add the following function at the bottom:

```solidity src/Example.sol
/// @notice Mint and register a new child IPA, mint a License Token
/// from the parent, and register it as a derivative of the parent.
/// @param parentIpId The ipId of the parent IPA.
/// @param licenseTermsId The ID of the license terms you will
/// mint a license token from.
/// @param receiver The address that will receive the NFT/IPA.
/// @return childTokenId The token ID of the NFT representing ownership of the child IPA.
/// @return childIpId The address of the child IPA.
function mintLicenseTokenAndRegisterDerivative(
  address parentIpId,
  uint256 licenseTermsId,
  address receiver
) external returns (uint256 childTokenId, address childIpId) {
  // We mint to this contract so that it has permissions
  // to register itself as a derivative of another
  // IP Asset.
  // We will later transfer it to the intended `receiver`
  childTokenId = SIMPLE_NFT.mint(address(this));
  childIpId = IP_ASSET_REGISTRY.register(block.chainid, address(SIMPLE_NFT), childTokenId);

  // mint a license token from the parent
  uint256 licenseTokenId = LICENSING_MODULE.mintLicenseTokens({
    licensorIpId: parentIpId,
    licenseTemplate: address(PIL_TEMPLATE),
    licenseTermsId: licenseTermsId,
    amount: 1,
    // mint the license token to this contract so it can
    // use it to register as a derivative of the parent
    receiver: address(this),
    royaltyContext: "", // for PIL, royaltyContext is empty string
    maxMintingFee: 0,
    maxRevenueShare: 0
  });

  uint256[] memory licenseTokenIds = new uint256[](1);
  licenseTokenIds[0] = licenseTokenId;

  // register the new child IPA as a derivative
  // of the parent
  LICENSING_MODULE.registerDerivativeWithLicenseTokens({
    childIpId: childIpId,
    licenseTokenIds: licenseTokenIds,
    royaltyContext: "", // empty for PIL
    maxRts: 0
  });

  // transfer the NFT to the receiver so it owns the child IPA
  SIMPLE_NFT.transferFrom(address(this), receiver, childTokenId);
}
```

# Testing our Contract

Create another new file under `test/Example.t.sol` and paste the following:

```solidity test/Example.t.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
// for testing purposes only
import { MockIPGraph } from "@storyprotocol/test/mocks/MockIPGraph.sol";
import { IIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IIPAssetRegistry.sol";
import { ILicenseRegistry } from "@storyprotocol/core/interfaces/registries/ILicenseRegistry.sol";

import { Example } from "../src/Example.sol";
import { SimpleNFT } from "../src/mocks/SimpleNFT.sol";

// Run this test:
// forge test --fork-url https://aeneid.storyrpc.io/ --match-path test/Example.t.sol
contract ExampleTest is Test {
  address internal alice = address(0xa11ce);
  address internal bob = address(0xb0b);

  // For addresses, see https://docs.story.foundation/developers/deployed-smart-contracts
  // Protocol Core - IPAssetRegistry
  address internal ipAssetRegistry = 0x77319B4031e6eF1250907aa00018B8B1c67a244b;
  // Protocol Core - LicenseRegistry
  address internal licenseRegistry = 0x529a750E02d8E2f15649c13D69a465286a780e24;
  // Protocol Core - LicensingModule
  address internal licensingModule = 0x04fbd8a2e56dd85CFD5500A4A4DfA955B9f1dE6f;
  // Protocol Core - PILicenseTemplate
  address internal pilTemplate = 0x2E896b0b2Fdb7457499B56AAaA4AE55BCB4Cd316;
  // Protocol Core - RoyaltyPolicyLAP
  address internal royaltyPolicyLAP = 0xBe54FB168b3c982b7AaE60dB6CF75Bd8447b390E;
  // Revenue Token - WIP
  address internal wip = 0x1514000000000000000000000000000000000000;

  SimpleNFT public SIMPLE_NFT;
  Example public EXAMPLE;

  function setUp() public {
    // this is only for testing purposes
    // due to our IPGraph precompile not being
    // deployed on the fork
    vm.etch(address(0x0101), address(new MockIPGraph()).code);

    EXAMPLE = new Example(ipAssetRegistry, licensingModule, pilTemplate, royaltyPolicyLAP, wip);
    SIMPLE_NFT = SimpleNFT(EXAMPLE.SIMPLE_NFT());
  }

  function test_mintAndRegisterAndCreateTermsAndAttach() public {
    ILicenseRegistry LICENSE_REGISTRY = ILicenseRegistry(licenseRegistry);
    IIPAssetRegistry IP_ASSET_REGISTRY = IIPAssetRegistry(ipAssetRegistry);

    uint256 expectedTokenId = SIMPLE_NFT.nextTokenId();
    address expectedIpId = IP_ASSET_REGISTRY.ipId(block.chainid, address(SIMPLE_NFT), expectedTokenId);

    (uint256 tokenId, address ipId, uint256 licenseTermsId) = EXAMPLE.mintAndRegisterAndCreateTermsAndAttach(alice);

    assertEq(tokenId, expectedTokenId);
    assertEq(ipId, expectedIpId);
    assertEq(SIMPLE_NFT.ownerOf(tokenId), alice);

    assertTrue(LICENSE_REGISTRY.hasIpAttachedLicenseTerms(ipId, pilTemplate, licenseTermsId));
    assertEq(LICENSE_REGISTRY.getAttachedLicenseTermsCount(ipId), 1);
    (address licenseTemplate, uint256 attachedLicenseTermsId) = LICENSE_REGISTRY.getAttachedLicenseTerms({
      ipId: ipId,
      index: 0
    });
    assertEq(licenseTemplate, pilTemplate);
    assertEq(attachedLicenseTermsId, licenseTermsId);
  }

  function test_mintLicenseTokenAndRegisterDerivative() public {
    ILicenseRegistry LICENSE_REGISTRY = ILicenseRegistry(licenseRegistry);
    IIPAssetRegistry IP_ASSET_REGISTRY = IIPAssetRegistry(ipAssetRegistry);

    (uint256 parentTokenId, address parentIpId, uint256 licenseTermsId) = EXAMPLE
    .mintAndRegisterAndCreateTermsAndAttach(alice);

    (uint256 childTokenId, address childIpId) = EXAMPLE.mintLicenseTokenAndRegisterDerivative(
      parentIpId,
      licenseTermsId,
      bob
    );

    assertTrue(LICENSE_REGISTRY.hasDerivativeIps(parentIpId));
    assertTrue(LICENSE_REGISTRY.isParentIp(parentIpId, childIpId));
    assertTrue(LICENSE_REGISTRY.isDerivativeIp(childIpId));
    assertEq(LICENSE_REGISTRY.getDerivativeIpCount(parentIpId), 1);
    assertEq(LICENSE_REGISTRY.getParentIpCount(childIpId), 1);
    assertEq(LICENSE_REGISTRY.getParentIp({ childIpId: childIpId, index: 0 }), parentIpId);
    assertEq(LICENSE_REGISTRY.getDerivativeIp({ parentIpId: parentIpId, index: 0 }), childIpId);
  }
}
```

Run `forge build`. If everything is successful, the command should successfully compile.

To test this out, simply run the following command:

```bash
forge test --fork-url https://aeneid.storyrpc.io/ --match-path test/Example.t.sol
```

# Deploy & Verify the Example Contract

The `--constructor-args` come from [Deployed Smart Contracts](/developers/deployed-smart-contracts).

```bash
forge create \
  --rpc-url https://aeneid.storyrpc.io/ \
  --private-key $PRIVATE_KEY \
  ./src/Example.sol:Example \
  --verify \
  --verifier blockscout \
  --verifier-url https://aeneid.storyscan.io/api/ \
  --constructor-args 0x77319B4031e6eF1250907aa00018B8B1c67a244b 0x04fbd8a2e56dd85CFD5500A4A4DfA955B9f1dE6f 0x2E896b0b2Fdb7457499B56AAaA4AE55BCB4Cd316 0xBe54FB168b3c982b7AaE60dB6CF75Bd8447b390E 0xF2104833d386a2734a4eB3B8ad6FC6812F29E38E
```

If everything worked correctly, you should see something like `Deployed to: 0xfb0923D531C1ca54AB9ee10CB8364b23d0C7F47d` in the console. Paste that address into [the explorer](https://aeneid.storyscan.io/) and see your verified contract!

# Great job! :)

<CardGroup cols={2}>
  <Card title="Completed Code" href="https://github.com/storyprotocol/story-protocol-boilerplate/blob/main/src/Example.sol" icon="thumbs-up">
    See the completed code.
  </Card>

  <Card title="Video Walkthrough" href="https://www.youtube.com/watch?v=X421IuZENqM" icon="video">
    Check out a video walkthrough of this tutorial!
  </Card>
</CardGroup>

# How to Tip an IP

> Learn how to tip an IP Asset using the SDK and Smart Contracts.

* [Use the SDK](#using-the-sdk)
* [Use a Smart Contract](#using-a-smart-contract)

# Using the SDK

<CardGroup cols={1}>
  <Card title="Completed Code" href="https://github.com/storyprotocol/typescript-tutorial/blob/main/scripts/royalty/payRevenue.ts" icon="thumbs-up">
    See a completed, working example of setting up a simple derivative chain and
    then tipping the child IP Asset.
  </Card>
</CardGroup>

In this tutorial, you will learn how to send money ("tip") an IP Asset using the TypeScript SDK.

## The Explanation

In this scenario, let's say there is a parent IP Asset that represents Mickey Mouse. Someone else draws a hat on that Mickey Mouse and registers it as a derivative (or "child") IP Asset. The License Terms specify that the child must share 50% of all commercial revenue (`commercialRevShare = 50`) with the parent. Someone else (a 3rd party user) comes along and wants to send the derivative 2 \$WIP for being really cool.

For the purposes of this example, we will assume the child is already registered as a derivative IP Asset. If you want help learning this, check out [Register a Derivative](/developers/typescript-sdk/register-derivative).

* Parent IP ID: `0x42595dA29B541770D9F9f298a014bF912655E183`
* Child IP ID: `0xeaa4Eed346373805B377F5a4fe1daeFeFB3D182a`

## 0. Before you Start

There are a few steps you have to complete before you can start the tutorial.

1. You will need to install [Node.js](https://nodejs.org/en/download) and [npm](https://docs.npmjs.com/downloading-and-installing-node-js-and-npm). If you've coded before, you likely have these.
2. Add your Story Network Testnet wallet's private key to `.env` file:

```text env
WALLET_PRIVATE_KEY=<YOUR_WALLET_PRIVATE_KEY>
```

3. Add your preferred RPC URL to your `.env` file. You can just use the public default one we provide:

```text env
RPC_PROVIDER_URL=https://aeneid.storyrpc.io
```

4. Install the dependencies:

```bash Terminal
npm install @story-protocol/core-sdk viem
```

## 1. Set up your Story Config

In a `utils.ts` file, add the following code to set up your Story Config:

* Associated docs: [TypeScript SDK Setup](/developers/typescript-sdk/setup)

```typescript utils.ts
import { StoryClient, StoryConfig } from "@story-protocol/core-sdk";
import { http } from "viem";
import { privateKeyToAccount, Address, Account } from "viem/accounts";

const privateKey: Address = `0x${process.env.WALLET_PRIVATE_KEY}`;
export const account: Account = privateKeyToAccount(privateKey);

const config: StoryConfig = {
  account: account,
  transport: http(process.env.RPC_PROVIDER_URL),
  chainId: "aeneid",
};
export const client = StoryClient.newClient(config);
```

## 2. Tipping the Derivative IP Asset

Now create a `main.ts` file. We will use the `payRoyaltyOnBehalf` function to pay the derivative asset.

You will be paying the IP Asset with \[$WIP](https://aeneid.storyscan.io/address/0x1514000000000000000000000000000000000000). **Note that if you don't have enough $WIP, the function will auto wrap an equivalent amount of $IP into $WIP for you.\*\* If you don't have enough of either, it will fail.

<Note>
  **Whitelisted Revenue Tokens**

  Only tokens that are whitelisted by our protocol can be used as payment ("revenue") tokens. \$WIP is one of those tokens. To see that list, go [here](/developers/deployed-smart-contracts).
</Note>

Now we can call the `payRoyaltyOnBehalf` function. In this case:

1. `receiverIpId` is the `ipId` of the derivative (child) asset
2. `payerIpId` is `zeroAddress` because the payer is a 3rd party (someone that thinks Mickey Mouse with a hat on him is cool), and not necessarily another IP Asset
3. `token` is the address of \$WIP, which can be found [here](/concepts/royalty-module/ip-royalty-vault#whitelisted-revenue-tokens)
4. `amount` is 2, since the person tipping wants to send 2 \$WIP

```typescript main.ts
import { client } from "./utils";
import { zeroAddress, parseEther } from "viem";
import { WIP_TOKEN_ADDRESS } from "@story-protocol/core-sdk";

async function main() {
  const response = await client.royalty.payRoyaltyOnBehalf({
    receiverIpId: "0xeaa4Eed346373805B377F5a4fe1daeFeFB3D182a",
    payerIpId: zeroAddress,
    token: WIP_TOKEN_ADDRESS,
    amount: parseEther("2"), // 2 $WIP
  });
  console.log(`Paid royalty at transaction hash ${response.txHash}`);
}

main();
```

## 3. Child Claiming Due Revenue

At this point we have already finished the tutorial: we learned how to tip an IP Asset. But what if the child and parent want to claim their due revenue?

The child has been paid 2 \$WIP. But remember, it shares 50% of its revenue with the parent IP because of the `commercialRevenue = 50` in the license terms.

The child IP can claim its 1 \$WIP by calling the `claimAllRevenue` function:

* `ancestorIpId` is the `ipId` of the IP Asset thats associated with the royalty vault that has the funds in it (more simply, this is just the child's `ipId`)
* `currencyTokens` is an array that contains the address of \$WIP, which can be found [here](/concepts/royalty-module/ip-royalty-vault#whitelisted-revenue-tokens)
* `claimer` is the address that holds the royalty tokens associated with the child's [IP Royalty Vault](/concepts/royalty-module/ip-royalty-vault). By default, they are in the IP Account, which is just the `ipId` of the child asset

```typescript main.ts
import { client } from "./utils";
import { zeroAddress, parseEther } from "viem";
import { WIP_TOKEN_ADDRESS } from "@story-protocol/core-sdk";

async function main() {
  // previous code here ...
  const response = await client.royalty.claimAllRevenue({
    ancestorIpId: "0xDa03c4B278AD44f5a669e9b73580F91AeDE0E3B2",
    claimer: "0xDa03c4B278AD44f5a669e9b73580F91AeDE0E3B2",
    currencyTokens: [WIP_TOKEN_ADDRESS],
    childIpIds: [],
    royaltyPolicies: [],
  });

  console.log(`Claimed revenue: ${response.claimedTokens}`);
}

main();
```

## 4. Parent Claiming Due Revenue

Continuing, the parent should be able to claim its revenue as well. In this example, the parent should be able to claim 1 $WIP since the child earned 2 $WIP and the `commercialRevShare = 50` in the license terms.

We will use the `claimAllRevenue` function to claim the due revenue tokens.

1. `ancestorIpId` is the `ipId` of the parent ("ancestor") asset
2. `claimer` is the address that holds the royalty tokens associated with the parent's [IP Royalty Vault](/concepts/royalty-module/ip-royalty-vault). By default, they are in the IP Account, which is just the `ipId` of the parent asset
3. `childIpIds` will have the `ipId` of the child asset
4. `royaltyPolicies` will contain the address of the royalty policy. As explained in [Royalty Module](/concepts/royalty-module), this is either `RoyaltyPolicyLAP` or `RoyaltyPolicyLRP`, depending on the license terms. In this case, let's assume the license terms specify a `RoyaltyPolicyLAP`. Simply go to [Deployed Smart Contracts](/developers/deployed-smart-contracts) and find the correct address.
5. `currencyTokens` is an array that contains the address of \$WIP, which can be found [here](/concepts/royalty-module/ip-royalty-vault#whitelisted-revenue-tokens)

```typescript main.ts
import { client } from "./utils";
import { zeroAddress, parseEther } from "viem";
import { WIP_TOKEN_ADDRESS } from "@story-protocol/core-sdk";

async function main() {
  // previous code here ...

  const response = await client.royalty.claimAllRevenue({
    ancestorIpId: "0x089d75C9b7E441dA3115AF93FF9A855BDdbfe384",
    claimer: "0x089d75C9b7E441dA3115AF93FF9A855BDdbfe384",
    currencyTokens: [WIP_TOKEN_ADDRESS],
    childIpIds: ["0xDa03c4B278AD44f5a669e9b73580F91AeDE0E3B2"],
    royaltyPolicies: ["0xBe54FB168b3c982b7AaE60dB6CF75Bd8447b390E"],
  });

  console.log(`Claimed revenue: ${response.claimedTokens}`);
}

main();
```

## 5. Done!

<CardGroup cols={1}>
  <Card title="Completed Code" href="https://github.com/storyprotocol/typescript-tutorial/blob/main/scripts/royalty/payRevenue.ts" icon="thumbs-up">
    See a completed, working example of setting up a simple derivative chain and
    then tipping the child IP Asset.
  </Card>
</CardGroup>

# Using a Smart Contract

<CardGroup cols={1}>
  <Card title="Go to Smart Contract Tutorial" href="/developers/smart-contracts-guide/claim-revenue" icon="house">
    View the tutorial here!
  </Card>
</CardGroup>


# Cross-Chain Royalty Payments

> A guide on how to set up cross-chain royalty payments for your IP using deBridge.

In this tutorial, we will explore how to use [deBridge](https://docs.debridge.finance/) to perform cross-chain royalty payments. From a high level, it involves:

1. Constructing a deBridge API call that will return tx data to swap tokens across chains and pay an IP Asset on Story
2. Executing the API call to receive a response
3. Verifying the API response to see that it contains tx data to swap and pay royalties
4. Executing the transaction (using the returned tx data) on the source chain

## Prerequisites

For easy setup, you can actually clone the [Story Protocol Boilerplate](https://github.com/storyprotocol/story-protocol-boilerplate) and view the test in the `test/6_DebridgeHook.t.sol` file. This already covers steps 1-3 below.

## Step 1: Constructing the deBridge API Call

The first step is to construct a deBridge API call. The purpose of this API call is to receive back a response that will contain transaction data so we can then execute it on the source chain.

Normally, this deBridge order would swap tokens from one chain to another. We can optionally attach a `dlnHook` that will execute an arbitrary action upon order completion (ex. after $ETH has been swapped for $WIP).

In this case, the `dlnHook` will be a call to `payRoyaltyOnBehalf` on Story's `RoyaltyModule` contract, which will pay royalties to an IP Asset.

To summarize, we will construct a deBridge API call that says "we want to swap $ETH for $WIP, and then pay royalties using that \$WIP to an IP Asset on Story".

### Step 1a. Constructing the `dlnHook`

The `dlnHook` is a JSON object that will be attached to the deBridge API call. It will contain the following information:

* The type of action to execute (`evm_transaction_call`)
* The address of the contract to call (`ROYALTY_MODULE`)
* The calldata to execute (`payRoyaltyOnBehalf`)

<Info>
  Check out the whole function by going [here](https://github.com/storyprotocol/story-protocol-boilerplate/blob/main/test/6_DebridgeHook.t.sol).
</Info>

```solidity Solidity
function _buildRoyaltyPaymentHook() internal pure returns (string memory dlnHookJson) {
    // an IP Asset on Story mainnet (it is actually Ippy - Story's mascot)
    address ipAssetId = 0xB1D831271A68Db5c18c8F0B69327446f7C8D0A42;

    bytes memory calldata_ = abi.encodeCall(
        IRoyaltyModule.payRoyaltyOnBehalf,
        (
            ipAssetId, // IP asset receiving royalties
            address(0), // External payer (0x0)
            0x1514000000000000000000000000000000000000, // Payment token (WIP)
            1e18 // 1 WIP
        )
    );

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
```

### Step 1b. Constructing the deBridge API Call

Now that we have the `dlnHook`, we can construct the whole deBridge API call, including the `dlnHook`.

<Info>
  Check out the whole function by going [here](https://github.com/storyprotocol/story-protocol-boilerplate/blob/main/test/6_DebridgeHook.t.sol).
</Info>

<Note>
  You can view deBridge's documentation on the `create-tx` endpoint [here](https://docs.debridge.finance/dln-the-debridge-liquidity-network-protocol/integration-guidelines/interacting-with-the-api/creating-an-order).
</Note>

| Attribute                       | Description                                                                                                                          |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `srcChainId`                    | The ID of the source blockchain (e.g., Ethereum mainnet is 1).                                                                       |
| `srcChainTokenIn`               | The address of the token being swapped on the source chain (ETH in this case).                                                       |
| `srcChainTokenInAmount`         | The amount of the source token to swap, set to `auto` for automatic calculation.                                                     |
| `dstChainId`                    | The ID of the destination blockchain (e.g., Story mainnet is 1315).                                                             |
| `dstChainTokenOut`              | The address of the token to receive on the destination chain (WIP token).                                                            |
| `dstChainTokenOutAmount`        | The amount of the destination token to receive. It should be the same as the amount we're paying in `payRoyaltyOnBehalf` in step 1a. |
| `dstChainTokenOutRecipient`     | This can just be the same as `senderAddress`.                                                                                        |
| `senderAddress`                 | The address initiating the transaction.                                                                                              |
| `srcChainOrderAuthorityAddress` | The address authorized to manage the order on the source chain. This can just be the same as `senderAddress`.                        |
| `dstChainOrderAuthorityAddress` | The address authorized to manage the order on the destination chain. This can just be the same as `senderAddress`.                   |
| `enableEstimate`                | A flag to enable transaction simulation and estimation.                                                                              |
| `prependOperatingExpenses`      | A flag to include operating expenses in the transaction.                                                                             |
| `dlnHook`                       | The URL-encoded hook that specifies additional actions to execute post-swap.                                                         |

```solidity Solidity
function _buildApiRequest(string memory dlnHookJson) internal pure returns (string memory apiUrl) {
    address senderAddress = 0xcf0a36dEC06E90263288100C11CF69828338E826; // Example sender

    apiUrl = string.concat(
        "https://dln.debridge.finance/v1.0/dln/order/create-tx",
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
```

## Step 2: Executing the API Call

Once the API call is constructed, execute it to receive a response. This response includes transaction data and an estimate for running the transaction on the source swap chain (e.g., Ethereum, Solana).

<Info>
  Check out the whole function by going [here](https://github.com/storyprotocol/story-protocol-boilerplate/blob/main/test/6_DebridgeHook.t.sol).
</Info>

```solidity Solidity
function _executeApiCall(string memory apiUrl) internal returns (string memory response) {
    console.log("deBridge API Request:");
    console.log(apiUrl);
    console.log("");

    string[] memory curlCommand = new string[](3);
    curlCommand[0] = "curl";
    curlCommand[1] = "-s";
    curlCommand[2] = apiUrl;

    bytes memory responseBytes = vm.ffi(curlCommand);
    response = string(responseBytes);

    console.log("deBridge API Response:");
    console.log(response);
    console.log("");
}
```

## Step 3: Verifying the API Response

Verify that the API call returns transaction data and an estimate. This step ensures that the transaction can be executed on the source chain.

```solidity Solidity
function _validateApiResponse(string memory response) internal pure {
    require(bytes(response).length > 0, "Empty API response");

    require(_contains(response, '"estimation"'), "Missing estimation field");
    require(_contains(response, '"tx"'), "Missing transaction field");
    require(_contains(response, '"orderId"'), "Missing order ID");
    require(_contains(response, '"dstChainTokenOut"'), "Missing destination token info");

    require(
        _contains(response, "d2577f3b"), // payRoyaltyOnBehalf selector
        "Hook not properly integrated in transaction"
    );

    require(
        _contains(_toLower(response), _toLower(_addressToHex(WIP_TOKEN))),
        "WIP token address not found in response"
    );
}
```

In this response is the following:

<Note>
  You can view the whole API return type
  [here](https://docs.debridge.finance/dln-the-debridge-liquidity-network-protocol/integration-guidelines/interacting-with-the-api/creating-an-order/api-response).
</Note>

```json
{
    ..., // other fields
    "tx": {
        "value": string,
        "data": string,
        "to": string
    }
}
```

## Step 4: Executing the Transaction on the Source Chain

Next, you would take the API response and execute the transaction on the source chain.

<Note>
  View [the docs here](https://docs.debridge.finance/dln-the-debridge-liquidity-network-protocol/integration-guidelines/interacting-with-the-api/submitting-an-order-creation-transaction) on submitting the transaction, including how this would be done differently on Solana.
</Note>

```typescript TypeScript
import { mainnet } from "viem/chains";
import { createWalletClient, http, WalletClient } from "viem";
import { privateKeyToAccount, Address, Account } from "viem/accounts";
import dotenv from "dotenv";

dotenv.config();

// Validate environment variables
if (!process.env.WALLET_PRIVATE_KEY) {
  throw new Error("WALLET_PRIVATE_KEY is required in .env file");
}

// Create account from private key
const account: Account = privateKeyToAccount(
  `0x${process.env.WALLET_PRIVATE_KEY}` as Address
);

// Initialize the wallet client
const walletClient = createWalletClient({
  chain: mainnet,
  transport: http("https://mainnet.infura.io/v3/YOUR_INFURA_PROJECT_ID"), // Use Infura or another Ethereum provider
  account,
}) as WalletClient;

// Function to send a transaction
async function sendTransaction(apiResponse: ApiResponse) {
  // Extract transaction details from the API response
  const transactionRequest = {
    to: apiResponse.tx.to, // Extracted from API response
    value: BigInt(apiResponse.tx.value), // Convert value to BigInt
    data: apiResponse.tx.data, // Extracted from API response
    account, // Include the account
    chain: mainnet, // Include the chain
  };

  try {
    const txHash = await walletClient.sendTransaction(transactionRequest);
    console.log("Transaction sent:", txHash);

    // Wait for the transaction to be mined
    const receipt = await walletClient.waitForTransactionReceipt(txHash);
    console.log("Transaction mined:", receipt.transactionHash);
  } catch (error) {
    console.error("Error sending transaction:", error);
  }
}

// Example usage with a mock API response
const mockApiResponse: ApiResponse = {
  // ... other fields
  tx: {
    to: "0xRecipientAddress", // Replace with the actual recipient's address
    value: "1000000000000000000", // 1 ETH in wei
    data: "0x", // No data for a simple ETH transfer
  },
  // ... other fields
};

// Execute the function to send the transaction
sendTransaction(mockApiResponse);
```

## Conclusion

Congratulations! You have successfully set up cross-chain royalty payments using deBridge. This tutorial demonstrated how to construct and execute a deBridge API call, verify the response, and perform the transaction on the source chain.


Complete Source Code For Foundry Based Example:

src/mocks/SimpleNFT.sol

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

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

src/Example.sol

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { IIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IIPAssetRegistry.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { IPILicenseTemplate } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";

import { SimpleNFT } from "./mocks/SimpleNFT.sol";

import { ERC721Holder } from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

/// @notice An example contract that demonstrates how to mint an NFT, register it as an IP Asset,
/// attach license terms to it, mint a license token from it, and register it as a derivative of the parent.
contract Example is ERC721Holder {
    IIPAssetRegistry public immutable IP_ASSET_REGISTRY;
    ILicensingModule public immutable LICENSING_MODULE;
    IPILicenseTemplate public immutable PIL_TEMPLATE;
    address public immutable ROYALTY_POLICY_LAP;
    address public immutable WIP;
    SimpleNFT public immutable SIMPLE_NFT;

    constructor(
        address ipAssetRegistry,
        address licensingModule,
        address pilTemplate,
        address royaltyPolicyLAP,
        address wip
    ) {
        IP_ASSET_REGISTRY = IIPAssetRegistry(ipAssetRegistry);
        LICENSING_MODULE = ILicensingModule(licensingModule);
        PIL_TEMPLATE = IPILicenseTemplate(pilTemplate);
        ROYALTY_POLICY_LAP = royaltyPolicyLAP;
        WIP = wip;
        // Create a new Simple NFT collection
        SIMPLE_NFT = new SimpleNFT("Simple IP NFT", "SIM");
    }

    /// @notice Mint an NFT, register it as an IP Asset, and attach License Terms to it.
    /// @param receiver The address that will receive the NFT/IPA.
    /// @return tokenId The token ID of the NFT representing ownership of the IPA.
    /// @return ipId The address of the IP Account.
    /// @return licenseTermsId The ID of the license terms.
    function mintAndRegisterAndCreateTermsAndAttach(
        address receiver
    ) external returns (uint256 tokenId, address ipId, uint256 licenseTermsId) {
        // We mint to this contract so that it has permissions
        // to attach license terms to the IP Asset.
        // We will later transfer it to the intended `receiver`
        tokenId = SIMPLE_NFT.mint(address(this));
        ipId = IP_ASSET_REGISTRY.register(block.chainid, address(SIMPLE_NFT), tokenId);

        // register license terms so we can attach them later
        licenseTermsId = PIL_TEMPLATE.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 20 * 10 ** 6, // 20%
                royaltyPolicy: ROYALTY_POLICY_LAP,
                currencyToken: WIP
            })
        );

        // attach the license terms to the IP Asset
        LICENSING_MODULE.attachLicenseTerms(ipId, address(PIL_TEMPLATE), licenseTermsId);

        // transfer the NFT to the receiver so it owns the IPA
        SIMPLE_NFT.transferFrom(address(this), receiver, tokenId);
    }

    /// @notice Mint and register a new child IPA, mint a License Token
    /// from the parent, and register it as a derivative of the parent.
    /// @param parentIpId The ipId of the parent IPA.
    /// @param licenseTermsId The ID of the license terms you will
    /// mint a license token from.
    /// @param receiver The address that will receive the NFT/IPA.
    /// @return childTokenId The token ID of the NFT representing ownership of the child IPA.
    /// @return childIpId The address of the child IPA.
    function mintLicenseTokenAndRegisterDerivative(
        address parentIpId,
        uint256 licenseTermsId,
        address receiver
    ) external returns (uint256 childTokenId, address childIpId) {
        // We mint to this contract so that it has permissions
        // to register itself as a derivative of another
        // IP Asset.
        // We will later transfer it to the intended `receiver`
        childTokenId = SIMPLE_NFT.mint(address(this));
        childIpId = IP_ASSET_REGISTRY.register(block.chainid, address(SIMPLE_NFT), childTokenId);

        // mint a license token from the parent
        uint256 licenseTokenId = LICENSING_MODULE.mintLicenseTokens({
            licensorIpId: parentIpId,
            licenseTemplate: address(PIL_TEMPLATE),
            licenseTermsId: licenseTermsId,
            amount: 1,
            // mint the license token to this contract so it can
            // use it to register as a derivative of the parent
            receiver: address(this),
            royaltyContext: "", // for PIL, royaltyContext is empty string
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        uint256[] memory licenseTokenIds = new uint256[](1);
        licenseTokenIds[0] = licenseTokenId;

        // register the new child IPA as a derivative
        // of the parent
        LICENSING_MODULE.registerDerivativeWithLicenseTokens({
            childIpId: childIpId,
            licenseTokenIds: licenseTokenIds,
            royaltyContext: "", // empty for PIL
            maxRts: 0
        });

        // transfer the NFT to the receiver so it owns the child IPA
        SIMPLE_NFT.transferFrom(address(this), receiver, childTokenId);
    }
}

test/utils/HexUtils.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

library HexUtils {
    /**
     * @dev Converts a `bytes` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(bytes memory data) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";

        bytes memory str = new bytes(2 + data.length * 2);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < data.length; i++) {
            str[2 + i * 2] = alphabet[uint256(uint8(data[i] >> 4))];
            str[3 + i * 2] = alphabet[uint256(uint8(data[i] & 0x0f))];
        }
        return string(str);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = bytes1(uint8(48 + uint256(value & 0xf)));
            value >>= 4;
        }
        require(value == 0, "HexUtils: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }
} 

test/utils/StringUtils.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

library StringUtils {
    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
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

    /**
     * @dev Converts a signed integer to string
     */
    function toString(int256 value) internal pure returns (string memory) {
        string memory _uintAsString = toString(abs(value));
        if (value >= 0) {
            return _uintAsString;
        }
        return string(abi.encodePacked("-", _uintAsString));
    }

    /**
     * @dev Returns the absolute value of a signed integer
     */
    function abs(int256 value) internal pure returns (uint256) {
        return value >= 0 ? uint256(value) : uint256(-value);
    }

    /**
     * @dev Concatenate two strings
     */
    function concat(string memory a, string memory b) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }

    /**
     * @dev Compare two strings for equality
     */
    function equal(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }
} 


test/0_IPARegistrar.t.sol

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { IIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IIPAssetRegistry.sol";
import { ISPGNFT } from "@storyprotocol/periphery/interfaces/ISPGNFT.sol";
import { IRegistrationWorkflows } from "@storyprotocol/periphery/interfaces/workflows/IRegistrationWorkflows.sol";
import { WorkflowStructs } from "@storyprotocol/periphery/lib/WorkflowStructs.sol";

import { SimpleNFT } from "../src/mocks/SimpleNFT.sol";

// Run this test:
// forge test --fork-url https://aeneid.storyrpc.io/ --match-path test/0_IPARegistrar.t.sol
contract IPARegistrarTest is Test {
    address internal alice = address(0xa11ce);

    // For addresses, see https://docs.story.foundation/docs/deployed-smart-contracts
    // Protocol Core - IPAssetRegistry
    IIPAssetRegistry internal IP_ASSET_REGISTRY = IIPAssetRegistry(0x77319B4031e6eF1250907aa00018B8B1c67a244b);
    // Protocol Periphery - RegistrationWorkflows
    IRegistrationWorkflows internal REGISTRATION_WORKFLOWS =
        IRegistrationWorkflows(0xbe39E1C756e921BD25DF86e7AAa31106d1eb0424);

    SimpleNFT public SIMPLE_NFT;
    ISPGNFT public SPG_NFT;

    function setUp() public {
        // Create a new Simple NFT collection
        SIMPLE_NFT = new SimpleNFT("Simple IP NFT", "SIM");
        // Create a new NFT collection via SPG
        SPG_NFT = ISPGNFT(
            REGISTRATION_WORKFLOWS.createCollection(
                ISPGNFT.InitParams({
                    name: "Test Collection",
                    symbol: "TEST",
                    baseURI: "",
                    contractURI: "",
                    maxSupply: 100,
                    mintFee: 0,
                    mintFeeToken: address(0),
                    mintFeeRecipient: address(this),
                    owner: address(this),
                    mintOpen: true,
                    isPublicMinting: false
                })
            )
        );
    }

    /// @notice Mint an NFT and then register it as an IP Asset.
    function test_register() public {
        uint256 expectedTokenId = SIMPLE_NFT.nextTokenId();
        address expectedIpId = IP_ASSET_REGISTRY.ipId(block.chainid, address(SIMPLE_NFT), expectedTokenId);

        uint256 tokenId = SIMPLE_NFT.mint(alice);
        address ipId = IP_ASSET_REGISTRY.register(block.chainid, address(SIMPLE_NFT), tokenId);

        assertEq(tokenId, expectedTokenId);
        assertEq(ipId, expectedIpId);
        assertEq(SIMPLE_NFT.ownerOf(tokenId), alice);
    }

    /// @notice Mint an NFT and register it in the same call via the Story Protocol Gateway.
    /// @dev Requires the collection address that is passed into the `mintAndRegisterIp` function
    /// to be created via SPG (createCollection), as done above. Or, a contract that
    /// implements the `ISPGNFT` interface.
    function test_mintAndRegisterIp() public {
        uint256 expectedTokenId = SPG_NFT.totalSupply() + 1;
        address expectedIpId = IP_ASSET_REGISTRY.ipId(block.chainid, address(SPG_NFT), expectedTokenId);

        // Note: The caller of this function must be the owner of the SPG NFT Collection.
        // In this case, the owner of the SPG NFT Collection is the contract itself
        // because it deployed it in the `setup` function.
        // We can make `alice` the recipient of the NFT though, which makes her the
        // owner of not only the NFT, but therefore the IP Asset.
        (address ipId, uint256 tokenId) = REGISTRATION_WORKFLOWS.mintAndRegisterIp(
            address(SPG_NFT),
            alice,
            WorkflowStructs.IPMetadata({
                ipMetadataURI: "https://ipfs.io/ipfs/QmZHfQdFA2cb3ASdmeGS5K6rZjz65osUddYMURDx21bT73",
                ipMetadataHash: keccak256(
                    abi.encodePacked(
                        "{'title':'My IP Asset','description':'This is a test IP asset','createdAt':'','creators':[]}"
                    )
                ),
                nftMetadataURI: "https://ipfs.io/ipfs/QmRL5PcK66J1mbtTZSw1nwVqrGxt98onStx6LgeHTDbEey",
                nftMetadataHash: keccak256(
                    abi.encodePacked(
                        "{'name':'Test NFT','description':'This is a test NFT','image':'https://picsum.photos/200'}"
                    )
                )
            }),
            true
        );

        assertEq(ipId, expectedIpId);
        assertEq(tokenId, expectedTokenId);
        assertEq(SPG_NFT.ownerOf(tokenId), alice);
    }
}

test/1_LicenseTerms.t.sol

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { IPILicenseTemplate } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";

// Run this test:
// forge test --fork-url https://aeneid.storyrpc.io/ --match-path test/1_LicenseTerms.t.sol
contract LicenseTermsTest is Test {
    address internal alice = address(0xa11ce);

    // For addresses, see https://docs.story.foundation/docs/deployed-smart-contracts
    // Protocol Core - PILicenseTemplate
    IPILicenseTemplate internal PIL_TEMPLATE = IPILicenseTemplate(0x2E896b0b2Fdb7457499B56AAaA4AE55BCB4Cd316);
    // Protocol Core - RoyaltyPolicyLAP
    address internal ROYALTY_POLICY_LAP = 0xBe54FB168b3c982b7AaE60dB6CF75Bd8447b390E;
    // Revenue Token - MERC20
    address internal MERC20 = 0xF2104833d386a2734a4eB3B8ad6FC6812F29E38E;

    function setUp() public {}

    /// @notice Registers new PIL Terms. Anyone can register PIL Terms.
    function test_registerPILTerms() public {
        PILTerms memory pilTerms = PILTerms({
            transferable: true,
            royaltyPolicy: ROYALTY_POLICY_LAP,
            defaultMintingFee: 0,
            expiration: 0,
            commercialUse: true,
            commercialAttribution: true,
            commercializerChecker: address(0),
            commercializerCheckerData: "",
            commercialRevShare: 0,
            commercialRevCeiling: 0,
            derivativesAllowed: true,
            derivativesAttribution: true,
            derivativesApproval: true,
            derivativesReciprocal: true,
            derivativeRevCeiling: 0,
            currency: MERC20,
            uri: ""
        });
        uint256 licenseTermsId = PIL_TEMPLATE.registerLicenseTerms(pilTerms);

        uint256 selectedLicenseTermsId = PIL_TEMPLATE.getLicenseTermsId(pilTerms);
        assertEq(licenseTermsId, selectedLicenseTermsId);
    }
}

test/2_AttachTerms.t.sol

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
// for testing purposes only
import { MockIPGraph } from "@storyprotocol/test/mocks/MockIPGraph.sol";
import { IIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IIPAssetRegistry.sol";
import { ILicenseRegistry } from "@storyprotocol/core/interfaces/registries/ILicenseRegistry.sol";
import { IPILicenseTemplate } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";
import { PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";

import { SimpleNFT } from "../src/mocks/SimpleNFT.sol";

// Run this test:
// forge test --fork-url https://aeneid.storyrpc.io/ --match-path test/2_AttachTerms.t.sol
contract AttachTermsTest is Test {
    address internal alice = address(0xa11ce);

    // For addresses, see https://docs.story.foundation/docs/deployed-smart-contracts
    // Protocol Core - IPAssetRegistry
    IIPAssetRegistry internal IP_ASSET_REGISTRY = IIPAssetRegistry(0x77319B4031e6eF1250907aa00018B8B1c67a244b);
    // Protocol Core - LicenseRegistry
    ILicenseRegistry internal LICENSE_REGISTRY = ILicenseRegistry(0x529a750E02d8E2f15649c13D69a465286a780e24);
    // Protocol Core - LicensingModule
    ILicensingModule internal LICENSING_MODULE = ILicensingModule(0x04fbd8a2e56dd85CFD5500A4A4DfA955B9f1dE6f);
    // Protocol Core - PILicenseTemplate
    IPILicenseTemplate internal PIL_TEMPLATE = IPILicenseTemplate(0x2E896b0b2Fdb7457499B56AAaA4AE55BCB4Cd316);
    // Protocol Core - RoyaltyPolicyLAP
    address internal ROYALTY_POLICY_LAP = 0xBe54FB168b3c982b7AaE60dB6CF75Bd8447b390E;
    // Revenue Token - MERC20
    address internal MERC20 = 0xF2104833d386a2734a4eB3B8ad6FC6812F29E38E;

    SimpleNFT public SIMPLE_NFT;
    uint256 public tokenId;
    address public ipId;
    uint256 public licenseTermsId;

    function setUp() public {
        // this is only for testing purposes
        // due to our IPGraph precompile not being
        // deployed on the fork
        vm.etch(address(0x0101), address(new MockIPGraph()).code);

        SIMPLE_NFT = new SimpleNFT("Simple IP NFT", "SIM");
        tokenId = SIMPLE_NFT.mint(alice);
        ipId = IP_ASSET_REGISTRY.register(block.chainid, address(SIMPLE_NFT), tokenId);

        // Register random Commercial Remix terms so we can attach them later
        licenseTermsId = PIL_TEMPLATE.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 20 * 10 ** 6, // 20%
                royaltyPolicy: ROYALTY_POLICY_LAP,
                currencyToken: MERC20
            })
        );
    }

    /// @notice Attaches license terms to an IP Asset.
    /// @dev Only the owner of an IP Asset can attach license terms to it.
    /// So in this case, alice has to be the caller of the function because
    /// she owns the NFT associated with the IP Asset.
    function test_attachLicenseTerms() public {
        vm.prank(alice);
        LICENSING_MODULE.attachLicenseTerms(ipId, address(PIL_TEMPLATE), licenseTermsId);

        assertTrue(LICENSE_REGISTRY.hasIpAttachedLicenseTerms(ipId, address(PIL_TEMPLATE), licenseTermsId));
        assertEq(LICENSE_REGISTRY.getAttachedLicenseTermsCount(ipId), 1);
        (address licenseTemplate, uint256 attachedLicenseTermsId) = LICENSE_REGISTRY.getAttachedLicenseTerms({
            ipId: ipId,
            index: 0
        });
        assertEq(licenseTemplate, address(PIL_TEMPLATE));
        assertEq(attachedLicenseTermsId, licenseTermsId);
    }
}

test/3_LicenseToken.t.sol

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
// for testing purposes only
import { MockIPGraph } from "@storyprotocol/test/mocks/MockIPGraph.sol";
import { IIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IIPAssetRegistry.sol";
import { IPILicenseTemplate } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { ILicenseToken } from "@storyprotocol/core/interfaces/ILicenseToken.sol";
import { RoyaltyPolicyLAP } from "@storyprotocol/core/modules/royalty/policies/LAP/RoyaltyPolicyLAP.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";
import { PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";

import { SimpleNFT } from "../src/mocks/SimpleNFT.sol";

// Run this test:
// forge test --fork-url https://aeneid.storyrpc.io/ --match-path test/3_LicenseToken.t.sol
contract LicenseTokenTest is Test {
    address internal alice = address(0xa11ce);
    address internal bob = address(0xb0b);

    // For addresses, see https://docs.story.foundation/docs/deployed-smart-contracts
    // Protocol Core - IPAssetRegistry
    IIPAssetRegistry internal IP_ASSET_REGISTRY = IIPAssetRegistry(0x77319B4031e6eF1250907aa00018B8B1c67a244b);
    // Protocol Core - LicensingModule
    ILicensingModule internal LICENSING_MODULE = ILicensingModule(0x04fbd8a2e56dd85CFD5500A4A4DfA955B9f1dE6f);
    // Protocol Core - PILicenseTemplate
    IPILicenseTemplate internal PIL_TEMPLATE = IPILicenseTemplate(0x2E896b0b2Fdb7457499B56AAaA4AE55BCB4Cd316);
    // Protocol Core - RoyaltyPolicyLAP
    address internal ROYALTY_POLICY_LAP = 0xBe54FB168b3c982b7AaE60dB6CF75Bd8447b390E;
    // Protocol Core - LicenseToken
    ILicenseToken internal LICENSE_TOKEN = ILicenseToken(0xFe3838BFb30B34170F00030B52eA4893d8aAC6bC);
    // Revenue Token - MERC20
    address internal MERC20 = 0xF2104833d386a2734a4eB3B8ad6FC6812F29E38E;

    SimpleNFT public SIMPLE_NFT;
    uint256 public tokenId;
    address public ipId;
    uint256 public licenseTermsId;

    function setUp() public {
        // this is only for testing purposes
        // due to our IPGraph precompile not being
        // deployed on the fork
        vm.etch(address(0x0101), address(new MockIPGraph()).code);

        SIMPLE_NFT = new SimpleNFT("Simple IP NFT", "SIM");
        tokenId = SIMPLE_NFT.mint(alice);
        ipId = IP_ASSET_REGISTRY.register(block.chainid, address(SIMPLE_NFT), tokenId);

        licenseTermsId = PIL_TEMPLATE.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 20 * 10 ** 6, // 20%
                royaltyPolicy: ROYALTY_POLICY_LAP,
                currencyToken: MERC20
            })
        );

        vm.prank(alice);
        LICENSING_MODULE.attachLicenseTerms(ipId, address(PIL_TEMPLATE), licenseTermsId);
    }

    /// @notice Mints license tokens for an IP Asset.
    /// Anyone can mint a license token.
    function test_mintLicenseToken() public {
        uint256 startLicenseTokenId = LICENSING_MODULE.mintLicenseTokens({
            licensorIpId: ipId,
            licenseTemplate: address(PIL_TEMPLATE),
            licenseTermsId: licenseTermsId,
            amount: 2,
            receiver: bob,
            royaltyContext: "", // for PIL, royaltyContext is empty string
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        assertEq(LICENSE_TOKEN.ownerOf(startLicenseTokenId), bob);
        assertEq(LICENSE_TOKEN.ownerOf(startLicenseTokenId + 1), bob);
    }
}

test/4_IPARemix.t.sol

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
// for testing purposes only
import { MockIPGraph } from "@storyprotocol/test/mocks/MockIPGraph.sol";
import { IIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IIPAssetRegistry.sol";
import { ILicenseRegistry } from "@storyprotocol/core/interfaces/registries/ILicenseRegistry.sol";
import { IPILicenseTemplate } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";
import { PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";

import { SimpleNFT } from "../src/mocks/SimpleNFT.sol";

// Run this test:
// forge test --fork-url https://aeneid.storyrpc.io/ --match-path test/4_IPARemix.t.sol
contract IPARemixTest is Test {
    address internal alice = address(0xa11ce);
    address internal bob = address(0xb0b);

    // For addresses, see https://docs.story.foundation/docs/deployed-smart-contracts
    // Protocol Core - IPAssetRegistry
    IIPAssetRegistry internal IP_ASSET_REGISTRY = IIPAssetRegistry(0x77319B4031e6eF1250907aa00018B8B1c67a244b);
    // Protocol Core - LicenseRegistry
    ILicenseRegistry internal LICENSE_REGISTRY = ILicenseRegistry(0x529a750E02d8E2f15649c13D69a465286a780e24);
    // Protocol Core - LicensingModule
    ILicensingModule internal LICENSING_MODULE = ILicensingModule(0x04fbd8a2e56dd85CFD5500A4A4DfA955B9f1dE6f);
    // Protocol Core - PILicenseTemplate
    IPILicenseTemplate internal PIL_TEMPLATE = IPILicenseTemplate(0x2E896b0b2Fdb7457499B56AAaA4AE55BCB4Cd316);
    // Protocol Core - RoyaltyPolicyLAP
    address internal ROYALTY_POLICY_LAP = 0xBe54FB168b3c982b7AaE60dB6CF75Bd8447b390E;
    // Revenue Token - MERC20
    address internal MERC20 = 0xF2104833d386a2734a4eB3B8ad6FC6812F29E38E;

    SimpleNFT public SIMPLE_NFT;
    uint256 public tokenId;
    address public ipId;
    uint256 public licenseTermsId;
    uint256 public startLicenseTokenId;

    function setUp() public {
        // this is only for testing purposes
        // due to our IPGraph precompile not being
        // deployed on the fork
        vm.etch(address(0x0101), address(new MockIPGraph()).code);

        SIMPLE_NFT = new SimpleNFT("Simple IP NFT", "SIM");
        tokenId = SIMPLE_NFT.mint(alice);
        ipId = IP_ASSET_REGISTRY.register(block.chainid, address(SIMPLE_NFT), tokenId);

        licenseTermsId = PIL_TEMPLATE.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 20 * 10 ** 6, // 20%
                royaltyPolicy: ROYALTY_POLICY_LAP,
                currencyToken: MERC20
            })
        );

        vm.prank(alice);
        LICENSING_MODULE.attachLicenseTerms(ipId, address(PIL_TEMPLATE), licenseTermsId);
        startLicenseTokenId = LICENSING_MODULE.mintLicenseTokens({
            licensorIpId: ipId,
            licenseTemplate: address(PIL_TEMPLATE),
            licenseTermsId: licenseTermsId,
            amount: 2,
            receiver: bob,
            royaltyContext: "", // for PIL, royaltyContext is empty string
            maxMintingFee: 0,
            maxRevenueShare: 0
        });
    }

    /// @notice Mints an NFT to be registered as IP, and then
    /// linked as a derivative of alice's asset using the
    /// minted license token.
    function test_registerDerivativeWithLicenseTokens() public {
        // First we mint an NFT and register it as an IP Asset,
        // owned by Bob.
        uint256 childTokenId = SIMPLE_NFT.mint(bob);
        address childIpId = IP_ASSET_REGISTRY.register(block.chainid, address(SIMPLE_NFT), childTokenId);

        uint256[] memory licenseTokenIds = new uint256[](1);
        licenseTokenIds[0] = startLicenseTokenId;

        // Bob uses the License Token he has from Alice's IP
        // to register his IP as a derivative of Alice's IP.
        vm.prank(bob);
        LICENSING_MODULE.registerDerivativeWithLicenseTokens({
            childIpId: childIpId,
            licenseTokenIds: licenseTokenIds,
            royaltyContext: "", // empty for PIL
            maxRts: 0
        });

        assertTrue(LICENSE_REGISTRY.hasDerivativeIps(ipId));
        assertTrue(LICENSE_REGISTRY.isParentIp(ipId, childIpId));
        assertTrue(LICENSE_REGISTRY.isDerivativeIp(childIpId));
        assertEq(LICENSE_REGISTRY.getParentIpCount(childIpId), 1);
        assertEq(LICENSE_REGISTRY.getDerivativeIpCount(ipId), 1);
        assertEq(LICENSE_REGISTRY.getParentIp({ childIpId: childIpId, index: 0 }), ipId);
        assertEq(LICENSE_REGISTRY.getDerivativeIp({ parentIpId: ipId, index: 0 }), childIpId);
    }
}

test/5_Royalty.t.sol

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
// for testing purposes only
import { MockIPGraph } from "@storyprotocol/test/mocks/MockIPGraph.sol";
import { IIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IIPAssetRegistry.sol";
import { IPILicenseTemplate } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { IRoyaltyWorkflows } from "@storyprotocol/periphery/interfaces/workflows/IRoyaltyWorkflows.sol";
import { IRoyaltyModule } from "@storyprotocol/core/interfaces/modules/royalty/IRoyaltyModule.sol";
import { RoyaltyPolicyLAP } from "@storyprotocol/core/modules/royalty/policies/LAP/RoyaltyPolicyLAP.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";
import { PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { MockERC20 } from "@storyprotocol/test/mocks/token/MockERC20.sol";

import { SimpleNFT } from "../src/mocks/SimpleNFT.sol";

// Run this test:
// forge test --fork-url https://aeneid.storyrpc.io/ --match-path test/5_Royalty.t.sol
contract RoyaltyTest is Test {
    address internal alice = address(0xa11ce);
    address internal bob = address(0xb0b);

    // For addresses, see https://docs.story.foundation/docs/deployed-smart-contracts
    // Protocol Core - IPAssetRegistry
    IIPAssetRegistry internal IP_ASSET_REGISTRY = IIPAssetRegistry(0x77319B4031e6eF1250907aa00018B8B1c67a244b);
    // Protocol Core - LicensingModule
    ILicensingModule internal LICENSING_MODULE = ILicensingModule(0x04fbd8a2e56dd85CFD5500A4A4DfA955B9f1dE6f);
    // Protocol Core - PILicenseTemplate
    IPILicenseTemplate internal PIL_TEMPLATE = IPILicenseTemplate(0x2E896b0b2Fdb7457499B56AAaA4AE55BCB4Cd316);
    // Protocol Core - RoyaltyPolicyLAP
    address internal ROYALTY_POLICY_LAP = 0xBe54FB168b3c982b7AaE60dB6CF75Bd8447b390E;
    // Protocol Core - RoyaltyModule
    IRoyaltyModule internal ROYALTY_MODULE = IRoyaltyModule(0xD2f60c40fEbccf6311f8B47c4f2Ec6b040400086);
    // Protocol Periphery - RoyaltyWorkflows
    IRoyaltyWorkflows internal ROYALTY_WORKFLOWS = IRoyaltyWorkflows(0x9515faE61E0c0447C6AC6dEe5628A2097aFE1890);
    // Revenue Token - MERC20
    MockERC20 internal MERC20 = MockERC20(0xF2104833d386a2734a4eB3B8ad6FC6812F29E38E);

    SimpleNFT public SIMPLE_NFT;
    uint256 public tokenId;
    address public ipId;
    uint256 public licenseTermsId;
    uint256 public startLicenseTokenId;
    address public childIpId;

    function setUp() public {
        // this is only for testing purposes
        // due to our IPGraph precompile not being
        // deployed on the fork
        vm.etch(address(0x0101), address(new MockIPGraph()).code);

        SIMPLE_NFT = new SimpleNFT("Simple IP NFT", "SIM");
        tokenId = SIMPLE_NFT.mint(alice);
        ipId = IP_ASSET_REGISTRY.register(block.chainid, address(SIMPLE_NFT), tokenId);

        licenseTermsId = PIL_TEMPLATE.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 20 * 10 ** 6, // 20%
                royaltyPolicy: ROYALTY_POLICY_LAP,
                currencyToken: address(MERC20)
            })
        );

        vm.prank(alice);
        LICENSING_MODULE.attachLicenseTerms(ipId, address(PIL_TEMPLATE), licenseTermsId);
        startLicenseTokenId = LICENSING_MODULE.mintLicenseTokens({
            licensorIpId: ipId,
            licenseTemplate: address(PIL_TEMPLATE),
            licenseTermsId: licenseTermsId,
            amount: 2,
            receiver: bob,
            royaltyContext: "", // for PIL, royaltyContext is empty string
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        // Registers a child IP (owned by Bob) as a derivative of Alice's IP.
        uint256 childTokenId = SIMPLE_NFT.mint(bob);
        childIpId = IP_ASSET_REGISTRY.register(block.chainid, address(SIMPLE_NFT), childTokenId);

        uint256[] memory licenseTokenIds = new uint256[](1);
        licenseTokenIds[0] = startLicenseTokenId;

        vm.prank(bob);
        LICENSING_MODULE.registerDerivativeWithLicenseTokens({
            childIpId: childIpId,
            licenseTokenIds: licenseTokenIds,
            royaltyContext: "", // empty for PIL
            maxRts: 0
        });
    }

    /// @notice Pays MERC20 to Bob's IP. Some of this MERC20 is then claimable
    /// by Alice's IP.
    /// @dev In this case, this contract will act as the 3rd party paying MERC20
    /// to Bob (the child IP).
    function test_claimAllRevenue() public {
        // ADMIN SETUP
        // We mint 100 MERC20 to this contract so it has some money to pay.
        MERC20.mint(address(this), 100);
        // We approve the Royalty Module to spend MERC20 on our behalf, which
        // it will do using `payRoyaltyOnBehalf`.
        MERC20.approve(address(ROYALTY_MODULE), 10);

        // This contract pays 10 MERC20 to Bob's IP.
        ROYALTY_MODULE.payRoyaltyOnBehalf(childIpId, address(0), address(MERC20), 10);

        // Now that Bob's IP has been paid, Alice can claim her share (2 MERC20, which
        // is 20% as specified in the license terms)
        address[] memory childIpIds = new address[](1);
        address[] memory royaltyPolicies = new address[](1);
        address[] memory currencyTokens = new address[](1);
        childIpIds[0] = childIpId;
        royaltyPolicies[0] = ROYALTY_POLICY_LAP;
        currencyTokens[0] = address(MERC20);

        uint256[] memory amountsClaimed = ROYALTY_WORKFLOWS.claimAllRevenue({
            ancestorIpId: ipId,
            claimer: ipId,
            childIpIds: childIpIds,
            royaltyPolicies: royaltyPolicies,
            currencyTokens: currencyTokens
        });

        // Check that 2 MERC20 was claimed by Alice's IP Account
        assertEq(amountsClaimed[0], 2);
        // Check that Alice's IP Account now has 2 MERC20 in its balance.
        assertEq(MERC20.balanceOf(ipId), 2);
        // Check that Bob's IP now has 8 MERC20 in its Royalty Vault, which it
        // can claim to its IP Account at a later point if he wants.
        assertEq(MERC20.balanceOf(ROYALTY_MODULE.ipRoyaltyVaults(childIpId)), 8);
    }

    /// @notice Shows an example of paying a minting fee
    function test_payMintingFee() public {
        // ADMIN SETUP
        // We mint 1 MERC20 to this contract so it has some money to pay.
        MERC20.mint(address(this), 1);
        // We approve the Royalty Module to spend MERC20 on our behalf, which
        // it will do using `payRoyaltyOnBehalf`.
        MERC20.approve(address(ROYALTY_MODULE), 1);

        // Create commercial use terms with a mint fee to test
        uint256 commercialUseLicenseTermsId = PIL_TEMPLATE.registerLicenseTerms(
            PILFlavors.commercialUse({
                mintingFee: 1, // 1 MERC20
                royaltyPolicy: ROYALTY_POLICY_LAP,
                currencyToken: address(MERC20)
            })
        );

        // attach the terms to the ip asset
        vm.prank(alice);
        LICENSING_MODULE.attachLicenseTerms(ipId, address(PIL_TEMPLATE), commercialUseLicenseTermsId);

        // pay the mint fee
        startLicenseTokenId = LICENSING_MODULE.mintLicenseTokens({
            licensorIpId: ipId,
            licenseTemplate: address(PIL_TEMPLATE),
            licenseTermsId: commercialUseLicenseTermsId,
            amount: 1,
            receiver: bob,
            royaltyContext: "", // for PIL, royaltyContext is empty string
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        // Now that Bob's IP has been paid, Alice can claim her share (2 MERC20, which
        // is 20% as specified in the license terms)
        address[] memory childIpIds = new address[](0);
        address[] memory royaltyPolicies = new address[](0);
        address[] memory currencyTokens = new address[](1);
        currencyTokens[0] = address(MERC20);

        uint256[] memory amountsClaimed = ROYALTY_WORKFLOWS.claimAllRevenue({
            ancestorIpId: ipId,
            claimer: ipId,
            childIpIds: childIpIds,
            royaltyPolicies: royaltyPolicies,
            currencyTokens: currencyTokens
        });

        // Check that 1 MERC20 was claimed by Alice's IP Account
        assertEq(amountsClaimed[0], 1);
        // Check that Alice's IP Account now has 1 MERC20 in its balance.
        assertEq(MERC20.balanceOf(ipId), 1);
    }
}

test/6_DebridgeHook.t.sol

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

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
// for testing purposes only
import { MockIPGraph } from "@storyprotocol/test/mocks/MockIPGraph.sol";
import { IIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IIPAssetRegistry.sol";
import { ILicenseRegistry } from "@storyprotocol/core/interfaces/registries/ILicenseRegistry.sol";

import { Example } from "../src/Example.sol";
import { SimpleNFT } from "../src/mocks/SimpleNFT.sol";

// Run this test:
// forge test --fork-url https://aeneid.storyrpc.io/ --match-path test/Example.t.sol
contract ExampleTest is Test {
    address internal alice = address(0xa11ce);
    address internal bob = address(0xb0b);

    // For addresses, see https://docs.story.foundation/docs/deployed-smart-contracts
    // Protocol Core - IPAssetRegistry
    address internal ipAssetRegistry = 0x77319B4031e6eF1250907aa00018B8B1c67a244b;
    // Protocol Core - LicenseRegistry
    address internal licenseRegistry = 0x529a750E02d8E2f15649c13D69a465286a780e24;
    // Protocol Core - LicensingModule
    address internal licensingModule = 0x04fbd8a2e56dd85CFD5500A4A4DfA955B9f1dE6f;
    // Protocol Core - PILicenseTemplate
    address internal pilTemplate = 0x2E896b0b2Fdb7457499B56AAaA4AE55BCB4Cd316;
    // Protocol Core - RoyaltyPolicyLAP
    address internal royaltyPolicyLAP = 0xBe54FB168b3c982b7AaE60dB6CF75Bd8447b390E;
    // Revenue Token - WIP
    address internal wip = 0x1514000000000000000000000000000000000000;

    SimpleNFT public SIMPLE_NFT;
    Example public EXAMPLE;

    function setUp() public {
        // this is only for testing purposes
        // due to our IPGraph precompile not being
        // deployed on the fork
        vm.etch(address(0x0101), address(new MockIPGraph()).code);

        EXAMPLE = new Example(ipAssetRegistry, licensingModule, pilTemplate, royaltyPolicyLAP, wip);
        SIMPLE_NFT = SimpleNFT(EXAMPLE.SIMPLE_NFT());
    }

    function test_mintAndRegisterAndCreateTermsAndAttach() public {
        ILicenseRegistry LICENSE_REGISTRY = ILicenseRegistry(licenseRegistry);
        IIPAssetRegistry IP_ASSET_REGISTRY = IIPAssetRegistry(ipAssetRegistry);

        uint256 expectedTokenId = SIMPLE_NFT.nextTokenId();
        address expectedIpId = IP_ASSET_REGISTRY.ipId(block.chainid, address(SIMPLE_NFT), expectedTokenId);

        (uint256 tokenId, address ipId, uint256 licenseTermsId) = EXAMPLE.mintAndRegisterAndCreateTermsAndAttach(alice);

        assertEq(tokenId, expectedTokenId);
        assertEq(ipId, expectedIpId);
        assertEq(SIMPLE_NFT.ownerOf(tokenId), alice);

        assertTrue(LICENSE_REGISTRY.hasIpAttachedLicenseTerms(ipId, pilTemplate, licenseTermsId));
        assertEq(LICENSE_REGISTRY.getAttachedLicenseTermsCount(ipId), 1);
        (address licenseTemplate, uint256 attachedLicenseTermsId) = LICENSE_REGISTRY.getAttachedLicenseTerms({
            ipId: ipId,
            index: 0
        });
        assertEq(licenseTemplate, pilTemplate);
        assertEq(attachedLicenseTermsId, licenseTermsId);
    }

    function test_mintLicenseTokenAndRegisterDerivative() public {
        ILicenseRegistry LICENSE_REGISTRY = ILicenseRegistry(licenseRegistry);
        IIPAssetRegistry IP_ASSET_REGISTRY = IIPAssetRegistry(ipAssetRegistry);

        (uint256 parentTokenId, address parentIpId, uint256 licenseTermsId) = EXAMPLE
            .mintAndRegisterAndCreateTermsAndAttach(alice);

        (uint256 childTokenId, address childIpId) = EXAMPLE.mintLicenseTokenAndRegisterDerivative(
            parentIpId,
            licenseTermsId,
            bob
        );

        assertTrue(LICENSE_REGISTRY.hasDerivativeIps(parentIpId));
        assertTrue(LICENSE_REGISTRY.isParentIp(parentIpId, childIpId));
        assertTrue(LICENSE_REGISTRY.isDerivativeIp(childIpId));
        assertEq(LICENSE_REGISTRY.getDerivativeIpCount(parentIpId), 1);
        assertEq(LICENSE_REGISTRY.getParentIpCount(childIpId), 1);
        assertEq(LICENSE_REGISTRY.getParentIp({ childIpId: childIpId, index: 0 }), parentIpId);
        assertEq(LICENSE_REGISTRY.getDerivativeIp({ parentIpId: parentIpId, index: 0 }), childIpId);
    }
}

# Deployed Smart Contracts

> A list of all deployed protocol addresses

## Core Protocol Contracts

* View contracts on our GitHub [here](https://github.com/storyprotocol/protocol-core-v1/tree/main)

<CodeGroup>
  ```json Aeneid Testnet
  {
    "AccessController": "0xcCF37d0a503Ee1D4C11208672e622ed3DFB2275a",
    "ArbitrationPolicyUMA": "0xfFD98c3877B8789124f02C7E8239A4b0Ef11E936",
    "CoreMetadataModule": "0x6E81a25C99C6e8430aeC7353325EB138aFE5DC16",
    "CoreMetadataViewModule": "0xB3F88038A983CeA5753E11D144228Ebb5eACdE20",
    "DisputeModule": "0x9b7A9c70AFF961C799110954fc06F3093aeb94C5",
    "EvenSplitGroupPool": "0xf96f2c30b41Cb6e0290de43C8528ae83d4f33F89",
    "GroupNFT": "0x4709798FeA84C84ae2475fF0c25344115eE1529f",
    "GroupingModule": "0x69D3a7aa9edb72Bc226E745A7cCdd50D947b69Ac",
    "IPAccountImplBeacon": "0x9825cc7A398D9C3dDD66232A8Ec76d5b05422581",
    "IPAccountImplBeaconProxy": "0x00b800138e4D82D1eea48b414d2a2A8Aee9A33b1",
    "IPAccountImplCode": "0xdeC03e0c63f800efD7C9d04A16e01E80cF57Bf79",
    "IPAssetRegistry": "0x77319B4031e6eF1250907aa00018B8B1c67a244b",
    "IPGraphACL": "0x1640A22a8A086747cD377b73954545e2Dfcc9Cad",
    "IpRoyaltyVaultBeacon": "0x6928ba25Aa5c410dd855dFE7e95713d83e402AA6",
    "IpRoyaltyVaultImpl": "0xbd0f3c59B6f0035f55C58893fA0b1Ac4aDEa50Dc",
    "LicenseRegistry": "0x529a750E02d8E2f15649c13D69a465286a780e24",
    "LicenseToken": "0xFe3838BFb30B34170F00030B52eA4893d8aAC6bC",
    "LicensingModule": "0x04fbd8a2e56dd85CFD5500A4A4DfA955B9f1dE6f",
    "ModuleRegistry": "0x022DBAAeA5D8fB31a0Ad793335e39Ced5D631fa5",
    "PILicenseTemplate": "0x2E896b0b2Fdb7457499B56AAaA4AE55BCB4Cd316",
    "ProtocolAccessManager": "0xFdece7b8a2f55ceC33b53fd28936B4B1e3153d53",
    "ProtocolPauseAdmin": "0xdd661f55128A80437A0c0BDA6E13F214A3B2EB24",
    "RoyaltyModule": "0xD2f60c40fEbccf6311f8B47c4f2Ec6b040400086",
    "RoyaltyPolicyLAP": "0xBe54FB168b3c982b7AaE60dB6CF75Bd8447b390E",
    "RoyaltyPolicyLRP": "0x9156e603C949481883B1d3355c6f1132D191fC41"
  }
  ```

  ```json Mainnet
  {
    "AccessController": "0xcCF37d0a503Ee1D4C11208672e622ed3DFB2275a",
    "ArbitrationPolicyUMA": "0xfFD98c3877B8789124f02C7E8239A4b0Ef11E936",
    "CoreMetadataModule": "0x6E81a25C99C6e8430aeC7353325EB138aFE5DC16",
    "CoreMetadataViewModule": "0xB3F88038A983CeA5753E11D144228Ebb5eACdE20",
    "DisputeModule": "0x9b7A9c70AFF961C799110954fc06F3093aeb94C5",
    "EvenSplitGroupPool": "0xf96f2c30b41Cb6e0290de43C8528ae83d4f33F89",
    "GroupNFT": "0x4709798FeA84C84ae2475fF0c25344115eE1529f",
    "GroupingModule": "0x69D3a7aa9edb72Bc226E745A7cCdd50D947b69Ac",
    "IPAccountImplBeacon": "0x9825cc7A398D9C3dDD66232A8Ec76d5b05422581",
    "IPAccountImplBeaconProxy": "0x00b800138e4D82D1eea48b414d2a2A8Aee9A33b1",
    "IPAccountImplCode": "0x7343646585443F1c3F64E4F08b708788527e1C77",
    "IPAssetRegistry": "0x77319B4031e6eF1250907aa00018B8B1c67a244b",
    "IPGraphACL": "0x1640A22a8A086747cD377b73954545e2Dfcc9Cad",
    "IpRoyaltyVaultBeacon": "0x6928ba25Aa5c410dd855dFE7e95713d83e402AA6",
    "IpRoyaltyVaultImpl": "0x63cC7611316880213f3A4Ba9bD72b0EaA2010298",
    "LicenseRegistry": "0x529a750E02d8E2f15649c13D69a465286a780e24",
    "LicenseToken": "0xFe3838BFb30B34170F00030B52eA4893d8aAC6bC",
    "LicensingModule": "0x04fbd8a2e56dd85CFD5500A4A4DfA955B9f1dE6f",
    "ModuleRegistry": "0x022DBAAeA5D8fB31a0Ad793335e39Ced5D631fa5",
    "PILicenseTemplate": "0x2E896b0b2Fdb7457499B56AAaA4AE55BCB4Cd316",
    "ProtocolAccessManager": "0xFdece7b8a2f55ceC33b53fd28936B4B1e3153d53",
    "ProtocolPauseAdmin": "0xdd661f55128A80437A0c0BDA6E13F214A3B2EB24",
    "RoyaltyModule": "0xD2f60c40fEbccf6311f8B47c4f2Ec6b040400086",
    "RoyaltyPolicyLAP": "0xBe54FB168b3c982b7AaE60dB6CF75Bd8447b390E",
    "RoyaltyPolicyLRP": "0x9156e603C949481883B1d3355c6f1132D191fC41"
  }
  ```
</CodeGroup>

## Periphery Contracts

* View contracts on our GitHub [here](https://github.com/storyprotocol/protocol-periphery-v1)

<CodeGroup>
  ```json Aeneid Testnet
  {
    "DerivativeWorkflows": "0x9e2d496f72C547C2C535B167e06ED8729B374a4f",
    "GroupingWorkflows": "0xD7c0beb3aa4DCD4723465f1ecAd045676c24CDCd",
    "LicenseAttachmentWorkflows": "0xcC2E862bCee5B6036Db0de6E06Ae87e524a79fd8",
    "OwnableERC20Beacon": "0xB83639aF55F03108091020b7c75a46e2eaAb4FfA",
    "OwnableERC20Template": "0xf8D299af9CBEd49f50D7844DDD1371157251d0A7",
    "RegistrationWorkflows": "0xbe39E1C756e921BD25DF86e7AAa31106d1eb0424",
    "RoyaltyTokenDistributionWorkflows": "0xa38f42B8d33809917f23997B8423054aAB97322C",
    "RoyaltyWorkflows": "0x9515faE61E0c0447C6AC6dEe5628A2097aFE1890",
    "SPGNFTBeacon": "0xD2926B9ecaE85fF59B6FB0ff02f568a680c01218",
    "SPGNFTImpl": "0x5266215a00c31AaA2f2BB7b951Ea0028Ea8b4e37",
    "TokenizerModule": "0xAC937CeEf893986A026f701580144D9289adAC4C"
  }
  ```

  ```json Mainnet
  {
    "DerivativeWorkflows": "0x9e2d496f72C547C2C535B167e06ED8729B374a4f",
    "GroupingWorkflows": "0xD7c0beb3aa4DCD4723465f1ecAd045676c24CDCd",
    "LicenseAttachmentWorkflows": "0xcC2E862bCee5B6036Db0de6E06Ae87e524a79fd8",
    "OwnableERC20Beacon": "0x9a81C447C0b4C47d41d94177AEea3511965d3Bc9",
    "OwnableERC20Template": "0xE6505ffc5A7C19B68cEc2311Cc35BC02d8f7e0B1",
    "RegistrationWorkflows": "0xbe39E1C756e921BD25DF86e7AAa31106d1eb0424",
    "RoyaltyTokenDistributionWorkflows": "0xa38f42B8d33809917f23997B8423054aAB97322C",
    "RoyaltyWorkflows": "0x9515faE61E0c0447C6AC6dEe5628A2097aFE1890",
    "SPGNFTBeacon": "0xD2926B9ecaE85fF59B6FB0ff02f568a680c01218",
    "SPGNFTImpl": "0x6Cfa03Bc64B1a76206d0Ea10baDed31D520449F5",
    "TokenizerModule": "0xAC937CeEf893986A026f701580144D9289adAC4C"
  }
  ```
</CodeGroup>

## License Hooks

* View contracts on our GitHub [here](https://github.com/storyprotocol/protocol-periphery-v1/tree/main/contracts/hooks)

<CodeGroup>
  ```json Aeneid Testnet
  {
    "LockLicenseHook": "0x54C52990dA304643E7412a3e13d8E8923cD5bfF2",
    "TotalLicenseTokenLimitHook": "0xaBAD364Bfa41230272b08f171E0Ca939bD600478"
  }
  ```

  ```json Mainnet
  {
    "LockLicenseHook": "0x5D874d4813c4A8A9FB2AB55F30cED9720AEC0222",
    "TotalLicenseTokenLimitHook": "0xB72C9812114a0Fc74D49e01385bd266A75960Cda"
  }
  ```
</CodeGroup>

## Whitelisted Revenue Tokens

The below list contains the whitelisted revenue tokens that can be used in the Royalty Module. Learn more about Revenue Tokens [here](/concepts/royalty-module/ip-royalty-vault).

<Tabs>
  <Tab title="Aeneid Testnet">
    | Token  | Contract Address                             | Explorer                                                                                       | Mint                                                                                                                    |
    | :----- | :------------------------------------------- | :--------------------------------------------------------------------------------------------- | :---------------------------------------------------------------------------------------------------------------------- |
    | WIP    | `0x1514000000000000000000000000000000000000` | [View here ↗️](https://aeneid.storyscan.io/address/0x1514000000000000000000000000000000000000) | N/A                                                                                                                     |
    | MERC20 | `0xF2104833d386a2734a4eB3B8ad6FC6812F29E38E` | [View here ↗️](https://aeneid.storyscan.io/address/0xF2104833d386a2734a4eB3B8ad6FC6812F29E38E) | [Mint ↗️](https://aeneid.storyscan.io/address/0xF2104833d386a2734a4eB3B8ad6FC6812F29E38E?tab=write_contract#0x40c10f19) |
  </Tab>

  <Tab title="Mainnet">
    | Token | Contract Address                             | Explorer                                                                                       | Mint |
    | :---- | :------------------------------------------- | :--------------------------------------------------------------------------------------------- | :--- |
    | WIP   | `0x1514000000000000000000000000000000000000` | [View here ↗️](https://aeneid.storyscan.io/address/0x1514000000000000000000000000000000000000) | N/A  |
  </Tab>
</Tabs>

## Misc

* **Multicall3**: 0xcA11bde05977b3631167028862bE2a173976CA11
* **Default License Terms ID** (Non-Commercial Social Remixing): 1

## Ecosystem Official Contracts

The below is a list of official ecosystem contracts.

### Story ENS

<CodeGroup>
  ```json Aeneid Testnet
  {
    "SidRegistry": "0x5dC881dDA4e4a8d312be3544AD13118D1a04Cb17",
    "PublicResolver": "0x6D3B3F99177FB2A5de7F9E928a9BD807bF7b5BAD"
  }
  ```

  ```json Mainnet
  {
    "SidRegistry": "0x5dC881dDA4e4a8d312be3544AD13118D1a04Cb17",
    "PublicResolver": "0x6D3B3F99177FB2A5de7F9E928a9BD807bF7b5BAD"
  }
  ```
</CodeGroup>




I would like to first run everything locally and then check it with the testnet as well. Build this foundry project for me from scratch along with comprehensive test suits. Make sure to make it in a modular way so that I can integrate the rest of tech plus frontend later. Give me all the code with detailed instructions on running it
