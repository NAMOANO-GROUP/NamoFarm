import 'dart:convert';
import 'package:flutter/material.dart';
import '../widgets/brand_logo.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/iso_calendar_picker.dart';
import 'planification/roadmap_calendrier.dart';

class RoadmapMilestone {
  final String id;
  final String title;
  final DateTime date;
  final Color color;

  RoadmapMilestone({
    required this.id,
    required this.title,
    required this.date,
    required this.color,
  });

  factory RoadmapMilestone.fromJson(Map<String, dynamic> json) {
    final colorValue = (json['color'] is int)
        ? json['color'] as int
        : int.tryParse((json['color'] ?? '').toString()) ?? Colors.blue.toARGB32();
    return RoadmapMilestone(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      date: DateTime.tryParse((json['date'] ?? '').toString()) ?? DateTime.now(),
      color: Color(colorValue),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'date': date.toIso8601String(),
      'color': color.toARGB32(),
    };
  }
}

class RoadmapTask {
  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final Color color;
  final bool group;
  final List<RoadmapMilestone> milestones;
  final List<RoadmapTask> subTasks;

  RoadmapTask({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.color,
    this.group = false,
    this.milestones = const [],
    this.subTasks = const [],
  });

  factory RoadmapTask.fromJson(Map<String, dynamic> json) {
    final colorValue = (json['color'] is int)
        ? json['color'] as int
      : int.tryParse((json['color'] ?? '').toString()) ?? Colors.blue.toARGB32();
    return RoadmapTask(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      start: DateTime.tryParse((json['start'] ?? '').toString()) ?? DateTime.now(),
      end: DateTime.tryParse((json['end'] ?? '').toString()) ?? DateTime.now(),
      color: Color(colorValue),
      group: json['group'] == true,
        milestones: (json['milestones'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(RoadmapMilestone.fromJson)
          .toList(),
      subTasks: (json['subTasks'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(RoadmapTask.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
      'color': color.toARGB32(),
      'group': group,
      'milestones': milestones.map((m) => m.toJson()).toList(),
      'subTasks': subTasks.map((t) => t.toJson()).toList(),
    };
  }
}

class ProductionPlan {
  final String id;
  final String name;
  final DateTime start;
  final DateTime end;
  final List<RoadmapTask> tasks;
  final List<DateTime> highlightedDates;

  ProductionPlan({
    required this.id,
    required this.name,
    required this.start,
    required this.end,
    this.tasks = const [],
    this.highlightedDates = const [],
  });

  factory ProductionPlan.fromJson(Map<String, dynamic> json) {
    return ProductionPlan(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      start: DateTime.tryParse((json['start'] ?? '').toString()) ?? DateTime.now(),
      end: DateTime.tryParse((json['end'] ?? '').toString()) ?? DateTime.now(),
      tasks: (json['tasks'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map( RoadmapTask.fromJson)
          .toList(),
      highlightedDates: (json['highlightedDates'] as List<dynamic>? ?? const [])
          .map((e) => DateTime.tryParse(e.toString()))
          .whereType<DateTime>()
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
      'tasks': tasks.map((t) => t.toJson()).toList(),
      'highlightedDates': highlightedDates.map((d) => d.toIso8601String()).toList(),
    };
  }
}

enum _RoadmapActionMode { edit, delete }

enum _RoadmapCreateKind { task, subtask, milestone, planningDate }

class _HighlightDateSelection {
  final int index;
  final DateTime date;

  const _HighlightDateSelection({required this.index, required this.date});
}

class _RoadmapGridPainter extends CustomPainter {
  _RoadmapGridPainter({required this.monthsTotal, required this.monthWidth, this.dark = false, this.todayUnit});

  final int monthsTotal;
  final double monthWidth;
  final bool dark;

  /// Position d'aujourd'hui en mois depuis le début du planning (null = hors période).
  final double? todayUnit;

  @override
  void paint(Canvas canvas, Size size) {
    final evenPaint = Paint()..color = dark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100;
    final oddPaint = Paint()..color = dark ? Colors.white.withValues(alpha: 0.09) : Colors.grey.shade200;
    final dashPaint = Paint()
      ..color = dark ? Colors.white.withValues(alpha: 0.30) : Colors.blueGrey.shade300
      ..strokeWidth = 1;

    for (var index = 0; index < monthsTotal; index += 1) {
      final left = monthWidth * index;
      final rect = Rect.fromLTWH(left, 0, monthWidth, size.height);
      canvas.drawRect(rect, index.isEven ? evenPaint : oddPaint);

      if (index > 0) {
        final x = left;
        var y = 0.0;
        while (y < size.height) {
          canvas.drawLine(Offset(x, y), Offset(x, (y + 4).clamp(0, size.height)), dashPaint);
          y += 8;
        }
      }
    }
    final t = todayUnit;
    if (t != null) {
      final x = t * monthWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), Paint()
        ..color = Colors.redAccent
        ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant _RoadmapGridPainter oldDelegate) {
    return oldDelegate.monthsTotal != monthsTotal ||
        oldDelegate.monthWidth != monthWidth ||
        oldDelegate.dark != dark ||
        oldDelegate.todayUnit != todayUnit;
  }
}

const roadmapMoisCourts = ['JANV', 'FÉVR', 'MARS', 'AVR', 'MAI', 'JUIN', 'JUIL', 'AOÛT', 'SEPT', 'OCT', 'NOV', 'DÉC'];
const _moisFr = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];

/// « 7 août » (ou « 7 août 2027 » si [annee]).
String roadmapDateCourte(DateTime d, {bool annee = false}) => '${d.day} ${_moisFr[d.month - 1]}${annee ? ' ${d.year}' : ''}';

/// Durée en jours calendaires, bornes incluses.
int roadmapDureeJours(DateTime debut, DateTime fin) =>
    DateTime.utc(fin.year, fin.month, fin.day).difference(DateTime.utc(debut.year, debut.month, debut.day)).inDays + 1;

/// « 7 août → 5 nov. · 91 j » (année ajoutée si les dates ne sont pas de la même année).
String roadmapPeriode(DateTime debut, DateTime fin) {
  final annee = debut.year != fin.year;
  return '${roadmapDateCourte(debut, annee: annee)} → ${roadmapDateCourte(fin, annee: annee)} · ${roadmapDureeJours(debut, fin)} j';
}

/// Avancement d'une tâche au jour [now] : 0 = à venir, 1 = terminée.
double roadmapAvancement(RoadmapTask t, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final jour = DateTime(n.year, n.month, n.day);
  final debut = DateTime(t.start.year, t.start.month, t.start.day);
  final fin = DateTime(t.end.year, t.end.month, t.end.day);
  if (jour.isBefore(debut)) return 0;
  if (jour.isAfter(fin)) return 1;
  // Le jour en cours compte pour moitié : le dernier jour n'est pas encore « terminé ».
  return (roadmapDureeJours(debut, jour) - 0.5) / roadmapDureeJours(debut, fin);
}

/// Tâches « feuilles » (sous-tâches, ou tâche sans sous-tâche) : ce sont elles qui occupent la période.
List<RoadmapTask> roadmapFeuilles(List<RoadmapTask> taches) => [
      for (final t in taches)
        if (t.subTasks.isEmpty) t else ...roadmapFeuilles(t.subTasks),
    ];

/// Nombre de tâches actives chaque mois du planning (charge).
List<int> roadmapChargeParMois(ProductionPlan plan) {
  final feuilles = roadmapFeuilles(plan.tasks);
  final out = <int>[];
  var m = DateTime(plan.start.year, plan.start.month, 1);
  final dernier = DateTime(plan.end.year, plan.end.month, 1);
  while (!m.isAfter(dernier)) {
    final fin = DateTime(m.year, m.month + 1, 0);
    out.add(feuilles.where((t) => !t.start.isAfter(fin) && !t.end.isBefore(m)).length);
    m = DateTime(m.year, m.month + 1, 1);
  }
  return out;
}

class RoadmapScreen extends StatefulWidget {
  /// Ouvert depuis Planification : une flèche de retour remplace le logo.
  final VoidCallback? onRetour;

  const RoadmapScreen({super.key, this.onRetour});

  @override
  State<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends State<RoadmapScreen> {
  final List<ProductionPlan> _plans = [];
  String? _selectedPlanId;
  double _zoom = 1.0;
  bool _calendrier = false;
  int _signalAujourdhui = 0;
  final ScrollController _hScroll = ScrollController();

  static const String _vuePrefsKey = 'roadmap.vue';
  static const _zooms = {'Mois': 1.0, 'Trimestre': 0.5, 'Année': 0.25};
  static const double _margeTimeline = 20;
  static const double _baseMonthWidth = 72;
  static const String _plansPrefsKey = 'roadmap.productionPlans';
  static const String _selectedPlanPrefsKey = 'roadmap.selectedPlanId';
  static const List<Color> _taskColors = [
    Color(0xFF1E88E5), Color(0xFF43A047), Color(0xFFFB8C00), Color(0xFF8E24AA), Color(0xFFE53935),
    Color(0xFF00897B), Color(0xFFF4511E), Color(0xFF3949AB), Color(0xFF7CB342), Color(0xFF6D4C41),
    Color(0xFF00ACC1), Color(0xFF5E35B1), Color(0xFFC0CA33), Color(0xFFD81B60), Color(0xFF546E7A),
    Color(0xFF039BE5), Color(0xFF7E57C2), Color(0xFFFF7043), Color(0xFF26A69A), Color(0xFF8D6E63),
    Color(0xFFEF5350), Color(0xFFAB47BC), Color(0xFF66BB6A), Color(0xFFFFCA28), Color(0xFF29B6F6),
    Color(0xFFFF8A65), Color(0xFF9CCC65), Color(0xFF42A5F5), Color(0xFFA1887F), Color(0xFF26C6DA),
  ];

  @override
  void initState() {
    super.initState();
    _loadPlans();
    SharedPreferences.getInstance().then((p) {
      if (mounted && p.getString(_vuePrefsKey) == 'calendrier') setState(() => _calendrier = true);
    });
  }

  Future<void> _changerVue() async {
    setState(() => _calendrier = !_calendrier);
    final p = await SharedPreferences.getInstance();
    await p.setString(_vuePrefsKey, _calendrier ? 'calendrier' : 'gantt');
  }

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

  ProductionPlan? get _selectedPlan {
    if (_selectedPlanId == null) return null;
    for (final p in _plans) {
      if (p.id == _selectedPlanId) return p;
    }
    return null;
  }

  Future<void> _loadPlans() async {
    // 1) Load the local cache first (fast, works offline).
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_plansPrefsKey);
    final selectedLocal = prefs.getString(_selectedPlanPrefsKey);

    List<ProductionPlan> localPlans = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = json.decode(raw);
        final dynamic rawPlans = decoded is List
            ? decoded
            : (decoded is Map ? decoded['plans'] : null);
        if (rawPlans is List) {
          localPlans = rawPlans
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .map(ProductionPlan.fromJson)
              .toList();
        }
      } catch (_) {
        // Ignore malformed persisted roadmap data.
      }
    }

    if (mounted && localPlans.isNotEmpty) {
      setState(() {
        _plans
          ..clear()
          ..addAll(localPlans);
        _selectedPlanId = (selectedLocal != null && _plans.any((p) => p.id == selectedLocal))
            ? selectedLocal
            : _plans.first.id;
      });
    }

    // 2) Server is the source of truth (persists across devices / sessions).
    try {
      final data = await ApiService.getRoadmap();
      final dynamic serverPlansRaw = data['plans'];
      final String? serverSelected = data['selectedPlanId']?.toString();

      if (serverPlansRaw is List) {
        final serverPlans = serverPlansRaw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .map(ProductionPlan.fromJson)
            .toList();

        if (serverPlans.isNotEmpty) {
          if (!mounted) return;
          setState(() {
            _plans
              ..clear()
              ..addAll(serverPlans);
            _selectedPlanId = (serverSelected != null && _plans.any((p) => p.id == serverSelected))
                ? serverSelected
                : _plans.first.id;
          });
          await _saveLocalOnly();
        } else if (localPlans.isNotEmpty) {
          // Server empty but we have local plans -> migrate them to the server.
          await _saveServerOnly();
        }
      }
    } catch (_) {
      // Offline or server unavailable: keep the local cache as-is.
    }
  }

  Future<void> _saveLocalOnly() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_plansPrefsKey, json.encode(_plans.map((p) => p.toJson()).toList()));
    if (_selectedPlanId != null && _selectedPlanId!.isNotEmpty) {
      await prefs.setString(_selectedPlanPrefsKey, _selectedPlanId!);
    } else {
      await prefs.remove(_selectedPlanPrefsKey);
    }
  }

  Future<void> _saveServerOnly() async {
    try {
      await ApiService.saveRoadmap({
        'plans': _plans.map((p) => p.toJson()).toList(),
        'selectedPlanId': _selectedPlanId,
      });
    } catch (_) {
      // Best-effort: if the server is unreachable, the local cache still holds the data.
    }
  }

  Future<void> _savePlans() async {
    await _saveLocalOnly();
    await _saveServerOnly();
  }

  int _monthSpan(DateTime start, DateTime end) {
    return ((end.year - start.year) * 12) + (end.month - start.month) + 1;
  }

  double _dateToMonthUnit(DateTime planStart, DateTime date, {bool endInclusive = false}) {
    final planMonthStart = DateTime(planStart.year, planStart.month, 1);
    final monthOffset = ((date.year - planMonthStart.year) * 12) + (date.month - planMonthStart.month);
    final daysInMonth = DateTime(date.year, date.month + 1, 0).day;
    final numerator = (date.day - 1) + (endInclusive ? 1 : 0);
    final fraction = (numerator / daysInMonth).clamp(0.0, 1.0);
    return monthOffset + fraction;
  }

  double _monthWidth() => _baseMonthWidth * _zoom;

  double _timelineWidth(ProductionPlan plan) {
    return _monthSpan(plan.start, plan.end) * _monthWidth();
  }

  double? _todayUnit(ProductionPlan plan) {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    if (today.isBefore(DateTime(plan.start.year, plan.start.month, 1)) ||
        today.isAfter(DateTime(plan.end.year, plan.end.month + 1, 0))) {
      return null;
    }
    return _dateToMonthUnit(plan.start, today, endInclusive: true) - 0.5 / DateTime(today.year, today.month + 1, 0).day;
  }

  void _allerAujourdhui(ProductionPlan plan) {
    if (_calendrier) {
      setState(() => _signalAujourdhui++);
      return;
    }
    final t = _todayUnit(plan);
    if (t == null || !_hScroll.hasClients) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aujourd’hui est hors de la période du planning')));
      return;
    }
    final viewport = _hScroll.position.viewportDimension;
    final cible = (t * _monthWidth() - viewport / 3).clamp(0.0, _hScroll.position.maxScrollExtent);
    _hScroll.animateTo(cible, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
  }

  void _menuPlanning(String action) {
    final plan = _selectedPlan;
    switch (action) {
      case 'nouveau':
        _showCreatePlanDialog();
      case 'periode':
        if (plan != null) _showEditPlanDialog(plan);
      case 'date_cle_modifier':
        if (plan != null) _showHighlightDatePicker(plan, _RoadmapActionMode.edit);
      case 'date_cle_supprimer':
        if (plan != null) _showHighlightDatePicker(plan, _RoadmapActionMode.delete);
      case 'supprimer':
        if (plan != null) _showDeletePlanDialog(plan);
      case 'tout':
        _showDeleteAllPlansDialog();
    }
  }

  /// Titre : le planning affiché, cliquable pour en changer.
  Widget _titrePlanning(ProductionPlan? plan) {
    if (_plans.isEmpty) return const Text('Roadmap');
    return PopupMenuButton<String>(
      tooltip: 'Changer de planning',
      onSelected: (id) {
        if (id == '__nouveau') {
          _showCreatePlanDialog();
          return;
        }
        setState(() => _selectedPlanId = id);
        _savePlans();
      },
      itemBuilder: (_) => [
        for (final p in _plans) CheckedPopupMenuItem(value: p.id, checked: p.id == plan?.id, child: Text(p.name)),
        if (_plans.length < 5) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(value: '__nouveau', child: ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(Icons.add), title: Text('Nouveau planning'))),
        ],
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(plan?.name ?? 'Roadmap', maxLines: 1, overflow: TextOverflow.ellipsis),
                if (plan != null)
                  Text(
                    '${roadmapDateCourte(plan.start, annee: true)} → ${roadmapDateCourte(plan.end, annee: true)}',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = _selectedPlan;
    final dates = plan == null ? 0 : plan.highlightedDates.length;
    final actions = <Widget>[
          if (plan != null) ...[
            IconButton.filled(
              tooltip: 'Ajouter une tâche, un jalon ou une date clé',
              visualDensity: VisualDensity.compact,
              // Couleurs explicites : la barre du haut imposerait sinon une icône claire sur fond clair.
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              onPressed: () => _showRoadmapCreateMenu(plan),
              icon: const Icon(Icons.add),
            ),
            IconButton(
              tooltip: 'Aller à aujourd’hui',
              onPressed: () => _allerAujourdhui(plan),
              icon: const Icon(Icons.today_outlined),
            ),
            if (!_calendrier)
              PopupMenuButton<double>(
                tooltip: 'Zoom',
                icon: const Icon(Icons.zoom_in),
                onSelected: (z) => setState(() => _zoom = z),
                itemBuilder: (_) => [
                  for (final e in _zooms.entries) CheckedPopupMenuItem(value: e.value, checked: _zoom == e.value, child: Text(e.key)),
                ],
              ),
            IconButton(
              tooltip: _calendrier ? 'Vue planning (Gantt)' : 'Vue calendrier',
              onPressed: _changerVue,
              icon: Icon(_calendrier ? Icons.view_timeline_outlined : Icons.calendar_month_outlined),
            ),
          ],
          PopupMenuButton<String>(
            tooltip: 'Plus d’options',
            onSelected: _menuPlanning,
            itemBuilder: (_) => [
              if (_plans.length < 5)
                const PopupMenuItem(value: 'nouveau', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.add_chart), title: Text('Nouveau planning'))),
              if (plan != null) ...[
                const PopupMenuItem(value: 'periode', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.edit_calendar_outlined), title: Text('Renommer / période'))),
                if (dates > 0) ...[
                  const PopupMenuItem(value: 'date_cle_modifier', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.outlined_flag), title: Text('Modifier une date clé'))),
                  const PopupMenuItem(value: 'date_cle_supprimer', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.flag_outlined), title: Text('Supprimer une date clé'))),
                ],
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'supprimer', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.delete_outline, color: Colors.redAccent), title: Text('Supprimer ce planning'))),
              ],
              if (_plans.length > 1)
                const PopupMenuItem(value: 'tout', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.delete_sweep_outlined, color: Colors.redAccent), title: Text('Supprimer tous les plannings'))),
            ],
          ),
    ];
    final corps = plan == null
        ? EmptyState(
            icon: Icons.view_timeline_outlined,
            title: 'Aucun planning',
            subtitle: 'Un planning montre vos bandes et projets mois par mois.',
            actionLabel: 'Créer un planning',
            actionIcon: Icons.add_chart,
            onAction: _showCreatePlanDialog,
          )
        : _calendrier
            ? RoadmapCalendrier(
                plan: plan,
                signalAujourdhui: _signalAujourdhui,
                onTache: (t) => _ficheTache(plan, t),
                onCreer: (d) => _showAddTaskDialog(plan, asSubtask: false, debut: d),
              )
            : Padding(padding: const EdgeInsets.fromLTRB(8, 4, 8, 8), child: _buildPlanDetails(plan));

    return Scaffold(
      appBar: AppBar(
        leading: widget.onRetour == null
            ? const BrandLogo()
            : IconButton(tooltip: 'Retour à Planification', icon: const Icon(Icons.arrow_back), onPressed: widget.onRetour),
        title: _titrePlanning(plan),
        actions: actions,
      ),
      body: corps,
    );
  }

  Widget _buildPlanDetails(ProductionPlan plan) {
    final today = _todayUnit(plan);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Marge de 20 de chaque côté : celle des cartes de tâches (liste 8 + carte 4 + contenu 8).
          final timelineWidth = (_timelineWidth(plan) + 2 * _margeTimeline).clamp(constraints.maxWidth, double.infinity);
          return SingleChildScrollView(
            controller: _hScroll,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: timelineWidth,
              height: constraints.maxHeight,
              child: Column(
                children: [
                  Padding(padding: const EdgeInsets.fromLTRB(_margeTimeline, 6, _margeTimeline, 4), child: _buildMonthHeader(plan, today)),
                  const Divider(height: 1),
                  Expanded(
                    child: plan.tasks.isEmpty
                        ? Center(
                            child: Text(
                              'Ajoutez une tâche avec le bouton « + »,\nou maintenez le doigt sur le planning.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          )
                        : GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onLongPressStart: (d) => _tacheALaDate(plan, d.localPosition.dx),
                            child: ListView(
                              padding: const EdgeInsets.all(8),
                              children: [for (final e in _lignesTaches(plan.tasks)) _buildTaskTile(e.$1, plan, indent: e.$2 * 16.0, today: today)],
                            ),
                          ),
                  ),
                  const Divider(height: 1),
                  Padding(padding: const EdgeInsets.fromLTRB(_margeTimeline, 4, _margeTimeline, 6), child: _buildCharge(plan)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Tâches et sous-tâches à plat (avec leur niveau) : chaque carte garde sa barre alignée sur les mois.
  List<(RoadmapTask, int)> _lignesTaches(List<RoadmapTask> taches, [int niveau = 0]) => [
        for (final t in taches) ...[(t, niveau), ..._lignesTaches(t.subTasks, niveau + 1)],
      ];

  /// Appui long sur le planning : nouvelle tâche qui commence à la date touchée.
  void _tacheALaDate(ProductionPlan plan, double dx) {
    final unit = ((dx - _margeTimeline) / _monthWidth()).clamp(0.0, _monthSpan(plan.start, plan.end) - 0.001);
    final mois = DateTime(plan.start.year, plan.start.month + unit.floor(), 1);
    final jours = DateTime(mois.year, mois.month + 1, 0).day;
    var debut = DateTime(mois.year, mois.month, 1 + ((unit - unit.floor()) * jours).floor());
    // Premier et dernier mois souvent partiels : la date reste dans la période du planning.
    if (debut.isBefore(plan.start)) debut = plan.start;
    if (debut.isAfter(plan.end)) debut = plan.end;
    _showAddTaskDialog(plan, asSubtask: false, debut: debut);
  }

  Widget _buildMonthHeader(ProductionPlan plan, double? today) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final months = <DateTime>[];
    final first = DateTime(plan.start.year, plan.start.month, 1);
    final last = DateTime(plan.end.year, plan.end.month, 1);
    var cursor = first;
    while (!cursor.isAfter(last)) {
      months.add(cursor);
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    final w = _monthWidth();

    return SizedBox(
      key: const ValueKey('roadmap-header-timeline'),
      width: _timelineWidth(plan),
      child: Stack(
        children: [
          Row(
            children: months.map((m) {
              final courant = m.year == now.year && m.month == now.month;
              final highlighted = plan.highlightedDates.any((d) => d.year == m.year && d.month == m.month);
              final bg = courant
                  ? scheme.primary.withValues(alpha: dark ? 0.30 : 0.15)
                  : highlighted
                      ? (dark ? Colors.amber.shade900.withValues(alpha: 0.45) : Colors.amber.shade100)
                      : (dark ? Colors.white.withValues(alpha: 0.06) : Colors.blueGrey.shade50);
              final borderColor = courant
                  ? scheme.primary
                  : highlighted
                      ? (dark ? Colors.amber.shade400 : Colors.amber.shade700)
                      : (dark ? Colors.white24 : Colors.blueGrey.shade200);
              final fg = dark ? Colors.white : Colors.black87;
              final nom = roadmapMoisCourts[m.month - 1];
              final libelle = w >= 44 ? nom : (w >= 26 ? nom.substring(0, 3) : nom.substring(0, 1));
              final annee = w >= 44 || m.month == 1;
              return Container(
                key: ValueKey('roadmap-month-${m.year}-${m.month}'),
                width: w,
                padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 3),
                decoration: BoxDecoration(color: bg, border: Border.all(color: borderColor)),
                child: Column(
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(libelle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: courant ? scheme.primary : fg)),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(annee ? '${m.year}' : ' ', style: TextStyle(fontSize: 9, color: fg.withValues(alpha: 0.7))),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          if (today != null)
            Positioned(
              left: today * w - 1,
              top: 0,
              bottom: 0,
              child: Tooltip(message: 'Aujourd’hui', child: Container(width: 2, color: Colors.redAccent)),
            ),
        ],
      ),
    );
  }

  /// Charge : nombre de tâches en cours chaque mois.
  Widget _buildCharge(ProductionPlan plan) {
    final charge = roadmapChargeParMois(plan);
    final maxi = charge.isEmpty ? 0 : charge.reduce((a, b) => a > b ? a : b);
    final scheme = Theme.of(context).colorScheme;
    final w = _monthWidth();
    return SizedBox(
      key: const ValueKey('roadmap-charge'),
      width: _timelineWidth(plan),
      height: 26,
      child: Row(
        children: [
          for (var i = 0; i < charge.length; i++)
            Tooltip(
              message: '${charge[i]} en cours',
              child: Container(
                width: w,
                margin: EdgeInsets.zero,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: charge[i] == 0
                      ? Colors.transparent
                      : Color.lerp(Colors.teal.shade200, Colors.deepOrange, maxi <= 1 ? 0 : (charge[i] - 1) / (maxi - 1))!
                          .withValues(alpha: 0.35),
                  border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    charge[i] == 0 ? '–' : '${charge[i]}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: charge[i] == 0 ? scheme.outline : null),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTaskTile(RoadmapTask task, ProductionPlan plan, {double indent = 0, double? today}) {
    final monthsTotal = _monthSpan(plan.start, plan.end);
    final startOffset = _dateToMonthUnit(plan.start, task.start).clamp(0.0, monthsTotal.toDouble());
    final endOffset = _dateToMonthUnit(plan.start, task.end, endInclusive: true).clamp(0.0, monthsTotal.toDouble());
    final barDuration = (endOffset - startOffset).clamp(0.12, monthsTotal.toDouble());
    final avancement = roadmapAvancement(task);
    final terminee = avancement >= 1;
    final barWidth = _monthWidth() * barDuration;
    final periode = roadmapPeriode(task.start, task.end);
    final scheme = Theme.of(context).colorScheme;
    final couleur = terminee ? task.color.withValues(alpha: 0.45) : task.color;

    return Card(
      margin: const EdgeInsets.only(left: 4, right: 4, bottom: 6),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => _ficheTache(plan, task),
              child: Row(
                children: [
                  if (indent > 0) ...[
                    SizedBox(width: indent - 8),
                    Icon(Icons.subdirectory_arrow_right, size: 14, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: task.group ? FontWeight.w700 : FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    terminee ? 'Terminée' : periode,
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              key: ValueKey('roadmap-task-timeline-${task.id}'),
              width: _timelineWidth(plan),
              height: 24,
              child: CustomPaint(
                painter: _RoadmapGridPainter(
                  monthsTotal: monthsTotal,
                  monthWidth: _monthWidth(),
                  dark: Theme.of(context).brightness == Brightness.dark,
                  todayUnit: today,
                ),
                child: Stack(
                  children: [
                    Positioned(
                      key: ValueKey('roadmap-bar-${task.id}'),
                      left: _monthWidth() * startOffset,
                      top: 3,
                      child: Tooltip(
                        message: '${task.title}\n$periode',
                        child: GestureDetector(
                          onTap: () => _ficheTache(plan, task),
                          child: Container(
                            width: barWidth,
                            height: 18,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(color: couleur, borderRadius: BorderRadius.circular(9)),
                            child: Stack(
                              children: [
                                if (avancement > 0 && avancement < 1)
                                  Container(width: barWidth * avancement, color: Colors.black.withValues(alpha: 0.22)),
                                if (barWidth >= 70)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        periode,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    ...task.milestones.map((m) {
                      final unit = _dateToMonthUnit(plan.start, m.date).clamp(0.0, monthsTotal.toDouble());
                      return Positioned(
                        left: (_monthWidth() * unit) - 7,
                        top: 1,
                        child: Tooltip(
                          message: '${m.title} · ${roadmapDateCourte(m.date, annee: true)}',
                          child: GestureDetector(
                            onTap: () => _showEditMilestoneDialog(plan, task, m),
                            child: Icon(Icons.flag, size: 16, color: m.color),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Fiche d'une tâche (toucher la barre) : période, avancement et actions.
  Future<void> _ficheTache(ProductionPlan plan, RoadmapTask task) async {
    final avancement = roadmapAvancement(task);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Row(
                children: [
                  Container(width: 14, height: 14, decoration: BoxDecoration(color: task.color, shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(task.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(roadmapPeriode(task.start, task.end)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: avancement, minHeight: 6, color: task.color),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                avancement >= 1 ? 'Terminée' : (avancement <= 0 ? 'À venir' : 'En cours · ${(avancement * 100).round()} %'),
                style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Modifier'), onTap: () => Navigator.pop(ctx, 'modifier')),
            ListTile(leading: const Icon(Icons.flag_outlined), title: const Text('Ajouter un jalon'), onTap: () => Navigator.pop(ctx, 'jalon')),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Supprimer', style: TextStyle(color: Colors.redAccent)),
              onTap: () => Navigator.pop(ctx, 'supprimer'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'modifier':
        await _showEditTaskDialog(plan, task);
      case 'jalon':
        await _showAddMilestoneDialog(plan, task);
      case 'supprimer':
        await _showDeleteTaskDialog(plan, task);
    }
  }

  Future<void> _showCreatePlanDialog() async {
    final name = TextEditingController();
    DateTimeRange range = DateTimeRange(start: DateTime.now(), end: DateTime.now().add(const Duration(days: 365)));

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nouveau planning macro'),
          content: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom du planning *')),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Période du planning'),
                subtitle: Text('${DateFormat('dd/MM/yyyy').format(range.start)} - ${DateFormat('dd/MM/yyyy').format(range.end)}'),
                trailing: const Icon(Icons.date_range),
                onTap: () async {
                  final picked = await showIsoDateRangePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                    initialDateRange: range,
                  );
                  if (picked != null) {
                    final months = ((picked.end.year - picked.start.year) * 12) + (picked.end.month - picked.start.month) + 1;
                    if (months > 60) return;
                    setDialogState(() => range = picked);
                  }
                },
              ),
              const Text('Durée max: 5 ans', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                if (name.text.trim().isEmpty || _plans.length >= 5) return;
                final id = DateTime.now().microsecondsSinceEpoch.toString();
                final plan = ProductionPlan(id: id, name: name.text.trim(), start: range.start, end: range.end);
                setState(() {
                  _plans.add(plan);
                  _selectedPlanId = id;
                });
                _savePlans();
                Navigator.pop(ctx);
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddTaskDialog(ProductionPlan plan, {required bool asSubtask, DateTime? debut}) async {
    final title = TextEditingController();
    final d = debut ?? plan.start;
    final finProposee = DateTime(d.year, d.month + 1, d.day);
    final fin = finProposee.isAfter(plan.end) ? plan.end : finProposee;
    DateTimeRange range = DateTimeRange(start: d, end: fin.isBefore(d) ? d : fin);
    Color selectedColor = _taskColors.first;
    RoadmapTask? selectedGroup;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(asSubtask ? 'Nouvelle sous-tâche' : 'Nouvelle tâche'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Titre *')),
                if (asSubtask)
                  DropdownButtonFormField<RoadmapTask>(
                    initialValue: selectedGroup,
                    items: plan.tasks
                        .where((t) => t.group)
                        .map((t) => DropdownMenuItem(value: t, child: Text(t.title)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedGroup = v),
                    decoration: const InputDecoration(labelText: 'Tâche de regroupement *'),
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Période de la tâche'),
                  subtitle: Text('${DateFormat('dd/MM/yyyy').format(range.start)} - ${DateFormat('dd/MM/yyyy').format(range.end)}'),
                  trailing: const Icon(Icons.date_range),
                  onTap: () async {
                    final picked = await showIsoDateRangePicker(
                      context: context,
                      firstDate: plan.start,
                      lastDate: plan.end,
                      initialDateRange: range,
                    );
                    if (picked != null) setDialogState(() => range = picked);
                  },
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _taskColors
                      .map((c) => _colorDot(c, selectedColor, () => setDialogState(() => selectedColor = c)))
                      .toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                if (title.text.trim().isEmpty) return;
                if (asSubtask && selectedGroup == null) return;
                final task = RoadmapTask(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  title: title.text.trim(),
                  start: range.start,
                  end: range.end,
                  color: selectedColor,
                  group: !asSubtask,
                );

                setState(() {
                  final idx = _plans.indexWhere((p) => p.id == plan.id);
                  if (idx < 0) return;
                  final current = _plans[idx];
                  final tasks = [...current.tasks];

                  if (asSubtask) {
                    final gIndex = tasks.indexWhere((t) => t.id == selectedGroup!.id);
                    if (gIndex >= 0) {
                      final g = tasks[gIndex];
                      tasks[gIndex] = RoadmapTask(
                        id: g.id,
                        title: g.title,
                        start: g.start,
                        end: g.end,
                        color: g.color,
                        group: g.group,
                        milestones: g.milestones,
                        subTasks: [...g.subTasks, task],
                      );
                    }
                  } else {
                    tasks.add(task);
                  }

                  _plans[idx] = ProductionPlan(
                    id: current.id,
                    name: current.name,
                    start: current.start,
                    end: current.end,
                    tasks: tasks,
                    highlightedDates: current.highlightedDates,
                  );
                });
                _savePlans();
                Navigator.pop(ctx);
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorDot(Color color, Color selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: selected == color ? Colors.black : Colors.transparent, width: 2),
        ),
      ),
    );
  }

  Future<void> _showHighlightDateDialog(ProductionPlan plan) async {
    final picked = await showIsoDatePicker(
      context: context,
      initialDate: plan.start,
      firstDate: plan.start,
      lastDate: plan.end,
    );
    if (picked == null) return;

    setState(() {
      final idx = _plans.indexWhere((p) => p.id == plan.id);
      if (idx < 0) return;
      final current = _plans[idx];
      _plans[idx] = ProductionPlan(
        id: current.id,
        name: current.name,
        start: current.start,
        end: current.end,
        tasks: current.tasks,
        highlightedDates: [...current.highlightedDates, picked],
      );
    });
    _savePlans();
  }

  Future<void> _showEditPlanDialog(ProductionPlan plan) async {
    final nameCtrl = TextEditingController(text: plan.name);
    DateTimeRange range = DateTimeRange(start: plan.start, end: plan.end);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Modifier planning'),
          content: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom du planning *')),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Période du planning'),
                subtitle: Text('${DateFormat('dd/MM/yyyy').format(range.start)} - ${DateFormat('dd/MM/yyyy').format(range.end)}'),
                trailing: const Icon(Icons.date_range),
                onTap: () async {
                  final picked = await showIsoDateRangePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                    initialDateRange: range,
                  );
                  if (picked != null) setDialogState(() => range = picked);
                },
              ),
            ],
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                setState(() {
                  final idx = _plans.indexWhere((p) => p.id == plan.id);
                  if (idx < 0) return;
                  final current = _plans[idx];
                  _plans[idx] = ProductionPlan(
                    id: current.id,
                    name: nameCtrl.text.trim(),
                    start: range.start,
                    end: range.end,
                    tasks: current.tasks,
                    highlightedDates: current.highlightedDates,
                  );
                });
                _savePlans();
                Navigator.pop(ctx);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditTaskDialog(ProductionPlan plan, RoadmapTask task) async {
    final titleCtrl = TextEditingController(text: task.title);
    DateTimeRange range = DateTimeRange(start: task.start, end: task.end);
    Color selectedColor = task.color;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Modifier tâche'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Titre *')),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Période de la tâche'),
                  subtitle: Text('${DateFormat('dd/MM/yyyy').format(range.start)} - ${DateFormat('dd/MM/yyyy').format(range.end)}'),
                  trailing: const Icon(Icons.date_range),
                  onTap: () async {
                    final picked = await showIsoDateRangePicker(
                      context: context,
                      firstDate: plan.start,
                      lastDate: plan.end,
                      initialDateRange: range,
                    );
                    if (picked != null) setDialogState(() => range = picked);
                  },
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _taskColors
                      .map((c) => _colorDot(c, selectedColor, () => setDialogState(() => selectedColor = c)))
                      .toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) return;
                final updated = RoadmapTask(
                  id: task.id,
                  title: titleCtrl.text.trim(),
                  start: range.start,
                  end: range.end,
                  color: selectedColor,
                  group: task.group,
                  milestones: task.milestones,
                  subTasks: task.subTasks,
                );
                setState(() {
                  final idx = _plans.indexWhere((p) => p.id == plan.id);
                  if (idx < 0) return;
                  final current = _plans[idx];
                  _plans[idx] = ProductionPlan(
                    id: current.id,
                    name: current.name,
                    start: current.start,
                    end: current.end,
                    tasks: _replaceTask(current.tasks, updated),
                    highlightedDates: current.highlightedDates,
                  );
                });
                _savePlans();
                Navigator.pop(ctx);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  List<RoadmapTask> _replaceTask(List<RoadmapTask> tasks, RoadmapTask updated) {
    return tasks.map((t) {
      if (t.id == updated.id) {
        return updated;
      }
      if (t.subTasks.isEmpty) return t;
      return RoadmapTask(
        id: t.id,
        title: t.title,
        start: t.start,
        end: t.end,
        color: t.color,
        group: t.group,
        milestones: t.milestones,
        subTasks: _replaceTask(t.subTasks, updated),
      );
    }).toList();
  }

  Future<void> _showAddMilestoneDialog(ProductionPlan plan, RoadmapTask task) async {
    final titleCtrl = TextEditingController();
    DateTime date = task.start;
    Color selectedColor = task.color;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ajouter jalon'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Titre du jalon *')),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date du jalon'),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(date)),
                  trailing: const Icon(Icons.date_range),
                  onTap: () async {
                    final picked = await showIsoDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: plan.start,
                      lastDate: plan.end,
                    );
                    if (picked != null) setDialogState(() => date = picked);
                  },
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _taskColors
                      .map((c) => _colorDot(c, selectedColor, () => setDialogState(() => selectedColor = c)))
                      .toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) return;
                final milestone = RoadmapMilestone(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  title: titleCtrl.text.trim(),
                  date: date,
                  color: selectedColor,
                );
                final updatedTask = RoadmapTask(
                  id: task.id,
                  title: task.title,
                  start: task.start,
                  end: task.end,
                  color: task.color,
                  group: task.group,
                  milestones: [...task.milestones, milestone],
                  subTasks: task.subTasks,
                );
                setState(() {
                  final idx = _plans.indexWhere((p) => p.id == plan.id);
                  if (idx < 0) return;
                  final current = _plans[idx];
                  _plans[idx] = ProductionPlan(
                    id: current.id,
                    name: current.name,
                    start: current.start,
                    end: current.end,
                    tasks: _replaceTask(current.tasks, updatedTask),
                    highlightedDates: current.highlightedDates,
                  );
                });
                _savePlans();
                Navigator.pop(ctx);
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditMilestoneDialog(ProductionPlan plan, RoadmapTask task, RoadmapMilestone milestone) async {
    final titleCtrl = TextEditingController(text: milestone.title);
    DateTime date = milestone.date;
    Color selectedColor = milestone.color;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Modifier jalon'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Titre du jalon *')),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date du jalon'),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(date)),
                  trailing: const Icon(Icons.date_range),
                  onTap: () async {
                    final picked = await showIsoDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: plan.start,
                      lastDate: plan.end,
                    );
                    if (picked != null) setDialogState(() => date = picked);
                  },
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _taskColors
                      .map((c) => _colorDot(c, selectedColor, () => setDialogState(() => selectedColor = c)))
                      .toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                final updatedMilestones = task.milestones.where((m) => m.id != milestone.id).toList();
                final updatedTask = RoadmapTask(
                  id: task.id,
                  title: task.title,
                  start: task.start,
                  end: task.end,
                  color: task.color,
                  group: task.group,
                  milestones: updatedMilestones,
                  subTasks: task.subTasks,
                );
                setState(() {
                  final idx = _plans.indexWhere((p) => p.id == plan.id);
                  if (idx < 0) return;
                  final current = _plans[idx];
                  _plans[idx] = ProductionPlan(
                    id: current.id,
                    name: current.name,
                    start: current.start,
                    end: current.end,
                    tasks: _replaceTask(current.tasks, updatedTask),
                    highlightedDates: current.highlightedDates,
                  );
                });
                _savePlans();
                Navigator.pop(ctx);
              },
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              label: const Text('Supprimer jalon'),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) return;
                final updatedMilestones = task.milestones.map((m) {
                  if (m.id != milestone.id) return m;
                  return RoadmapMilestone(
                    id: m.id,
                    title: titleCtrl.text.trim(),
                    date: date,
                    color: selectedColor,
                  );
                }).toList();
                final updatedTask = RoadmapTask(
                  id: task.id,
                  title: task.title,
                  start: task.start,
                  end: task.end,
                  color: task.color,
                  group: task.group,
                  milestones: updatedMilestones,
                  subTasks: task.subTasks,
                );
                setState(() {
                  final idx = _plans.indexWhere((p) => p.id == plan.id);
                  if (idx < 0) return;
                  final current = _plans[idx];
                  _plans[idx] = ProductionPlan(
                    id: current.id,
                    name: current.name,
                    start: current.start,
                    end: current.end,
                    tasks: _replaceTask(current.tasks, updatedTask),
                    highlightedDates: current.highlightedDates,
                  );
                });
                _savePlans();
                Navigator.pop(ctx);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteTaskDialog(ProductionPlan plan, RoadmapTask task) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer tâche'),
        content: Text('Supprimer "${task.title}" et ses sous-tâches ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() {
      final idx = _plans.indexWhere((p) => p.id == plan.id);
      if (idx < 0) return;
      final current = _plans[idx];
      _plans[idx] = ProductionPlan(
        id: current.id,
        name: current.name,
        start: current.start,
        end: current.end,
        tasks: _removeTask(current.tasks, task.id),
        highlightedDates: current.highlightedDates,
      );
    });
    _savePlans();
  }

  Future<void> _showRoadmapCreateMenu(ProductionPlan plan) async {
    final kind = await _showRoadmapPickerDialog<_RoadmapCreateKind>(
      title: 'Ajouter un élément',
      children: [
        ListTile(
          leading: const Icon(Icons.task_alt),
          title: const Text('Tâche'),
          onTap: () => Navigator.pop(context, _RoadmapCreateKind.task),
        ),
        ListTile(
          leading: const Icon(Icons.account_tree_outlined),
          title: const Text('Sous-tâche'),
          onTap: () => Navigator.pop(context, _RoadmapCreateKind.subtask),
        ),
        ListTile(
          leading: const Icon(Icons.flag_outlined),
          title: const Text('Jalon'),
          onTap: () => Navigator.pop(context, _RoadmapCreateKind.milestone),
        ),
        ListTile(
          leading: const Icon(Icons.outlined_flag),
          title: const Text('Date clé du planning'),
          onTap: () => Navigator.pop(context, _RoadmapCreateKind.planningDate),
        ),
      ],
    );
    if (kind == null || !mounted) return;

    switch (kind) {
      case _RoadmapCreateKind.task:
        await _showAddTaskDialog(plan, asSubtask: false);
        break;
      case _RoadmapCreateKind.subtask:
        await _showAddTaskDialog(plan, asSubtask: true);
        break;
      case _RoadmapCreateKind.milestone:
        await _showMilestoneTaskPicker(plan);
        break;
      case _RoadmapCreateKind.planningDate:
        await _showHighlightDateDialog(plan);
        break;
    }
  }

  /// Boîte de sélection centrée et défilable (remplace les anciens bottom sheets
  /// ancrés en bas qui coupaient le contenu sur petits écrans).
  Future<T?> _showRoadmapPickerDialog<T>({
    required String title,
    required List<Widget> children,
  }) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 16)),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: SizedBox(
          width: double.maxFinite,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
            child: ListView(shrinkWrap: true, children: children),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        ],
      ),
    );
  }

  Future<void> _showMilestoneTaskPicker(ProductionPlan plan) async {
    final tasks = _collectAllTasks(plan.tasks);
    if (tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune tâche disponible pour ajouter un jalon')),
      );
      return;
    }

    await _showRoadmapPickerDialog<void>(
      title: 'Choisir la tâche du jalon',
      children: tasks.map((task) {
        return ListTile(
          leading: const Icon(Icons.flag_outlined),
          title: Text(task.title),
          subtitle: Text('${DateFormat('dd/MM/yyyy').format(task.start)} -> ${DateFormat('dd/MM/yyyy').format(task.end)}'),
          onTap: () {
            Navigator.pop(context);
            _showAddMilestoneDialog(plan, task);
          },
        );
      }).toList(),
    );
  }

  Future<void> _showHighlightDatePicker(ProductionPlan plan, _RoadmapActionMode mode) async {
    final dates = _collectHighlightDates(plan);
    if (dates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune date clé disponible')),
      );
      return;
    }

    await _showRoadmapPickerDialog<void>(
      title: 'Choisir une date clé',
      children: dates.map((item) {
        return ListTile(
          leading: Icon(mode == _RoadmapActionMode.edit ? Icons.edit : Icons.delete_outline, color: mode == _RoadmapActionMode.delete ? Colors.redAccent : null),
          title: Text('Date clé ${item.index + 1}'),
          subtitle: Text(DateFormat('dd/MM/yyyy').format(item.date)),
          onTap: () {
            Navigator.pop(context);
            if (mode == _RoadmapActionMode.edit) {
              _showEditHighlightDateDialog(plan, item);
            } else {
              _showDeleteHighlightDateDialog(plan, item);
            }
          },
        );
      }).toList(),
    );
  }

  List<RoadmapTask> _collectAllTasks(List<RoadmapTask> tasks) {
    final out = <RoadmapTask>[];
    for (final task in tasks) {
      out.add(task);
      out.addAll(_collectAllTasks(task.subTasks));
    }
    return out;
  }

  List<_HighlightDateSelection> _collectHighlightDates(ProductionPlan plan) {
    return List<_HighlightDateSelection>.generate(
      plan.highlightedDates.length,
      (index) => _HighlightDateSelection(index: index, date: plan.highlightedDates[index]),
    );
  }

  Future<void> _showEditHighlightDateDialog(ProductionPlan plan, _HighlightDateSelection selection) async {
    final picked = await showIsoDatePicker(
      context: context,
      initialDate: selection.date,
      firstDate: plan.start,
      lastDate: plan.end,
    );
    if (picked == null) return;

    setState(() {
      final idx = _plans.indexWhere((p) => p.id == plan.id);
      if (idx < 0) return;
      final current = _plans[idx];
      final dates = [...current.highlightedDates];
      if (selection.index < 0 || selection.index >= dates.length) return;
      dates[selection.index] = picked;
      _plans[idx] = ProductionPlan(
        id: current.id,
        name: current.name,
        start: current.start,
        end: current.end,
        tasks: current.tasks,
        highlightedDates: dates,
      );
    });
    _savePlans();
  }

  Future<void> _showDeleteHighlightDateDialog(ProductionPlan plan, _HighlightDateSelection selection) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer date clé'),
        content: Text('Supprimer la date clé du ${DateFormat('dd/MM/yyyy').format(selection.date)} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() {
      final idx = _plans.indexWhere((p) => p.id == plan.id);
      if (idx < 0) return;
      final current = _plans[idx];
      final dates = [...current.highlightedDates];
      if (selection.index < 0 || selection.index >= dates.length) return;
      dates.removeAt(selection.index);
      _plans[idx] = ProductionPlan(
        id: current.id,
        name: current.name,
        start: current.start,
        end: current.end,
        tasks: current.tasks,
        highlightedDates: dates,
      );
    });
    _savePlans();
  }

  List<RoadmapTask> _removeTask(List<RoadmapTask> tasks, String taskId) {
    final out = <RoadmapTask>[];
    for (final t in tasks) {
      if (t.id == taskId) continue;
      out.add(
        RoadmapTask(
          id: t.id,
          title: t.title,
          start: t.start,
          end: t.end,
          color: t.color,
          group: t.group,
          milestones: t.milestones,
          subTasks: _removeTask(t.subTasks, taskId),
        ),
      );
    }
    return out;
  }

  Future<void> _showDeletePlanDialog(ProductionPlan plan) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer planning'),
        content: Text('Supprimer le planning "${plan.name}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() {
      _plans.removeWhere((p) => p.id == plan.id);
      if (_selectedPlanId == plan.id) {
        _selectedPlanId = _plans.isEmpty ? null : _plans.first.id;
      }
    });
    _savePlans();
  }

  Future<void> _showDeleteAllPlansDialog() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer tous les plannings'),
        content: const Text('Cette action supprimera tous les plannings et toutes les tâches. Continuer ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Tout supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _plans.clear();
      _selectedPlanId = null;
    });
    _savePlans();
  }
}
