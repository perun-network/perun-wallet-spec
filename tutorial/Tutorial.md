# Integrating Perun Payment Channels into YOUR CKB wallet software
In this tutorial, we work through the development steps of integrating Perun Payment Channels into an existing CKB wallet.
The goal is that users can access a simplified Perun Channel API through their respective wallet.
Users can use this API to open channels with peers, send payments through channels and close a channel, withdrawing their funds.

## Preliminaries
This tutorial abstracts from technical details regarding channels and the Perun protocol. Instead, we advise to work through the following material to obtain a general understanding:
[perun-doc](https://labs.hyperledger.org/perun-doc/go-perun/index.html)

Note that Perun is a *blockchain agnostic* protocol, so don't worry about the examples being Ethereum-focused.
Luckily, there is an interactive app that demonstrates the CKB implementation of multi-asset payment channels. You can try it out yourself:
[perun-ckb-demo](https://github.com/perun-network/perun-ckb-demo)

### Existing Components
Before diving into the actual integration, we need to set an overview of all involved components:

#### [go-perun](https://github.com/hyperledger-labs/go-perun)
go-perun is our core framework and implements the protocol in the Go programming language. It implements the blockchain agnostic parts and defines interfaces for everything blockchain-specific. In order to support Perun Channels on a blockchain, one needs to create a blockchain-specific backend that implements said interfaces (this is already done for CKB). It also defines and implements a client and channel API that we will use to serve our simplified channel API. Most likely, you will not need to touch go-perun to integrate channels into your CKB wallet.

#### [perun-ckb-backend](https://github.com/perun-network/perun-ckb-backend)
The perun-ckb-backend implements the necessary blockchain-specific go-perun interfaces. At the same time it exposes clients, wallets and event subscriptions as a library, so that developers can use Perun payment channels on CKB. The [perun-ckb-demo](https://github.com/perun-network/perun-ckb-demo) provides an example how developers might use payment channels, interacting with the perun-ckb-backend and go-perun.

#### [perun-ckb-contract](https://github.com/perun-network/perun-ckb-contract)
CKB's Perun implementation is a bit special, as CKB is a UTXO-based blockchain with advanced smart contract support. Perun's CKB contracts consist of three scripts:
- **perun-channel-typescript (PCTS)**: Every open channel is represented by a unique live cell with the PCTS as type script. The PCTS contains all the channel logic and therefore handles opening, funding, disputing and closing channels.
- **perun-channel-lockscript (PCLS)**: The PCLS is the lock script for the channel cell and ensures that only (authorized) channel participants may interact with the channel.
- **perun-funds-lockscript (PFLS)**: In order to fund a channel, the funds (UDTs or CKBytes) must be locked to the PFLS with args that identify the respective channel. The PFLS then makes sure that the funds can only be unlocked through interaction with the PCTS (according to the Perun protocol).

There is a lot more to understand about Perun's CKB contracts, but we will not go into more detail here. All the interactions with the respective contracts / scritps are already implemented and abstracted in the perun-ckb-backend. If you, nevertheless, want to learn more about the protocol implementation and the contract, we advise you to take a look at the well-commented contract code or the (early) specification document: [perun-on-ckb-spec](https://docs.google.com/document/d/1V3Qq12XyFk37Sv3c7PzUbsRf8w_g3Ypyv7KJX1u-tDA/edit#heading=h.w60zhpajtahh).

### Architecture
The architecture of the wallet integration is described in detail within this repository. We strongly advise to have a look in the proto files for the definitions of the ChannelService and WalletService. Still, we will engage in a comprehensive introduction here:

The wallet integration consists of two components, each exposing a RPC api to the other.

#### Channel Service
The channel service exposes the ChannelService api to the wallet. It is a Go program that interacts with a CKB node (via rpc), go-perun (as a library) and the perun-ckb-backend (as a library). Very roughly speaking, it acts as a Perun Protocol **proxy** to the wallet. Currently, we imagine a channel service running on the same device as the wallet. We use RPC though, specifically to accomodate for different setups, where the channel service is running remotely or even shared by multiple wallets. The channel service fulfills two purposes:
1. Expose the (simplified) Perun Channel API to the wallet (`OpenChannel`, `UpdateChannel`, `CloseChannel`). In this role, it handles requests by the wallet, e.g. to open a channel with another party, using go-perun and the perun-ckb-backend.
2. Forward (simplified) protocol messages from the protocol (go-perun) side to the wallet. For this, the channel service queries the WalletService (served by the wallet) through RPC.

The channel service handles a lot of responsibilities **through go-perun**, such as:
- Keeping track of the open channels and channel states
- Watching the chain for relevant events (using the perun-ckb-backend's [adjudicator subscription](https://github.com/perun-network/perun-ckb-backend/tree/dev/channel/adjudicator)) and acting according to protocol. Note that is alread covered by perun-ckb-backend and go-perun. The channel-service only needs to provide some callback handlers.
- Persisting channels and relevant channel data (e.g. using go-perun's [Persistor](https://github.com/perun-network/go-perun/blob/main/channel/persistence/persistence.go))
- Communication between channel participants (users). Here, go-perun already provides functionality for e.g. network communication. You just need to initialize it.

There already exists a first channel-service implementation [here](https://github.com/perun-network/channel-service). It is implemented in the effort to integrate Perun Channels into the Neuron wallet, but it is kept "wallet-agnostic". Thus, you should be able to use this service directly to integrate your wallet, with only minimal changes necessary. We note that the current channel service implementation does not support persistence and only supports in-process communication as it is in a POC/demo state.

### Wallet Service
The Wallet Service depends greatly on the target wallet you want to integrate. Generally, the Wallet Service must expose the Wallet Service API (`OpenChannel`, `UpdateNotification`, `SignMessage`, `SignTransactions`) through RPC for the Channel Service to use.
Additionally, the Wallet Service should use the Channel Service to give users the ability to actively participate in Perun channels (to open channels, propose updates or close channels).


Let us first work through the Wallet Service API
#### Open Channel 
This endpoint is called whenever the user represented by the wallet receives an ingoing request to open a channel through go-perun in the channel service. The channel service this endpoint in the wallet, forwarding important information about the request such as the peer, the assets and initial balance distribution and the challenge duration. The wallet answers this either by rejecting the request (thus not engaging in opening a channel) or by accepting it. If the request is accepted, the wallet needs to provide a random nonce along with the accept message. Aside from parsing the request, marshalling the response and generating the nonce, the wallet is tasked with deciding, whether the user actually wants to open the channel according to the request. This could be realized either by default (e.g. always open channels if my initial balance is 0) or through interaction with the user (UI)

#### UpdateNotification
Perun Channels advance state through *updates*. This means, every payment is a state update with coherently updated balance distribution and incremented version number. Whenever the client of the user in the channel service receives an incoming update request, the channel service should forward this request to the wallet through this endpoint (different channel service implementation are of course possible, but this is the most reasonable). This UpdateNotification contains the proposed state *after* the update. Similar to OpenChannel, the wallet is tasked with either accepting or rejecting the update. Note that it might not make sense to require approval of the wallet user for all incoming updates. More advanced implementations could allow the user to install update policies so that e.g. updates where the user's balance increases (incoming payments) are always accepted or updates for payments up to a certain amount in the last 24h are always accepted etc.. or allows users to deploy hooks for incoming update notifications.

#### SignMessage
In Perun, we distinguish between the on-chain keypair, which is used to sign transactions and the off-chain keypair, which is used to sign Perun state updates. One might use the same keypair for both purposes, but this is discouraged and there is really no reason to do so (it might be helpful though for quick demos...). In our design, we decided that *both* keypairs (yes, also the off-chain keypair) should be maintained by the wallet, as this is a wallet's most core purpose after all. 

The `SignMessage` endpoint is exposed by the wallet to specifically to sign state updates (or initial states for opening) with the off-chain keypair. The wallet receives the identifier of the keypair to sign with (e.g. a public key, a ckb address, ...) as well as the payload as bytes (molecule encoded state to sign). The wallet should either reject signing or return the signature. 

Currently, we expect the signature to be a DER encoded secp256k1 ecdsa signature on the payload's blake2b-256 hash. For some complicated reason, the current channel-service expects this signature to be padded to 73 bytes with a custom padding (see perun-ckb-backend/wallet/signature.go), but DER encoding or applying this padding could also be done within the channel service with the signature (in a different format) received from the wallet service. We note that we currently do not use any hash-personalization for the payload pre-hash. See the `SignData` function in /perun-ckb-backend/wallet/account.go for a reference implementation in go.

We note that e.g. for incoming updates, the wallet will first be sent an `UpdateNotification`. If this is accepted, there is some back and forth in the channel service until there the channel service asks the wallet to sign the corresponding state update through `SignMessage`. Some wallet implementations might want to ask the user for approval on every `SignMessage`. We note that it would also be possible for the wallet to identify that a `SignMessage` request belongs to a previously approved `UpdateNotification` and thus sign the message without the user's specific approval (without further interaction). Thus, similar to `UpdateNotification`, there remains a lot of room for wallets to implement policies and quality of life features, while still balancing security.

#### SignTransaction
The Perun protocol requires parties to go on-chain (send transactions), for opening/ funding a channel, for closing/force-closing (including withdrawals) and for registering disputes (should any party stop responding or behave maliciously). These transactions must obviously be signed by the wallet with the on-chain keypair to
- pay fees
- lock funds (CKBytes, UDTs) in the channel during opening / funding
- unlock the channel - our current PFLS requires a certain lock script to be present in the inputs of a transaction for the transaction to consume the channel cell that is locked by the PFLS. We recommend to use the Secp256K1Blake160SigHashAll as unlock script, preferably with the key that is used for fees and funding anyway because then the channel is automatically unlocked.

The idea is that transactions are prepared by the channel service (through the perun-ckb-backend) so that the wallet only needs to sign them and put the signature as witness in the correct place. The wallet does not need to send the transaction itself. We kept this API on a byte-level to allow for different channel service and wallet implementations. E.g. the wallet might just return the signature on the given transaction and the channel service is then responsible for putting it in the correct witness field. We emphasize that the Perun protocol makes use of "non-standard" lockscripts and typescripts. You need to make sure that your wallet's transaction signing is able to handle transactions with fund inputs (locked with PFLS) and channel-cell inputs (locked with PCLS) with the according witnesses. The wallet's transaction signing receives a (balanced) transaction with all necessary inputs and outputs and should sign the transaction such that all payment inputs (e.g. secp256k1sighashall lockscripts) verify without interfering with the Perun inputs and witnesses.

#### GetAssets
The GetAssets endpoint is currently unused. The idea is, that it should be possible for the wallet (and by extension the user) to decide which specific assets (outpoints) to use to e.g. fund the channel with or pay fees. This migh be especially handy if you consider UDT assets. Currently this is not supported, as it would require a lot of changes to parts of the perun-ckb-backend. The used outpoints for the funding and payments of fees are decided by the perun-ckb-backend.

With this, we conclude the description of the wallet service API.

We note that the wallet should also use the API exposed by the channel service (through a ChannelServiceClient) to enable users to *acticvely* interact with channels. There should be a UI component, where users can actively see the state of current channels, open new channels, propose updates to channels or close existing channels. This API should be connected to a ChannelServiceClient running in the wallet that forwards the actions to the channel service.

### Summary
We conclude with briefly summarizing the necessary steps to integrate Perun into YOUR wallet.
- Implement channel service
    - either use existing one [here](https://github.com/perun-network/channel-service)
    - or implement your own channel service in the following steps
        - generate grpc proto
        - implement ChannelServiceServer using
            - WalletServiceClient
            - go-perun
            - perun-ckb-backend
            - use our prototype implementation as guidance
- Implement wallet service
    - generate proto services
    - you will most likely need to generate the molecule for the perun-types for the language of your wallet (`.mol` files in https://github.com/perun-network/perun-ckb-contract/tree/dev/contracts/perun-common)
    - Implement WalletServiceServer
    - Implement ChannelServiceClient
    - Implement UI components to allow the user to interact with channels and accept/reject incoming open requests, updates or signing requests for channel state or transactions
- Connect services through RPC


### Thoughts on Security, Potential Risks and Remedies
While the Perun protocol itself has been proven secure, there is no guarantee that the Nervos/CKB instantiation comes without security issues. All of the components (contracts, backend, ...) are in an early stage of development and might contain security vulnerabilities that, in the worst case, may lead to loss of funds. We advise to treat the components as such and perform comprehensive testing before using them with real funds. This especially applies to the existing [channel-service](https://github.com/perun-network/channel-service) implementation and the neuron integration, as they are still very proof-of-concept-like.

There are also some security considerations concerning the actual integration into a wallet. The most important items that come to mind are:
- The channel-service acts as a trusted component, but it is sensible to verify everything as far as possible, before issuing signatures e.g.:
    - Verify the integrity of channel states in your wallet before presenting them to the user to sign them. You should provide both the raw bytes as well as a decoding displayed as structural / human-readable representation. You can use our molecule types for this.
    - The channel-service will provide the wallet with transactions ready to sign e.g. for opening, funding, disputes and closing/withdrawal. You can improve security by both verifying these transactions as far as possible and explaining / representing what they actually do to the user before prompting the user to sign them.
- Keep all private-keys inside the wallet. It would be possible (and probably easier) to implement this such that the keys for signing updates/transactions are kept within the channel-service. We strongly advise against this.
- Keep in mind that loss of funds can also happen without any malicious actors e.g. due to bugs. E.g.: If there were a bug in the perun-ckb-backend that lead to failure of building a closing/withdrawal transaction, you would have a very hard time reclaiming the funds manually. We advise to do intensive testing before using your integration with real funds on mainnet.

### FAQ

#### What if my wallet is already implemented in Go?
In this case you don't need to bother with all this (services, RPC, ...). You can just use the go-perun and perun-ckb-backend API to directly integrate Perun channels into Your wallet. There is no need for a channel service running in a separate process.

#### How do I implement the Perun logic correctly?
The good news is, you don't really need to. Everything Perun-specific can be handled through the perun-ckb-backend and go-perun libraries within the channel service.

#### Is it safe to use Perun channels?
Conceptually yes, though you should do a lot of testing to make sure your final implementation does not contain any bugs / flaws. In the worst case, a bug may lead to loss or theft of funds.

#### How are channels persisted when I close the wallet?
It is the channel service's responsibility to persist states. It should use go-perun's [Persistor](https://github.com/perun-network/go-perun/blob/main/channel/persistence/persistence.go) to make sure that all necessary information is persisted. If you run into issues, where you want to display channel info in your wallet and this info isn't persisted when you close the wallet, then you could e.g. add an RPC call that asks the channel service for that info.

#### Do I need to watch the chain for events that are relevant to my Channels?
There is already functionality for this in the perun-ckb-backend and go-perun. You just need to initialize it correctly in the channel service upon channel opening.

#### How do I decode Perun types?
Use molecule: 
- https://github.com/perun-network/perun-ckb-contract/blob/dev/contracts/perun-common/types.mol
- https://github.com/perun-network/perun-ckb-contract/blob/dev/contracts/perun-common/offchain_types.mol


### Contact us
If remain open questions, feel free to open an issue on github. Alternatively, check out our [discord](https://perun.network/discord).