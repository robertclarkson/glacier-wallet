# Bitcoin Transaction Signing Implementation

## Overview

This document explains how the Glacier wallet builds and signs Bitcoin transactions in-app using ECDSA with secp256k1, ensuring private keys never leave the application.

## Security Architecture

### Private Key Management
- **Private keys stay in-app**: Never exported to Bitcoin Core
- **In-memory only**: Keys stored in `BitcoinWallet` instance
- **No RPC wallet dependency**: Bitcoin Core wallet only used for watch-only operations

### Signing Process
All transaction signing happens client-side using the `pointycastle` library.

## Transaction Building Process

### 1. Input Selection
```dart
// Select UTXOs with sufficient balance
final selectedInputs = <Map<String, dynamic>>[];
int totalInput = 0;

for (final utxo in availableUtxos) {
  selectedInputs.add({
    'txid': utxo['txid'],
    'vout': utxo['vout'],
    'amount': utxo['amount'],
  });
  totalInput += (utxo['amount'] * 100000000).round();
  if (totalInput >= amountSats + fee) break;
}
```

### 2. Output Creation
```dart
final outputs = <String, int>{
  timeLockAddress: amountSats,  // P2SH timelock address
};

// Add change output if above dust limit
if (change > 546) {
  outputs[wallet.address] = change;
}
```

### 3. Transaction Signing

The `buildAndSignTransaction` method performs these steps:

#### Step 3.1: Create Signature for Each Input
For each input, we create a modified version of the transaction:
- Include the scriptPubKey of the UTXO being spent
- Hash with SIGHASH_ALL flag
- Sign using ECDSA secp256k1

```dart
// Build transaction for signing
final txForSigning = BytesBuilder();
txForSigning.add(_int32LE(2));  // version
txForSigning.add(_varint(inputs.length));

// Add inputs (scriptPubKey only for input being signed)
for (int j = 0; j < inputs.length; j++) {
  // ... add txid, vout
  if (i == j) {
    // Include P2PKH scriptPubKey for signing
    txForSigning.add(_varint(scriptPubKey.length));
    txForSigning.add(scriptPubKey);
  } else {
    txForSigning.add(_varint(0));  // empty
  }
  txForSigning.add(_int32LE(0xfffffffe));
}

// Add outputs and locktime
// ... outputs
txForSigning.add(_int32LE(locktime));
txForSigning.add(_int32LE(1));  // SIGHASH_ALL

// Double SHA256
final txHash = _doublesha256(txForSigning.toBytes());

// Sign
final signature = _signTransactionHash(txHash);
```

#### Step 3.2: ECDSA Signing

```dart
Uint8List _signTransactionHash(Uint8List txHash) {
  // Create secp256k1 domain parameters
  final domainParams = ECDomainParameters('secp256k1');
  
  // Parse private key
  final d = BigInt.parse(_privateKeyHex, radix: 16);
  final privateKey = ECPrivateKey(d, domainParams);
  
  // Create signer with deterministic k (RFC 6979)
  final signer = ECDSASigner(null, HMac(SHA256Digest(), 64));
  signer.init(true, pc.PrivateKeyParameter(privateKey));
  
  // Sign
  final sig = signer.generateSignature(txHash) as ECSignature;
  
  // Encode in DER format with SIGHASH_ALL
  return _encodeDERSignature(sig);
}
```

#### Step 3.3: DER Encoding

Bitcoin requires signatures in DER (Distinguished Encoding Rules) format:

```dart
Uint8List _encodeDERSignature(ECSignature sig) {
  final rBytes = _bigIntToBytes(sig.r);
  final sBytes = _bigIntToBytes(sig.s);
  
  final result = BytesBuilder();
  result.addByte(0x30);  // DER sequence tag
  result.addByte(rBytes.length + sBytes.length + 4);  // total length
  result.addByte(0x02);  // integer tag for r
  result.addByte(rBytes.length);
  result.add(rBytes);
  result.addByte(0x02);  // integer tag for s
  result.addByte(sBytes.length);
  result.add(sBytes);
  result.addByte(0x01);  // SIGHASH_ALL
  
  return result.toBytes();
}
```

#### Step 3.4: Build Final Transaction

```dart
// Build signed transaction
final signedTx = BytesBuilder();

// Version
signedTx.add(_int32LE(2));

// Inputs with scriptSig
for (int i = 0; i < inputs.length; i++) {
  // ... add txid, vout
  
  // Build scriptSig: <signature> <pubkey>
  final scriptSig = BytesBuilder();
  scriptSig.add(_varint(signatures[i].length));
  scriptSig.add(signatures[i]);
  scriptSig.add(_varint(pubKeyBytes.length));
  scriptSig.add(pubKeyBytes);
  
  signedTx.add(_varint(scriptSig.toBytes().length));
  signedTx.add(scriptSig.toBytes());
  signedTx.add(_int32LE(0xfffffffe));
}

// Add outputs and locktime
// ...

return hex.encode(signedTx.toBytes());
```

## Transaction Structure

### Raw Transaction Format

```
[version (4 bytes)]
[input count (varint)]
  For each input:
    [prev tx hash (32 bytes, reversed)]
    [prev output index (4 bytes)]
    [scriptSig length (varint)]
    [scriptSig]
    [sequence (4 bytes)]
[output count (varint)]
  For each output:
    [amount (8 bytes)]
    [scriptPubKey length (varint)]
    [scriptPubKey]
[locktime (4 bytes)]
```

### scriptSig Structure (P2PKH)

```
[signature length] [signature] [pubkey length] [pubkey]
```

The signature includes the SIGHASH_ALL flag (0x01) at the end.

## Key Components

### Dependencies
- **pointycastle**: ECDSA signing, secp256k1, SHA256, HMAC
- **crypto**: SHA256 hashing
- **convert**: Hex encoding

### Helper Functions

#### Varint Encoding
```dart
Uint8List _varint(int value) {
  if (value < 0xfd) return Uint8List.fromList([value]);
  if (value <= 0xffff) {
    return Uint8List.fromList([0xfd, value & 0xff, (value >> 8) & 0xff]);
  }
  // ... handle larger values
}
```

#### Little-Endian Integers
```dart
Uint8List _int32LE(int value) {
  return Uint8List.fromList([
    value & 0xff,
    (value >> 8) & 0xff,
    (value >> 16) & 0xff,
    (value >> 24) & 0xff,
  ]);
}

Uint8List _int64LE(int value) {
  // 8 bytes, little-endian
}
```

#### Double SHA256
```dart
Uint8List _doublesha256(Uint8List data) {
  final hash1 = sha256.convert(data);
  final hash2 = sha256.convert(hash1.bytes);
  return Uint8List.fromList(hash2.bytes);
}
```

## Broadcasting

Once signed, the transaction is broadcast via Bitcoin RPC:

```dart
final txId = await _rpc!.sendRawTransaction(signedTxHex);
```

Bitcoin Core validates:
- ✅ Script execution (signature verification)
- ✅ Input amounts vs outputs (no overspending)
- ✅ Coinbase maturity (100 confirmations)
- ✅ UTXO existence
- ✅ Double-spend prevention

## Common Issues & Solutions

### Issue 1: "mandatory-script-verify-flag-failed"
**Cause**: Invalid signature or scriptSig format
**Solution**: Ensure proper DER encoding, correct SIGHASH_ALL flag

### Issue 2: "bad-txns-premature-spend-of-coinbase"
**Cause**: Trying to spend coinbase with <100 confirmations
**Solution**: Filter UTXOs requiring 100 confirmations

### Issue 3: "Operation not valid with the current stack size"
**Cause**: scriptSig not constructed properly
**Solution**: Verify signature and pubkey lengths are correct

## Testing

### Regtest Commands
```bash
# Generate blocks to get spendable funds
bitcoin-cli -regtest generatetoaddress 101 <address>

# Verify transaction
bitcoin-cli -regtest decoderawtransaction <hex>

# Check mempool
bitcoin-cli -regtest getrawmempool

# Mine to confirm
bitcoin-cli -regtest generatetoaddress 1 <address>
```

## References
- [Bitcoin Transaction Format](https://en.bitcoin.it/wiki/Transaction)
- [BIP-66: Strict DER Signatures](https://github.com/bitcoin/bips/blob/master/bip-0066.mediawiki)
- [RFC 6979: Deterministic ECDSA](https://tools.ietf.org/html/rfc6979)
- [secp256k1 Curve](https://en.bitcoin.it/wiki/Secp256k1)
