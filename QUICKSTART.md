# Quick Start Guide - Glacier Bitcoin Wallet

## Step-by-Step Tutorial

### 1. Start Bitcoin Core (Regtest Mode)

Open a terminal and run:

```bash
# Option A: Using bitcoind
bitcoind -regtest -rpcuser=bitcoin -rpcpassword=bitcoin -rpcport=18443 -daemon

# Option B: Using bitcoin-qt (GUI)
bitcoin-qt -regtest -rpcuser=bitcoin -rpcpassword=bitcoin -rpcport=18443
```

Verify it's running:
```bash
bitcoin-cli -regtest -rpcuser=bitcoin -rpcpassword=bitcoin getblockchaininfo
```

### 2. Launch the Glacier Wallet

```bash
cd /home/tinfoil/bitcoin/glacier_flutter
flutter run -d linux
```

### 3. Set Up Your Wallet

#### On the Setup Screen:

1. **Click "Generate New Wallet"**
   - This creates a new Bitcoin wallet
   - You'll see your wallet address displayed
   - This is a regtest-only demonstration wallet

2. **Click "Connect to Node"**
   - Default settings should work if Bitcoin Core is running locally
   - Username: `bitcoin`
   - Password: `bitcoin`
   - Port: `18443`

3. **Success!**
   - You'll be redirected to the home screen
   - Your balance will be 0.00000000 BTC initially

### 4. Fund Your Wallet

#### Generate Blocks to Get Some Bitcoin:

1. Click the **"Mine Blocks"** button
2. Enter `101` (to mature the coinbase transactions)
3. Click "Generate"
4. Wait a few seconds
5. Your balance should now show 50 BTC (from block rewards)!

### 5. Create Your First Time-Locked Transaction

#### On the Home Screen:

1. Click the **"Time Lock"** button

#### On the Time Lock Screen:

1. **Amount**: Enter `1.0` (1 BTC)

2. **Recipient Address**: 
   - Click "Use My Address" (sends back to yourself)
   - Or paste any regtest address

3. **Select Unlock Time**:
   - Click the date button, select tomorrow
   - Click the time button, select a time
   - Or use Quick Select buttons (e.g., "1 Hour")

4. **Create Transaction**:
   - Click "Create Time-Locked Transaction"
   - You'll see a dialog with the time-lock address
   - This P2SH address contains the CLTV script

5. **Success!**
   - The transaction is now saved in your wallet
   - It appears in the "Time-Locked Transactions" section on home screen

### 6. Understanding What Happened

When you created the time-lock:

1. **CLTV Script Created**: 
   ```
   <unix_timestamp> OP_CHECKLOCKTIMEVERIFY OP_DROP 
   OP_DUP OP_HASH160 <your_pubkey_hash> OP_EQUALVERIFY OP_CHECKSIG
   ```

2. **P2SH Address Generated**: 
   - The script is hashed
   - A Pay-to-Script-Hash address is created
   - This address starts with '2' on regtest

3. **Transaction Details Stored**:
   - Amount locked
   - Unlock timestamp
   - Recipient address
   - Redeem script

### 7. Monitoring Your Time-Locks

On the **Home Screen**, you'll see:

- **Locked** (Orange badge): Cannot be spent yet
- **Unlocked** (Green badge): Can be spent now
- **Time Remaining**: Countdown to unlock time

### 8. Testing Time Progression

#### Option A: Wait for Real Time
- Just wait until the unlock time passes
- Refresh the app to see the status change

#### Option B: Advance Bitcoin Time (Regtest Trick)
```bash
# Generate more blocks to advance median time past
bitcoin-cli -regtest -rpcuser=bitcoin -rpcpassword=bitcoin generate 1
```

## Common Commands

### Bitcoin Core Management

```bash
# Check if Bitcoin Core is running
bitcoin-cli -regtest -rpcuser=bitcoin -rpcpassword=bitcoin getblockchaininfo

# Generate blocks
bitcoin-cli -regtest -rpcuser=bitcoin -rpcpassword=bitcoin generatetoaddress 10 <address>

# Check balance
bitcoin-cli -regtest -rpcuser=bitcoin -rpcpassword=bitcoin getbalance

# List unspent outputs
bitcoin-cli -regtest -rpcuser=bitcoin -rpcpassword=bitcoin listunspent

# Stop Bitcoin Core
bitcoin-cli -regtest -rpcuser=bitcoin -rpcpassword=bitcoin stop
```

### Flutter Commands

```bash
# Run the app
flutter run -d linux

# Hot reload (while app is running)
# Press 'r' in the terminal

# Hot restart (while app is running)
# Press 'R' in the terminal

# Quit the app
# Press 'q' in the terminal
```

## Example Walkthrough

### Creating a 1-Hour Time Lock

1. **Start**: Launch app, generate wallet, connect to node
2. **Fund**: Generate 101 blocks → Balance: 50 BTC
3. **Create Time Lock**:
   - Amount: `5.0` BTC
   - Recipient: Your address
   - Time: Select "1 Hour" quick button
   - Create transaction
4. **View**: Check home screen, see "Locked" status
5. **Wait**: 1 hour passes
6. **Check**: Refresh app, status changes to "Unlocked"

### Creating a Future-Dated Lock

1. **Date Selection**: Click date picker
2. **Pick Date**: Select 1 month from now
3. **Pick Time**: Select a specific time
4. **Verify**: Check the Unix timestamp displayed
5. **Create**: Submit the transaction
6. **Result**: Time-lock with ~30 days remaining

## Understanding the UI

### Wallet Setup Screen
- **Wallet Setup Card**: Generate or restore wallet
- **Bitcoin Node Card**: Configure RPC connection
- **Setup Instructions**: Quick reference guide

### Home Screen
- **Balance Card**: Current wallet balance + action buttons
- **Blockchain Info**: Block height and connection status
- **Wallet Address**: Your receive address
- **Time-Locked Transactions**: List of all CLTV transactions

### Time Lock Screen
- **Info Card**: Explanation of CHECKTIMELOCKVERIFY
- **Amount Input**: How much BTC to lock
- **Recipient Input**: Who can claim after unlock time
- **Unlock Time**: Date and time selection
- **Quick Select**: Pre-set time durations
- **Balance Display**: Available funds

## Tips & Tricks

1. **Always Mine 101+ Blocks First**
   - Coinbase transactions need 100 confirmations to mature
   - Mining 101 blocks ensures you have spendable funds

2. **Use Your Own Address for Testing**
   - Click "Use My Address" to send time-locks to yourself
   - This way you don't need a second wallet

3. **Quick Time Testing**
   - Use "1 Hour" or "6 Hours" for quick testing
   - Don't wait days/weeks for demo purposes

4. **Refresh to Update**
   - Click the refresh icon to update balance and blockchain info
   - The app doesn't auto-refresh (demo limitation)

5. **Check Median Time Past**
   - CLTV uses median time past, not current time
   - Generate a block to update MTP if needed

## What's Next?

Now that you have the wallet running, try:

1. **Multiple Time Locks**: Create several with different unlock times
2. **Different Amounts**: Lock various amounts to see the tracking
3. **Far Future Locks**: Create a lock for next year
4. **Experiment with Scripts**: Check `lib/utils/bitcoin_script.dart` to see the CLTV implementation

## Need Help?

### App Won't Connect?
- Is Bitcoin Core running? Check with `bitcoin-cli`
- Are the RPC credentials correct?
- Is port 18443 available?

### Zero Balance?
- Have you generated blocks?
- Need at least 101 blocks for mature coinbase
- Click "Mine Blocks" and generate more

### Time Lock Not Unlocking?
- Is the current time past the unlock time?
- Try generating a block to update median time past
- Refresh the app to update UI

## Advanced: Bitcoin CLI Integration

You can verify the wallet's operations using bitcoin-cli:

```bash
# Import your wallet address for watching
bitcoin-cli -regtest -rpcuser=bitcoin -rpcpassword=bitcoin importaddress <your_address>

# Check transactions for your address
bitcoin-cli -regtest -rpcuser=bitcoin -rpcpassword=bitcoin listtransactions

# Decode a raw transaction
bitcoin-cli -regtest -rpcuser=bitcoin -rpcpassword=bitcoin decoderawtransaction <hex>

# Get median time past
bitcoin-cli -regtest -rpcuser=bitcoin -rpcpassword=bitcoin getblockchaininfo | grep mediantime
```

Happy time-locking! 🔒⏰
