import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../models/bande.dart';
import '../../utils/bande_kpis.dart';
import '../../utils/crm_labels.dart';
import '../../widgets/bandes/bande_widgets.dart';
import '../../widgets/crm/crm_widgets.dart';
import '../../widgets/empty_state.dart';

const _palette = [Colors.green, Colors.indigo, Colors.orange, Colors.purple, Colors.teal, Colors.red, Colors.brown, Colors.cyan];

/// Vue « Comparer » : bandes côte à côte (courbes, classement, bâtiments).
class BandesComparaisonView extends StatefulWidget {
  final List<Bande> bandes;
  final Map<String, ReferenceType> references;
  final ValueChanged<Bande> onOpen;

  const BandesComparaisonView({super.key, required this.bandes, required this.references, required this.onOpen});

  @override
  State<BandesComparaisonView> createState() => _BandesComparaisonViewState();
}

class _BandesComparaisonViewState extends State<BandesComparaisonView> {
  Set<String>? _selection;

  /// Par défaut : les 6 bandes les plus récentes.
  Set<String> _defaut(List<Bande> bandes) => bandes.take(6).map((b) => b.id!).toSet();

  @override
  Widget build(BuildContext context) {
    final bandes = widget.bandes.where((b) => b.id != null).toList()
      ..sort((a, b) => b.dateOuverture.compareTo(a.dateOuverture));
    if (bandes.isEmpty) {
      return const EmptyState(icon: Icons.compare_arrows, title: 'Aucune bande à comparer', subtitle: 'Ouvrez une bande pour commencer.');
    }
    final selection = (_selection ?? _defaut(bandes)).where((id) => bandes.any((b) => b.id == id)).toSet();
    final kpis = {for (final b in bandes) b.id!: computeBandeKpis(b, referencePour(widget.references, b.typeVolaille))};
    final choisies = bandes.where((b) => selection.contains(b.id)).toList();
    final couleurs = {for (var i = 0; i < choisies.length; i++) choisies[i].id!: _palette[i % _palette.length]};
    final classement = [...choisies]..sort((a, b) => (kpis[b.id]!.iep ?? -1).compareTo(kpis[a.id]!.iep ?? -1));

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        CrmSectionHeader('Bandes comparées (${choisies.length})', icon: Icons.checklist),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final b in bandes)
              FilterChip(
                avatar: selection.contains(b.id)
                    ? CircleAvatar(backgroundColor: couleurs[b.id] ?? Colors.grey, radius: 6)
                    : null,
                label: Text(b.nom),
                selected: selection.contains(b.id),
                onSelected: (v) => setState(() {
                  final next = {...selection};
                  v ? next.add(b.id!) : next.remove(b.id);
                  _selection = next;
                }),
              ),
          ],
        ),
        const SizedBox(height: 12),
        CrmCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Courbes de croissance', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Poids moyen (g) selon l’âge (jours). Pointillés : référence du type de la première bande.',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              _CourbesChart(bandes: choisies, couleurs: couleurs, references: widget.references),
            ],
          ),
        ),
        CrmCard(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(14, 6, 14, 6),
                child: Text('Classement par indice d’efficacité (IEP)', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 18,
                  headingRowHeight: 40,
                  dataRowMinHeight: 44,
                  dataRowMaxHeight: 52,
                  showCheckboxColumn: false,
                  columns: const [
                    DataColumn(label: Text('#')),
                    DataColumn(label: Text('Bande')),
                    DataColumn(label: Text('Âge'), numeric: true),
                    DataColumn(label: Text('Viabilité'), numeric: true),
                    DataColumn(label: Text('Poids'), numeric: true),
                    DataColumn(label: Text('IC'), numeric: true),
                    DataColumn(label: Text('IEP'), numeric: true),
                  ],
                  rows: [
                    for (var i = 0; i < classement.length; i++)
                      () {
                        final b = classement[i];
                        final k = kpis[b.id]!;
                        return DataRow(
                          onSelectChanged: (_) => widget.onOpen(b),
                          cells: [
                            DataCell(Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800))),
                            DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                              CircleAvatar(radius: 5, backgroundColor: couleurs[b.id]),
                              const SizedBox(width: 6),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(b.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text(
                                    '${typeVolailleLabel(b.typeVolaille)} · ${b.dateFermeture == null ? 'ouverte' : 'fermée'}',
                                    style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ])),
                            DataCell(Text('J${k.ageJours}')),
                            DataCell(Text('${fmt1(k.viabilitePct)} %')),
                            DataCell(Text(k.poidsG == null ? '—' : '${fmtEntier(k.poidsG!)} g',
                                style: TextStyle(color: couleurEcart(k.ecartReferencePct)))),
                            DataCell(Text(k.ic == null ? '—' : fmt2(k.ic!))),
                            DataCell(Text(k.iep == null ? '—' : fmtEntier(k.iep!), style: const TextStyle(fontWeight: FontWeight.w800))),
                          ],
                        );
                      }(),
                  ],
                ),
              ),
            ],
          ),
        ),
        CrmCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Performances par bâtiment', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Moyennes de toutes les bandes (ouvertes et fermées).',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              for (final p in performancesParBatiment(bandes, kpis))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: avatarColor(p.batiment).withValues(alpha: 0.15),
                    child: Icon(Icons.home_work_outlined, color: avatarColor(p.batiment)),
                  ),
                  title: Text(p.batiment, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${p.nbBandes} bande(s) · viabilité ${fmt1(p.viabiliteMoy)} % · IC ${p.icMoy == null ? '—' : fmt2(p.icMoy!)}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(p.iepMoy == null ? '—' : fmtEntier(p.iepMoy!), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      const Text('IEP moyen', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CourbesChart extends StatelessWidget {
  final List<Bande> bandes;
  final Map<String, Color> couleurs;
  final Map<String, ReferenceType> references;

  const _CourbesChart({required this.bandes, required this.couleurs, required this.references});

  @override
  Widget build(BuildContext context) {
    final series = [for (final b in bandes) (bande: b, pts: courbeCroissance(b))].where((s) => s.pts.isNotEmpty).toList();
    if (series.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('Aucune pesée enregistrée pour ces bandes.', style: TextStyle(color: Colors.grey))),
      );
    }
    final maxAge = series.expand((s) => s.pts).map((p) => p.age).reduce((a, b) => a > b ? a : b);
    final premiere = series.first.bande;
    final ref = referencePour(references, premiere.typeVolaille);
    final refPts = [
      for (var age = 0; age <= maxAge; age += (maxAge > 30 ? 2 : 1))
        FlSpot(age.toDouble(), ref.poidsA(age, poidsArriveeG: premiere.poidsArriveeG)),
    ];

    return Column(
      children: [
        SizedBox(
          height: 230,
          child: LineChart(LineChartData(
            minX: 0,
            maxX: maxAge.toDouble(),
            minY: 0,
            gridData: const FlGridData(show: true, drawVerticalLine: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 42,
                  getTitlesWidget: (v, meta) =>
                      v == meta.min ? const SizedBox.shrink() : Text(fmtEntier(v), style: const TextStyle(fontSize: 9)),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  getTitlesWidget: (v, meta) => Text('J${v.toInt()}', style: const TextStyle(fontSize: 9)),
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) => spots.map((s) {
                  final name = s.barIndex == 0 ? 'Référence' : series[s.barIndex - 1].bande.nom;
                  return LineTooltipItem('$name\nJ${s.x.toInt()} · ${fmtEntier(s.y)} g',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11));
                }).toList(),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: refPts,
                isCurved: true,
                color: Colors.grey,
                barWidth: 2,
                dashArray: [6, 4],
                dotData: const FlDotData(show: false),
              ),
              for (final s in series)
                LineChartBarData(
                  spots: [for (final p in s.pts) FlSpot(p.age.toDouble(), p.poids)],
                  isCurved: s.pts.length > 2,
                  preventCurveOverShooting: true,
                  color: couleurs[s.bande.id],
                  barWidth: 3,
                  dotData: FlDotData(show: s.pts.length < 15),
                ),
            ],
          )),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (final s in series)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 12, height: 3, color: couleurs[s.bande.id]),
                const SizedBox(width: 4),
                Flexible(child: Text(s.bande.nom, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11))),
              ]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 12, height: 2, color: Colors.grey),
              const SizedBox(width: 4),
              Flexible(
                child: Text('Référence ${typeVolailleLabel(premiere.typeVolaille)}',
                    overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
              ),
            ]),
          ],
        ),
      ],
    );
  }
}
