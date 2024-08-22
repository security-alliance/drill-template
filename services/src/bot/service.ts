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
import { BigNumber, Signer, Wallet, ethers, utils } from 'ethers'

import { version } from '../../package.json'

import { Erc20TokenAbi } from './ERC20TokenAbi'

type Options = {
  rpcProvider: Provider
  mnemonic: string
  faucetKey: string
  sleepTimeMs: number
  numBots: number
  minimumBotBalance: string
  faucetEthTxAmount: string
  faucetErc20TxAmount: string
}

type Metrics = {
  nodeConnectionFailures: Gauge
  faucetL1Balance: Gauge
  faucetErc20Balance: Gauge
  nativeBalances: Gauge
  erc20Balances: Gauge
}

type Bot = {
  signer: Signer
  nativeBalance: BigNumber
  erc20Balance: BigNumber
  address: string
  nickname: string
}

type State = {
  bots: Bot[]
  faucetSigner: Signer
  erc20Token: ethers.Contract
}

const l1Erc20Address = '0x608ddcdf387c1638993dc0f45dfd2746b08b9b4a'


export class ERC20Bot extends BaseServiceV2<Options, Metrics, State> {
  constructor(options?: Partial<Options & StandardOptions>) {
    super({
      version,
      name: 'ERC20-bot',
      loop: true,
      options: {
        loopIntervalMs: 1000,
        ...options,
      },
      optionsSpec: {
        rpcProvider: {
          validator: validators.provider,
          desc: 'Provider for interacting with L1',
        },
        mnemonic: {
          validator: validators.str,
          desc: 'Mnemonic for the account that will be used to send transactions',
        },
        faucetKey: {
          validator: validators.str,
          desc: 'Private key for the faucet account that will be used to send transactions',
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
      },
      metricsSpec: {
        nodeConnectionFailures: {
          type: Gauge,
          desc: 'Number of times node connection has failed',
          labels: ['layer', 'section'],
        },
        faucetL1Balance: {
          type: Gauge,
          desc: 'Faucet L1 balance',
        },
        faucetErc20Balance: {
          type: Gauge,
          desc: 'Faucet ERC20 balance',
        },
        nativeBalances: {
          type: Gauge,
          desc: 'Balances of addresses',
          labels: ['address', 'nickname'],
        },
        erc20Balances: {
          type: Gauge,
          desc: 'Balances of addresses',
          labels: ['address', 'nickname'],
        },
      },
    })
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

    this.state.erc20Token = new ethers.Contract(
      l1Erc20Address,
      Erc20TokenAbi,
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
        erc20Balance: BigNumber.from(0),
        nickname: `L1-${i}`,
      })
      console.log(`Added L1 signer ${l1Signer.address}`)
    })
  }

  // K8s healthcheck
  async routes(router: ExpressRouter): Promise<void> {
    router.get('/healthz', async (req, res) => {
      return res.status(200).json({
        ok: true,
      })
    })
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
        `L1 signer ${bot.address} balance: ${bot.nativeBalance} < ${minimumBotBalance}`
      )
      const faucetEthTx = await this.state.faucetSigner.sendTransaction({
        to: bot.address,
        value: faucetEthTxAmount,
      })
      await faucetEthTx.wait()
    }

    if (bot.erc20Balance < faucetERC20TxAmount) {
      console.log(
        `L1 signer ${bot.address} ERC20 balance: ${bot.erc20Balance} < ${faucetERC20TxAmount}`
      )
      const faucetERC20Tx = await this.state.faucetSigner.sendTransaction(
        await this.state.erc20Token.populateTransaction.transfer(
          bot.address,
          faucetERC20TxAmount
        )
      )
      await faucetERC20Tx.wait()
    }
  }

  private async trackBotBalances(bot: Bot): Promise<void> {
    const l1Balance = await bot.signer.getBalance()
    this.metrics.nativeBalances.set(
      { address: bot.address, nickname: bot.nickname },
      parseInt(l1Balance.toString(), 10)
    )

    const erc20L1Balance = await this.state.erc20Token.balanceOf(bot.address)
    this.metrics.erc20Balances.set(
      { address: bot.address, nickname: bot.nickname },
      parseInt(erc20L1Balance.toString(), 10)
    )

    bot.nativeBalance = l1Balance
    bot.erc20Balance = erc20L1Balance
  }

  private async trackFaucetBalances(): Promise<void> {
    const faucetL1Balance = await this.state.faucetSigner.getBalance()
    console.log(`Faucet L1 balance: ${faucetL1Balance}`)
    const faucetAddress = await this.state.faucetSigner.getAddress()
    const faucetERC20Balance = await this.state.erc20Token.balanceOf(
      faucetAddress
    )
    this.metrics.faucetL1Balance.set(parseInt(faucetL1Balance.toString(), 10))
    this.metrics.faucetErc20Balance.set(
      parseInt(faucetERC20Balance.toString(), 10)
    )
    console.log(`Faucet ERC20 balance: ${faucetERC20Balance}`)
  }

  private async runErc20Transfers(bot: Bot): Promise<void> {
    const transferAmount = bot.erc20Balance.div(3)
    const otherBot = this.getRandomOtherBot(bot)
    console.log(
      `Transferring ${utils.formatEther(transferAmount)} ERC20 from ${
        bot.address
      } to ${otherBot.address}`
    )
    const transferTx = await bot.signer.sendTransaction(
      await this.state.erc20Token.populateTransaction.transfer(
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

  async main(): Promise<void> {
    // Parse options
    const minimumBotBalance = utils.parseEther(this.options.minimumBotBalance)

    await this.trackFaucetBalances()

    for (const bot of this.state.bots) {
      await this.trackBotBalances(bot)
      console.log('Bot: ', bot.nickname)
      console.log('----------------------------------------------------')
      console.log('Address:    ', bot.address)
      console.log('L1 ERC20 Balance:', utils.formatEther(bot.erc20Balance))
      console.log('L1 ETH Balance:', utils.formatEther(bot.nativeBalance))
      await this.ensureMinimumBalances(bot)

      if (
        bot.nativeBalance.gt(minimumBotBalance) &&
        bot.erc20Balance.gt(minimumBotBalance)
      ) {
        await this.runErc20Transfers(bot)
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
