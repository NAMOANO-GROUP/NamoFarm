import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'providers/bandes_provider.dart';
import 'providers/clients_provider.dart';
import 'providers/fournisseurs_provider.dart';
import 'providers/commandes_provider.dart';
import 'providers/stocks_provider.dart';
import 'providers/alertes_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/crm_provider.dart';
import 'providers/finance_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/admin_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/reproduction_provider.dart';

void main() {
  runApp(const AgriBusiness());
}

class AgriBusiness extends StatelessWidget {
  const AgriBusiness({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..initSession()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => BandesProvider()),
        ChangeNotifierProvider(create: (_) => ClientsProvider()),
        ChangeNotifierProvider(create: (_) => FournisseursProvider()),
        ChangeNotifierProvider(create: (_) => CommandesProvider()),
        ChangeNotifierProvider(create: (_) => StocksProvider()),
        ChangeNotifierProvider(create: (_) => AlertesProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => CrmProvider()),
        ChangeNotifierProvider(create: (_) => FinanceProvider()),
        ChangeNotifierProvider(create: (_) => ReproductionProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
          title: 'AgriBusiness',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(Brightness.light, themeProvider.seed),
          darkTheme: _buildTheme(Brightness.dark, themeProvider.seed),
          themeMode: themeProvider.mode,
          home: const _AppGate(),
        ),
      ),
    );
  }
}

ThemeData _buildTheme(Brightness brightness, Color seed) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: brightness),
    useMaterial3: true,
    // Smaller side inset so dialog forms get more usable width on small phones.
    dialogTheme: DialogThemeData(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
    ),
  );
}

class _AppGate extends StatelessWidget {
  const _AppGate();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isLoading) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final child = auth.isAuthenticated ? const HomeScreen() : const LoginScreen();

        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => auth.registerActivity(),
          onPointerMove: (_) => auth.registerActivity(),
          child: child,
        );
      },
    );
  }
}
