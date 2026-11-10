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
const _largeurSemaine = 24.0;

DateTime _semaineSuivante(DateTime lundi) => DateTime(lundi.year, lundi.month, lundi.day + 7);

/// Regroupe des lundis en suites de semaines consécutives (triées, sans doublon).
List<List<DateTime>> roadmapSuitesDeSemaines(Iterable<DateTime> lundis) {
  final tries = {for (final l in lundis) roadmapLundi(l)}.toList()..sort();
  final suites = <List<DateTime>>[];
  for (final l in tries) {
    if (suites.isNotEmpty && _semaineSuivante(suites.last.last) == l) {
      suites.last.add(l);
    } else {
      suites.add([l]);
    }
  }
  return suites;
}

/// Retire les semaines [lundis] des marques existantes ; une marque coupée en deux devient deux marques.
List<RoadmapWeekMark> roadmapRetirerSemaines(List<RoadmapWeekMark> marques, Iterable<DateTime> lundis) {
  final retirees = {for (final l in lundis) roadmapLundi(l)};
  final out = <RoadmapWeekMark>[];
  for (final m in marques) {
    final restantes = <DateTime>[];
    for (var i = 0; i < m.weeks; i++) {
      final l = DateTime(m.start.year, m.start.month, m.start.day + 7 * i);
      if (!retirees.contains(l)) restantes.add(l);
    }
    final suites = roadmapSuitesDeSemaines(restantes);
    for (var k = 0; k < suites.length; k++) {
      out.add(RoadmapWeekMark(
        id: k == 0 ? m.id : '${m.id}-$k',
        start: suites[k].first,
        weeks: suites[k].length,
        color: m.color,
        label: m.label,
      ));
    }
  }
  return out;
}

/// Colore les semaines [lundis] (même non consécutives) : elles remplacent toute couleur déjà posée dessus.
List<RoadmapWeekMark> roadmapAppliquerCouleur(
  List<RoadmapWeekMark> marques,
  Iterable<DateTime> lundis, {
  required Color color,
  String label = '',
  String? idBase,
}) {
  final base = idBase ?? DateTime.now().microsecondsSinceEpoch.toString();
  final suites = roadmapSuitesDeSemaines(lundis);
  return [
    ...roadmapRetirerSemaines(marques, lundis),
    for (var k = 0; k < suites.length; k++)
      RoadmapWeekMark(id: '$base-$k', start: suites[k].first, weeks: suites[k].length, color: color, label: label),
  ];
}

/// Couleurs proposées pour une semaine marquée.
const roadmapCouleursMarques = [
  Color(0xFFE53935),
  Color(0xFFFB8C00),
  Color(0xFFFDD835),
  Color(0xFF43A047),
  Color(0xFF00897B),
  Color(0xFF1E88E5),
  Color(0xFF8E24AA),
  Color(0xFFD81B60),
  Color(0xFF6D4C41),
  Color(0xFF546E7A),
];

/// Roadmap en calendrier annuel : un mois par grille, chaque jour coloré selon la tâche en cours.
class RoadmapCalendrier extends StatefulWidget {
  final ProductionPlan plan;

  /// Toucher une tâche dans le détail d'un jour.
  final ValueChanged<RoadmapTask> onTache;

  /// Créer une tâche à la date touchée.
  final ValueChanged<DateTime> onCreer;

  /// Nouvelle liste de semaines marquées (couleur du numéro) après un ajout, une modification ou un retrait.
  final ValueChanged<List<RoadmapWeekMark>> onMarques;

  /// Année à afficher quand l'utilisateur demande « aujourd'hui » (incrémenter pour re-déclencher).
  final int signalAujourdhui;

  const RoadmapCalendrier({
    super.key,
    required this.plan,
    required this.onTache,
    required this.onCreer,
    required this.onMarques,
    this.signalAujourdhui = 0,
  });

  @override
  State<RoadmapCalendrier> createState() => _RoadmapCalendrierState();
}

class _RoadmapCalendrierState extends State<RoadmapCalendrier> {
  late int _annee = _anneeInitiale();

  /// Semaines (lundis) sélectionnées pour être colorées ensemble.
  final Set<DateTime> _selection = {};

  /// Fiche de couleur ouverte : elle remplace la barre de sélection du bas.
  bool _ficheOuverte = false;

  void _basculerSemaine(DateTime lundi) => setState(() {
        if (!_selection.remove(lundi)) _selection.add(lundi);
      });

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
    final marques = widget.plan.weekMarks.where((m) => m.couvre(roadmapLundi(d))).toList();
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
              if (taches.isEmpty && jalons.isEmpty && !cle && marques.isEmpty)
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
              for (final m in marques)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(width: 22, height: 5, decoration: BoxDecoration(color: m.color, borderRadius: BorderRadius.circular(3))),
                  title: Text(m.label.isEmpty ? 'Semaine marquée' : m.label),
                  subtitle: Text('Semaine ${roadmapNumeroSemaine(d)}'),
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: () {
                    Navigator.pop(ctx);
                    _ficheSemaine(roadmapLundi(d));
                  },
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

    final liste = LayoutBuilder(
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
            const SizedBox(height: 4),
            if (plan.weekMarks.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Touchez un numéro de semaine pour le colorer ; maintenez-le pour en sélectionner plusieurs.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                ),
              ),
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
    return Column(children: [if (_selection.isNotEmpty && !_ficheOuverte) _barreSelection(), Expanded(child: liste)]);
  }

  /// Barre d'action en haut, pendant la sélection de plusieurs semaines.
  Widget _barreSelection() {
    final scheme = Theme.of(context).colorScheme;
    final n = _selection.length;
    return Container(
      key: const ValueKey('roadmap-cal-selection'),
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$n semaine${n > 1 ? 's' : ''} sélectionnée${n > 1 ? 's' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSecondaryContainer),
            ),
          ),
          TextButton(onPressed: () => setState(_selection.clear), child: const Text('Annuler')),
          const SizedBox(width: 4),
          FilledButton.icon(
            onPressed: () => _ficheSemaine(_selection.first, selection: {..._selection}),
            icon: const Icon(Icons.palette_outlined),
            label: const Text('Colorer'),
          ),
        ],
      ),
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
              const SizedBox(
                width: _largeurSemaine,
                height: 22,
                child: Center(child: Text('S', style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w700))),
              ),
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
        for (var s = 0; s < 6; s++) _semaine(cases.sublist(s * 7, s * 7 + 7), visibles, scheme, aujourdhui, cles),
      ],
    );
  }

  /// Une ligne du mois : numéro de semaine (coloré si la semaine est marquée) puis les 7 jours.
  Widget _semaine(List<DateTime?> jours, List<RoadmapTask> visibles, ColorScheme scheme, DateTime aujourdhui, Set<DateTime> cles) {
    final premier = jours.whereType<DateTime>().firstOrNull;
    final lundi = premier == null ? null : roadmapLundi(premier);
    final marques = lundi == null ? const <RoadmapWeekMark>[] : widget.plan.weekMarks.where((m) => m.couvre(lundi)).toList();
    final bordure = BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.55), width: 0.5);

    final marque = marques.firstOrNull;
    final texte = marque == null
        ? scheme.onSurfaceVariant
        : (ThemeData.estimateBrightnessForColor(marque.color) == Brightness.dark ? Colors.white : Colors.black87);

    final Widget numero = lundi == null
        ? Container(width: _largeurSemaine, height: 30, decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withValues(alpha: 0.35), border: Border.fromBorderSide(bordure)))
        : InkWell(
            key: ValueKey('roadmap-cal-sem-${lundi.year}-${lundi.month}-${lundi.day}'),
            onTap: () => _selection.isNotEmpty ? _basculerSemaine(lundi) : _ficheSemaine(lundi),
            onLongPress: () => _basculerSemaine(lundi),
            child: Container(
              width: _largeurSemaine,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: marque == null ? scheme.surfaceContainerHighest.withValues(alpha: 0.55) : marque.color.withValues(alpha: 0.9),
                border: _selection.contains(lundi) ? Border.all(color: scheme.primary, width: 2.5) : Border.fromBorderSide(bordure),
              ),
              child: Text(
                '${roadmapNumeroSemaine(lundi)}',
                style: TextStyle(fontSize: 10, fontWeight: marque == null ? FontWeight.w500 : FontWeight.w800, color: texte),
              ),
            ),
          );

    return Row(
      children: [
        numero,
        for (final d in jours) Expanded(child: _case(d, visibles, scheme, aujourdhui, cles)),
      ],
    );
  }

  Future<void> _ficheSemaine(DateTime lundi, {Set<DateTime>? selection}) async {
    final multi = selection != null;
    final lundis = (selection ?? const <DateTime>{}).toList()..sort();
    final marque = multi ? null : widget.plan.weekMarks.where((m) => m.couvre(lundi)).firstOrNull;
    final modele = multi ? widget.plan.weekMarks.where((m) => lundis.any(m.couvre)).firstOrNull : marque;
    final aMarque = multi ? widget.plan.weekMarks.any((m) => lundis.any(m.couvre)) : marque != null;
    final libelle = TextEditingController(text: modele?.label ?? '');
    var couleur = modele?.color ?? roadmapCouleursMarques.first;
    var semaines = marque?.weeks ?? 1;
    final debut = marque?.start ?? lundi;
    setState(() => _ficheOuverte = true);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setFiche) {
          final scheme = Theme.of(ctx).colorScheme;
          final fin = DateTime(debut.year, debut.month, debut.day + 7 * semaines - 1);
          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 28 + MediaQuery.viewInsetsOf(ctx).bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              multi
                                  ? '${lundis.length} semaine${lundis.length > 1 ? 's' : ''} sélectionnée${lundis.length > 1 ? 's' : ''}'
                                  : semaines > 1 || marque != null && marque.start != lundi
                                      ? 'Semaines ${roadmapNumeroSemaine(debut)} à ${roadmapNumeroSemaine(fin)}'
                                      : 'Semaine ${roadmapNumeroSemaine(lundi)}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              multi
                                  ? 'Semaines ${lundis.map(roadmapNumeroSemaine).join(', ')}'
                                  : '${roadmapDateCourte(debut)} → ${roadmapDateCourte(fin, annee: true)}',
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      if (aMarque)
                        IconButton(
                          tooltip: 'Retirer la couleur',
                          onPressed: () {
                            Navigator.pop(ctx);
                            if (multi) {
                              widget.onMarques(roadmapRetirerSemaines(widget.plan.weekMarks, lundis));
                              setState(_selection.clear);
                            } else {
                              widget.onMarques([for (final m in widget.plan.weekMarks) if (m.id != marque!.id) m]);
                            }
                          },
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        ),
                      const SizedBox(width: 4),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          if (multi) {
                            widget.onMarques(roadmapAppliquerCouleur(widget.plan.weekMarks, lundis, color: couleur, label: libelle.text.trim()));
                            setState(_selection.clear);
                            return;
                          }
                          final nouvelle = RoadmapWeekMark(
                            id: marque?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
                            start: debut,
                            weeks: semaines,
                            color: couleur,
                            label: libelle.text.trim(),
                          );
                          widget.onMarques([
                            for (final m in widget.plan.weekMarks)
                              if (m.id != nouvelle.id) m,
                            nouvelle,
                          ]);
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Enregistrer'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: libelle,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Libellé (facultatif)',
                      hintText: 'Ex. Tabaski, fêtes de fin d’année, vente difficile',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Couleur', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final c in roadmapCouleursMarques)
                        InkWell(
                          key: ValueKey('roadmap-couleur-${c.toARGB32()}'),
                          customBorder: const CircleBorder(),
                          onTap: () => setFiche(() => couleur = c),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(color: couleur == c ? scheme.onSurface : Colors.transparent, width: 2.5),
                            ),
                            child: couleur == c ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                          ),
                        ),
                    ],
                  ),
                  if (!multi) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(child: Text('Nombre de semaines', style: TextStyle(fontWeight: FontWeight.w600))),
                        IconButton.outlined(
                          tooltip: 'Moins de semaines',
                          onPressed: semaines > 1 ? () => setFiche(() => semaines--) : null,
                          icon: const Icon(Icons.remove),
                        ),
                        SizedBox(width: 44, child: Center(child: Text('$semaines', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)))),
                        IconButton.outlined(
                          tooltip: 'Plus de semaines',
                          onPressed: semaines < 12 ? () => setFiche(() => semaines++) : null,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (mounted) setState(() => _ficheOuverte = false);
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
