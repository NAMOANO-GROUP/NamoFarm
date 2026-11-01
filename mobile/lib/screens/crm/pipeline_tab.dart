import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/client.dart';
import '../../models/crm_pipeline.dart';
import '../../providers/crm_provider.dart';
import '../../utils/crm_labels.dart';
import '../../utils/money_format.dart';
import '../../widgets/crm/crm_charts.dart';
import '../../widgets/crm/crm_widgets.dart';
import '../../widgets/crm/kanban_board.dart';
import 'client_detail_screen.dart';
import 'crm_common.dart';
import 'deal_dialog.dart';

enum _PipelineView { tableau, analyse }

class PipelineTab extends StatefulWidget {
  const PipelineTab({super.key});

  @override
  State<PipelineTab> createState() => _PipelineTabState();
}

class _PipelineTabState extends State<PipelineTab> {
  _PipelineView _view = _PipelineView.tableau;

  Future<void> _move(PipelineDeal deal, String stage) async {
    final crm = context.read<CrmProvider>();
    final ok = await crm.deplacerDeal(deal, stage);
    if (!mounted) return;
    showCrmSnack(
      context,
      ok ? '${deal.nomComplet} → ${pipelineStage(stage).label}' : 'Déplacement impossible, réessayez',
      action: ok
          ? SnackBarAction(label: 'Annuler', onPressed: () => crm.restaurerDeal(deal))
          : null,
    );
  }

  void _openClient(PipelineDeal deal) {
    final client = Client(
      id: deal.clientId,
      nom: deal.nom,
      prenom: deal.prenom,
      telephone: deal.telephone,
      entreprise: deal.entreprise,
      statut: deal.statut,
      chiffreAffairesCumul: deal.chiffreAffairesCumul,
    );
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClientDetailScreen(client: client)));
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.watch<CrmProvider>();
    final deals = crm.deals;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Wrap(
                spacing: 18,
                runSpacing: 6,
                children: [
                  _Summary('En cours', formatCompactFcfa(crm.montantOuvert), Icons.account_balance_wallet_outlined),
                  _Summary('Prévision pondérée', formatCompactFcfa(crm.previsionPonderee), Icons.insights_outlined),
                  _Summary('Conversion', '${crm.conversionRate.toStringAsFixed(1)} %', Icons.percent),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<_PipelineView>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: _PipelineView.tableau, icon: Icon(Icons.view_kanban_outlined), tooltip: 'Tableau'),
                      ButtonSegment(value: _PipelineView.analyse, icon: Icon(Icons.bar_chart), tooltip: 'Analyse'),
                    ],
                    selected: {_view},
                    onSelectionChanged: (v) => setState(() => _view = v.first),
                  ),
                  IconButton(
                    tooltip: 'Actualiser',
                    icon: const Icon(Icons.refresh),
                    onPressed: () => context.read<CrmProvider>().chargerPipelineCommercial(),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (crm.isLoading && deals.isEmpty) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: _view == _PipelineView.tableau
              ? KanbanBoard<PipelineDeal>(
                  itemKey: (d) => d.clientId,
                  onMove: _move,
                  emptyLabel: 'Glissez une affaire ici',
                  columns: [
                    for (final stage in pipelineStages)
                      () {
                        final items = deals.where((d) => d.stage == stage.value).toList()
                          ..sort((a, b) => b.montant.compareTo(a.montant));
                        final total = items.fold<double>(0, (s, d) => s + d.montant);
                        return KanbanColumn<PipelineDeal>(
                          id: stage.value,
                          title: stage.label,
                          icon: stage.icon,
                          color: stage.color,
                          items: items,
                          subtitle: total > 0 ? formatCompactFcfa(total) : null,
                        );
                      }(),
                  ],
                  itemBuilder: (context, deal) => DealCard(
                    deal: deal,
                    onTap: () => showDealDialog(context, deal),
                    onOpenClient: () => _openClient(deal),
                    onMove: (stage) => _move(deal, stage),
                  ),
                )
              : _Analyse(crm: crm),
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _Summary(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(label, style: TextStyle(fontSize: 11, color: muted)),
          ],
        ),
      ],
    );
  }
}

/// Carte d'affaire : client, montant, probabilité, clôture et score.
class DealCard extends StatelessWidget {
  final PipelineDeal deal;
  final VoidCallback onTap;
  final VoidCallback onOpenClient;
  final ValueChanged<String> onMove;

  const DealCard({super.key, required this.deal, required this.onTap, required this.onOpenClient, required this.onMove});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cloture = deal.dateCloturePrevue;
    final enRetard = cloture != null && daysFromToday(cloture) < 0 && deal.stage != 'gagne' && deal.stage != 'perdu';
    final sc = scoreColor(deal.score);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 0, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClientAvatar(name: deal.nomComplet, radius: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(deal.nomComplet,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                        if (deal.entreprise.isNotEmpty)
                          Text(deal.entreprise,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Actions de l’affaire',
                    icon: const Icon(Icons.more_vert, size: 18),
                    onSelected: (v) {
                      if (v == 'open') return onOpenClient();
                      if (v == 'edit') return onTap();
                      if (v.startsWith('move:')) onMove(v.substring(5));
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'open', child: Text('Ouvrir la fiche client')),
                      const PopupMenuItem(value: 'edit', child: Text("Modifier l'affaire")),
                      const PopupMenuDivider(),
                      for (final s in pipelineStages.where((s) => s.value != deal.stage))
                        PopupMenuItem(value: 'move:${s.value}', child: Text('Déplacer vers « ${s.label} »')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        deal.montant > 0 ? formatAmountFcfa(deal.montant) : 'Montant à estimer',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: deal.montant > 0 ? null : scheme.onSurfaceVariant,
                          fontStyle: deal.montant > 0 ? null : FontStyle.italic,
                        ),
                      ),
                    ),
                    Tooltip(
                      message: 'Score ${deal.score.round()}/100',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: sc.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                        child: Text('${deal.score.round()}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: sc.shade700)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Row(
                  children: [
                    Icon(Icons.percent, size: 13, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 2),
                    Text('${deal.probabilite.round()} %', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    const SizedBox(width: 10),
                    if (cloture != null) ...[
                      Icon(Icons.flag_outlined, size: 13, color: enRetard ? Colors.red : scheme.onSurfaceVariant),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          relativeDay(cloture),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: enRetard ? Colors.red : scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Analyse extends StatelessWidget {
  final CrmProvider crm;
  const _Analyse({required this.crm});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: crm.chargerPipelineCommercial,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          CrmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Affaires par étape', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                if (crm.pipelineStages.isEmpty)
                  const Text('Aucune donnée pour le moment')
                else
                  PipelineFunnelChart(stages: crm.pipelineStages),
              ],
            ),
          ),
          if (crm.leadSources.isNotEmpty)
            CrmCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Origine des prospects', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  LeadSourcesChart(sources: crm.leadSources),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
