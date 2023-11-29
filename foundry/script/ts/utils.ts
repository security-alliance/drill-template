import axios from 'axios'
import { ethers } from 'ethers'

export interface EtherscanSourceCodeResult {
    SourceCode: string
    ABI: string
    ContractName: string
    CompilerVersion: string
    OptimizationUsed: string
    Runs: string
    ConstructorArguments: string
    EVMVersion: string
    Library: string
    LicenseType: string
    Proxy: string
    Implementation: string
    SwarmSource: string
}

export interface EtherscanSourceCodeResponse {
    status: string
    message: string
    result: EtherscanSourceCodeResult[]
}

export class EtherscanApi {
    private url: string
    private apikey: string
    private provider: ethers.providers.JsonRpcProvider
    private networkUrls: { [key: string]: string } = {
        MAINNET: 'https://api.etherscan.io',
        POLYGON: 'https://api.polygonscan.com',
    }
    constructor(network: string, apikey: string, provider: ethers.providers.JsonRpcProvider) {
        if (!this.networkUrls[network]) throw new Error(`Invalid network ${network}`)
        this.url = this.networkUrls[network]
        this.apikey = apikey
        this.provider = provider
    }
    async getSourceCode(address: string): Promise<EtherscanSourceCodeResult> {
        const url = `${this.url}/api?module=contract&action=getsourcecode&address=${address}&apikey=${this.apikey}`
        const res = await axios.get(url)
        const data = res.data as EtherscanSourceCodeResponse
        if (!(data.status === '1')) throw new Error(`Failed to get code for ${address}`)
        return data.result[0]
    }

    async getDeploymentBlock(address: string): Promise<number | undefined> {
        const url = `${this.url}/api?module=contract&action=getcontractcreation&contractaddresses=${address}&apikey=${this.apikey}`
        const res = await axios.get(url)
        if (!(res?.data.status === '1')) throw new Error(`Failed for ${address}`)
        const deploymentTx = res.data.result[0].txHash
        console.log({ deploymentTx })

        const tx = await this.provider.getTransaction(deploymentTx)
        const deploymentBlock = tx.blockNumber
        return deploymentBlock
    }
}

export async function getSourceCode(apikey: string, address: string): Promise<EtherscanSourceCodeResult> {
    const url = `https://api.etherscan.io/api?module=contract&action=getsourcecode&address=${address}&apikey=${apikey}`
    const res = await axios.get(url)
    const data = res.data as EtherscanSourceCodeResponse
    if (!(data.status === '1')) throw new Error(`Failed to get code for ${address}`)
    return data.result[0]
}

export async function getDeploymentBlock(provider: ethers.providers.JsonRpcProvider, apikey: string, address: string): Promise<number | undefined> {
    const url = `https://api.etherscan.io/api?module=contract&action=getcontractcreation&contractaddresses=${address}&apikey=${apikey}`
    const res = await axios.get(url)
    if (!(res?.data.status === '1')) throw new Error(`Failed for ${address}`)
    const deploymentTx = res.data.result[0].txHash
    console.log({ deploymentTx })

    const tx = await provider.getTransaction(deploymentTx)
    const deploymentBlock = tx.blockNumber
    return deploymentBlock
}
export interface SafeStatusResponse {
    address: string
    nonce: number
    threshold: number
    owners: string[]
    masterCopy: string
    modules: any[]
    fallbackHandler: string
    guard: string
    version: string
}

export class SafeApi {
    private url: string
    private networkUrls: { [key: string]: string } = {
        MAINNET: 'https://safe-transaction-mainnet.safe.global',
        POLYGON: 'https://safe-transaction-polygon.safe.global',
    }
    constructor(network: string) {
        if (!this.networkUrls[network]) throw new Error(`Invalid network ${network}`)
        this.url = this.networkUrls[network]
    }

    async status(address: string) {
        const url = `${this.url}/api/v1/safes/${address}/`
        const res = await axios.get(url)
        // console.log({res})
        if (res.status !== 200) throw new Error(`Failed for ${address}`)
        return res.data as SafeStatusResponse
    }
}
