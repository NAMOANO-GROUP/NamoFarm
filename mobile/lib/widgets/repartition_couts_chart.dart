import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../utils/money_format.dart';

double _n(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

/// Postes de coût d'une bande (données /finance/analytique), dans l'ordre d'affichage.
List<(String, double, Color)> postesCoutBande(Map<String, dynamic> b) {
  final autres = b.containsKey('autresDepenses')
      ? _n(b['autresDepenses'])
      : _n(b['depenses']) - _n(b['prophylaxie']) - _n(b['coutPoussins']);
  return [
    ('Prix des poussins', _n(b['coutPoussins']), Colors.teal),
    ('Prophylaxie', _n(b['prophylaxie']), Colors.purple),
    ('Alimentation', _n(b['coutAliment']), Colors.brown),
    ('Coût fixe', _n(b['coutFixe']), Colors.indigo),
    ('Amortissement', _n(b['coutAmortissement']), Colors.blueGrey),
    ('Autres', autres, Colors.orange),
  ];
}

/// Somme des postes de plusieurs bandes.
List<(String, double, Color)> postesCoutBandes(Iterable<Map<String, dynamic>> bandes) {
  final out = postesCoutBande(const {});
  for (final b in bandes) {
    final p = postesCoutBande(b);
    for (var i = 0; i < out.length; i++) {
      out[i] = (out[i].$1, out[i].$2 + p[i].$2, out[i].$3);
    }
  }
  return out;
}

/// Camembert (donut) de la répartition des coûts avec légende montant + %.
class RepartitionCoutsChart extends StatelessWidget {
  final List<(String, double, Color)> postes;
  final String titre;

  const RepartitionCoutsChart({super.key, required this.postes, this.titre = 'Répartition des coûts'});

  RepartitionCoutsChart.bande(Map<String, dynamic> bande, {super.key, this.titre = 'Répartition des coûts'})
      : postes = postesCoutBande(bande);

  @override
  Widget build(BuildContext context) {
    final visibles = postes.where((p) => p.$2 > 0).toList();
    final total = visibles.fold<double>(0, (s, p) => s + p.$2);
    if (total <= 0) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    final pie = SizedBox(
      height: 180,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 36,
          startDegreeOffset: -90,
          sections: [
            for (final p in visibles)
              PieChartSectionData(
                value: p.$2,
                color: p.$3,
                radius: 52,
                title: p.$2 / total >= 0.07 ? '${(p.$2 / total * 100).toStringAsFixed(0)}%' : '',
                titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
              ),
          ],
        ),
      ),
    );

    final legende = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final p in visibles)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: p.$3, borderRadius: BorderRadius.circular(3)),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(p.$1, maxLines: 1, overflow: TextOverflow.ellipsis)),
                Flexible(
                  child: Text(
                    '${formatAmountFcfa(p.$2)}  •  ${(p.$2 / total * 100).toStringAsFixed(1)}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.pie_chart_outline, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(child: Text(titre, style: const TextStyle(fontWeight: FontWeight.w600))),
            Text(formatCompactFcfa(total), style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, c) => c.maxWidth >= 600
              ? Row(
                  children: [
                    Expanded(child: pie),
                    const SizedBox(width: 24),
                    Expanded(child: legende),
                  ],
                )
              : Column(children: [pie, const SizedBox(height: 12), legende]),
        ),
      ],
    );
  }
}
