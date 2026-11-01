import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/bande.dart';
import '../../models/sante.dart';
import '../../providers/bandes_provider.dart';
import '../../providers/sante_provider.dart';
import '../../services/api_service.dart';
import '../../utils/bande_kpis.dart';
import '../../utils/prophylaxie.dart';
import '../../widgets/empty_state.dart';
import 'a_faire_tab.dart' show prophylaxieSnack;

String _typeLibelle(String type) => type.isEmpty ? 'Tous types de volaille' : typeVolailleLabel(type);

/// Protocoles vaccinaux : cartes avec calendrier, modèles, application à une bande en cours.
class ProtocolesTab extends StatelessWidget {
  const ProtocolesTab({super.key});

  Future<void> _depuisModele(BuildContext context) async {
    final provider = context.read<SanteProvider>();
    final m = await showModalBottomSheet<ModeleProtocole>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text('Partir d’un modèle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Calendriers courants, à adapter avec votre vétérinaire.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ),
            for (final m in modelesProtocoles)
              ListTile(
                leading: const Icon(Icons.vaccines_outlined),
                title: Text(m.nom),
                subtitle: Text('${m.etapes.length} étapes · ${m.etapes.map((e) => 'J${e.jourAge}').join(', ')}'),
                onTap: () => Navigator.pop(ctx, m),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (m == null || !context.mounted) return;
    final ok = await provider.creerProtocole(m.toPayload());
    if (context.mounted) prophylaxieSnack(context, ok ? 'Protocole « ${m.nom} » créé' : 'Erreur : ${provider.lastError ?? ''}');
  }

  @override
  Widget build(BuildContext context) {
    final protocoles = context.watch<SanteProvider>().protocoles;
    return RefreshIndicator(
      onRefresh: context.read<SanteProvider>().charger,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _depuisModele(context),
              icon: const Icon(Icons.auto_awesome_outlined, size: 18),
              label: const Text('Partir d’un modèle'),
            ),
          ),
          const SizedBox(height: 8),
          if (protocoles.isEmpty)
            const EmptyState(
              icon: Icons.vaccines_outlined,
              title: 'Aucun protocole',
              subtitle: 'Un protocole planifie automatiquement les vaccins d’une bande dès sa création.',
            )
          else
            for (final p in protocoles) _ProtocoleCarte(p),
        ],
      ),
    );
  }
}

class _ProtocoleCarte extends StatelessWidget {
  final ProtocoleVaccinal p;
  const _ProtocoleCarte(this.p);

  Future<void> _menu(BuildContext context, String action) async {
    final provider = context.read<SanteProvider>();
    switch (action) {
      case 'appliquer':
        await appliquerProtocole(context, p);
      case 'modifier':
        await showProtocoleForm(context, protocole: p);
      case 'dupliquer':
        final ok = await provider.creerProtocole({
          'nom': '${p.nom} (copie)',
          'typeVolaille': p.typeVolaille,
          'etapes': [for (final e in p.etapes) e.toJson()],
          'notes': p.notes,
        });
        if (context.mounted) prophylaxieSnack(context, ok ? 'Protocole dupliqué' : 'Erreur : ${provider.lastError ?? ''}');
      case 'supprimer':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Supprimer le protocole ?'),
            content: Text('« ${p.nom} » sera supprimé. Les vaccins déjà planifiés sur les bandes restent.'),
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
        if (ok != true || p.id == null || !context.mounted) return;
        final done = await provider.supprimerProtocole(p.id!);
        if (context.mounted) prophylaxieSnack(context, done ? 'Protocole supprimé' : 'Suppression impossible');
    }
  }

  @override
  Widget build(BuildContext context) {
    final etapes = [...p.etapes]..sort((a, b) => a.jourAge.compareTo(b.jourAge));
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.teal.shade700, Colors.teal.shade400])),
            child: Row(
              children: [
                CircleAvatar(backgroundColor: Colors.white.withValues(alpha: 0.25), child: const Icon(Icons.vaccines, color: Colors.white)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.nom,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text(
                        '${_typeLibelle(p.typeVolaille)} · ${etapes.length} étape${etapes.length > 1 ? 's' : ''}'
                        '${etapes.isEmpty ? '' : ' · J${etapes.first.jourAge} à J${etapes.last.jourAge}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.92)),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Options du protocole',
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (v) => _menu(context, v),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'appliquer', child: Text('Appliquer à une bande')),
                    PopupMenuItem(value: 'modifier', child: Text('Modifier')),
                    PopupMenuItem(value: 'dupliquer', child: Text('Dupliquer')),
                    PopupMenuItem(value: 'supprimer', child: Text('Supprimer', style: TextStyle(color: Colors.red))),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: etapes.isEmpty
                ? Text('Aucune étape', style: TextStyle(color: scheme.onSurfaceVariant))
                : Column(
                    children: [
                      for (final e in etapes)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 48,
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('J${e.jourAge}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontWeight: FontWeight.w800, color: Colors.teal.shade700)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(e.intervention, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    Text(
                                      [
                                        if (e.produit.isNotEmpty) e.produit,
                                        if (e.dose.isNotEmpty) e.dose,
                                        if (e.voie.isNotEmpty) e.voie,
                                        if (e.delaiAttenteJours > 0) 'délai ${e.delaiAttenteJours} j',
                                      ].join(' · '),
                                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => appliquerProtocole(context, p),
                icon: const Icon(Icons.playlist_add, size: 18),
                label: const Text('Appliquer à une bande en cours'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Planifie les étapes restantes d'un protocole sur une bande en cours.
Future<void> appliquerProtocole(BuildContext context, ProtocoleVaccinal p) async {
  final bandesProvider = context.read<BandesProvider>();
  final bandes = bandesProvider.bandesActives;
  if (bandes.isEmpty) {
    prophylaxieSnack(context, 'Aucune bande en cours.');
    return;
  }
  final choix = await showModalBottomSheet<Bande>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Appliquer « ${p.nom} »', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final b in bandes)
                  () {
                    final r = etapesAAppliquer(p, b);
                    return ListTile(
                      leading: const Icon(Icons.egg_outlined),
                      title: Text(b.nom),
                      subtitle: Text([
                        typeVolailleLabel(b.typeVolaille),
                        '${r.aCreer.length} à planifier',
                        if (r.ignorees > 0) '${r.ignorees} déjà passée(s)',
                        if (r.dejaPrevues > 0) '${r.dejaPrevues} déjà prévue(s)',
                      ].join(' · ')),
                      enabled: r.aCreer.isNotEmpty,
                      onTap: () => Navigator.pop(ctx, b),
                    );
                  }(),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
  if (choix == null || choix.id == null || !context.mounted) return;
  final r = etapesAAppliquer(p, choix);
  var n = 0;
  for (final ev in r.aCreer) {
    try {
      await ApiService.ajouterEvenementPrevisionnel(choix.id!, ev);
      n++;
    } catch (_) {
      // On continue avec les autres étapes ; le résultat est indiqué à la fin.
    }
  }
  await bandesProvider.chargerBandesActives();
  if (context.mounted) {
    prophylaxieSnack(
      context,
      n == r.aCreer.length ? '$n intervention(s) planifiée(s) pour ${choix.nom}' : '$n sur ${r.aCreer.length} planifiée(s) (erreur réseau ou droits)',
    );
  }
}

/// Création ou modification d'un protocole.
Future<void> showProtocoleForm(BuildContext context, {ProtocoleVaccinal? protocole}) async {
  final edition = protocole != null;
  final provider = context.read<SanteProvider>();
  final nom = TextEditingController(text: protocole?.nom ?? '');
  final notes = TextEditingController(text: protocole?.notes ?? '');
  var type = protocole?.typeVolaille ?? 'poulet_ameliore_45j';
  final etapes = [...?protocole?.etapes]..sort((a, b) => a.jourAge.compareTo(b.jourAge));

  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (dialogContext, setDialog) => AlertDialog(
        title: Text(edition ? 'Modifier le protocole' : 'Nouveau protocole'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(controller: nom, decoration: const InputDecoration(labelText: 'Nom du protocole')),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Type de volaille'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Tous types')),
                    for (final e in typesVolaille.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                    if (type.isNotEmpty && !typesVolaille.containsKey(type)) DropdownMenuItem(value: type, child: Text(type)),
                  ],
                  onChanged: (v) => setDialog(() => type = v ?? type),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(child: Text('Calendrier', style: TextStyle(fontWeight: FontWeight.bold))),
                    TextButton.icon(
                      onPressed: () async {
                        final e = await _etapeDialog(dialogContext);
                        if (e != null) {
                          setDialog(() => etapes
                            ..add(e)
                            ..sort((a, b) => a.jourAge.compareTo(b.jourAge)));
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Étape'),
                    ),
                  ],
                ),
                if (etapes.isEmpty)
                  const Text('Aucune étape : ajoutez les vaccins et traitements par âge.', style: TextStyle(color: Colors.grey)),
                for (var i = 0; i < etapes.length; i++)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Text('J${etapes[i].jourAge}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    title: Text(etapes[i].intervention),
                    subtitle: Text([etapes[i].produit, etapes[i].voie].where((x) => x.isNotEmpty).join(' · ')),
                    onTap: () async {
                      final e = await _etapeDialog(dialogContext, etape: etapes[i]);
                      if (e != null) {
                        setDialog(() => etapes
                          ..[i] = e
                          ..sort((a, b) => a.jourAge.compareTo(b.jourAge)));
                      }
                    },
                    trailing: IconButton(
                      tooltip: 'Retirer l’étape',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setDialog(() => etapes.removeAt(i)),
                    ),
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
              if (nom.text.trim().isEmpty) {
                prophylaxieSnack(context, 'Le nom est obligatoire.');
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
  if (ok != true || !context.mounted) return;
  final payload = {
    'nom': nom.text.trim(),
    'typeVolaille': type,
    'etapes': [for (final e in etapes) e.toJson()],
    'notes': notes.text.trim(),
  };
  final done = edition ? await provider.mettreAJourProtocole(protocole.id!, payload) : await provider.creerProtocole(payload);
  if (context.mounted) prophylaxieSnack(context, done ? 'Protocole enregistré' : 'Erreur : ${provider.lastError ?? ''}');
}

Future<ProtocoleEtape?> _etapeDialog(BuildContext context, {ProtocoleEtape? etape}) {
  final jour = TextEditingController(text: etape == null ? '' : '${etape.jourAge}');
  final intervention = TextEditingController(text: etape?.intervention ?? '');
  final produit = TextEditingController(text: etape?.produit ?? '');
  final dose = TextEditingController(text: etape?.dose ?? '');
  final delai = TextEditingController(text: etape == null || etape.delaiAttenteJours == 0 ? '' : '${etape.delaiAttenteJours}');
  var voie = etape?.voie ?? '';
  return showDialog<ProtocoleEtape>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (c, setDialog) => AlertDialog(
        title: Text(etape == null ? 'Nouvelle étape' : 'Modifier l’étape'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: jour,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Âge des animaux', suffixText: 'jours'),
                ),
                TextField(controller: intervention, decoration: const InputDecoration(labelText: 'Intervention (ex. Vaccin Gumboro)')),
                TextField(controller: produit, decoration: const InputDecoration(labelText: 'Produit / vaccin')),
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
                TextField(
                  controller: delai,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Délai d’attente avant vente', suffixText: 'jours'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              final j = int.tryParse(jour.text.trim());
              if (j == null || j < 0 || intervention.text.trim().isEmpty) {
                prophylaxieSnack(c, 'Indiquez l’âge et l’intervention.');
                return;
              }
              Navigator.pop(
                c,
                ProtocoleEtape(
                  jourAge: j,
                  intervention: intervention.text.trim(),
                  produit: produit.text.trim(),
                  dose: dose.text.trim(),
                  voie: voie,
                  delaiAttenteJours: int.tryParse(delai.text.trim()) ?? 0,
                  notes: etape?.notes ?? '',
                ),
              );
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    ),
  );
}
