import 'package:flutter/material.dart';

/// Petit logo NamoFarm à placer dans la barre du haut (AppBar) des écrans.
/// Se replie silencieusement si l'image n'est pas disponible.
class BrandLogo extends StatelessWidget {
  final double size;
  const BrandLogo({super.key, this.size = 30});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Image.asset(
        'assets/logo/namofarm.png',
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      ),
    );
  }
}
