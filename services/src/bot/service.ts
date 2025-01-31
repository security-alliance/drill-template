import {
  BaseServiceV2,
  StandardOptions,
  ExpressRouter,
  Gauge,
  validators,
  waitForProvider,
} from '@eth-optimism/common-ts'
import { sleep } from '@eth-optimism/core-utils'
import { Provider, Log } from '@ethersproject/abstract-provider'
import { BigNumber, Signer, Wallet, ethers, utils } from 'ethers'

import { version } from '../../package.json'

import { MockTokenAbi } from '../../lib/abi/MockTokenAbi'
import { LockupAbi } from '../../lib/abi/LockupAbi'
import { LockupExploitAbi } from '../../lib/abi/LockupExploitAbi'
import { LockupExploitBytecode } from '../../lib/abi/bytecode/LockupExploitBytecode'

type Options = {
  rpcProvider: Provider
  mnemonic: string
  faucetKey: string
  sleepTimeMs: number
  numBots: number
  lockupIndexingStartBlock: number
  minimumBotBalance: string
  faucetEthTxAmount: string
  faucetErc20TxAmount: string
  mockTokenAddress: string
  callbackTokenAddress: string
  lockupProxyAddress: string
  lockupPeriodSeconds: number
  exploitWaitTimeMs: number
  exploiterPrivateKey: string
}

type Metrics = {
  nodeConnectionFailures: Gauge
  faucetNativeBalance: Gauge
  nativeBalances: Gauge
  tokenBalances: Gauge
}

type Lockup = {
  id: number
  token: string
  recipient: string
  startTime: number
  amount: BigNumber
}

type Bot = {
  signer: Signer
  nativeBalance: BigNumber
  tokenBalance: Map<string, BigNumber>
  address: string
  nickname: string
  lockups: Map<number, Lockup>
  pendingLockupIds: Set<number>
  availableLockupIds: Set<number>
}

type Exploiter = Bot & {
  exploiterContract: ethers.Contract | null
}

type State = {
  bots: Bot[]
  exploiter: Exploiter
  faucetSigner: Signer
  mockToken: ethers.Contract
  callbackToken: ethers.Contract
  lockupProxy: ethers.Contract
  exploitStartTime: number
}

const MAX_UINT256 = BigNumber.from(2).pow(256).sub(1)

export class ERC20Bot extends BaseServiceV2<Options, Metrics, State> {
  constructor(options?: Partial<Options & StandardOptions>) {
    super({
      version,
      name: 'bot',
      loop: true,
      options: {
        loopIntervalMs: 1000,
        ...options,
      },
      optionsSpec: {
        rpcProvider: {
          validator: validators.provider,
          desc: 'Provider for interacting with the network',
        },
        mnemonic: {
          validator: validators.str,
          desc: 'Mnemonic for the account that will be used to send transactions',
        },
        faucetKey: {
          validator: validators.str,
          desc: 'Private key for the faucet account that will be used to send transactions',
        },
        mockTokenAddress: {
          validator: validators.address,
          desc: 'Address of the mock token',
        },
        callbackTokenAddress: {
          validator: validators.address,
          desc: 'Address of the callback token',
        },
        lockupProxyAddress: {
          validator: validators.address,
          desc: 'Address of the lockup proxy',
        },
        lockupPeriodSeconds: {
          validator: validators.num,
          default: 500,
          desc: 'Lockup period in seconds',
        },
        lockupIndexingStartBlock: {
          validator: validators.num,
          default: 0,
          desc: 'Block number to start indexing lockups from',
        },
        numBots: {
          validator: validators.num,
          default: 10,
          desc: 'Number of bots to run',
        },
        sleepTimeMs: {
          validator: validators.num,
          default: 15000,
          desc: 'Time in ms to sleep when waiting for a node',
          public: true,
        },
        minimumBotBalance: {
          validator: validators.str,
          default: '0.01',
          desc: 'Minimum balance of a bot',
        },
        faucetEthTxAmount: {
          validator: validators.str,
          default: '0.5',
          desc: 'Amount of ETH to request from the faucet',
        },
        faucetErc20TxAmount: {
          validator: validators.str,
          default: '100',
          desc: 'Amount of ERC20 to request from the faucet',
        },
        exploitWaitTimeMs: {
          validator: validators.num,
          default: 100000,
          // default: 3000,
          desc: 'Time in ms to wait before launching the exploit',
        },
        exploiterPrivateKey: {
          validator: validators.str,
          desc: 'Private key for the exploiter wallet',
        },
      },
      metricsSpec: {
        nodeConnectionFailures: {
          type: Gauge,
          desc: 'Number of times node connection has failed',
          labels: ['layer', 'section'],
        },
        faucetNativeBalance: {
          type: Gauge,
          desc: 'Faucet balance',
        },
        nativeBalances: {
          type: Gauge,
          desc: 'Balances of addresses',
          labels: ['address', 'nickname'],
        },
        tokenBalances: {
          type: Gauge,
          desc: 'Balances of addresses',
          labels: ['token', 'address', 'nickname'],
        },
      },
    })
  }

  private async deployExploiterContract(): Promise<void> {
    const LockupExploitFactory = new ethers.ContractFactory(
      LockupExploitAbi,
      LockupExploitBytecode,
      this.state.exploiter.signer
    )
    this.state.exploiter.exploiterContract = await LockupExploitFactory.deploy(
      this.state.exploiter.address
    )
    await this.state.exploiter.exploiterContract.deployed()
    console.log(
      `Exploiter contract deployed at ${this.state.exploiter.exploiterContract.address}`
    )
  }

  private async lockupTokensForExploit(amount: BigNumber): Promise<number> {
    if (!this.state.exploiter.exploiterContract) {
      throw new Error('Exploiter contract not deployed')
    }

    // Approve tokens
    const approveTx = await this.state.callbackToken
      .connect(this.state.exploiter.signer)
      .approve(this.state.lockupProxy.address, amount)
    await approveTx.wait()

    // Lockup tokens
    const lockupTx = await this.state.lockupProxy
      .connect(this.state.exploiter.signer)
      .lockup(
        this.state.callbackToken.address,
        this.state.exploiter.exploiterContract.address,
        amount
      )
    const receipt = await lockupTx.wait()

    // Find the NewLockup event to get the lockup ID
    const newLockupEvent = receipt.events.find((e) => e.event === 'NewLockup')
    const lockupId = newLockupEvent.args.l.id.toNumber()

    console.log(
      `Locked up ${amount.toString()} tokens for exploit with lockup ID ${lockupId}`
    )

    // Add the lockup to the exploiter's pending lockups
    this.state.exploiter.pendingLockupIds.add(lockupId)

    return lockupId
  }

  private async runExploit(lockupId: number): Promise<void> {
    if (!this.state.exploiter.exploiterContract) {
      throw new Error('Exploiter contract not deployed')
    }

    const exploitTx = await this.state.exploiter.exploiterContract
      .connect(this.state.exploiter.signer)
      .runExploit(
        this.state.callbackToken.address,
        this.state.lockupProxy.address,
        lockupId
      )
    await exploitTx.wait()
    console.log(`Exploit run for lockup ID ${lockupId}`)

    // Remove the lockup from the exploiter's pending lockups
    this.state.exploiter.lockups.delete(lockupId)
    this.state.exploiter.availableLockupIds.delete(lockupId)
  }

  private getRandomOtherBot(bot: Bot): Bot {
    return this.state.bots.filter((b) => b.address !== bot.address)[
      Math.floor(Math.random() * (this.state.bots.length - 1))
    ]
  }

  async init(): Promise<void> {
    // Connect to L1.
    await waitForProvider(this.options.rpcProvider, {
      logger: this.logger,
      name: 'L1',
    })

    this.state.faucetSigner = new Wallet(this.options.faucetKey).connect(
      this.options.rpcProvider
    )

    const faucetAddress = await this.state.faucetSigner.getAddress()
    console.log(`Initialized faucet signer ${faucetAddress}`)

    this.state.mockToken = new ethers.Contract(
      this.options.mockTokenAddress,
      MockTokenAbi,
      this.options.rpcProvider
    )

    this.state.callbackToken = new ethers.Contract(
      this.options.callbackTokenAddress,
      MockTokenAbi,
      this.options.rpcProvider
    )

    this.state.lockupProxy = new ethers.Contract(
      this.options.lockupProxyAddress,
      LockupAbi,
      this.options.rpcProvider
    )

    this.state.bots = []

    Array.from({ length: this.options.numBots }).forEach(async (_, i) => {
      const l1Signer = Wallet.fromMnemonic(
        this.options.mnemonic,
        `m/44'/60'/0'/0/${i}`
      ).connect(this.options.rpcProvider)
      this.state.bots.push({
        signer: l1Signer,
        address: l1Signer.address,
        nativeBalance: BigNumber.from(0),
        tokenBalance: new Map<string, BigNumber>([
          [this.state.mockToken.address, BigNumber.from(0)],
          [this.state.callbackToken.address, BigNumber.from(0)],
        ]),
        nickname: `L1-${i}`,
        lockups: new Map<number, Lockup>(),
        pendingLockupIds: new Set<number>(),
        availableLockupIds: new Set<number>(),
      })
      console.log(`Added signer ${l1Signer.address}`)
    })

    // Initialize exploiter
    const exploiterWallet = new Wallet(
      this.options.exploiterPrivateKey,
      this.options.rpcProvider
    )
    this.state.exploiter = {
      signer: exploiterWallet,
      address: exploiterWallet.address,
      nativeBalance: BigNumber.from(0),
      tokenBalance: new Map<string, BigNumber>([
        [this.state.mockToken.address, BigNumber.from(0)],
        [this.state.callbackToken.address, BigNumber.from(0)],
      ]),
      nickname: 'Exploiter',
      lockups: new Map<number, Lockup>(),
      pendingLockupIds: new Set<number>(),
      availableLockupIds: new Set<number>(),
      exploiterContract: null,
    }
    console.log(`Added exploiter signer ${this.state.exploiter.address}`)

    this.state.exploitStartTime = Date.now()

    await this.trackBotBalances(this.state.exploiter)
    await this.ensureMinimumBalances(this.state.exploiter)

    if (!this.state.exploiter.exploiterContract) {
      await this.deployExploiterContract()
    }
    console.log(
      `Exploiter contract deployed at ${this.state.exploiter.exploiterContract.address}`
    )

    await this.indexPreviousLockups()
  }

  // K8s healthcheck
  async routes(router: ExpressRouter): Promise<void> {
    router.get('/healthz', async (req, res) => {
      return res.status(200).json({
        ok: true,
      })
    })
  }

  private async indexPreviousLockups(): Promise<void> {
    const INDEXING_START_BLOCK = this.options.lockupIndexingStartBlock
    console.log(
      `Indexing previous lockups starting from block ${INDEXING_START_BLOCK}...`
    )
    const latestBlock = await this.options.rpcProvider.getBlock('latest')
    const filter = this.state.lockupProxy.filters.NewLockup()
    const events = await this.state.lockupProxy.queryFilter(
      filter,
      INDEXING_START_BLOCK,
      latestBlock.number
    )

    for (const event of events) {
      const lockupInfo = event.args.l
      const newLockup: Lockup = {
        id: lockupInfo.id.toNumber(),
        token: lockupInfo.token,
        recipient: lockupInfo.recipient,
        startTime: lockupInfo.startTime.toNumber(),
        amount: lockupInfo.amount,
      }
      // console.log(
      //   `New lockup created for ${newLockup.recipient}: ID ${newLockup.id} with startTime ${newLockup.startTime}`
      // )

      const recipientBot = this.state.bots.find(
        (bot) => bot.address.toLowerCase() === newLockup.recipient.toLowerCase()
      )
      if (recipientBot) {
        recipientBot.lockups.set(newLockup.id, newLockup)
        recipientBot.pendingLockupIds.add(newLockup.id)
        // console.log(
        //   `Indexed lockup ${newLockup.id} for ${recipientBot.address}`
        // )
      } else if (
        newLockup.recipient.toLowerCase() ===
        this.state.exploiter.address.toLowerCase()
      ) {
        this.state.exploiter.pendingLockupIds.add(newLockup.id)
      }
    }

    // Now check for claimed lockups
    const claimFilter = this.state.lockupProxy.filters.LockupClaimed()
    const claimEvents = await this.state.lockupProxy.queryFilter(
      claimFilter,
      INDEXING_START_BLOCK,
      latestBlock.number
    )

    for (const event of claimEvents) {
      const claimedLockupInfo = event.args.l
      const claimedId = claimedLockupInfo.id.toNumber()

      for (const bot of this.state.bots) {
        if (bot.lockups.has(claimedId)) {
          bot.lockups.delete(claimedId)
          bot.pendingLockupIds.delete(claimedId)
          // console.log(`Removed claimed lockup ${claimedId} for ${bot.address}`)
        }
      }
      if (this.state.exploiter.lockups.has(claimedId)) {
        this.state.exploiter.lockups.delete(claimedId)
        this.state.exploiter.pendingLockupIds.delete(claimedId)
      }
    }

    console.log('Finished indexing previous lockups')
  }

  private async ensureMinimumBalances(bot: Bot): Promise<void> {
    // Parse options
    const minimumBotBalance = utils.parseEther(this.options.minimumBotBalance)
    const faucetEthTxAmount = utils.parseEther(this.options.faucetEthTxAmount)
    const faucetERC20TxAmount = utils.parseEther(
      this.options.faucetErc20TxAmount
    )

    if (bot.nativeBalance.lt(minimumBotBalance)) {
      console.log(
        `signer ${bot.address} balance: ${bot.nativeBalance} < ${minimumBotBalance}`
      )
      const faucetEthTx = await this.state.faucetSigner.sendTransaction({
        to: bot.address,
        value: faucetEthTxAmount,
      })
      await faucetEthTx.wait()
    }

    if (
      bot.tokenBalance.get(this.state.mockToken.address).lt(faucetERC20TxAmount)
    ) {
      console.log(
        `signer ${bot.address} ERC20 balance: ${bot.tokenBalance.get(
          this.state.mockToken.address
        )} < ${faucetERC20TxAmount}`
      )
      const faucetERC20Tx = await this.state.faucetSigner.sendTransaction(
        await this.state.mockToken.populateTransaction.mint(
          bot.address,
          faucetERC20TxAmount
        )
      )
      await faucetERC20Tx.wait()
    }

    if (
      bot.tokenBalance
        .get(this.state.callbackToken.address)
        .lt(faucetERC20TxAmount)
    ) {
      console.log(
        `signer ${bot.address} ERC20 balance: ${bot.tokenBalance.get(
          this.state.callbackToken.address
        )} < ${faucetERC20TxAmount}`
      )
      const faucetERC20Tx = await this.state.faucetSigner.sendTransaction(
        await this.state.callbackToken.populateTransaction.mint(
          bot.address,
          faucetERC20TxAmount
        )
      )
      await faucetERC20Tx.wait()
    }
  }

  private async trackBotBalances(bot: Bot): Promise<void> {
    const nativeBalance = await bot.signer.getBalance()
    this.metrics.nativeBalances.set(
      { address: bot.address, nickname: bot.nickname },
      parseInt(nativeBalance.toString(), 10)
    )

    const mockTokenBalance = await this.state.mockToken.balanceOf(bot.address)
    this.metrics.tokenBalances.set(
      {
        token: this.state.mockToken.address,
        address: bot.address,
        nickname: bot.nickname,
      },
      parseInt(mockTokenBalance.toString(), 10)
    )

    const callbackTokenBalance = await this.state.callbackToken.balanceOf(
      bot.address
    )
    this.metrics.tokenBalances.set(
      {
        token: this.state.callbackToken.address,
        address: bot.address,
        nickname: bot.nickname,
      },
      parseInt(callbackTokenBalance.toString(), 10)
    )

    bot.nativeBalance = nativeBalance
    bot.tokenBalance.set(this.state.mockToken.address, mockTokenBalance)
    bot.tokenBalance.set(this.state.callbackToken.address, callbackTokenBalance)
  }

  private async trackLockupState(bot: Bot): Promise<void> {
    const lockupIds = Array.from(bot.pendingLockupIds)
    console.log(`Tracking ${lockupIds.length} lockups for ${bot.address}`)
    const latestBlock = await this.options.rpcProvider.getBlock('latest')
    const latestBlockTimestamp = latestBlock.timestamp

    console.log(`Latest block timestamp: ${latestBlockTimestamp}`)

    for (const id of lockupIds) {
      try {
        const lockup = await this.state.lockupProxy.lockups(id)
        const startTime = lockup.startTime.toNumber()
        const lockupEndTime = startTime + this.options.lockupPeriodSeconds

        if (latestBlockTimestamp >= lockupEndTime) {
          console.log(
            `Lockup ${id} is available (Current time: ${latestBlockTimestamp}, Lockup end: ${lockupEndTime})`
          )
          bot.availableLockupIds.add(id)
          bot.pendingLockupIds.delete(id)
        } else {
          console.log(
            `Lockup ${id} is not yet available (Current time: ${latestBlockTimestamp}, Lockup end: ${lockupEndTime})`
          )
          console.log(
            `Wait for ${lockupEndTime - latestBlockTimestamp} seconds...`
          )
        }
      } catch (error) {
        console.error(`Error fetching lockup ${id}:`, error)
      }
    }

    console.log(
      `Available lockups for ${bot.address}: ${Array.from(
        bot.availableLockupIds
      ).join(', ')}`
    )
    console.log(
      `Pending lockups for ${bot.address}: ${Array.from(
        bot.pendingLockupIds
      ).join(', ')}`
    )
  }

  private async trackFaucetBalances(): Promise<void> {
    const faucetNativeBalance = await this.state.faucetSigner.getBalance()
    console.log(`Faucet balance: ${faucetNativeBalance}`)
    this.metrics.faucetNativeBalance.set(
      parseInt(faucetNativeBalance.toString(), 10)
    )
  }

  private async approveMaxLockup(
    bot: Bot,
    token: ethers.Contract
  ): Promise<void> {
    console.log(
      `Approving max ${token.address} from ${bot.address} to ${this.state.lockupProxy.address}`
    )
    const approveTx = await bot.signer.sendTransaction(
      await token.populateTransaction.approve(
        this.state.lockupProxy.address,
        MAX_UINT256
      )
    )
    await approveTx.wait()
  }

  private async runApprovals(bot: Bot, token: ethers.Contract): Promise<void> {
    const approval = await token.allowance(
      bot.address,
      this.state.lockupProxy.address
    )
    if (approval.lt(MAX_UINT256)) {
      console.log(
        `Approving max ${token.address} from ${bot.address} to ${this.state.lockupProxy.address}`
      )
      await this.approveMaxLockup(bot, token)
    }
  }

  private async runErc20Transfers(
    bot: Bot,
    tokenAddress: string
  ): Promise<void> {
    const transferAmount = bot.tokenBalance.get(tokenAddress).div(3)
    const otherBot = this.getRandomOtherBot(bot)
    console.log(
      `Transferring ${utils.formatEther(transferAmount)} ERC20 from ${
        bot.address
      } to ${otherBot.address}`
    )
    const transferTx = await bot.signer.sendTransaction(
      await this.state.mockToken.populateTransaction.transfer(
        otherBot.address,
        transferAmount
      )
    )
    await transferTx.wait()
    console.log(
      `Transferred ${utils.formatEther(transferAmount)} ERC20 from ${
        bot.address
      } to ${otherBot.address}`
    )
  }

  private async runLockup(bot: Bot, tokenAddress: string): Promise<void> {
    const otherBot = this.getRandomOtherBot(bot)
    const numPendingLockups = otherBot.pendingLockupIds.size
    if (numPendingLockups > 2) {
      console.log(
        `Bot ${otherBot.address} already has ${numPendingLockups} pending lockups`
      )
      return
    }
    console.log(`Running lockup from ${bot.address} to ${otherBot.address}`)
    const lockupAmount = bot.tokenBalance.get(tokenAddress).div(2)
    const lockupTx = await bot.signer.sendTransaction(
      await this.state.lockupProxy.populateTransaction.lockup(
        tokenAddress,
        otherBot.address,
        lockupAmount
      )
    )
    const receipt = await lockupTx.wait()

    // Find the NewLockup event in the transaction logs
    const newLockupLog = receipt.logs.find((log: Log) => {
      try {
        const parsedLog = this.state.lockupProxy.interface.parseLog(log)
        return parsedLog.name === 'NewLockup'
      } catch {
        return false
      }
    })

    if (newLockupLog) {
      const parsedLog = this.state.lockupProxy.interface.parseLog(newLockupLog)
      const lockupInfo = parsedLog.args.l
      const newLockup: Lockup = {
        id: lockupInfo.id.toNumber(),
        token: lockupInfo.token,
        recipient: lockupInfo.recipient,
        startTime: lockupInfo.startTime.toNumber(),
        amount: lockupInfo.amount,
      }

      // Add the new lockup to otherBot's pending lockups
      otherBot.lockups.set(newLockup.id, newLockup)
      otherBot.pendingLockupIds.add(newLockup.id)

      console.log(
        `New lockup created for ${otherBot.address}: ID ${newLockup.id}`
      )
    } else {
      console.log('Failed to find NewLockup event in transaction receipt')
    }
  }

  private async redeemLockups(bot: Bot): Promise<void> {
    const lockupIds = bot.availableLockupIds
    if (lockupIds.size === 0) {
      console.log(`No lockups to redeem for ${bot.address}`)
      return
    }
    console.log(`Redeeming ${lockupIds.size} lockups for ${bot.address}`)
    const redeemTx = await bot.signer.sendTransaction(
      await this.state.lockupProxy.populateTransaction.claim(
        Array.from(lockupIds)
      )
    )
    await redeemTx.wait()
    // Delete the lockup from the bot's pending lockups
    for (const id of lockupIds) {
      bot.lockups.delete(id)
      bot.availableLockupIds.delete(id)
    }
  }

  async main(): Promise<void> {
    const currentTime = Date.now()
    if (
      currentTime - this.state.exploitStartTime >=
      this.options.exploitWaitTimeMs
    ) {
      console.log(
        'Exploit wait time has passed. Checking for exploitable lockups...'
      )
      await this.trackBotBalances(this.state.exploiter)
      await this.ensureMinimumBalances(this.state.exploiter)

      // Track lockup state for the exploiter
      await this.trackLockupState(this.state.exploiter)

      // Check if there are any available lockups for the exploiter
      if (this.state.exploiter.availableLockupIds.size > 0) {
        const availableLockupId = this.state.exploiter.availableLockupIds
          .values()
          .next().value
        console.log(`Running exploit for lockup ID: ${availableLockupId}`)
        await this.runExploit(availableLockupId)
      } else if (this.state.exploiter.pendingLockupIds.size < 2) {
        // If there are no available lockups and less than 2 pending, create a new lockup
        console.log(
          'No available lockups. Creating a new lockup for future exploit...'
        )
        const exploitAmount = this.state.exploiter.tokenBalance
          .get(this.state.callbackToken.address)
          .div(3)
        await this.lockupTokensForExploit(exploitAmount)
      } else {
        console.log(
          'Waiting for existing lockups to become available for exploit...'
        )
      }
    } else {
      console.log(
        `Waiting for exploit to start... (Current time: ${currentTime}, Exploit start time: ${
          this.state.exploitStartTime
        }, Additional Wait time: ${
          this.options.exploitWaitTimeMs -
          (currentTime - this.state.exploitStartTime)
        } ms)`
      )
    }

    // Parse options
    const minimumBotBalance = utils.parseEther(this.options.minimumBotBalance)

    await this.trackFaucetBalances()

    for (const bot of this.state.bots) {
      await this.trackBotBalances(bot)
      await this.trackLockupState(bot)
      console.log('Bot: ', bot.nickname)
      console.log('----------------------------------------------------')
      console.log('Address:    ', bot.address)
      console.log('ETH Balance:', utils.formatEther(bot.nativeBalance))
      console.log(
        'Mock Token Balance:',
        utils.formatEther(bot.tokenBalance.get(this.state.mockToken.address))
      )
      console.log(
        'Callback Token Balance:',
        utils.formatEther(
          bot.tokenBalance.get(this.state.callbackToken.address)
        )
      )
      await this.ensureMinimumBalances(bot)

      await this.runApprovals(bot, this.state.mockToken)
      await this.runApprovals(bot, this.state.callbackToken)

      if (
        bot.nativeBalance.gt(minimumBotBalance) &&
        bot.tokenBalance.get(this.state.mockToken.address).gt(minimumBotBalance)
      ) {
        await this.runErc20Transfers(bot, this.state.mockToken.address)
        await this.runLockup(bot, this.state.mockToken.address)
        await this.redeemLockups(bot)
      }
      if (
        bot.nativeBalance.gt(minimumBotBalance) &&
        bot.tokenBalance
          .get(this.state.callbackToken.address)
          .gt(minimumBotBalance)
      ) {
        await this.runErc20Transfers(bot, this.state.callbackToken.address)
        await this.runLockup(bot, this.state.callbackToken.address)
        await this.redeemLockups(bot)
      }
      console.log('----------------------------------------------------')
      console.log('----------------------------------------------------')
    }

    return sleep(this.options.sleepTimeMs)
  }
}

if (require.main === module) {
  const service = new ERC20Bot()
  service.run()
}
