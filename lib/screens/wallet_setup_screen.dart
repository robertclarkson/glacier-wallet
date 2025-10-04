import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';

class WalletSetupScreen extends StatefulWidget {
  const WalletSetupScreen({super.key});

  @override
  State<WalletSetupScreen> createState() => _WalletSetupScreenState();
}

class _WalletSetupScreenState extends State<WalletSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hostController = TextEditingController(text: '127.0.0.1');
  final _portController = TextEditingController(text: '18443');
  final _usernameController = TextEditingController(text: 'bitcoin');
  final _passwordController = TextEditingController(text: 'bitcoin');
  
  bool _showAdvanced = false;

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color glacierBlue = Color(0xFF4A90E2); // Glacier blue
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: glacierBlue,
        foregroundColor: Colors.white,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.ac_unit, color: Colors.white.withOpacity(0.9)),
            const SizedBox(width: 8),
            const Text('Glacier Bitcoin Wallet'),
          ],
        ),
        centerTitle: true,
      ),
      body: Consumer<WalletProvider>(
        builder: (context, walletProvider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.ac_unit,
                    size: 80,
                    color: glacierBlue,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Time-Locked Bitcoin Wallet',
                    style: TextStyle(
                      fontSize: 36, // 24 * 1.5
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Create time-locked transactions using CHECKTIMELOCKVERIFY',
                    style: TextStyle(
                      fontSize: 24, // 16 * 1.5
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  
                  // Wallet section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Wallet Setup',
                            style: TextStyle(
                              fontSize: 27, // 18 * 1.5
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (walletProvider.wallet == null) ...[
                            ElevatedButton(
                              onPressed: walletProvider.isLoading ? null : () {
                                walletProvider.generateNewWallet();
                              },
                              child: const Text('Generate New Wallet'),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Note: This generates a demo wallet for regtest use only.',
                              style: TextStyle(color: Colors.grey, fontSize: 18), // 12 * 1.5
                            ),
                          ] else ...[
                            const Text(
                              '✓ Wallet Generated',
                              style: TextStyle(color: Colors.green),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Address: ${walletProvider.wallet!.address}',
                                    style: const TextStyle(fontSize: 18, color: Colors.grey), // 12 * 1.5
                                  ),
                                ),
                                IconButton(
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: walletProvider.wallet!.address),
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Address copied to clipboard'),
                                          duration: Duration(seconds: 2),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.copy, size: 18),
                                  tooltip: 'Copy address',
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Bitcoin node connection
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Bitcoin Node',
                                style: TextStyle(
                                  fontSize: 27, // 18 * 1.5
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (walletProvider.isConnected)
                                const Icon(Icons.check_circle, color: Colors.green),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          if (!_showAdvanced) ...[
                            const Text(
                              'Connect to local regtest node (127.0.0.1:18443)',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _showAdvanced = true;
                                });
                              },
                              child: const Text('Advanced Settings'),
                            ),
                          ] else ...[
                            TextFormField(
                              controller: _hostController,
                              decoration: const InputDecoration(
                                labelText: 'Host',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter host';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _portController,
                              decoration: const InputDecoration(
                                labelText: 'Port',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter port';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _usernameController,
                              decoration: const InputDecoration(
                                labelText: 'RPC Username',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _passwordController,
                              decoration: const InputDecoration(
                                labelText: 'RPC Password',
                                border: OutlineInputBorder(),
                              ),
                              obscureText: true,
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _showAdvanced = false;
                                });
                              },
                              child: const Text('Hide Advanced'),
                            ),
                          ],
                          
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: walletProvider.isLoading ? null : () async {
                              if (_formKey.currentState!.validate()) {
                                await walletProvider.connectToNode(
                                  host: _hostController.text,
                                  port: int.parse(_portController.text),
                                  username: _usernameController.text,
                                  password: _passwordController.text,
                                );
                                
                                if (walletProvider.isConnected && mounted) {
                                  Navigator.pushReplacementNamed(context, '/home');
                                }
                              }
                            },
                            child: walletProvider.isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(walletProvider.isConnected ? 'Connected' : 'Connect to Node'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  if (walletProvider.error != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: Colors.red[900],
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.error, color: Colors.red),
                                SizedBox(width: 8),
                                Text(
                                  'Error',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(walletProvider.error!),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                walletProvider.clearError();
                              },
                              child: const Text('Dismiss'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 32),
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Setup Instructions',
                            style: TextStyle(
                              fontSize: 24, // 16 * 1.5
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '1. Start Bitcoin Core in regtest mode:\n'
                            '   bitcoind -regtest -rpcuser=bitcoin -rpcpassword=bitcoin\n\n'
                            '2. Generate a new wallet above\n\n'
                            '3. Connect to your Bitcoin node\n\n'
                            '4. You can then generate blocks and create time-locked transactions',
                            style: TextStyle(color: Colors.grey, fontSize: 18), // 12 * 1.5
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
