<h1 align="center"><br>
    <a href="https://perun.network/"><img src=".assets/go-perun.png" alt="Perun" width="196"></a>
<br></h1>

<h2 align="center">Perun-Wallet-Spec</h2>

<p align="center">
  <a href="https://www.apache.org/licenses/LICENSE-2.0.txt"><img src="https://img.shields.io/badge/license-Apache%202-blue" alt="License: Apache 2.0"></a>
</p>


This repository contains documents regarding the specification of a Perun
channel service, which is standardized to allow implementing Perun channels into
any wallet ready to conform with the standard.

The specification itself can be found in [here](./Spec.md).

It contains an architecture overview of how the integration works in a real
setting, sequence diagrams showing the data-flow to visualize how the interaction
between the wallet and Perun channel service is supposed to look like and a
[protobuf description](./src/proto/perun-wallet.proto) for all required messages.

## Integrating Perun payment channels

Step-by-step guide:
  1. Generate implementations and skeletons from the protobuf description for a
language required by your wallet.
  2. Implement a channel service adapter which wraps the rpc interface methods exposed by our channel service.
  3. Create a callback handler module running within your wallet exposing the minimal API required for the channel service to work.
  4. Done.
