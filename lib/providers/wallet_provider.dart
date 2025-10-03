import 'package:flutter/foundation.dart';
import 'package:convert/convert.dart';
import '../utils/bitcoin_wallet.dart';
import '../utils/bitcoin_script.dart' as script;
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
        // Try to import wallet address to Bitcoin Core (optional, might fail with descriptor wallets)
        try {
          await _rpc!.call('importaddress', [_wallet!.address, '', false]);
          debugPrint('✅ [WalletProvider] Address imported to Bitcoin Core');
        } catch (e) {
          debugPrint('⚠️ [WalletProvider] Could not import address (this is OK for descriptor wallets): $e');
        }
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
          
          return {
            'txid': utxo['txid'],
            'vout': utxo['vout'],
            'address': utxo['scriptPubKey']?['address'] ?? _wallet!.address,
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
      final mempool = await _rpc!.call('getrawmempool', [true]);
      final confirmed = await _rpc!.call('listtransactions', ['*', 100]);
      
      _timeLockTransactions = [];
      
      // Process mempool transactions
      if (mempool != null && mempool is Map) {
        for (var txid in mempool.keys) {
          final tx = await _rpc!.call('getrawtransaction', [txid, true]);
          if (tx != null && _isTimeLockTransaction(tx)) {
            _timeLockTransactions.add(_parseTimeLockTransaction(tx, 'pending'));
          }
        }
      }
      
      // Process confirmed transactions
      if (confirmed != null && confirmed is List) {
        for (var tx in confirmed) {
          final txid = tx['txid'];
          final rawTx = await _rpc!.call('getrawtransaction', [txid, true]);
          if (rawTx != null && _isTimeLockTransaction(rawTx)) {
            final status = _getTransactionStatus(rawTx);
            _timeLockTransactions.add(_parseTimeLockTransaction(rawTx, status));
          }
        }
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [WalletProvider] Failed to load timelock transactions: $e');
    }
  }

  /// Check if transaction is a time-locked transaction
  bool _isTimeLockTransaction(Map<String, dynamic> tx) {
    try {
      final vout = tx['vout'] as List?;
      if (vout == null || vout.isEmpty) return false;
      
      for (var output in vout) {
        final scriptPubKey = output['scriptPubKey'];
        if (scriptPubKey != null) {
          final asm = scriptPubKey['asm'] ?? '';
          if (asm.contains('OP_CHECKLOCKTIMEVERIFY') || asm.contains('OP_CLTV')) {
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get transaction status
  String _getTransactionStatus(Map<String, dynamic> tx) {
    final locktime = tx['locktime'] ?? 0;
    
    if (locktime > _blockHeight) {
      return 'locked';
    }
    
    // Check if already spent
    // This is simplified - in production you'd check if outputs are spent
    return 'ready';
  }

  /// Parse time-locked transaction
  Map<String, dynamic> _parseTimeLockTransaction(Map<String, dynamic> tx, String status) {
    final locktime = tx['locktime'] ?? 0;
    final vout = tx['vout'] as List? ?? [];
    
    double amount = 0.0;
    for (var output in vout) {
      amount += (output['value'] ?? 0.0).toDouble();
    }
    
    return {
      'txid': tx['txid'],
      'amount': amount,
      'locktime': locktime,
      'status': status,
      'confirmations': tx['confirmations'] ?? 0,
    };
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

      if (totalInputSats < amountSats + 1000) {
        throw Exception('Insufficient funds. Need ${((amountSats + 1000) / 100000000).toStringAsFixed(8)} BTC');
      }

      // Build transaction inputs
      final inputs = selectedUTXOs.map((utxo) => {
        'txid': utxo['txid'],
        'vout': utxo['vout'],
      }).toList();

      // Create timelock script
      final scriptBytes = script.BitcoinScript.createCLTVScript(_wallet!.publicKeyHash, blockHeight);
      final timeLockScript = hex.encode(scriptBytes);
      debugPrint('   Timelock script: $timeLockScript');

      // Build transaction with timelock output
      final rawTx = await _rpc!.call('createrawtransaction', [
        inputs,
        [
          {
            'data': timeLockScript,
          },
        ],
        blockHeight,
      ]);

      if (rawTx == null) {
        throw Exception('Failed to create raw transaction');
      }

      debugPrint('   Raw transaction created');

      // Fund the transaction (adds change output and sets fee)
      final fundedResult = await _rpc!.call('fundrawtransaction', [rawTx]);
      if (fundedResult == null) {
        throw Exception('Failed to fund transaction');
      }

      final fundedTx = fundedResult['hex'];
      final fee = fundedResult['fee'];
      debugPrint('   Transaction funded, fee: ${fee} BTC');

      // Sign the transaction
      final signedResult = await _rpc!.call('signrawtransactionwithwallet', [fundedTx]);
      if (signedResult == null || signedResult['complete'] != true) {
        throw Exception('Failed to sign transaction');
      }

      final signedTx = signedResult['hex'];
      debugPrint('   Transaction signed');

      // Broadcast the transaction
      final txid = await _rpc!.call('sendrawtransaction', [signedTx]);
      if (txid == null) {
        throw Exception('Failed to broadcast transaction');
      }

      debugPrint('✅ [WalletProvider] Timelock transaction broadcast!');
      debugPrint('   TXID: $txid');

      // Update balance and transactions
      await updateBalance();

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
        
        if (totalInputSats >= amountSats + 1000) {
          break;
        }
      }

      debugPrint('   Selected ${selectedUTXOs.length} UTXOs');
      debugPrint('   Total input: ${(totalInputSats / 100000000).toStringAsFixed(8)} BTC');

      if (totalInputSats < amountSats + 1000) {
        throw Exception('Insufficient funds');
      }

      // Build transaction inputs
      final inputs = selectedUTXOs.map((utxo) => {
        'txid': utxo['txid'],
        'vout': utxo['vout'],
      }).toList();

      // Create timelock script
      final scriptBytes = script.BitcoinScript.createCLTVScript(_wallet!.publicKeyHash, unlockTimestamp);
      final timeLockScript = hex.encode(scriptBytes);
      debugPrint('   Timelock script: $timeLockScript');

      // Build transaction
      final rawTx = await _rpc!.call('createrawtransaction', [
        inputs,
        [
          {
            'data': timeLockScript,
          },
        ],
        unlockTimestamp,
      ]);

      if (rawTx == null) {
        throw Exception('Failed to create raw transaction');
      }

      debugPrint('   Raw transaction created');

      // Fund the transaction
      final fundedResult = await _rpc!.call('fundrawtransaction', [rawTx]);
      if (fundedResult == null) {
        throw Exception('Failed to fund transaction');
      }

      final fundedTx = fundedResult['hex'];
      final fee = fundedResult['fee'];
      debugPrint('   Transaction funded, fee: ${fee} BTC');

      // Sign the transaction
      final signedResult = await _rpc!.call('signrawtransactionwithwallet', [fundedTx]);
      if (signedResult == null || signedResult['complete'] != true) {
        throw Exception('Failed to sign transaction');
      }

      final signedTx = signedResult['hex'];
      debugPrint('   Transaction signed');

      // Broadcast the transaction
      final txid = await _rpc!.call('sendrawtransaction', [signedTx]);
      if (txid == null) {
        throw Exception('Failed to broadcast transaction');
      }

      debugPrint('✅ [WalletProvider] Timelock transaction broadcast!');
      debugPrint('   TXID: $txid');

      // Update balance and transactions
      await updateBalance();

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

      // Get the locked transaction
      final lockedTx = await _rpc!.call('getrawtransaction', [txid, true]);
      if (lockedTx == null) {
        throw Exception('Transaction not found');
      }

      final locktime = lockedTx['locktime'] ?? 0;
      debugPrint('   Locktime: $locktime');
      debugPrint('   Current block: $_blockHeight');

      // Verify locktime has passed
      if (locktime > 500000000) {
        // Timestamp
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        if (locktime > now) {
          throw Exception('Transaction is still locked (time-based)');
        }
      } else {
        // Block height
        if (locktime > _blockHeight) {
          throw Exception('Transaction is still locked (block-based)');
        }
      }

      // Find the timelock output
      final vout = lockedTx['vout'] as List;
      int? timeLockVout;
      double? timeLockAmount;

      for (var i = 0; i < vout.length; i++) {
        final output = vout[i];
        final scriptPubKey = output['scriptPubKey'];
        if (scriptPubKey != null) {
          final asm = scriptPubKey['asm'] ?? '';
          if (asm.contains('OP_CHECKLOCKTIMEVERIFY')) {
            timeLockVout = i;
            timeLockAmount = (output['value'] ?? 0.0).toDouble();
            break;
          }
        }
      }

      if (timeLockVout == null) {
        throw Exception('No timelock output found');
      }

      debugPrint('   Found timelock output at index $timeLockVout');
      debugPrint('   Amount: ${timeLockAmount?.toStringAsFixed(8)} BTC');

      // Create spending transaction
      final spendTx = await _rpc!.call('createrawtransaction', [
        [
          {
            'txid': txid,
            'vout': timeLockVout,
          }
        ],
        {
          _wallet!.address: timeLockAmount! - 0.0001, // Subtract small fee
        },
      ]);

      if (spendTx == null) {
        throw Exception('Failed to create spending transaction');
      }

      // Sign the spending transaction
      final signedResult = await _rpc!.call('signrawtransactionwithwallet', [spendTx]);
      if (signedResult == null || signedResult['complete'] != true) {
        throw Exception('Failed to sign spending transaction');
      }

      final signedTx = signedResult['hex'];

      // Broadcast
      final spendTxid = await _rpc!.call('sendrawtransaction', [signedTx]);
      if (spendTxid == null) {
        throw Exception('Failed to broadcast spending transaction');
      }

      debugPrint('✅ [WalletProvider] Unlock transaction broadcast!');
      debugPrint('   Spend TXID: $spendTxid');

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
