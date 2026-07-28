import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/sante.dart';
import '../providers/sante_provider.dart';
import '../widgets/iso_calendar_picker.dart';

class SanteScreen extends StatefulWidget {
  const SanteScreen({super.key});

  @override
  State<SanteScreen> createState() => _SanteScreenState();
}

class _SanteScreenState extends State<SanteScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const List<String> _typesVolaille = [
    'poulet_chair', 'poule_pondeuse', 'dinde', 'canard', 'autre',
  ];
  static const List<String> _typesTraitement = [
    'vaccination', 'traitement', 'prophylaxie', 'vitamines', 'autre',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SanteProvider>().charger();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime? d) => d == null ? '-' : DateFormat('dd/MM/yyyy').format(d);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Santé / Prophylaxie'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.vaccines_outlined), text: 'Protocoles'),
            Tab(icon: Icon(Icons.medical_services_outlined), text: 'Registre'),
          ],
        ),
      ),
      body: Consumer<SanteProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) return const Center(child: CircularProgressIndicator());
          return TabBarView(
            controller: _tabController,
            children: [
              _protocolesTab(provider),
              _registreTab(provider),
            ],
          );
        },
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) => FloatingActionButton.extended(
          onPressed: () => _tabController.index == 0 ? _showProtocoleForm() : _showTraitementForm(),
          icon: const Icon(Icons.add),
          label: Text(_tabController.index == 0 ? 'Protocole' : 'Traitement'),
        ),
      ),
    );
  }

  // -------------------- Protocoles --------------------

  Widget _protocolesTab(SanteProvider provider) {
    return RefreshIndicator(
      onRefresh: provider.charger,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (provider.lastError != null && provider.lastError!.isNotEmpty)
            Card(color: Colors.red.shade50, child: Padding(padding: const EdgeInsets.all(12), child: Text(provider.lastError!, style: const TextStyle(color: Colors.red)))),
          if (provider.protocoles.isEmpty)
            const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: Text('Aucun protocole vaccinal')))
          else
            ...provider.protocoles.map(_protocoleCard),
        ],
      ),
    );
  }

  Widget _protocoleCard(ProtocoleVaccinal p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: const CircleAvatar(child: Icon(Icons.vaccines_outlined)),
        title: Text(p.nom, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${p.typeVolaille.isEmpty ? 'Tous types' : p.typeVolaille} • ${p.etapes.length} étape(s)', maxLines: 1, overflow: TextOverflow.ellipsis),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...p.etapes.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('J${e.jourAge} • ${e.intervention}${e.produit.isNotEmpty ? ' (${e.produit})' : ''}${e.voie.isNotEmpty ? ' - ${e.voie}' : ''}${e.delaiAttenteJours > 0 ? ' • délai ${e.delaiAttenteJours}j' : ''}'),
                    )),
                if (p.notes.isNotEmpty) Text('Notes: ${p.notes}', style: const TextStyle(fontStyle: FontStyle.italic)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(onPressed: () => _showProtocoleForm(protocole: p), icon: const Icon(Icons.edit, size: 18), label: const Text('Modifier')),
                    OutlinedButton.icon(
                      onPressed: () => _confirmDelete('Supprimer le protocole "${p.nom}" ?', () => context.read<SanteProvider>().supprimerProtocole(p.id!)),
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                      label: const Text('Supprimer', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showProtocoleForm({ProtocoleVaccinal? protocole}) {
    final isEdit = protocole != null;
    final nomCtrl = TextEditingController(text: protocole?.nom ?? '');
    final notesCtrl = TextEditingController(text: protocole?.notes ?? '');
    String type = protocole?.typeVolaille.isNotEmpty == true ? protocole!.typeVolaille : 'poulet_chair';
    final etapes = List<ProtocoleEtape>.from(protocole?.etapes ?? const []);

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialog) => AlertDialog(
          title: Text(isEdit ? 'Modifier le protocole' : 'Nouveau protocole'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nomCtrl, decoration: const InputDecoration(labelText: 'Nom du protocole *')),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Type de volaille'),
                  items: _typesVolaille.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setDialog(() => type = v ?? type),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(child: Text('Étapes (calendrier)', style: TextStyle(fontWeight: FontWeight.bold))),
                    TextButton.icon(
                      onPressed: () async {
                        final etape = await _showEtapeDialog(dialogContext);
                        if (etape != null) setDialog(() => etapes.add(etape));
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter'),
                    ),
                  ],
                ),
                if (etapes.isEmpty)
                  const Align(alignment: Alignment.centerLeft, child: Text('Aucune étape', style: TextStyle(color: Colors.grey)))
                else
                  ...etapes.asMap().entries.map((entry) {
                    final i = entry.key;
                    final e = entry.value;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('J${e.jourAge} • ${e.intervention}'),
                      subtitle: Text('${e.produit}${e.voie.isNotEmpty ? ' - ${e.voie}' : ''}${e.delaiAttenteJours > 0 ? ' • délai ${e.delaiAttenteJours}j' : ''}'),
                      trailing: IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setDialog(() => etapes.removeAt(i))),
                    );
                  }),
                TextField(controller: notesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(dialogContext);
                final provider = context.read<SanteProvider>();
                if (nomCtrl.text.trim().isEmpty) {
                  messenger.showSnackBar(const SnackBar(content: Text('Le nom est obligatoire')));
                  return;
                }
                final payload = {
                  'nom': nomCtrl.text.trim(),
                  'typeVolaille': type,
                  'etapes': etapes.map((e) => e.toJson()).toList(),
                  'notes': notesCtrl.text.trim(),
                };
                final ok = isEdit
                    ? await provider.mettreAJourProtocole(protocole.id!, payload)
                    : await provider.creerProtocole(payload);
                if (!mounted) return;
                navigator.pop();
                messenger.showSnackBar(SnackBar(content: Text(ok ? 'Protocole enregistré' : 'Erreur: ${provider.lastError ?? ''}')));
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<ProtocoleEtape?> _showEtapeDialog(BuildContext ctx) {
    final jourCtrl = TextEditingController();
    final interventionCtrl = TextEditingController();
    final produitCtrl = TextEditingController();
    final doseCtrl = TextEditingController();
    final voieCtrl = TextEditingController();
    final delaiCtrl = TextEditingController();
    return showDialog<ProtocoleEtape>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('Étape du protocole'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: jourCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Âge (jours) *')),
              TextField(controller: interventionCtrl, decoration: const InputDecoration(labelText: 'Intervention *')),
              TextField(controller: produitCtrl, decoration: const InputDecoration(labelText: 'Produit / vaccin')),
              TextField(controller: doseCtrl, decoration: const InputDecoration(labelText: 'Dose')),
              TextField(controller: voieCtrl, decoration: const InputDecoration(labelText: 'Voie (eau, spray, injection...)')),
              TextField(controller: delaiCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Délai d\'attente (jours)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              if (interventionCtrl.text.trim().isEmpty) return;
              Navigator.pop(
                c,
                ProtocoleEtape(
                  jourAge: int.tryParse(jourCtrl.text.trim()) ?? 0,
                  intervention: interventionCtrl.text.trim(),
                  produit: produitCtrl.text.trim(),
                  dose: doseCtrl.text.trim(),
                  voie: voieCtrl.text.trim(),
                  delaiAttenteJours: int.tryParse(delaiCtrl.text.trim()) ?? 0,
                ),
              );
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  // -------------------- Registre traitements --------------------

  Widget _registreTab(SanteProvider provider) {
    return RefreshIndicator(
      onRefresh: provider.charger,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (provider.traitements.isEmpty)
            const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: Text('Aucun traitement enregistré')))
          else
            ...provider.traitements.map(_traitementCard),
        ],
      ),
    );
  }

  Widget _traitementCard(TraitementSanitaire t) {
    Color? color;
    String badge = '';
    if (t.statutDelai == 'en_cours') {
      color = Colors.orange.shade50;
      badge = 'Délai en cours → ${_fmtDate(t.dateFinDelaiAttente)}';
    } else if (t.statutDelai == 'termine' && t.delaiAttenteJours > 0) {
      color = Colors.green.shade50;
      badge = 'Délai respecté';
    }
    return Card(
      color: color,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: t.statutDelai == 'en_cours' ? Colors.orange.shade100 : Colors.green.shade100,
          child: Icon(Icons.medical_services_outlined, color: t.statutDelai == 'en_cours' ? Colors.orange : Colors.green.shade700),
        ),
        title: Text('${t.type} • ${t.produit}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${_fmtDate(t.dateTraitement)}${t.dose.isNotEmpty ? ' • ${t.dose}' : ''}${t.motif.isNotEmpty ? ' • ${t.motif}' : ''}${badge.isNotEmpty ? '\n$badge' : ''}',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: badge.isNotEmpty,
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') _showTraitementForm(traitement: t);
            if (v == 'delete') _confirmDelete('Supprimer ce traitement ?', () => context.read<SanteProvider>().supprimerTraitement(t.id!));
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Modifier')),
            PopupMenuItem(value: 'delete', child: Text('Supprimer')),
          ],
        ),
      ),
    );
  }

  void _showTraitementForm({TraitementSanitaire? traitement}) {
    final isEdit = traitement != null;
    final produitCtrl = TextEditingController(text: traitement?.produit ?? '');
    final doseCtrl = TextEditingController(text: traitement?.dose ?? '');
    final voieCtrl = TextEditingController(text: traitement?.voie ?? '');
    final motifCtrl = TextEditingController(text: traitement?.motif ?? '');
    final delaiCtrl = TextEditingController(text: isEdit ? traitement.delaiAttenteJours.toString() : '');
    final notesCtrl = TextEditingController(text: traitement?.notes ?? '');
    DateTime date = traitement?.dateTraitement ?? DateTime.now();
    String type = traitement?.type ?? 'vaccination';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialog) => AlertDialog(
          title: Text(isEdit ? 'Modifier le traitement' : 'Nouveau traitement'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _typesTraitement.contains(type) ? type : 'traitement',
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: _typesTraitement.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setDialog(() => type = v ?? type),
                ),
                TextField(controller: produitCtrl, decoration: const InputDecoration(labelText: 'Produit / vaccin *')),
                TextField(controller: doseCtrl, decoration: const InputDecoration(labelText: 'Dose')),
                TextField(controller: voieCtrl, decoration: const InputDecoration(labelText: 'Voie')),
                TextField(controller: motifCtrl, decoration: const InputDecoration(labelText: 'Motif')),
                TextField(
                  controller: delaiCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Délai d\'attente (jours)', helperText: 'Avant abattage / consommation'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date du traitement'),
                  subtitle: Text(_fmtDate(date)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showIsoDatePicker(context: dialogContext, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (picked != null) setDialog(() => date = picked);
                  },
                ),
                TextField(controller: notesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(dialogContext);
                final provider = context.read<SanteProvider>();
                if (produitCtrl.text.trim().isEmpty) {
                  messenger.showSnackBar(const SnackBar(content: Text('Le produit est obligatoire')));
                  return;
                }
                final payload = {
                  'type': type,
                  'produit': produitCtrl.text.trim(),
                  'dose': doseCtrl.text.trim(),
                  'voie': voieCtrl.text.trim(),
                  'motif': motifCtrl.text.trim(),
                  'delaiAttenteJours': int.tryParse(delaiCtrl.text.trim()) ?? 0,
                  'dateTraitement': date.toIso8601String(),
                  'notes': notesCtrl.text.trim(),
                };
                final ok = isEdit
                    ? await provider.mettreAJourTraitement(traitement.id!, payload)
                    : await provider.creerTraitement(payload);
                if (!mounted) return;
                navigator.pop();
                messenger.showSnackBar(SnackBar(content: Text(ok ? 'Traitement enregistré' : 'Erreur: ${provider.lastError ?? ''}')));
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String message, Future<bool> Function() action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmation'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final done = await action();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done ? 'Supprimé' : 'Suppression impossible')));
  }
}
