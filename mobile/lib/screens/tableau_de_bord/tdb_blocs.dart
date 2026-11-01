import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/bande.dart';
import '../../utils/bande_kpis.dart';
import '../../utils/cheptel.dart';
import '../../utils/finance.dart' show fcfa;
import '../../utils/money_format.dart';
import '../../utils/tableau_de_bord.dart';
import '../../widgets/bandes/bande_widgets.dart';
import '../../widgets/crm/crm_widgets.dart';
import '../tendance_screen.dart';
import 'tdb_source.dart';

const _moisCourts = ['Janv', 'Févr', 'Mars', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sept', 'Oct', 'Nov', 'Déc'];

/// En-tête de bloc : icône, titre et action à droite.
class _Entete extends StatelessWidget {
  final BlocTdb bloc;
  final String? titre;
  final Widget? action;

  const _Entete(this.bloc, {this.titre, this.action});

  @override
  Widget build(BuildContext context) =>
      CrmSectionHeader(titre ?? blocTdbLibelles[bloc]!, icon: blocTdbIcons[bloc]!, trailing: action);
}

// ---------------------------------------------------------------- Aujourd'hui

class AujourdhuiBloc extends StatefulWidget {
  final List<ElementAujourdhui> elements;
  final ValueChanged<ElementAujourdhui> onOuvrir;

  const AujourdhuiBloc({super.key, required this.elements, required this.onOuvrir});

  @override
  State<AujourdhuiBloc> createState() => _AujourdhuiBlocState();
}

class _AujourdhuiBlocState extends State<AujourdhuiBloc> {
  static const _apercu = 5;
  bool _tout = false;

  @override
  Widget build(BuildContext context) {
    final elements = widget.elements;
    final urgents = elements.where((e) => e.urgent).length;
    final affiches = _tout ? elements : elements.take(_apercu).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Entete(
          BlocTdb.aujourdhui,
          titre: elements.isEmpty ? 'À faire aujourd’hui' : 'À faire aujourd’hui (${elements.length})',
        ),
        if (urgents > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                const Icon(Icons.priority_high, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    urgents == 1
                        ? '1 point demande votre attention en priorité'
                        : '$urgents points demandent votre attention en priorité',
                    style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        CrmCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: elements.isEmpty
              ? const ListTile(
                  leading: Icon(Icons.check_circle, color: Colors.green),
                  title: Text('Rien d’urgent aujourd’hui'),
                  subtitle: Text('Tâches, stocks et sorties de bandes sont à jour.'),
                )
              : Column(
                  children: [
                    for (var i = 0; i < affiches.length; i++) ...[
                      if (i > 0) const Divider(height: 1, indent: 64),
                      _ElementLigne(e: affiches[i], onTap: () => widget.onOuvrir(affiches[i])),
                    ],
                    if (elements.length > _apercu)
                      TextButton(
                        onPressed: () => setState(() => _tout = !_tout),
                        child: Text(_tout ? 'Afficher moins' : 'Voir tout (${elements.length})'),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ElementLigne extends StatelessWidget {
  final ElementAujourdhui e;
  final VoidCallback onTap;

  const _ElementLigne({required this.e, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: CircleAvatar(
      backgroundColor: e.color.withValues(alpha: 0.14),
      child: Icon(e.icon, color: e.color, size: 20),
    ),
    title: Text(
      e.titre,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.w600),
    ),
    subtitle: e.detail.isEmpty
        ? null
        : Text(
            e.detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: e.urgent ? Colors.red.shade700 : null),
          ),
    trailing: const Icon(Icons.chevron_right),
  );
}

// ---------------------------------------------------------------- Indicateurs

class IndicateursBloc extends StatelessWidget {
  final PeriodeTdb periode;
  final ValueChanged<PeriodeTdb> onPeriode;
  final ChiffresPeriode? actuel;
  final ChiffresPeriode? precedent;
  final bool charge;
  final double? argentDisponible;
  final ResumeElevage elevage;
  final ResumeCheptel? cheptel;
  final VoidCallback onFinance;
  final VoidCallback onBandes;
  final VoidCallback? onCheptel;

  const IndicateursBloc({
    super.key,
    required this.periode,
    required this.onPeriode,
    required this.actuel,
    required this.precedent,
    required this.charge,
    required this.argentDisponible,
    required this.elevage,
    this.cheptel,
    required this.onFinance,
    required this.onBandes,
    this.onCheptel,
  });

  @override
  Widget build(BuildContext context) {
    final a = actuel;
    final p = precedent;
    final argent = [
      if (argentDisponible != null)
        _Indicateur(
          label: 'Argent disponible',
          valeur: formatCompactFcfa(argentDisponible!),
          icon: Icons.account_balance_wallet_outlined,
          color: argentDisponible! >= 0 ? Colors.teal : Colors.red,
          onTap: onFinance,
        ),
      if (a != null) ...[
        _Indicateur(
          label: 'Ventes',
          valeur: formatCompactFcfa(a.ventes),
          icon: Icons.point_of_sale,
          color: Colors.green,
          evolution: evolutionPct(a.ventes, p?.ventes),
          onTap: onFinance,
        ),
        _Indicateur(
          label: 'Dépenses',
          valeur: formatCompactFcfa(a.depenses),
          icon: Icons.shopping_cart_outlined,
          color: Colors.red,
          evolution: evolutionPct(a.depenses, p?.depenses),
          hausseMauvaise: true,
          onTap: onFinance,
        ),
        _Indicateur(
          label: 'Résultat',
          valeur: formatCompactFcfa(a.resultat),
          icon: a.resultat >= 0 ? Icons.trending_up : Icons.trending_down,
          color: a.resultat >= 0 ? Colors.blue : Colors.orange,
          evolution: evolutionPct(a.resultat, p?.resultat),
          onTap: onFinance,
        ),
      ],
    ];
    final e = elevage;
    final elevageTuiles = [
      _Indicateur(
        label: 'Sujets en élevage',
        valeur: fmtEntier(e.sujets),
        icon: Icons.egg_outlined,
        color: Colors.green,
        legende: e.nbBandes <= 1 ? '${e.nbBandes} bande' : '${e.nbBandes} bandes',
        onTap: onBandes,
      ),
      _Indicateur(
        label: 'Mortalité',
        valeur: '${fmt1(e.mortalitePct)} %',
        icon: Icons.heart_broken_outlined,
        color: e.mortalitePct > 5 ? Colors.red : Colors.blueGrey,
        legende: 'bandes en cours',
        onTap: onBandes,
      ),
      _Indicateur(
        label: 'IC moyen',
        valeur: e.icMoyen == null ? '—' : fmt2(e.icMoyen!),
        icon: Icons.restaurant_outlined,
        color: Colors.brown,
        legende: 'kg d’aliment par kg',
        onTap: onBandes,
      ),
      _Indicateur(
        label: 'Alertes élevage',
        valeur: '${e.nbAlertes}',
        icon: Icons.warning_amber_rounded,
        color: e.nbAlertes > 0 ? Colors.orange : Colors.green,
        legende: e.nbAlertes > 0 ? 'à vérifier' : 'tout va bien',
        onTap: onBandes,
      ),
      if (cheptel != null) ...[
        _Indicateur(
          label: 'Cheptel',
          valeur: fmtEntier(cheptel!.animaux),
          icon: Icons.pets,
          color: Colors.brown,
          legende: cheptel!.troupeaux <= 1 ? '${cheptel!.troupeaux} troupeau' : '${cheptel!.troupeaux} troupeaux',
          onTap: onCheptel,
        ),
        _Indicateur(
          label: 'Cheptel sur 30 j',
          valeur: '+${cheptel!.naissances30j} / −${cheptel!.morts30j}',
          icon: Icons.child_care,
          color: cheptel!.morts30j > cheptel!.naissances30j ? Colors.orange : Colors.green,
          legende: 'naissances / morts',
          onTap: onCheptel,
        ),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Entete(BlocTdb.indicateurs, action: _ChoixPeriode(periode: periode, onPeriode: onPeriode)),
        if (periodeTdbComparaison[periode]!.isNotEmpty && a != null)
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              'Évolution ${periodeTdbComparaison[periode]}',
              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        const SizedBox(height: 8),
        if (!charge)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (argent.isNotEmpty)
          _Grille(argent),
        const SizedBox(height: 8),
        _Grille(elevageTuiles),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Liste de choix de la période (compacte, dans l'en-tête du bloc).
class _ChoixPeriode extends StatelessWidget {
  final PeriodeTdb periode;
  final ValueChanged<PeriodeTdb> onPeriode;

  const _ChoixPeriode({required this.periode, required this.onPeriode});

  @override
  Widget build(BuildContext context) => PopupMenuButton<PeriodeTdb>(
        tooltip: 'Période',
        initialValue: periode,
        onSelected: onPeriode,
        itemBuilder: (_) => [
          for (final p in PeriodeTdb.values) CheckedPopupMenuItem(value: p, checked: p == periode, child: Text(periodeTdbLibelles[p]!)),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.date_range_outlined, size: 16),
              const SizedBox(width: 6),
              Text(periodeTdbLibelles[periode]!, style: const TextStyle(fontWeight: FontWeight.w600)),
              const Icon(Icons.arrow_drop_down, size: 20),
            ],
          ),
        ),
      );
}

class _Grille extends StatelessWidget {
  final List<Widget> enfants;
  const _Grille(this.enfants);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final colonnes = c.maxWidth >= 640 ? 4 : 2;
      final largeur = (c.maxWidth - (colonnes - 1) * 8) / colonnes;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (final e in enfants) SizedBox(width: largeur, child: e)],
      );
    },
  );
}

class _Indicateur extends StatelessWidget {
  final String label;
  final String valeur;
  final IconData icon;
  final MaterialColor color;
  final double? evolution;
  final bool hausseMauvaise;
  final String? legende;
  final VoidCallback? onTap;

  const _Indicateur({
    required this.label,
    required this.valeur,
    required this.icon,
    required this.color,
    this.evolution,
    this.hausseMauvaise = false,
    this.legende,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ev = evolution;
    final bon = ev == null || (ev >= 0) != hausseMauvaise;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(valeur, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: ev != null
                    ? Text(
                        '${ev >= 0 ? '▲' : '▼'} ${ev.abs().round()} %',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: bon ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                      )
                    : Text(legende ?? ' ', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Bandes

class BandesTdbBloc extends StatelessWidget {
  final List<Bande> bandes;
  final Map<String, BandeKpis> kpis;
  final Map<String, double> marges;
  final ValueChanged<Bande> onOuvrir;
  final VoidCallback onToutes;

  const BandesTdbBloc({
    super.key,
    required this.bandes,
    required this.kpis,
    required this.marges,
    required this.onOuvrir,
    required this.onToutes,
  });

  @override
  Widget build(BuildContext context) {
    final ouvertes = bandes.where((b) => b.dateFermeture == null && kpis[b.id] != null).toList()
      ..sort((a, b) => kpis[a.id]!.joursRestants.compareTo(kpis[b.id]!.joursRestants));
    const max = 4;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Entete(
          BlocTdb.bandes,
          titre: 'Bandes en cours (${ouvertes.length})',
          action: TextButton(onPressed: onToutes, child: const Text('Tout voir')),
        ),
        if (ouvertes.isEmpty)
          const CrmCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.egg_outlined),
              title: Text('Aucune bande en cours'),
            ),
          )
        else
          for (final b in ouvertes.take(max))
            _BandeLigne(bande: b, kpis: kpis[b.id]!, marge: marges[b.id], onTap: () => onOuvrir(b)),
        if (ouvertes.length > max)
          TextButton(onPressed: onToutes, child: Text('Voir les ${ouvertes.length - max} autres bandes')),
      ],
    );
  }
}

class _BandeLigne extends StatelessWidget {
  final Bande bande;
  final BandeKpis kpis;
  final double? marge;
  final VoidCallback onTap;

  const _BandeLigne({required this.bande, required this.kpis, required this.marge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ecart = kpis.ecartReferencePct;
    final m = marge;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      bande.nom,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      typeVolailleLabel(bande.typeVolaille),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              CycleProgress(bande: bande, kpis: kpis),
              const SizedBox(height: 8),
              Row(
                children: [
                  _Petit('Effectif', fmtEntier(kpis.effectif)),
                  _Petit(
                    'Poids',
                    kpis.poidsG == null ? '—' : '${fmtEntier(kpis.poidsG!)} g',
                    sous: ecart == null ? null : '${fmtEcart(ecart)} vs réf.',
                    couleur: couleurEcart(ecart),
                  ),
                  _Petit(
                    'Marge',
                    m == null ? '—' : formatCompactFcfa(m),
                    couleur: m == null ? null : (m >= 0 ? Colors.green : Colors.red),
                  ),
                ],
              ),
              if (kpis.alertes.isNotEmpty) ...[const SizedBox(height: 8), BandeAlertesPills(alertes: kpis.alertes)],
            ],
          ),
        ),
      ),
    );
  }
}

class _Petit extends StatelessWidget {
  final String label;
  final String valeur;
  final String? sous;
  final MaterialColor? couleur;

  const _Petit(this.label, this.valeur, {this.sous, this.couleur});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            valeur,
            style: TextStyle(fontWeight: FontWeight.w700, color: couleur?.shade700),
          ),
        ),
        if (sous != null)
          Text(
            sous!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: couleur?.shade700),
          ),
      ],
    ),
  );
}

// ---------------------------------------------------------------- Tendance

class TendanceBloc extends StatelessWidget {
  final List<MoisTendance>? mois;
  final bool charge;

  const TendanceBloc({super.key, required this.mois, required this.charge});

  void _detail(BuildContext context, bool ventes) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ventes
          ? const TendanceScreen(titre: 'Tendance des ventes', kind: 'ventes', color: Colors.green)
          : const TendanceScreen(titre: 'Tendance des dépenses', kind: 'depenses', color: Colors.red),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final m = mois;
    final ventes = m?.fold<double>(0, (s, x) => s + x.ventes) ?? 0;
    final depenses = m?.fold<double>(0, (s, x) => s + x.depenses) ?? 0;
    final resultat = ventes - depenses;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Entete(BlocTdb.tendance),
        CrmCard(
          child: !charge
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              : m == null
              ? const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.bar_chart),
                  title: Text('Données indisponibles'),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        _Legende(Colors.green.shade600, 'Ventes ${formatCompactFcfa(ventes)}'),
                        _Legende(Colors.red.shade400, 'Dépenses ${formatCompactFcfa(depenses)}'),
                        Text(
                          'Résultat ${fcfa(resultat)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: resultat >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(height: 190, child: _Barres(m)),
                    Wrap(
                      children: [
                        TextButton(onPressed: () => _detail(context, true), child: const Text('Détail des ventes')),
                        TextButton(onPressed: () => _detail(context, false), child: const Text('Détail des dépenses')),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Barres extends StatelessWidget {
  final List<MoisTendance> mois;
  const _Barres(this.mois);

  @override
  Widget build(BuildContext context) {
    if (mois.every((x) => x.ventes == 0 && x.depenses == 0)) {
      return const Center(
        child: Text('Pas encore de ventes ni de dépenses.', style: TextStyle(color: Colors.grey)),
      );
    }
    return BarChart(
      BarChartData(
        gridData: const FlGridData(drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, _, rod, rodIndex) {
              final x = mois[group.x];
              return BarTooltipItem(
                '${_moisCourts[x.mois - 1]} ${x.annee}\n${rodIndex == 0 ? 'Ventes' : 'Dépenses'} : ${fcfa(rod.toY)}',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, meta) => v == meta.max
                  ? const SizedBox.shrink()
                  : Text(formatCompactNumber(v), style: const TextStyle(fontSize: 9)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= mois.length || (mois.length > 6 && i.isOdd && i != mois.length - 1)) {
                  return const SizedBox.shrink();
                }
                return Text(_moisCourts[mois[i].mois - 1], style: const TextStyle(fontSize: 10));
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < mois.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 2,
              barRods: [
                BarChartRodData(
                  toY: mois[i].ventes,
                  width: 6,
                  color: Colors.green.shade600,
                  borderRadius: BorderRadius.circular(2),
                ),
                BarChartRodData(
                  toY: mois[i].depenses,
                  width: 6,
                  color: Colors.red.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Legende extends StatelessWidget {
  final Color couleur;
  final String texte;

  const _Legende(this.couleur, this.texte);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: couleur, borderRadius: BorderRadius.circular(3)),
      ),
      const SizedBox(width: 4),
      Text(texte, style: const TextStyle(fontSize: 12)),
    ],
  );
}

// ---------------------------------------------------------------- Commercial

class CommercialBloc extends StatelessWidget {
  final SocleTdb? socle;
  final VoidCallback onCrm;

  const CommercialBloc({super.key, required this.socle, required this.onCrm});

  @override
  Widget build(BuildContext context) {
    final s = socle;
    if (s != null && !s.commercialDisponible) return const SizedBox.shrink();
    final tuiles = [
      _Indicateur(
        label: 'Relances à faire',
        valeur: s?.relancesAFaire == null ? '—' : '${s!.relancesAFaire}',
        icon: Icons.phone_in_talk_outlined,
        color: (s?.relancesAFaire ?? 0) > 0 ? Colors.orange : Colors.green,
        legende: 'clients à recontacter',
        onTap: onCrm,
      ),
      _Indicateur(
        label: 'Commandes en attente',
        valeur: s?.commandesEnAttente == null ? '—' : '${s!.commandesEnAttente}',
        icon: Icons.hourglass_bottom,
        color: Colors.purple,
        legende: 'à confirmer',
        onTap: onCrm,
      ),
      _Indicateur(
        label: 'Affaires en cours',
        valeur: s?.previsionPonderee == null ? '—' : formatCompactFcfa(s!.previsionPonderee!),
        icon: Icons.handshake_outlined,
        color: Colors.indigo,
        legende: 'prévision pondérée',
        onTap: onCrm,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Entete(
          BlocTdb.commercial,
          action: TextButton(onPressed: onCrm, child: const Text('Ouvrir le CRM')),
        ),
        LayoutBuilder(
          builder: (context, c) {
            final colonnes = c.maxWidth >= 480 ? 3 : 2;
            final largeur = (c.maxWidth - (colonnes - 1) * 8) / colonnes;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final t in tuiles) SizedBox(width: largeur, child: t)],
            );
          },
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ---------------------------------------------------------------- Personnaliser

/// Ordre et visibilité des blocs (glisser-déposer + interrupteurs).
class PersonnaliserTdbSheet extends StatefulWidget {
  final List<BlocTdb> ordre;
  final Set<BlocTdb> masques;
  final void Function(List<BlocTdb> ordre, Set<BlocTdb> masques) onChange;

  const PersonnaliserTdbSheet({super.key, required this.ordre, required this.masques, required this.onChange});

  @override
  State<PersonnaliserTdbSheet> createState() => _PersonnaliserTdbSheetState();
}

class _PersonnaliserTdbSheetState extends State<PersonnaliserTdbSheet> {
  late final List<BlocTdb> _ordre = [...widget.ordre];
  late final Set<BlocTdb> _masques = {...widget.masques};

  void _notifier() => widget.onChange([..._ordre], {..._masques});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Personnaliser', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _ordre
                        ..clear()
                        ..addAll(BlocTdb.values);
                      _masques.clear();
                    });
                    _notifier();
                  },
                  child: const Text('Par défaut'),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Maintenez et glissez pour changer l’ordre ; l’interrupteur affiche ou masque un bloc.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          Flexible(
            child: ReorderableListView(
              shrinkWrap: true,
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  _ordre.insert(newIndex, _ordre.removeAt(oldIndex));
                });
                _notifier();
              },
              children: [
                for (var i = 0; i < _ordre.length; i++)
                  Card(
                    key: ValueKey(_ordre[i]),
                    elevation: 0,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    child: ListTile(
                      leading: ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle)),
                      title: Row(
                        children: [
                          Icon(blocTdbIcons[_ordre[i]], size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(blocTdbLibelles[_ordre[i]]!, overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                      trailing: Switch(
                        value: !_masques.contains(_ordre[i]),
                        onChanged: (v) {
                          setState(() => v ? _masques.remove(_ordre[i]) : _masques.add(_ordre[i]));
                          _notifier();
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Terminé')),
          ),
        ],
      ),
    );
  }
}
