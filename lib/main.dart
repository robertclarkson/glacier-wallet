import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/wallet_provider.dart';
import 'screens/home_screen.dart';
import 'screens/wallet_setup_screen.dart';

void main() {
  runApp(const GlacierBitcoinWallet());
}

class GlacierBitcoinWallet extends StatelessWidget {
  const GlacierBitcoinWallet({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => WalletProvider(),
      child: MaterialApp(
        title: 'Glacier Bitcoin Wallet',
        theme: ThemeData(
          primarySwatch: Colors.orange,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: Colors.grey[900],
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        home: const WalletSetupScreen(),
        routes: {
          '/home': (context) => const HomeScreen(),
          '/setup': (context) => const WalletSetupScreen(),
        },
      ),
    );
  }
}
