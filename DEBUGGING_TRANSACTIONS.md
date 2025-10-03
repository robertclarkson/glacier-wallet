# Common Wallet Issues and Debugging

## Issue: OP_EQUALVERIFY Failure When Spending UTXOs

### Symptom
```
RPC Error: mandatory-script-verify-flag-failed (Script failed an OP_EQUALVERIFY operation)
```

### Root Cause
The public key hash in the transaction's scriptSig doesn't match the public key hash in the UTXO's scriptPubKey.

### Common Scenarios

#### 1. Wallet Address Mismatch
**Problem**: You received funds to address A, but you're trying to spend them with the private key for address B.

**How it happens**:
- Generate a wallet → Address: `bcrt1q...abc`
- Mine blocks to that address → UTXOs created for `bcrt1q...abc`
- Restart app
- Generate a NEW wallet → Address: `bcrt1q...xyz` (DIFFERENT!)
- Try to spend old UTXOs → **FAIL** (wrong private key)

**Solution**: Persist the wallet's mnemonic and reload the same wallet

####  2. Public Key Derivation Mismatch
**Problem**: The public key doesn't match the private key due to incorrect elliptic curve operations.

**How it happens**:
- Using simplified/fake public key derivation (e.g., `pubKey = hash(privKey)`)
- Not using proper secp256k1 curve multiplication
- Mixing compressed and uncompressed public keys

**Solution**: Use proper secp256k1: `Q = d * G` where d is private key, G is generator point

#### 3. scriptSig Format Error
**Problem**: The scriptSig is malformed.

**Bitcoin P2PKH scriptSig format**:
```
[sig_length_byte] [signature_with_SIGHASH] [pubkey_length_byte] [public_key]
```

**Common mistakes**:
- Using varint for lengths (should be single byte for <75 byte pushes)
- Missing SIGHASH_ALL flag on signature
- Wrong DER encoding

### Debugging Steps

#### Step 1: Verify Keys Match
Add debug logging to your transaction building:

```dart
print('🔑 [DEBUG] Building transaction with:');
print('   Private key: ${_privateKeyHex.substring(0, 16)}...');
print('   Public key: $publicKeyHex');
print('   Public key hash: $publicKeyHash');
print('   Address: $address');
```

#### Step 2: Check UTXO Ownership
```dart
print('   Selected UTXO: ${utxo['txid']}:${utxo['vout']}');
print('   UTXO address: ${utxo['address']}');
print('   Wallet address: ${wallet.address}');
print('   Match: ${utxo['address'] == wallet.address}');
```

#### Step 3: Decode the Transaction
Use Bitcoin Core to inspect the raw transaction:

```bash
bitcoin-cli -regtest decoderawtransaction <hex>
```

Look for:
- `scriptSig` in inputs - should contain signature + public key
- Public key in scriptSig should hash to the address that owns the UTXO

#### Step 4: Verify Signature
```bash
bitcoin-cli -regtest testmempoolaccept '["<rawtxhex>"]'
```

This will show detailed validation errors.

### Solutions

#### Solution 1: Wallet Persistence
Save the mnemonic and reload it:

```dart
// Save on generation
final prefs = await SharedPreferences.getInstance();
await prefs.setString('mnemonic', wallet.mnemonic);

// Load on startup
final mnemonic = prefs.getString('mnemonic');
if (mnemonic != null) {
  _wallet = BitcoinWallet.fromMnemonic(mnemonic);
}
```

#### Solution 2: Use Correct scriptPubKey for Signing
When signing, use the scriptPubKey from the UTXO you're spending:

```dart
// Get scriptPubKey from the UTXO being spent
final scriptPubKey = utxo['scriptPubKey'];

// Use it when building the signature hash
// (instead of reconstructing from wallet's current public key hash)
```

#### Solution 3: Fix Public Key Derivation
Ensure proper secp256k1 operations:

```dart
String _derivePublicKey(String privateKeyHex) {
  final domainParams = ECDomainParameters('secp256k1');
  final d = BigInt.parse(privateKeyHex, radix: 16);
  
  // Q = d * G (elliptic curve multiplication)
  final Q = domainParams.G * d;
  
  final x = Q!.x!.toBigInteger()!;
  final y = Q.y!.toBigInteger()!;
  
  // Compressed format: 0x02 or 0x03 + x-coordinate
  final prefix = (y & BigInt.one) == BigInt.zero ? 0x02 : 0x03;
  var xHex = x.toRadixString(16).padLeft(64, '0');
  
  return hex.encode([prefix] + hex.decode(xHex));
}
```

### Testing

1. **Test with fresh wallet and fresh UTXOs**:
   - Generate wallet
   - Mine blocks to that wallet's address
   - Immediately try to spend (same session)
   - Should work if keys are correct

2. **Test with reloaded wallet**:
   - Save mnemonic
   - Restart app
   - Load same mnemonic
   - Try to spend old UTXOs
   - Should work if persistence is correct

3. **Verify public key**:
   ```dart
   // The hash of the public key should match the address
   final pubKeyHash = HASH160(publicKey);
   final address = base58encode([0x6F] + pubKeyHash + checksum);
   // This should equal wallet.address
   ```

## Glacier Wallet Specific

### Current Issue
The app doesn't persist wallets, so each restart creates a new wallet with a new address. Old UTXOs can't be spent because they belong to the old address.

### Temporary Workaround
Don't restart the app while testing. Create wallet, mine blocks, and create timelocks all in one session.

### Proper Fix
Implement wallet persistence using shared_preferences or secure_storage.
