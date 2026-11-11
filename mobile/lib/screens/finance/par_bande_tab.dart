import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/finance_provider.dart';
import '../../utils/finance.dart';
import '../../widgets/crm/crm_widgets.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/repartition_couts_chart.dart';
import '../bande_bilan_screen.dart';
import 'configuration_tab.dart';

double _n(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

/// Rentabilité par bande (données /finance/analytique) : marge, coût au kg, prix minimum.
class ParBandeTab extends StatefulWidget {
  const ParBandeTab({super.key});

  @override
  State<ParBandeTab> createState() => _ParBandeTabState();
}

class _ParBandeTabState extends State<ParBandeTab> {
  bool _terminees = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    if (!provider.accueilCharge) return const Center(child: CircularProgressIndicator());

    final toutes = provider.analytiqueBandes;
    final bandes = toutes.where((b) => ((b['statut'] ?? '') == 'fermee') == _terminees).toList();
    final marge = bandes.fold<double>(0, (s, b) => s + _n(b['margeNette']));

    return RefreshIndicator(
      onRefresh: () => provider.chargerAccueil(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: false,
                      label: Text('En cours (${toutes.where((b) => b['statut'] != 'fermee').length})'),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Terminées (${toutes.where((b) => b['statut'] == 'fermee').length})'),
                    ),
                  ],
                  selected: {_terminees},
                  onSelectionChanged: (s) => setState(() => _terminees = s.first),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (bandes.isEmpty)
            EmptyState(
              icon: Icons.egg_outlined,
              title: _terminees ? 'Aucune bande terminée' : 'Aucune bande en cours',
              subtitle:
                  'La rentabilité de chaque bande s’affiche ici à partir des dépenses qui lui sont rattachées et de ses ventes.',
            )
          else ...[
            CrmCard(
              child: Row(
                children: [
                  Icon(
                    marge >= 0 ? Icons.trending_up : Icons.trending_down,
                    color: marge >= 0 ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _terminees ? 'Résultat des bandes terminées' : 'Résultat actuel des bandes en cours',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    fcfa(marge),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: marge >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
            CrmCard(
              child: RepartitionCoutsChart(
                postes: postesCoutBandes(bandes),
                titre: _terminees ? 'Coûts des bandes terminées' : 'Coûts des bandes en cours',
              ),
            ),
            for (final b in bandes) _BandeCarte(bande: b),
          ],
        ],
      ),
    );
  }
}

class _BandeCarte extends StatelessWidget {
  final Map<String, dynamic> bande;

  const _BandeCarte({required this.bande});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fermee = bande['statut'] == 'fermee';
    final marge = _n(bande['margeNette']);
    final revenus = _n(bande['revenus']);
    final cout = _n(bande['coutTotal']);
    final coutKg = bande['coutParKg'] == null ? null : _n(bande['coutParKg']);
    final prixMin = _n(bande['seuilRentabiliteParSujet']);
    // Animaux élevés (vendus ou présents) : le prix minimum reste utile après les premières ventes.
    final effectif = bande['effectifProduit'] != null ? _n(bande['effectifProduit']) : _n(bande['effectifVivant']);
    final couts = resumeCoutsBande(bande);

    final String message;
    final Color couleur;
    if (fermee) {
      message = marge >= 0 ? 'Terminée avec un bénéfice' : 'Terminée en perte';
      couleur = marge >= 0 ? Colors.green : Colors.red;
    } else if (revenus <= 0) {
      message = 'Pas encore de vente : dépenses engagées';
      couleur = Colors.blueGrey;
    } else {
      message = marge >= 0 ? 'Rentable à ce jour' : 'Pas encore rentable';
      couleur = marge >= 0 ? Colors.green : Colors.orange;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BandeBilanScreen(bande: bande))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (bande['bandeNom'] ?? 'Bande').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    fcfa(marge),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: marge >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.circle, size: 8, color: couleur),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(message, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _Mesure('Dépensé', fcfa(cout)),
                  _Mesure('Vendu', fcfa(revenus)),
                  _Mesure('Coût au kg', coutKg == null ? '—' : fcfa(coutKg)),
                ],
              ),
              if (prixMin > 0 && effectif > 0) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Prix minimum : '),
                        TextSpan(
                          text: '${fcfa(prixMin)} par sujet',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const TextSpan(text: ' pour ne pas perdre d’argent.'),
                      ],
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
              // Simple rappel : la saisie se fait dans l'onglet Configuration.
              if (couts != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.tune, size: 14, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        couts,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Mesure extends StatelessWidget {
  final String label;
  final String valeur;

  const _Mesure(this.label, this.valeur);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(valeur, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
}
