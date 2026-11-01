import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/tache_crm.dart';
import '../../providers/crm_provider.dart';
import '../../services/api_service.dart';
import '../../utils/crm_labels.dart';
import '../../utils/csv_export.dart';
import '../../widgets/crm/kanban_board.dart';
import '../../widgets/crm/tache_card.dart';
import '../../widgets/empty_state.dart';
import 'crm_common.dart';
import 'tache_dialog.dart';

enum RelancesView { tableau, liste }

enum RelancesGroupement { echeance, progression }

class RelancesTab extends StatefulWidget {
  const RelancesTab({super.key});

  @override
  State<RelancesTab> createState() => _RelancesTabState();
}

class _RelancesTabState extends State<RelancesTab> {
  RelancesView _view = RelancesView.tableau;
  RelancesGroupement _groupement = RelancesGroupement.echeance;
  bool _mesTaches = false;
  bool _showHistorique = false;

  List<TacheCRM> _filtrer(List<TacheCRM> taches, String me) {
    if (!_mesTaches) return taches;
    final moi = me.trim().toLowerCase();
    return taches.where((t) => t.assigneA.trim().toLowerCase() == moi).toList();
  }

  Future<void> _moveTache(TacheCRM t, String columnId) async {
    final crm = context.read<CrmProvider>();
    if (_groupement == RelancesGroupement.progression) {
      if (columnId == 'terminee') {
        await toggleTacheWithUndo(context, t);
      } else {
        await crm.changerStatutTache(t, columnId);
      }
      return;
    }
    final bucket = DueBucket.values.firstWhere((b) => b.name == columnId);
    final date = dueDateForBucket(bucket);
    if (date == null) return;
    final ok = await crm.changerEcheanceTache(t, date);
    if (mounted) showCrmSnack(context, ok ? 'Échéance : ${relativeDay(date).toLowerCase()}' : 'Mise à jour impossible');
  }

  Future<void> _effacerHistorique() async {
    final crm = context.read<CrmProvider>();
    final ok = await confirmAction(
      context,
      title: "Effacer l'historique",
      message: 'Supprimer définitivement toutes les tâches terminées ou annulées ?',
      confirmLabel: 'Effacer',
      destructive: true,
    );
    if (!ok) return;
    final done = await crm.effacerHistoriqueTaches();
    if (mounted) showCrmSnack(context, done ? 'Historique effacé' : "Impossible d'effacer l'historique");
  }

  Widget _card(TacheCRM t) => TacheCard(
        tache: t,
        onToggleDone: t.id == null ? null : () => toggleTacheWithUndo(context, t),
        onTap: t.id == null ? null : () => showTacheDialog(context, tache: t),
        onDelete: t.id == null ? null : () => deleteTacheWithConfirm(context, t),
      );

  @override
  Widget build(BuildContext context) {
    final crm = context.watch<CrmProvider>();
    final me = currentUserName(context);
    final taches = _filtrer(crm.taches, me);
    final actives = taches.where((t) => isTacheOuverte(t.statut)).toList()
      ..sort((a, b) => a.dateEcheance.compareTo(b.dateEcheance));
    final historique = taches.where((t) => !isTacheOuverte(t.statut)).toList()
      ..sort((a, b) => b.dateEcheance.compareTo(a.dateEcheance));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 4),
          child: Row(
            children: [
              SegmentedButton<RelancesView>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: RelancesView.tableau, icon: Icon(Icons.view_kanban_outlined), tooltip: 'Tableau'),
                  ButtonSegment(value: RelancesView.liste, icon: Icon(Icons.view_list_outlined), tooltip: 'Liste'),
                ],
                selected: {_view},
                onSelectionChanged: (v) => setState(() => _view = v.first),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        avatar: const Icon(Icons.person_pin_outlined, size: 16),
                        label: const Text('Mes tâches'),
                        selected: _mesTaches,
                        onSelected: (v) => setState(() => _mesTaches = v),
                      ),
                      if (_view == RelancesView.tableau) ...[
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('Par échéance'),
                          selected: _groupement == RelancesGroupement.echeance,
                          onSelected: (_) => setState(() => _groupement = RelancesGroupement.echeance),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('Par progression'),
                          selected: _groupement == RelancesGroupement.progression,
                          onSelected: (_) => setState(() => _groupement = RelancesGroupement.progression),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Plus d’actions',
                onSelected: (v) {
                  if (v == 'export') {
                    exportCsvToClipboard(context, loader: ApiService.exportHistoriqueTachesCrmCsv, label: 'Historique relances CRM');
                  } else if (v == 'clear') {
                    _effacerHistorique();
                  } else if (v == 'refresh') {
                    context.read<CrmProvider>().chargerTachesCrm();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'refresh', child: Text('Actualiser')),
                  PopupMenuItem(value: 'export', enabled: historique.isNotEmpty, child: const Text("Exporter l'historique (CSV)")),
                  PopupMenuItem(value: 'clear', enabled: historique.isNotEmpty, child: const Text("Effacer l'historique")),
                ],
              ),
              IconButton.filled(
                tooltip: 'Nouvelle tâche',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_task, size: 18),
                onPressed: () => showTacheDialog(context),
              ),
            ],
          ),
        ),
        if (crm.tachesLoading && crm.taches.isEmpty) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: _view == RelancesView.tableau ? _board(actives, historique) : _liste(actives, historique),
        ),
      ],
    );
  }

  Widget _board(List<TacheCRM> actives, List<TacheCRM> historique) {
    final List<KanbanColumn<TacheCRM>> columns;
    if (_groupement == RelancesGroupement.progression) {
      columns = [
        for (final s in ['a_faire', 'en_cours'])
          KanbanColumn<TacheCRM>(
            id: s,
            title: tacheStatut(s).label,
            icon: tacheStatut(s).icon,
            color: tacheStatut(s).color,
            items: actives.where((t) => t.statut == s).toList(),
          ),
        KanbanColumn<TacheCRM>(
          id: 'terminee',
          title: 'Terminées',
          icon: Icons.check_circle,
          color: Colors.green,
          items: historique.where((t) => t.statut == 'terminee').take(30).toList(),
        ),
      ];
    } else {
      columns = [
        for (final b in DueBucket.values)
          KanbanColumn<TacheCRM>(
            id: b.name,
            title: dueBucketLabels[b]!,
            color: dueBucketColors[b]!,
            icon: b == DueBucket.enRetard ? Icons.warning_amber_rounded : Icons.event_outlined,
            acceptsDrops: b != DueBucket.enRetard,
            items: actives.where((t) => dueBucketFor(t.dateEcheance) == b).toList(),
          ),
      ];
    }
    if (columns.every((c) => c.items.isEmpty) && historique.isEmpty) return _empty();
    return KanbanBoard<TacheCRM>(
      columns: columns,
      columnWidth: 280,
      itemKey: (t) => t.id ?? t.titre,
      onMove: _moveTache,
      emptyLabel: 'Glissez une tâche ici',
      itemBuilder: (context, t) => _card(t),
    );
  }

  Widget _liste(List<TacheCRM> actives, List<TacheCRM> historique) {
    if (actives.isEmpty && historique.isEmpty) return _empty();
    return RefreshIndicator(
      onRefresh: () => context.read<CrmProvider>().chargerTachesCrm(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        children: [
          for (final b in DueBucket.values) ...() {
            final items = actives.where((t) => dueBucketFor(t.dateEcheance) == b).toList();
            if (items.isEmpty) return const <Widget>[];
            return [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                child: Row(
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: dueBucketColors[b], shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text('${dueBucketLabels[b]} (${items.length})', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              ...items.map(_card),
            ];
          }(),
          if (historique.isNotEmpty)
            ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 4),
              initiallyExpanded: _showHistorique,
              onExpansionChanged: (v) => setState(() => _showHistorique = v),
              leading: const Icon(Icons.check_circle_outline, color: Colors.green),
              title: Text('Terminées (${historique.length})'),
              children: historique.map(_card).toList(),
            ),
        ],
      ),
    );
  }

  Widget _empty() => EmptyState(
        icon: Icons.task_alt,
        title: _mesTaches ? 'Aucune tâche ne vous est assignée' : 'Aucune relance pour le moment',
        subtitle: 'Planifiez vos appels, visites et relances commerciales avec le bouton « + » en haut.',
      );
}
