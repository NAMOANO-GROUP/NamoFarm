import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/alerte.dart';
import '../../models/bande.dart';
import '../../providers/alertes_provider.dart';
import '../../services/api_service.dart';
import '../../utils/crm_labels.dart';
import '../../utils/todo.dart';
import '../../widgets/form_section.dart';
import '../../widgets/iso_calendar_picker.dart';
import '../../widgets/recurrence_picker.dart';
import '../crm/crm_common.dart';

/// Échéances début/fin finales selon la récurrence et le mode « toute la journée ».
({DateTime debut, DateTime fin}) computeTodoEcheances(
    String rec, Map<String, dynamic> config, DateTime debut, DateTime fin, bool allDay) {
  if (rec != 'aucune' && rec != 'quotidien') {
    final first = computeFirstEcheance(rec, config, debut);
    final d = allDay
        ? DateTime(first.year, first.month, first.day)
        : DateTime(first.year, first.month, first.day, debut.hour, debut.minute);
    final durMin = fin.difference(debut).inMinutes;
    final f = allDay ? DateTime(first.year, first.month, first.day, 23, 59) : d.add(Duration(minutes: durMin > 0 ? durMin : 60));
    return (debut: d, fin: f);
  }
  final d = allDay ? DateTime(debut.year, debut.month, debut.day) : debut;
  final f = allDay ? DateTime(fin.year, fin.month, fin.day, 23, 59) : (fin.isAfter(d) ? fin : d.add(const Duration(hours: 1)));
  return (debut: d, fin: f);
}

/// Charge les bandes ouvertes (pour lier une tâche à une bande).
Future<List<Bande>> chargerBandesOuvertes() async {
  try {
    final data = await ApiService.getBandesActives();
    return data.whereType<Map>().map((e) => Bande.fromJson(Map<String, dynamic>.from(e))).where((b) => b.id != null).toList();
  } catch (_) {
    return const [];
  }
}

/// Création (alerte == null), modification, ou conversion d'une tâche automatique en tâche modifiable.
Future<bool> showTodoDialog(BuildContext context, {Alerte? alerte, DateTime? debut, String? bandeId}) async {
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _TodoDialog(alerte: alerte, debut: debut, bandeId: bandeId),
  );
  return saved == true;
}

class _TodoDialog extends StatefulWidget {
  final Alerte? alerte;
  final DateTime? debut;
  final String? bandeId;

  const _TodoDialog({this.alerte, this.debut, this.bandeId});

  @override
  State<_TodoDialog> createState() => _TodoDialogState();
}

class _TodoDialogState extends State<_TodoDialog> {
  late final Alerte? _a = widget.alerte;
  late final TextEditingController _titre = TextEditingController(text: _a?.titre ?? '');
  late final TextEditingController _message = TextEditingController(text: _a?.message ?? '');
  late final TextEditingController _assigne = TextEditingController(text: _a?.assigneA ?? '');
  final TextEditingController _etape = TextEditingController();
  late String _type = _a?.type ?? 'autre';
  late String _priorite = _a?.priorite ?? 'moyenne';
  late String _progression = _a?.progression ?? 'a_faire';
  late String _recurrence = _a?.recurrence ?? 'aucune';
  late Map<String, dynamic> _recurrenceConfig = Map<String, dynamic>.from(_a?.recurrenceConfig ?? const {});
  late bool _touteJournee = _a?.touteJournee ?? false;
  late DateTime _debut = _a?.dateEcheance ?? widget.debut ?? _defaultDebut();
  late DateTime _fin = _a?.dateFin ?? _debut.add(const Duration(hours: 1));
  late String? _bandeId = _a?.bandeId ?? widget.bandeId;
  late List<ChecklistItem> _checklist = [...?_a?.checklist];
  List<Bande> _bandes = [];
  bool _saving = false;
  String? _error;

  bool get _isNew => _a == null;
  bool get _isAuto => _a?.automatique == true;

  static DateTime _defaultDebut() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1, 8);
  }

  @override
  void initState() {
    super.initState();
    if (_isNew && _assigne.text.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _assigne.text = currentUserName(context);
      });
    }
    chargerBandesOuvertes().then((b) {
      if (mounted) setState(() => _bandes = b);
    });
  }

  @override
  void dispose() {
    for (final c in [_titre, _message, _assigne, _etape]) {
      c.dispose();
    }
    super.dispose();
  }

  String _fmt(DateTime d) => _touteJournee ? DateFormat('dd/MM/yyyy').format(d) : DateFormat('dd/MM/yyyy HH:mm').format(d);

  Future<DateTime?> _pick(DateTime initial) async {
    final date = await showIsoDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) return null;
    if (_touteJournee) return DateTime(date.year, date.month, date.day);
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    final tt = t ?? TimeOfDay.fromDateTime(initial);
    return DateTime(date.year, date.month, date.day, tt.hour, tt.minute);
  }

  void _ajouterEtape() {
    final t = _etape.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _checklist = [..._checklist, ChecklistItem(titre: t)];
      _etape.clear();
    });
  }

  Future<void> _save() async {
    if (_titre.text.trim().isEmpty) {
      setState(() => _error = 'Le titre est obligatoire');
      return;
    }
    _ajouterEtape();
    setState(() {
      _saving = true;
      _error = null;
    });
    final e = computeTodoEcheances(_recurrence, _recurrenceConfig, _debut, _fin, _touteJournee);
    final payload = <String, dynamic>{
      'titre': _titre.text.trim(),
      'message': _message.text.trim(),
      'type': _type,
      'priorite': _priorite,
      'progression': _progression,
      'recurrence': _recurrence,
      'recurrenceConfig': _recurrenceConfig,
      'dateEcheance': e.debut.toIso8601String(),
      'dateFin': e.fin.toIso8601String(),
      'touteJournee': _touteJournee,
      'bandeId': _bandeId,
      'assigneA': _assigne.text.trim(),
      'checklist': _checklist.map((c) => c.toJson()).toList(),
    };
    final provider = context.read<AlertesProvider>();
    bool ok;
    if (_isNew || _isAuto) {
      ok = await provider.creerAlerte({...payload, 'source': 'todo', 'automatique': false});
      // Une tâche automatique convertie est considérée comme traitée.
      if (ok && _isAuto) await provider.marquerFaite(_a!);
    } else {
      ok = await provider.mettreAJourAlerte(_a!.id!, payload);
    }
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = "Impossible d'enregistrer la tâche";
      });
    }
  }

  Future<void> _supprimer() async {
    final provider = context.read<AlertesProvider>();
    final navigator = Navigator.of(context);
    final ok = await confirmAction(
      context,
      title: 'Supprimer la tâche',
      message: 'Supprimer « ${_a!.titre} » ? Cette action est définitive.',
      confirmLabel: 'Supprimer',
      destructive: true,
    );
    if (!ok) return;
    final deleted = await provider.supprimer(_a);
    if (deleted && mounted) navigator.pop(true);
  }

  Widget _chips(List<CrmOption> options, String selected, ValueChanged<String> onSelect) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final o in options)
            ChoiceChip(
              avatar: Icon(o.icon, size: 16, color: o.color),
              label: Text(o.label),
              selected: selected == o.value,
              onSelected: (_) => onSelect(o.value),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final bandeItems = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(value: null, child: Text('Aucune bande')),
      ..._bandes.map((b) => DropdownMenuItem<String?>(value: b.id, child: Text(b.nom, overflow: TextOverflow.ellipsis))),
      if (_bandeId != null && !_bandes.any((b) => b.id == _bandeId))
        DropdownMenuItem<String?>(value: _bandeId, child: Text(_a?.bandeNom.isNotEmpty == true ? _a!.bandeNom : 'Bande liée')),
    ];
    final faits = _checklist.where((c) => c.fait).length;

    return AlertDialog(
      title: Text(_isNew ? 'Nouvelle tâche' : (_isAuto ? 'Convertir en tâche' : 'Modifier la tâche')),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(controller: _titre, autofocus: _isNew, decoration: const InputDecoration(labelText: 'Titre *')),
              const SizedBox(height: 8),
              TextField(controller: _message, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes')),
              const FormSection('Catégorie', icon: Icons.category_outlined),
              _chips(todoCategories, _type, (v) => setState(() => _type = v)),
              const FormSection('Priorité', icon: Icons.flag_outlined),
              _chips(tachePriorites, _priorite, (v) => setState(() => _priorite = v)),
              if (!_isNew && !_isAuto) ...[
                const FormSection('Avancement', icon: Icons.timelapse),
                _chips(todoProgressions.take(2).toList(), _progression, (v) => setState(() => _progression = v)),
              ],
              const FormSection('Affectation', icon: Icons.badge_outlined),
              DropdownButtonFormField<String?>(
                initialValue: bandeItems.any((i) => i.value == _bandeId) ? _bandeId : null,
                isExpanded: true,
                items: bandeItems,
                onChanged: (v) => setState(() => _bandeId = v),
                decoration: const InputDecoration(labelText: 'Bande', prefixIcon: Icon(Icons.egg_outlined)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _assigne,
                decoration: const InputDecoration(labelText: 'Assignée à', prefixIcon: Icon(Icons.person_outline)),
              ),
              const FormSection('Planification', icon: Icons.event_outlined),
              RecurrencePicker(
                recurrence: _recurrence,
                config: _recurrenceConfig,
                onChanged: (r, c) => setState(() {
                  _recurrence = r;
                  _recurrenceConfig = c;
                }),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Toute la journée'),
                value: _touteJournee,
                onChanged: (v) => setState(() => _touteJournee = v),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Début'),
                subtitle: Text(_fmt(_debut)),
                trailing: const Icon(Icons.schedule),
                onTap: () async {
                  final picked = await _pick(_debut);
                  if (picked != null) {
                    setState(() {
                      _debut = picked;
                      if (!_fin.isAfter(_debut)) _fin = _debut.add(const Duration(hours: 1));
                    });
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Fin'),
                subtitle: Text(_fmt(_fin)),
                trailing: const Icon(Icons.schedule),
                onTap: () async {
                  final picked = await _pick(_fin);
                  if (picked != null) setState(() => _fin = picked);
                },
              ),
              FormSection('Checklist${_checklist.isEmpty ? '' : ' ($faits/${_checklist.length})'}', icon: Icons.checklist),
              for (var i = 0; i < _checklist.length; i++)
                Row(
                  children: [
                    Checkbox(
                      value: _checklist[i].fait,
                      onChanged: (v) => setState(() => _checklist = [..._checklist]..[i] = _checklist[i].copyWith(fait: v ?? false)),
                    ),
                    Expanded(
                      child: Text(_checklist[i].titre,
                          style: TextStyle(decoration: _checklist[i].fait ? TextDecoration.lineThrough : null)),
                    ),
                    IconButton(
                      tooltip: "Retirer l'étape",
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _checklist = [..._checklist]..removeAt(i)),
                    ),
                  ],
                ),
              TextField(
                controller: _etape,
                onSubmitted: (_) => _ajouterEtape(),
                decoration: InputDecoration(
                  hintText: 'Ajouter une étape',
                  prefixIcon: const Icon(Icons.add),
                  suffixIcon: IconButton(tooltip: "Ajouter l'étape", icon: const Icon(Icons.keyboard_return), onPressed: _ajouterEtape),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (!_isNew && !_isAuto)
          TextButton(
            onPressed: _saving ? null : _supprimer,
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Annuler')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Enregistrement…' : (_isNew ? 'Créer' : (_isAuto ? 'Convertir' : 'Enregistrer'))),
        ),
      ],
    );
  }
}
