"""
MEV Sandwich Bot — Uniswap V2 Arbitrum (Template)
Adapt RPC, router, tokens for target chain.
Requires: web3, eth-account (pip install web3 eth-account)
Usage: PK=<private_key> python3 sniper.py
"""
import asyncio
import json
import os
import time
from web3 import Web3
from web3.middleware import ExtraDataToPOAMiddleware
from eth_account import Account

# === CONFIG — ADAPT PER CHAIN ===
RPC_URL = os.getenv("RPC_URL", "https://arb1.arbitrum.io/rpc")
PRIVATE_KEY = os.getenv("PK")
PROFIT_WALLET = "0xYOUR_WALLET"
UNISWAP_V2_ROUTER = "0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24"
WETH = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1"
USDC = "0xaf88d065e77c8cC2239327C5EDb3A432268e5831"

# === V2 ROUTER ABI (minimal) ===
V2_ABI = json.loads('''[
    {"name":"swapExactETHForTokens","type":"function","stateMutability":"payable","inputs":[{"type":"uint256","name":"amountOutMin"},{"type":"address[]","name":"path"},{"type":"address","name":"to"},{"type":"uint256","name":"deadline"}],"outputs":[{"type":"uint256[]"}]},
    {"name":"swapExactTokensForETH","type":"function","inputs":[{"type":"uint256","name":"amountIn"},{"type":"uint256","name":"amountOutMin"},{"type":"address[]","name":"path"},{"type":"address","name":"to"},{"type":"uint256","name":"deadline"}],"outputs":[{"type":"uint256[]"}]},
    {"name":"getAmountsOut","type":"function","stateMutability":"view","inputs":[{"type":"uint256","name":"amountIn"},{"type":"address[]","name":"path"}],"outputs":[{"type":"uint256[]"}]}
]''')

ERC20_ABI = json.loads('''[
    {"name":"balanceOf","type":"function","stateMutability":"view","inputs":[{"type":"address"}],"outputs":[{"type":"uint256"}]},
    {"name":"approve","type":"function","inputs":[{"type":"address","name":"spender"},{"type":"uint256","name":"amount"}],"outputs":[{"type":"bool"}]},
    {"name":"allowance","type":"function","stateMutability":"view","inputs":[{"type":"address","name":"owner"},{"type":"address","name":"spender"}],"outputs":[{"type":"uint256"}]}
]''')


def get_w3():
    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    return w3


class SandwichBot:
    def __init__(self):
        self.w3 = get_w3()
        self.account = Account.from_key(PRIVATE_KEY)
        self.router = self.w3.eth.contract(address=Web3.to_checksum_address(UNISWAP_V2_ROUTER), abi=V2_ABI)
        self.min_profit_usd = 10
        self.max_gas_gwei = 0.03  # Arbitrum L2 cheap gas

    def get_eth_balance(self):
        return self.w3.eth.get_balance(self.account.address)

    def calc_sandwich(self, victim_tx):
        """Parse victim swap, calculate sandwich profitability."""
        try:
            tx_data = victim_tx.get("input", "0x")
            if not tx_data or tx_data == "0x":
                return None
            to_addr = victim_tx.get("to", "")
            value = int(victim_tx.get("value", "0"), 16)
            if to_addr.lower() != UNISWAP_V2_ROUTER.lower():
                return None

            selector = tx_data[:10]
            if selector == "0x7ff36ab5":  # swapExactETHForTokens
                decoded = self.router.decode_function_input(tx_data)
                params = decoded[1]
                path = params["path"]
                eth_in = value
                if len(path) < 2:
                    return None
                token = path[-1]
                front_amount = int(eth_in * 0.3)
                if front_amount < self.w3.to_wei(0.001, "ether"):
                    return None

                front_path = [WETH, token]
                back_path = [token, WETH]
                front_out = self.router.functions.getAmountsOut(front_amount, front_path).call()
                tokens_bought = front_out[-1]
                back_out = self.router.functions.getAmountsOut(tokens_bought, back_path).call()
                eth_returned = back_out[-1]
                profit_wei = eth_returned - front_amount
                if profit_wei <= 0:
                    return None
                gas_cost = self.w3.to_wei(0.003, "ether")
                net = profit_wei - gas_cost
                net_usd = float(self.w3.from_wei(net, "ether")) * 1765.0
                if net_usd < self.min_profit_usd:
                    return None
                return {
                    "victim_hash": victim_tx["hash"].hex(),
                    "token": token,
                    "front_amount_wei": front_amount,
                    "tokens_bought": tokens_bought,
                    "eth_returned": eth_returned,
                    "profit_wei": profit_wei,
                    "net_profit_usd": net_usd,
                    "path_front": front_path,
                    "path_back": back_path,
                }
            return None
        except Exception:
            return None

    async def run_forever(self):
        print(f"[*] Bot started. Wallet: {self.account.address}")
        print(f"[*] Profit → {PROFIT_WALLET}")
        processed = set()
        while True:
            try:
                gas_gwei = float(self.w3.from_wei(self.w3.eth.gas_price, "gwei"))
                if gas_gwei > self.max_gas_gwei:
                    await asyncio.sleep(5)
                    continue

                block = self.w3.eth.get_block("pending", full_transactions=True)
                txs = block.get("transactions", [])
                for tx in txs:
                    tx_hash = tx["hash"].hex()
                    if tx_hash in processed:
                        continue
                    opp = self.calc_sandwich(tx)
                    if opp:
                        print(f"[+] OPP: {opp['victim_hash'][:16]}... profit=${opp['net_profit_usd']:.2f}")
                        # Build + send frontrun/backrun here
                        processed.add(tx_hash)
                        break
                await asyncio.sleep(2)
            except Exception as e:
                print(f"[!] Error: {e}")
                await asyncio.sleep(3)


if __name__ == "__main__":
    asyncio.run(SandwichBot().run_forever())
