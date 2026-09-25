import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/bande.dart';
import '../services/api_service.dart';
import '../utils/money_format.dart';

class BandeDashboardScreen extends StatefulWidget {
  final Bande bande;
  const BandeDashboardScreen({super.key, required this.bande});

  @override
  State<BandeDashboardScreen> createState() => _BandeDashboardScreenState();
}

class _BandeDashboardScreenState extends State<BandeDashboardScreen> {
  Map<String, dynamic>? data;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ApiService.getSuiviDashboardBande(widget.bande.id!);
      if (mounted) {
        setState(() {
          data = d;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (data == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Dashboard bande ${widget.bande.nom}')),
        body: const Center(child: Text('Impossible de charger les données')),
      );
    }

    final growth = data!['growth'] as List<dynamic>;
    final theoriqueGrowth = data!['theoriqueGrowth'] as List<dynamic>? ?? const [];
    final conso = data!['conso'] as List<dynamic>;
    final theoriqueConso = data!['theoriqueConso'] as List<dynamic>? ?? const [];
    final mortality = data!['mortaliteJour'] as List<dynamic>;
    final forecast7j = data!['forecast7j'] as List<dynamic>? ?? const [];
    final eventsPrevisionnels = data!['eventsPrevisionnels'] as List<dynamic>? ?? const [];
    final perf = data!['performance'] as Map<String, dynamic>;

    return Scaffold(
      appBar: AppBar(title: Text('Dashboard bande ${widget.bande.nom}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPerfPanel(perf),
          const SizedBox(height: 12),
          _cardChart(
            'Courbe de croissance (réel vs théorique)',
            _lineChart(growth, 'poids', Colors.green, yUnit: 'g', second: theoriqueGrowth, secondYKey: 'poids', secondColor: Colors.orange, interpolateReal: true),
            legend: const [
              _LegendItem('Réel', Colors.green),
              _LegendItem('Théorique', Colors.orange),
            ],
          ),
          _cardChart(
            'Consommation cumulée (réel vs théorique)',
            _lineChart(conso, 'cumulKg', Colors.brown, yUnit: 'kg', second: theoriqueConso, secondYKey: 'cumulKg', secondColor: Colors.blueGrey),
            legend: const [
              _LegendItem('Réel', Colors.brown),
              _LegendItem('Théorique', Colors.blueGrey),
            ],
          ),
          _cardChart('Mortalité par jour', _barChart(mortality, 'mortalite', Colors.red, yUnit: 'têtes/jour')),
          _forecastCard(forecast7j, eventsPrevisionnels),
        ],
      ),
    );
  }

  Widget _forecastCard(List<dynamic> forecast7j, List<dynamic> events) {
    if (forecast7j.isEmpty && events.isEmpty) {
      return const SizedBox.shrink();
    }

    final horizon = forecast7j.isNotEmpty ? forecast7j.last as Map<String, dynamic> : null;
    final isWide = MediaQuery.of(context).size.width > 600;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text('Prévisionnel 7 jours', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            if (horizon != null)
              GridView.count(
                crossAxisCount: isWide ? 3 : 1,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: isWide ? 2.4 : 5,
                children: [
                  _statTile('Poids projeté', '${_fmt(horizon['poidsProjete'], digits: 0)} g', Icons.monitor_weight_outlined, Colors.green),
                  _statTile('Conso cumulée projetée', '${_fmt(horizon['consoCumulProjeteeKg'])} kg', Icons.restaurant, Colors.brown),
                  _statTile('Mortalité/j projetée', _fmt(horizon['mortaliteJourProjetee']), Icons.warning_amber_outlined, Colors.red),
                ],
              ),
            if (events.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('Événements prévisionnels', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...events.map((e) {
                final evt = e as Map<String, dynamic>;
                final sev = (evt['severite'] ?? '').toString();
                final color = sev == 'haute' ? Colors.red : Colors.orange;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withValues(alpha: 0.30)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: color, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          (evt['message'] ?? '').toString(),
                          style: const TextStyle(fontSize: 13, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPerfPanel(Map<String, dynamic> perf) {
    final ecartPoids = (perf['ecartPoidsTheoriquePct'] ?? 0).toDouble();
    final ecartConso = (perf['ecartConsoTheoriquePct'] ?? 0).toDouble();
    final isWide = MediaQuery.of(context).size.width > 600;
    final items = <Widget>[
      _statTile('Effectif initial', '${perf['effectifInitial'] ?? 0}', Icons.egg_outlined, Colors.blueGrey),
      _statTile('Effectif restant', '${perf['effectifRestant'] ?? 0}', Icons.groups_outlined, Colors.teal),
      _statTile('Mortalité cumulée', '${(perf['mortaliteCumulee'] ?? 0).toStringAsFixed(1)} %', Icons.warning_amber_outlined, Colors.red),
      _statTile('Conso cumulée', '${(perf['consommationCumuleeKg'] ?? 0).toStringAsFixed(1)} kg', Icons.restaurant, Colors.brown),
      _statTile('Poids final', '${(perf['poidsMoyenFinal'] ?? 0).toStringAsFixed(0)} g', Icons.monitor_weight_outlined, Colors.green),
      _statTile('Écart poids', '${ecartPoids >= 0 ? '+' : ''}${ecartPoids.toStringAsFixed(1)} %', Icons.trending_up, ecartPoids >= 0 ? Colors.green : Colors.orange),
      _statTile('Écart conso', '${ecartConso >= 0 ? '+' : ''}${ecartConso.toStringAsFixed(1)} %', Icons.show_chart, ecartConso <= 0 ? Colors.green : Colors.orange),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Performance de la bande', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: isWide ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.4,
              children: items,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardChart(String title, Widget chart, {List<_LegendItem> legend = const []}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if (legend.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: legend
                    .map(
                      (item) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 12, height: 12, decoration: BoxDecoration(color: item.color, borderRadius: BorderRadius.circular(2))),
                          const SizedBox(width: 6),
                          Text(item.label),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(height: 220, child: chart),
          ],
        ),
      ),
    );
  }

  Widget _lineChart(
    List<dynamic> raw,
    String yKey,
    Color color, {
    required String yUnit,
    List<dynamic>? second,
    String? secondYKey,
    Color? secondColor,
    bool interpolateReal = false,
  }) {
    if (raw.isEmpty) return const Center(child: Text('Pas de données'));

    final spots = <FlSpot>[];
    for (var i = 0; i < raw.length; i++) {
      final age = (raw[i]['age'] ?? (i + 1)).toDouble();
      final y = (raw[i][yKey] ?? 0).toDouble();
      // On ne garde que les jours réellement pesés pour relier les points (pesée hebdomadaire).
      if (interpolateReal && y <= 0) continue;
      spots.add(FlSpot(age, y));
    }
    spots.sort((a, b) => a.x.compareTo(b.x));
    if (spots.isEmpty) return const Center(child: Text('Pas de données'));

    final secondSpots = <FlSpot>[];
    if (second != null && secondYKey != null && second.isNotEmpty) {
      for (var i = 0; i < second.length; i++) {
        final age = (second[i]['age'] ?? (i + 1)).toDouble();
        secondSpots.add(FlSpot(age, (second[i][secondYKey] ?? 0).toDouble()));
      }
    }

    return LineChart(
      LineChartData(
        minX: 1,
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            axisNameWidget: Text(yUnit, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              getTitlesWidget: (value, meta) {
                if (value == meta.min) return const SizedBox.shrink();
                return Text(formatCompactNumber(value), style: const TextStyle(fontSize: 9));
              },
            ),
          ),
          bottomTitles: AxisTitles(
            axisNameWidget: const Text('Jours', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: spots.length > 30 ? 10 : spots.length > 15 ? 5 : 2,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(value.toStringAsFixed(0), style: const TextStyle(fontSize: 9)),
              ),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: !interpolateReal,
            color: color,
            barWidth: 3,
            dotData: FlDotData(show: interpolateReal),
          ),
          if (secondSpots.isNotEmpty)
            LineChartBarData(
              spots: secondSpots,
              isCurved: true,
              color: secondColor ?? Colors.orange,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              dashArray: [6, 4],
            ),
        ],
      ),
    );
  }

  Widget _barChart(List<dynamic> raw, String yKey, Color color, {required String yUnit}) {
    if (raw.isEmpty) return const Center(child: Text('Pas de données'));

    final bars = <BarChartGroupData>[];
    var maxAge = 0;
    for (var i = 0; i < raw.length; i++) {
      final age = (raw[i]['age'] ?? i).toInt();
      if (age > maxAge) maxAge = age;
      bars.add(
        BarChartGroupData(
          x: age,
          barRods: [
            BarChartRodData(toY: (raw[i][yKey] ?? 0).toDouble(), color: color, width: 8, borderRadius: BorderRadius.circular(3))
          ],
        ),
      );
    }

    final step = maxAge > 40 ? 7 : maxAge > 20 ? 5 : maxAge > 10 ? 3 : 1;

    return BarChart(
      BarChartData(
        barGroups: bars,
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            axisNameWidget: Text(yUnit, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              getTitlesWidget: (value, meta) {
                if (value == meta.min) return const SizedBox.shrink();
                return Text(formatCompactNumber(value), style: const TextStyle(fontSize: 9));
              },
            ),
          ),
          bottomTitles: AxisTitles(
            axisNameWidget: const Text('Jours', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              getTitlesWidget: (value, meta) {
                final v = value.toInt();
                if (v != 1 && v % step != 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('$v', style: const TextStyle(fontSize: 9)),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
      ),
    );
  }

  String _fmt(dynamic value, {int digits = 2}) {
    if (value is num) return value.toStringAsFixed(digits);
    return '0';
  }
}

class _LegendItem {
  final String label;
  final Color color;

  const _LegendItem(this.label, this.color);
}
