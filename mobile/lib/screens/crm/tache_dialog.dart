import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/client.dart';
import '../../models/tache_crm.dart';
import '../../providers/crm_provider.dart';
import '../../services/api_service.dart';
import '../../utils/crm_labels.dart';
import '../../widgets/form_section.dart';
import '../../widgets/iso_calendar_picker.dart';
import 'crm_common.dart';

/// Création (tache == null) ou modification d'une tâche CRM, avec checklist façon Planner.
Future<bool> showTacheDialog(BuildContext context, {TacheCRM? tache, String? clientId, DateTime? echeance}) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => _TacheDialog(tache: tache, clientId: clientId, echeance: echeance),
  );
  return saved == true;
}

class _TacheDialog extends StatefulWidget {
  final TacheCRM? tache;
  final String? clientId;
  final DateTime? echeance;

  const _TacheDialog({this.tache, this.clientId, this.echeance});

  @override
  State<_TacheDialog> createState() => _TacheDialogState();
}

class _TacheDialogState extends State<_TacheDialog> {
  late final TextEditingController _titre = TextEditingController(text: widget.tache?.titre ?? '');
  late final TextEditingController _desc = TextEditingController(text: widget.tache?.description ?? '');
  late final TextEditingController _assigne = TextEditingController(text: widget.tache?.assigneA ?? '');
  final TextEditingController _nouvelleEtape = TextEditingController();
  late String _type = widget.tache?.type ?? 'relance';
  late String _priorite = widget.tache?.priorite ?? 'moyenne';
  late String _statut = widget.tache?.statut ?? 'a_faire';
  late bool _rappel = widget.tache?.rappelActive ?? true;
  late DateTime _echeance = widget.tache?.dateEcheance ?? widget.echeance ?? DateTime.now().add(const Duration(days: 1));
  late String? _clientId = (widget.tache?.clientId.isNotEmpty ?? false) ? widget.tache!.clientId : widget.clientId;
  late List<ChecklistItem> _checklist = [...?widget.tache?.checklist];
  List<Client> _clients = [];
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.tache != null;

  @override
  void initState() {
    super.initState();
    if (!_isEdit && _assigne.text.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _assigne.text = currentUserName(context);
      });
    }
    _loadClients();
  }

  Future<void> _loadClients() async {
    try {
      final data = await ApiService.getClients();
      final list = data
          .whereType<Map>()
          .map((e) => Client.fromJson(Map<String, dynamic>.from(e)))
          .where((c) => (c.id ?? '').isNotEmpty)
          .toList()
        ..sort((a, b) => a.nomComplet.toLowerCase().compareTo(b.nomComplet.toLowerCase()));
      if (mounted) setState(() => _clients = list);
    } catch (_) {
      // La liste des clients est facultative : la tâche peut être créée sans client.
    }
  }

  @override
  void dispose() {
    for (final c in [_titre, _desc, _assigne, _nouvelleEtape]) {
      c.dispose();
    }
    super.dispose();
  }

  void _ajouterEtape() {
    final t = _nouvelleEtape.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _checklist = [..._checklist, ChecklistItem(titre: t)];
      _nouvelleEtape.clear();
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
    final payload = {
      'clientId': _clientId,
      'titre': _titre.text.trim(),
      'description': _desc.text.trim(),
      'type': _type,
      'priorite': _priorite,
      'statut': _statut,
      'rappelActive': _rappel,
      'assigneA': _assigne.text.trim(),
      'dateEcheance': _echeance.toUtc().toIso8601String(),
      'checklist': _checklist.map((c) => c.toJson()).toList(),
    };
    final crm = context.read<CrmProvider>();
    final ok = _isEdit ? await crm.mettreAJourTache(widget.tache!.id!, payload) : await crm.creerTache(payload);
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

  Widget _chips(List<CrmOption> options, String selected, ValueChanged<String> onSelect) {
    return Wrap(
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
  }

  @override
  Widget build(BuildContext context) {
    final clientItems = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(value: null, child: Text('Aucun client')),
      ..._clients.map((c) => DropdownMenuItem<String?>(
            value: c.id,
            child: Text(c.statut == 'fournisseur' ? '${c.nomComplet} (fournisseur)' : c.nomComplet, overflow: TextOverflow.ellipsis),
          )),
    ];
    final clientValue = clientItems.any((i) => i.value == _clientId) ? _clientId : null;
    final faits = _checklist.where((c) => c.fait).length;

    return AlertDialog(
      title: Text(_isEdit ? 'Modifier la tâche' : 'Nouvelle tâche'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(controller: _titre, autofocus: !_isEdit, decoration: const InputDecoration(labelText: 'Titre *')),
              const SizedBox(height: 8),
              TextField(controller: _desc, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes')),
              const FormSection('Type', icon: Icons.category_outlined),
              _chips(tacheTypes, _type, (v) => setState(() => _type = v)),
              const FormSection('Priorité', icon: Icons.flag_outlined),
              _chips(tachePriorites, _priorite, (v) => setState(() => _priorite = v)),
              if (_isEdit) ...[
                const FormSection('Progression', icon: Icons.timelapse),
                _chips(tacheStatuts, _statut, (v) => setState(() => _statut = v)),
              ],
              const FormSection('Planification', icon: Icons.event_outlined),
              DropdownButtonFormField<String?>(
                initialValue: clientValue,
                isExpanded: true,
                items: clientItems,
                onChanged: (v) => setState(() => _clientId = v),
                decoration: const InputDecoration(labelText: 'Contact lié', prefixIcon: Icon(Icons.person_outline)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _assigne,
                decoration: const InputDecoration(labelText: 'Assignée à', prefixIcon: Icon(Icons.badge_outlined)),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month),
                title: const Text('Échéance'),
                subtitle: Text('${relativeDay(_echeance)} · ${formatDateFr(_echeance)}'),
                onTap: () async {
                  final d = await showIsoDatePicker(
                    context: context,
                    initialDate: _echeance,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (d != null) setState(() => _echeance = d);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _rappel,
                onChanged: (v) => setState(() => _rappel = v),
                title: const Text('Rappel actif'),
              ),
              FormSection('Checklist${_checklist.isEmpty ? '' : ' ($faits/${_checklist.length})'}', icon: Icons.checklist),
              for (var i = 0; i < _checklist.length; i++)
                Row(
                  children: [
                    Checkbox(
                      value: _checklist[i].fait,
                      onChanged: (v) => setState(() {
                        _checklist = [..._checklist]..[i] = _checklist[i].copyWith(fait: v ?? false);
                      }),
                    ),
                    Expanded(
                      child: Text(
                        _checklist[i].titre,
                        style: TextStyle(decoration: _checklist[i].fait ? TextDecoration.lineThrough : null),
                      ),
                    ),
                    IconButton(
                      tooltip: "Retirer l'étape",
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _checklist = [..._checklist]..removeAt(i)),
                    ),
                  ],
                ),
              TextField(
                controller: _nouvelleEtape,
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
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Annuler')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Enregistrement…' : (_isEdit ? 'Enregistrer' : 'Créer')),
        ),
      ],
    );
  }
}
