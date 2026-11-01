import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/client.dart';
import '../../providers/auth_provider.dart';
import '../../providers/clients_provider.dart';
import '../../utils/contact_launcher.dart';
import '../../utils/crm_labels.dart';
import '../../utils/money_format.dart';
import '../../widgets/crm/crm_widgets.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_styles.dart';
import 'client_detail_screen.dart';
import 'client_form_dialog.dart';
import 'crm_common.dart';

/// Vues enregistrées façon HubSpot.
enum ClientsView { tous, prospects, actifs, inactifs, sansContact, topClients }

const _viewLabels = {
  ClientsView.tous: 'Tous',
  ClientsView.prospects: 'Prospects',
  ClientsView.actifs: 'Actifs',
  ClientsView.inactifs: 'Inactifs',
  ClientsView.sansContact: 'Sans contact 30 j',
  ClientsView.topClients: 'Meilleurs clients',
};

const _viewStatut = {
  ClientsView.prospects: 'prospect',
  ClientsView.actifs: 'actif',
  ClientsView.inactifs: 'inactif',
};

/// Applique les vues calculées côté application (les vues par statut sont filtrées par l'API).
List<Client> applyClientsView(List<Client> clients, ClientsView view, {DateTime? now}) {
  final today = now ?? DateTime.now();
  switch (view) {
    case ClientsView.sansContact:
      return clients
          .where((c) => c.statut != 'inactif')
          .where((c) => c.dernierContactLe == null || today.difference(c.dernierContactLe!).inDays >= 30)
          .toList();
    case ClientsView.topClients:
      return ([...clients]..sort((a, b) => b.chiffreAffairesCumul.compareTo(a.chiffreAffairesCumul)))
          .where((c) => c.chiffreAffairesCumul > 0)
          .take(20)
          .toList();
    default:
      return clients;
  }
}

class ClientsTab extends StatefulWidget {
  const ClientsTab({super.key});

  @override
  State<ClientsTab> createState() => _ClientsTabState();
}

class _ClientsTabState extends State<ClientsTab> {
  final TextEditingController _search = TextEditingController();
  ClientsView _view = ClientsView.tous;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final provider = context.read<ClientsProvider>();
    await provider.ensureFiltresRestaures();
    if (!mounted) return;
    _search.text = provider.searchQuery;
    final statut = provider.crmStatutFilter;
    setState(() {
      _view = _viewStatut.entries.firstWhere((e) => e.value == statut, orElse: () => const MapEntry(ClientsView.tous, '')).key;
    });
    await provider.chargerClientsPourCrm();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _selectView(ClientsView view) async {
    setState(() => _view = view);
    await context.read<ClientsProvider>().filtrerClientsCrm(_viewStatut[view]);
  }

  void _openClient(Client c) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClientDetailScreen(client: c)));
  }

  Future<void> _delete(Client c) async {
    final ok = await confirmAction(
      context,
      title: 'Supprimer le client',
      message: 'Supprimer « ${c.nomComplet} » ?',
      confirmLabel: 'Supprimer',
      destructive: true,
    );
    if (!ok || !mounted || c.id == null) return;
    final deleted = await context.read<ClientsProvider>().supprimerClient(c.id!);
    if (mounted) showCrmSnack(context, deleted ? 'Client supprimé' : 'Suppression impossible');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClientsProvider>();
    final auth = context.watch<AuthProvider>();
    final role = (auth.user?['role'] ?? '').toString();
    final canDelete = auth.hasPermission('clients.delete') || role == 'gestionnaire_ferme';
    final clients = applyClientsView(provider.clients.where((c) => c.statut != 'fournisseur').toList(), _view);

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
                    'Rechercher un client',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: IconButton(
                      tooltip: 'Effacer la recherche',
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () async {
                        _search.clear();
                        await context.read<ClientsProvider>().viderRechercheCrm();
                      },
                    ),
                  ),
                  onChanged: (v) => context.read<ClientsProvider>().rechercherClientsCrm(v),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Nouveau client',
                onPressed: () => showClientFormDialog(context),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.person_add_alt_1, size: 18),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              for (final v in ClientsView.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(_viewLabels[v]!),
                    selected: _view == v,
                    onSelected: (_) => _selectView(v),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
          child: Row(
            children: [
              Text('${clients.length} client${clients.length > 1 ? 's' : ''}',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
            ],
          ),
        ),
        Expanded(
          child: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : clients.isEmpty
                  ? EmptyState(
                      icon: Icons.people_outline,
                      title: 'Aucun client dans cette vue',
                      subtitle: 'Ajoutez un client ou changez de vue.',
                      actionLabel: 'Nouveau client',
                      onAction: () => showClientFormDialog(context),
                    )
                  : RefreshIndicator(
                      onRefresh: () => context.read<ClientsProvider>().chargerClientsPourCrm(),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                        itemCount: clients.length,
                        itemBuilder: (_, i) => _ClientTile(
                          client: clients[i],
                          canDelete: canDelete,
                          onOpen: () => _openClient(clients[i]),
                          onEdit: () => showClientFormDialog(context, client: clients[i]),
                          onDelete: () => _delete(clients[i]),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}

class _ClientTile extends StatelessWidget {
  final Client client;
  final bool canDelete;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ClientTile({
    required this.client,
    required this.canDelete,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wide = MediaQuery.of(context).size.width >= 700;
    final dernier = client.dernierContactLe;
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
              ClientAvatar(name: client.nomComplet),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(client.nomComplet,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 6),
                        CrmPill(clientStatut(client.statut), dense: true, showIcon: false),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (client.entreprise.isNotEmpty) client.entreprise,
                        client.telephone,
                        dernier == null ? 'Jamais contacté' : 'Contact : ${relativeDay(dernier).toLowerCase()}',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatCompactFcfa(client.chiffreAffairesCumul), style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('CA cumulé', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
                ],
              ),
              if (wide) ...[
                IconButton(
                  tooltip: 'Appeler',
                  icon: const Icon(Icons.call_outlined, color: Colors.green),
                  onPressed: () => openContactUri(context, telUri(client.telephone), unavailable: 'Numéro indisponible'),
                ),
                IconButton(
                  tooltip: 'WhatsApp',
                  icon: const Icon(Icons.chat_outlined, color: Colors.teal),
                  onPressed: () => openContactUri(context, whatsappUri(client.telephone), unavailable: 'Numéro indisponible'),
                ),
              ],
              PopupMenuButton<String>(
                tooltip: 'Plus d’actions',
                onSelected: (v) {
                  switch (v) {
                    case 'open':
                      onOpen();
                    case 'call':
                      openContactUri(context, telUri(client.telephone), unavailable: 'Numéro indisponible');
                    case 'whatsapp':
                      openContactUri(context, whatsappUri(client.telephone), unavailable: 'Numéro indisponible');
                    case 'edit':
                      onEdit();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'open', child: Text('Ouvrir la fiche')),
                  if (!wide) const PopupMenuItem(value: 'call', child: Text('Appeler')),
                  if (!wide) const PopupMenuItem(value: 'whatsapp', child: Text('WhatsApp')),
                  const PopupMenuItem(value: 'edit', child: Text('Modifier')),
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
