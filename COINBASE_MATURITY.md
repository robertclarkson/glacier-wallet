# Coinbase Maturity Requirement

## What is a Coinbase Transaction?

A **coinbase transaction** is the first transaction in every block. It's how miners are rewarded with newly created bitcoin (the block subsidy) plus transaction fees. When you mine blocks in regtest mode using `bitcoin-cli generatetoaddress`, you're creating coinbase outputs.

## The 100 Confirmation Rule

Bitcoin protocol **requires 100 confirmations** before coinbase outputs can be spent. This is a consensus rule to protect against blockchain reorganizations.

### Why 100 Blocks?

1. **Chain Reorganization Protection**: If a longer chain appears, blocks can be "orphaned"
2. **Coinbase outputs could disappear** if their block gets orphaned
3. **100 blocks deep** is considered safe from reorganization
4. Regular transactions only need **1 confirmation** to spend

## Impact on Glacier Wallet

### Error Message
```
bad-txns-premature-spend-of-coinbase, tried to spend coinbase at depth 1
```

This error appears when you try to create a timelock transaction immediately after mining blocks.

### Solution

**Mine at least 100 blocks** before creating timelock transactions:

```bash
# Mine 101 blocks to your address
bitcoin-cli -regtest generatetoaddress 101 bcrt1q...

# Now the first block's coinbase output is spendable!
```

### In the Wallet

The app now automatically filters UTXOs:
- **Regular UTXOs**: Require 1 confirmation
- **All UTXOs on regtest**: Require 100 confirmations (for safety)

If you see "No spendable UTXOs available", you need to:
1. Check your current block height
2. Mine more blocks until you have ≥100 confirmations
3. Wait for the auto-refresh (10 seconds) or reconnect

## Regtest Quick Start

```bash
# Start with a fresh regtest
bitcoin-cli -regtest createwallet "glacier_watch"

# Mine 101 blocks to your wallet address
bitcoin-cli -regtest generatetoaddress 101 bcrt1qyour_address_here

# Now you can create timelocks!
```

## Production Considerations

In production/mainnet/testnet:
- You'd check `utxo['coinbase']` or `utxo['generated']` fields
- Only apply 100-conf rule to actual coinbase outputs
- Regular received transactions need only 1 confirmation
- The app could be more selective

For regtest simplicity, we require 100 confirmations for all outputs.
