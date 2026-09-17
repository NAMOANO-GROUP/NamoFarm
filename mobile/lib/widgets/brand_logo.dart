import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/nav_hub_provider.dart';

/// Petit logo NamoFarm à placer dans la barre du haut (AppBar) des écrans.
/// Se replie silencieusement si l'image n'est pas disponible.
/// Cliquable : ramène à la page d'accueil hub (ferme les pages empilées).
class BrandLogo extends StatelessWidget {
  final double size;
  const BrandLogo({super.key, this.size = 30});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        // Ferme d'éventuelles pages empilées puis affiche le hub.
        Navigator.of(context).popUntil((route) => route.isFirst);
        try {
          context.read<NavHubProvider>().goHub();
        } catch (_) {
          // Provider absent (ex: écran hors zone authentifiée) : on ignore.
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Image.asset(
          'assets/logo/namofarm.png',
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}
