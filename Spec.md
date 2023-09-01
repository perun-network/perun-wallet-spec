# Perun Wallet API Specification

The Perun wallet API specification describing the messages send and received
to/from a Perun wallet backend provider.

## Architecture

![architecture](./resources/spec-architecture.jpg)

## Communication

The communication between the channel service and the wallet integrating Perun
channels is defined in the following sequence diagram.

### Signing Messages
![sign-msg](./resources/sequence-sign-message.png)

### Signing Transactions
![sign-msg](./resources/sequence-sign-transaction.png)

### Opening a channel
![open](./resources/sequence-open.png)

### Updating a channel
![update](./resources/sequence-update.png)

### Closing a channel
![close](./resources/sequence-close.png)

### Force closing a channel
![force-close](./resources/sequence-force-close.png)
