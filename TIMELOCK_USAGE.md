# Time-Locked Transactions Usage Guide

## Overview
The wallet now supports creating time-locked transactions using Bitcoin's CHECKTIMELOCKVERIFY (OP_CLTV) opcode. Funds are sent to a P2SH address and can only be spent after the specified time/block height.

## How It Works

### Creating a Time-Lock

1. **Navigate to "Create Time-Lock"** from the home screen
2. **Enter Amount** - Specify how many BTC to lock
3. **Choose Lock Type**:
   - **Date/Time**: Lock until a specific calendar date/time
   - **Block Height**: Lock until a specific block number is reached
4. **Set Unlock Condition**:
   - For Date/Time: Use the date and time pickers
   - For Block Height: Enter the target block number
5. **Click "Create Time-Lock Transaction"**

### What Happens

When you create a time-lock:

1. ✅ **Funds are sent** to a special P2SH address
2. ✅ **Transaction is broadcast** to the Bitcoin network
3. ✅ **Balance is updated** immediately
4. ✅ **Timelock is tracked** in the home screen

The recipient address is **NOT** specified during creation - you'll choose it later when unlocking!

### Two Lock Types

#### 1. Date/Time Lock (Timestamp)
- Uses Unix timestamp (must be ≥ 500,000,000)
- Example: Lock until October 5, 2025 14:30
- Good for: Calendar-based time locks

#### 2. Block Height Lock
- Uses block number (must be < 500,000,000)
- Example: Lock until block 5000
- Good for: Deterministic locks independent of real-world time

## Current Status

### Implemented ✅
- ✅ Create time-locked P2SH addresses
- ✅ Send funds to timelock addresses
- ✅ Broadcast funding transactions
- ✅ Track locked funds
- ✅ Display lock status (locked/unlocked)
- ✅ Show time remaining or blocks remaining
- ✅ Support both DateTime and Block Height modes

### To Be Implemented 🔨
- 🔨 Unlock/spend time-locked funds
- 🔨 Specify recipient when unlocking
- 🔨 Create spending transaction with CLTV script witness
- 🔨 Validate unlock time has passed before broadcasting

## Technical Details

### P2SH Address Generation

The timelock address is a Pay-to-Script-Hash (P2SH) address containing:

```
<lockTime> OP_CHECKTIMELOCKVERIFY OP_DROP 
OP_DUP OP_HASH160 <pubKeyHash> OP_EQUALVERIFY OP_CHECKSIG
```

### Funding Transaction

The funding transaction is a standard Bitcoin transaction:
- **Inputs**: Your regular UTXOs
- **Outputs**: 
  - Timelock P2SH address (locked amount)
  - Change address (if any)

This transaction is immediately broadcast and confirmed.

### Unlocking Transaction (Future)

To spend the locked funds, you'll need to:
1. Create a transaction spending from the timelock address
2. Set nLockTime to the unlock time/block height
3. Provide the redeem script in the witness
4. Sign with your private key
5. Broadcast after the lock time has passed

## Example Usage

### Lock 1 BTC for 1 Hour
```
1. Amount: 1.0 BTC
2. Lock Type: Date/Time
3. Unlock: Current time + 1 hour
4. Create → Funds sent to P2SH address
5. Wait 1 hour
6. Unlock (future feature) → Specify recipient and spend
```

### Lock 0.5 BTC for 100 Blocks
```
1. Amount: 0.5 BTC
2. Lock Type: Block Height
3. Unlock Block: Current block + 100
4. Create → Funds sent to P2SH address
5. Mine/wait for 100 blocks
6. Unlock (future feature) → Specify recipient and spend
```

## Security Notes

- ⚠️ **Private key required**: You must have the wallet's private key to unlock
- ⚠️ **Testnet/Regtest only**: This is demo code for testing
- ⚠️ **Simplified crypto**: Uses simplified ECDSA (not production-ready)
- ⚠️ **No backup of timelocks**: Timelocks are stored in-memory only

## Regtest Testing

To test on regtest:

```bash
# Start Bitcoin Core in regtest mode
bitcoind -regtest -daemon

# Create initial wallet in Bitcoin Core
bitcoin-cli -regtest createwallet "glacier_watch" true

# Generate blocks to your wallet address
bitcoin-cli -regtest generatetoaddress 101 <your_address>

# Create a timelock for block +10
# (Lock 0.1 BTC until current_block + 10)

# Mine blocks to mature the funding tx
bitcoin-cli -regtest generatetoaddress 1 <any_address>

# Mine 10 more blocks to unlock
bitcoin-cli -regtest generatetoaddress 10 <any_address>

# Now the funds can be unlocked!
```

## Next Steps

The next feature to implement is **unlocking time-locked funds**:

1. Detect unlocked timelocks
2. Show "Unlock" button for eligible locks
3. Allow user to specify recipient address
4. Create spending transaction with:
   - Input from timelock UTXO
   - nLockTime set to unlock time/block
   - Redeem script in witness
5. Sign and broadcast

This will complete the full CHECKTIMELOCKVERIFY workflow! 🚀
