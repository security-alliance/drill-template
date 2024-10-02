## Tools

### Foundry & Hardhat

The test folder contains some utilities for interacting with common protocols. These can be used to test scenarios locally using a fork network. When working with a protocol it is important to write tests to validate the assumptions around the protocol's configuration. Often in writing these tests you will discover potential things to simulate in the drill.

The folder also includes a client for fetching data from TheGraph. This is useful to get network conditions at the time of the fork to simulate behavoir of real addresses.

### Silverback

[Silverback](https://github.com/ApeWorX/silverback) is a framework to orchestrate bots & monitoring. This repository contains some example apps of how to set up:

* Telegram bots to monitor the drill
* Impersonation bots to simulate actions by real addresses
* Configuration with local & remote forks
* Utilities for interacting with various common protocols like Uniswap

### Live Fork & Explorer

There are two recommended ways to run the live exercise. You can either set up a fork network on Tenderly using Testnets which comes with an included explorer, or can host a Blockscout explorer connected to a remote anvil node.

### Bot Services

There is an example bot service in the bots folder. This is a typescript bot that can be used to simulate actions by real addresses. It is inspired by the Optimism services from their [Chain-Mon package](https://github.com/ethereum-optimism/optimism/tree/develop/packages/chain-mon). It can be used to simulate actions like deposits, withdrawals, and trades.

### Monitoring & Alerting Services

There is an example monitoring service in the monitoring folder. This is a typescript bot that can be used to monitor the state of the protocol and send alerts to Prometheus, Grafana, and OpsGenie. It is inspired by the Optimism services from their [Chain-Mon package](https://github.com/ethereum-optimism/optimism/tree/develop/packages/chain-mon). It can be used to monitor things like the state of the protocol, the state of the network, and the state of the explorer.
