import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/finance_provider.dart';
import '../../utils/finance.dart';
import '../../utils/money_format.dart';
import '../../widgets/crm/crm_widgets.dart';
import 'finance_common.dart';
import 'operation_sheet.dart';

/// Accueil Finance : « Où en est mon argent ? » en un coup d'œil.
class FinanceAccueilTab extends StatelessWidget {
  const FinanceAccueilTab({super.key});

  Future<void> _saisir(BuildContext context, {required bool entree}) async {
    final ok = await showOperationSheet(context, entree: entree);
    if (ok == true && context.mounted) {
      financeSnack(context, entree ? 'Entrée d’argent enregistrée' : 'Dépense enregistrée');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    if (!provider.accueilCharge) return const Center(child: CircularProgressIndicator());

    final now = DateTime.now();
    final mvts = provider.mouvementsRecents;
    final mois = derniersMois(mvts, now: now);
    final ce = mois.last;
    final prec = mois[mois.length - 2];
    final postes = depensesParPoste(mvts, now.year, now.month);
    final conseils = conseilsFinance(
      mouvements: mvts,
      now: now,
      soldeDans3Mois: provider.soldeDans3Mois,
      bandes: provider.analytiqueBandes,
    );
    final solde = ((provider.solde['soldeCaisse'] ?? 0) as num).toDouble();
    final large = MediaQuery.sizeOf(context).width >= 700;

    final kpis = [
      _MoisKpi(
        label: 'Entrées',
        valeur: ce.entrees,
        couleur: Colors.green.shade700,
        tendance: variationPct(ce.entrees, prec.entrees),
      ),
      _MoisKpi(
        label: 'Sorties',
        valeur: ce.sorties,
        couleur: Colors.red.shade700,
        tendance: variationPct(ce.sorties, prec.sorties),
        hausseMauvaise: true,
      ),
      _MoisKpi(label: 'Reste', valeur: ce.net, couleur: ce.net >= 0 ? Colors.teal.shade700 : Colors.orange.shade800),
    ];

    return RefreshIndicator(
      onRefresh: () => provider.chargerAccueil(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          if (provider.soldeErreur || provider.mouvementsErreur)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                child: const ListTile(
                  dense: true,
                  leading: Icon(Icons.cloud_off_outlined, color: Colors.orange),
                  title: Text('Certaines données n’ont pas pu être chargées. Tirez vers le bas pour réessayer.'),
                ),
              ),
            ),
          _SoldeCarte(
            solde: provider.soldeErreur ? null : solde,
            onDepense: () => _saisir(context, entree: false),
            onEntree: () => _saisir(context, entree: true),
          ),
          const SizedBox(height: 12),
          CrmSectionHeader('Ce mois-ci · ${ce.libelle}', icon: Icons.calendar_month_outlined),
          if (provider.accueilTronque)
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, 6),
              child: Text(
                'Plus de 1000 mouvements sur un mois : les totaux de ce mois sont partiels (voir Mouvements).',
                style: TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ),
          Row(
            children: [
              for (var i = 0; i < kpis.length; i++) ...[if (i > 0) const SizedBox(width: 6), Expanded(child: kpis[i])],
            ],
          ),
          if (conseils.isNotEmpty) ...[
            const SizedBox(height: 8),
            const CrmSectionHeader('À retenir', icon: Icons.lightbulb_outline),
            CrmCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final c in conseils)
                    ListTile(
                      dense: true,
                      leading: Icon(c.icon, color: c.color),
                      title: Text(c.texte, style: const TextStyle(fontSize: 14)),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 4),
          if (large)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _GraphiqueMois(mois: mois)),
                const SizedBox(width: 12),
                Expanded(
                  child: _OuPartArgent(postes: postes, total: ce.sorties),
                ),
              ],
            )
          else ...[
            _GraphiqueMois(mois: mois),
            _OuPartArgent(postes: postes, total: ce.sorties),
          ],
        ],
      ),
    );
  }
}

/// Indicateur du mois : libellé, montant et évolution par rapport au mois précédent.
class _MoisKpi extends StatelessWidget {
  final String label;
  final double valeur;
  final Color couleur;
  final double? tendance;

  /// Une hausse est mauvaise (sorties) : affichée en rouge.
  final bool hausseMauvaise;

  const _MoisKpi({
    required this.label,
    required this.valeur,
    required this.couleur,
    this.tendance,
    this.hausseMauvaise = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = tendance;
    final bon = t == null || (t >= 0) != hausseMauvaise;
    return CrmCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatCompactFcfa(valeur),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: couleur),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              t == null ? ' ' : '${t >= 0 ? '▲' : '▼'} ${t.abs().round()} % vs mois dernier',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: bon ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoldeCarte extends StatelessWidget {
  /// null : solde indisponible (erreur de chargement).
  final double? solde;
  final VoidCallback onDepense;
  final VoidCallback onEntree;

  const _SoldeCarte({required this.solde, required this.onDepense, required this.onEntree});

  @override
  Widget build(BuildContext context) {
    final positif = (solde ?? 0) >= 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: positif ? const [Color(0xFF0B5D3B), Color(0xFF2E7D32)] : const [Color(0xFF7A1F1F), Color(0xFFC62828)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Argent disponible', style: TextStyle(color: Colors.white.withValues(alpha: 0.9))),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              solde == null ? '—' : fcfa(solde!),
              key: const Key('finance-solde'),
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            positif
                ? 'Total des entrées moins les sorties depuis le début.'
                : 'Attention : vous avez dépensé plus que ce qui est entré.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.red.shade700),
                  onPressed: onDepense,
                  icon: const Icon(Icons.remove_circle_outline),
                  label: const FittedBox(child: Text('Dépense')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: onEntree,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const FittedBox(child: Text('Entrée d’argent')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GraphiqueMois extends StatelessWidget {
  final List<MoisFinance> mois;

  const _GraphiqueMois({required this.mois});

  @override
  Widget build(BuildContext context) {
    final vide = mois.every((m) => m.entrees == 0 && m.sorties == 0);
    return CrmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Entrées et sorties sur 6 mois', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Row(
            children: [
              _Legende(Colors.green.shade600, 'Entrées'),
              const SizedBox(width: 12),
              _Legende(Colors.red.shade400, 'Sorties'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: vide
                ? const Center(
                    child: Text('Pas encore de mouvement sur cette période.', style: TextStyle(color: Colors.grey)),
                  )
                : BarChart(
                    BarChartData(
                      gridData: const FlGridData(drawVerticalLine: false),
                      borderData: FlBorderData(show: false),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, _, rod, rodIndex) => BarTooltipItem(
                            '${mois[group.x].court} · ${rodIndex == 0 ? 'Entrées' : 'Sorties'}\n${fcfa(rod.toY)}',
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
                              if (i < 0 || i >= mois.length) return const SizedBox.shrink();
                              return Text(mois[i].court, style: const TextStyle(fontSize: 10));
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        for (var i = 0; i < mois.length; i++)
                          BarChartGroupData(
                            x: i,
                            barsSpace: 3,
                            barRods: [
                              BarChartRodData(
                                toY: mois[i].entrees,
                                width: 9,
                                color: Colors.green.shade600,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              BarChartRodData(
                                toY: mois[i].sorties,
                                width: 9,
                                color: Colors.red.shade400,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
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

class _OuPartArgent extends StatelessWidget {
  final List<MapEntry<String, double>> postes;
  final double total;

  const _OuPartArgent({required this.postes, required this.total});

  @override
  Widget build(BuildContext context) {
    final top = postes.take(5).toList();
    return CrmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text('Où part l’argent ce mois-ci', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          if (top.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('Aucune dépense ce mois-ci.', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            for (final e in top)
              _PosteBarre(poste: postePour(e.key), montant: e.value, part: total <= 0 ? 0 : e.value / total),
        ],
      ),
    );
  }
}

class _PosteBarre extends StatelessWidget {
  final FinancePoste poste;
  final double montant;
  final double part;

  const _PosteBarre({required this.poste, required this.montant, required this.part});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(poste.icon, size: 20, color: poste.color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(poste.libelle, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Text('${(part * 100).round()} %', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: part.clamp(0, 1).toDouble(),
                  minHeight: 6,
                  color: poste.color,
                  backgroundColor: poste.color.withValues(alpha: 0.12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(formatCompactFcfa(montant), style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}
