# SEAL Drill Template

This repository contains the templates and relevant tooling used by the SEAL Chaos Team to coordinate drills with protocol teams.

## Getting Started

The general framework for planning and executing a drill is outlined in this README below. Supporting text templates can be found in the [`templates/`](./templates) directory

For a complete demonstration of a drill on an example protocol, visit the [`e2e-example/`](./e2e-example) directory. The contents of this directory can also be modified and adapted for conducting your own drills.

For general tools, refer to the [`tools/`](./tools) directory.

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

A sample tabletop script is available in [`templates/tabletop.md`](templates/tabletop.md).

### Phase 3 - Live Drill Planning

After the tabletop, the tools in this repository can be used to plan a live drill. The drill should be designed to test the protocol's response process, and to validate the recon work. It should also be designed to be as safe as possible, and to minimize the impact on users or risk to the protocol.

Once a scenario has been selected, it can be tested using the Foundry & Hardhat suite using a fork network to validate the conditions of the scenario. The scenario can then be implemented in Silverback, and operated on a live fork on Tenderly.

While it is possible to override contract states and code on fork networks, it is best to keep the scenario as realistic as possible by simulating actions that could realistically be taken by addresses with the appropriate permissions. This helps to validate the protocol's configuration, and to ensure that the protocol team is able to respond to the scenario.

### Phase 4 - Retrospective

After the drill, it is important to perform a retrospective with the protocol team. This should include a discussion of what went well, what could have gone better, and any changes that should be made to the protocol's configuration or response process. It is also a good time to discuss any additional training or resources that the protocol team may need.

A sample retrospective script is available in [`templates/retrospective.md`](templates/retrospective.md).
