import 'dart:typed_data';
import 'package:convert/convert.dart';

/// Bitcoin Script opcodes and utilities
class BitcoinScript {
  // Opcodes
  static const int OP_0 = 0x00;
  static const int OP_1 = 0x51;
  static const int OP_DUP = 0x76;
  static const int OP_HASH160 = 0xa9;
  static const int OP_EQUALVERIFY = 0x88;
  static const int OP_CHECKSIG = 0xac;
  static const int OP_CHECKLOCKTIMEVERIFY = 0xb1;
  static const int OP_DROP = 0x75;
  static const int OP_IF = 0x63;
  static const int OP_ELSE = 0x67;
  static const int OP_ENDIF = 0x68;
  static const int OP_VERIFY = 0x69;

  /// Create a standard P2PKH (Pay to Public Key Hash) script
  static Uint8List p2pkh(String pubKeyHash) {
    final script = <int>[];
    script.add(OP_DUP);
    script.add(OP_HASH160);
    script.add(20); // Push 20 bytes
    script.addAll(hex.decode(pubKeyHash));
    script.add(OP_EQUALVERIFY);
    script.add(OP_CHECKSIG);
    return Uint8List.fromList(script);
  }

  /// Create a CHECKTIMELOCKVERIFY script
  /// This script locks coins until a specific block height or timestamp
  static Uint8List createCLTVScript(String pubKeyHash, int lockTime) {
    final script = <int>[];
    
    // Push lock time onto stack
    final lockTimeBytes = _numberToMinimalBytes(lockTime);
    script.add(lockTimeBytes.length);
    script.addAll(lockTimeBytes);
    
    // CHECKLOCKTIMEVERIFY opcode
    script.add(OP_CHECKLOCKTIMEVERIFY);
    
    // Drop the lock time from stack
    script.add(OP_DROP);
    
    // Standard P2PKH after the timelock
    script.add(OP_DUP);
    script.add(OP_HASH160);
    script.add(20); // Push 20 bytes
    script.addAll(hex.decode(pubKeyHash));
    script.add(OP_EQUALVERIFY);
    script.add(OP_CHECKSIG);
    
    return Uint8List.fromList(script);
  }

  /// Create a conditional CLTV script that allows spending either:
  /// 1. After the locktime with the owner's key
  /// 2. Immediately with both owner and co-signer keys
  static Uint8List createConditionalCLTVScript(
    String ownerPubKeyHash, 
    String coSignerPubKeyHash, 
    int lockTime
  ) {
    final script = <int>[];
    
    // IF branch (immediate spending with both signatures)
    script.add(OP_IF);
    
    // First signature check (owner)
    script.add(OP_DUP);
    script.add(OP_HASH160);
    script.add(20);
    script.addAll(hex.decode(ownerPubKeyHash));
    script.add(OP_EQUALVERIFY);
    script.add(OP_CHECKSIG);
    
    // Second signature check (co-signer) - simplified for example
    script.add(OP_DUP);
    script.add(OP_HASH160);
    script.add(20);
    script.addAll(hex.decode(coSignerPubKeyHash));
    script.add(OP_EQUALVERIFY);
    script.add(OP_CHECKSIG);
    
    // ELSE branch (time-locked spending with owner's key only)
    script.add(OP_ELSE);
    
    // Push lock time
    final lockTimeBytes = _numberToMinimalBytes(lockTime);
    script.add(lockTimeBytes.length);
    script.addAll(lockTimeBytes);
    
    // CHECKLOCKTIMEVERIFY
    script.add(OP_CHECKLOCKTIMEVERIFY);
    script.add(OP_DROP);
    
    // Owner signature check
    script.add(OP_DUP);
    script.add(OP_HASH160);
    script.add(20);
    script.addAll(hex.decode(ownerPubKeyHash));
    script.add(OP_EQUALVERIFY);
    script.add(OP_CHECKSIG);
    
    script.add(OP_ENDIF);
    
    return Uint8List.fromList(script);
  }

  /// Create script signature for CLTV transaction
  static Uint8List createCLTVScriptSig(
    Uint8List signature,
    Uint8List publicKey,
    Uint8List redeemScript,
    {bool useTimeLockPath = true}
  ) {
    final scriptSig = <int>[];
    
    // Push signature
    scriptSig.add(signature.length);
    scriptSig.addAll(signature);
    
    // Push public key
    scriptSig.add(publicKey.length);
    scriptSig.addAll(publicKey);
    
    if (!useTimeLockPath) {
      // For conditional scripts, push 1 to take the IF path
      scriptSig.add(OP_1);
    }
    
    // Push redeem script
    scriptSig.add(redeemScript.length);
    scriptSig.addAll(redeemScript);
    
    return Uint8List.fromList(scriptSig);
  }

  /// Convert number to minimal byte representation
  static Uint8List _numberToMinimalBytes(int number) {
    if (number == 0) return Uint8List.fromList([]);
    
    final bytes = <int>[];
    bool negative = number < 0;
    int absNumber = number.abs();
    
    while (absNumber > 0) {
      bytes.add(absNumber & 0xFF);
      absNumber >>= 8;
    }
    
    // If the most significant bit is set, we need to add a padding byte
    if (bytes.last & 0x80 != 0) {
      bytes.add(negative ? 0x80 : 0x00);
    } else if (negative) {
      bytes[bytes.length - 1] |= 0x80;
    }
    
    return Uint8List.fromList(bytes);
  }

  /// Get script hash for P2SH address
  static String getScriptHash(Uint8List script) {
    final hash = _hash160(script);
    return hex.encode(hash);
  }

  /// RIPEMD160(SHA256(data))
  static Uint8List _hash160(Uint8List data) {
    // For now, we'll use a simplified hash (in real implementation, use proper RIPEMD160)
    final sha256Hash = _sha256(data);
    return sha256Hash.sublist(0, 20); // Truncate to 20 bytes as approximation
  }

  /// SHA256 hash
  static Uint8List _sha256(Uint8List data) {
    // Simplified - in real implementation, use proper crypto library
    return Uint8List.fromList(List.generate(32, (i) => i * 7 % 256));
  }
}
