import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/client.dart';
import '../../providers/auth_provider.dart';
import '../../providers/fournisseurs_provider.dart';
import '../../utils/contact_launcher.dart';
import '../../widgets/crm/crm_widgets.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_styles.dart';
import '../crm/crm_common.dart';
import 'fournisseur_detail_screen.dart';
import 'fournisseur_form_dialog.dart';

/// Feuille "Fournisseurs" du module Achats.
class FournisseursTab extends StatefulWidget {
  const FournisseursTab({super.key});

  @override
  State<FournisseursTab> createState() => _FournisseursTabState();
}

class _FournisseursTabState extends State<FournisseursTab> {
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<FournisseursProvider>().chargerFournisseurs());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(Client f) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => FournisseurDetailScreen(fournisseur: f)));
  }

  Future<void> _delete(Client f) async {
    if (f.id == null || f.id!.isEmpty) return;
    final ok = await confirmAction(
      context,
      title: 'Supprimer le fournisseur',
      message: 'Supprimer « ${f.nomComplet} » ?',
      confirmLabel: 'Supprimer',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final deleted = await context.read<FournisseursProvider>().supprimerFournisseur(f.id!);
    if (mounted) showCrmSnack(context, deleted ? 'Fournisseur supprimé' : 'Suppression impossible');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FournisseursProvider>();
    final auth = context.watch<AuthProvider>();
    final canUpdate = auth.hasPermission('clients.update');
    final canDelete = auth.hasPermission('clients.delete') || canUpdate;
    final fournisseurs = provider.fournisseurs;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  style: kFilterTextStyle,
                  decoration: filterDecoration(
                    'Rechercher un fournisseur',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: IconButton(
                      tooltip: 'Effacer la recherche',
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _search.clear();
                        context.read<FournisseursProvider>().chargerFournisseurs();
                      },
                    ),
                  ),
                  onChanged: (v) => context.read<FournisseursProvider>().rechercherFournisseurs(v),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Nouveau fournisseur',
                onPressed: () => showFournisseurFormDialog(context),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_business_outlined, size: 18),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          child: Row(
            children: [
              Text('${fournisseurs.length} fournisseur${fournisseurs.length > 1 ? 's' : ''}',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
            ],
          ),
        ),
        Expanded(
          child: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : fournisseurs.isEmpty
                  ? EmptyState(
                      icon: Icons.local_shipping_outlined,
                      title: 'Aucun fournisseur',
                      subtitle: 'Ajoutez vos fournisseurs d’aliment, de poussins, de vaccins...',
                      actionLabel: 'Nouveau fournisseur',
                      onAction: () => showFournisseurFormDialog(context),
                    )
                  : RefreshIndicator(
                      onRefresh: () => context.read<FournisseursProvider>().chargerFournisseurs(),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                        itemCount: fournisseurs.length,
                        itemBuilder: (_, i) => _FournisseurTile(
                          fournisseur: fournisseurs[i],
                          canUpdate: canUpdate,
                          canDelete: canDelete,
                          onOpen: () => _open(fournisseurs[i]),
                          onEdit: () => showFournisseurFormDialog(context, fournisseur: fournisseurs[i]),
                          onDelete: () => _delete(fournisseurs[i]),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}

class _FournisseurTile extends StatelessWidget {
  final Client fournisseur;
  final bool canUpdate;
  final bool canDelete;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FournisseurTile({
    required this.fournisseur,
    required this.canUpdate,
    required this.canDelete,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final f = fournisseur;
    final scheme = Theme.of(context).colorScheme;
    final titre = f.entreprise.isNotEmpty ? f.entreprise : f.nomComplet;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              ClientAvatar(name: titre),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titre, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (f.entreprise.isNotEmpty) f.nomComplet,
                        if (f.commentaireActivite.isNotEmpty) f.commentaireActivite,
                        f.telephone,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Appeler',
                icon: const Icon(Icons.call_outlined, color: Colors.green),
                onPressed: () => contacterEtProposerConsignation(
                  context,
                  contactId: f.id ?? '',
                  telephone: f.telephone,
                  canal: ContactCanal.appel,
                ),
              ),
              IconButton(
                tooltip: 'WhatsApp',
                icon: const Icon(Icons.chat_outlined, color: Colors.teal),
                onPressed: () => contacterEtProposerConsignation(
                  context,
                  contactId: f.id ?? '',
                  telephone: f.telephone,
                  prenom: f.prenom,
                  canal: ContactCanal.whatsapp,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Plus d’actions',
                onSelected: (v) {
                  switch (v) {
                    case 'open':
                      onOpen();
                    case 'email':
                      openContactUri(context, mailUri(f.email), unavailable: 'Aucune adresse email');
                    case 'edit':
                      onEdit();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'open', child: Text('Ouvrir la fiche')),
                  if (f.email.isNotEmpty) const PopupMenuItem(value: 'email', child: Text('Envoyer un email')),
                  if (canUpdate) const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                  if (canDelete) const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
