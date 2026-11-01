import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/cheptel.dart';
import '../../utils/cheptel.dart';
import 'mouvement_sheet.dart';

/// Pastilles d'alerte d'un troupeau.
class AlertesCheptelPills extends StatelessWidget {
  final List<AlerteCheptel> alertes;
  const AlertesCheptelPills(this.alertes, {super.key});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final a in alertes)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: alerteCheptelCouleurs[a]!.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: alerteCheptelCouleurs[a]!.withValues(alpha: 0.4)),
          ),
          child: Text(
            alerteCheptelLibelles[a]!,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: alerteCheptelCouleurs[a]!.shade700),
          ),
        ),
    ],
  );
}

/// Évolution de l'effectif sur 30 jours (« +5 en 30 j »).
class EvolutionCheptel extends StatelessWidget {
  final int evolution;
  const EvolutionCheptel(this.evolution, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = evolution > 0 ? Colors.green.shade700 : (evolution < 0 ? Colors.red.shade700 : Colors.grey);
    final txt = evolution == 0 ? 'stable sur 30 j' : '${evolution > 0 ? '▲ +' : '▼ '}$evolution en 30 j';
    return Text(
      txt,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c),
    );
  }
}

/// Courbe de l'effectif selon les vraies dates ([mini] = sans axes, pour les cartes).
class CourbeEffectif extends StatelessWidget {
  final Cheptel cheptel;
  final bool mini;
  final Color? couleur;

  const CourbeEffectif(this.cheptel, {super.key, this.mini = false, this.couleur});

  @override
  Widget build(BuildContext context) {
    final pts = courbeEffectif(cheptel);
    final color = couleur ?? Theme.of(context).colorScheme.primary;
    if (pts.length < 2) {
      return mini
          ? const SizedBox.shrink()
          : const Center(
              child: Text(
                'Pas encore assez de mouvements pour tracer la courbe.',
                style: TextStyle(color: Colors.grey),
              ),
            );
    }
    final debut = pts.first.date;
    double x(DateTime d) => d.difference(debut).inDays.toDouble();
    final spots = [for (final p in pts) FlSpot(x(p.date), p.effectif.toDouble())];
    final total = x(pts.last.date);
    return LineChart(
      LineChartData(
        minY: 0,
        gridData: FlGridData(show: !mini, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          enabled: !mini,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${_dateCourte(debut.add(Duration(days: s.x.round())))}\n${s.y.round()} animaux',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                ),
            ],
          ),
        ),
        titlesData: mini
            ? const FlTitlesData(show: false)
            : FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (v, meta) => v == meta.max
                        ? const SizedBox.shrink()
                        : Text(v.toStringAsFixed(0), style: const TextStyle(fontSize: 10)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: total <= 0 ? 1 : (total / 4).ceilToDouble(),
                    getTitlesWidget: (v, meta) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _dateCourte(debut.add(Duration(days: v.round()))),
                        style: const TextStyle(fontSize: 9),
                      ),
                    ),
                  ),
                ),
              ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isStepLineChart: true,
            barWidth: mini ? 2 : 3,
            color: color,
            dotData: FlDotData(show: !mini && spots.length <= 30),
            belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.12)),
          ),
        ],
      ),
    );
  }
}

String _dateCourte(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

/// Boutons rapides de saisie (Naissance, Mort, Vente, Achat, Recompter).
class ActionsRapidesCheptel extends StatelessWidget {
  final Cheptel cheptel;
  final ValueChanged<bool>? onFait;

  const ActionsRapidesCheptel(this.cheptel, {super.key, this.onFait});

  static const _rapides = ['naissance', 'mortalite', 'vente', 'entree', 'ajustement'];

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final v in _rapides)
        () {
          final t = typeMouvement(v);
          return ActionChip(
            avatar: Icon(t.icon, size: 16, color: t.color),
            label: Text(t.court),
            visualDensity: VisualDensity.compact,
            onPressed: () async {
              final ok = await showMouvementCheptelSheet(context, cheptel, type: v);
              if (ok == true && context.mounted) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text('Enregistré : ${t.libelle.toLowerCase()}'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                onFait?.call(true);
              }
            },
          );
        }(),
    ],
  );
}

/// Pastille ronde de l'espèce.
class EspeceAvatar extends StatelessWidget {
  final String espece;
  final double radius;
  final bool surFonce;

  const EspeceAvatar(this.espece, {super.key, this.radius = 20, this.surFonce = false});

  @override
  Widget build(BuildContext context) {
    final e = especePour(espece);
    return CircleAvatar(
      radius: radius,
      backgroundColor: surFonce ? Colors.white.withValues(alpha: 0.25) : e.color.withValues(alpha: 0.15),
      child: Icon(e.icon, size: radius, color: surFonce ? Colors.white : e.color),
    );
  }
}
