import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../models/crm_pipeline.dart';
import '../../utils/crm_labels.dart';
import '../../utils/money_format.dart';

FlTitlesData _titles({
  required String leftLabel,
  required String Function(int index) bottomLabel,
  required int count,
  String Function(double value)? leftFormat,
}) {
  return FlTitlesData(
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: AxisTitles(
      axisNameWidget: Text(leftLabel, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600)),
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 40,
        getTitlesWidget: (value, meta) {
          if (value == meta.min) return const SizedBox.shrink();
          return Text(leftFormat?.call(value) ?? value.toInt().toString(), style: const TextStyle(fontSize: 9));
        },
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 28,
        getTitlesWidget: (value, meta) {
          final i = value.toInt();
          if (i < 0 || i >= count) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(bottomLabel(i), style: const TextStyle(fontSize: 9)),
          );
        },
      ),
    ),
  );
}

BarChartGroupData _bar(int x, double y, Color color) => BarChartGroupData(
      x: x,
      barRods: [BarChartRodData(toY: y, width: 16, borderRadius: BorderRadius.circular(4), color: color)],
    );

/// Nombre d'affaires par étape du pipeline.
class PipelineFunnelChart extends StatelessWidget {
  final List<Map<String, dynamic>> stages;

  const PipelineFunnelChart({super.key, required this.stages});

  @override
  Widget build(BuildContext context) {
    final counts = {
      for (final s in stages) (s['stage'] ?? '').toString(): ((s['count'] ?? 0) as num).toDouble(),
    };
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, _, _) {
                final stage = pipelineStages[group.x];
                return BarTooltipItem(
                  '${stage.label}\n${formatCompactNumber(counts[stage.value] ?? 0)} affaire(s)',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                );
              },
            ),
          ),
          titlesData: _titles(
            leftLabel: 'Affaires',
            count: pipelineStages.length,
            bottomLabel: (i) => pipelineStages[i].label,
          ),
          barGroups: [
            for (var i = 0; i < pipelineStages.length; i++)
              _bar(i, counts[pipelineStages[i].value] ?? 0, pipelineStages[i].color),
          ],
        ),
      ),
    );
  }
}

/// Répartition des affaires par source de prospect.
class LeadSourcesChart extends StatelessWidget {
  final List<Map<String, dynamic>> sources;

  const LeadSourcesChart({super.key, required this.sources});

  @override
  Widget build(BuildContext context) {
    final subset = ([...sources]..sort((a, b) => ((b['count'] ?? 0) as num).compareTo((a['count'] ?? 0) as num)))
        .take(6)
        .toList();
    if (subset.isEmpty) return const SizedBox.shrink();
    String label(int i) => (subset[i]['source'] ?? '').toString();
    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                '${label(group.x)}\n${rod.toY.toInt()} prospect(s)',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          titlesData: _titles(
            leftLabel: 'Prospects',
            count: subset.length,
            bottomLabel: (i) => label(i).length > 10 ? '${label(i).substring(0, 10)}…' : label(i),
          ),
          barGroups: [
            for (var i = 0; i < subset.length; i++) _bar(i, ((subset[i]['count'] ?? 0) as num).toDouble(), Colors.teal),
          ],
        ),
      ),
    );
  }
}

const _moisCourts = ['Janv', 'Févr', 'Mars', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sept', 'Oct', 'Nov', 'Déc'];

/// Ventes mensuelles des 12 derniers mois.
class VentesMensuellesChart extends StatelessWidget {
  final List<CrmVenteMois> ventes;

  const VentesMensuellesChart({super.key, required this.ventes});

  @override
  Widget build(BuildContext context) {
    if (ventes.isEmpty) return const SizedBox.shrink();
    final color = Theme.of(context).colorScheme.primary;
    String label(int i) => '${_moisCourts[(ventes[i].mois - 1).clamp(0, 11)]}\n${ventes[i].annee % 100}';
    return SizedBox(
      height: 190,
      child: BarChart(
        BarChartData(
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                '${_moisCourts[(ventes[group.x].mois - 1).clamp(0, 11)]} ${ventes[group.x].annee}\n${formatCompactFcfa(rod.toY)}',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          titlesData: _titles(
            leftLabel: 'FCFA',
            count: ventes.length,
            bottomLabel: label,
            leftFormat: formatCompactNumber,
          ),
          barGroups: [for (var i = 0; i < ventes.length; i++) _bar(i, ventes[i].total, color)],
        ),
      ),
    );
  }
}
