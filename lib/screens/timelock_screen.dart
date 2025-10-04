import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/wallet_provider.dart';

// Color constants
const Color glacierBlue = Color(0xFF4A90E2); // Glacier blue for locked funds

class TimeLockScreen extends StatefulWidget {
  const TimeLockScreen({super.key});

  @override
  State<TimeLockScreen> createState() => _TimeLockScreenState();
}

class _TimeLockScreenState extends State<TimeLockScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _blockHeightController = TextEditingController();
  
  DateTime _selectedDateTime = DateTime.now().add(const Duration(hours: 1));
  bool _useBlockHeight = false; // Toggle between datetime and block height
  
  @override
  void dispose() {
    _amountController.dispose();
    _blockHeightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Time-Locked Transaction'),
      ),
      body: Consumer<WalletProvider>(
        builder: (context, walletProvider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Info Card
                  Card(
                    color: Colors.blue[900],
                    child: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                'CHECKTIMELOCKVERIFY',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'This creates a transaction that can only be spent after the specified time. '
                            'The funds will be locked until the unlock time is reached.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Amount Field
                  TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount (BTC)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.monetization_on),
                      helperText: 'Amount to lock',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter an amount';
                      }
                      
                      final amount = double.tryParse(value);
                      if (amount == null || amount <= 0) {
                        return 'Please enter a valid amount';
                      }
                      
                      if (amount > walletProvider.balance) {
                        return 'Insufficient balance';
                      }
                      
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  // Info about recipient
                  Card(
                    color: Colors.grey[850],
                    child: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue, size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Recipient address will be specified when unlocking the funds after the timelock expires.',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Lock Type Toggle
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Lock Type',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: SegmentedButton<bool>(
                                  segments: const [
                                    ButtonSegment<bool>(
                                      value: false,
                                      label: Text('Date/Time'),
                                      icon: Icon(Icons.calendar_today),
                                    ),
                                    ButtonSegment<bool>(
                                      value: true,
                                      label: Text('Block Height'),
                                      icon: Icon(Icons.layers),
                                    ),
                                  ],
                                  selected: {_useBlockHeight},
                                  onSelectionChanged: (Set<bool> newSelection) {
                                    setState(() {
                                      _useBlockHeight = newSelection.first;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _useBlockHeight
                                ? 'Lock until a specific block height is reached'
                                : 'Lock until a specific date and time',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Block Height or Date/Time Selection
                  if (_useBlockHeight) ...[
                    // Block Height Input
                    TextFormField(
                      controller: _blockHeightController,
                      decoration: InputDecoration(
                        labelText: 'Block Height',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.layers),
                        helperText: 'Current block: ${walletProvider.blockHeight}',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.add),
                          tooltip: 'Current + 100',
                          onPressed: () {
                            _blockHeightController.text = 
                                (walletProvider.blockHeight + 100).toString();
                          },
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a block height';
                        }
                        final height = int.tryParse(value);
                        if (height == null) {
                          return 'Please enter a valid number';
                        }
                        if (height <= walletProvider.blockHeight) {
                          return 'Block height must be in the future (current: ${walletProvider.blockHeight})';
                        }
                        // Block height must be < 500000000 per Bitcoin protocol
                        if (height >= 500000000) {
                          return 'Block height must be less than 500,000,000';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildQuickBlockButton(
                          '+6 blocks (~1 hour)', 
                          walletProvider.blockHeight + 6
                        ),
                        _buildQuickBlockButton(
                          '+144 blocks (~1 day)', 
                          walletProvider.blockHeight + 144
                        ),
                        _buildQuickBlockButton(
                          '+1008 blocks (~1 week)', 
                          walletProvider.blockHeight + 1008
                        ),
                        _buildQuickBlockButton(
                          '+4320 blocks (~1 month)', 
                          walletProvider.blockHeight + 4320
                        ),
                      ],
                    ),
                  ] else ...[
                    // Date and Time Selection
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Unlock Time',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: _selectedDateTime,
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                                    );
                                    
                                    if (date != null) {
                                      setState(() {
                                        _selectedDateTime = DateTime(
                                          date.year,
                                          date.month,
                                          date.day,
                                          _selectedDateTime.hour,
                                          _selectedDateTime.minute,
                                        );
                                      });
                                    }
                                  },
                                  icon: const Icon(Icons.calendar_today),
                                  label: Text(DateFormat('MMM dd, yyyy').format(_selectedDateTime)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final time = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
                                    );
                                    
                                    if (time != null) {
                                      setState(() {
                                        _selectedDateTime = DateTime(
                                          _selectedDateTime.year,
                                          _selectedDateTime.month,
                                          _selectedDateTime.day,
                                          time.hour,
                                          time.minute,
                                        );
                                      });
                                    }
                                  },
                                  icon: const Icon(Icons.access_time),
                                  label: Text(DateFormat('HH:mm').format(_selectedDateTime)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Selected: ${DateFormat('MMM dd, yyyy HH:mm').format(_selectedDateTime)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Unix timestamp: ${_selectedDateTime.millisecondsSinceEpoch ~/ 1000}',
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Quick time buttons
                  const Text(
                    'Quick Select:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildQuickTimeButton('1 Hour', const Duration(hours: 1)),
                      _buildQuickTimeButton('6 Hours', const Duration(hours: 6)),
                      _buildQuickTimeButton('1 Day', const Duration(days: 1)),
                      _buildQuickTimeButton('1 Week', const Duration(days: 7)),
                      _buildQuickTimeButton('1 Month', const Duration(days: 30)),
                      _buildQuickTimeButton('1 Year', const Duration(days: 365)),
                    ],
                  ),
                ],

                  const SizedBox(height: 32),

                  // Create Transaction Button
                  ElevatedButton(
                    onPressed: walletProvider.isLoading ? null : () async {
                      if (_formKey.currentState!.validate()) {
                        String? timeLockAddress;
                        
                        try {
                          if (_useBlockHeight) {
                            // Validate block height
                            final blockHeight = int.tryParse(_blockHeightController.text);
                            if (blockHeight == null || blockHeight <= walletProvider.blockHeight) {
                              debugPrint('❌ [TimeLockScreen] Invalid block height: $blockHeight (current: ${walletProvider.blockHeight})');
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Block height must be in the future'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            final amount = double.parse(_amountController.text);
                            debugPrint('🔒 [TimeLockScreen] Creating block height timelock: $amount BTC until block $blockHeight');

                            timeLockAddress = await walletProvider.createTimeLockTransactionFromBlockHeight(
                              amount: amount,
                              blockHeight: blockHeight,
                            );
                          } else {
                            // Validate unlock time is in the future
                            if (_selectedDateTime.isBefore(DateTime.now())) {
                              debugPrint('❌ [TimeLockScreen] Invalid unlock time: $_selectedDateTime (must be in future)');
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Unlock time must be in the future'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            final amount = double.parse(_amountController.text);
                            debugPrint('🔒 [TimeLockScreen] Creating datetime timelock: $amount BTC until $_selectedDateTime');

                            timeLockAddress = await walletProvider.createTimeLockTransaction(
                              amount: amount,
                              unlockTime: _selectedDateTime,
                            );
                          }
                        } catch (e, stackTrace) {
                          debugPrint('❌ [TimeLockScreen] Error creating timelock: $e');
                          debugPrint('   Stack trace: $stackTrace');
                          
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                          return;
                        }

                        if (timeLockAddress != null && mounted) {
                          debugPrint('✅ [TimeLockScreen] Timelock created successfully: $timeLockAddress');
                          final addressToShow = timeLockAddress; // Create non-nullable copy
                          showDialog(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: Text(_useBlockHeight ? 'Block Height Lock Created' : 'Time-Lock Created'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _useBlockHeight
                                        ? 'Funds locked until block ${_blockHeightController.text}!'
                                        : 'Funds locked until ${DateFormat('MMM dd, yyyy HH:mm').format(_selectedDateTime)}!'
                                  ),
                                  const SizedBox(height: 16),
                                  const Text('Time-Lock Address:'),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[800],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            addressToShow,
                                            style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () async {
                                            await Clipboard.setData(
                                              ClipboardData(text: addressToShow),
                                            );
                                            if (dialogContext.mounted) {
                                              ScaffoldMessenger.of(dialogContext).showSnackBar(
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
                                  ),
                                  const SizedBox(height: 16),
                                  if (_useBlockHeight)
                                    Text(
                                      'Unlock Block: ${_blockHeightController.text}\n'
                                      'Current Block: ${walletProvider.blockHeight}\n'
                                      'Blocks Remaining: ${int.parse(_blockHeightController.text) - walletProvider.blockHeight}',
                                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                                    )
                                  else
                                    Text(
                                      'Unlock Time: ${DateFormat('MMM dd, yyyy HH:mm').format(_selectedDateTime)}\n'
                                      'Unix Timestamp: ${_selectedDateTime.millisecondsSinceEpoch ~/ 1000}',
                                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                                    ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Note: In a real implementation, you would need to '
                                    'fund this address and create the actual transaction.',
                                    style: TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Done'),
                                ),
                              ],
                            ),
                          );
                        }
                      }
                    },
                    child: walletProvider.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create Time-Locked Transaction'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: glacierBlue,
                      foregroundColor: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Balance info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Available Balance:'),
                        Text(
                          '${walletProvider.balance.toStringAsFixed(8)} BTC',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),

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
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickTimeButton(String label, Duration duration) {
    return OutlinedButton(
      onPressed: () {
        setState(() {
          _selectedDateTime = DateTime.now().add(duration);
        });
      },
      child: Text(label),
    );
  }

  Widget _buildQuickBlockButton(String label, int blockHeight) {
    return OutlinedButton(
      onPressed: () {
        setState(() {
          _blockHeightController.text = blockHeight.toString();
        });
      },
      child: Text(label),
    );
  }
}
