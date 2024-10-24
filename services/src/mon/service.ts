import {
  BaseServiceV2,
  StandardOptions,
  ExpressRouter,
  Gauge,
  validators,
  waitForProvider,
} from '@eth-optimism/common-ts'
import { sleep } from '@eth-optimism/core-utils'
import { Provider } from '@ethersproject/abstract-provider'
import { BigNumber, ethers } from 'ethers'

import { version } from '../../package.json'

import { LockupAbi } from '../../lib/abi/LockupAbi'
import { MockTokenAbi } from '../../lib/abi/MockTokenAbi'

type Options = {
  rpcProvider: Provider
  lockupProxyAddress: string
  sleepTimeMs: number
  lockupIndexingStartBlock: number
  bufferBlockCount: number
}

type Metrics = {
  nodeConnectionFailures: Gauge
  lockupEventsCount: Gauge
  claimEventsCount: Gauge
  totalLockedAmount: Gauge
  totalClaimedAmount: Gauge
  invariantViolations: Gauge
  lockupContractBalance: Gauge
}

type LockupEvent = {
  id: number
  token: string
  recipient: string
  amount: BigNumber
  blockNumber: number
}

type ClaimEvent = {
  id: number
  token: string
  recipient: string
  amount: BigNumber
  blockNumber: number
}

type TokenBalance = {
  locked: BigNumber
  claimed: BigNumber
  lastUpdatedBlock: number
}

type State = {
  lockupProxy: ethers.Contract
  lockupEvents: LockupEvent[]
  claimEvents: ClaimEvent[]
  tokenBalances: Map<string, Map<string, TokenBalance>>
  lastProcessedBlockNumber: number
  isInitialSyncComplete: boolean
}

export class LockupMonitor extends BaseServiceV2<Options, Metrics, State> {
  constructor(options?: Partial<Options & StandardOptions>) {
    super({
      version,
      name: 'lockup-monitor',
      loop: true,
      options: {
        loopIntervalMs: 60000, // Run every minute
        bufferBlockCount: 5, // Default buffer of 5 blocks
        ...options,
      },
      optionsSpec: {
        rpcProvider: {
          validator: validators.provider,
          desc: 'Provider for interacting with the network',
        },
        lockupProxyAddress: {
          validator: validators.address,
          desc: 'Address of the lockup proxy',
        },
        sleepTimeMs: {
          validator: validators.num,
          default: 15000,
          desc: 'Time in ms to sleep when waiting for a node',
          public: true,
        },
        lockupIndexingStartBlock: {
          validator: validators.num,
          default: 0,
          desc: 'Block number to start indexing lockups from',
        },
        bufferBlockCount: {
          validator: validators.num,
          default: 5,
          desc: 'Number of blocks to use as a buffer before checking invariants',
        },
      },
      metricsSpec: {
        nodeConnectionFailures: {
          type: Gauge,
          desc: 'Number of times node connection has failed',
          labels: ['layer'],
        },
        lockupEventsCount: {
          type: Gauge,
          desc: 'Number of lockup events',
          labels: ['token'],
        },
        claimEventsCount: {
          type: Gauge,
          desc: 'Number of claim events',
          labels: ['token'],
        },
        totalLockedAmount: {
          type: Gauge,
          desc: 'Total locked amount per token',
          labels: ['token'],
        },
        totalClaimedAmount: {
          type: Gauge,
          desc: 'Total claimed amount per token',
          labels: ['token'],
        },
        invariantViolations: {
          type: Gauge,
          desc: 'Number of invariant violations (claimed > locked for token and recipient)',
          labels: ['token', 'recipient'],
        },
        lockupContractBalance: {
          type: Gauge,
          desc: 'Balance of the lockup contract',
          labels: ['token'],
        },
      },
    })
  }

  async init(): Promise<void> {
    await waitForProvider(this.options.rpcProvider, {
      logger: this.logger,
      name: 'L1',
    })

    this.state.lockupProxy = new ethers.Contract(
      this.options.lockupProxyAddress,
      LockupAbi,
      this.options.rpcProvider
    )

    this.state.lockupEvents = []
    this.state.claimEvents = []
    this.state.tokenBalances = new Map()
    this.state.lastProcessedBlockNumber =
      this.options.lockupIndexingStartBlock - 1
    this.state.isInitialSyncComplete = false

    await this.indexPreviousEvents()
  }

  async routes(router: ExpressRouter): Promise<void> {
    router.get('/healthz', async (req, res) => {
      return res.status(200).json({
        ok: true,
      })
    })
  }

  private async indexPreviousEvents(): Promise<void> {
    console.log(
      `Indexing previous events starting from block ${this.options.lockupIndexingStartBlock}...`
    )
    const latestBlock = await this.options.rpcProvider.getBlock('latest')

    const lockupFilter = this.state.lockupProxy.filters.NewLockup()
    const lockupEvents = await this.state.lockupProxy.queryFilter(
      lockupFilter,
      this.options.lockupIndexingStartBlock,
      latestBlock.number
    )

    const claimFilter = this.state.lockupProxy.filters.LockupClaimed()
    const claimEvents = await this.state.lockupProxy.queryFilter(
      claimFilter,
      this.options.lockupIndexingStartBlock,
      latestBlock.number
    )

    console.log(
      `Found ${lockupEvents.length} lockup events and ${claimEvents.length} claim events`
    )

    this.processEvents(lockupEvents, claimEvents)

    this.state.lastProcessedBlockNumber = latestBlock.number
    this.state.isInitialSyncComplete = true
    console.log(
      `Finished indexing previous events up to block ${latestBlock.number}`
    )
    // this.logAllBalances()
  }

  private processEvents(
    lockupEvents: ethers.Event[],
    claimEvents: ethers.Event[]
  ): void {
    const allEvents = [...lockupEvents, ...claimEvents].sort((a, b) => {
      if (a.blockNumber !== b.blockNumber) {
        return a.blockNumber - b.blockNumber
      }
      return a.transactionIndex - b.transactionIndex
    })

    for (const event of allEvents) {
      if (event.event === 'NewLockup') {
        this.processLockupEvent(event)
      } else if (event.event === 'LockupClaimed') {
        this.processClaimEvent(event)
      }
    }
  }

  private processLockupEvent(event: ethers.Event): void {
    const lockupInfo = event.args.l
    const newLockup: LockupEvent = {
      id: lockupInfo.id.toNumber(),
      token: lockupInfo.token,
      recipient: lockupInfo.recipient,
      amount: lockupInfo.amount,
      blockNumber: event.blockNumber,
    }
    this.state.lockupEvents.push(newLockup)

    if (!this.state.tokenBalances.has(newLockup.token)) {
      this.state.tokenBalances.set(newLockup.token, new Map())
    }
    const tokenBalances = this.state.tokenBalances.get(newLockup.token)!
    const currentBalance = tokenBalances.get(newLockup.recipient) || {
      locked: BigNumber.from(0),
      claimed: BigNumber.from(0),
      lastUpdatedBlock: 0,
    }
    const newBalance = {
      locked: currentBalance.locked.add(newLockup.amount),
      claimed: currentBalance.claimed,
      lastUpdatedBlock: newLockup.blockNumber,
    }
    tokenBalances.set(newLockup.recipient, newBalance)

    // console.log(`Processed lockup event:`)
    // console.log(`  ID: ${newLockup.id}`)
    // console.log(`  Token: ${newLockup.token}`)
    // console.log(`  Recipient: ${newLockup.recipient}`)
    // console.log(`  Amount: ${newLockup.amount.toString()}`)
    // console.log(`  Block: ${newLockup.blockNumber}`)
    // console.log(`  New Balance:`)
    // console.log(`    Locked: ${newBalance.locked.toString()}`)
    // console.log(`    Claimed: ${newBalance.claimed.toString()}`)
  }

  private processClaimEvent(event: ethers.Event): void {
    const claimInfo = event.args.l
    const newClaim: ClaimEvent = {
      id: claimInfo.id.toNumber(),
      token: claimInfo.token,
      recipient: claimInfo.recipient,
      amount: claimInfo.amount,
      blockNumber: event.blockNumber,
    }
    this.state.claimEvents.push(newClaim)

    if (!this.state.tokenBalances.has(newClaim.token)) {
      this.state.tokenBalances.set(newClaim.token, new Map())
    }
    const tokenBalances = this.state.tokenBalances.get(newClaim.token)!
    const currentBalance = tokenBalances.get(newClaim.recipient) || {
      locked: BigNumber.from(0),
      claimed: BigNumber.from(0),
      lastUpdatedBlock: 0,
    }
    const newBalance = {
      locked: currentBalance.locked, // Keep the locked amount as is
      claimed: currentBalance.claimed.add(newClaim.amount),
      lastUpdatedBlock: event.blockNumber,
    }
    tokenBalances.set(newClaim.recipient, newBalance)
  }

  private convertToDecimal(amount: BigNumber, decimals: number): number {
    const amountString = ethers.utils.formatUnits(amount, decimals)
    return parseFloat(amountString)
  }
  
  private async updateLockupBalanceMetrics(tokenAddress: string): Promise<void> {
    const mockToken = new ethers.Contract(
      tokenAddress,
      MockTokenAbi,
      this.options.rpcProvider
    )
    const balance = await mockToken.balanceOf(this.options.lockupProxyAddress)
    this.metrics.lockupContractBalance.set(
      { token: tokenAddress },
      this.convertToDecimal(balance, 18)
    )
  }

  private async updateMetrics(currentBlockNumber: number): Promise<void> {
    const lockupTokens = new Set(this.state.lockupEvents.map((e) => e.token))
    for (const token of lockupTokens) {
      const count = this.state.lockupEvents.filter(
        (e) => e.token === token
      ).length
      this.metrics.lockupEventsCount.set({ token }, count)

      await this.updateLockupBalanceMetrics(token)
    }

    const claimTokens = new Set(this.state.claimEvents.map((e) => e.token))
    for (const token of claimTokens) {
      const count = this.state.claimEvents.filter(
        (e) => e.token === token
      ).length
      this.metrics.claimEventsCount.set({ token }, count)

      await this.updateLockupBalanceMetrics(token)
    }

    for (const [token, balances] of this.state.tokenBalances) {
      for (const [recipient, balance] of balances) {
        this.metrics.totalLockedAmount.set(
          { token },
          this.convertToDecimal(balance.locked, 18)
        )

        this.metrics.totalClaimedAmount.set(
          { token },
          this.convertToDecimal(balance.claimed, 18)
        )

        if (
          this.state.isInitialSyncComplete &&
          currentBlockNumber >=
            balance.lastUpdatedBlock + this.options.bufferBlockCount &&
          balance.claimed.gt(balance.locked)
        ) {
          this.metrics.invariantViolations.set({ token, recipient }, 1)
          console.warn(`Invariant violation detected:`)
          console.warn(`  Token: ${token}`)
          console.warn(`  Recipient: ${recipient}`)
          console.warn(`  Locked: ${balance.locked.toString()}`)
          console.warn(`  Claimed: ${balance.claimed.toString()}`)
          console.warn(`  Last Updated Block: ${balance.lastUpdatedBlock}`)
          console.warn(`  Current Block: ${currentBlockNumber}`)
        } else {
          this.metrics.invariantViolations.set({ token, recipient }, 0)
        }
      }
    }
  }

  private logAllBalances(): void {
    console.log('Current state of all balances:')
    for (const [token, balances] of this.state.tokenBalances) {
      for (const [recipient, balance] of balances) {
        console.log(`Token: ${token}, Recipient: ${recipient}`)
        console.log(`  Locked: ${balance.locked.toString()}`)
        console.log(`  Claimed: ${balance.claimed.toString()}`)
        console.log(`  Last Updated Block: ${balance.lastUpdatedBlock}`)
      }
    }
  }

  async main(): Promise<void> {
    const latestBlock = await this.options.rpcProvider.getBlock('latest')

    const fromBlock = Math.min(
      this.state.lastProcessedBlockNumber + 1,
      latestBlock.number
    )

    if (fromBlock > latestBlock.number) {
      console.log(
        `No new blocks to process. Current: ${this.state.lastProcessedBlockNumber}, Latest: ${latestBlock.number}`
      )
      await this.updateMetrics(latestBlock.number)
      return sleep(this.options.sleepTimeMs)
    }

    console.log(`Processing blocks from ${fromBlock} to ${latestBlock.number}`)

    const lockupFilter = this.state.lockupProxy.filters.NewLockup()
    const newLockupEvents = await this.state.lockupProxy.queryFilter(
      lockupFilter,
      fromBlock,
      latestBlock.number
    )

    const claimFilter = this.state.lockupProxy.filters.LockupClaimed()
    const newClaimEvents = await this.state.lockupProxy.queryFilter(
      claimFilter,
      fromBlock,
      latestBlock.number
    )

    this.processEvents(newLockupEvents, newClaimEvents)

    this.state.lastProcessedBlockNumber = latestBlock.number

    await this.updateMetrics(latestBlock.number)

    console.log(
      `Processed ${newLockupEvents.length} new lockup events and ${newClaimEvents.length} new claim events up to block ${latestBlock.number}`
    )
    // this.logAllBalances()

    return sleep(this.options.sleepTimeMs)
  }
}

if (require.main === module) {
  const service = new LockupMonitor()
  service.run()
}
