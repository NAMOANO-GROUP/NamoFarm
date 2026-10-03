import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/alerte.dart';

/// Vue calendrier type Outlook : colonnes = jours, grille horaire avec blocs
/// positionnés selon l'heure. 7 jours sur grand écran, 3 sur petit. Zoom,
/// plage horaire réglable, scroll auto à l'heure courante et glisser-déposer.
class WeekCalendarView extends StatefulWidget {
  final List<Alerte> alertes;
  final void Function(Alerte) onTap;
  final void Function(Alerte, DateTime newStart)? onMove;

  const WeekCalendarView({super.key, required this.alertes, required this.onTap, this.onMove});

  @override
  State<WeekCalendarView> createState() => _WeekCalendarViewState();
}

class _WeekCalendarViewState extends State<WeekCalendarView> {
  static const double _gutter = 44;
  static const List<String> _joursCourts = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

  late DateTime _firstDay;
  double _hourHeight = 56;
  bool _fullDay = false;
  final ScrollController _scroll = ScrollController();
  bool _scrolledToNow = false;
  final Map<int, GlobalKey> _dayKeys = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _firstDay = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  GlobalKey _keyForCol(int i) => _dayKeys.putIfAbsent(i, () => GlobalKey());

  Color _prioColor(String p) {
    switch (p) {
      case 'urgente': return Colors.red;
      case 'haute': return Colors.orange;
      case 'moyenne': return Colors.blue;
      default: return Colors.blueGrey;
    }
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  // Fond grisé pour les créneaux hors horaires de travail.
  Color get _horsTravail {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.withValues(alpha: 0.12);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final visibleDays = constraints.maxWidth > 700 ? 7 : 3;
        final colWidth = (constraints.maxWidth - _gutter) / visibleDays;
        // En vue 7 jours, on cale le début sur le lundi (lundi à gauche, dimanche à droite).
        final firstVisible = visibleDays == 7
            ? _firstDay.subtract(Duration(days: _firstDay.weekday - 1))
            : _firstDay;
        final days = [for (var i = 0; i < visibleDays; i++) firstVisible.add(Duration(days: i))];

        int startHour = 6, endHour = 21;
        if (_fullDay) {
          startHour = 0;
          endHour = 24;
        } else {
          for (final a in widget.alertes) {
            if (a.touteJournee) continue;
            if (!days.any((d) => _sameDay(d, a.dateEcheance))) continue;
            startHour = a.dateEcheance.hour < startHour ? a.dateEcheance.hour : startHour;
            final fin = a.dateFin ?? a.dateEcheance.add(const Duration(hours: 1));
            final finHour = fin.minute > 0 ? fin.hour + 1 : fin.hour;
            endHour = finHour > endHour ? finHour : endHour;
          }
          startHour = startHour.clamp(0, 23);
          endHour = endHour.clamp(startHour + 1, 24);
        }

        // Scroll auto vers l'heure courante (une fois).
        if (!_scrolledToNow) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_scrolledToNow && _scroll.hasClients) {
              final nowH = DateTime.now().hour;
              final target = ((nowH - startHour - 1).clamp(0, 24)) * _hourHeight;
              _scroll.jumpTo(target.clamp(0, _scroll.position.maxScrollExtent));
              _scrolledToNow = true;
            }
          });
        }

        return Column(
          children: [
            _navigationBar(firstVisible, visibleDays),
            _dayHeaders(days, colWidth),
            _allDayRow(days, colWidth),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                child: SizedBox(
                  height: (endHour - startHour) * _hourHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _hourGutter(startHour, endHour),
                      for (var i = 0; i < days.length; i++)
                        SizedBox(
                          width: colWidth,
                          child: _dayColumn(days[i], i, startHour, endHour, colWidth),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _navigationBar(DateTime firstVisible, int visibleDays) {
    final last = firstVisible.add(Duration(days: visibleDays - 1));
    final df = DateFormat('dd/MM');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Précédent',
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _firstDay = _firstDay.subtract(Duration(days: visibleDays))),
          ),
          Expanded(
            child: Center(
              child: Text('${df.format(firstVisible)} – ${df.format(last)}',
                  style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Suivant',
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _firstDay = _firstDay.add(Duration(days: visibleDays))),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            tooltip: 'Réduire',
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _hourHeight = (_hourHeight - 12).clamp(36, 120)),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            tooltip: 'Agrandir',
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _hourHeight = (_hourHeight + 12).clamp(36, 120)),
          ),
          IconButton(
            icon: Icon(_fullDay ? Icons.schedule : Icons.hourglass_full),
            tooltip: _fullDay ? 'Heures utiles' : 'Journée complète',
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _fullDay = !_fullDay),
          ),
          TextButton(
            onPressed: () => setState(() {
              final now = DateTime.now();
              _firstDay = DateTime(now.year, now.month, now.day);
              _scrolledToNow = false;
            }),
            child: const Text('Auj.'),
          ),
        ],
      ),
    );
  }

  Widget _dayHeaders(List<DateTime> days, double colWidth) {
    final now = DateTime.now();
    return Row(
      children: [
        const SizedBox(width: _gutter),
        for (final day in days)
          SizedBox(
            width: colWidth,
            child: Column(
              children: [
                Text(_joursCourts[(day.weekday - 1) % 7], style: const TextStyle(fontSize: 11, color: Colors.grey)),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _sameDay(day, now) ? Theme.of(context).colorScheme.primary : Colors.transparent,
                  ),
                  alignment: Alignment.center,
                  child: Text('${day.day}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _sameDay(day, now) ? Theme.of(context).colorScheme.onPrimary : null,
                      )),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _allDayRow(List<DateTime> days, double colWidth) {
    final hasAllDay = widget.alertes.any((a) => a.touteJournee && days.any((d) => _sameDay(d, a.dateEcheance)));
    if (!hasAllDay) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          width: _gutter,
          child: Padding(padding: EdgeInsets.only(right: 4), child: Text('Jour', style: TextStyle(fontSize: 9, color: Colors.grey), textAlign: TextAlign.right)),
        ),
        for (final day in days)
          SizedBox(
            width: colWidth,
            child: Column(
              children: [
                for (final a in widget.alertes.where((a) => a.touteJournee && _sameDay(a.dateEcheance, day)))
                  _taskChip(a),
              ],
            ),
          ),
      ],
    );
  }

  Widget _taskChip(Alerte a) {
    final color = _prioColor(a.priorite);
    return GestureDetector(
      onTap: () => widget.onTap(a),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(6)),
        child: Text(a.titre, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11)),
      ),
    );
  }

  Widget _hourGutter(int startHour, int endHour) {
    return SizedBox(
      width: _gutter,
      height: (endHour - startHour) * _hourHeight,
      child: Stack(
        children: [
          for (var h = startHour; h <= endHour; h++)
            Positioned(
              top: (h - startHour) * _hourHeight - 6,
              right: 4,
              child: Text('${h.toString().padLeft(2, '0')}:00', style: const TextStyle(fontSize: 9, color: Colors.grey)),
            ),
        ],
      ),
    );
  }

  Widget _dayColumn(DateTime day, int colIndex, int startHour, int endHour, double colWidth) {
    final gridMinutes = startHour * 60;
    final pxPerMin = _hourHeight / 60.0;
    final dayTasks = widget.alertes
        .where((a) => !a.touteJournee && _sameDay(a.dateEcheance, day))
        .toList()
      ..sort((a, b) => a.dateEcheance.compareTo(b.dateEcheance));
    final placements = _layout(dayTasks);
    final key = _keyForCol(colIndex);

    return DragTarget<Alerte>(
      onAcceptWithDetails: (details) {
        if (widget.onMove == null) return;
        final box = key.currentContext?.findRenderObject() as RenderBox?;
        if (box == null) return;
        final local = box.globalToLocal(details.offset);
        var minutes = gridMinutes + (local.dy / pxPerMin).round();
        minutes = ((minutes / 15).round() * 15).clamp(0, 24 * 60 - 1);
        final newStart = DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);
        widget.onMove!(details.data, newStart);
      },
      builder: (ctx, candidate, rejected) {
        return Container(
          key: key,
          decoration: BoxDecoration(
            color: candidate.isNotEmpty ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.06) : null,
            border: Border(left: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Stack(
            children: [
              // Mise en évidence des horaires de travail : grisé hors 8h–18h et tout le dimanche.
              if (day.weekday == DateTime.sunday)
                Positioned.fill(child: Container(color: _horsTravail))
              else ...[
                if (startHour < 8)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: ((8 * 60 - gridMinutes) * pxPerMin).clamp(0, double.infinity),
                    child: Container(color: _horsTravail),
                  ),
                if (endHour > 18)
                  Positioned(
                    top: ((18 * 60 - gridMinutes) * pxPerMin).clamp(0, double.infinity),
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(color: _horsTravail),
                  ),
              ],
              for (var h = startHour; h <= endHour; h++)
                Positioned(
                  top: (h - startHour) * _hourHeight,
                  left: 0,
                  right: 0,
                  child: Divider(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
                ),
              for (final p in placements)
                Positioned(
                  top: ((p.task.dateEcheance.hour * 60 + p.task.dateEcheance.minute) - gridMinutes) * pxPerMin,
                  height: (p.durationMin.clamp(30, 24 * 60)) * pxPerMin - 2,
                  left: p.leftFraction * colWidth,
                  width: p.fraction * colWidth,
                  child: _draggableBlock(p.task),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _draggableBlock(Alerte a) {
    final block = _taskBlock(a);
    // Les tâches automatiques ne sont pas déplaçables.
    if (a.automatique || widget.onMove == null) return block;
    return LongPressDraggable<Alerte>(
      data: a,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.9,
          child: SizedBox(width: 120, child: _taskBlock(a)),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: block),
      child: block,
    );
  }

  Widget _taskBlock(Alerte a) {
    final color = _prioColor(a.priorite);
    final fin = a.dateFin ?? a.dateEcheance.add(const Duration(hours: 1));
    final heure = '${DateFormat('HH:mm').format(a.dateEcheance)}–${DateFormat('HH:mm').format(fin)}';
    return GestureDetector(
      onTap: () => widget.onTap(a),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(6),
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a.titre, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            Text(heure, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 9)),
          ],
        ),
      ),
    );
  }

  List<_Placement> _layout(List<Alerte> tasks) {
    final result = <_Placement>[];
    if (tasks.isEmpty) return result;
    int endMin(Alerte a) {
      final fin = a.dateFin ?? a.dateEcheance.add(const Duration(hours: 1));
      return fin.hour * 60 + fin.minute;
    }
    int startMin(Alerte a) => a.dateEcheance.hour * 60 + a.dateEcheance.minute;

    var cluster = <Alerte>[];
    var clusterEnd = -1;
    final clusters = <List<Alerte>>[];
    for (final t in tasks) {
      if (cluster.isEmpty || startMin(t) < clusterEnd) {
        cluster.add(t);
        clusterEnd = clusterEnd > endMin(t) ? clusterEnd : endMin(t);
      } else {
        clusters.add(cluster);
        cluster = [t];
        clusterEnd = endMin(t);
      }
    }
    if (cluster.isNotEmpty) clusters.add(cluster);

    for (final c in clusters) {
      final colEnds = <int>[];
      final cols = <Alerte, int>{};
      for (final t in c) {
        var placed = false;
        for (var i = 0; i < colEnds.length; i++) {
          if (startMin(t) >= colEnds[i]) {
            colEnds[i] = endMin(t);
            cols[t] = i;
            placed = true;
            break;
          }
        }
        if (!placed) {
          cols[t] = colEnds.length;
          colEnds.add(endMin(t));
        }
      }
      final n = colEnds.length;
      for (final t in c) {
        result.add(_Placement(task: t, durationMin: endMin(t) - startMin(t), colIndex: cols[t]!, colCount: n));
      }
    }
    return result;
  }
}

class _Placement {
  final Alerte task;
  final int durationMin;
  final int colIndex;
  final int colCount;
  const _Placement({required this.task, required this.durationMin, required this.colIndex, required this.colCount});

  double get fraction => 1 / colCount;
  double get leftFraction => colIndex / colCount;
}
