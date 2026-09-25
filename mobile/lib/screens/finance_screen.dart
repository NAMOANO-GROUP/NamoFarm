import 'package:flutter/material.dart';
import '../widgets/brand_logo.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/finance_provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/csv_export.dart';
import '../widgets/number_field.dart';
import '../widgets/async_button.dart';
import '../utils/money_format.dart';
import '../widgets/iso_calendar_picker.dart';
import '../widgets/filter_styles.dart';
import '../widgets/status_pill.dart';
import '../widgets/empty_state.dart';
import 'comptabilite_screen.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final TextEditingController _yearCtrl = TextEditingController();
  bool _showMouvements = false;

  double? _parseDecimal(String value) {
    final normalized = value.replaceAll('\u00A0', '').replaceAll(' ', '').trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  Widget _financeActionTile(String label, IconData icon, List<Color> gradient, VoidCallback onTap) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.20), shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const List<Map<String, String>> _sourceOptions = [
    {'value': '', 'label': 'Tous les types'},
    {'value': 'approvisionnement', 'label': 'Approvisionnement'},
    {'value': 'depense', 'label': 'Depense'},
    {'value': 'vente', 'label': 'Vente'},
    {'value': 'vente_commande_payee', 'label': 'Vente (ancien format)'},
    {'value': 'stock_entree', 'label': 'Achat stock'},
    {'value': 'stock_sortie', 'label': 'Ancienne sortie stock'},
    {'value': 'correction', 'label': 'Correction'},
  ];

  static const List<Map<String, dynamic>> _monthOptions = [
    {'value': null, 'label': 'Tous les mois'},
    {'value': 1, 'label': 'Janvier'},
    {'value': 2, 'label': 'Fevrier'},
    {'value': 3, 'label': 'Mars'},
    {'value': 4, 'label': 'Avril'},
    {'value': 5, 'label': 'Mai'},
    {'value': 6, 'label': 'Juin'},
    {'value': 7, 'label': 'Juillet'},
    {'value': 8, 'label': 'Aout'},
    {'value': 9, 'label': 'Septembre'},
    {'value': 10, 'label': 'Octobre'},
    {'value': 11, 'label': 'Novembre'},
    {'value': 12, 'label': 'Decembre'},
  ];

  static const List<Map<String, dynamic>> _weekdayOptions = [
    {'value': 1, 'label': 'Lun'},
    {'value': 2, 'label': 'Mar'},
    {'value': 3, 'label': 'Mer'},
    {'value': 4, 'label': 'Jeu'},
    {'value': 5, 'label': 'Ven'},
    {'value': 6, 'label': 'Sam'},
    {'value': 7, 'label': 'Dim'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<FinanceProvider>();
      provider.chargerTresorerie();
      provider.chargerAnalysesAvancees();
    });
  }

  @override
  void dispose() {
    _yearCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BrandLogo(), title: const Text('Tresorerie / Finance')),
      body: Consumer<FinanceProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final solde = provider.solde;
          final totalEntrees = (solde['totalEntrees'] ?? 0) as num;
          final totalSorties = (solde['totalSorties'] ?? 0) as num;
          final soldeCaisse = (solde['soldeCaisse'] ?? 0) as num;

          return RefreshIndicator(
            onRefresh: () async {
              await provider.chargerTresorerie();
              await provider.chargerAnalysesAvancees();
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.green.shade900.withValues(alpha: 0.30)
                      : Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Solde de caisse', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text(
                          formatAmountFcfa(soldeCaisse),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: soldeCaisse >= 0 ? Colors.green.shade700 : Colors.red,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.call_received, size: 16, color: Colors.green),
                            const SizedBox(width: 4),
                            Text('Entrées: ${formatAmountFcfa(totalEntrees)}', style: const TextStyle(color: Colors.green)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.call_made, size: 16, color: Colors.red),
                            const SizedBox(width: 4),
                            Text('Sorties: ${formatAmountFcfa(totalSorties)}', style: const TextStyle(color: Colors.red)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _financeActionTile(
                        'Ajouter dépense',
                        Icons.remove_circle_outline,
                        const [Color(0xFF7A1F1F), Color(0xFFC62828)],
                        _showAjouterDepenseDialog,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _financeActionTile(
                        'Approvisionner',
                        Icons.add_circle_outline,
                        const [Color(0xFF0B5D3B), Color(0xFF2E7D32)],
                        _showApprovisionnementDialog,
                      ),
                    ),
                  ],
                ),
                if (provider.lastError != null && provider.lastError!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(provider.lastError!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 16),
                _buildFiltresCard(provider),
                const SizedBox(height: 12),
                _buildAnalysesAvanceesCard(provider),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Mouvements de tresorerie', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                    OutlinedButton.icon(
                      onPressed: () => exportCsvToClipboard(
                        context,
                        loader: () => ApiService.exportHistoriqueMouvementsTresorerieCsv(
                          sources: provider.sourceFilters.toList(),
                          weekdays: provider.weekdayFilters.toList(),
                          month: provider.monthFilter,
                          year: provider.yearFilter,
                          dateFrom: provider.dateFrom,
                          dateTo: provider.dateTo,
                        ),
                        label: 'Mouvements tresorerie',
                      ),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Exporter CSV'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final financeProvider = context.read<FinanceProvider>();
                        final messenger = ScaffoldMessenger.of(context);
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Effacer l\'historique ?'),
                            content: const Text('Cette action supprimera tous les mouvements de trésorerie.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                child: const Text('Effacer'),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true || !mounted) return;
                        final ok = await financeProvider.effacerHistoriqueMouvements();
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(content: Text(ok ? 'Historique effacé' : 'Suppression impossible')),
                        );
                      },
                      icon: const Icon(Icons.delete_sweep),
                      label: const Text('Effacer historique'),
                    ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ExpansionTile(
                  initiallyExpanded: _showMouvements,
                  onExpansionChanged: (expanded) => setState(() => _showMouvements = expanded),
                  leading: const Icon(Icons.history),
                  title: Text('Afficher historique (${provider.mouvements.length})'),
                  children: [
                    if (provider.mouvements.isEmpty)
                      const Card(child: Padding(padding: EdgeInsets.all(20), child: EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'Aucun mouvement',
                        subtitle: 'Les entrées et sorties de trésorerie apparaîtront ici.',
                      )))
                    else
                      ...provider.mouvements.map(_buildMouvementTile),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnalysesAvanceesCard(FinanceProvider provider) {
    final r = provider.rapprochement;
    final budget = provider.budgetPrevisionnel;
    final projection = provider.projectionTresorerie;
    final marges = provider.margesBandes;

    final rapprochementLoaded = r.isNotEmpty;
    final budgetLoaded = budget.isNotEmpty;
    final projectionLoaded = projection.isNotEmpty;

    final sortedMarges = [...marges]
      ..sort((a, b) => ((b['marge'] ?? 0) as num).compareTo((a['marge'] ?? 0) as num));

    final top3 = sortedMarges.take(3).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Analyses financières',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () => context.read<FinanceProvider>().chargerAnalysesAvancees(),
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Actualiser',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ComptabiliteScreen()),
                ),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                icon: const Icon(Icons.calculate_outlined, size: 18),
                label: const Text('Comptabilité par bande'),
              ),
            ),
            const SizedBox(height: 14),
            if (!rapprochementLoaded && !budgetLoaded && !projectionLoaded && marges.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: Text('Aucune analyse chargée', style: TextStyle(color: Colors.grey))),
              )
            else ...[
              _analyseSection('Rapprochement', Icons.account_balance_outlined, [
                _miniStat('Caisse', formatCompactFcfa((r['caisseNet'] ?? 0) as num), Colors.blue),
                _miniStat('Banque', formatCompactFcfa((r['banqueNet'] ?? 0) as num), Colors.indigo),
                _miniStat('Écart', formatCompactFcfa((r['ecart'] ?? 0) as num), ((r['ecart'] ?? 0) as num) == 0 ? Colors.green : Colors.orange),
              ]),
              const SizedBox(height: 10),
              _analyseSection('Budget prévisionnel (moyenne)', Icons.event_repeat_outlined, [
                _miniStat('Entrées', formatCompactFcfa((budget['moyenneEntrees'] ?? 0) as num), Colors.green),
                _miniStat('Sorties', formatCompactFcfa((budget['moyenneSorties'] ?? 0) as num), Colors.red),
              ]),
              const SizedBox(height: 10),
              _analyseSection('Projection trésorerie', Icons.timeline_outlined, [
                _miniStat('Solde actuel', formatCompactFcfa((projection['soldeActuel'] ?? 0) as num), ((projection['soldeActuel'] ?? 0) as num) >= 0 ? Colors.green : Colors.red),
                _miniStat('Net mensuel', formatCompactFcfa((projection['netMoyenMensuel'] ?? 0) as num), ((projection['netMoyenMensuel'] ?? 0) as num) >= 0 ? Colors.green : Colors.red),
              ]),
              if (top3.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.leaderboard_outlined, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    const Text('Top marges par bande', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                ...top3.map((m) {
                  final marge = (m['marge'] ?? 0) as num;
                  final color = marge >= 0 ? Colors.green : Colors.red;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text((m['bandeNom'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        StatusPill(
                          label: '${formatCompactFcfa(marge)} • ${(m['tauxMarge'] ?? 0)}%',
                          color: marge >= 0 ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 0),
                        Icon(marge >= 0 ? Icons.trending_up : Icons.trending_down, size: 16, color: color),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 10),
                _buildTopMargeChart(top3),
              ],
              const SizedBox(height: 12),
              _buildProjectionChart((projection['projection'] as List? ?? const [])),
            ],
          ],
        ),
      ),
    );
  }

  // Section d'analyse : titre + icône + rangée de mini-stats.
  Widget _analyseSection(String title, IconData icon, List<Widget> stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 6),
        Row(children: stats),
      ],
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopMargeChart(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final spots = <BarChartGroupData>[];
    for (var i = 0; i < rows.length; i += 1) {
      final marge = ((rows[i]['marge'] ?? 0) as num).toDouble();
      spots.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: marge,
              width: 18,
              borderRadius: BorderRadius.circular(4),
              color: marge >= 0 ? Colors.green : Colors.red,
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          gridData: const FlGridData(show: true),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final i = group.x.toInt();
                if (i < 0 || i >= rows.length) return null;
                final name = (rows[i]['bandeNom'] ?? '').toString();
                final marge = ((rows[i]['marge'] ?? 0) as num);
                return BarTooltipItem(
                  '$name\nMarge: ${formatAmountFcfa(marge)}',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              axisNameWidget: const Text('Marge (FCFA)', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600)),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 56,
                getTitlesWidget: (value, meta) {
                  if (value == meta.min) return const SizedBox.shrink();
                  return Text(formatCompactNumber(value), style: const TextStyle(fontSize: 9));
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= rows.length) return const SizedBox.shrink();
                  final label = (rows[i]['bandeNom'] ?? '').toString();
                  final short = label.length > 9 ? '${label.substring(0, 9)}…' : label;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(short, style: const TextStyle(fontSize: 9)),
                  );
                },
              ),
            ),
          ),
          barGroups: spots,
        ),
      ),
    );
  }

  Widget _buildProjectionChart(List projectionRows) {
    final parsed = projectionRows
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (parsed.isEmpty) return const SizedBox.shrink();

    final spots = <FlSpot>[];
    for (var i = 0; i < parsed.length; i += 1) {
      final y = ((parsed[i]['soldeProjete'] ?? 0) as num).toDouble();
      spots.add(FlSpot(i.toDouble(), y));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.show_chart, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            const Text('Projection trésorerie (6 mois)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 200,
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: true),
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final i = spot.x.toInt();
                      if (i < 0 || i >= parsed.length) {
                        return const LineTooltipItem('', TextStyle());
                      }
                      final month = (parsed[i]['mois'] ?? '').toString();
                      final value = ((parsed[i]['soldeProjete'] ?? 0) as num);
                      return LineTooltipItem(
                        '$month\n${formatAmountFcfa(value)}',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      );
                    }).toList();
                  },
                ),
              ),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 46,
                    getTitlesWidget: (value, meta) {
                      if (value == meta.min || value == meta.max) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(formatCompactNumber(value), style: const TextStyle(fontSize: 9)),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= parsed.length) return const SizedBox.shrink();
                      final month = (parsed[i]['mois'] ?? '').toString();
                      final compact = month.length >= 7 ? month.substring(2) : month;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(compact, style: const TextStyle(fontSize: 10)),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Colors.blue,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                ),
              ],
            ),
          ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: const [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 10, color: Colors.blue),
                SizedBox(width: 4),
                Text('Solde projeté'),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFiltresCard(FinanceProvider provider) {
    final providerYear = provider.yearFilter;
    final targetYearText = providerYear?.toString() ?? '';
    if (_yearCtrl.text != targetYearText) {
      _yearCtrl.text = targetYearText;
    }

    final dateRangeLabel = (provider.dateFrom != null && provider.dateTo != null)
        ? '${DateFormat('dd/MM/yyyy').format(provider.dateFrom!)} - ${DateFormat('dd/MM/yyyy').format(provider.dateTo!)}'
        : 'Aucun intervalle';

    final sourceSummary = provider.sourceFilters.isEmpty
      ? 'Tous les types'
      : provider.sourceFilters
        .map((value) => _sourceOptions.firstWhere(
            (opt) => opt['value'] == value,
            orElse: () => {'label': value},
          )['label'] ?? value)
        .join(', ');

    final weekdaySummary = provider.weekdayFilters.isEmpty
      ? 'Tous les jours'
      : _weekdayOptions
        .where((opt) => provider.weekdayFilters.contains(opt['value']))
        .map((opt) => (opt['label'] ?? '').toString())
        .join(', ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filtres mouvements', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 2),
            ListTile(
              dense: true,
              visualDensity: const VisualDensity(vertical: -4),
              contentPadding: EdgeInsets.zero,
              title: const Text('Types de mouvement', style: TextStyle(fontSize: 13)),
              subtitle: Text(sourceSummary, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
              trailing: const Icon(Icons.arrow_drop_down),
              onTap: () => _showSourceSelectionDialog(provider),
            ),
            ListTile(
              dense: true,
              visualDensity: const VisualDensity(vertical: -4),
              contentPadding: EdgeInsets.zero,
              title: const Text('Jours de la semaine', style: TextStyle(fontSize: 13)),
              subtitle: Text(weekdaySummary, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
              trailing: const Icon(Icons.arrow_drop_down),
              onTap: () => _showWeekdaySelectionDialog(provider),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    initialValue: provider.monthFilter,
                    isExpanded: true,
                    isDense: true,
                    style: kFilterTextStyle.copyWith(color: Theme.of(context).colorScheme.onSurface),
                    decoration: filterDecoration('Mois'),
                    items: _monthOptions
                        .map(
                          (opt) => DropdownMenuItem<int?>(
                            value: opt['value'] as int?,
                            child: Text(opt['label'] as String, style: kFilterTextStyle),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => context.read<FinanceProvider>().setMonthFilter(v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _yearCtrl,
                    keyboardType: TextInputType.number,
                    style: kFilterTextStyle,
                    decoration: filterDecoration(
                      'Année',
                      suffixIcon: IconButton(
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          _yearCtrl.clear();
                          context.read<FinanceProvider>().setYearFilter(null);
                        },
                        icon: const Icon(Icons.clear, size: 18),
                      ),
                    ),
                    onSubmitted: (value) {
                      final parsed = int.tryParse(value.trim());
                      context.read<FinanceProvider>().setYearFilter(parsed);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            ListTile(
              dense: true,
              visualDensity: const VisualDensity(vertical: -4),
              contentPadding: EdgeInsets.zero,
              title: const Text('Intervalle de date', style: TextStyle(fontSize: 13)),
              subtitle: Text(dateRangeLabel, style: const TextStyle(fontSize: 11)),
              trailing: const Icon(Icons.date_range),
              onTap: _showDateRangePicker,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (provider.dateFrom != null || provider.dateTo != null)
                  TextButton.icon(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
                    onPressed: () => context.read<FinanceProvider>().clearDateRange(),
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Effacer intervalle', style: TextStyle(fontSize: 12)),
                  )
                else
                  const SizedBox.shrink(),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
                  onPressed: () => context.read<FinanceProvider>().clearAllFilters(),
                  icon: const Icon(Icons.filter_alt_off, size: 16),
                  label: const Text('Reinitialiser', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSourceSelectionDialog(FinanceProvider provider) async {
    final current = provider.sourceFilters.toSet();
    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) {
        final temp = current.toSet();
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Types de mouvement'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _sourceOptions
                      .where((opt) => (opt['value'] ?? '').isNotEmpty)
                      .map((opt) {
                        final value = opt['value']!;
                        return CheckboxListTile(
                          value: temp.contains(value),
                          title: Text(opt['label'] ?? value),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          onChanged: (checked) {
                            setDialogState(() {
                              if (checked == true) {
                                temp.add(value);
                              } else {
                                temp.remove(value);
                              }
                            });
                          },
                        );
                      })
                      .toList(),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
              TextButton(onPressed: () => Navigator.pop(dialogContext, <String>{}), child: const Text('Tout réinitialiser')),
              ElevatedButton(onPressed: () => Navigator.pop(dialogContext, temp), child: const Text('Appliquer')),
            ],
          ),
        );
      },
    );

    if (selected == null || !mounted) return;
    await context.read<FinanceProvider>().setSourceFilters(selected);
  }

  Future<void> _showWeekdaySelectionDialog(FinanceProvider provider) async {
    final current = provider.weekdayFilters.toSet();
    final selected = await showDialog<Set<int>>(
      context: context,
      builder: (dialogContext) {
        final temp = current.toSet();
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Jours de la semaine'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _weekdayOptions.map((opt) {
                    final value = opt['value'] as int;
                    final label = (opt['label'] ?? value.toString()).toString();
                    return CheckboxListTile(
                      value: temp.contains(value),
                      title: Text(label),
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                      onChanged: (checked) {
                        setDialogState(() {
                          if (checked == true) {
                            temp.add(value);
                          } else {
                            temp.remove(value);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
              TextButton(onPressed: () => Navigator.pop(dialogContext, <int>{}), child: const Text('Tout réinitialiser')),
              ElevatedButton(onPressed: () => Navigator.pop(dialogContext, temp), child: const Text('Appliquer')),
            ],
          ),
        );
      },
    );

    if (selected == null || !mounted) return;
    await context.read<FinanceProvider>().setWeekdayFilters(selected);
  }

  Future<void> _showDateRangePicker() async {
    final provider = context.read<FinanceProvider>();
    final picked = await showIsoDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: provider.dateFrom != null && provider.dateTo != null
          ? DateTimeRange(start: provider.dateFrom!, end: provider.dateTo!)
          : null,
    );
    if (picked != null) {
      await provider.setDateRange(picked.start, picked.end);
    }
  }

  Widget _buildMouvementTile(Map<String, dynamic> m) {
    final date = m['date'] != null ? DateTime.tryParse(m['date'].toString()) : null;
    final formattedDate = date != null ? DateFormat('dd/MM/yyyy HH:mm').format(date) : '-';
    final nature = (m['nature'] ?? '').toString();
    final isEntree = nature == 'entree';
    final montant = (m['montant'] ?? 0) as num;
    final quiPrenom = (m['quiPrenom'] ?? '').toString();
    final quiNom = (m['quiNom'] ?? '').toString();
    final source = (m['source'] ?? '').toString();
    final categorie = (m['categorie'] ?? '').toString();
    final type = (m['type'] ?? '').toString();
    final commentaire = (m['commentaire'] ?? '').toString();
    final id = (m['_id'] ?? '').toString();
    final auth = context.watch<AuthProvider>();
    final canDelete = auth.isAdmin || auth.isSuperadmin;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(isEntree ? Icons.call_received : Icons.call_made, color: isEntree ? Colors.green : Colors.red),
        title: Text('${isEntree ? 'Entree' : 'Sortie'}: ${formatAmountFcfa(montant)}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$formattedDate • $quiPrenom $quiNom'),
            Text('Source: $source • Categorie: $categorie • Type: $type'),
            if (commentaire.isNotEmpty) Text(commentaire, style: const TextStyle(fontStyle: FontStyle.italic)),
          ],
        ),
        trailing: canDelete && id.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                tooltip: 'Supprimer cette transaction',
                onPressed: () => _confirmerSuppressionMouvement(id),
              )
            : null,
        isThreeLine: true,
      ),
    );
  }

  Future<void> _confirmerSuppressionMouvement(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette transaction ?'),
        content: const Text('Cette action est irreversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final provider = context.read<FinanceProvider>();
    final ok = await provider.supprimerMouvement(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Transaction supprimee' : 'Erreur: ${provider.lastError ?? ''}')),
    );
  }

  Future<void> _showAjouterDepenseDialog() async {
    final quiNomCtrl = TextEditingController();
    final quiPrenomCtrl = TextEditingController();
    final categorieCtrl = TextEditingController();
    final typeCtrl = TextEditingController();
    final montantCtrl = TextEditingController();
    final commentaireCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String selectedBandeId = '';

    List<Map<String, dynamic>> bandesActives = const [];
    try {
      final rawBandes = await ApiService.getBandesActives();
      bandesActives = rawBandes
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    } catch (_) {
      bandesActives = const [];
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Nouvelle depense'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: quiPrenomCtrl, decoration: const InputDecoration(labelText: 'Prenom *')),
                TextField(controller: quiNomCtrl, decoration: const InputDecoration(labelText: 'Nom *')),
                TextField(controller: categorieCtrl, decoration: const InputDecoration(labelText: 'Categorie *')),
                TextField(controller: typeCtrl, decoration: const InputDecoration(labelText: 'Type *')),
                DropdownButtonFormField<String>(
                  initialValue: selectedBandeId,
                  decoration: const InputDecoration(labelText: 'Bande (optionnelle)'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('Sans bande'),
                    ),
                    ...bandesActives.map((b) {
                      final id = (b['id'] ?? b['_id'] ?? '').toString();
                      final nom = (b['nom'] ?? 'Bande').toString();
                      final batiment = (b['batiment'] ?? '').toString();
                      final label = batiment.isNotEmpty ? '$nom - $batiment' : nom;
                      return DropdownMenuItem<String>(
                        value: id,
                        child: Text(label),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedBandeId = value ?? '';
                    });
                  },
                ),
                NumberField(controller: montantCtrl, label: 'Montant *'),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date'),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showIsoDatePicker(
                      context: dialogContext,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                ),
                TextField(controller: commentaireCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Commentaire')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
            AsyncButton(
              label: const Text('Enregistrer'),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(dialogContext);
                final montant = _parseDecimal(montantCtrl.text) ?? 0;
                if (quiNomCtrl.text.trim().isEmpty ||
                    quiPrenomCtrl.text.trim().isEmpty ||
                    categorieCtrl.text.trim().isEmpty ||
                    typeCtrl.text.trim().isEmpty ||
                    montant <= 0) {
                  messenger.showSnackBar(const SnackBar(content: Text('Renseigne tous les champs obligatoires (*)')));
                  return;
                }
                final ok = await context.read<FinanceProvider>().ajouterDepense({
                  'quiNom': quiNomCtrl.text.trim(),
                  'quiPrenom': quiPrenomCtrl.text.trim(),
                  'categorie': categorieCtrl.text.trim(),
                  'type': typeCtrl.text.trim(),
                  'montant': montant,
                  'date': selectedDate.toIso8601String(),
                  'commentaire': commentaireCtrl.text.trim(),
                  if (selectedBandeId.isNotEmpty) 'bandeId': selectedBandeId,
                });
                if (!mounted) return;
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(content: Text(ok ? 'Depense enregistree' : 'Erreur enregistrement depense')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showApprovisionnementDialog() {
    final quiNomCtrl = TextEditingController();
    final quiPrenomCtrl = TextEditingController();
    final montantCtrl = TextEditingController();
    final commentaireCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Approvisionnement caisse'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: quiPrenomCtrl, decoration: const InputDecoration(labelText: 'Prenom *')),
                TextField(controller: quiNomCtrl, decoration: const InputDecoration(labelText: 'Nom *')),
                NumberField(controller: montantCtrl, label: 'Montant *'),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date'),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showIsoDatePicker(
                      context: dialogContext,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                ),
                TextField(controller: commentaireCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Commentaire')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
            AsyncButton(
              label: const Text('Enregistrer'),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(dialogContext);
                final montant = _parseDecimal(montantCtrl.text) ?? 0;
                if (quiNomCtrl.text.trim().isEmpty || quiPrenomCtrl.text.trim().isEmpty || montant <= 0) {
                  messenger.showSnackBar(const SnackBar(content: Text('Renseigne tous les champs obligatoires (*)')));
                  return;
                }
                final ok = await context.read<FinanceProvider>().ajouterApprovisionnement({
                  'quiNom': quiNomCtrl.text.trim(),
                  'quiPrenom': quiPrenomCtrl.text.trim(),
                  'montant': montant,
                  'date': selectedDate.toIso8601String(),
                  'commentaire': commentaireCtrl.text.trim(),
                });
                if (!mounted) return;
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(content: Text(ok ? 'Approvisionnement enregistre' : 'Erreur enregistrement approvisionnement')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
