import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/couvee.dart';
import '../../providers/reproduction_provider.dart';
import '../../utils/couvoir.dart';
import '../../utils/crm_labels.dart';
import '../../utils/number_input.dart';
import '../../widgets/iso_calendar_picker.dart';
import '../../widgets/number_field.dart';

void _snack(BuildContext context, String m) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

String _iso(DateTime d) => DateTime(d.year, d.month, d.day, 12).toIso8601String();

Widget _dateTile(BuildContext context, String label, DateTime? date, ValueChanged<DateTime> onPicked) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event_outlined),
      title: Text(label),
      subtitle: Text(date == null ? '—' : formatDateLongFr(date)),
      onTap: () async {
        final picked = await showIsoDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onPicked(picked);
      },
    );

Future<bool> _enregistrer(BuildContext context, Future<bool> Function(ReproductionProvider) action, String succes) async {
  final provider = context.read<ReproductionProvider>();
  final ok = await action(provider);
  if (context.mounted) {
    final err = provider.lastError;
    _snack(context, ok ? succes : 'Erreur${err != null && err.isNotEmpty ? ' : $err' : ''}');
  }
  return ok;
}

/// Mise en incubation (création) avec date d'éclosion prévue selon l'espèce.
Future<void> showMiseEnIncubation(BuildContext context) async {
  final code = TextEditingController();
  final race = TextEditingController();
  final oeufs = TextEditingController();
  final notes = TextEditingController();
  var date = DateTime.now();

  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (dialogContext, setDialog) {
        final inc = incubationPour(race.text);
        final prevue = DateTime(date.year, date.month, date.day + inc.jours);
        return AlertDialog(
          title: const Text('Mise en incubation'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: code,
                    decoration: const InputDecoration(labelText: 'Code de la couvée', prefixIcon: Icon(Icons.tag)),
                  ),
                  TextField(
                    controller: race,
                    onChanged: (_) => setDialog(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Race / espèce',
                      helperText: 'Ex. Poule locale, Pintade, Canard, Caille',
                      prefixIcon: Icon(Icons.egg_outlined),
                    ),
                  ),
                  NumberField(controller: oeufs, label: 'Nombre d’œufs', decimal: false, prefixIcon: Icons.numbers),
                  _dateTile(dialogContext, 'Date de mise en incubation', date, (d) => setDialog(() => date = d)),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${inc.espece} : ${inc.jours} jours d’incubation.\nÉclosion prévue le ${formatDateLongFr(prevue)}.'),
                  ),
                  TextField(
                    controller: notes,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Notes (origine des œufs...)', prefixIcon: Icon(Icons.notes_outlined)),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
            FilledButton(
              onPressed: () {
                if (code.text.trim().isEmpty || (parseInteger(oeufs.text) ?? 0) <= 0) {
                  _snack(context, 'Indiquez le code et le nombre d’œufs.');
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    ),
  );
  if (ok != true || !context.mounted) return;
  await _enregistrer(
    context,
    (p) => p.creer({
      'code': code.text.trim(),
      'race': race.text.trim(),
      'dateMiseIncubation': _iso(date),
      'nbOeufsIncubes': parseInteger(oeufs.text),
      'notes': notes.text.trim(),
    }),
    'Couvée mise en incubation',
  );
}

/// Saisie de l'éclosion (éclos, viables, date).
Future<void> showSaisieEclosion(BuildContext context, Couvee c) async {
  final eclos = TextEditingController(text: c.nbEclos?.toString() ?? '');
  final viables = TextEditingController(text: c.nbPoussinsViables?.toString() ?? '');
  var date = c.dateEclosion?.toLocal() ?? DateTime.now();

  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (dialogContext, setDialog) => AlertDialog(
        title: Text('Éclosion · ${c.code}'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${c.nbOeufsIncubes} œufs incubés'),
                NumberField(controller: eclos, label: 'Poussins éclos', decimal: false, prefixIcon: Icons.egg_alt),
                NumberField(
                  controller: viables,
                  label: 'Poussins viables (facultatif)',
                  decimal: false,
                  prefixIcon: Icons.favorite_border,
                ),
                _dateTile(dialogContext, 'Date d’éclosion', date, (d) => setDialog(() => date = d)),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: eclos,
                  builder: (_, _, _) {
                    final n = parseInteger(eclos.text);
                    if (n == null || c.nbOeufsIncubes <= 0) return const SizedBox.shrink();
                    final t = n / c.nbOeufsIncubes * 100;
                    final bon = t >= objectifEclosionPct;
                    return Text(
                      'Taux d’éclosion : ${t.toStringAsFixed(1)} % (objectif ${objectifEclosionPct.round()} %)',
                      style: TextStyle(fontWeight: FontWeight.w600, color: bon ? Colors.green.shade700 : Colors.orange.shade800),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              final n = parseInteger(eclos.text);
              final v = viables.text.trim().isEmpty ? null : parseInteger(viables.text);
              if (n == null || n < 0 || n > c.nbOeufsIncubes) {
                _snack(context, 'Le nombre d’éclos doit être entre 0 et ${c.nbOeufsIncubes}.');
                return;
              }
              if (v != null && (v < 0 || v > n)) {
                _snack(context, 'Les viables ne peuvent pas dépasser les éclos.');
                return;
              }
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Enregistrer l’éclosion'),
          ),
        ],
      ),
    ),
  );
  if (ok != true || c.id == null || !context.mounted) return;
  await _enregistrer(
    context,
    (p) => p.mettreAJour(c.id!, {
      'nbEclos': parseInteger(eclos.text),
      'nbPoussinsViables': viables.text.trim().isEmpty ? null : parseInteger(viables.text),
      'dateEclosion': _iso(date),
      'statut': 'eclos',
    }),
    'Éclosion enregistrée',
  );
}

/// Modification complète d'une couvée.
Future<void> showModifierCouvee(BuildContext context, Couvee c) async {
  final code = TextEditingController(text: c.code);
  final race = TextEditingController(text: c.race);
  final oeufs = TextEditingController(text: '${c.nbOeufsIncubes}');
  final eclos = TextEditingController(text: c.nbEclos?.toString() ?? '');
  final viables = TextEditingController(text: c.nbPoussinsViables?.toString() ?? '');
  final notes = TextEditingController(text: c.notes);
  var dateIncubation = c.dateMiseIncubation?.toLocal() ?? DateTime.now();
  DateTime? dateEclosion = c.dateEclosion?.toLocal();
  var statut = statutsCouvee.containsKey(c.statut) ? c.statut : 'en_incubation';
  int? entier(String s) => s.trim().isEmpty ? null : parseInteger(s);

  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (dialogContext, setDialog) => AlertDialog(
        title: const Text('Modifier la couvée'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(controller: code, decoration: const InputDecoration(labelText: 'Code')),
                TextField(controller: race, decoration: const InputDecoration(labelText: 'Race / espèce')),
                NumberField(controller: oeufs, label: 'Œufs incubés', decimal: false),
                _dateTile(dialogContext, 'Mise en incubation', dateIncubation, (d) => setDialog(() => dateIncubation = d)),
                NumberField(controller: eclos, label: 'Poussins éclos', decimal: false),
                NumberField(controller: viables, label: 'Poussins viables', decimal: false),
                _dateTile(dialogContext, 'Éclosion', dateEclosion, (d) => setDialog(() => dateEclosion = d)),
                DropdownButtonFormField<String>(
                  initialValue: statut,
                  decoration: const InputDecoration(labelText: 'Statut'),
                  items: [
                    for (final e in statutsCouvee.entries) DropdownMenuItem(value: e.key, child: Text(e.value.$1)),
                  ],
                  onChanged: (v) => setDialog(() => statut = v ?? statut),
                ),
                TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              if (code.text.trim().isEmpty || entier(oeufs.text) == null) {
                _snack(context, 'Le code et le nombre d’œufs sont obligatoires.');
                return;
              }
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    ),
  );
  if (ok != true || c.id == null || !context.mounted) return;
  await _enregistrer(
    context,
    (p) => p.mettreAJour(c.id!, {
      'code': code.text.trim(),
      'race': race.text.trim(),
      'dateMiseIncubation': _iso(dateIncubation),
      'nbOeufsIncubes': entier(oeufs.text),
      'nbEclos': entier(eclos.text),
      'nbPoussinsViables': entier(viables.text),
      'dateEclosion': dateEclosion == null ? null : _iso(dateEclosion!),
      'statut': statut,
      'notes': notes.text.trim(),
    }),
    'Couvée modifiée',
  );
}

Future<void> cloturerCouvee(BuildContext context, Couvee c) async {
  if (c.id == null) return;
  await _enregistrer(context, (p) => p.mettreAJour(c.id!, {'statut': 'termine'}), 'Couvée clôturée');
}

/// Suppression après confirmation ; renvoie true si supprimée.
Future<bool> confirmerSuppressionCouvee(BuildContext context, Couvee c) async {
  if (c.id == null) return false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Supprimer la couvée ?'),
      content: Text('« ${c.code} » sera supprimée définitivement.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;
  return _enregistrer(context, (p) => p.supprimer(c.id!), 'Couvée supprimée');
}
