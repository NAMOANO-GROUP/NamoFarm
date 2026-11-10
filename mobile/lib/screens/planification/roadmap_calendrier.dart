import 'package:flutter/material.dart';

import '../roadmap_screen.dart';

DateTime _jour(DateTime d) => DateTime(d.year, d.month, d.day);

/// Tâches « feuilles » en cours le [jour] (bornes incluses).
List<RoadmapTask> roadmapTachesDuJour(List<RoadmapTask> feuilles, DateTime jour) {
  final d = _jour(jour);
  return [
    for (final t in feuilles)
      if (!d.isBefore(_jour(t.start)) && !d.isAfter(_jour(t.end))) t,
  ];
}

/// Jalons posés le [jour], sur n'importe quelle tâche ou sous-tâche.
List<RoadmapMilestone> roadmapJalonsDuJour(List<RoadmapTask> taches, DateTime jour) {
  final d = _jour(jour);
  return [
    for (final t in taches) ...[
      for (final m in t.milestones)
        if (_jour(m.date) == d) m,
      ...roadmapJalonsDuJour(t.subTasks, jour),
    ],
  ];
}

/// Cases d'un mois, lundi en premier : null = hors mois (toujours 6 semaines, comme un calendrier papier).
List<DateTime?> roadmapCasesMois(int annee, int mois) {
  final premier = DateTime(annee, mois, 1);
  final nbJours = DateTime(annee, mois + 1, 0).day;
  final decalage = premier.weekday - 1;
  return [
    for (var i = 0; i < 42; i++) i >= decalage && i < decalage + nbJours ? DateTime(annee, mois, i - decalage + 1) : null,
  ];
}

const _moisLongs = ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];
const _joursCourts = ['Lu', 'Ma', 'Me', 'Je', 'Ve', 'Sa', 'Di'];

/// Roadmap en calendrier annuel : un mois par grille, chaque jour coloré selon la tâche en cours.
class RoadmapCalendrier extends StatefulWidget {
  final ProductionPlan plan;

  /// Toucher une tâche dans le détail d'un jour.
  final ValueChanged<RoadmapTask> onTache;

  /// Créer une tâche à la date touchée.
  final ValueChanged<DateTime> onCreer;

  /// Année à afficher quand l'utilisateur demande « aujourd'hui » (incrémenter pour re-déclencher).
  final int signalAujourdhui;

  const RoadmapCalendrier({
    super.key,
    required this.plan,
    required this.onTache,
    required this.onCreer,
    this.signalAujourdhui = 0,
  });

  @override
  State<RoadmapCalendrier> createState() => _RoadmapCalendrierState();
}

class _RoadmapCalendrierState extends State<RoadmapCalendrier> {
  late int _annee = _anneeInitiale();

  int _anneeInitiale() {
    final n = DateTime.now().year;
    return n >= widget.plan.start.year && n <= widget.plan.end.year ? n : widget.plan.start.year;
  }

  @override
  void didUpdateWidget(covariant RoadmapCalendrier old) {
    super.didUpdateWidget(old);
    if (old.plan.id != widget.plan.id) {
      _annee = _anneeInitiale();
    } else if (_annee < widget.plan.start.year || _annee > widget.plan.end.year) {
      _annee = _anneeInitiale();
    }
    if (old.signalAujourdhui != widget.signalAujourdhui) _annee = _anneeInitiale();
  }

  List<RoadmapTask> get _feuilles => roadmapFeuilles(widget.plan.tasks);

  Set<DateTime> get _datesCles => {for (final d in widget.plan.highlightedDates) _jour(d)};

  Future<void> _detailJour(DateTime d) async {
    final taches = roadmapTachesDuJour(_feuilles, d);
    final jalons = roadmapJalonsDuJour(widget.plan.tasks, d);
    final cle = _datesCles.contains(_jour(d));
    final scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            children: [
              Text(roadmapDateCourte(d, annee: true), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              if (taches.isEmpty && jalons.isEmpty && !cle)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    children: [
                      Icon(Icons.event_available_outlined, color: scheme.onSurfaceVariant),
                      const SizedBox(height: 6),
                      Text('Aucune tâche ce jour', style: TextStyle(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              if (cle)
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.flag, color: Colors.redAccent),
                  title: Text('Date clé du planning'),
                ),
              for (final m in jalons)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.flag_outlined, color: m.color),
                  title: Text(m.title),
                  subtitle: const Text('Jalon'),
                ),
              for (final t in taches)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(width: 14, height: 14, decoration: BoxDecoration(color: t.color, shape: BoxShape.circle)),
                  title: Text(t.title),
                  subtitle: Text(roadmapPeriode(t.start, t.end)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onTache(t);
                  },
                ),
              const SizedBox(height: 14),
              FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.pop(ctx);
                  widget.onCreer(d);
                },
                icon: const Icon(Icons.add),
                label: const Text('Ajouter une tâche à cette date'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final scheme = Theme.of(context).colorScheme;
    final feuilles = _feuilles;
    final peutReculer = _annee > plan.start.year;
    final peutAvancer = _annee < plan.end.year;

    return LayoutBuilder(
      builder: (context, c) {
        final colonnes = c.maxWidth >= 1000 ? 4 : (c.maxWidth >= 640 ? 3 : 2);
        const gap = 12.0;
        final largeur = (c.maxWidth - 24 - gap * (colonnes - 1)) / colonnes;
        return ListView(
          key: const ValueKey('roadmap-calendrier'),
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Année précédente',
                  visualDensity: VisualDensity.compact,
                  onPressed: peutReculer ? () => setState(() => _annee--) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('$_annee', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                IconButton(
                  tooltip: 'Année suivante',
                  visualDensity: VisualDensity.compact,
                  onPressed: peutAvancer ? () => setState(() => _annee++) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: gap,
              runSpacing: 16,
              children: [
                for (var m = 1; m <= 12; m++) SizedBox(width: largeur, child: _mois(m, feuilles, scheme)),
              ],
            ),
          ],
        );
      },
    );
  }


  Widget _mois(int mois, List<RoadmapTask> visibles, ColorScheme scheme) {
    final cases = roadmapCasesMois(_annee, mois);
    final aujourdhui = _jour(DateTime.now());
    final cles = _datesCles;
    return Column(
      key: ValueKey('roadmap-cal-mois-$_annee-$mois'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(_moisLongs[mois - 1], style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: scheme.primary)),
        ),
        Container(
          color: const Color(0xFF37474F),
          child: Row(
            children: [
              for (final j in _joursCourts)
                Expanded(
                  child: Container(
                    height: 22,
                    alignment: Alignment.center,
                    child: Text(j, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
        ),
        for (var s = 0; s < 6; s++)
          Row(
            children: [
              for (var j = 0; j < 7; j++)
                Expanded(child: _case(cases[s * 7 + j], visibles, scheme, aujourdhui, cles)),
            ],
          ),
      ],
    );
  }

  Widget _case(DateTime? d, List<RoadmapTask> visibles, ColorScheme scheme, DateTime aujourdhui, Set<DateTime> cles) {
    final bordure = BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.55), width: 0.5);
    if (d == null) {
      return Container(height: 30, decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withValues(alpha: 0.35), border: Border.fromBorderSide(bordure)));
    }
    final taches = roadmapTachesDuJour(visibles, d);
    final jalons = roadmapJalonsDuJour(widget.plan.tasks, d);
    final estAujourdhui = d == aujourdhui;
    final cle = cles.contains(d);
    return InkWell(
      onTap: () => _detailJour(d),
      child: Container(
        key: ValueKey('roadmap-cal-jour-${d.year}-${d.month}-${d.day}'),
        height: 30,
        decoration: BoxDecoration(
          color: taches.isEmpty ? null : taches.first.color.withValues(alpha: 0.42),
          border: estAujourdhui ? Border.all(color: scheme.primary, width: 2) : Border.fromBorderSide(bordure),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text('${d.day}', style: TextStyle(fontSize: 11.5, fontWeight: estAujourdhui || taches.isNotEmpty ? FontWeight.w800 : FontWeight.w500)),
            if (taches.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Row(
                  children: [for (final t in taches.take(3)) Expanded(child: Container(height: 3, color: t.color))],
                ),
              ),
            if (jalons.isNotEmpty) Positioned(top: 1, right: 1, child: Icon(Icons.flag, size: 9, color: jalons.first.color)),
            if (cle) const Positioned(top: 2, left: 2, child: CircleAvatar(radius: 2.5, backgroundColor: Colors.redAccent)),
          ],
        ),
      ),
    );
  }
}
