# Drill Scenario Template

This repository contains the tools that the SEAL Chaos Team uses to coordinate drills with protocol teams. They include:

* A Foundry & Hardhat setup for developing & testing scenarios on a local fork
* A [Silverback](https://github.com/ApeWorX/silverback) python application for orchestrating the drill & monitoring
* Configurations for running a live fork on Tenderly
* A template for a tabletop exercise
* A template typescript bot service (inspired by Optimism)
* A template monitoring bot service with connections to Prometheus, Grafana, and OpsGenie (inspired by Optimism)

## Planning a Drill

### Phase 1 - Recon

To plan an effective drill for a protocol, it is important to perform a thorough analysis of the protocol's attack surface, dependencies, governance capabilities, and assumptions. Typically we start by gathering all open source resources about the protocol, including:

* Smart contract architecture
* Deployment & upgrade processes
* Governance processes
* Dependencies on other protocols
* Differences between deployed versions of the protocol, and any planned upcoming changes
* Any known vulnerabilities or past incidents and how the team responds
* Admin functionality & the entities trusted to use it

### Phase 2 - Validation & Tabletop Exercise

Before designing the live drill, it is recommended to perform a tabletop exercise with the protocol team. This is a great way to validate the recon work, and to get a better understanding of the protocol's attack surface. It also helps to build a relationship with the protocol team, which is important for the live drill.

The tabletop exercise should include a few different scenarios to help understand:

* What the protocol team's response process is
* How roles & responsibilities are assigned
* How communication is handled
* The team's understanding of the protocol's configuration & attack surface
* Known issues or upcoming changes

It can also help to ask the team if there are any particular areas of the protocol that they are concerned about, or that they would like to test.

A sample tabletop script is available in [tabletop/template.md](tabletop/template.md).

### Phase 3 - Live Drill Planning

After the tabletop, the tools in this repository can be used to plan a live drill. The drill should be designed to test the protocol's response process, and to validate the recon work. It should also be designed to be as safe as possible, and to minimize the impact on users or risk to the protocol.

Once a scenario has been selected, it can be tested using the Foundry & Hardhat suite using a fork network to validate the conditions of the scenario. The scenario can then be implemented in Silverback, and operated on a live fork on Tenderly.

While it is possible to override contract states and code on fork networks, it is best to keep the scenario as realistic as possible by simulating actions that could realistically be taken by addresses with the appropriate permissions. This helps to validate the protocol's configuration, and to ensure that the protocol team is able to respond to the scenario.

### Phase 4 - Postmortem

After the drill, it is important to perform a postmortem with the protocol team. This should include a discussion of what went well, what could have gone better, and any changes that should be made to the protocol's configuration or response process. It is also a good time to discuss any additional training or resources that the protocol team may need.

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

