import fs from 'fs'

import '@nomiclabs/hardhat-ethers'
import '@typechain/hardhat'
import 'dotenv/config'
import '@nomicfoundation/hardhat-foundry'
import 'hardhat-preprocessor'

import 'hardhat-gas-reporter'

import { task } from 'hardhat/config'

const defaultNetwork = 'localhost'

function getRemappings() {
    return fs
        .readFileSync('remappings.txt', 'utf8')
        .split('\n')
        .filter(Boolean) // remove empty lines
        .map((line) => line.trim().split('='))
}

function mnemonic() {
    try {
        return fs.readFileSync('./mnemonic.txt').toString().trim()
    } catch (e) {
        if (defaultNetwork !== 'localhost') {
            console.log('☢️ WARNING: No mnemonic file created for a deploy account. Try `yarn run generate` and then `yarn run account`.')
        }
    }
    return ''
}
const networks = {
    localhost: {
        url: 'http://localhost:8545',
        /*      
        notice no mnemonic here? it will just use account 0 of the hardhat node to deploy
        (you can put in a mnemonic here to set the deployer locally)
      
      */
    },
    rinkeby: {
        url: 'https://rinkeby.infura.io/v3/460f40a260564ac4a4f4b3fffb032dad', // <---- YOUR INFURA ID! (or it won't work)
        //    url: "https://speedy-nodes-nyc.moralis.io/XXXXXXXXXXXXXXXXXXXXXXX/eth/rinkeby", // <---- YOUR MORALIS ID! (not limited to infura)
        accounts: {
            mnemonic: mnemonic(),
        },
    },
    kovan: {
        url: 'https://kovan.infura.io/v3/460f40a260564ac4a4f4b3fffb032dad', // <---- YOUR INFURA ID! (or it won't work)
        //    url: "https://speedy-nodes-nyc.moralis.io/XXXXXXXXXXXXXXXXXXXXXXX/eth/kovan", // <---- YOUR MORALIS ID! (not limited to infura)
        accounts: {
            mnemonic: mnemonic(),
        },
    },
    mainnet: {
        url: 'https://mainnet.infura.io/v3/460f40a260564ac4a4f4b3fffb032dad', // <---- YOUR INFURA ID! (or it won't work)
        //      url: "https://speedy-nodes-nyc.moralis.io/XXXXXXXXXXXXXXXXXXXXXXXXX/eth/mainnet", // <---- YOUR MORALIS ID! (not limited to infura)
        // gasPrice: mainnetGwei * 1000000000,
        accounts: {
            mnemonic: mnemonic(),
        },
    },
    ropsten: {
        url: 'https://ropsten.infura.io/v3/460f40a260564ac4a4f4b3fffb032dad', // <---- YOUR INFURA ID! (or it won't work)
        //      url: "https://speedy-nodes-nyc.moralis.io/XXXXXXXXXXXXXXXXXXXXXXXXX/eth/ropsten",// <---- YOUR MORALIS ID! (not limited to infura)
        accounts: {
            mnemonic: mnemonic(),
        },
    },
    goerli: {
        url: 'https://goerli.infura.io/v3/460f40a260564ac4a4f4b3fffb032dad', // <---- YOUR INFURA ID! (or it won't work)
        //      url: "https://speedy-nodes-nyc.moralis.io/XXXXXXXXXXXXXXXXXXXXXXXXX/eth/goerli", // <---- YOUR MORALIS ID! (not limited to infura)
        accounts: {
            mnemonic: mnemonic(),
        },
    },
    xdai: {
        url: 'https://rpc.gnosischain.com/',
        gasPrice: 1000000000,
        accounts: {
            mnemonic: mnemonic(),
        },
    },
    fantom: {
        url: 'https://rpcapi.fantom.network',
        gasPrice: 1000000000,
        accounts: {
            mnemonic: mnemonic(),
        },
    },
    testnetFantom: {
        url: 'https://rpc.testnet.fantom.network',
        gasPrice: 1000000000,
        accounts: {
            mnemonic: mnemonic(),
        },
    },
    polygon: {
        url: 'https://polygon-rpc.com',
        // url: "https://speedy-nodes-nyc.moralis.io/XXXXXXXXXXXXXXXXXXXx/polygon/mainnet", // <---- YOUR MORALIS ID! (not limited to infura)
        gasPrice: 32000000000,
        accounts: {
            mnemonic: mnemonic(),
        },
    },
    mumbai: {
        url: 'https://rpc-mumbai.maticvigil.com',
        // url: "https://speedy-nodes-nyc.moralis.io/XXXXXXXXXXXXXXXXXXXXXXX/polygon/mumbai", // <---- YOUR MORALIS ID! (not limited to infura)
        gasPrice: 3200000000,
        accounts: {
            mnemonic: mnemonic(),
        },
    },
    matic: {
        url: 'https://rpc-mainnet.maticvigil.com/',
        // gasPrice: 450000000000,
        accounts: {
            mnemonic: mnemonic(),
        },
    },
    optimism: {
        url: 'https://mainnet.optimism.io',
        accounts: {
            mnemonic: mnemonic(),
        },
        companionNetworks: {
            l1: 'mainnet',
        },
    },
    kovanOptimism: {
        url: 'https://kovan.optimism.io',
        accounts: {
            mnemonic: mnemonic(),
        },
        companionNetworks: {
            l1: 'kovan',
        },
    },
    localOptimism: {
        url: 'http://localhost:8545',
        accounts: {
            mnemonic: mnemonic(),
        },
        companionNetworks: {
            l1: 'localOptimismL1',
        },
    },
    localOptimismL1: {
        url: 'http://localhost:9545',
        gasPrice: 0,
        accounts: {
            mnemonic: mnemonic(),
        },
        companionNetworks: {
            l2: 'localOptimism',
        },
    },
    localAvalanche: {
        url: 'http://localhost:9650/ext/bc/C/rpc',
        gasPrice: 225000000000,
        chainId: 43112,
        accounts: {
            mnemonic: mnemonic(),
        },
    },
    fujiAvalanche: {
        url: 'https://api.avax-test.network/ext/bc/C/rpc',
        gasPrice: 225000000000,
        chainId: 43113,
        accounts: {
            mnemonic: mnemonic(),
        },
    },
    mainnetAvalanche: {
        url: 'https://api.avax.network/ext/bc/C/rpc',
        gasPrice: 225000000000,
        chainId: 43114,
        accounts: {
            mnemonic: mnemonic(),
        },
    },
    testnetHarmony: {
        url: 'https://api.s0.b.hmny.io',
        gasPrice: 1000000000,
        chainId: 1666700000,
        accounts: {
            mnemonic: mnemonic(),
        },
    },
    mainnetHarmony: {
        url: 'https://api.harmony.one',
        gasPrice: 1000000000,
        chainId: 1666600000,
        accounts: {
            mnemonic: mnemonic(),
        },
    },
    moonbeam: {
        url: 'https://rpc.api.moonbeam.network',
        chainId: 1284,
        accounts: {
            mnemonic: mnemonic(),
        },
    },
    moonriver: {
        url: 'https://rpc.api.moonriver.moonbeam.network',
        chainId: 1285,
        accounts: {
            mnemonic: mnemonic(),
        },
    },
    moonbaseAlpha: {
        url: 'https://rpc.api.moonbase.moonbeam.network',
        chainId: 1287,
        accounts: {
            mnemonic: mnemonic(),
        },
    },
    moonbeamDevNode: {
        url: 'http://127.0.0.1:9933',
        chainId: 1281,
        accounts: {
            mnemonic: mnemonic(),
        },
    },
}

module.exports = {
    preprocess: {
        eachLine: () => ({
            transform: (line: string) => {
                if (line.match(/^\s*import /i)) {
                    for (const [from, to] of getRemappings()) {
                        if (line.includes(from)) {
                            line = line.replace(from, to)
                            break
                        }
                    }
                }
                return line
            },
        }),
    },
    paths: {
        sources: './src',
        tests: './test/ts',
        cache: './cache_hardhat',
        artifacts: './artifacts',
    },
    defaultNetwork,
    networks,
    /**
     * gas reporter configuration that let's you know
     * an estimate of gas for contract deployments and function calls
     * More here: https://hardhat.org/plugins/hardhat-gas-reporter.html
     */
    gasReporter: {
        currency: 'USD',
        coinmarketcap: process.env.COINMARKETCAP || null,
    },

    // if you want to deploy to a testnet, mainnet, or xdai, you will need to configure:
    // 1. An Infura key (or similar)
    // 2. A private key for the deployer
    // DON'T PUSH THESE HERE!!!
    // An `example.env` has been provided in the Hardhat root. Copy it and rename it `.env`
    // Follow the directions, and uncomment the network you wish to deploy to.

    solidity: {
        compilers: [
            {
                version: '0.8.17',
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
            {
                version: '0.8.15',
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
            {
                version: '0.8.10',
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
            {
                version: '0.8.7',
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
            {
                version: '0.6.12',
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
            {
                version: '0.4.24',
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
        ],
    },
    ovm: {
        solcVersion: '0.7.6',
    },
    namedAccounts: {
        deployer: {
            default: 0, // here this will by default take the first account as deployer
        },
    },
    // typechain: {
    //     outDir: 'typechain',
    //     target: 'ethers-v5',
    // },
}

const DEBUG = false

function debug(text: string) {
    if (DEBUG) {
        console.log(text)
    }
}

task('wallet', 'Create a wallet (pk) link', async (_, { ethers }) => {
    const randomWallet = ethers.Wallet.createRandom()
    const privateKey = randomWallet._signingKey().privateKey
    console.log('🔐 WALLET Generated as ' + randomWallet.address + '')
    console.log('🔗 http://localhost:3000/pk#' + privateKey)
})

task('generate', 'Create a mnemonic for builder deploys', async (_, { ethers }) => {
    const bip39 = require('bip39')
    const hdkey = require('ethereumjs-wallet/hdkey')
    const mnemonic = bip39.generateMnemonic()
    if (DEBUG) console.log('mnemonic', mnemonic)
    const seed = await bip39.mnemonicToSeed(mnemonic)
    if (DEBUG) console.log('seed', seed)
    const hdwallet = hdkey.fromMasterSeed(seed)
    const wallet_hdpath = "m/44'/60'/0'/0/"
    const account_index = 0
    const fullPath = wallet_hdpath + account_index
    if (DEBUG) console.log('fullPath', fullPath)
    const wallet = hdwallet.derivePath(fullPath).getWallet()
    const privateKey = '0x' + wallet._privKey.toString('hex')
    if (DEBUG) console.log('privateKey', privateKey)
    const EthUtil = require('ethereumjs-util')
    const address = '0x' + EthUtil.privateToAddress(wallet._privKey).toString('hex')
    console.log('🔐 Account Generated as ' + address + ' and set as mnemonic in packages/hardhat')
    console.log("💬 Use 'yarn run account' to get more information about the deployment account.")

    fs.writeFileSync('./' + address + '.txt', mnemonic.toString())
    fs.writeFileSync('./mnemonic.txt', mnemonic.toString())
})

task('accounts', 'Prints the list of accounts', async (_, { ethers }) => {
    const accounts = await ethers.provider.listAccounts()
    accounts.forEach((account) => console.log(account))
})

task('blockNumber', 'Prints the block number', async (_, { ethers }) => {
    const blockNumber = await ethers.provider.getBlockNumber()
    console.log(blockNumber)
})
