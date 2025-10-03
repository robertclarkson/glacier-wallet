import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';

class BitcoinTransaction {
  final int version;
  final List<TransactionInput> inputs;
  final List<TransactionOutput> outputs;
  final int lockTime;

  BitcoinTransaction({
    this.version = 1,
    required this.inputs,
    required this.outputs,
    this.lockTime = 0,
  });

  /// Serialize transaction for signing
  Uint8List serialize({bool forSigning = false, int? inputIndex}) {
    final buffer = BytesBuilder();
    
    // Version (4 bytes, little endian)
    buffer.add(_intToLittleEndian(version, 4));
    
    // Input count
    buffer.add(_varInt(inputs.length));
    
    // Inputs
    for (int i = 0; i < inputs.length; i++) {
      final input = inputs[i];
      buffer.add(input.serialize(
        forSigning: forSigning,
        isSigningInput: forSigning && i == inputIndex,
      ));
    }
    
    // Output count
    buffer.add(_varInt(outputs.length));
    
    // Outputs
    for (final output in outputs) {
      buffer.add(output.serialize());
    }
    
    // Lock time (4 bytes, little endian)
    buffer.add(_intToLittleEndian(lockTime, 4));
    
    return buffer.toBytes();
  }

  /// Get transaction hash (double SHA256)
  String getTransactionId() {
    final serialized = serialize();
    final hash1 = sha256.convert(serialized);
    final hash2 = sha256.convert(hash1.bytes);
    return hex.encode(hash2.bytes.reversed.toList());
  }

  static Uint8List _intToLittleEndian(int value, int bytes) {
    final result = Uint8List(bytes);
    for (int i = 0; i < bytes; i++) {
      result[i] = (value >> (i * 8)) & 0xFF;
    }
    return result;
  }

  static Uint8List _varInt(int value) {
    if (value < 0xFD) {
      return Uint8List.fromList([value]);
    } else if (value <= 0xFFFF) {
      return Uint8List.fromList([0xFD, value & 0xFF, (value >> 8) & 0xFF]);
    } else if (value <= 0xFFFFFFFF) {
      return Uint8List.fromList([
        0xFE,
        value & 0xFF,
        (value >> 8) & 0xFF,
        (value >> 16) & 0xFF,
        (value >> 24) & 0xFF,
      ]);
    } else {
      return Uint8List.fromList([
        0xFF,
        value & 0xFF,
        (value >> 8) & 0xFF,
        (value >> 16) & 0xFF,
        (value >> 24) & 0xFF,
        (value >> 32) & 0xFF,
        (value >> 40) & 0xFF,
        (value >> 48) & 0xFF,
        (value >> 56) & 0xFF,
      ]);
    }
  }
}

class TransactionInput {
  final String previousTxId;
  final int outputIndex;
  final Uint8List scriptSig;
  final int sequence;

  TransactionInput({
    required this.previousTxId,
    required this.outputIndex,
    required this.scriptSig,
    this.sequence = 0xFFFFFFFF,
  });

  Uint8List serialize({bool forSigning = false, bool isSigningInput = false}) {
    final buffer = BytesBuilder();
    
    // Previous transaction hash (32 bytes, reversed)
    final txHash = hex.decode(previousTxId).reversed.toList();
    buffer.add(txHash);
    
    // Output index (4 bytes, little endian)
    buffer.add(BitcoinTransaction._intToLittleEndian(outputIndex, 4));
    
    // Script length and script
    if (forSigning && !isSigningInput) {
      // Empty script for non-signing inputs
      buffer.add([0]);
    } else {
      buffer.add(BitcoinTransaction._varInt(scriptSig.length));
      buffer.add(scriptSig);
    }
    
    // Sequence (4 bytes, little endian)
    buffer.add(BitcoinTransaction._intToLittleEndian(sequence, 4));
    
    return buffer.toBytes();
  }
}

class TransactionOutput {
  final int value; // in satoshis
  final Uint8List scriptPubKey;

  TransactionOutput({
    required this.value,
    required this.scriptPubKey,
  });

  Uint8List serialize() {
    final buffer = BytesBuilder();
    
    // Value (8 bytes, little endian)
    buffer.add(BitcoinTransaction._intToLittleEndian(value, 8));
    
    // Script length and script
    buffer.add(BitcoinTransaction._varInt(scriptPubKey.length));
    buffer.add(scriptPubKey);
    
    return buffer.toBytes();
  }
}
