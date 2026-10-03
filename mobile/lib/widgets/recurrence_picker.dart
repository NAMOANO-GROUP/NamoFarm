import 'package:flutter/material.dart';

const List<String> kJoursSemaineCourts = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
const List<String> kMoisFr = [
  'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
  'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
];

/// Calcule la première échéance d'une tâche selon sa récurrence/config.
/// Pour 'aucune'/'quotidien', renvoie [fallback] (la date choisie au calendrier).
DateTime computeFirstEcheance(String recurrence, Map<String, dynamic> config, DateTime fallback) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 8);
  int clampDay(int y, int m, int day) {
    final last = DateTime(y, m + 1, 0).day;
    return day.clamp(1, last);
  }

  switch (recurrence) {
    case 'hebdomadaire':
      final jours = ((config['joursSemaine'] as List?) ?? const [])
          .map((e) => (e as num).toInt())
          .toSet();
      if (jours.isEmpty) return fallback;
      for (var i = 0; i <= 7; i++) {
        final cand = today.add(Duration(days: i));
        if (jours.contains(cand.weekday)) return cand;
      }
      return fallback;
    case 'mensuel':
      final jour = (config['jourMois'] as num?)?.toInt() ?? today.day;
      var y = today.year, m = today.month;
      var cand = DateTime(y, m, clampDay(y, m, jour), 8);
      if (cand.isBefore(today)) {
        m += 1;
        if (m > 12) {
          m = 1;
          y += 1;
        }
        cand = DateTime(y, m, clampDay(y, m, jour), 8);
      }
      return cand;
    case 'annuel':
      final mois = (config['mois'] as num?)?.toInt() ?? today.month;
      final jourA = (config['jourMois'] as num?)?.toInt() ?? today.day;
      var ya = today.year;
      var candA = DateTime(ya, mois, clampDay(ya, mois, jourA), 8);
      if (candA.isBefore(today)) {
        ya += 1;
        candA = DateTime(ya, mois, clampDay(ya, mois, jourA), 8);
      }
      return candA;
    default:
      return fallback;
  }
}

/// Résumé lisible de la récurrence pour les puces d'affichage.
String recurrenceSummary(String recurrence, Map<String, dynamic> config) {
  switch (recurrence) {
    case 'quotidien':
      return 'Tous les jours';
    case 'hebdomadaire':
      final jours = ((config['joursSemaine'] as List?) ?? const [])
          .map((e) => (e as num).toInt())
          .toList()
        ..sort();
      if (jours.isEmpty) return 'Chaque semaine';
      return jours.map((j) => kJoursSemaineCourts[j - 1]).join(', ');
    case 'mensuel':
      final jour = (config['jourMois'] as num?)?.toInt();
      return jour == null ? 'Chaque mois' : 'Le $jour/mois';
    case 'annuel':
      final mois = (config['mois'] as num?)?.toInt();
      final jour = (config['jourMois'] as num?)?.toInt();
      if (mois == null) return 'Chaque an';
      return '${jour ?? ''} ${kMoisFr[mois - 1]}'.trim();
    default:
      return '';
  }
}

/// Sélecteur de récurrence (type + options conditionnelles) pour les tâches.
class RecurrencePicker extends StatefulWidget {
  final String recurrence;
  final Map<String, dynamic> config;
  final void Function(String recurrence, Map<String, dynamic> config) onChanged;

  const RecurrencePicker({
    super.key,
    required this.recurrence,
    required this.config,
    required this.onChanged,
  });

  @override
  State<RecurrencePicker> createState() => _RecurrencePickerState();
}

class _RecurrencePickerState extends State<RecurrencePicker> {
  late String _recurrence;
  late Set<int> _joursSemaine;
  late int _jourMois;
  late int _mois;

  @override
  void initState() {
    super.initState();
    _recurrence = widget.recurrence.isEmpty ? 'aucune' : widget.recurrence;
    final c = widget.config;
    _joursSemaine = ((c['joursSemaine'] as List?) ?? const [])
        .map((e) => (e as num).toInt())
        .toSet();
    final now = DateTime.now();
    _jourMois = (c['jourMois'] as num?)?.toInt() ?? now.day;
    _mois = (c['mois'] as num?)?.toInt() ?? now.month;
  }

  Map<String, dynamic> _buildConfig() {
    switch (_recurrence) {
      case 'hebdomadaire':
        return {'joursSemaine': (_joursSemaine.toList()..sort())};
      case 'mensuel':
        return {'jourMois': _jourMois};
      case 'annuel':
        return {'mois': _mois, 'jourMois': _jourMois};
      default:
        return {};
    }
  }

  void _emit() => widget.onChanged(_recurrence, _buildConfig());

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _recurrence,
          items: const [
            DropdownMenuItem(value: 'aucune', child: Text('Ne se répète pas')),
            DropdownMenuItem(value: 'quotidien', child: Text('Tous les jours')),
            DropdownMenuItem(value: 'hebdomadaire', child: Text('Chaque semaine (jours au choix)')),
            DropdownMenuItem(value: 'mensuel', child: Text('Chaque mois (jour au choix)')),
            DropdownMenuItem(value: 'annuel', child: Text('Chaque année (mois + jour)')),
          ],
          onChanged: (v) {
            setState(() => _recurrence = v ?? 'aucune');
            _emit();
          },
          decoration: const InputDecoration(labelText: 'Récurrence'),
        ),
        if (_recurrence == 'hebdomadaire') ...[
          const SizedBox(height: 8),
          const Align(alignment: Alignment.centerLeft, child: Text('Jours de la semaine', style: TextStyle(fontSize: 12, color: Colors.grey))),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 1; i <= 7; i++)
                FilterChip(
                  label: Text(kJoursSemaineCourts[i - 1]),
                  selected: _joursSemaine.contains(i),
                  onSelected: (sel) {
                    setState(() {
                      if (sel) {
                        _joursSemaine.add(i);
                      } else {
                        _joursSemaine.remove(i);
                      }
                    });
                    _emit();
                  },
                ),
            ],
          ),
        ],
        if (_recurrence == 'mensuel') ...[
          const SizedBox(height: 8),
          _jourMoisDropdown(),
        ],
        if (_recurrence == 'annuel') ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _moisDropdown()),
              const SizedBox(width: 8),
              Expanded(child: _jourMoisDropdown()),
            ],
          ),
        ],
      ],
    );
  }

  Widget _jourMoisDropdown() {
    return DropdownButtonFormField<int>(
      initialValue: _jourMois.clamp(1, 31),
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Jour du mois'),
      items: [for (var d = 1; d <= 31; d++) DropdownMenuItem(value: d, child: Text('$d'))],
      onChanged: (v) {
        setState(() => _jourMois = v ?? _jourMois);
        _emit();
      },
    );
  }

  Widget _moisDropdown() {
    return DropdownButtonFormField<int>(
      initialValue: _mois.clamp(1, 12),
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Mois'),
      items: [for (var m = 1; m <= 12; m++) DropdownMenuItem(value: m, child: Text(kMoisFr[m - 1]))],
      onChanged: (v) {
        setState(() => _mois = v ?? _mois);
        _emit();
      },
    );
  }
}
