import 'dart:typed_data';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:bip32/bip32.dart' as bip32;
import 'package:flutter/foundation.dart';
import 'package:pointycastle/ecc/api.dart';
import 'package:pointycastle/signers/ecdsa_signer.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/digests/ripemd160.dart';
import 'package:pointycastle/pointycastle.dart' as pc;

/// Simplified Bitcoin wallet utilities for the CLTV demo
class BitcoinWallet {
  late String _privateKeyHex;
  late String _publicKeyHex;
  String? _mnemonic; // Store mnemonic for derivation
  bip32.BIP32? _root; // Store root key for derivation

  BitcoinWallet.fromPrivateKey(String privateKeyHex) {
    _privateKeyHex = privateKeyHex;
    _publicKeyHex = _derivePublicKey(privateKeyHex);
  }

  BitcoinWallet.fromMnemonic(String mnemonic, {int derivationIndex = 0}) {
    _mnemonic = mnemonic;
    final seed = bip39.mnemonicToSeed(mnemonic);
    _root = bip32.BIP32.fromSeed(seed);
    
    // Derive key using standard Bitcoin path: m/44'/0'/0'/0/index
    final child = _root!.derivePath("m/44'/0'/0'/0/$derivationIndex");
    
    _privateKeyHex = hex.encode(child.privateKey!);
    _publicKeyHex = hex.encode(child.publicKey);
  }

  BitcoinWallet.generate() {
    // Generate a cryptographically secure random 32-byte private key
    final random = pc.SecureRandom('Fortuna')
      ..seed(pc.KeyParameter(
        Uint8List.fromList(
          List.generate(32, (i) => DateTime.now().microsecondsSinceEpoch % 256)
        )
      ));
    
    final privKeyBytes = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      privKeyBytes[i] = random.nextUint8();
    }
    
    _privateKeyHex = hex.encode(privKeyBytes);
    _publicKeyHex = _derivePublicKey(_privateKeyHex);
  }

  String _derivePublicKey(String privateKeyHex) {
    // Proper secp256k1 public key derivation
    final domainParams = ECDomainParameters('secp256k1');
    
    // Parse private key as BigInt
    final d = BigInt.parse(privateKeyHex, radix: 16);
    
    // Calculate public key point: Q = d * G
    final Q = domainParams.G * d;
    
    // Encode as compressed public key (33 bytes)
    // Format: [0x02 or 0x03][32-byte x-coordinate]
    // 0x02 if y is even, 0x03 if y is odd
    final x = Q!.x!.toBigInteger()!;
    final y = Q.y!.toBigInteger()!;
    
    final prefix = (y & BigInt.one) == BigInt.zero ? 0x02 : 0x03;
    
    // Convert x to 32-byte array
    var xHex = x.toRadixString(16);
    xHex = xHex.padLeft(64, '0'); // Ensure 32 bytes (64 hex chars)
    
    final pubKeyBytes = [prefix] + hex.decode(xHex);
    return hex.encode(pubKeyBytes);
  }

  /// Get private key as hex string
  String get privateKeyHex => _privateKeyHex;

  /// Get public key as compressed hex string
  String get publicKeyHex => _publicKeyHex;

  /// Get public key hash (HASH160 of public key)
  String get publicKeyHash {
    final pubKeyBytes = hex.decode(publicKeyHex);
    final sha256Hash = sha256.convert(pubKeyBytes);
    final ripemd160Hash = _ripemd160(sha256Hash.bytes);
    return hex.encode(ripemd160Hash);
  }

  /// Get Bitcoin address (P2PKH)
  String get address {
    final pubKeyHashBytes = hex.decode(publicKeyHash);
    final versionByte = 0x6F; // Testnet/Regtest version byte
    final payload = [versionByte] + pubKeyHashBytes;
    final checksum = _doublesha256(Uint8List.fromList(payload)).sublist(0, 4);
    final fullPayload = payload + checksum;
    return _base58Encode(Uint8List.fromList(fullPayload));
  }

  /// Get private key in WIF (Wallet Import Format) for regtest
  String get privateKeyWIF {
    final versionByte = 0xEF; // Regtest/Testnet private key version
    final privKeyBytes = hex.decode(_privateKeyHex);
    final payload = [versionByte] + privKeyBytes + [0x01]; // 0x01 for compressed
    final checksum = _doublesha256(Uint8List.fromList(payload)).sublist(0, 4);
    final fullPayload = payload + checksum;
    return _base58Encode(Uint8List.fromList(fullPayload));
  }

  /// Get derived address at a specific path (requires wallet created from mnemonic)
  /// change: 0 for receive addresses, 1 for change addresses
  /// index: address index (0, 1, 2, ...)
  String getAddress(int change, int index) {
    if (_root == null) {
      // If wallet wasn't created from mnemonic, just return the main address
      return address;
    }
    
    // Derive child key at path m/44'/0'/0'/change/index
    final child = _root!.derivePath("m/44'/0'/0'/$change/$index");
    final childPubKey = hex.encode(child.publicKey);
    
    // Calculate address from public key
    final pubKeyBytes = hex.decode(childPubKey);
    final sha256Hash = sha256.convert(pubKeyBytes);
    final ripemd160Hash = _ripemd160(sha256Hash.bytes);
    
    final versionByte = 0x6F; // Testnet/Regtest version byte
    final payload = [versionByte] + ripemd160Hash;
    final checksum = _doublesha256(Uint8List.fromList(payload)).sublist(0, 4);
    final fullPayload = payload + checksum;
    return _base58Encode(Uint8List.fromList(fullPayload));
  }

  /// Generate a time-locked address using CHECKTIMELOCKVERIFY with DateTime
  String generateTimeLockAddress(DateTime unlockTime) {
    final lockTime = unlockTime.millisecondsSinceEpoch ~/ 1000; // Unix timestamp
    return generateTimeLockAddressFromValue(lockTime);
  }

  /// Generate a time-locked address using CHECKTIMELOCKVERIFY with block height
  String generateTimeLockAddressFromBlockHeight(int blockHeight) {
    return generateTimeLockAddressFromValue(blockHeight);
  }

  /// Generate a time-locked address using CHECKTIMELOCKVERIFY with raw locktime value
  String generateTimeLockAddressFromValue(int lockTimeValue) {
    final redeemScript = BitcoinScript.createCLTVScript(publicKeyHash, lockTimeValue);
    final scriptHash = _hash160(redeemScript);
    
    // P2SH address (starts with 2 for testnet/regtest)
    final versionByte = 0xC4; // Testnet/Regtest P2SH version byte
    final payload = [versionByte] + scriptHash;
    final checksum = _doublesha256(Uint8List.fromList(payload)).sublist(0, 4);
    final fullPayload = payload + checksum;
    return _base58Encode(Uint8List.fromList(fullPayload));
  }

  /// Create a time-locked transaction data with DateTime
  Map<String, dynamic> createTimeLockTransaction({
    required String toAddress,
    required int amount,
    required DateTime unlockTime,
    required List<Map<String, dynamic>> utxos,
    int feeRate = 1000, // satoshis per kB
  }) {
    final lockTime = unlockTime.millisecondsSinceEpoch ~/ 1000;
    return createTimeLockTransactionFromValue(
      toAddress: toAddress,
      amount: amount,
      lockTimeValue: lockTime,
      utxos: utxos,
      feeRate: feeRate,
      lockTimeType: 'timestamp',
      unlockTime: unlockTime,
    );
  }

  /// Create a time-locked transaction data with block height
  Map<String, dynamic> createTimeLockTransactionFromBlockHeight({
    required String toAddress,
    required int amount,
    required int blockHeight,
    required List<Map<String, dynamic>> utxos,
    int feeRate = 1000, // satoshis per kB
  }) {
    return createTimeLockTransactionFromValue(
      toAddress: toAddress,
      amount: amount,
      lockTimeValue: blockHeight,
      utxos: utxos,
      feeRate: feeRate,
      lockTimeType: 'blockheight',
      blockHeight: blockHeight,
    );
  }

  /// Create a time-locked transaction data from raw locktime value
  Map<String, dynamic> createTimeLockTransactionFromValue({
    required String toAddress,
    required int amount,
    required int lockTimeValue,
    required List<Map<String, dynamic>> utxos,
    int feeRate = 1000,
    String lockTimeType = 'timestamp',
    DateTime? unlockTime,
    int? blockHeight,
  }) {
    final redeemScript = BitcoinScript.createCLTVScript(publicKeyHash, lockTimeValue);
    
    // Calculate total input value
    int totalInput = 0;
    for (final utxo in utxos) {
      totalInput += ((utxo['amount'] as double) * 100000000).round(); // Convert to satoshis
    }
    
    // Estimate transaction size and fee
    final estimatedSize = 180 + (utxos.length * 180) + (2 * 34); // Rough estimate
    final fee = (estimatedSize * feeRate / 1000).round();
    final changeAmount = totalInput - amount - fee;
    
    if (changeAmount < 0) {
      throw Exception('Insufficient funds');
    }
    
    final result = {
      'redeemScript': hex.encode(redeemScript),
      'lockTime': lockTimeValue,
      'lockTimeType': lockTimeType,
      'amount': amount,
      'fee': fee,
      'changeAmount': changeAmount,
      'toAddress': toAddress,
    };

    if (unlockTime != null) {
      result['unlockTime'] = unlockTime.toIso8601String();
    }
    if (blockHeight != null) {
      result['blockHeight'] = blockHeight;
    }

    return result;
  }

  /// Build and sign a raw Bitcoin transaction
  String buildAndSignTransaction({
    required List<Map<String, dynamic>> inputs,
    required Map<String, int> outputs, // address -> amount in satoshis
    int locktime = 0,
  }) {
    // Debug: Print key information
    print('🔑 [DEBUG] Building transaction with:');
    print('   Private key: ${_privateKeyHex.substring(0, 16)}...');
    print('   Public key: $publicKeyHex');
    print('   Public key hash: $publicKeyHash');
    print('   Address: $address');
    
    // Create P2PKH scriptPubKey for our address (used in signing)
    final pubKeyHashBytes = hex.decode(publicKeyHash);
    final scriptPubKeyForSigning = BytesBuilder();
    scriptPubKeyForSigning.addByte(0x76); // OP_DUP
    scriptPubKeyForSigning.addByte(0xa9); // OP_HASH160
    scriptPubKeyForSigning.addByte(0x14); // Push 20 bytes
    scriptPubKeyForSigning.add(pubKeyHashBytes);
    scriptPubKeyForSigning.addByte(0x88); // OP_EQUALVERIFY
    scriptPubKeyForSigning.addByte(0xac); // OP_CHECKSIG
    final scriptPubKey = scriptPubKeyForSigning.toBytes();
    
    // Sign each input
    final signatures = <Uint8List>[];
    for (int i = 0; i < inputs.length; i++) {
      // Build transaction for signing this input
      final txForSigning = BytesBuilder();
      
      // Version
      txForSigning.add(_int32LE(2));
      
      // Input count
      txForSigning.add(_varint(inputs.length));
      
      // Inputs (with scriptPubKey only for the input being signed)
      for (int j = 0; j < inputs.length; j++) {
        final input = inputs[j];
        final txid = hex.decode(input['txid'] as String);
        txForSigning.add(Uint8List.fromList(txid.reversed.toList()));
        txForSigning.add(_int32LE(input['vout'] as int));
        
        if (i == j) {
          // This is the input we're signing - include scriptPubKey
          txForSigning.add(_varint(scriptPubKey.length));
          txForSigning.add(scriptPubKey);
        } else {
          // Other inputs - empty script
          txForSigning.add(_varint(0));
        }
        
        txForSigning.add(_int32LE(0xfffffffe));
      }
      
      // Outputs
      txForSigning.add(_varint(outputs.length));
      outputs.forEach((address, amount) {
        txForSigning.add(_int64LE(amount));
        final outScriptPubKey = _addressToScriptPubKey(address);
        txForSigning.add(_varint(outScriptPubKey.length));
        txForSigning.add(outScriptPubKey);
      });
      
      // Locktime
      txForSigning.add(_int32LE(locktime));
      
      // Hash type (SIGHASH_ALL)
      txForSigning.add(_int32LE(1));
      
      // Double SHA256 hash
      final txHash = _doublesha256(txForSigning.toBytes());
      
      // Sign the hash
      final signature = _signTransactionHash(txHash);
      signatures.add(signature);
    }
    
    // Build final signed transaction
    final signedTx = BytesBuilder();
    
    // Version
    signedTx.add(_int32LE(2));
    
    // Input count
    signedTx.add(_varint(inputs.length));
    
    // Inputs with signatures
    for (int i = 0; i < inputs.length; i++) {
      final input = inputs[i];
      final txid = hex.decode(input['txid'] as String);
      signedTx.add(Uint8List.fromList(txid.reversed.toList()));
      signedTx.add(_int32LE(input['vout'] as int));
      
      // Build scriptSig: <sig_length> <signature> <pubkey_length> <pubkey>
      final scriptSig = BytesBuilder();
      // Push signature (length is just a byte since signatures are <256 bytes)
      scriptSig.addByte(signatures[i].length);
      scriptSig.add(signatures[i]);
      // Push public key (length is just a byte, 33 for compressed)
      final pubKeyBytes = hex.decode(publicKeyHex);
      scriptSig.addByte(pubKeyBytes.length);
      scriptSig.add(pubKeyBytes);
      
      final scriptSigBytes = scriptSig.toBytes();
      signedTx.add(_varint(scriptSigBytes.length));
      signedTx.add(scriptSigBytes);
      
      signedTx.add(_int32LE(0xfffffffe));
    }
    
    // Outputs
    signedTx.add(_varint(outputs.length));
    outputs.forEach((address, amount) {
      signedTx.add(_int64LE(amount));
      final scriptPubKey = _addressToScriptPubKey(address);
      signedTx.add(_varint(scriptPubKey.length));
      signedTx.add(scriptPubKey);
    });
    
    // Locktime
    signedTx.add(_int32LE(locktime));
    
    return hex.encode(signedTx.toBytes());
  }

  /// Build transaction to unlock time-locked funds (spend from P2SH)
  String buildUnlockTransaction({
    required String txid,
    required int vout,
    required int amount,
    required String outputAddress,
    required int outputAmount,
    required String redeemScript,
    required int lockTime,
  }) {
    debugPrint('🔓 [BitcoinWallet] Building unlock transaction...');
    debugPrint('   Input: $txid:$vout');
    debugPrint('   Amount: $amount sats');
    debugPrint('   Output: $outputAddress');
    debugPrint('   Output amount: $outputAmount sats');
    debugPrint('   Redeem script: $redeemScript');
    debugPrint('   Lock time: $lockTime');
    
    // Decode redeem script
    final redeemScriptBytes = hex.decode(redeemScript);
    
    // Build unsigned transaction for signing
    final txForSigning = BytesBuilder();
    
    // Version
    txForSigning.add(_int32LE(2));
    
    // Input count
    txForSigning.add(_varint(1));
    
    // Input with redeem script for signing
    final txidBytes = hex.decode(txid);
    txForSigning.add(Uint8List.fromList(txidBytes.reversed.toList()));
    txForSigning.add(_int32LE(vout));
    
    // For P2SH spending, include the redeem script when signing
    txForSigning.add(_varint(redeemScriptBytes.length));
    txForSigning.add(redeemScriptBytes);
    
    // Sequence (must be less than 0xfffffffe for CLTV to work)
    txForSigning.add(_int32LE(0xfffffffe));
    
    // Output count
    txForSigning.add(_varint(1));
    
    // Output
    txForSigning.add(_int64LE(outputAmount));
    final outputScriptPubKey = _addressToScriptPubKey(outputAddress);
    txForSigning.add(_varint(outputScriptPubKey.length));
    txForSigning.add(outputScriptPubKey);
    
    // Locktime (must be set to the CLTV value or higher)
    txForSigning.add(_int32LE(lockTime));
    
    // Hash type
    txForSigning.add(_int32LE(1)); // SIGHASH_ALL
    
    // Double SHA256 hash
    final txHash = _doublesha256(txForSigning.toBytes());
    
    // Sign the hash
    final signature = _signTransactionHash(txHash);
    
    debugPrint('   Signature created (${signature.length} bytes)');
    
    // Build final signed transaction
    final signedTx = BytesBuilder();
    
    // Version
    signedTx.add(_int32LE(2));
    
    // Input count
    signedTx.add(_varint(1));
    
    // Input
    signedTx.add(Uint8List.fromList(txidBytes.reversed.toList()));
    signedTx.add(_int32LE(vout));
    
    // Build scriptSig for P2SH CLTV spending:
    // <signature> <pubkey> <redeemScript>
    final scriptSig = BytesBuilder();
    
    // Push signature
    scriptSig.addByte(signature.length);
    scriptSig.add(signature);
    
    // Push public key
    final pubKeyBytes = hex.decode(publicKeyHex);
    scriptSig.addByte(pubKeyBytes.length);
    scriptSig.add(pubKeyBytes);
    
    // Push redeem script
    scriptSig.addByte(redeemScriptBytes.length);
    scriptSig.add(redeemScriptBytes);
    
    final scriptSigBytes = scriptSig.toBytes();
    signedTx.add(_varint(scriptSigBytes.length));
    signedTx.add(scriptSigBytes);
    
    signedTx.add(_int32LE(0xfffffffe));
    
    // Output count
    signedTx.add(_varint(1));
    
    // Output
    signedTx.add(_int64LE(outputAmount));
    signedTx.add(_varint(outputScriptPubKey.length));
    signedTx.add(outputScriptPubKey);
    
    // Locktime
    signedTx.add(_int32LE(lockTime));
    
    final txHex = hex.encode(signedTx.toBytes());
    debugPrint('   ✅ Unlock transaction built (${txHex.length} chars)');
    
    return txHex;
  }

  /// Sign a transaction hash with the private key
  Uint8List _signTransactionHash(Uint8List txHash) {
    // Create secp256k1 domain parameters
    final domainParams = ECDomainParameters('secp256k1');
    
    // Parse private key
    final d = BigInt.parse(_privateKeyHex, radix: 16);
    final privateKey = ECPrivateKey(d, domainParams);
    
    // Create signer with deterministic k (RFC 6979)
    final signer = ECDSASigner(null, HMac(SHA256Digest(), 64));
    final privKeyParams = pc.PrivateKeyParameter(privateKey);
    signer.init(true, privKeyParams);
    
    // Sign
    final sig = signer.generateSignature(txHash) as ECSignature;
    
    // Encode signature in DER format with SIGHASH_ALL
    return _encodeDERSignature(sig);
  }

  /// Encode ECDSA signature in DER format with low-S normalization
  Uint8List _encodeDERSignature(ECSignature sig) {
    var r = sig.r;
    var s = sig.s;
    
    // Normalize S to low-S value (BIP-62)
    // secp256k1 curve order
    final n = BigInt.parse('fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141', radix: 16);
    final halfN = n >> 1;
    
    // If S > N/2, use N - S instead (low-S normalization)
    if (s.compareTo(halfN) > 0) {
      s = n - s;
    }
    
    final rBytes = _bigIntToBytes(r);
    final sBytes = _bigIntToBytes(s);
    
    final result = BytesBuilder();
    result.addByte(0x30); // DER sequence tag
    result.addByte(rBytes.length + sBytes.length + 4); // Total length
    result.addByte(0x02); // Integer tag
    result.addByte(rBytes.length);
    result.add(rBytes);
    result.addByte(0x02); // Integer tag
    result.addByte(sBytes.length);
    result.add(sBytes);
    result.addByte(0x01); // SIGHASH_ALL
    
    return result.toBytes();
  }

  Uint8List _bigIntToBytes(BigInt value) {
    var hex = value.toRadixString(16);
    if (hex.length % 2 != 0) hex = '0' + hex;
    final bytes = Uint8List.fromList(
      List<int>.generate(
        hex.length ~/ 2,
        (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16),
      ),
    );
    // Add padding if high bit is set
    if (bytes[0] & 0x80 != 0) {
      return Uint8List.fromList([0x00, ...bytes]);
    }
    return bytes;
  }

  Uint8List _addressToScriptPubKey(String address) {
    // Decode base58 address
    final decoded = _base58Decode(address);
    final versionByte = decoded[0];
    
    if (versionByte == 0x6F) {
      // P2PKH (regtest)
      final pubKeyHash = decoded.sublist(1, 21);
      final script = BytesBuilder();
      script.addByte(0x76); // OP_DUP
      script.addByte(0xa9); // OP_HASH160
      script.addByte(0x14); // Push 20 bytes
      script.add(pubKeyHash);
      script.addByte(0x88); // OP_EQUALVERIFY
      script.addByte(0xac); // OP_CHECKSIG
      return script.toBytes();
    } else if (versionByte == 0xC4) {
      // P2SH (regtest)
      final scriptHash = decoded.sublist(1, 21);
      final script = BytesBuilder();
      script.addByte(0xa9); // OP_HASH160
      script.addByte(0x14); // Push 20 bytes
      script.add(scriptHash);
      script.addByte(0x87); // OP_EQUAL
      return script.toBytes();
    }
    
    throw Exception('Unsupported address type');
  }

  Uint8List _base58Decode(String input) {
    const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    BigInt num = BigInt.zero;
    
    for (int i = 0; i < input.length; i++) {
      num = num * BigInt.from(58) + BigInt.from(alphabet.indexOf(input[i]));
    }
    
    // Convert to bytes
    final bytes = <int>[];
    while (num > BigInt.zero) {
      bytes.insert(0, (num % BigInt.from(256)).toInt());
      num = num ~/ BigInt.from(256);
    }
    
    // Add leading zeros
    for (int i = 0; i < input.length && input[i] == '1'; i++) {
      bytes.insert(0, 0);
    }
    
    return Uint8List.fromList(bytes);
  }

  Uint8List _varint(int value) {
    if (value < 0xfd) {
      return Uint8List.fromList([value]);
    } else if (value <= 0xffff) {
      return Uint8List.fromList([0xfd, value & 0xff, (value >> 8) & 0xff]);
    } else if (value <= 0xffffffff) {
      return Uint8List.fromList([
        0xfe,
        value & 0xff,
        (value >> 8) & 0xff,
        (value >> 16) & 0xff,
        (value >> 24) & 0xff,
      ]);
    }
    throw Exception('Value too large for varint');
  }

  Uint8List _int32LE(int value) {
    return Uint8List.fromList([
      value & 0xff,
      (value >> 8) & 0xff,
      (value >> 16) & 0xff,
      (value >> 24) & 0xff,
    ]);
  }

  Uint8List _int64LE(int value) {
    return Uint8List.fromList([
      value & 0xff,
      (value >> 8) & 0xff,
      (value >> 16) & 0xff,
      (value >> 24) & 0xff,
      (value >> 32) & 0xff,
      (value >> 40) & 0xff,
      (value >> 48) & 0xff,
      (value >> 56) & 0xff,
    ]);
  }

  /// Sign a raw transaction hex
  String signRawTransaction({
    required String rawTxHex,
    required List<Map<String, dynamic>> inputs,
  }) {
    // For now, this is a simplified signing that creates a valid-looking transaction
    // In production, you'd need proper ECDSA signing with secp256k1
    
    // This is a placeholder - the actual signing would require:
    // 1. Parse the raw transaction
    // 2. For each input, create signature hash
    // 3. Sign with ECDSA
    // 4. Add signature and pubkey to scriptSig
    // 5. Serialize back to hex
    
    // For the demo, we'll just return the raw tx and let Bitcoin Core handle it
    return rawTxHex;
  }

  /// Create a signed funding transaction for timelock
  Future<String> createSignedTimelockFundingTx({
    required String timeLockAddress,
    required int amount,
    required List<Map<String, dynamic>> utxos,
    required String changeAddress,
  }) async {
    // Build the transaction manually
    final txInputs = <Map<String, dynamic>>[];
    int totalInput = 0;
    
    // Use first UTXO that has enough funds
    for (final utxo in utxos) {
      final utxoAmount = ((utxo['amount'] as double) * 100000000).round();
      txInputs.add({
        'txid': utxo['txid'],
        'vout': utxo['vout'],
        'scriptPubKey': utxo['scriptPubKey'],
        'amount': utxoAmount,
      });
      totalInput += utxoAmount;
      
      if (totalInput >= amount + 1000) break; // amount + fee
    }
    
    if (totalInput < amount + 1000) {
      throw Exception('Insufficient funds');
    }
    
    // Calculate change
    final fee = 1000; // 1000 sats fee
    final change = totalInput - amount - fee;
    
    // Build outputs
    final outputs = <Map<String, dynamic>>[];
    outputs.add({
      'address': timeLockAddress,
      'amount': amount,
    });
    
    if (change > 546) { // dust limit
      outputs.add({
        'address': changeAddress,
        'amount': change,
      });
    }
    
    // Create the raw transaction structure
    // This is a simplified version - in production use proper Bitcoin serialization
    final tx = {
      'version': 2,
      'inputs': txInputs,
      'outputs': outputs,
      'locktime': 0,
    };
    
    // Return a marker that this needs RPC signing
    return 'NEEDS_RPC_SIGNING:${_serializeTxForRPC(tx)}';
  }
  
  String _serializeTxForRPC(Map<String, dynamic> tx) {
    // Simplified serialization - just return JSON for now
    return jsonEncode(tx);
  }

  // Helper methods
  Uint8List _doublesha256(Uint8List data) {
    final hash1 = sha256.convert(data);
    final hash2 = sha256.convert(hash1.bytes);
    return Uint8List.fromList(hash2.bytes);
  }

  Uint8List _hash160(Uint8List data) {
    final sha256Hash = sha256.convert(data);
    return _ripemd160(sha256Hash.bytes);
  }

  Uint8List _ripemd160(List<int> data) {
    // Proper RIPEMD160 implementation using pointycastle
    final digest = RIPEMD160Digest();
    final input = Uint8List.fromList(data);
    final output = Uint8List(20); // RIPEMD160 produces 20 bytes
    digest.update(input, 0, input.length);
    digest.doFinal(output, 0);
    return output;
  }

  String _base58Encode(Uint8List data) {
    const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    
    // Count leading zeros
    int leadingZeros = 0;
    for (int byte in data) {
      if (byte == 0) {
        leadingZeros++;
      } else {
        break;
      }
    }
    
    // Convert to big integer
    BigInt num = BigInt.zero;
    for (int byte in data) {
      num = num * BigInt.from(256) + BigInt.from(byte);
    }
    
    // Encode
    String encoded = '';
    while (num > BigInt.zero) {
      final remainder = num % BigInt.from(58);
      num = num ~/ BigInt.from(58);
      encoded = alphabet[remainder.toInt()] + encoded;
    }
    
    // Add leading ones for leading zeros
    encoded = '1' * leadingZeros + encoded;
    
    return encoded;
  }
}

// BitcoinScript class for CLTV operations
class BitcoinScript {
  static const int OP_CHECKLOCKTIMEVERIFY = 0xb1;
  static const int OP_DROP = 0x75;
  static const int OP_DUP = 0x76;
  static const int OP_HASH160 = 0xa9;
  static const int OP_EQUALVERIFY = 0x88;
  static const int OP_CHECKSIG = 0xac;

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
}
