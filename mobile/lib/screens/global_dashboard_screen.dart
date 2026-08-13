import 'package:flutter/material.dart';
import '../widgets/brand_logo.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import '../services/api_service.dart';
import '../utils/csv_export.dart';
import '../utils/money_format.dart';

class GlobalDashboardScreen extends StatefulWidget {
  const GlobalDashboardScreen({super.key});

  @override
  State<GlobalDashboardScreen> createState() => _GlobalDashboardScreenState();
}

class _GlobalDashboardScreenState extends State<GlobalDashboardScreen> {
  static const List<Map<String, String>> _periodOptions = [
    {'value': 'jour', 'label': 'Jour'},
    {'value': 'semaine', 'label': 'Semaine'},
    {'value': 'mois', 'label': 'Mois'},
    {'value': 'annee', 'label': 'Année'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().chargerDashboards();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BrandLogo(),
        title: const Text('Tableau de Bord Global'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Rapport PDF',
            onPressed: _showExportLinks,
          ),
        ],
      ),
      body: Consumer<DashboardProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final g = provider.global;
          final crm = provider.crm;

          if (g.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Aucune donnée disponible'),
                    if ((provider.lastError ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        provider.lastError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => provider.chargerDashboards(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.chargerDashboards(),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _buildCompactFilters(provider, context),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: MediaQuery.of(context).size.width > 900 ? 4 : 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: MediaQuery.of(context).size.width > 900
                      ? 1.6
                      : (MediaQuery.of(context).size.width < 360 ? 1.25 : 1.45),
                  children: [
                    _kpiCard('CA total', formatAmountFcfa(g['chiffreAffairesTotal'] ?? 0), Colors.green),
                    _kpiCard('Dépenses', formatAmountFcfa(g['depensesTotales'] ?? 0), Colors.red),
                    _kpiCard('Bénéfice net', formatAmountFcfa(g['beneficeNet'] ?? 0), Colors.blue),
                    _kpiCard('Marge', '${(g['marge'] ?? 0).toStringAsFixed(2)} %', Colors.orange),
                    _kpiCard('Consommation aliment', '${(g['consoAliment'] ?? 0).toStringAsFixed(2)} kg', Colors.brown),
                    _kpiCard('Taux mortalité', '${(g['tauxMortalite'] ?? 0).toStringAsFixed(2)} %', Colors.deepOrange),
                    _kpiCard('Clients actifs', '${g['clientsActifs'] ?? 0}', Colors.teal),
                    _kpiCard('Commandes', '${g['nbCommandes'] ?? 0}', Colors.purple),
                  ],
                ),
                const SizedBox(height: 20),
                _chartCard('Évolution des ventes', _lineChartFromAgg(g['ventesParPeriode'] ?? [], Colors.green)),
                const SizedBox(height: 12),
                _chartCard('Évolution des dépenses', _lineChartFromAgg(g['depensesParPeriode'] ?? [], Colors.red)),
                const SizedBox(height: 12),
                _crmSummaryCard(crm),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompactFilters(DashboardProvider provider, BuildContext context) {
    final hasAdvancedFilter = provider.selectedBatiment.isNotEmpty || provider.selectedBandeId.isNotEmpty;
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _periodOptions.map((opt) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: ChoiceChip(
                  label: Text(opt['label']!, style: const TextStyle(fontSize: 12)),
                  selected: provider.period == opt['value'],
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onSelected: (v) { if (v) provider.chargerDashboards(period: opt['value']); },
                ),
              )).toList(),
            ),
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.tune, size: 20),
              tooltip: 'Bâtiment / Bande',
              visualDensity: VisualDensity.compact,
              onPressed: () => _showAdvancedFilters(context, provider),
            ),
            if (hasAdvancedFilter)
              Positioned(
                right: 6, top: 6,
                child: Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ],
    );
  }

  void _showAdvancedFilters(BuildContext context, DashboardProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Filtres avancés'),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: provider.selectedBatiment.isEmpty ? '' : provider.selectedBatiment,
              decoration: const InputDecoration(labelText: 'Bâtiment', isDense: true),
              items: [
                const DropdownMenuItem(value: '', child: Text('Tous les bâtiments')),
                ...provider.batiments.map((b) => DropdownMenuItem(value: b, child: Text(b))),
              ],
              onChanged: (v) { provider.chargerDashboards(batiment: v ?? '', bandeId: ''); Navigator.pop(ctx); },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: provider.selectedBandeId.isEmpty ? '' : provider.selectedBandeId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Bande', isDense: true),
              items: [
                const DropdownMenuItem(value: '', child: Text('Toutes les bandes')),
                ...provider.bandesFiltreesPourBatiment.map((b) {
                  final id = (b['id'] ?? b['_id']).toString();
                  final nom = '${b['nom'] ?? ''}${(b['batiment'] ?? '').toString().isNotEmpty ? ' – ${b['batiment']}' : ''}';
                  return DropdownMenuItem(value: id, child: Text(nom, overflow: TextOverflow.ellipsis));
                }),
              ],
              onChanged: (v) { provider.chargerDashboards(bandeId: v ?? ''); Navigator.pop(ctx); },
            ),
            if (provider.selectedBatiment.isNotEmpty || provider.selectedBandeId.isNotEmpty) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () { provider.chargerDashboards(batiment: '', bandeId: ''); Navigator.pop(ctx); },
                icon: const Icon(Icons.clear),
                label: const Text('Effacer les filtres'),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
        ],
      ),
    );
  }

  Widget _kpiCard(String title, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chartCard(String title, Widget chart) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(height: 220, child: chart),
          ],
        ),
      ),
    );
  }

  Widget _lineChartFromAgg(List<dynamic> raw, Color color) {
    if (raw.isEmpty) return const Center(child: Text('Pas de données'));

    final points = <FlSpot>[];
    for (var i = 0; i < raw.length; i++) {
      final val = (raw[i]['total'] ?? 0).toDouble();
      points.add(FlSpot(i.toDouble(), val));
    }

    final xInterval = raw.length > 8 ? (raw.length / 6).ceilToDouble() : 1.0;

    return LineChart(
      LineChartData(
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touched) => touched.map((s) {
              final i = s.x.toInt();
              final label = (i >= 0 && i < raw.length) ? (raw[i]['periode'] ?? '').toString() : '';
              return LineTooltipItem(
                '${label.isNotEmpty ? "$label\n" : ""}${formatCompactNumber(s.y)}',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              );
            }).toList(),
          ),
        ),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: true),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
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
              reservedSize: 28,
              interval: xInterval,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= raw.length) return const SizedBox.shrink();
                final label = (raw[i]['periode'] ?? '').toString();
                final compact = label.length > 6 ? label.substring(label.length - 5) : label;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(compact, style: const TextStyle(fontSize: 9)),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: points,
            isCurved: true,
            barWidth: 3,
            color: color,
            dotData: const FlDotData(show: false),
          )
        ],
      ),
    );
  }

  Widget _crmSummaryCard(Map<String, dynamic> crm) {
    if (crm.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Synthèse CRM', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Text('Total clients: ${crm['totalClients'] ?? 0}'),
                Text('Prospects: ${crm['totalProspects'] ?? 0}'),
                Text('Nouveaux clients: ${crm['nouveauxClients'] ?? 0}'),
                Text('Relances à faire: ${crm['relancesAFaire'] ?? 0}'),
                Text('Commandes en attente: ${crm['commandesEnAttente'] ?? 0}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showExportLinks() {
    final today = DateTime.now().toIso8601String().split('T').first;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Partager le rapport global', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('Rapport PDF'),
              subtitle: const Text('Synthèse finances, élevage, reproduction, santé'),
              onTap: () {
                Navigator.pop(ctx);
                shareReportFile(
                  context,
                  loader: ApiService.downloadGlobalPdfReport,
                  filename: 'rapport-global-$today.pdf',
                  mimeType: 'application/pdf',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green),
              title: const Text('Rapport Excel'),
              subtitle: const Text('Synthèse + performance par bande'),
              onTap: () {
                Navigator.pop(ctx);
                shareReportFile(
                  context,
                  loader: ApiService.downloadGlobalExcelReport,
                  filename: 'rapport-global-$today.xlsx',
                  mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
