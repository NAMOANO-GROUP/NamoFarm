import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/finance_provider.dart';
import '../../utils/crm_labels.dart';
import '../../utils/finance.dart';
import '../../utils/number_input.dart';
import '../../widgets/async_button.dart';
import '../../widgets/iso_calendar_picker.dart';
import '../../widgets/number_field.dart';
import 'finance_common.dart';
import 'operation_sheet.dart';

/// Fiche d'un mouvement (feuille du bas) : détail lisible, Refaire, Modifier, Supprimer.
Future<void> showMouvementDetail(BuildContext context, Mouvement m) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final provider = sheetContext.read<FinanceProvider>();
      final admin = estAdminFinance(sheetContext);
      final bande = provider.nomBande(m.bandeId);
      final scheme = Theme.of(sheetContext).colorScheme;
      Widget ligne(IconData icon, String label, String valeur) => ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, size: 20, color: scheme.onSurfaceVariant),
        title: Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        subtitle: Text(valeur, style: const TextStyle(fontSize: 15)),
      );
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: m.color.withValues(alpha: 0.15),
                  child: Icon(m.icon, color: m.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(m.libelle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                montantSigne(m.montant, m.entree),
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: couleurMontant(m.entree)),
              ),
            ),
            const SizedBox(height: 8),
            if (m.date != null)
              ligne(Icons.event_outlined, 'Date', '${timelineDayLabel(m.date!)} à ${formatHeure(m.date!)}'),
            ligne(Icons.swap_horiz, 'Origine', sourceLibelle(m.source)),
            if (m.estDepense && m.categorie.isNotEmpty)
              ligne(Icons.category_outlined, 'Activité', activiteLibelle(m.categorie)),
            if (bande.isNotEmpty) ligne(Icons.layers_outlined, 'Bande', bande),
            if (m.qui.isNotEmpty) ligne(Icons.person_outline, m.entree ? 'Par' : 'Payé par', m.qui),
            if (m.commentaire.isNotEmpty) ligne(Icons.notes_outlined, 'Note', m.commentaire),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (m.estDepense)
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      final ok = await showOperationSheet(context, modele: m);
                      if (ok == true && context.mounted) financeSnack(context, 'Dépense enregistrée');
                    },
                    icon: const Icon(Icons.replay),
                    label: const Text('Refaire'),
                  ),
                if (admin && m.id.isNotEmpty) ...[
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      showModifierMouvementDialog(context, m);
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Modifier'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      confirmerSuppressionMouvement(context, m);
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Supprimer'),
                  ),
                ],
              ],
            ),
          ],
        ),
      );
    },
  );
}

Future<void> confirmerSuppressionMouvement(BuildContext context, Mouvement m) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Supprimer ce mouvement ?'),
      content: Text('${m.libelle} : ${montantSigne(m.montant, m.entree)}.\nCette action est irréversible.'),
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
  if (ok != true || !context.mounted) return;
  final provider = context.read<FinanceProvider>();
  final done = await provider.supprimerMouvement(m.id);
  if (!context.mounted) return;
  financeSnack(context, done ? 'Mouvement supprimé' : 'Suppression impossible : ${provider.lastError ?? ''}');
}

/// Modification complète d'un mouvement (administrateurs).
Future<void> showModifierMouvementDialog(BuildContext context, Mouvement m) async {
  if (m.id.isEmpty) return;
  final provider = context.read<FinanceProvider>();
  final prenom = TextEditingController(text: m.quiPrenom);
  final nom = TextEditingController(text: m.quiNom);
  final montant = TextEditingController(text: m.montant == 0 ? '' : montantSaisie(m.montant));
  final commentaire = TextEditingController(text: m.commentaire);
  var nature = m.entree ? 'entree' : 'sortie';
  var bandeId = m.bandeId;
  String? categorie = m.categorie.isEmpty ? null : m.categorie;
  String? type = m.type.isEmpty ? null : m.type;
  var date = m.date ?? DateTime.now();
  final bandes = provider.bandes;

  List<DropdownMenuItem<String>> options(Iterable<MapEntry<String, String>> valeurs, String? actuelle) => [
    if (actuelle != null && !valeurs.any((e) => e.key == actuelle))
      DropdownMenuItem(value: actuelle, child: Text(actuelle)),
    for (final e in valeurs)
      DropdownMenuItem(
        value: e.key,
        child: Text(e.value, overflow: TextOverflow.ellipsis),
      ),
  ];

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: const Text('Modifier le mouvement'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'sortie', label: Text('Sortie')),
                    ButtonSegment(value: 'entree', label: Text('Entrée')),
                  ],
                  selected: {nature},
                  onSelectionChanged: (s) => setDialogState(() => nature = s.first),
                ),
                const SizedBox(height: 8),
                NumberField(
                  controller: montant,
                  label: 'Montant',
                  prefixIcon: Icons.payments_outlined,
                  suffixText: 'FCFA',
                ),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Poste', prefixIcon: Icon(Icons.label_outline)),
                  items: options(postesDepense.map((p) => MapEntry(p.valeur, p.libelle)), type),
                  onChanged: (v) => setDialogState(() => type = v),
                ),
                DropdownButtonFormField<String>(
                  initialValue: categorie,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Activité', prefixIcon: Icon(Icons.category_outlined)),
                  items: options(activites.entries, categorie),
                  onChanged: (v) => setDialogState(() => categorie = v),
                ),
                DropdownButtonFormField<String>(
                  initialValue: bandes.any((b) => (b['_id'] ?? b['id'] ?? '').toString() == bandeId) ? bandeId : '',
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Bande', prefixIcon: Icon(Icons.layers_outlined)),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Sans bande')),
                    for (final b in bandes)
                      DropdownMenuItem(
                        value: (b['_id'] ?? b['id'] ?? '').toString(),
                        child: Text((b['nom'] ?? 'Bande').toString(), overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setDialogState(() => bandeId = v ?? ''),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: prenom,
                        decoration: const InputDecoration(labelText: 'Prénom'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: nom,
                        decoration: const InputDecoration(labelText: 'Nom'),
                      ),
                    ),
                  ],
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('Date'),
                  subtitle: Text(formatDateFr(date)),
                  onTap: () async {
                    final picked = await showIsoDatePicker(
                      context: dialogContext,
                      initialDate: date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setDialogState(
                        () => date = DateTime(picked.year, picked.month, picked.day, date.hour, date.minute),
                      );
                    }
                  },
                ),
                TextField(
                  controller: commentaire,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Note', prefixIcon: Icon(Icons.notes_outlined)),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
          AsyncButton(
            label: const Text('Enregistrer'),
            onPressed: () async {
              final valeur = parseAmount(montant.text) ?? 0;
              if (valeur <= 0) {
                financeSnack(context, 'Montant invalide');
                return;
              }
              final ok = await provider.modifierMouvement(m.id, {
                'nature': nature,
                'montant': valeur,
                'categorie': categorie ?? '',
                'type': type ?? '',
                'quiPrenom': prenom.text.trim(),
                'quiNom': nom.text.trim(),
                'date': date.toUtc().toIso8601String(),
                'commentaire': commentaire.text.trim(),
                'bandeId': bandeId,
              });
              // Le dialogue a pu être fermé pendant l'enregistrement : ne pas fermer l'écran dessous.
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (context.mounted) {
                financeSnack(
                  context,
                  ok ? 'Mouvement modifié' : 'Modification impossible : ${provider.lastError ?? ''}',
                );
              }
            },
          ),
        ],
      ),
    ),
  );
}
