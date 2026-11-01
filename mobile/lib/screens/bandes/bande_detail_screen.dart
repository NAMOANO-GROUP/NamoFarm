import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/alerte.dart';
import '../../models/bande.dart';
import '../../providers/alertes_provider.dart';
import '../../providers/bandes_provider.dart';
import '../../services/api_service.dart';
import '../../services/references_service.dart';
import '../../utils/bande_kpis.dart';
import '../../utils/crm_labels.dart';
import '../../utils/money_format.dart';
import '../../utils/todo.dart';
import '../../widgets/bandes/bande_widgets.dart';
import '../../widgets/crm/contact_widgets.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/todo/todo_card.dart';
import '../bande_bilan_screen.dart';
import '../bande_dashboard_screen.dart';
import '../crm/crm_common.dart';
import '../suivi_screen.dart';
import '../todo/todo_dialog.dart';
import '../todo/todo_modeles_sheet.dart';
import 'bande_actions.dart';

/// Onglets de la fiche bande.
enum BandeOnglet { apercu, courbes, journal, sante, taches, finances }

const _ongletLabels = {
  BandeOnglet.apercu: ('Aperçu', Icons.dashboard_outlined),
  BandeOnglet.courbes: ('Courbes', Icons.show_chart),
  BandeOnglet.journal: ('Journal', Icons.timeline),
  BandeOnglet.sante: ('Santé', Icons.vaccines_outlined),
  BandeOnglet.taches: ('Tâches', Icons.task_alt),
  BandeOnglet.finances: ('Finances', Icons.payments_outlined),
};

/// Fiche unique d'une bande : indicateurs en tête, puis onglets (suivi, courbes, journal, santé, tâches, finances).
class BandeDetailScreen extends StatefulWidget {
  final Bande bande;
  final BandeOnglet ongletInitial;

  const BandeDetailScreen({super.key, required this.bande, this.ongletInitial = BandeOnglet.apercu});

  @override
  State<BandeDetailScreen> createState() => _BandeDetailScreenState();
}

class _BandeDetailScreenState extends State<BandeDetailScreen> {
  Map<String, ReferenceType> _refs = Map.of(defaultReferences);

  @override
  void initState() {
    super.initState();
    ReferencesService.charger().then((r) {
      if (mounted) setState(() => _refs = r);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final alertes = context.read<AlertesProvider>();
      if (alertes.alertes.isEmpty) alertes.chargerAlertes(period: 'all');
      if (alertes.historiqueAlertes.isEmpty) alertes.chargerHistoriqueAlertes();
    });
  }

  /// Version la plus récente de la bande (rechargée après chaque saisie).
  Bande _bande(BandesProvider p) {
    for (final b in [...p.bandesActives, ...p.bandesHistorique]) {
      if (b.id == widget.bande.id) return b;
    }
    return widget.bande;
  }

  @override
  Widget build(BuildContext context) {
    final bande = _bande(context.watch<BandesProvider>());
    final ref = referencePour(_refs, bande.typeVolaille);
    final kpis = computeBandeKpis(bande, ref);
    final active = bande.dateFermeture == null;

    return DefaultTabController(
      length: BandeOnglet.values.length,
      initialIndex: widget.ongletInitial.index,
      child: Scaffold(
        appBar: AppBar(
          title: Text(bande.nom, overflow: TextOverflow.ellipsis),
          actions: [
            if (active)
              PopupMenuButton<SaisieBande>(
                tooltip: 'Nouvelle saisie',
                icon: const Icon(Icons.edit_note),
                onSelected: (s) => ouvrirSaisie(context, bande, s),
                itemBuilder: (_) => [
                  for (final s in SaisieBande.values)
                    PopupMenuItem(
                      value: s,
                      child: Row(children: [
                        Icon(saisieIcons[s], color: saisieColors[s], size: 20),
                        const SizedBox(width: 10),
                        Text(saisieLabels[s]!),
                      ]),
                    ),
                ],
              ),
            PopupMenuButton<String>(
              tooltip: 'Plus d’actions',
              onSelected: (v) async {
                final provider = context.read<BandesProvider>();
                if (v == 'refresh') {
                  await Future.wait([provider.chargerBandesActives(), provider.chargerHistorique()]);
                } else if (v == 'fermer') {
                  final closed = await fermerBandeAvecBilan(context, bande, ref);
                  if (closed && context.mounted) setState(() {});
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'refresh', child: Text('Actualiser')),
                if (active) const PopupMenuItem(value: 'fermer', child: Text('Fermer la bande')),
              ],
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              for (final o in BandeOnglet.values) Tab(icon: Icon(_ongletLabels[o]!.$2), text: _ongletLabels[o]!.$1),
            ],
          ),
        ),
        body: Column(
          children: [
            _Header(bande: bande, kpis: kpis),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                children: [
                  SuiviScreen(key: ValueKey('apercu-${bande.id}'), bande: bande, embedded: true, lectureSeule: !active),
                  BandeDashboardScreen(key: ValueKey('courbes-${bande.id}'), bande: bande, embedded: true),
                  _JournalView(bande: bande),
                  _SanteView(bande: bande),
                  _TachesView(bande: bande),
                  _FinancesView(bandeId: bande.id ?? ''),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Bande bande;
  final BandeKpis kpis;
  const _Header({required this.bande, required this.kpis});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final tiles = bandeKpiTiles(kpis, width: wide ? 150 : 128);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              typeVolailleLabel(bande.typeVolaille),
              if (bande.race.isNotEmpty) bande.race,
              if (bande.batiment.isNotEmpty) bande.batiment,
              'ouverte le ${formatDateFr(bande.dateOuverture)}',
            ].join(' • '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          CycleProgress(bande: bande, kpis: kpis),
          if (kpis.alertes.isNotEmpty) ...[
            const SizedBox(height: 8),
            BandeAlertesPills(alertes: kpis.alertes),
          ],
          const SizedBox(height: 10),
          if (wide)
            Wrap(spacing: 8, runSpacing: 8, children: tiles)
          else
            SizedBox(
              height: 78,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: tiles.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => tiles[i],
              ),
            ),
        ],
      ),
    );
  }
}

/// Journal : saisies quotidiennes et événements de santé, groupés par jour.
class _JournalView extends StatelessWidget {
  final Bande bande;
  const _JournalView({required this.bande});

  static String _n(num v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final entries = <TimelineEntry>[
      for (final s in bande.suiviJournalier)
        () {
          final parts = [
            if (s.alimentationKg > 0) 'Aliment ${_n(s.alimentationKg)} kg${s.alimentationType.isNotEmpty ? ' (${s.alimentationType})' : ''}',
            if (s.eauLitres > 0) 'Eau ${_n(s.eauLitres)} L',
            if (s.poidsMotenG > 0) 'Poids moyen ${_n(s.poidsMotenG)} g',
            if (s.temperature != 0 || s.humidite != 0) 'Climat ${_n(s.temperature)} °C / ${_n(s.humidite)} %',
          ];
          final mort = s.mortaliteJour > 0;
          final (icon, color) = mort
              ? (Icons.health_and_safety_outlined, Colors.red)
              : (s.poidsMotenG > 0
                  ? (Icons.monitor_weight_outlined, Colors.blue)
                  : (s.alimentationKg > 0 ? (Icons.restaurant_outlined, Colors.brown) : (Icons.thermostat_outlined, Colors.teal)));
          return TimelineEntry(
            date: s.date,
            kind: 'suivi',
            icon: icon,
            color: color,
            title: mort ? 'Mortalité : ${s.mortaliteJour} sujet(s)' : 'Saisie J${_age(s.date)}',
            body: [parts.join(' · '), if (s.observations.isNotEmpty) s.observations].where((t) => t.isNotEmpty).join('\n'),
          );
        }(),
      for (final e in bande.evenementsSante)
        TimelineEntry(
          date: e.date,
          kind: 'sante',
          icon: Icons.vaccines_outlined,
          color: Colors.purple,
          title: '${e.type[0].toUpperCase()}${e.type.substring(1)} · ${e.description}',
          body: [if (e.medicament.isNotEmpty) e.medicament, if (e.cout > 0) formatAmountFcfa(e.cout)].join(' · '),
        ),
    ];
    if (entries.isEmpty) {
      return const EmptyState(
        icon: Icons.timeline,
        title: 'Aucune saisie',
        subtitle: 'Les pesées, l’alimentation, la mortalité et le climat apparaîtront ici, jour par jour.',
      );
    }
    return ListView(padding: const EdgeInsets.all(12), children: buildActivityTimeline(context, entries));
  }

  int _age(DateTime d) => DateTime(d.year, d.month, d.day).difference(DateTime(bande.dateOuverture.year, bande.dateOuverture.month, bande.dateOuverture.day)).inDays;
}

/// Santé : traitements et vaccinations de la bande, avec leur coût.
class _SanteView extends StatelessWidget {
  final Bande bande;
  const _SanteView({required this.bande});

  @override
  Widget build(BuildContext context) {
    final events = [...bande.evenementsSante]..sort((a, b) => b.date.compareTo(a.date));
    if (events.isEmpty) {
      return const EmptyState(
        icon: Icons.vaccines_outlined,
        title: 'Aucun événement de santé',
        subtitle: 'Les vaccinations et traitements enregistrés pour cette bande apparaîtront ici.',
      );
    }
    final total = events.fold<double>(0, (s, e) => s + e.cout);
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('${events.length} événement(s) · coût total ${formatAmountFcfa(total)}',
            style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        for (final e in events)
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.purple.withValues(alpha: 0.12),
                child: Icon(e.type == 'vaccination' ? Icons.vaccines : Icons.medication_outlined, color: Colors.purple),
              ),
              title: Text(e.description.isEmpty ? e.type : e.description, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text([
                formatDateFr(e.date),
                if (e.medicament.isNotEmpty) e.medicament,
                if (e.doseParTete.isNotEmpty) '${e.doseParTete} / tête',
                if (e.dureeJours > 1) '${e.dureeJours} jours',
              ].join(' · ')),
              trailing: e.cout > 0 ? Text(formatCompactFcfa(e.cout), style: const TextStyle(fontWeight: FontWeight.w700)) : null,
            ),
          ),
      ],
    );
  }
}

/// Tâches Todo liées à la bande (création, modèles de plan, terminer avec annulation).
class _TachesView extends StatelessWidget {
  final Bande bande;
  const _TachesView({required this.bande});

  Future<void> _toggle(BuildContext context, Alerte a) async {
    final provider = context.read<AlertesProvider>();
    if (a.estFaite) {
      await provider.rouvrir(a);
      return;
    }
    final res = await provider.terminer(a);
    if (!context.mounted) return;
    showCrmSnack(
      context,
      res.ok ? 'Tâche terminée 🎉' : 'Mise à jour impossible',
      action: res.ok ? SnackBarAction(label: 'Annuler', onPressed: () => provider.rouvrir(a, prochaineId: res.prochaineId)) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlertesProvider>();
    final ouvertes = provider.alertes.where((a) => a.bandeId == bande.id).toList()
      ..sort((a, b) => a.dateEcheance.compareTo(b.dateEcheance));
    final faites = provider.historiqueAlertes.where((a) => a.bandeId == bande.id).toList()
      ..sort((a, b) => b.dateEcheance.compareTo(a.dateEcheance));
    final active = bande.dateFermeture == null;

    Widget card(Alerte a) => TodoCard(
          alerte: a,
          compact: true,
          onToggleDone: a.modifiable ? () => _toggle(context, a) : null,
          onTap: a.modifiable ? () => showTodoDialog(context, alerte: a) : null,
        );

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('${ouvertes.length} tâche(s) à faire', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            PopupMenuButton<TodoModele>(
              tooltip: 'Appliquer un modèle de plan',
              icon: const Icon(Icons.library_add_check_outlined),
              onSelected: (m) => showAppliquerModeleDialog(
                context,
                m,
                bandeId: bande.id,
                bandeNom: bande.nom,
                depart: m.id == 'bande_chair' ? bande.dateOuverture : DateTime.now(),
              ),
              itemBuilder: (_) => [for (final m in todoModeles) PopupMenuItem(value: m, child: Text(m.titre))],
            ),
            IconButton.filled(
              tooltip: 'Nouvelle tâche',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.add_task, size: 18),
              onPressed: () => showTodoDialog(context, bandeId: bande.id),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (ouvertes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              active ? 'Aucune tâche planifiée pour cette bande.' : 'Aucune tâche ouverte.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          )
        else
          ...ouvertes.map(card),
        if (faites.isNotEmpty)
          ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: const Icon(Icons.check_circle_outline, color: Colors.green),
            title: Text('Terminées (${faites.length})'),
            children: faites.map(card).toList(),
          ),
      ],
    );
  }
}

/// Finances : réutilise le bilan analytique de la bande (coûts, ventes, marge), chargé à l'ouverture de l'onglet.
class _FinancesView extends StatefulWidget {
  final String bandeId;
  const _FinancesView({required this.bandeId});

  @override
  State<_FinancesView> createState() => _FinancesViewState();
}

class _FinancesViewState extends State<_FinancesView> {
  late final Future<Map<String, dynamic>?> _future = _charger();

  Future<Map<String, dynamic>?> _charger() async {
    final data = await ApiService.getComptabiliteAnalytique();
    for (final b in (data['bandes'] as List? ?? const []).whereType<Map>()) {
      if (b['bandeId']?.toString() == widget.bandeId) return Map<String, dynamic>.from(b);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) {
          return const EmptyState(
            icon: Icons.lock_outline,
            title: 'Finances indisponibles',
            subtitle: 'Vos droits ne permettent pas de consulter les finances, ou la connexion a échoué.',
          );
        }
        final data = snap.data;
        if (data == null) {
          return const EmptyState(
            icon: Icons.payments_outlined,
            title: 'Aucune donnée financière',
            subtitle: 'Les dépenses et ventes rattachées à cette bande apparaîtront ici.',
          );
        }
        return BandeBilanScreen(bande: data, embedded: true);
      },
    );
  }
}
