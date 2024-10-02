import os
import json
import time
from datetime import datetime
from ape import chain, networks, accounts, Contract
from ape.api import BlockAPI
from ape.types import ContractLog
from ape_uniswap import uniswap
from eth_utils import to_checksum_address
from typing import Optional

from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.interval import IntervalTrigger
from telegram.ext import Application

import textwrap


from silverback import CircuitBreaker, SilverbackApp
import requests


# Do this to initialize your app
app = SilverbackApp()

scheduler = BackgroundScheduler()
scheduler.start()


TELEGRAM_TOKEN = os.getenv('TELEGRAM_TOKEN')
TELEGRAM_CHAT_ID = os.getenv('TELEGRAM_CHAT_ID')
TENDERLY_JWT = os.getenv('TENDERLY_JWT')
TENDERLY_PROJECT_ID = os.getenv('TENDERLY_PROJECT_ID')

USDC_ADDRESS = to_checksum_address("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48")
USDT_ADDRESS = to_checksum_address("0xdac17f958d2ee523a2206206994597c13d831ec7")
WETH_ADDRESS = to_checksum_address("0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2")


UNI_UR = "0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD"
UNI_PERMIT2 = "0x000000000022D473030F116dDEE9F6B43aC78BA3"

UNI_USDC_WETH_POOL = "0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640"
UNI_WETH_USDT_POOL = "0x11b815efb8f581194ae79006d24e0d814b7697f6"

uni_usdc_weth_pool = Contract(
    to_checksum_address(UNI_USDC_WETH_POOL), abi='abis/univ3pool.json')

uni_weth_usdt_pool = Contract(
    to_checksum_address(UNI_WETH_USDT_POOL), abi='abis/univ3pool.json')


WETH = Contract(
    WETH_ADDRESS, abi='abis/weth.json'
)

permit2 = Contract(UNI_PERMIT2, abi='abis/permit2.json')

maxUint256 = '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'
maxUint160 = '0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF'
maxUint48 = '0xFFFFFFFFFFFF'


global_state = {}

@app.on_startup()
async def startup(state):
    # Set up notifications
    if (TELEGRAM_TOKEN is None or TELEGRAM_CHAT_ID is None):
        raise CircuitBreaker("Telegram token or chat id not set")

    tg = Application.builder().token(TELEGRAM_TOKEN).build()
    global_state['tg'] = tg
    refresh_ccs()

    await tg.bot.send_message(
        chat_id=TELEGRAM_CHAT_ID, text="🦍 Ape started!")

    await tg.bot.send_message(
        chat_id=TELEGRAM_CHAT_ID, text="🤖 ...configuring...")

    global_state['executing'] = True
    ecosystem_name = networks.provider.network.ecosystem.name
    chain_id = networks.provider.network.chain_id
    network_name = networks.provider.network.name
    provider_name = networks.provider.name
    print(
        f"You are connected to network '{ecosystem_name}:{chain_id}:{network_name}:{provider_name}'.")

    provider = networks.provider
    global_state['provider'] = provider

    current_time = int(time.time())
    print(f"Setting Current time: {current_time}")

    provider.set_timestamp(current_time)

    print(f"Provider gas price: {provider.gas_price}")

    await tg.bot.send_message(
        chat_id=TELEGRAM_CHAT_ID, text="✅ Ready!")
    global_state['executing'] = False
    global_state['last_execution'] = current_time
    scheduler.add_job(mine_blocks, IntervalTrigger(seconds=5), max_instances=2)
    return {"message": "Starting..."}


@app.on_(chain.blocks)
def exec_block(block: BlockAPI):
    if block.number % 5 == 0:
        print(f"Block number: {block.number}")


@app.on_shutdown()
def shutdown(state):
    scheduler.remove_all_jobs()
    return {"message": "Stopping..."}


# Configuration Functions

def mine_blocks():
    current_time = int(time.time())
    last_refresh = global_state.get('last_ccs_refresh', 0)
    if (current_time - last_refresh > 20):
        if (not global_state.get('refreshing', False)):
            print("Refreshing CCS")
            global_state['refreshing'] = True
            refresh_ccs()
            global_state['last_ccs_refresh'] = current_time
            global_state['refreshing'] = False
        else:
            print("Already refreshing")

    if (global_state['executing']):
        print("Already executing")
        return
    else:
        cooldown_time = global_state.get('cooldown_time', 5)
        last_execution = global_state.get('last_execution', 0)
        if (current_time - last_execution < cooldown_time):
            print("Execution cooldown")
            return

        execute_transaction()


def refresh_ccs():
    print("Reading CCS")
    try:
        with open('ccs.json', 'r') as file:
            data = json.load(file)
            if (data.get('interrupt', False)):
                raise CircuitBreaker("CCS Interrupted")

            global_state['ccs'] = data
    except Exception as e:
        print("Error occurred while reading 'ccs.json': ", e)
        raise CircuitBreaker("CCS Error")




def format_token(amount: int, decimals: int):
    amount_in_units = amount / 10 ** decimals
    if amount_in_units >= 1000:
        return escape_markdown_v2(f"{amount_in_units:.0f}")
    else:
        return escape_markdown_v2(f"{amount_in_units:.4f}")

        
async def deliver_summary_message(alert_queue):
    if not alert_queue:
        return

    # Group alerts by category
    alerts_by_category = {}
    for alert in alert_queue:
        category = alert['category']
        if category not in alerts_by_category:
            alerts_by_category[category] = []
        alerts_by_category[category].append(alert)

    # Build summary message
    timestamp = datetime.utcnow().strftime('%B %d, %H:%M UTC')
    summary_message = f"📋 New Alert Summary \\| Generated on {timestamp}\n\n"
    for category, alerts in alerts_by_category.items():
        summary_message += f"{category}: {len(alerts)} alerts\n"
        for alert in alerts:
            summary_message += f"{alert['short_message']}"
            if alert['explorer_url']:
                summary_message += f", [Debug Transaction]({alert['explorer_url']})"
            summary_message += "\n"
        summary_message += "\n"  # Add a newline to separate categories
        
    summary_message += f"\n{divider()}\n"

    # Send summary message
    await send_tg_message(summary_message)

    # Clear the alert queue

async def send_or_queue_alert(message: str, category: str, short_message: str, explorer_url: str = None):
    if (not global_state.get('enable_alert_queue', False)):
        await send_tg_message(message)
        return

    alert_queue = global_state.get('alert_queue', [])
    alert_queue.append({'message': message, 'short_message': short_message, 'category': category, 'explorer_url': explorer_url})
    global_state['alert_queue'] = alert_queue
    last_alert = global_state.get('last_alert', 0)
    alert_queue_time = global_state.get('alert_queue_time', 30)
    
    current_time = int(time.time())
    if current_time - last_alert >= alert_queue_time:
        global_state['last_alert'] = current_time
        queued_alerts = alert_queue.copy()
        global_state['alert_queue'] = []
        await deliver_summary_message(queued_alerts)


async def report_swap(log: ContractLog, symbol1: str, symbol2: str, decimals1: int, decimals2: int):
    provider = global_state['provider']

    txn = log.transaction_hash
    amount_0 = log.get("amount0")
    amount_1 = log.get("amount1")
    sender = log.get("sender")
    recipient = log.get("recipient")

    receipt = provider.get_receipt(txn)

    explorer_url = None
    if (global_state.get('ccs', {}).get('enable_tenderly_links', False)):
        tx_id = get_transaction_id(txn, TENDERLY_PROJECT_ID, TENDERLY_JWT)
        explorer_url = get_tenderly_url(
            tx_id, TENDERLY_PROJECT_ID) if tx_id else None


    report = textwrap.dedent(f"""
    {divider()}
    🔁 Swap detected {symbol1} for {symbol2}
    {format_token(amount_0, decimals1)} for {format_token(amount_1 * -1, decimals2)}
    Sender: {sender}
    Recipient: {recipient}
    {f'[Debug Transaction]({explorer_url})' if explorer_url else ''}
    {divider()}""")
    print(report)
    short_message = f"🔁 Swap detected {symbol1} for {symbol2}"
    await send_or_queue_alert(report, 'Uniswap V3 Swap', short_message, explorer_url)


@app.on_(uni_usdc_weth_pool.Swap)
async def report_swap_weth_usdc(log: ContractLog):
    if (not global_state.get('report_swap_usdc', True)):
        return
    await report_swap(log, "USDC", "WETH", 6, 18)

def execute_transaction():
    provider = global_state['provider']
    min_eth_balance = provider.conversion_manager.convert("1 ETH", int)
    target_swap = provider.conversion_manager.convert("0.5 ETH", int)
    account = accounts['0x1100000000000000000000000000000000000011']
    # Add buffer for debt block calculation
    ensure_min_eth_balance(
        provider, account.address, min_eth_balance + target_swap)
    WETH.deposit(value=target_swap, sender=account)

    WETH.deposit(value=target_swap, sender=account)
    WETH.approve(UNI_UR, maxUint256, sender=account)
    permit2.approve(WETH.address, UNI_UR, maxUint160,
                    maxUint48, sender=account)
    WETH.approve(UNI_PERMIT2, maxUint256, sender=account)
    uniswap.execute_v3_swap_exact_in_simple(
        target_swap,
        0,
        WETH.address,
        USDC_ADDRESS,
        500,
        sender=account
    )

def get_account_balance(provider, address):
    balance = provider.get_balance(address)
    print(f"Account ETH balance: {balance}")
    return balance


def ensure_min_eth_balance(provider, address: str, min_eth_balance: Optional[int] = None) -> int:
    if not min_eth_balance:
        min_eth_balance = provider.conversion_manager.convert("1 ETH", int)


    account_balance = get_account_balance(provider, address)
    if account_balance < min_eth_balance:
        provider.set_balance(address, min_eth_balance)

    account_balance = get_account_balance(provider, address)
    return account_balance




# Notification Utils
async def send_tg_message(message):
    if (not global_state.get('enable_telegram', True)):
        return
    tg = global_state['tg']
    # escaped_message = escape_markdown_v2(message)
    await tg.bot.send_message(
        chat_id=TELEGRAM_CHAT_ID, text=message, parse_mode="MarkdownV2")


def escape_markdown_v2(text):
    escape_chars = r'\*_[]()~`>#+-=|{}.!'
    return ''.join('\\' + char if char in escape_chars else char for char in text)


def format_percent(amount):
    return escape_markdown_v2(f"{amount:.2f}%")


def format_eth(amount):
    return escape_markdown_v2(f"{amount / 10**18:.4f}")


def divider():
    return '\-' * 20


def get_recent_transactions(project_id: str, jwt: str):
    if 'transactions' not in global_state:
        global_state['transactions'] = {}

    url = f"TENDERLY_URL"

    headers = {
        "Accept": "application/json",
        "Authorization": f"Bearer {jwt}"
    }

    response = requests.get(url, headers=headers)

    # The response of the GET request is stored in the .json() method
    data = response.json()

    # Iterate over the transactions and store the ID and hash in the global variable
    for transaction in data.get('fork_transactions', []):
        global_state['transactions'][transaction['hash']] = transaction['id']


def get_transaction_id(hash: str, project_id: str, jwt: str):
    # Try to get the transaction ID from the global variable
    transaction_id = global_state.get('transactions', {}).get(hash)

    # If the transaction ID is not found in the global variable
    if transaction_id is None:
        # Call get_recent_transactions to refresh the global variable
        get_recent_transactions(project_id, jwt)

        # Try to get the transaction ID again
        transaction_id = global_state.get('transactions', {}).get(hash)

    return transaction_id


def get_tenderly_url(id: str, project_id: str):
    return f"https://dashboard.tenderly.co/[projectname]/testnet/{project_id}/tx/mainnet/{id}"
