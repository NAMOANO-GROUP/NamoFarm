import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/module_cartes.dart';
import 'achats/fournisseurs_tab.dart';
import 'stocks_screen.dart';

/// Une page du module Achats, visible selon une permission.
class _Feuille {
  final ModuleCarte carte;
  final String permission;

  const _Feuille({required this.carte, required this.permission});
}

/// Module Achats (approvisionnement) : accueil à deux cartes, Stocks et Fournisseurs.
/// Ajoutez ici les futures pages (commandes fournisseurs, réceptions...).
class AchatsScreen extends StatelessWidget {
  const AchatsScreen({super.key});

  static const permissions = ['stocks:view', 'clients.read'];

  static final _feuilles = [
    _Feuille(
      carte: ModuleCarte(
        cle: const ValueKey('achats-carte-stocks'),
        icone: Icons.inventory_2_outlined,
        couleur: const Color(0xFFEF6C00),
        titre: 'Stocks',
        description: 'Aliments, médicaments, vitamines : quantités, seuils d’alerte et mouvements.',
        page: (context, retour) => moduleSousPage(retour: retour, titre: 'Stocks', body: const StocksScreen(embedded: true)),
      ),
      permission: 'stocks:view',
    ),
    _Feuille(
      carte: ModuleCarte(
        cle: const ValueKey('achats-carte-fournisseurs'),
        icone: Icons.local_shipping_outlined,
        couleur: const Color(0xFF1565C0),
        titre: 'Fournisseurs',
        description: 'Vos fournisseurs d’aliment, de poussins et de vaccins : contacts, réceptions et réassort.',
        page: (context, retour) => moduleSousPage(retour: retour, titre: 'Fournisseurs', body: const FournisseursTab()),
      ),
      // Même permission que les routes backend /fournisseurs.
      permission: 'clients.read',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cartes = [for (final f in _feuilles) if (auth.hasPermission(f.permission)) f.carte];
    return ModuleCartesScreen(titre: 'Achats', cartes: cartes);
  }
}
