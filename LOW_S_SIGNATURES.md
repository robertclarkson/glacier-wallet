# Low-S Signature Normalization (BIP-62)

## Overview

Bitcoin requires ECDSA signatures to use "low-S" values to prevent transaction malleability. This document explains the issue and how Glacier Wallet implements the fix.

## The Problem: Transaction Malleability

In ECDSA (Elliptic Curve Digital Signature Algorithm), a signature consists of two values: `(r, s)`.

Due to the mathematical properties of elliptic curves, if `(r, s)` is a valid signature for a message, then `(r, n - s)` is also valid (where `n` is the curve order).

This means the same transaction could have **two different valid signatures**, leading to:
- Different transaction IDs (txid)
- Ability to modify transactions in-flight
- Issues with transaction chains

## The Solution: Low-S Enforcement

Bitcoin enforces that `s` must be in the lower half of the valid range:
- If `s <= n/2`: signature is valid (low-S)
- If `s > n/2`: signature is rejected (high-S)

This is enforced by the `SCRIPT_VERIFY_LOW_S` flag in Bitcoin Core.

## Implementation in Glacier Wallet

### secp256k1 Curve Order

The secp256k1 curve order is:
```
n = 0xfffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141
```

Half of n:
```
n/2 = 0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0
```

### Signature Normalization

When encoding a DER signature, we normalize `s`:

```dart
Uint8List _encodeDERSignature(ECSignature sig) {
  var r = sig.r;
  var s = sig.s;
  
  // secp256k1 curve order
  final n = BigInt.parse('fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141', radix: 16);
  final halfN = n >> 1;
  
  // If S > N/2, use N - S instead (low-S normalization)
  if (s.compareTo(halfN) > 0) {
    s = n - s;
  }
  
  // ... encode DER signature with normalized s
}
```

### Error Before Fix

```
RPC Error: non-mandatory-script-verify-flag (Non-canonical signature: S value is unnecessarily high)
```

This error occurred when the ECDSA signer randomly generated an `s` value that was > n/2.

### After Fix

All signatures now pass Bitcoin's validation:
- `s` values are always ≤ n/2
- Transactions are non-malleable
- Signatures are canonical

## BIP-62: Dealing with Malleability

[BIP-62](https://github.com/bitcoin/bips/blob/master/bip-0062.mediawiki) defines several rules to prevent transaction malleability:

1. **Low-S values**: Enforce s ≤ n/2
2. **Strict DER encoding**: Signatures must be properly DER-encoded
3. **No extra data**: scriptSigs must not have unnecessary data
4. **Normalized signatures**: Only one valid signature per transaction

Glacier Wallet implements all of these rules.

## DER Signature Format

A properly encoded DER signature with SIGHASH_ALL:

```
30                              - DER sequence tag
[total_length]                  - Length of remaining data
  02                            - Integer tag (r)
  [r_length]                    - Length of r
  [r_bytes]                     - r value (big-endian)
  02                            - Integer tag (s)
  [s_length]                    - Length of s (normalized to low-S)
  [s_bytes]                     - s value (big-endian, low-S)
01                              - SIGHASH_ALL flag
```

### Example

```
304402201234...5678  - Valid low-S signature
  ^^                  - 0x30 (DER sequence)
    ^^                - Total length (0x44 = 68 bytes)
      ^^              - 0x02 (integer for r)
        ^^            - r length (0x20 = 32 bytes)
          [32 bytes]  - r value
                ^^    - 0x02 (integer for s)
                  ^^  - s length
            [? bytes] - s value (LOW-S!)
                  ^^  - 0x01 (SIGHASH_ALL)
```

## Testing

To verify low-S signatures:

```bash
# Decode a transaction
bitcoin-cli -regtest decoderawtransaction <hex>

# Check the scriptSig signatures
# Each signature should end with '01' (SIGHASH_ALL)
# And the S value should be < n/2
```

You can also use Bitcoin Core's test:

```bash
# This will reject high-S signatures
bitcoin-cli -regtest testmempoolaccept '["<rawtxhex>"]'
```

## Deterministic Signatures (RFC 6979)

Glacier Wallet also uses **deterministic k-value generation** (RFC 6979) for ECDSA signing:

```dart
final signer = ECDSASigner(null, HMac(SHA256Digest(), 64));
```

This ensures:
- Same message + same private key = same signature (deterministic)
- No need for random number generator during signing
- Protection against weak RNG attacks
- Still produces low-S signatures when normalized

## References

- [BIP-62: Dealing with Malleability](https://github.com/bitcoin/bips/blob/master/bip-0062.mediawiki)
- [BIP-66: Strict DER Signatures](https://github.com/bitcoin/bips/blob/master/bip-0066.mediawiki)
- [RFC 6979: Deterministic ECDSA](https://tools.ietf.org/html/rfc6979)
- [secp256k1 Parameters](https://en.bitcoin.it/wiki/Secp256k1)

## Impact on Glacier Wallet

With low-S normalization:
- ✅ All transactions are now accepted by Bitcoin Core
- ✅ Signatures are non-malleable
- ✅ Transaction IDs cannot be modified
- ✅ Compatible with all Bitcoin nodes
- ✅ Compliant with BIP-62 and BIP-66

## Complete Transaction Signing Flow

1. Build unsigned transaction
2. For each input:
   - Create signature hash (double SHA256)
   - Sign with ECDSA (deterministic k via RFC 6979)
   - **Normalize S to low-S** ← Critical step!
   - Encode in DER format
   - Add SIGHASH_ALL flag
3. Build scriptSig with signature + public key
4. Serialize complete transaction
5. Broadcast to network

Every step is now implemented correctly in Glacier Wallet! 🎉
