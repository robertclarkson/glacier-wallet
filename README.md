# Glacier Bitcoin Wallet - CHECKTIMELOCKVERIFY Demo

A Flutter-based Bitcoin wallet that demonstrates the use of CHECKTIMELOCKVERIFY (OP_CLTV) to create time-locked transactions on Bitcoin's regtest network.

## Overview

This wallet allows you to:
- Generate Bitcoin wallets
- Connect to a local Bitcoin Core regtest node
- Create time-locked transactions using CHECKTIMELOCKVERIFY
- Monitor blockchain state and wallet balance
- Mine blocks on regtest for testing

## What is CHECKTIMELOCKVERIFY?

CHECKTIMELOCKVERIFY (OP_CLTV) is a Bitcoin script opcode that allows you to create transactions that cannot be spent until a certain time has passed. This is useful for:
- Escrow services
- Time-delayed inheritance
- Vesting schedules
- Savings accounts with withdrawal restrictions

## Features

### Core Functionality
- **Wallet Generation**: Create new Bitcoin wallets for regtest
- **RPC Connection**: Connect to Bitcoin Core via JSON-RPC
- **Time-Locked Transactions**: Create transactions that can only be spent after a specific datetime
- **Block Mining**: Generate blocks on regtest for testing
- **Balance Tracking**: Monitor your wallet balance in real-time

### Technical Implementation
- Custom Bitcoin script creation with OP_CLTV
- P2SH (Pay to Script Hash) address generation
- Transaction building and serialization
- HASH160 and SHA256 hashing
- Base58 encoding for addresses

## Prerequisites

1. **Bitcoin Core** - Running in regtest mode
2. **Flutter** - Version 3.9.2 or higher
3. **Dart** - Comes with Flutter

## Setup Instructions

### 1. Start Bitcoin Core in Regtest Mode

```bash
# Start Bitcoin Core daemon in regtest mode
bitcoind -regtest -rpcuser=bitcoin -rpcpassword=bitcoin -rpcport=18443

# Or using bitcoin-qt
bitcoin-qt -regtest -rpcuser=bitcoin -rpcpassword=bitcoin -rpcport=18443
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Run the Application

```bash
flutter run -d linux  # For Linux
# or
flutter run -d macos  # For macOS
# or
flutter run -d windows  # For Windows
```

## Usage Guide

### Initial Setup

1. **Generate Wallet**
   - Launch the app
   - Click "Generate New Wallet"
   - Your wallet address will be displayed

2. **Connect to Bitcoin Node**
   - Default settings connect to `127.0.0.1:18443`
   - Username: `bitcoin`
   - Password: `bitcoin`
   - Click "Connect to Node"

3. **Generate Blocks**
   - Click "Mine Blocks" on the home screen
   - Enter number of blocks to generate (6+ for coinbase maturity)
   - This will fund your wallet with mining rewards

### Creating Time-Locked Transactions

1. Click the "Time Lock" button on the home screen
2. Enter the amount in BTC
3. Enter the recipient address (or use your own)
4. Select the unlock date and time
5. Click "Create Time-Locked Transaction"

The app will generate a P2SH address containing the CLTV script. Funds sent to this address cannot be spent until the specified unlock time.

## How CHECKTIMELOCKVERIFY Works

### The Script Structure

A CLTV script looks like this:

```
<locktime> OP_CHECKLOCKTIMEVERIFY OP_DROP OP_DUP OP_HASH160 <pubKeyHash> OP_EQUALVERIFY OP_CHECKSIG
```

### Execution Flow

1. **Push locktime**: The unlock timestamp is pushed onto the stack
2. **OP_CHECKLOCKTIMEVERIFY**: Validates that the transaction's locktime is >= the stack value
3. **OP_DROP**: Remove the locktime from the stack
4. **Standard P2PKH**: The rest is a standard Pay-to-PubKey-Hash script

### Time Representation

- Block height: Values < 500,000,000 represent block numbers
- Unix timestamp: Values >= 500,000,000 represent Unix timestamps
- This app uses Unix timestamps for date/time locks

## Project Structure

```
lib/
├── main.dart                     # App entry point
├── models/
│   └── bitcoin_transaction.dart  # Transaction models
├── providers/
│   └── wallet_provider.dart      # State management
├── screens/
│   ├── home_screen.dart          # Main wallet screen
│   ├── timelock_screen.dart      # CLTV transaction creation
│   └── wallet_setup_screen.dart  # Initial setup
├── services/
│   └── bitcoin_rpc.dart          # Bitcoin RPC client
└── utils/
    ├── bitcoin_script.dart       # Script creation utilities
    └── bitcoin_wallet.dart       # Wallet key management
```

## Security Notes

⚠️ **This is a demonstration application for regtest use only**

- **Not for production**: This wallet is for educational purposes
- **Simplified cryptography**: Uses simplified implementations for demo
- **No private key encryption**: Private keys are stored in memory
- **Regtest only**: Designed for local testing network
- **No recovery mechanism**: No seed phrase backup implemented

## Troubleshooting

### Cannot Connect to Bitcoin Node

- Ensure Bitcoin Core is running: `bitcoin-cli -regtest getblockchaininfo`
- Check RPC credentials match
- Verify port 18443 is not blocked

### Insufficient Balance

- Generate blocks to fund wallet: Click "Mine Blocks" and generate 6+ blocks
- Wait for coinbase maturity (100 blocks in regtest)

## Resources

- [Bitcoin Script Reference](https://en.bitcoin.it/wiki/Script)
- [BIP-65: CHECKLOCKTIMEVERIFY](https://github.com/bitcoin/bips/blob/master/bip-0065.mediawiki)
- [Bitcoin Developer Guide](https://developer.bitcoin.org/devguide/)

## License

This is an educational project. Use at your own risk.
