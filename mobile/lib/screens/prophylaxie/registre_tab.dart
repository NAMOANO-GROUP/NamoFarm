import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/sante.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bandes_provider.dart';
import '../../providers/sante_provider.dart';
import '../../utils/crm_labels.dart';
import '../../utils/prophylaxie.dart';
import '../../widgets/crm/crm_widgets.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/iso_calendar_picker.dart';
import 'a_faire_tab.dart' show prophylaxieSnack;

/// Registre des traitements : produit, bande, dose, voie et délai d'attente avant vente.
class RegistreTab extends StatelessWidget {
  const RegistreTab({super.key});

  @override
  Widget build(BuildContext context) {
    final traitements = context.watch<SanteProvider>().traitements;
    final bandes = context.watch<BandesProvider>().bandesActives;
    bool peutSupprimer = false;
    try {
      final auth = context.watch<AuthProvider>();
      peutSupprimer = auth.hasPermission('sante.delete');
    } on ProviderNotFoundException {
      peutSupprimer = false;
    }
    String nomBande(String? id) {
      for (final b in bandes) {
        if (b.id == id) return b.nom;
      }
      return '';
    }

    final parMois = <DateTime, List<TraitementSanitaire>>{};
    for (final t in traitements) {
      final d = t.dateTraitement?.toLocal() ?? DateTime(1970);
      parMois.putIfAbsent(DateTime(d.year, d.month), () => []).add(t);
    }
    final mois = parMois.keys.toList()..sort((a, b) => b.compareTo(a));

    return RefreshIndicator(
      onRefresh: context.read<SanteProvider>().charger,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          if (traitements.isEmpty)
            const EmptyState(
              icon: Icons.menu_book_outlined,
              title: 'Registre vide',
              subtitle: 'Notez chaque traitement (produit, dose, délai d’attente) avec le bouton « + » en haut.',
            ),
          for (final m in mois) ...[
            CrmSectionHeader(m.year == 1970 ? 'Sans date' : _moisLibelle(m), icon: Icons.calendar_month_outlined),
            CrmCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < parMois[m]!.length; i++) ...[
                    if (i > 0) const Divider(height: 1, indent: 64),
                    _Ligne(t: parMois[m]![i], bande: nomBande(parMois[m]![i].bandeId), peutSupprimer: peutSupprimer),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

const _moisFr = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];

String _moisLibelle(DateTime m) {
  final n = _moisFr[m.month - 1];
  return '${n[0].toUpperCase()}${n.substring(1)} ${m.year}';
}

class _Ligne extends StatelessWidget {
  final TraitementSanitaire t;
  final String bande;
  final bool peutSupprimer;

  const _Ligne({required this.t, required this.bande, required this.peutSupprimer});

  Future<void> _supprimer(BuildContext context) async {
    final provider = context.read<SanteProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce traitement ?'),
        content: Text('${t.produit} sera retiré du registre.'),
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
    if (ok != true || t.id == null || !context.mounted) return;
    final done = await provider.supprimerTraitement(t.id!);
    if (context.mounted) prophylaxieSnack(context, done ? 'Traitement supprimé' : 'Suppression impossible');
  }

  @override
  Widget build(BuildContext context) {
    final (libelle, icon, couleur) = typeTraitement(t.type);
    final delai = delaiAttente(t);
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: () => showTraitementForm(context, traitement: t),
      leading: CircleAvatar(backgroundColor: couleur.withValues(alpha: 0.14), child: Icon(icon, color: couleur, size: 20)),
      title: Text(t.produit, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              libelle,
              if (bande.isNotEmpty) bande,
              if (t.dateTraitement != null) formatDateFr(t.dateTraitement!.toLocal()),
              if (t.dose.isNotEmpty) t.dose,
              if (t.voie.isNotEmpty) t.voie,
              if (t.motif.isNotEmpty) t.motif,
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (delai != null)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (delai.enCours ? Colors.orange : Colors.green).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                delai.enCours
                    ? 'Délai d’attente : vente possible le ${formatDateFr(delai.fin)} (encore ${delai.joursRestants} j)'
                    : 'Délai d’attente terminé',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: delai.enCours ? Colors.orange.shade800 : Colors.green.shade700,
                ),
              ),
            ),
        ],
      ),
      isThreeLine: delai != null,
      trailing: peutSupprimer
          ? IconButton(
              tooltip: 'Supprimer',
              icon: Icon(Icons.delete_outline, color: scheme.onSurfaceVariant),
              onPressed: () => _supprimer(context),
            )
          : null,
    );
  }
}

/// Saisie ou modification d'un traitement du registre.
Future<void> showTraitementForm(BuildContext context, {TraitementSanitaire? traitement}) async {
  final edition = traitement != null;
  final provider = context.read<SanteProvider>();
  final bandes = context.read<BandesProvider>().bandesActives;
  final produit = TextEditingController(text: traitement?.produit ?? '');
  final dose = TextEditingController(text: traitement?.dose ?? '');
  final motif = TextEditingController(text: traitement?.motif ?? '');
  final delai = TextEditingController(text: (traitement?.delaiAttenteJours ?? 0) == 0 ? '' : '${traitement!.delaiAttenteJours}');
  var type = traitement?.type ?? 'traitement';
  var voie = traitement?.voie ?? '';
  var bandeId = traitement?.bandeId ?? (bandes.length == 1 ? bandes.first.id ?? '' : '');
  var date = traitement?.dateTraitement?.toLocal() ?? DateTime.now();

  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (dialogContext, setDialog) {
        final j = int.tryParse(delai.text.trim()) ?? 0;
        final fin = DateTime(date.year, date.month, date.day + j);
        return AlertDialog(
          title: Text(edition ? 'Modifier le traitement' : 'Nouveau traitement'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final e in typesTraitement.entries)
                        ChoiceChip(
                          avatar: Icon(e.value.$2, size: 16, color: e.value.$3),
                          label: Text(e.value.$1),
                          selected: type == e.key,
                          onSelected: (_) => setDialog(() => type = e.key),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: bandeId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Bande traitée', prefixIcon: Icon(Icons.egg_outlined)),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Aucune bande en particulier')),
                      for (final b in bandes)
                        if (b.id != null) DropdownMenuItem(value: b.id!, child: Text(b.nom, overflow: TextOverflow.ellipsis)),
                      // Bande déjà fermée : conservée telle quelle à la modification.
                      if (bandeId.isNotEmpty && !bandes.any((b) => b.id == bandeId))
                        DropdownMenuItem(value: bandeId, child: const Text('Bande terminée')),
                    ],
                    onChanged: (v) => setDialog(() => bandeId = v ?? ''),
                  ),
                  TextField(
                    controller: produit,
                    decoration: const InputDecoration(labelText: 'Produit', prefixIcon: Icon(Icons.medication_outlined)),
                  ),
                  TextField(controller: dose, decoration: const InputDecoration(labelText: 'Dose')),
                  DropdownButtonFormField<String>(
                    initialValue: voie.isEmpty ? null : voie,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Voie d’administration'),
                    items: [
                      for (final v in voiesAdministration) DropdownMenuItem(value: v, child: Text(v)),
                      if (voie.isNotEmpty && !voiesAdministration.contains(voie)) DropdownMenuItem(value: voie, child: Text(voie)),
                    ],
                    onChanged: (v) => setDialog(() => voie = v ?? ''),
                  ),
                  TextField(controller: motif, decoration: const InputDecoration(labelText: 'Motif (symptômes, prévention...)')),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('Date du traitement'),
                    subtitle: Text(formatDateLongFr(date)),
                    onTap: () async {
                      final picked = await showIsoDatePicker(
                        context: dialogContext,
                        initialDate: date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setDialog(() => date = picked);
                    },
                  ),
                  TextField(
                    controller: delai,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setDialog(() {}),
                    decoration: InputDecoration(
                      labelText: 'Délai d’attente avant vente',
                      suffixText: 'jours',
                      helperText: j > 0 ? 'Vente possible à partir du ${formatDateFr(fin)}' : 'Voir la notice du produit',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
            FilledButton(
              onPressed: () {
                if (produit.text.trim().isEmpty) {
                  prophylaxieSnack(context, 'Indiquez le produit.');
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
  final payload = {
    'bandeId': bandeId.isEmpty ? null : bandeId,
    'dateTraitement': DateTime(date.year, date.month, date.day, 12).toIso8601String(),
    'type': type,
    'produit': produit.text.trim(),
    'dose': dose.text.trim(),
    'voie': voie,
    'motif': motif.text.trim(),
    'delaiAttenteJours': int.tryParse(delai.text.trim()) ?? 0,
  };
  final done = edition ? await provider.mettreAJourTraitement(traitement.id!, payload) : await provider.creerTraitement(payload);
  if (context.mounted) prophylaxieSnack(context, done ? 'Traitement enregistré' : 'Erreur : ${provider.lastError ?? ''}');
}
