import 'package:flutter/material.dart';

import '../utils/money_format.dart';
import '../widgets/brand_logo.dart';

/// Bilan financier simple d'une bande (données issues de /finance/analytique).
class BandeBilanScreen extends StatelessWidget {
  final Map<String, dynamic> bande;

  const BandeBilanScreen({super.key, required this.bande});

  num _n(dynamic v) => (v ?? 0) as num;

  @override
  Widget build(BuildContext context) {
    final nom = (bande['bandeNom'] ?? 'Bande').toString();
    final statut = (bande['statut'] ?? '').toString();
    final type = (bande['typeVolaille'] ?? '').toString();
    final ca = _n(bande['revenus']);
    final depense = _n(bande['coutTotal']);
    final benefice = _n(bande['margeNette']);
    final marge = _n(bande['tauxMarge']);
    final mortalite = _n(bande['mortalite']);
    final tauxMortalite = _n(bande['tauxMortalite']);
    final coutAliment = _n(bande['coutAliment']);
    final effectif = _n(bande['effectifVivant']);
    final beneficePositif = benefice >= 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: const BrandLogo(),
        title: Text(nom),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Bandeau bénéfice/marge premium.
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: beneficePositif
                    ? [const Color(0xFF0B5D3B), const Color(0xFF2E7D32)]
                    : [const Color(0xFF7A1F1F), const Color(0xFFC62828)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(beneficePositif ? Icons.trending_up : Icons.trending_down, color: Colors.white),
                    const SizedBox(width: 8),
                    Text('Bénéfice net', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(formatAmountFcfa(benefice),
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 4),
                Text('Marge: ${marge.toStringAsFixed(1)} %  •  ${statut.isNotEmpty ? statut : 'bande'}${type.isNotEmpty ? ' • $type' : ''}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: 84,
            ),
            children: [
              _tile(context, 'CA (ventes)', formatAmountFcfa(ca), Icons.point_of_sale, Colors.green, isDark),
              _tile(context, 'Dépense totale', formatAmountFcfa(depense), Icons.trending_down, Colors.red, isDark),
              _tile(context, 'Coût aliment', formatAmountFcfa(coutAliment), Icons.restaurant, Colors.brown, isDark),
              _tile(context, 'Mortalité', '${mortalite.toStringAsFixed(0)} (${tauxMortalite.toStringAsFixed(1)} %)', Icons.warning_amber_outlined, Colors.deepOrange, isDark),
              _tile(context, 'Effectif vivant', effectif.toStringAsFixed(0), Icons.groups_outlined, Colors.teal, isDark),
              _tile(context, 'Coût / sujet', formatAmountFcfa(_n(bande['coutParSujet'])), Icons.person_outline, Colors.indigo, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.35 : 0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.28 : 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isDark ? _lighten(color) : color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _lighten(Color c, [double amount = 0.25]) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }
}
