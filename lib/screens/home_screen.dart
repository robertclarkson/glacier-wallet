import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/wallet_provider.dart';
import 'timelock_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh data when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<WalletProvider>(context, listen: false).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Color scheme
    const Color glacierBlue = Color(0xFF4A90E2); // Glacier blue for locked funds
    const Color bitcoinOrange = Color(0xFFF7931A); // Bitcoin orange for unlocked funds
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: glacierBlue,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Icon(Icons.ac_unit, color: Colors.white.withOpacity(0.9)), // Glacier/snowflake icon
            const SizedBox(width: 8),
            const Text('Glacier Wallet'),
          ],
        ),
        actions: [
          Consumer<WalletProvider>(
            builder: (context, walletProvider, child) {
              return IconButton(
                onPressed: walletProvider.isLoading ? null : () {
                  walletProvider.refresh();
                },
                icon: walletProvider.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              );
            },
          ),
          IconButton(
            onPressed: () {
              Provider.of<WalletProvider>(context, listen: false).disconnect();
              Navigator.pushReplacementNamed(context, '/setup');
            },
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Consumer<WalletProvider>(
        builder: (context, walletProvider, child) {
          if (!walletProvider.isConnected) {
            return const Center(
              child: Text('Not connected to Bitcoin node'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Balance Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        const Text(
                          'Total Balance',
                          style: TextStyle(
                            fontSize: 24, // 16 * 1.5
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(walletProvider.unlockedBalance + walletProvider.lockedBalance).toStringAsFixed(8)} BTC',
                          style: const TextStyle(
                            fontSize: 42, // 28 * 1.5
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Unlocked vs Locked breakdown
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Column(
                              children: [
                                const Text(
                                  'Unlocked',
                                  style: TextStyle(
                                    fontSize: 18, // 12 * 1.5
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${walletProvider.unlockedBalance.toStringAsFixed(8)} BTC',
                                  style: const TextStyle(
                                    fontSize: 21, // 14 * 1.5
                                    fontWeight: FontWeight.bold,
                                    color: bitcoinOrange,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 24),
                            Column(
                              children: [
                                const Text(
                                  'Locked',
                                  style: TextStyle(
                                    fontSize: 18, // 12 * 1.5
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${walletProvider.lockedBalance.toStringAsFixed(8)} BTC',
                                  style: const TextStyle(
                                    fontSize: 21, // 14 * 1.5
                                    fontWeight: FontWeight.bold,
                                    color: glacierBlue,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              onPressed: walletProvider.isLoading ? null : () {
                                _showGenerateBlocksDialog(context, walletProvider);
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Mine Blocks'),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const TimeLockScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.schedule),
                              label: const Text('Time Lock'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: glacierBlue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Blockchain Info Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Blockchain Info',
                          style: TextStyle(
                            fontSize: 27, // 18 * 1.5
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Block Height:'),
                            Text(
                              '${walletProvider.blockHeight}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Connection:'),
                            Row(
                              children: [
                                Icon(
                                  Icons.circle,
                                  color: walletProvider.isConnected ? Colors.green : Colors.red,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  walletProvider.isConnected ? 'Connected' : 'Disconnected',
                                  style: TextStyle(
                                    color: walletProvider.isConnected ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Wallet Address Card
                if (walletProvider.wallet != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Wallet Address',
                            style: TextStyle(
                              fontSize: 27, // 18 * 1.5
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    walletProvider.wallet!.address,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 18, // 12 * 1.5
                                    ),
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
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Time-Locked Transactions
                if (walletProvider.timeLockTransactions.isNotEmpty) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Time-Locked Transactions',
                            style: TextStyle(
                              fontSize: 27, // 18 * 1.5
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...walletProvider.timeLockTransactions.map((tx) {
                            final lockTimeType = tx['lockTimeType'] ?? 'timestamp';
                            final canSpend = walletProvider.canSpendTimeLock(tx);
                            final status = tx['status'] as String?;
                            final isUnlocked = status == 'unlocked';
                            final confirmations = tx['confirmations'] as int? ?? 0;
                            final isPending = confirmations == 0; // Unconfirmed transaction
                            final unlockTime = tx['unlockTime'] != null 
                                ? DateTime.parse(tx['unlockTime']) 
                                : null;
                            
                            // Determine display status
                            String displayStatus;
                            Color statusColor;
                            IconData? statusIcon; // Nullable - only some states have icons
                            
                            if (isPending && !isUnlocked) {
                              displayStatus = 'Pending';
                              statusColor = Colors.amber;
                              statusIcon = Icons.hourglass_empty;
                            } else if (isUnlocked) {
                              displayStatus = 'Unlocked';
                              statusColor = Colors.grey;
                              statusIcon = null; // No icon for spent
                            } else if (canSpend) {
                              displayStatus = 'Ready';
                              statusColor = bitcoinOrange; // Bitcoin orange for ready to unlock
                              statusIcon = null; // No icon for ready
                            } else {
                              displayStatus = 'Locked';
                              statusColor = glacierBlue; // Glacier blue for locked
                              statusIcon = null; // No icon for locked
                            }
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: statusColor,
                                  width: (isPending && !isUnlocked) ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${(tx['amount'] as double).toStringAsFixed(8)} BTC',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24, // 16 * 1.5
                                          decoration: isUnlocked ? TextDecoration.lineThrough : null,
                                          color: isUnlocked ? Colors.grey : ((isPending && !isUnlocked) ? Colors.amber : Colors.white),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (statusIcon != null) ...[
                                              Icon(statusIcon, size: 16, color: Colors.white),
                                              const SizedBox(width: 4),
                                            ],
                                            Text(
                                              displayStatus,
                                              style: const TextStyle(
                                                fontSize: 18, // 12 * 1.5
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Show pending message
                                  if (isPending && !isUnlocked) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.amber.withOpacity(0.5)),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.info_outline, size: 16, color: Colors.amber),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Waiting for confirmation (mine a block to confirm)',
                                              style: TextStyle(
                                                color: Colors.amber.shade200,
                                                fontSize: 14,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  if (lockTimeType == 'blockheight') ...[
                                    Row(
                                      children: [
                                        const Icon(Icons.layers, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Unlock Block: ${tx['blockHeight']}',
                                          style: const TextStyle(color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                    if (!canSpend) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Blocks remaining: ${tx['blockHeight'] - walletProvider.blockHeight}',
                                        style: const TextStyle(color: glacierBlue),
                                      ),
                                    ],
                                  ] else if (unlockTime != null) ...[
                                    Row(
                                      children: [
                                        const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Unlock Time: ${DateFormat('MMM dd, yyyy HH:mm').format(unlockTime)}',
                                          style: const TextStyle(color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                    if (!canSpend) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Time remaining: ${_getTimeRemaining(unlockTime)}',
                                        style: const TextStyle(color: glacierBlue),
                                      ),
                                    ],
                                  ],
                                  const SizedBox(height: 8),
                                  // Transaction ID with copy button
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[900],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.tag, size: 12, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            tx['txid'] as String,
                                            style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 16, // 11 * 1.5 ≈ 16
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () async {
                                            await Clipboard.setData(
                                              ClipboardData(text: tx['txid'] as String),
                                            );
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Transaction ID copied to clipboard'),
                                                  duration: Duration(seconds: 2),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            }
                                          },
                                          icon: const Icon(Icons.copy, size: 14),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Show unlock TxID if already unlocked
                                  if (isUnlocked && tx['unlockTxId'] != null) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[900],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.check_circle, size: 12, color: Colors.green),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'Unlock TX: ${tx['unlockTxId'] as String}',
                                              style: const TextStyle(
                                                fontFamily: 'monospace',
                                                fontSize: 16, // 11 * 1.5 ≈ 16
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () async {
                                              await Clipboard.setData(
                                                ClipboardData(text: tx['unlockTxId'] as String),
                                              );
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('Unlock transaction ID copied to clipboard'),
                                                    duration: Duration(seconds: 2),
                                                    backgroundColor: Colors.green,
                                                  ),
                                                );
                                              }
                                            },
                                            icon: const Icon(Icons.copy, size: 14),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  // Show unlock button only if can spend AND not already unlocked
                                  if (canSpend && !isUnlocked) ...[
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () async {
                                          // Show confirmation dialog
                                          final confirmed = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('Unlock Timelock'),
                                              content: Text(
                                                'Unlock ${(tx['amount']).toStringAsFixed(8)} BTC and send to your wallet?\n\n'
                                                'Destination: ${walletProvider.wallet!.address}',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, false),
                                                  child: const Text('Cancel'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () => Navigator.pop(context, true),
                                                  child: const Text('Unlock'),
                                                ),
                                              ],
                                            ),
                                          );
                                          
                                          if (confirmed == true && context.mounted) {
                                            final txId = await walletProvider.unlockTimeLock(tx);
                                            
                                            if (context.mounted) {
                                              if (txId != null) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Timelock unlocked! TxID: ${txId.substring(0, 16)}...'),
                                                    backgroundColor: bitcoinOrange,
                                                    duration: const Duration(seconds: 4),
                                                  ),
                                                );
                                              } else {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Failed to unlock: ${walletProvider.error}'),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                              }
                                            }
                                          }
                                        },
                                        icon: const Icon(Icons.lock_open),
                                        label: const Text('Unlock & Spend'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: bitcoinOrange,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                ],

                // Error display
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
              ],
            ),
          );
        },
      ),
    );
  }

  void _showGenerateBlocksDialog(BuildContext context, WalletProvider walletProvider) {
    final controller = TextEditingController(text: '6');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate Blocks'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('How many blocks to generate?'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Number of blocks',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final blocks = int.tryParse(controller.text) ?? 6;
              Navigator.pop(context);
              await walletProvider.generateBlocks(blocks);
            },
            child: const Text('Generate'),
          ),
        ],
      ),
    );
  }

  String _getTimeRemaining(DateTime unlockTime) {
    final now = DateTime.now();
    final difference = unlockTime.difference(now);
    
    if (difference.isNegative) {
      return 'Unlocked';
    }
    
    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;
    
    if (days > 0) {
      return '${days}d ${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}
