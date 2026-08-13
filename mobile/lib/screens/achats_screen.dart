import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/achat.dart';
import '../providers/achats_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/money_format.dart';
import '../widgets/brand_logo.dart';

class AchatsScreen extends StatefulWidget {
  const AchatsScreen({super.key});

  @override
  State<AchatsScreen> createState() => _AchatsScreenState();
}

class _AchatsScreenState extends State<AchatsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AchatsProvider>().charger();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final canValidate = auth.hasPermission('achats.validate');

    return Scaffold(
      appBar: AppBar(
        leading: const BrandLogo(),
        title: const Text('Demandes d\'achat'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'En attente'),
            Tab(text: 'Validées'),
            Tab(text: 'Reçues'),
            Tab(text: 'Refusées'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<AchatsProvider>().charger(),
          ),
        ],
      ),
      body: Consumer<AchatsProvider>(
        builder: (context, provider, _) {
          if (provider.loading) return const Center(child: CircularProgressIndicator());
          if (provider.error != null) {
            return Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(provider.error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: provider.charger, child: const Text('Réessayer')),
              ],
            ));
          }
          return TabBarView(
            controller: _tabs,
            children: [
              _liste(provider.enAttente, canValidate: canValidate, statut: 'en_attente'),
              _liste(provider.valides, canValidate: canValidate, statut: 'valide'),
              _liste(provider.recus, canValidate: false, statut: 'recu'),
              _liste(provider.refuses, canValidate: false, statut: 'refuse'),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreerDialog,
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Nouvelle demande'),
      ),
    );
  }

  Widget _liste(List<Achat> items, {required bool canValidate, required String statut}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 8),
            Text('Aucune demande ${_statutLabel(statut).toLowerCase()}', style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => context.read<AchatsProvider>().charger(),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        itemBuilder: (context, i) => _achatCard(items[i], canValidate: canValidate),
      ),
    );
  }

  Widget _achatCard(Achat achat, {required bool canValidate}) {
    final df = DateFormat('dd/MM/yyyy');
    final demandeur = '${achat.demandeurPrenom} ${achat.demandeurNom}'.trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(achat.titre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                _urgenceBadge(achat.urgence),
                const SizedBox(width: 6),
                _statutBadge(achat.statut),
              ],
            ),
            const SizedBox(height: 6),
            Text('${achat.article} • ${formatAmount(achat.quantite)} ${achat.unite}',
                style: const TextStyle(fontSize: 13)),
            if (achat.montantEstime > 0)
              Text('Montant estimé : ${formatAmountFcfa(achat.montantEstime)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            if (achat.fournisseur.isNotEmpty)
              Text('Fournisseur : ${achat.fournisseur}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            if (achat.motif.isNotEmpty)
              Text('Motif : ${achat.motif}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.person_outline, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(demandeur.isNotEmpty ? demandeur : '—', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                const Spacer(),
                if (achat.dateDemande != null)
                  Text(df.format(achat.dateDemande!), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
            if (achat.notesValidation.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Note : ${achat.notesValidation}',
                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
            ],
            if (canValidate && achat.statut == 'en_attente') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showValiderDialog(achat),
                      icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                      label: const Text('Valider', style: TextStyle(color: Colors.green)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showRefuserDialog(achat),
                      icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                      label: const Text('Refuser', style: TextStyle(color: Colors.red)),
                    ),
                  ),
                ],
              ),
            ],
            if (canValidate && achat.statut == 'valide') ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showRecevoirDialog(achat),
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Marquer reçu'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _urgenceBadge(String urgence) {
    final colors = {
      'urgente': Colors.red,
      'haute': Colors.orange,
      'normale': Colors.blue,
      'faible': Colors.grey,
    };
    final color = colors[urgence] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(urgence, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _statutBadge(String statut) {
    final configs = {
      'en_attente': (Colors.orange, 'En attente'),
      'valide': (Colors.green, 'Validé'),
      'recu': (Colors.teal, 'Reçu'),
      'refuse': (Colors.red, 'Refusé'),
    };
    final (color, label) = configs[statut] ?? (Colors.grey, statut);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }

  String _statutLabel(String statut) {
    const map = {'en_attente': 'En attente', 'valide': 'Validée', 'recu': 'Reçue', 'refuse': 'Refusée'};
    return map[statut] ?? statut;
  }

  // ─── Dialogs ──────────────────────────────────────────────────────────────

  void _showCreerDialog() {
    final titreCtrl = TextEditingController();
    final articleCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final uniteCtrl = TextEditingController(text: 'kg');
    final fournisseurCtrl = TextEditingController();
    final prixCtrl = TextEditingController();
    final motifCtrl = TextEditingController();
    String categorie = 'aliment';
    String urgence = 'normale';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Nouvelle demande d\'achat'),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titreCtrl, decoration: const InputDecoration(labelText: 'Titre *')),
              const SizedBox(height: 8),
              TextField(controller: articleCtrl, decoration: const InputDecoration(labelText: 'Article *')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    decoration: const InputDecoration(labelText: 'Quantité *'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: uniteCtrl, decoration: const InputDecoration(labelText: 'Unité'))),
              ]),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: categorie,
                decoration: const InputDecoration(labelText: 'Catégorie'),
                items: const [
                  DropdownMenuItem(value: 'aliment', child: Text('Aliment')),
                  DropdownMenuItem(value: 'medicament', child: Text('Médicament')),
                  DropdownMenuItem(value: 'vitamine', child: Text('Vitamine')),
                  DropdownMenuItem(value: 'materiel', child: Text('Matériel')),
                  DropdownMenuItem(value: 'autre', child: Text('Autre')),
                ],
                onChanged: (v) => setLocal(() => categorie = v ?? 'aliment'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: urgence,
                decoration: const InputDecoration(labelText: 'Urgence'),
                items: const [
                  DropdownMenuItem(value: 'faible', child: Text('Faible')),
                  DropdownMenuItem(value: 'normale', child: Text('Normale')),
                  DropdownMenuItem(value: 'haute', child: Text('Haute')),
                  DropdownMenuItem(value: 'urgente', child: Text('Urgente')),
                ],
                onChanged: (v) => setLocal(() => urgence = v ?? 'normale'),
              ),
              const SizedBox(height: 8),
              TextField(controller: fournisseurCtrl, decoration: const InputDecoration(labelText: 'Fournisseur')),
              const SizedBox(height: 8),
              TextField(
                controller: prixCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                decoration: const InputDecoration(labelText: 'Prix unitaire estimé (FCFA)'),
              ),
              const SizedBox(height: 8),
              TextField(controller: motifCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Motif / justification')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                final qty = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 0;
                if (titreCtrl.text.trim().isEmpty || articleCtrl.text.trim().isEmpty || qty <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Titre, article et quantité sont obligatoires')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                final ok = await context.read<AchatsProvider>().creer({
                  'titre': titreCtrl.text.trim(),
                  'article': articleCtrl.text.trim(),
                  'quantite': qty,
                  'unite': uniteCtrl.text.trim().isNotEmpty ? uniteCtrl.text.trim() : 'unité',
                  'categorie': categorie,
                  'urgence': urgence,
                  'fournisseur': fournisseurCtrl.text.trim(),
                  'prixUnitaireEstime': double.tryParse(prixCtrl.text.replaceAll(',', '.')) ?? 0,
                  'motif': motifCtrl.text.trim(),
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ok ? 'Demande créée' : 'Erreur lors de la création')),
                  );
                }
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }

  void _showValiderDialog(Achat achat) {
    final notesCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Valider : ${achat.titre}'),
        content: TextField(controller: notesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Note (optionnel)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await context.read<AchatsProvider>().valider(achat.id!, notes: notesCtrl.text.trim());
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Demande validée' : 'Erreur')));
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  void _showRefuserDialog(Achat achat) {
    final notesCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Refuser : ${achat.titre}'),
        content: TextField(controller: notesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Motif du refus *')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (notesCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le motif du refus est obligatoire')));
                return;
              }
              Navigator.pop(ctx);
              final ok = await context.read<AchatsProvider>().refuser(achat.id!, notes: notesCtrl.text.trim());
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Demande refusée' : 'Erreur')));
            },
            child: const Text('Refuser'),
          ),
        ],
      ),
    );
  }

  void _showRecevoirDialog(Achat achat) {
    final qtyCtrl = TextEditingController(text: formatAmount(achat.quantite).replaceAll('\u00a0', '').replaceAll(',', '.'));
    final prixCtrl = TextEditingController(text: achat.prixUnitaireEstime > 0 ? achat.prixUnitaireEstime.toStringAsFixed(0) : '');
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Réceptionner : ${achat.titre}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              decoration: InputDecoration(labelText: 'Quantité reçue (${achat.unite})'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: prixCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              decoration: const InputDecoration(labelText: 'Prix unitaire réel (FCFA)'),
            ),
            const SizedBox(height: 8),
            TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notes (optionnel)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final qty = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 0;
              if (qty <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quantité invalide')));
                return;
              }
              Navigator.pop(ctx);
              final ok = await context.read<AchatsProvider>().marquerRecu(
                achat.id!,
                quantiteRecue: qty,
                prixReel: double.tryParse(prixCtrl.text.replaceAll(',', '.')) ?? 0,
                notes: notesCtrl.text.trim(),
              );
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Réception enregistrée' : 'Erreur')));
            },
            child: const Text('Confirmer réception'),
          ),
        ],
      ),
    );
  }
}
