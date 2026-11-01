import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/alerte.dart';
import '../models/bande.dart';
import '../providers/alertes_provider.dart';
import '../providers/crm_provider.dart';
import '../services/api_service.dart';
import '../utils/crm_labels.dart';
import '../utils/csv_export.dart';
import '../utils/todo.dart';
import '../widgets/brand_logo.dart';
import '../widgets/crm/kanban_board.dart';
import '../widgets/empty_state.dart';
import '../widgets/todo/todo_card.dart';
import '../widgets/week_calendar_view.dart';
import 'bande_dashboard_screen.dart';
import 'commandes_screen.dart';
import 'crm/crm_common.dart';
import 'crm/tache_dialog.dart';
import 'stocks_screen.dart';
import 'todo/todo_charts.dart';
import 'todo/todo_dialog.dart';
import 'todo/todo_modeles_sheet.dart';

enum _Vue { liste, tableau, planning, graphiques }

enum _Groupe { echeance, avancement, categorie, bande }

const _groupeLabels = {
  _Groupe.echeance: 'Par échéance',
  _Groupe.avancement: 'Par avancement',
  _Groupe.categorie: 'Par catégorie',
  _Groupe.bande: 'Par bande',
};

/// Catégories toujours proposées comme colonnes du tableau « par catégorie ».
const _categoriesTableau = ['vaccination', 'medicament', 'alimentation', 'pesee', 'stock_bas', 'vente', 'autre'];

/// Todo façon Microsoft Planner : vues Liste / Tableau / Planning / Graphiques,
/// ajout rapide, filtres, gestes de glissement, modèles de plan.
class AlertesScreen extends StatefulWidget {
  const AlertesScreen({super.key});

  @override
  State<AlertesScreen> createState() => _AlertesScreenState();
}

class _AlertesScreenState extends State<AlertesScreen> {
  _Vue _vue = _Vue.liste;
  _Groupe _groupe = _Groupe.echeance;
  /// Échéances cochées dans le menu Filtres (vide = toutes).
  final Set<DueBucket> _echeances = {};
  bool _mesTaches = false;
  bool _showTerminees = false;
  List<Bande> _bandes = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AlertesProvider>();
      provider.chargerAlertes(period: 'all');
      provider.chargerAlertesAutomatiques();
      provider.chargerHistoriqueAlertes();
      provider.chargerHistoriqueAlertesAutomatiques();
      chargerBandesOuvertes().then((b) {
        if (mounted) setState(() => _bandes = b);
      });
    });
  }

  // ---------- Actions ----------

  Future<void> _terminer(Alerte a) async {
    final provider = context.read<AlertesProvider>();
    if (!a.modifiable) {
      final ok = await provider.marquerFaite(a);
      if (mounted) showCrmSnack(context, ok ? 'Alerte traitée' : 'Mise à jour impossible');
      return;
    }
    final res = await provider.terminer(a);
    if (!mounted) return;
    final recurrente = a.recurrence != 'aucune' && a.recurrence.isNotEmpty;
    showCrmSnack(
      context,
      !res.ok ? 'Mise à jour impossible' : (recurrente ? 'Tâche terminée · prochaine occurrence planifiée' : 'Tâche terminée 🎉'),
      action: res.ok
          ? SnackBarAction(
              label: 'Annuler',
              onPressed: () async {
                final undone = await provider.rouvrir(a, prochaineId: res.prochaineId);
                if (!undone && mounted) showCrmSnack(context, "Impossible d'annuler, la tâche reste terminée");
              },
            )
          : null,
    );
  }

  Future<void> _rouvrir(Alerte a) async {
    if (!a.modifiable) return;
    final ok = await context.read<AlertesProvider>().rouvrir(a);
    if (mounted) showCrmSnack(context, ok ? 'Tâche rouverte' : 'Mise à jour impossible');
  }

  Future<void> _reporter(Alerte a) async {
    final provider = context.read<AlertesProvider>();
    final ok = await provider.reporterADemain(a);
    if (!mounted) return;
    final deplacee = a.copyWith(
      dateEcheance: a.dateEcheance.add(const Duration(days: 1)),
      dateFin: a.dateFin?.add(const Duration(days: 1)),
    );
    showCrmSnack(
      context,
      ok ? 'Reportée à ${relativeDay(deplacee.dateEcheance).toLowerCase()}' : 'Report impossible',
      action: ok ? SnackBarAction(label: 'Annuler', onPressed: () => provider.changerEcheance(deplacee, a.dateEcheance)) : null,
    );
  }

  bool _hasSource(Alerte a) =>
      a.automatique && const ['crm_tache', 'stock', 'commercial', 'sanitaire', 'planification'].contains(a.source);

  Future<void> _ouvrirSource(Alerte a) async {
    final navigator = Navigator.of(context);
    switch (a.source) {
      case 'crm_tache':
        final crm = context.read<CrmProvider>();
        if (crm.taches.isEmpty) await crm.chargerTachesCrm();
        final tache = crm.taches.where((t) => t.id == a.crmTacheId).firstOrNull;
        if (!mounted) return;
        if (tache == null) {
          showCrmSnack(context, 'Relance CRM introuvable');
        } else {
          await showTacheDialog(context, tache: tache);
          if (mounted) context.read<AlertesProvider>().chargerAlertesAutomatiques();
        }
      case 'stock':
        navigator.push(MaterialPageRoute(builder: (_) => const StocksScreen()));
      case 'commercial':
        navigator.push(MaterialPageRoute(builder: (_) => const CommandesScreen()));
      default:
        final bande = _bandes.where((b) => b.id == a.bandeId).firstOrNull;
        if (bande == null) {
          showCrmSnack(context, 'Bande introuvable');
        } else {
          navigator.push(MaterialPageRoute(builder: (_) => BandeDashboardScreen(bande: bande)));
        }
    }
  }

  void _ouvrir(Alerte a) {
    if (!a.modifiable && _hasSource(a)) {
      _ouvrirSource(a);
    } else {
      showTodoDialog(context, alerte: a);
    }
  }

  Future<void> _effacerHistorique() async {
    final provider = context.read<AlertesProvider>();
    final ok = await confirmAction(
      context,
      title: "Effacer l'historique",
      message: 'Supprimer définitivement toutes les tâches terminées ?',
      confirmLabel: 'Effacer',
      destructive: true,
    );
    if (!ok) return;
    final done = await provider.effacerHistorique();
    if (mounted) showCrmSnack(context, done ? 'Historique effacé' : "Impossible d'effacer l'historique");
  }

  void _autoNonModifiable() =>
      showCrmSnack(context, 'Tâche automatique : ouvrez-la ou convertissez-la en tâche pour la déplacer.');

  // ---------- Construction ----------

  Widget _card(Alerte a, {bool compact = false}) => TodoCard(
        alerte: a,
        compact: compact,
        onToggleDone: a.estFaite ? () => _rouvrir(a) : () => _terminer(a),
        onTap: () => _ouvrir(a),
        onOpenSource: _hasSource(a) ? () => _ouvrirSource(a) : null,
      );

  /// Glisser à droite : terminer ; glisser à gauche : reporter à demain.
  Widget _swipe(Alerte a) {
    return Dismissible(
      key: ValueKey('todo-${a.id ?? a.titre}-${a.dateEcheance.toIso8601String()}'),
      direction: a.modifiable ? DismissDirection.horizontal : DismissDirection.startToEnd,
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          await _terminer(a);
        } else {
          await _reporter(a);
        }
        // La liste est mise à jour par le provider : on ne retire pas la carte nous-mêmes.
        return false;
      },
      background: _swipeBg(Colors.green, Icons.check, 'Terminer', Alignment.centerLeft),
      secondaryBackground: _swipeBg(Colors.blue, Icons.next_plan_outlined, 'Demain', Alignment.centerRight),
      child: _card(a),
    );
  }

  Widget _swipeBg(Color color, IconData icon, String label, Alignment align) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(12)),
        alignment: align,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BrandLogo(),
        title: const Text('Todo list'),
        actions: [
          IconButton(
            tooltip: 'Modèles de plan',
            icon: const Icon(Icons.library_add_check_outlined),
            onPressed: () => showTodoModelesSheet(context),
          ),
          Consumer<AlertesProvider>(
            builder: (context, provider, _) {
              final hasHistorique = provider.historiqueAlertes.isNotEmpty || provider.historiqueAlertesAutomatiques.isNotEmpty;
              return PopupMenuButton<String>(
                tooltip: 'Plus d’actions',
                onSelected: (v) {
                  switch (v) {
                    case 'refresh':
                      provider.chargerTout();
                    case 'export':
                      exportCsvToClipboard(context, loader: ApiService.exportHistoriqueAlertesCsv, label: 'Historique alertes');
                    case 'clear':
                      _effacerHistorique();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'refresh', child: Text('Actualiser')),
                  PopupMenuItem(value: 'export', enabled: hasHistorique, child: const Text("Exporter l'historique (CSV)")),
                  PopupMenuItem(value: 'clear', enabled: hasHistorique, child: const Text("Effacer l'historique")),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<AlertesProvider>(
        builder: (context, provider, _) {
          final me = currentUserName(context);
          final ouvertes = [...provider.alertes, ...provider.alertesAutomatiques];
          final terminees = [...provider.historiqueAlertes, ...provider.historiqueAlertesAutomatiques]
            ..sort((a, b) => b.dateEcheance.compareTo(a.dateEcheance));
          final visibles = filtrerTodo(ouvertes, echeances: _echeances, mesTaches: _mesTaches, me: me);
          final loading = provider.isLoading && ouvertes.isEmpty && terminees.isEmpty;

          return Column(
            children: [
              _toolbar(ouvertes, me),
              if (loading) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: switch (_vue) {
                  _Vue.liste => _liste(visibles, terminees, ouvertes.isEmpty && terminees.isEmpty),
                  _Vue.tableau => _tableau(visibles, terminees),
                  _Vue.planning => WeekCalendarView(
                      alertes: ouvertes,
                      onTap: _ouvrir,
                      onMove: (a, newStart) async {
                        if (!a.modifiable) return _autoNonModifiable();
                        await provider.changerEcheance(a, newStart);
                      },
                    ),
                  _Vue.graphiques => TodoChartsView(ouvertes: ouvertes, terminees: terminees),
                },
              ),
            ],
          );
        },
      ),
    );
  }

  /// Ligne unique : vues, menu Filtres (liste et tableau) et bouton d'ajout.
  Widget _toolbar(List<Alerte> ouvertes, String me) {
    final filtrable = _vue == _Vue.liste || _vue == _Vue.tableau;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          SegmentedButton<_Vue>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: _Vue.liste, icon: Icon(Icons.view_list_outlined), tooltip: 'Liste'),
              ButtonSegment(value: _Vue.tableau, icon: Icon(Icons.view_kanban_outlined), tooltip: 'Tableau'),
              ButtonSegment(value: _Vue.planning, icon: Icon(Icons.calendar_view_week_outlined), tooltip: 'Planning'),
              ButtonSegment(value: _Vue.graphiques, icon: Icon(Icons.insights_outlined), tooltip: 'Graphiques'),
            ],
            selected: {_vue},
            onSelectionChanged: (v) => setState(() => _vue = v.first),
          ),
          const Spacer(),
          if (filtrable) ...[
            _filtreMenu(ouvertes, me),
            const SizedBox(width: 8),
          ],
          IconButton.filled(
            tooltip: 'Nouvelle tâche',
            onPressed: () => showTodoDialog(context),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_task, size: 18),
          ),
        ],
      ),
    );
  }

  int get _nbFiltres => _echeances.length + (_mesTaches ? 1 : 0);

  /// Menu déroulant à choix multiples : échéances (cumulables), Mes tâches, et colonnes du tableau.
  Widget _filtreMenu(List<Alerte> ouvertes, String me) {
    int count(DueBucket b) => filtrerTodo(ouvertes, echeances: {b}, mesTaches: _mesTaches, me: me).length;
    final actifs = _nbFiltres;
    return MenuAnchor(
      alignmentOffset: const Offset(0, 4),
      menuChildren: [
        const _MenuTitre('Échéance'),
        for (final b in DueBucket.values)
          CheckboxMenuButton(
            closeOnActivate: false,
            value: _echeances.contains(b),
            onChanged: (v) => setState(() => v == true ? _echeances.add(b) : _echeances.remove(b)),
            child: Text('${dueBucketLabels[b]} (${count(b)})'),
          ),
        const Divider(height: 8),
        CheckboxMenuButton(
          closeOnActivate: false,
          value: _mesTaches,
          onChanged: (v) => setState(() => _mesTaches = v == true),
          child: const Text('Mes tâches'),
        ),
        if (_vue == _Vue.tableau) ...[
          const Divider(height: 8),
          const _MenuTitre('Colonnes du tableau'),
          for (final g in _Groupe.values)
            RadioMenuButton<_Groupe>(
              closeOnActivate: false,
              value: g,
              groupValue: _groupe,
              onChanged: (v) => setState(() => _groupe = v ?? _groupe),
              child: Text(_groupeLabels[g]!),
            ),
        ],
        if (actifs > 0) ...[
          const Divider(height: 8),
          MenuItemButton(
            leadingIcon: const Icon(Icons.filter_alt_off_outlined, size: 18),
            onPressed: () => setState(() {
              _echeances.clear();
              _mesTaches = false;
            }),
            child: const Text('Réinitialiser les filtres'),
          ),
        ],
      ],
      builder: (context, controller, _) {
        void toggle() => controller.isOpen ? controller.close() : controller.open();
        final icon = Badge(
          isLabelVisible: actifs > 0,
          label: Text('$actifs'),
          child: const Icon(Icons.filter_list, size: 20),
        );
        // Petit écran : icône seule pour garder vues, filtres et ajout sur une ligne.
        if (MediaQuery.sizeOf(context).width < 600) {
          return IconButton.outlined(tooltip: 'Filtres', visualDensity: VisualDensity.compact, onPressed: toggle, icon: icon);
        }
        return OutlinedButton.icon(
          onPressed: toggle,
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          icon: icon,
          label: const Text('Filtres'),
        );
      },
    );
  }

  // ---------- Vue Liste ----------

  Widget _liste(List<Alerte> visibles, List<Alerte> terminees, bool vide) {
    if (vide) {
      return EmptyState(
        icon: Icons.task_alt,
        title: 'Aucune tâche',
        subtitle: 'Ajoutez une tâche avec le bouton ✓+ ou partez d’un modèle de plan.',
        actionLabel: 'Modèles de plan',
        actionIcon: Icons.library_add_check_outlined,
        onAction: () => showTodoModelesSheet(context),
      );
    }
    return RefreshIndicator(
      onRefresh: () => context.read<AlertesProvider>().chargerTout(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        children: [
          if (visibles.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Rien à faire pour ce filtre 🎉', style: TextStyle(color: Colors.grey))),
            ),
          for (final b in DueBucket.values) ...() {
            final items = visibles.where((a) => dueBucketFor(a.dateEcheance) == b).toList();
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
              ...items.map(_swipe),
            ];
          }(),
          if (terminees.isNotEmpty)
            ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 4),
              initiallyExpanded: _showTerminees,
              onExpansionChanged: (v) => setState(() => _showTerminees = v),
              leading: const Icon(Icons.check_circle_outline, color: Colors.green),
              title: Text('Terminées (${terminees.length})'),
              children: terminees.take(100).map((a) => _card(a, compact: true)).toList(),
            ),
        ],
      ),
    );
  }

  // ---------- Vue Tableau ----------

  Widget _tableau(List<Alerte> visibles, List<Alerte> terminees) {
    final List<KanbanColumn<Alerte>> columns;
    switch (_groupe) {
      case _Groupe.echeance:
        columns = [
          for (final b in DueBucket.values)
            KanbanColumn<Alerte>(
              id: b.name,
              title: dueBucketLabels[b]!,
              color: dueBucketColors[b]!,
              icon: b == DueBucket.enRetard ? Icons.warning_amber_rounded : Icons.event_outlined,
              acceptsDrops: b != DueBucket.enRetard,
              items: visibles.where((a) => dueBucketFor(a.dateEcheance) == b).toList(),
            ),
        ];
      case _Groupe.avancement:
        columns = [
          for (final p in todoProgressions.take(2))
            KanbanColumn<Alerte>(
              id: p.value,
              title: p.label,
              color: p.color,
              icon: p.icon,
              items: visibles.where((a) => (a.progression == 'en_cours') == (p.value == 'en_cours')).toList(),
            ),
          KanbanColumn<Alerte>(
            id: 'faite',
            title: 'Terminées',
            color: Colors.green,
            icon: Icons.check_circle,
            items: terminees.take(30).toList(),
          ),
        ];
      case _Groupe.categorie:
        final types = {..._categoriesTableau, ...visibles.map((a) => a.type)};
        columns = [
          for (final t in types)
            KanbanColumn<Alerte>(
              id: t,
              title: todoCategorie(t).label,
              color: todoCategorie(t).color,
              icon: todoCategorie(t).icon,
              items: visibles.where((a) => a.type == t).toList(),
            ),
        ];
      case _Groupe.bande:
        final noms = <String, String>{for (final b in _bandes) b.id!: b.nom};
        for (final a in visibles) {
          if (a.bandeId != null) noms.putIfAbsent(a.bandeId!, () => a.bandeNom.isEmpty ? 'Bande' : a.bandeNom);
        }
        columns = [
          KanbanColumn<Alerte>(
            id: '',
            title: 'Sans bande',
            color: Colors.blueGrey,
            icon: Icons.inbox_outlined,
            items: visibles.where((a) => a.bandeId == null).toList(),
          ),
          for (final e in noms.entries)
            KanbanColumn<Alerte>(
              id: e.key,
              title: e.value,
              color: avatarColor(e.value),
              icon: Icons.egg_outlined,
              items: visibles.where((a) => a.bandeId == e.key).toList(),
            ),
        ];
    }

    return KanbanBoard<Alerte>(
      columns: columns,
      columnWidth: 280,
      itemKey: (a) => a.id ?? '${a.titre}-${a.dateEcheance.toIso8601String()}',
      emptyLabel: 'Glissez une tâche ici',
      onMove: (a, columnId) => _deplacer(a, columnId, columns),
      itemBuilder: (context, a) => _card(a, compact: true),
    );
  }

  Future<void> _deplacer(Alerte a, String columnId, List<KanbanColumn<Alerte>> columns) async {
    final provider = context.read<AlertesProvider>();
    if (_groupe == _Groupe.avancement) {
      if (columnId == 'faite') return _terminer(a);
      if (a.estFaite) return _rouvrir(a);
      if (!a.modifiable) return _autoNonModifiable();
      await provider.changerProgression(a, columnId);
      return;
    }
    if (!a.modifiable) return _autoNonModifiable();
    switch (_groupe) {
      case _Groupe.echeance:
        final jour = dueDateForBucket(DueBucket.values.firstWhere((b) => b.name == columnId));
        if (jour == null) return;
        final debut = DateTime(jour.year, jour.month, jour.day, a.dateEcheance.hour, a.dateEcheance.minute);
        final ok = await provider.changerEcheance(a, debut);
        if (mounted) showCrmSnack(context, ok ? 'Échéance : ${relativeDay(debut).toLowerCase()}' : 'Mise à jour impossible');
      case _Groupe.categorie:
        await provider.changerType(a, columnId);
      case _Groupe.bande:
        final nom = columns.firstWhere((c) => c.id == columnId).title;
        await provider.changerBande(a, columnId.isEmpty ? null : columnId, columnId.isEmpty ? '' : nom);
      case _Groupe.avancement:
        break;
    }
  }
}

/// Intitulé de section dans un menu déroulant.
class _MenuTitre extends StatelessWidget {
  final String text;
  const _MenuTitre(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary),
        ),
      );
}
