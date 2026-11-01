import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/brand_logo.dart';
import 'achats/fournisseurs_tab.dart';
import 'stocks_screen.dart';

/// Une feuille (onglet) du module Achats, visible selon une permission.
class _Feuille {
  final Tab tab;
  final Widget page;
  final String permission;

  const _Feuille({required this.tab, required this.page, required this.permission});
}

/// Module Achats (approvisionnement) : stocks et fournisseurs.
/// Ajoutez ici les futures feuilles (commandes fournisseurs, réceptions...).
class AchatsScreen extends StatelessWidget {
  const AchatsScreen({super.key});

  static const permissions = ['stocks:view', 'clients.read'];

  static const _feuilles = [
    _Feuille(
      tab: Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Stocks'),
      page: StocksScreen(embedded: true),
      permission: 'stocks:view',
    ),
    _Feuille(
      tab: Tab(icon: Icon(Icons.local_shipping_outlined), text: 'Fournisseurs'),
      page: FournisseursTab(),
      // Même permission que les routes backend /fournisseurs.
      permission: 'clients.read',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final feuilles = _feuilles.where((f) => auth.hasPermission(f.permission)).toList();

    return DefaultTabController(
      length: feuilles.length,
      child: Scaffold(
        appBar: AppBar(
          leading: const BrandLogo(),
          title: const Text('Achats'),
          bottom: feuilles.length < 2
              ? null
              : TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [for (final f in feuilles) f.tab],
                ),
        ),
        body: feuilles.isEmpty
            ? const Center(child: Text('Aucune feuille autorisée'))
            : feuilles.length == 1
                ? feuilles.first.page
                : TabBarView(children: [for (final f in feuilles) f.page]),
      ),
    );
  }
}
