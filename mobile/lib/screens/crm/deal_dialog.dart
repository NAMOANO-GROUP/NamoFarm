import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/crm_pipeline.dart';
import '../../providers/crm_provider.dart';
import '../../utils/crm_labels.dart';
import '../../utils/money_format.dart';
import '../../utils/number_input.dart';
import '../../widgets/form_section.dart';
import '../../widgets/iso_calendar_picker.dart';
import '../../widgets/number_field.dart';
import 'crm_common.dart';

/// Édition d'une affaire : étape, montant, probabilité, date de clôture, source.
Future<bool> showDealDialog(BuildContext context, PipelineDeal deal) async {
  final saved = await showDialog<bool>(context: context, builder: (_) => _DealDialog(deal: deal));
  return saved == true;
}

class _DealDialog extends StatefulWidget {
  final PipelineDeal deal;
  const _DealDialog({required this.deal});

  @override
  State<_DealDialog> createState() => _DealDialogState();
}

class _DealDialogState extends State<_DealDialog> {
  late String _stage = widget.deal.stage;
  late double _probabilite = widget.deal.probabilite;
  late DateTime? _cloture = widget.deal.dateCloturePrevue;
  late final TextEditingController _montant = TextEditingController(
    text: widget.deal.montant > 0 ? const ThousandsSeparatorInputFormatter(allowDecimal: false)
        .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: widget.deal.montant.round().toString()))
        .text : '',
  );
  late final TextEditingController _source =
      TextEditingController(text: widget.deal.sourceLead == 'inconnu' ? '' : widget.deal.sourceLead);
  final TextEditingController _note = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _montant.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _montant.removeListener(_refresh);
    _montant.dispose();
    _source.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final updated = widget.deal.copyWith(
      stage: _stage,
      montant: parseAmount(_montant.text) ?? 0,
      probabilite: _probabilite,
      dateCloturePrevue: _cloture,
      clearDateCloture: _cloture == null,
      sourceLead: _source.text.trim().isEmpty ? 'inconnu' : _source.text.trim(),
    );
    final ok = await context
        .read<CrmProvider>()
        .mettreAJourPipelineClient(widget.deal.clientId, updated.toUpdatePayload(note: _note.text.trim()));
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() => _saving = false);
      showCrmSnack(context, "Impossible d'enregistrer l'affaire");
    }
  }

  @override
  Widget build(BuildContext context) {
    final montant = parseAmount(_montant.text) ?? 0;
    return AlertDialog(
      title: Text('Affaire · ${widget.deal.nomComplet}'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FormSection('Étape', icon: Icons.account_tree_outlined, padding: EdgeInsets.only(bottom: 6)),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in pipelineStages)
                    ChoiceChip(
                      avatar: Icon(s.icon, size: 16, color: s.color),
                      label: Text(s.label),
                      selected: _stage == s.value,
                      onSelected: (_) => setState(() {
                        _stage = s.value;
                        _probabilite = (defaultStageProbability[s.value] ?? _probabilite).toDouble();
                      }),
                    ),
                ],
              ),
              const FormSection('Valeur', icon: Icons.payments_outlined),
              NumberField(controller: _montant, label: 'Montant estimé', decimal: false, suffixText: 'FCFA'),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Probabilité'),
                  Expanded(
                    child: Slider(
                      value: _probabilite.clamp(0, 100),
                      max: 100,
                      divisions: 20,
                      label: '${_probabilite.round()} %',
                      onChanged: (v) => setState(() => _probabilite = v),
                    ),
                  ),
                  SizedBox(width: 44, child: Text('${_probabilite.round()} %', textAlign: TextAlign.end)),
                ],
              ),
              if (montant > 0)
                Text(
                  'Prévision pondérée : ${formatAmountFcfa(montant * _probabilite / 100)}',
                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.flag_circle_outlined),
                title: const Text('Clôture prévue'),
                subtitle: Text(_cloture == null ? 'Non définie' : '${relativeDay(_cloture!)} · ${formatDateFr(_cloture!)}'),
                trailing: _cloture == null
                    ? null
                    : IconButton(
                        tooltip: 'Effacer la date',
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _cloture = null),
                      ),
                onTap: () async {
                  final d = await showIsoDatePicker(
                    context: context,
                    initialDate: _cloture ?? DateTime.now().add(const Duration(days: 14)),
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (d != null) setState(() => _cloture = d);
                },
              ),
              const FormSection('Origine', icon: Icons.travel_explore),
              TextField(controller: _source, decoration: const InputDecoration(labelText: 'Source du prospect')),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final s in leadSources)
                    ActionChip(
                      label: Text(s, style: const TextStyle(fontSize: 12)),
                      onPressed: () => setState(() => _source.text = s),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(controller: _note, maxLines: 2, decoration: const InputDecoration(labelText: 'Note (historique)')),
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
