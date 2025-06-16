Perfect! Everything is working and all the test cases are also working so I think integration with Debridge is complete. Now we will move to frontend and integrate Yakoa API first. Below are the entire Yakoa docs along with the creds required for accessing the API.

Getting Started
Yakoa’s API helps platforms authenticate digital content for intellectual property (IP) use — whether it’s infringing, authorized, or original. Designed for blockchains, marketplaces, and creative tools, this API gives you automated infrastructure for IP detection, rights validation, and downstream content protection.

You can use it to:

Detect unauthorized reuse of brand-owned content
Check if a creator or asset has prior authorization
Flag original contributions so they’re protected against future infringement
What This API Does
When you register a digital asset (a “Token”), Yakoa evaluates it using AI-powered originality detection and a growing database of known IP, prior authorizations, and protected content.

This answers three critical questions:

Is this asset infringing on existing IP?
We check against all registered brand materials and previously flagged content.

Has this use been authorized?
If the creator or token is already approved by a brand, even if indirectly, that authorization is respected and recorded.

What’s original here, and how should it be protected?
The API flags novel contributions so they become part of the in-network reference set — allowing future infringements of this content to be caught automatically.

Core Entities
These are the main objects you’ll interact with:

Brand: An external IP holder (e.g., a company or creator with known assets and rights)
Creator: A user submitting content
Token: A digital asset (image, video, or audio) with a provenance record (content credential or NFT)
Authorization: A record of permission from an external Brand to your platform's content
License: A record of permission from content on your platform
Trust: A record of your own trust signals for the content on your platform
See Key Concepts for full definitions.

Typical Workflow
Register Tokens: When new content is created:
a. Register a Token with its metadata and media URLs, and add any known Authorizations or Licenses. b. The infringement check will start asynchronously
Monitor Results:
a. Check the infringements object in the response from the token GET endpoint b. In higher-volume use cases, set up a custom integration via web hook
Allow for Updates:
a. If the content evolves, the ownership changes, or a dispute gets raised, pass that information into the Yakoa system to keep your network up to date.

Key Concepts
Here, we go over the core data models and entities you will interact with when using Yakoa's content autnentication API. Understanding these concepts is key to a seamless integration.

Table of Contents
Brand
Creator
Token
Authorization
License
Trust
Brand
Purpose: Represents an external IP owner (company, organization, or individual) from outside your platform. Brands are the basis against which Tokens are checked for infringement.

Why it matters: No network will contain all IP that could be infringed upon, so Yakoa also monitors for infringements against well known, public IP. Matches against this IP are flagged against Brand deemed to own the IP. These results are reported as external_infringements in the Token API, opposed to in_network_infringements, which are only checked against the content already registered in the network.

Creator
Purpose: Represents an entity (often identified by a blockchain address or platform user ID) responsible for producing Tokens.

Why it matters: Tracks provenance of Tokens. Enables Brand-level authorizations for Creators, simplifying IP management for trusted partners, and prevents flagging multiple tokens created by the same Creator against each other.

Token
Purpose: A tokenized media asset, which includes one or more media files (images, videos, audio) and provenance metadata (NFTs or content credentials). Each Token is checked for potential IP infringement.

Why it matters: This is the primary entity for IP analysis. The media URLs must be publicly accessible for checks to occur.

Authorization
Purpose: A formal record indicating that a Brand has permitted a specific Creator or a specific Token to use its IP. This is crucial for distinguishing legitimate use from infringement.

Why it matters: Allows Brands to whitelist trusted Creators or specific content, reducing false positives and enabling collaborations.

License
Purpose: Represents a formal agreement or permission that grants a Token the right to use intellectual property from another Token (a "parent" Token).

Why it matters: Licenses allow for the creation of legitimate derivative works and complex IP relationships within networks. Declaring licenses helps the system understand these relationships and can influence infringement analysis (e.g., a Token might match a Brand's IP, but if it's licensed from an authorized parent Token that also derives from the Brand, it is not considered an infringement).

Trust
Purpose: Allows a token's media to be marked as trusted. The currently available reasons for trust are:

Platform Trust: The platform the media came is is trusted, meaning the media is not likely to infringe on any IP.
No Licenses: The media has no licenses that can be obtained from it, reducing the damage of a potential infringement.
Why is matters: Trusted assets allow you to supplement Yakoa's checks with your own internal trust signals. This can bypass comprehensive infringement checking, but to still allow downstream infringements to be flagged against the trusted media.

Demo Environment
Log into this documentation page with a valid email to automatically receive a demo API key and be added to the demo environment. You'll then see this demo key automatically populated in these docs under the "Credentials" field on any endpoint page!

In this environment, you can run a limited number of content authentication calls through the API and monitor the status of those authentications by polling the Token GET endpoint.

When you're ready to test your application at a larger scale, contact the Yakoa team to coordinate a higher limit, dedicated subdomain, and more seamless web hook integration.

About the demo environment
The demo environment has special limitations that make it great for testing, but less useful in a production setting.

Shared network space
Every user in the demo environment shares a single network space. This means that anyone who knows your unique token identifiers can view the status of your authentications, and your content might be matched against other submissions to the demo environment as an in-network infringement, giving you some unexpected results.

Daily reset
The demo environment clears out its content database at 12:00am UTC each day. This makes it easier for our users to retry the same tests each day, but means that your submitted content won't persist for infringement detection after the reset.

When you're ready to put things into production, or test at a larger scale, contact the Yakoa team.

Register Token
post
https://{subdomain}.ip-api-sandbox.yakoa.io/{network}/token
Registers a new Token or registers new metadata for an existing Token.
This is the primary endpoint for introducing Token data into the Yakoa IP system or modifying it. When you POST data to this endpoint:

The system checks if a Token with the given id (contract address and on-chain token ID, on the specified chain) already exists.
If new: The Token is registered with all provided details:
registration_tx: Transaction details of its creation/minting.
creator_id: The associated Creator.
metadata: Its descriptive metadata.
media: A list of its associated media files (images, videos, etc.).
license_parents (optional): Any parent tokens it derives rights from.
authorizations (optional): Any pre-existing direct authorizations for this Token.
If existing: The Token's information is updated.
The system compares the block_number of the provided registration_tx with the existing one.
If the new registration_tx is more recent (higher block number), the Token's record (including media, metadata etc.) is updated with the new data.
If the existing registration_tx is more recent or the same, the existing core data is preserved
Infringement Check: After registration or update, an IP infringement check is initiated for the Token's media. The results can be retrieved by subsequent calls to the Token GET endpoint.
Key Request Body Fields:

id (string, required): Token identifier (e.g., contract_address:token_id).
registration_tx (object, required): Transaction details.
creator_id (string, required): Creator's identifier.
metadata (object, required): Token metadata.
media (array of objects, required): Media items associated with the Token. Each must have media_id and url. If the media is coming from a non-proveable location, it must include a hash to ensure the content that Yakoa fetches and processes matches that expected by the platform. If the content fetched by Yakoa does not match the expected hash, the media will get a hash_mismatch status and no infringement checks will be run. If the media comes from a proveable location (e.g., IPFS), the hash is not required. Media can optionally include a trust_reason.
license_parents (array, optional): Parent license information.
authorizations (array, optional): Direct brand authorizations for this token.
Use Cases:

Registering a newly minted NFT on a marketplace.
Updating a Token's metadata or media if it changes on-chain or in its source.
Adding new brand authorizations directly to a Token.
Important Notes:

Media URLs must be publicly accessible.
If an existing token is updated with a registration_tx that is older than the stored one, the response will be a 200 OK with the existing token data, rather than a 201 Created.
Body Params
id
string
required
registration_tx
object
required

TransactionPostData object
creator_id
string
required
metadata
object
required

metadata object
media
array of objects
required

ADD object
license_parents

array

null
authorizations

array

null
Metadata
other_data

AuthorizationPostData

null
and below is the example of calling the api

import yakoaIpApi from '@api/yakoa-ip-api';

yakoaIpApi.auth('NkmwG6N1jc5IdtSBahCVP77y5HEYE0F09hrGdAKX');
yakoaIpApi.tokenTokenPost()
  .then(({ data }) => console.log(data))
  .catch(err => console.error(err));

Get Token
get
https://{subdomain}.ip-api-sandbox.yakoa.io/{network}/token/{token_id}
Retrieves comprehensive details for a specific Token.
This endpoint fetches all stored information for a Token, identified by its unique token_id (which includes the chain and contract_address). The response includes:

The Token's id (contract address and on-chain token ID).
registration_tx: Details of the transaction that registered or last updated this Token.
creator_id: The identifier of the Creator associated with this Token.
metadata: The metadata object provided during registration.
media: An array of media items linked to this Token, including their media_id, url, hash, and fetch_status.
license_parents: Information about any parent Tokens from which this Token might inherit rights.
token_authorizations: A list of authorizations granted directly to this Token by Brands.
infringements: The latest infringement check results for this Token. (See Infringements & Credits for details).
Path Parameters:

token_id (string, required): The unique identifier of the Token, typically in the format contract_address:token_id or just contract_address for ERC721 tokens where the on-chain token ID is part of the path.
network (string, required, from parent router): The blockchain network the Token is associated with.
Metadata
token_id
string
required


and below is the example of calling the api

import yakoaIpApi from '@api/yakoa-ip-api';

yakoaIpApi.auth('NkmwG6N1jc5IdtSBahCVP77y5HEYE0F09hrGdAKX');
yakoaIpApi.tokenTokenIdTokenGet({token_id: 'token_id'})
  .then(({ data }) => console.log(data))
  .catch(err => console.error(err));


Get Token Media
get
https://{subdomain}.ip-api-sandbox.yakoa.io/{network}/token/{token_id}/media/{media_id}
Retrieves a specific media item associated with a token.

The media item is identified by its media_id and belongs to the token specified by token_id in the path. This endpoint returns the details of the media, including its URL, hash (if available), and trust reason.

and below is the example of calling the api

import yakoaIpApi from '@api/yakoa-ip-api';

yakoaIpApi.auth('NkmwG6N1jc5IdtSBahCVP77y5HEYE0F09hrGdAKX');
yakoaIpApi.tokenTokenIdMediaMediaIdMediaGet({token_id: 'token_id', media_id: 'media_id'})
  .then(({ data }) => console.log(data))
  .catch(err => console.error(err));


Update Token Media
patch
https://{subdomain}.ip-api-sandbox.yakoa.io/{network}/token/{token_id}/media/{media_id}
Updates attributes of a specific media item associated with a token.

Allows for partial updates to a media item's properties, such as its trust_reason. The media item is identified by its media_id and belongs to the token specified by token_id in the path. The request body should contain the fields to be updated.

Body Params
trust_reason

TrustedPlatformTrustReason

NoLicensesTrustReason

null

and below is the example of calling the api
import yakoaIpApi from '@api/yakoa-ip-api';

yakoaIpApi.auth('NkmwG6N1jc5IdtSBahCVP77y5HEYE0F09hrGdAKX');
yakoaIpApi.tokenTokenIdMediaMediaIdMediaPatch({token_id: 'token_id', media_id: 'media_id'})
  .then(({ data }) => console.log(data))
  .catch(err => console.error(err));

Get Token Brand Authorization
get
https://{subdomain}.ip-api-sandbox.yakoa.io/{network}/token/{token_id}/authorization/{brand_id}
Retrieves details of a specific Brand Authorization for a Token.
This endpoint fetches the authorization record that permits a specific Token to use content associated with a particular Brand.

Use Cases:

Verifying if a specific Token is authorized by a Brand before taking action (e.g., during an infringement review).
Displaying authorization details in a user interface.
Auditing permissions granted to a Token.
Path Parameters:

token_id (string, required, from parent router): The unique identifier of the Token.
network (string, required, from parent router): The blockchain network.
brand_id (string, required): The unique identifier of the Brand for which authorization details are being requested for this Token.


and below is the example of calling the api

import yakoaIpApi from '@api/yakoa-ip-api';

yakoaIpApi.auth('NkmwG6N1jc5IdtSBahCVP77y5HEYE0F09hrGdAKX');
yakoaIpApi.tokenTokenIdAuthorizationBrandIdAuthorizationGet({token_id: 'token_id', brand_id: '[object Object]'})
  .then(({ data }) => console.log(data))
  .catch(err => console.error(err));


Delete Token Brand Authorization
delete
https://{subdomain}.ip-api-sandbox.yakoa.io/{network}/token/{token_id}/authorization/{brand_id}
Deletes an existing Brand Authorization for a specific Token.
This action revokes a previously granted permission for a Token to use content associated with a specific Brand.

Use Cases:

A Brand revokes permission for a specific Token due to a change in licensing terms.
An erroneous authorization needs to be removed.
Path Parameters:

token_id (string, required, from parent router): The unique identifier of the Token.
network (string, required, from parent router): The blockchain network.
brand_id (string, required): The unique identifier of the Brand whose authorization is being deleted for this Token.
Responses:

204 No Content: Successfully deleted the authorization (or it didn't exist).


import yakoaIpApi from '@api/yakoa-ip-api';

yakoaIpApi.auth('NkmwG6N1jc5IdtSBahCVP77y5HEYE0F09hrGdAKX');
yakoaIpApi.tokenTokenIdAuthorizationBrandIdAuthorizationDelete({token_id: 'token_id', brand_id: '[object Object]'})
  .then(({ data }) => console.log(data))
  .catch(err => console.error(err));


Create or Update Token Brand Authorization
post
https://{subdomain}.ip-api-sandbox.yakoa.io/{network}/token/{token_id}/authorization
Creates or updates a Brand Authorization for a specific Token.
{user.email}

This endpoint establishes or modifies a record indicating that a specific Token has explicit permission from a Brand to use its intellectual property. If an authorization for this Token and Brand already exists, its data field is updated. Otherwise, a new authorization record is created.

Use Cases:

A Brand explicitly approves a specific Token (e.g., a piece of user-generated content using their IP).
Marking a Token as a "false positive" after an infringement check, thereby authorizing it.
Updating the details or evidence of an existing authorization for a Token.
Path Parameters:

token_id (string, required, from parent router): The unique identifier of the Token receiving the authorization.
network (string, required, from parent router): The blockchain network.
Request Body:

brand_id (string, optional): The unique identifier of the Brand granting the authorization.
brand_name (string, optional): The name of the Brand. (Either brand_id or brand_name must be provided).
data (object, required): An object containing details about the authorization. The structure of this object can vary. Common fields include:
type (string): The type of authorization (e.g., "email", "false_positive").
Other fields relevant to the type (e.g., email_address for "email", reason for "false_positive").
Body Params
brand_id

string

null
brand_name

string

null
data
required

EmailAuthorization

FalsePositive
Metadata
token_id
string
required


import yakoaIpApi from '@api/yakoa-ip-api';

yakoaIpApi.auth('NkmwG6N1jc5IdtSBahCVP77y5HEYE0F09hrGdAKX');
yakoaIpApi.tokenTokenIdAuthorizationAuthorizationPost({token_id: 'token_id'})
  .then(({ data }) => console.log(data))
  .catch(err => console.error(err));

Now i want to build a minimal frontend first basically it should be able to display all the basic functionality along with authentication from Yakoa. Metamask will be the wallet and Next.js for frontend. While integrating Yakoa if there are changes in the smart contract also do that but if not then give me also instruction on deploying it on Story Testnet. Make sure to integrate both Frontend and Backend and make sure all the basic functionality works first frontend is not my focus. 

basically following should work:

IP Registration: Creator registers IP on Story Protocol

Yakoa Screening: Automatic infringement check via Story's existing Yakoa integration

Attestation: Only IP that passes Yakoa's authenticity checks receives positive attestations

Collateral Eligibility: Only attested, non-infringing IP becomes eligible for use as collateral

Cross-Chain Lending: deBridge enables lending across multiple chains

Make sure to give me all the instructions in as much detail as possible