import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/crm_provider.dart';
import '../../utils/crm_labels.dart';
import '../../widgets/iso_calendar_picker.dart';
import 'crm_common.dart';

const _typesSaisissables = ['commentaire', 'appel', 'whatsapp', 'visite', 'email', 'reunion'];

/// Consigner une activité (note, appel, WhatsApp, visite...) sur la fiche d'un client.
Future<bool> showInteractionDialog(
  BuildContext context, {
  required String clientId,
  String type = 'commentaire',
  String sujet = '',
}) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => _InteractionDialog(clientId: clientId, initialType: type, initialSujet: sujet),
  );
  return saved == true;
}

class _InteractionDialog extends StatefulWidget {
  final String clientId;
  final String initialType;
  final String initialSujet;

  const _InteractionDialog({required this.clientId, required this.initialType, required this.initialSujet});

  @override
  State<_InteractionDialog> createState() => _InteractionDialogState();
}

class _InteractionDialogState extends State<_InteractionDialog> {
  late String _type = _typesSaisissables.contains(widget.initialType) ? widget.initialType : 'commentaire';
  late final TextEditingController _sujet = TextEditingController(text: widget.initialSujet);
  final TextEditingController _contenu = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _sujet.dispose();
    _contenu.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_contenu.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final when = DateTime(_date.year, _date.month, _date.day, now.hour, now.minute);
    final ok = await context.read<CrmProvider>().ajouterInteractionClient(widget.clientId, {
      'type': _type,
      'sujet': _sujet.text.trim(),
      'contenu': _contenu.text.trim(),
      'auteur': currentUserName(context),
      'dateInteraction': when.toUtc().toIso8601String(),
    });
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() => _saving = false);
      showCrmSnack(context, "Impossible d'enregistrer l'activité");
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Consigner une activité'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in _typesSaisissables.map(interactionType))
                    ChoiceChip(
                      avatar: Icon(t.icon, size: 16, color: t.color),
                      label: Text(t.label),
                      selected: _type == t.value,
                      onSelected: (_) => setState(() => _type = t.value),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(controller: _sujet, decoration: const InputDecoration(labelText: 'Sujet')),
              const SizedBox(height: 8),
              TextField(
                controller: _contenu,
                autofocus: true,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Compte rendu *', alignLabelWithHint: true),
              ),
              const SizedBox(height: 4),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('Date'),
                subtitle: Text(relativeDay(_date)),
                onTap: () async {
                  final d = await showIsoDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) setState(() => _date = d);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Annuler')),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Enregistrement…' : 'Enregistrer')),
      ],
    );
  }
}
