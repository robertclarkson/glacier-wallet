import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

/// Bitcoin RPC client for regtest node communication
class BitcoinRPC {
  final String host;
  final int port;
  final String username;
  final String password;
  
  BitcoinRPC({
    this.host = '127.0.0.1',
    this.port = 18443, // Default regtest port
    this.username = 'bitcoin',
    this.password = 'bitcoin',
  });

  /// Make RPC call to Bitcoin node
  Future<dynamic> call(String method, [List<dynamic>? params]) async {
    final url = Uri.parse('http://$host:$port/');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Basic ${base64Encode(utf8.encode('$username:$password'))}',
    };
    
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'id': Random().nextInt(1000000),
      'method': method,
      'params': params ?? [],
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      final data = jsonDecode(response.body);
      
      if (data['error'] != null) {
        throw Exception('RPC Error: ${data['error']['message']}');
      }
      
      return data['result'];
    } catch (e) {
      throw Exception('Failed to connect to Bitcoin node: $e');
    }
  }

  /// Get blockchain info
  Future<Map<String, dynamic>> getBlockchainInfo() async {
    return await call('getblockchaininfo');
  }

  /// Get new address
  Future<String> getNewAddress([String? label]) async {
    return await call('getnewaddress', label != null ? [label] : []);
  }

  /// Get balance
  Future<double> getBalance() async {
    return await call('getbalance');
  }

  /// List unspent transaction outputs
  Future<List<dynamic>> listUnspent([int minConf = 1, int maxConf = 9999999]) async {
    return await call('listunspent', [minConf, maxConf]);
  }

  /// Send raw transaction
  Future<String> sendRawTransaction(String hexString) async {
    return await call('sendrawtransaction', [hexString]);
  }

  /// Get raw transaction
  Future<Map<String, dynamic>> getRawTransaction(String txid, [bool verbose = true]) async {
    return await call('getrawtransaction', [txid, verbose]);
  }

  /// Generate blocks (regtest only)
  Future<List<String>> generateToAddress(int numBlocks, String address) async {
    return List<String>.from(await call('generatetoaddress', [numBlocks, address]));
  }

  /// Get current block height
  Future<int> getBlockCount() async {
    return await call('getblockcount');
  }

  /// Get block hash by height
  Future<String> getBlockHash(int height) async {
    return await call('getblockhash', [height]);
  }

  /// Get block by hash
  Future<Map<String, dynamic>> getBlock(String hash, [int verbosity = 1]) async {
    return await call('getblock', [hash, verbosity]);
  }

  /// Import address for watching
  Future<void> importAddress(String address, [String label = '', bool rescan = false]) async {
    await call('importaddress', [address, label, rescan]);
  }

  /// Import private key (WIF format)
  Future<void> importPrivKey(String privKeyWIF, [String label = '', bool rescan = false]) async {
    await call('importprivkey', [privKeyWIF, label, rescan]);
  }

  /// Scan the UTXO set for specific addresses (better for watch-only)
  Future<Map<String, dynamic>> scanTxOutSet(List<String> addresses) async {
    final descriptors = addresses.map((addr) => 'addr($addr)').toList();
    return await call('scantxoutset', ['start', descriptors]);
  }

  /// Decode raw transaction
  Future<Map<String, dynamic>> decodeRawTransaction(String hexString) async {
    return await call('decoderawtransaction', [hexString]);
  }

  /// Create raw transaction
  Future<String> createRawTransaction(
    List<Map<String, dynamic>> inputs,
    Map<String, double> outputs,
    [int lockTime = 0]
  ) async {
    return await call('createrawtransaction', [inputs, outputs, lockTime]);
  }

  /// Fund raw transaction
  Future<Map<String, dynamic>> fundRawTransaction(String hexString) async {
    return await call('fundrawtransaction', [hexString]);
  }

  /// Sign raw transaction
  Future<Map<String, dynamic>> signRawTransactionWithWallet(String hexString) async {
    return await call('signrawtransactionwithwallet', [hexString]);
  }

  /// Send to address
  Future<String> sendToAddress(String address, double amount, [String comment = '']) async {
    return await call('sendtoaddress', [address, amount, comment]);
  }

  /// List loaded wallets
  Future<List<String>> listWallets() async {
    return List<String>.from(await call('listwallets'));
  }

  /// Create a new Bitcoin Core wallet
  Future<void> createWallet(String walletName, {bool disablePrivateKeys = true}) async {
    await call('createwallet', [walletName, disablePrivateKeys]);
  }

  /// Load an existing Bitcoin Core wallet
  Future<void> loadWallet(String walletName) async {
    await call('loadwallet', [walletName]);
  }

  /// Ensure a wallet is loaded in Bitcoin Core (load default if needed)
  Future<void> ensureWalletLoaded({String walletName = 'glacier_watch'}) async {
    try {
      // Check if any wallet is loaded
      final wallets = await listWallets();
      
      if (wallets.isNotEmpty) {
        // A wallet is already loaded, we're good
        return;
      }
      
      // No wallet loaded, try to load the default one
      try {
        await loadWallet(walletName);
      } catch (e) {
        // Wallet doesn't exist, create it as watch-only
        await createWallet(walletName, disablePrivateKeys: true);
      }
    } catch (e) {
      throw Exception('Failed to ensure wallet is loaded: $e');
    }
  }

  /// Test connection to Bitcoin node
  Future<bool> testConnection() async {
    try {
      await getBlockchainInfo();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get median time past (for CLTV calculations)
  Future<int> getMedianTimePast() async {
    final blockCount = await getBlockCount();
    final blockHash = await getBlockHash(blockCount);
    final block = await getBlock(blockHash);
    return block['mediantime'] ?? block['time'];
  }

  /// Estimate fee rate
  Future<double> estimateSmartFee(int confTarget) async {
    try {
      final result = await call('estimatesmartfee', [confTarget]);
      return result['feerate'] ?? 0.001; // Default to 1000 sats/kB
    } catch (e) {
      return 0.001; // Fallback fee rate
    }
  }
}
