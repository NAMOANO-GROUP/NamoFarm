import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/cheptel.dart';
import '../../providers/alertes_provider.dart';
import '../../providers/cheptel_provider.dart';
import '../../utils/cheptel.dart';
import '../../utils/crm_labels.dart';
import '../../utils/number_input.dart';
import '../../widgets/iso_calendar_picker.dart';
import '../../widgets/number_field.dart';

void _snack(BuildContext context, String m) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

/// Création ou modification d'un troupeau. Renvoie true si enregistré.
Future<bool> showTroupeauForm(BuildContext context, {Cheptel? cheptel}) async {
  final edition = cheptel != null;
  final nom = TextEditingController(text: cheptel?.nom ?? '');
  final effectif = TextEditingController();
  final notes = TextEditingController(text: cheptel?.notes ?? '');
  var espece = cheptel?.espece.isNotEmpty == true ? cheptel!.espece : 'chevre';
  final provider = context.read<CheptelProvider>();

  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialog) => AlertDialog(
        title: Text(edition ? 'Modifier le troupeau' : 'Nouveau troupeau'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Espèce', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final e in [
                      ...especesCheptel,
                      if (!especesCheptel.any((x) => x.valeur == espece)) especePour(espece),
                    ])
                      ChoiceChip(
                        avatar: Icon(e.icon, size: 16, color: e.color),
                        label: Text(e.libelle),
                        selected: espece == e.valeur,
                        onSelected: (_) => setDialog(() {
                          final ancien = especePour(espece).libelle;
                          espece = e.valeur;
                          if (nom.text.trim().isEmpty || nom.text.trim() == ancien) nom.text = e.libelle;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nom,
                  decoration: const InputDecoration(
                    labelText: 'Nom du troupeau',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                if (!edition)
                  NumberField(
                    controller: effectif,
                    label: 'Nombre d’animaux aujourd’hui',
                    decimal: false,
                    prefixIcon: Icons.groups_outlined,
                  ),
                TextField(
                  controller: notes,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notes', prefixIcon: Icon(Icons.notes_outlined)),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              if (nom.text.trim().isEmpty) {
                _snack(context, 'Le nom est obligatoire');
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
  if (ok != true) return false;
  final data = {
    'nom': nom.text.trim(),
    'espece': espece,
    'notes': notes.text.trim(),
    if (!edition) 'effectifInitial': parseInteger(effectif.text) ?? 0,
  };
  final done = edition ? await provider.mettreAJourCheptel(cheptel.id!, data) : await provider.creerCheptel(data);
  if (context.mounted) _snack(context, done ? 'Troupeau enregistré' : 'Erreur : ${provider.lastError ?? ''}');
  return done;
}

/// Suppression d'un troupeau après confirmation. Renvoie true si supprimé.
Future<bool> confirmerSuppressionTroupeau(BuildContext context, Cheptel c) async {
  if (c.id == null) return false;
  final provider = context.read<CheptelProvider>();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Supprimer le troupeau ?'),
      content: Text('« ${c.nom} » et tout son historique seront supprimés. Cette action est irréversible.'),
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
  if (ok != true) return false;
  final done = await provider.supprimerCheptel(c.id!);
  if (context.mounted) _snack(context, done ? 'Troupeau supprimé' : 'Suppression impossible');
  return done;
}

AlertesProvider? _alertes(BuildContext context) {
  try {
    return context.read<AlertesProvider>();
  } on ProviderNotFoundException {
    return null;
  }
}

/// Plan santé : rappels type de l'espèce, à cocher, envoyés dans la Todo.
Future<void> showPlanSanteSheet(BuildContext context, Cheptel c) async {
  final rappels = planSante(c.espece);
  final coches = <int>{for (var i = 0; i < rappels.length; i++) i};
  var depart = DateTime.now();
  final alertes = _alertes(context);

  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheet) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text('Plan santé · ${c.nom}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Rappels proposés pour cette espèce, à adapter avec votre vétérinaire. Ils seront ajoutés à la Todo.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.event_outlined),
            title: const Text('À partir du'),
            subtitle: Text(formatDateLongFr(depart)),
            onTap: () async {
              final picked = await showIsoDatePicker(
                context: sheetContext,
                initialDate: depart,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) setSheet(() => depart = picked);
            },
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (var i = 0; i < rappels.length; i++)
                  CheckboxListTile(
                    dense: true,
                    value: coches.contains(i),
                    onChanged: (v) => setSheet(() => v == true ? coches.add(i) : coches.remove(i)),
                    title: Text(rappels[i].titre),
                    subtitle: Text(
                      [
                        formatDateFr(DateTime(depart.year, depart.month, depart.day + rappels[i].jour)),
                        if (rappels[i].recurrence != 'aucune')
                          _recurrences[rappels[i].recurrence] ?? rappels[i].recurrence,
                      ].join(' · '),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: coches.isEmpty || alertes == null ? null : () => Navigator.pop(sheetContext, true),
              icon: const Icon(Icons.playlist_add_check),
              label: Text('Ajouter ${coches.length} rappel(s) à la Todo'),
            ),
          ),
        ],
      ),
    ),
  );
  if (ok != true || alertes == null) return;
  final choisis = [
    for (var i = 0; i < rappels.length; i++)
      if (coches.contains(i)) rappels[i],
  ];
  final n = await alertes.creerPlusieurs(tachesPlanSante(c, choisis, depart));
  if (context.mounted) {
    _snack(
      context,
      n == choisis.length ? '$n rappel(s) ajouté(s) à la Todo' : '$n rappel(s) sur ${choisis.length} ajouté(s)',
    );
  }
}

const _recurrences = {
  'quotidien': 'chaque jour',
  'hebdomadaire': 'chaque semaine',
  'bihebdomadaire': 'toutes les 2 semaines',
  'mensuel': 'chaque mois',
  'annuel': 'chaque année',
};

/// Mise à la reproduction : calcule la mise-bas (ou l'éclosion) et crée les tâches correspondantes.
Future<void> showMiseBasDialog(BuildContext context, Cheptel c) async {
  final e = especePour(c.espece);
  final alertes = _alertes(context);
  var saillie = DateTime.now();
  var gestation = e.gestationJours > 0 ? e.gestationJours : 150;
  final femelles = TextEditingController(text: '1');
  final duree = TextEditingController(text: '$gestation');

  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialog) {
        final prevue = DateTime(saillie.year, saillie.month, saillie.day + gestation);
        return AlertDialog(
          title: Text(e.volaille ? 'Mise en couvaison' : 'Mise à la reproduction'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: Text(e.volaille ? 'Début de la couvaison' : 'Date de saillie'),
                    subtitle: Text(formatDateLongFr(saillie)),
                    onTap: () async {
                      final picked = await showIsoDatePicker(
                        context: dialogContext,
                        initialDate: saillie,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setDialog(() => saillie = picked);
                    },
                  ),
                  NumberField(
                    controller: femelles,
                    label: e.volaille ? 'Nombre de couveuses' : 'Nombre de femelles',
                    decimal: false,
                    prefixIcon: Icons.female,
                  ),
                  TextField(
                    controller: duree,
                    keyboardType: TextInputType.number,
                    onChanged: (v) => setDialog(() => gestation = int.tryParse(v) ?? gestation),
                    decoration: InputDecoration(
                      labelText: e.volaille ? 'Durée d’incubation' : 'Durée de gestation',
                      suffixText: 'jours',
                      prefixIcon: const Icon(Icons.timelapse),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: e.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${e.naissanceLibelle} prévue le ${formatDateLongFr(prevue)}.\n'
                      'Trois tâches seront ajoutées à la Todo : préparation, jour J et contrôle des petits.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
            FilledButton(
              onPressed: alertes == null ? null : () => Navigator.pop(dialogContext, true),
              child: const Text('Planifier'),
            ),
          ],
        );
      },
    ),
  );
  if (ok != true || alertes == null) return;
  final taches = tachesNaissancePrevue(
    c,
    saillie,
    nbFemelles: parseInteger(femelles.text) ?? 1,
    gestationJours: gestation,
  );
  final n = await alertes.creerPlusieurs(taches);
  if (context.mounted) {
    _snack(
      context,
      n == taches.length
          ? '${e.naissanceLibelle} planifiée dans la Todo'
          : 'Planification incomplète ($n/${taches.length})',
    );
  }
}
