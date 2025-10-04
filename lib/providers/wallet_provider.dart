import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../utils/bitcoin_wallet.dart';
import '../services/bitcoin_rpc.dart';

/// Provider for managing wallet state and Bitcoin operations
class WalletProvider with ChangeNotifier {
  BitcoinWallet? _wallet;
  BitcoinRPC? _rpc;
  double _balance = 0.0;
  int _blockHeight = 0;
  bool _isConnected = false;
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _utxos = [];
  List<Map<String, dynamic>> _timeLockTransactions = [];

  // Getters
  BitcoinWallet? get wallet => _wallet;
  double get balance => _balance;
  int get blockHeight => _blockHeight;
  bool get isConnected => _isConnected;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get utxos => _utxos;
  List<Map<String, dynamic>> get timeLockTransactions => _timeLockTransactions;
  
  /// Get total locked balance (funds in timelock transactions that haven't been unlocked)
  double get lockedBalance {
    return _timeLockTransactions
        .where((tx) => tx['status'] != 'unlocked')
        .fold(0.0, (sum, tx) => sum + (tx['amount'] as double));
  }
  
  /// Get unlocked balance (regular wallet balance)
  /// Locked funds are in separate P2SH addresses and are scanned separately
  double get unlockedBalance => _balance;

  /// Generate a new wallet
  void generateNewWallet() {
    try {
      _wallet = BitcoinWallet.generate();
      debugPrint('🔑 [WalletProvider] Generated new wallet: ${_wallet!.address}');
      debugPrint('   Public Key: ${_wallet!.publicKeyHex}');
      notifyListeners();
    } catch (e) {
      _error = 'Failed to generate wallet: $e';
      debugPrint('❌ [WalletProvider] Error generating wallet: $e');
      notifyListeners();
    }
  }

  /// Connect to Bitcoin node
  Future<void> connectToNode({
    required String host,
    required int port,
    required String username,
    required String password,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _rpc = BitcoinRPC(
        host: host,
        port: port,
        username: username,
        password: password,
      );
      
      await _testConnection();
      
      if (_isConnected && _wallet != null) {
        await refresh();
      }
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to connect: $e';
      _isConnected = false;
      _isLoading = false;
      debugPrint('❌ [WalletProvider] Connection error: $e');
      notifyListeners();
    }
  }

  /// Disconnect from the node
  void disconnect() {
    _rpc = null;
    _isConnected = false;
    _balance = 0.0;
    _blockHeight = 0;
    _utxos = [];
    _timeLockTransactions = [];
    notifyListeners();
  }

  /// Refresh wallet data
  Future<void> refresh() async {
    if (_rpc == null || _wallet == null) return;

    try {
      await _updateBlockchainInfo();
      await _updateBalance();
      await _updateUTXOs();
      await _loadTimeLockTransactions();
    } catch (e) {
      _error = 'Failed to refresh: $e';
      debugPrint('❌ [WalletProvider] Refresh error: $e');
      notifyListeners();
    }
  }

  /// Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Test RPC connection
  Future<void> _testConnection() async {
    try {
      final info = await _rpc!.call('getblockchaininfo');
      _isConnected = info != null;
      if (_isConnected) {
        _blockHeight = info['blocks'] ?? 0;
      }
      notifyListeners();
    } catch (e) {
      _isConnected = false;
      _error = 'Connection failed: $e';
      notifyListeners();
    }
  }

  /// Test RPC connection
  Future<void> updateBalance() async {
    if (_rpc == null || _wallet == null) return;

    try {
      await _updateBlockchainInfo();
      await _updateBalance();
      await _updateUTXOs();
      await _loadTimeLockTransactions();
    } catch (e) {
      _error = 'Failed to update balance: $e';
      notifyListeners();
    }
  }

  /// Update blockchain information
  Future<void> _updateBlockchainInfo() async {
    try {
      final info = await _rpc!.call('getblockchaininfo');
      if (info != null) {
        _blockHeight = info['blocks'] ?? 0;
      }
    } catch (e) {
      debugPrint('❌ [WalletProvider] Failed to update blockchain info: $e');
    }
  }

  /// Update balance from blockchain
  Future<void> _updateBalance() async {
    try {
      final result = await _rpc!.call('scantxoutset', [
        'start',
        ['addr(${_wallet!.address})']
      ]);

      if (result != null) {
        _balance = (result['total_amount'] ?? 0.0).toDouble();
        
        final unspents = result['unspents'] as List? ?? [];
        debugPrint('📍 [WalletProvider] Found ${unspents.length} UTXOs');
        debugPrint('   Total balance: ${_balance.toStringAsFixed(8)} BTC');
        
        // Count mature UTXOs
        int matureCount = 0;
        for (var utxo in unspents) {
          final height = utxo['height'] ?? 0;
          final confirmations = _blockHeight - height + 1;
          if (confirmations >= 100) {
            matureCount++;
          }
        }
        debugPrint('   Mature UTXOs (100+ confirmations): $matureCount');
      }
    } catch (e) {
      debugPrint('❌ [WalletProvider] Failed to update balance: $e');
    }
  }

  /// Update UTXOs list for spending
  Future<void> _updateUTXOs() async {
    try {
      final result = await _rpc!.call('scantxoutset', [
        'start',
        ['addr(${_wallet!.address})']
      ]);

      if (result != null) {
        final unspents = result['unspents'] as List? ?? [];
        _utxos = unspents.map((utxo) {
          final height = utxo['height'] ?? 0;
          final confirmations = _blockHeight - height + 1;
          
          // scriptPubKey can be either a string or a map, handle both cases
          String address = _wallet!.address;
          final scriptPubKey = utxo['scriptPubKey'];
          if (scriptPubKey is Map && scriptPubKey.containsKey('address')) {
            address = scriptPubKey['address'] ?? _wallet!.address;
          }
          
          return {
            'txid': utxo['txid'],
            'vout': utxo['vout'],
            'address': address,
            'amount': (utxo['amount'] ?? 0.0).toDouble(),
            'height': height,
            'confirmations': confirmations,
          };
        }).toList();
        
        debugPrint('💰 [WalletProvider] Updated UTXO list: ${_utxos.length} total UTXOs');
      }
    } catch (e) {
      debugPrint('❌ [WalletProvider] Failed to update UTXOs: $e');
    }
  }

  /// Load time-locked transactions
  Future<void> _loadTimeLockTransactions() async {
    try {
      // We manage timelocks entirely in-app, so we just keep the manually added ones
      // No need to query Bitcoin Core's wallet since we don't use it
      
      // Just preserve the manually added timelocks (those with 'timeLockAddress' field)
      final manualTimelocks = _timeLockTransactions.where((tx) => 
        tx.containsKey('timeLockAddress')
      ).toList();
      
      debugPrint('📋 [WalletProvider] Managing timelocks in-app: ${manualTimelocks.length} timelocks');
      for (var tx in manualTimelocks) {
        debugPrint('   - TXID: ${tx['txid']}, Status: ${tx['status']}, Unlock TxID: ${tx['unlockTxId']}');
      }
      
      _timeLockTransactions = manualTimelocks;
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [WalletProvider] Failed to load timelock transactions: $e');
    }
  }

  /// Create time-locked transaction from block height
  Future<String?> createTimeLockTransactionFromBlockHeight({
    required double amount,
    required int blockHeight,
  }) async {
    if (_rpc == null || _wallet == null) return null;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Ensure we have fresh UTXO data
      await _updateBlockchainInfo();
      await _updateUTXOs();
      
      // Convert amount to satoshis
      final amountSats = (amount * 100000000).round();
      
      debugPrint('🔒 [WalletProvider] Starting timelock creation (Block Height)...');
      debugPrint('   Amount: ${amount.toStringAsFixed(8)} BTC ($amountSats sats)');
      debugPrint('   Unlock Block: $blockHeight (current: $_blockHeight)');
      debugPrint('   Total UTXOs in wallet: ${_utxos.length}');

      // Validate block height
      if (blockHeight <= _blockHeight) {
        throw Exception('Block height must be in the future (current: $_blockHeight)');
      }

      // Filter for mature UTXOs (100+ confirmations)
      final availableUTXOs = _utxos.where((utxo) {
        final confirmations = utxo['confirmations'] as int? ?? 0;
        return confirmations >= 100;
      }).toList();

      debugPrint('   Available UTXOs (100+ confirmations): ${availableUTXOs.length}');

      if (availableUTXOs.isEmpty) {
        throw Exception('No spendable UTXOs available. Coinbase outputs need 100 confirmations.');
      }

      // Select UTXOs for spending
      final selectedUTXOs = <Map<String, dynamic>>[];
      int totalInputSats = 0;
      
      for (var utxo in availableUTXOs) {
        selectedUTXOs.add(utxo);
        totalInputSats += ((utxo['amount'] as double) * 100000000).round();
        
        // Check if we have enough (including fee)
        if (totalInputSats >= amountSats + 1000) {
          break;
        }
      }

      debugPrint('   Selected ${selectedUTXOs.length} UTXOs');
      debugPrint('   Total input: ${(totalInputSats / 100000000).toStringAsFixed(8)} BTC');

      if (totalInputSats < amountSats + 5000) {
        throw Exception('Insufficient funds. Need ${((amountSats + 5000) / 100000000).toStringAsFixed(8)} BTC');
      }

      // Generate timelock P2SH address
      final timeLockAddress = _wallet!.generateTimeLockAddressFromBlockHeight(blockHeight);
      debugPrint('   Timelock address: $timeLockAddress');

      // Build transaction inputs with sequence number to enable locktime
      final inputsForSigning = selectedUTXOs.map((utxo) => {
        'txid': utxo['txid'],
        'vout': utxo['vout'],
        'amount': ((utxo['amount'] as double) * 100000000).round(),
      }).toList();

      // Calculate change amount (input - amount - fee)
      final feeSats = 5000; // 5000 sats fee to meet min relay fee
      final changeSats = totalInputSats - amountSats - feeSats;
      
      // Build outputs: timelock address + change to our address
      final outputsForSigning = <String, int>{};
      outputsForSigning[timeLockAddress] = amountSats;
      if (changeSats > 0) {
        outputsForSigning[_wallet!.address] = changeSats;
      }

      debugPrint('   Timelock output: ${amountSats / 100000000.0} BTC');
      debugPrint('   Fee: ${feeSats / 100000000.0} BTC');
      debugPrint('   Change: ${changeSats / 100000000.0} BTC');

      // Build and sign the transaction using our wallet
      // Note: locktime=0 for funding transaction. The CLTV check happens when spending FROM the timelocked address
      final signedTx = _wallet!.buildAndSignTransaction(
        inputs: inputsForSigning,
        outputs: outputsForSigning,
        locktime: 0, // No locktime on funding tx
      );
      
      debugPrint('   Transaction built and signed');

      // Broadcast the transaction
      final txid = await _rpc!.call('sendrawtransaction', [signedTx]);
      if (txid == null) {
        throw Exception('Failed to broadcast transaction');
      }

      debugPrint('✅ [WalletProvider] Timelock transaction broadcast!');
      debugPrint('   TXID: $txid');

      // Add the timelock transaction to our tracked list with all info needed for spending
      _timeLockTransactions.add({
        'txid': txid,
        'amount': amountSats / 100000000.0,
        'amountSats': amountSats, // Store sats for spending
        'locktime': blockHeight,
        'blockHeight': blockHeight, // Add this for home screen compatibility
        'lockTimeType': 'blockheight',
        'unlockTime': null, // Block height doesn't have a specific time
        'status': 'locked',
        'confirmations': 0,
        'timeLockAddress': timeLockAddress,
        'vout': 0, // The timelock output is the first output (index 0)
      });
      
      debugPrint('📋 [WalletProvider] Added timelock to list. Total timelocks: ${_timeLockTransactions.length}');
      debugPrint('   List contents: $_timeLockTransactions');

      // Refresh balance to remove spent UTXOs from the count
      // The spent UTXOs should no longer appear in scantxoutset once the tx is in mempool
      await _updateBlockchainInfo();
      await _updateBalance();
      await _updateUTXOs();

      notifyListeners();
      await _updateUTXOs();

      _isLoading = false;
      notifyListeners();

      return txid;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      debugPrint('❌ [WalletProvider] Error creating timelock transaction: $e');
      notifyListeners();
      return null;
    }
  }

  /// Create time-locked transaction from DateTime
  Future<String?> createTimeLockTransactionFromDateTime({
    required double amount,
    required DateTime unlockTime,
  }) async {
    if (_rpc == null || _wallet == null) return null;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Ensure we have fresh UTXO data
      await _updateBlockchainInfo();
      await _updateUTXOs();
      
      // Convert amount to satoshis
      final amountSats = (amount * 100000000).round();
      final unlockTimestamp = unlockTime.millisecondsSinceEpoch ~/ 1000;

      debugPrint('🔒 [WalletProvider] Starting timelock creation (DateTime)...');
      debugPrint('   Amount: ${amount.toStringAsFixed(8)} BTC ($amountSats sats)');
      debugPrint('   Unlock Time: $unlockTime');
      debugPrint('   Total UTXOs in wallet: ${_utxos.length}');

      // Validate unlock time
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (unlockTimestamp <= now) {
        throw Exception('Unlock time must be in the future');
      }

      // Filter for mature UTXOs (100+ confirmations)
      final availableUTXOs = _utxos.where((utxo) {
        final confirmations = utxo['confirmations'] as int? ?? 0;
        return confirmations >= 100;
      }).toList();

      debugPrint('   Available UTXOs (100+ confirmations): ${availableUTXOs.length}');

      if (availableUTXOs.isEmpty) {
        throw Exception('No spendable UTXOs available. Coinbase outputs need 100 confirmations.');
      }

      // Select UTXOs for spending
      final selectedUTXOs = <Map<String, dynamic>>[];
      int totalInputSats = 0;
      
      for (var utxo in availableUTXOs) {
        selectedUTXOs.add(utxo);
        totalInputSats += ((utxo['amount'] as double) * 100000000).round();
        
        if (totalInputSats >= amountSats + 5000) {
          break;
        }
      }

      debugPrint('   Selected ${selectedUTXOs.length} UTXOs');
      debugPrint('   Total input: ${(totalInputSats / 100000000).toStringAsFixed(8)} BTC');

      if (totalInputSats < amountSats + 5000) {
        throw Exception('Insufficient funds');
      }

      // Generate timelock P2SH address
      final timeLockAddress = _wallet!.generateTimeLockAddress(unlockTime);
      debugPrint('   Timelock address: $timeLockAddress');

      // Build transaction inputs with sequence number to enable locktime
      final inputsForSigning = selectedUTXOs.map((utxo) => {
        'txid': utxo['txid'],
        'vout': utxo['vout'],
        'amount': ((utxo['amount'] as double) * 100000000).round(),
      }).toList();

      // Calculate change amount (input - amount - fee)
      final feeSats = 5000; // 5000 sats fee to meet min relay fee
      final changeSats = totalInputSats - amountSats - feeSats;
      
      // Build outputs: timelock address + change to our address
      final outputsForSigning = <String, int>{};
      outputsForSigning[timeLockAddress] = amountSats;
      if (changeSats > 0) {
        outputsForSigning[_wallet!.address] = changeSats;
      }

      debugPrint('   Timelock output: ${amountSats / 100000000.0} BTC');
      debugPrint('   Fee: ${feeSats / 100000000.0} BTC');
      debugPrint('   Change: ${changeSats / 100000000.0} BTC');

      // Build and sign the transaction using our wallet
      // Note: locktime=0 for funding transaction. The CLTV check happens when spending FROM the timelocked address
      final signedTx = _wallet!.buildAndSignTransaction(
        inputs: inputsForSigning,
        outputs: outputsForSigning,
        locktime: 0, // No locktime on funding tx
      );
      
      debugPrint('   Transaction built and signed');

      // Broadcast the transaction
      final txid = await _rpc!.call('sendrawtransaction', [signedTx]);
      if (txid == null) {
        throw Exception('Failed to broadcast transaction');
      }

      debugPrint('✅ [WalletProvider] Timelock transaction broadcast!');
      debugPrint('   TXID: $txid');

      // Add the timelock transaction to our tracked list with all info needed for spending
      _timeLockTransactions.add({
        'txid': txid,
        'amount': amountSats / 100000000.0,
        'amountSats': amountSats, // Store sats for spending
        'locktime': unlockTimestamp,
        'lockTimeType': 'timestamp',
        'unlockTime': unlockTime.toIso8601String(),
        'status': 'locked',
        'confirmations': 0,
        'timeLockAddress': timeLockAddress,
        'vout': 0, // The timelock output is the first output (index 0)
      });
      
      debugPrint('📋 [WalletProvider] Added timelock to list. Total timelocks: ${_timeLockTransactions.length}');

      // Don't call updateBalance() here as it would clear our manually added timelock
      // Just update the blockchain info and UTXOs
      await _updateBlockchainInfo();
      await _updateBalance();
      await _updateUTXOs();

      _isLoading = false;
      notifyListeners();

      return txid;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      debugPrint('❌ [WalletProvider] Error creating timelock transaction: $e');
      notifyListeners();
      return null;
    }
  }

  /// Unlock and spend a time-locked transaction
  Future<String?> unlockTimeLockTransaction(String txid) async {
    if (_rpc == null || _wallet == null) return null;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('🔓 [WalletProvider] Starting unlock transaction...');
      debugPrint('   TXID: $txid');

      // Find the transaction in our stored list
      final storedTx = _timeLockTransactions.firstWhere(
        (tx) => tx['txid'] == txid,
        orElse: () => throw Exception('Transaction not found in timelock list'),
      );

      final locktime = storedTx['locktime'] as int;
      final timeLockAddress = storedTx['timeLockAddress'] as String;
      final amount = storedTx['amount'] as double;
      
      debugPrint('   Locktime: $locktime');
      debugPrint('   Current block: $_blockHeight');
      debugPrint('   Timelock address: $timeLockAddress');
      debugPrint('   Amount: $amount BTC');

      // Verify locktime has passed
      if (locktime > 500000000) {
        // Timestamp
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        if (locktime > now) {
          throw Exception('Transaction is still locked (time-based). Wait until ${DateTime.fromMillisecondsSinceEpoch(locktime * 1000)}');
        }
      } else {
        // Block height
        if (locktime > _blockHeight) {
          throw Exception('Transaction is still locked (block-based). Need to reach block $locktime (currently at $_blockHeight)');
        }
      }

      debugPrint('   ✓ Locktime has passed, can unlock now');
      
      // Get stored transaction details (no need to query blockchain)
      final timeLockVout = storedTx['vout'] as int? ?? 0; // Default to 0 if not stored
      // Handle old transactions that don't have amountSats field
      final timeLockSats = storedTx['amountSats'] as int? ?? ((storedTx['amount'] as double) * 100000000).round();
      
      debugPrint('   Using stored output: vout $timeLockVout, amount $timeLockSats sats');
      
      // Generate the redeem script (same as when we created the address)
      final redeemScriptBytes = BitcoinScript.createCLTVScript(_wallet!.publicKeyHash, locktime);
      final redeemScriptHex = redeemScriptBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      
      debugPrint('   Redeem script: $redeemScriptHex');
      
      // Build unlock transaction
      final outputSats = timeLockSats - 5000; // Subtract fee
      final signedTx = _wallet!.buildUnlockTransaction(
        txid: txid,
        vout: timeLockVout,
        amount: timeLockSats,
        outputAddress: _wallet!.address,
        outputAmount: outputSats,
        redeemScript: redeemScriptHex,
        lockTime: locktime,
      );

      debugPrint('   Transaction built and signed');

      // Broadcast
      final spendTxid = await _rpc!.call('sendrawtransaction', [signedTx]);
      if (spendTxid == null) {
        throw Exception('Failed to broadcast spending transaction');
      }

      debugPrint('✅ [WalletProvider] Unlock transaction broadcast!');
      debugPrint('   Spend TXID: $spendTxid');

      // Mark the timelock as unlocked
      storedTx['status'] = 'unlocked';
      storedTx['unlockTxId'] = spendTxid;
      
      debugPrint('   Marked transaction as unlocked: ${storedTx['txid']}');
      debugPrint('   Status: ${storedTx['status']}');
      debugPrint('   Unlock TxID: ${storedTx['unlockTxId']}');

      // Notify listeners first to update UI
      notifyListeners();

      // Update balance
      await refresh();

      _isLoading = false;
      notifyListeners();

      return spendTxid;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      debugPrint('❌ [WalletProvider] Error unlocking transaction: $e');
      notifyListeners();
      return null;
    }
  }

  /// Create time-locked transaction (DateTime version - wrapper)
  Future<String?> createTimeLockTransaction({
    required double amount,
    required DateTime unlockTime,
  }) async {
    return createTimeLockTransactionFromDateTime(
      amount: amount,
      unlockTime: unlockTime,
    );
  }

  /// Unlock time-locked transaction (wrapper for unlockTimeLockTransaction)
  Future<String?> unlockTimeLock(Map<String, dynamic> tx) async {
    final txid = tx['txid'] as String?;
    if (txid == null) return null;
    return unlockTimeLockTransaction(txid);
  }

  /// Check if a timelock transaction can be spent
  bool canSpendTimeLock(Map<String, dynamic> tx) {
    final locktime = tx['locktime'] as int? ?? 0;
    
    if (locktime > 500000000) {
      // Timestamp-based
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return locktime <= now;
    } else {
      // Block height-based
      return locktime <= _blockHeight;
    }
  }

  /// Generate blocks in regtest
  Future<void> generateBlocks(int count) async {
    if (_rpc == null || _wallet == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      debugPrint('⛏️ [WalletProvider] Generating $count blocks to ${_wallet!.address}');
      
      await _rpc!.call('generatetoaddress', [count, _wallet!.address]);
      
      debugPrint('✅ [WalletProvider] Generated $count blocks');
      
      // Refresh wallet data
      await refresh();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to generate blocks: $e';
      _isLoading = false;
      debugPrint('❌ [WalletProvider] Error generating blocks: $e');
      notifyListeners();
    }
  }
}
