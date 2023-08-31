# Perun-Wallet-Spec

This repository contains documents regarding the specification of a Perun
channel service, which is standardized to allow implementing Perun channels into
any wallet ready to conform with the standard.

The specification itself can be found in [here](./Spec.md).

It contains an architecture overview of how the integration works in a real
setting, sequence diagrams showing the data-flow to visualize how the interaction
between the wallet and Perun channel service is supposed to look like and a
[protobuf description](./src/perun-wallet.proto) for all required messages.

## Integrating Perun payment channels

Generate implementations and skeletons from the protobuf description for a
language required by your wallet. Afterwards implement a channel service adapter
which wraps the rpc interface methods exposed by our channel service.
Create a callback handler module running within your wallet exposing the minimal
API required for the channel service to work and you are done.
