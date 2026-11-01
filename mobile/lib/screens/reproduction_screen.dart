import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/couvee.dart';
import '../providers/reproduction_provider.dart';
import '../utils/couvoir.dart';
import '../utils/crm_labels.dart';
import '../widgets/add_button.dart';
import '../widgets/brand_logo.dart';
import '../widgets/empty_state.dart';
import 'couvoir/couvee_detail_screen.dart';
import 'couvoir/couvee_dialogs.dart';
import 'couvoir/couvee_widgets.dart';

/// Couvoir : couvées en incubation et historique.
class ReproductionScreen extends StatefulWidget {
  const ReproductionScreen({super.key});

  @override
  State<ReproductionScreen> createState() => _ReproductionScreenState();
}

class _ReproductionScreenState extends State<ReproductionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ReproductionProvider>().charger();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReproductionProvider>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: const BrandLogo(),
          title: const Text('Couvoir'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: AddButton(tooltip: 'Mise en incubation', icon: Icons.egg_alt, onPressed: () => showMiseEnIncubation(context)),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(icon: const Icon(Icons.egg_alt_outlined, size: 20), text: 'En cours (${provider.actives.length})'),
              Tab(icon: const Icon(Icons.history, size: 20), text: 'Historique (${provider.historique.length})'),
            ],
          ),
        ),
        body: provider.isLoading && provider.couvees.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _Liste(provider: provider, couvees: _triees(provider.actives), enCours: true),
                  _Liste(provider: provider, couvees: provider.historique, enCours: false),
                ],
              ),
      ),
    );
  }

  /// En incubation d'abord (éclosion la plus proche en tête), puis les couvées écloses.
  List<Couvee> _triees(List<Couvee> couvees) {
    int cle(Couvee c) {
      final av = enIncubation(c) ? avancementCouvee(c) : null;
      return av?.joursRestants ?? 100000;
    }

    return [...couvees]..sort((a, b) => cle(a).compareTo(cle(b)));
  }
}

class _Liste extends StatelessWidget {
  final ReproductionProvider provider;
  final List<Couvee> couvees;
  final bool enCours;

  const _Liste({required this.provider, required this.couvees, required this.enCours});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: provider.charger,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          if (provider.lastError != null && provider.lastError!.isNotEmpty)
            Card(
              color: Colors.red.withValues(alpha: 0.12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(provider.lastError!, style: const TextStyle(color: Colors.red)),
              ),
            ),
          if (enCours) _Resume(resumeCouvoir(provider.couvees)) else _PerformancesHistorique(couvees),
          const SizedBox(height: 12),
          if (couvees.isEmpty)
            EmptyState(
              icon: Icons.egg_alt_outlined,
              title: enCours ? 'Aucune couvée en cours' : 'Aucune couvée terminée',
              subtitle: enCours ? 'Mettez des œufs en incubation avec le bouton en haut à droite.' : null,
            )
          else
            for (final c in couvees) _CouveeCarte(c),
        ],
      ),
    );
  }
}

class _Resume extends StatelessWidget {
  final ResumeCouvoir r;
  const _Resume(this.r);

  @override
  Widget build(BuildContext context) {
    final av = r.prochaineAvancement;
    final tuiles = [
      ('En incubation', '${r.oeufsEnIncubation}', r.enCours <= 1 ? '${r.enCours} couvée' : '${r.enCours} couvées', Icons.egg_outlined,
          Colors.amber),
      (
        'Prochaine éclosion',
        av == null ? '—' : (av.joursRestants <= 0 ? 'Maintenant' : 'J-${av.joursRestants}'),
        av == null ? 'aucune couvée' : '${r.prochaine!.code} · ${formatDateFr(av.eclosionPrevue)}',
        Icons.egg_alt,
        av != null && av.enRetard ? Colors.orange : Colors.green,
      ),
      (
        'Taux d’éclosion',
        r.tauxEclosion12Mois == null ? '—' : '${r.tauxEclosion12Mois!.toStringAsFixed(0)} %',
        '12 mois · objectif ${objectifEclosionPct.round()} %',
        Icons.percent,
        r.tauxEclosion12Mois == null || r.tauxEclosion12Mois! >= objectifEclosionPct ? Colors.teal : Colors.orange,
      ),
      ('Poussins', '${r.poussins12Mois}', 'sur 12 mois', Icons.pets, Colors.brown),
    ];
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, cs) {
      final col = cs.maxWidth >= 640 ? 4 : 2;
      final w = (cs.maxWidth - (col - 1) * 8) / col;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final t in tuiles)
            Container(
              width: w,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: t.$5.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: t.$5.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(t.$4, color: t.$5, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(t.$2, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                        ),
                        Text(t.$3, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    });
  }
}

/// Taux d'éclosion des dernières couvées terminées, comparé à l'objectif.
class _PerformancesHistorique extends StatelessWidget {
  final List<Couvee> couvees;
  const _PerformancesHistorique(this.couvees);

  @override
  Widget build(BuildContext context) {
    final avecTaux = couvees.where((c) => tauxEclosionIncubes(c) != null).take(12).toList().reversed.toList();
    if (avecTaux.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Taux d’éclosion des dernières couvées', style: TextStyle(fontWeight: FontWeight.w700)),
            Text('Trait : objectif ${objectifEclosionPct.round()} %', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            SizedBox(
              height: 170,
              child: BarChart(
                BarChartData(
                  maxY: 100,
                  minY: 0,
                  gridData: const FlGridData(drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  extraLinesData: ExtraLinesData(horizontalLines: [
                    HorizontalLine(y: objectifEclosionPct, color: scheme.onSurface.withValues(alpha: 0.6), strokeWidth: 1, dashArray: [4, 4]),
                  ]),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                        '${avecTaux[group.x].code}\n${rod.toY.toStringAsFixed(1)} %',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: 25,
                        getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(fontSize: 9)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 20,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= avecTaux.length) return const SizedBox.shrink();
                          final code = avecTaux[i].code;
                          return Text(code.length > 6 ? '${code.substring(0, 6)}…' : code, style: const TextStyle(fontSize: 9));
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < avecTaux.length; i++)
                      () {
                        final t = tauxEclosionIncubes(avecTaux[i])!;
                        return BarChartGroupData(x: i, barRods: [
                          BarChartRodData(
                            toY: t,
                            width: 14,
                            borderRadius: BorderRadius.circular(4),
                            color: t >= objectifEclosionPct ? Colors.green : (t >= objectifEclosionPct - 15 ? Colors.orange : Colors.red),
                          ),
                        ]);
                      }(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CouveeCarte extends StatelessWidget {
  final Couvee c;
  const _CouveeCarte(this.c);

  @override
  Widget build(BuildContext context) {
    final inc = incubationPour(c.race);
    final av = enIncubation(c) ? avancementCouvee(c) : null;
    final alertes = alertesCouvee(c);
    final statutCouleur = statutCouveeCouleur(c.statut);
    final te = tauxEclosionIncubes(c);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CouveeDetailScreen(couvee: c))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: av != null
                      ? [Colors.amber.shade800, Colors.amber.shade500]
                      : [statutCouleur.shade600, statutCouleur.shade400],
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    child: Icon(av != null ? Icons.egg_outlined : Icons.egg_alt, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.code,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text(
                          [
                            if (c.race.isNotEmpty) c.race else inc.espece,
                            '${c.nbOeufsIncubes} œufs',
                            if (c.dateMiseIncubation != null) 'le ${formatDateFr(c.dateMiseIncubation!.toLocal())}',
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.92)),
                        ),
                      ],
                    ),
                  ),
                  if (av == null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(20)),
                      child: Text(statutCouveeLibelle(c.statut),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statutCouleur.shade800)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (av != null) AvancementIncubation(av) else EntonnoirMini(c),
                  if (av == null && te != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Éclosion ${te.toStringAsFixed(1)} % des œufs',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: te >= objectifEclosionPct ? Colors.green.shade700 : Colors.orange.shade800,
                      ),
                    ),
                  ],
                  if (alertes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    AlertesCouveePills(alertes),
                  ],
                  if (av != null || c.statut == 'eclos') ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: av != null
                          ? FilledButton.tonalIcon(
                              onPressed: () => showSaisieEclosion(context, c),
                              icon: const Icon(Icons.egg_alt, size: 18),
                              label: const Text('Saisir l’éclosion'),
                            )
                          : OutlinedButton.icon(
                              onPressed: () => cloturerCouvee(context, c),
                              icon: const Icon(Icons.check_circle_outline, size: 18),
                              label: const Text('Clôturer'),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
