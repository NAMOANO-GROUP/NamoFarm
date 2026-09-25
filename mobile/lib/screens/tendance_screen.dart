import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../services/api_service.dart';
import '../utils/money_format.dart';
import '../widgets/brand_logo.dart';

/// Page dédiée montrant la tendance mensuelle (ventes ou dépenses) sur 12 mois,
/// avec un filtre Année propre à la page.
class TendanceScreen extends StatefulWidget {
  final String titre;
  final String kind; // 'ventes' ou 'depenses'
  final Color color;

  const TendanceScreen({
    super.key,
    required this.titre,
    required this.kind,
    required this.color,
  });

  @override
  State<TendanceScreen> createState() => _TendanceScreenState();
}

class _TendanceScreenState extends State<TendanceScreen> {
  static const List<String> _moisCourts = [
    'J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D',
  ];
  static const List<String> _moisLongs = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ];

  late int _year;
  bool _loading = true;
  String? _error;
  List<double> _valeurs = List<double>.filled(12, 0);

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.getTendanceMensuelle(_year);
      final list = (data[widget.kind] as List? ?? const []);
      final vals = List<double>.filled(12, 0);
      for (final e in list) {
        final m = (e['mois'] as num?)?.toInt() ?? 0;
        if (m >= 1 && m <= 12) vals[m - 1] = (e['total'] as num?)?.toDouble() ?? 0;
      }
      if (!mounted) return;
      setState(() {
        _valeurs = vals;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _valeurs.fold<double>(0, (s, v) => s + v);
    final maxVal = _valeurs.fold<double>(0, (m, v) => v > m ? v : m);
    final years = List<int>.generate(6, (i) => DateTime.now().year - i);

    return Scaffold(
      appBar: AppBar(
        leading: const BrandLogo(),
        title: Text(widget.titre),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _charger,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Text('Année', style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      DropdownButton<int>(
                        value: _year,
                        items: years.map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                        onChanged: (y) {
                          if (y == null) return;
                          setState(() => _year = y);
                          _charger();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    color: widget.color.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.16 : 0.10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: widget.color.withValues(alpha: 0.35)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(widget.kind == 'ventes' ? Icons.trending_up : Icons.trending_down, color: _accent(context), size: 28),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total $_year', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              Text(formatAmountFcfa(total),
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _accent(context))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null && _error!.isNotEmpty)
                    Card(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.red.shade900.withValues(alpha: 0.30)
                          : Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _error!,
                          style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.red.shade200 : Colors.red),
                        ),
                      ),
                    ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 16, 16, 12),
                      child: SizedBox(
                        height: 260,
                        child: total <= 0
                            ? const Center(child: Text('Aucune donnée pour cette année', style: TextStyle(color: Colors.grey)))
                            : _barChart(maxVal),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // Couleur d'accent éclaircie en mode sombre pour rester lisible sur fond foncé.
  Color _accent(BuildContext context) {
    if (Theme.of(context).brightness != Brightness.dark) return widget.color;
    final hsl = HSLColor.fromColor(widget.color);
    return hsl.withLightness((hsl.lightness + 0.20).clamp(0.0, 1.0)).toColor();
  }

  Widget _barChart(double maxVal) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal * 1.15,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              '${_moisLongs[group.x]}\n${formatAmountFcfa(rod.toY)}',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11),
            ),
          ),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) {
                if (value == meta.min) return const SizedBox.shrink();
                return Text(formatCompactNumber(value), style: const TextStyle(fontSize: 9));
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 20,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i > 11) return const SizedBox.shrink();
                return Padding(padding: const EdgeInsets.only(top: 4), child: Text(_moisCourts[i], style: const TextStyle(fontSize: 10)));
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < 12; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: _valeurs[i],
                  color: widget.color,
                  width: 12,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
