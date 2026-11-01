import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/client.dart';
import '../../models/commande.dart';
import '../../models/crm_pipeline.dart';
import '../../models/interaction.dart';
import '../../models/tache_crm.dart';
import '../../providers/clients_provider.dart';
import '../../providers/crm_provider.dart';
import '../../services/api_service.dart';
import '../../utils/contact_launcher.dart';
import '../../utils/crm_labels.dart';
import '../../utils/money_format.dart';
import '../../widgets/crm/crm_widgets.dart';
import '../../widgets/crm/tache_card.dart';
import 'client_form_dialog.dart';
import 'crm_common.dart';
import 'deal_dialog.dart';
import 'interaction_dialog.dart';
import 'tache_dialog.dart';

/// Fiche client à la manière de HubSpot : en-tête, actions rapides,
/// fil d'activité unifié et éléments associés (affaire, relances, commandes).
class ClientDetailScreen extends StatefulWidget {
  final Client client;
  const ClientDetailScreen({super.key, required this.client});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

enum _Section { activite, relances, commandes, infos }

enum _Filtre { tout, echanges, commandes, taches, pipeline }

class _TimelineEntry {
  final DateTime date;
  final _Filtre kind;
  final IconData icon;
  final MaterialColor color;
  final String title;
  final String? body;
  final String? meta;

  const _TimelineEntry({
    required this.date,
    required this.kind,
    required this.icon,
    required this.color,
    required this.title,
    this.body,
    this.meta,
  });
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  List<Commande> _commandes = [];
  bool _commandesLoading = true;
  _Section _section = _Section.activite;
  _Filtre _filtre = _Filtre.tout;

  String get _clientId => widget.client.id ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  Future<void> _charger() async {
    final crm = context.read<CrmProvider>();
    await Future.wait([
      crm.chargerInteractionsClient(_clientId),
      if (crm.taches.isEmpty) crm.chargerTachesCrm(),
      if (crm.deals.isEmpty) crm.chargerPipelineCommercial(),
      _chargerCommandes(),
    ]);
  }

  Future<void> _chargerCommandes() async {
    try {
      final data = await ApiService.getCommandes();
      final list = data
          .whereType<Map>()
          .map((e) => Commande.fromJson(Map<String, dynamic>.from(e)))
          .where((c) => c.clientId == _clientId)
          .toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
      if (mounted) setState(() => _commandes = list);
    } catch (_) {
      // Les commandes sont un complément de la fiche : on affiche le reste même en cas d'erreur.
    } finally {
      if (mounted) setState(() => _commandesLoading = false);
    }
  }

  Client _client(ClientsProvider provider) {
    for (final c in provider.clients) {
      if (c.id == _clientId) return c;
    }
    return widget.client;
  }

  Future<void> _contact(Client client, String canal) async {
    switch (canal) {
      case 'appel':
        final ok = await openContactUri(context, telUri(client.telephone), unavailable: 'Numéro de téléphone indisponible');
        if (ok && mounted) _proposerConsignation('appel', 'Appel');
      case 'whatsapp':
        final ok = await openContactUri(
          context,
          whatsappUri(client.telephone, message: 'Bonjour ${client.prenom}, '),
          unavailable: 'Numéro WhatsApp indisponible',
        );
        if (ok && mounted) _proposerConsignation('whatsapp', 'Message WhatsApp');
      case 'email':
        await openContactUri(context, mailUri(client.email), unavailable: 'Aucune adresse email');
    }
  }

  void _proposerConsignation(String type, String sujet) {
    showCrmSnack(
      context,
      'Pensez à consigner cet échange',
      action: SnackBarAction(
        label: 'Consigner',
        onPressed: () => showInteractionDialog(context, clientId: _clientId, type: type, sujet: sujet),
      ),
    );
  }

  Future<void> _supprimer(Client client) async {
    final ok = await confirmAction(
      context,
      title: 'Supprimer le client',
      message: 'Supprimer « ${client.nomComplet} » ? Son historique ne sera plus accessible.',
      confirmLabel: 'Supprimer',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final deleted = await context.read<ClientsProvider>().supprimerClient(_clientId);
    if (!mounted) return;
    if (deleted) {
      Navigator.pop(context);
    } else {
      showCrmSnack(context, 'Suppression impossible');
    }
  }

  List<_TimelineEntry> _timeline(List<Interaction> interactions, List<TacheCRM> taches) {
    final entries = <_TimelineEntry>[];
    for (final i in interactions) {
      final opt = interactionType(i.type);
      if (i.isPipelineUpdate) {
        final meta = i.pipelineMeta ?? const {};
        final stage = pipelineStage((meta['stage'] ?? '').toString());
        final montant = (meta['montant'] is num) ? (meta['montant'] as num).toDouble() : 0.0;
        final note = (meta['note'] ?? '').toString();
        entries.add(_TimelineEntry(
          date: i.dateInteraction,
          kind: _Filtre.pipeline,
          icon: stage.icon,
          color: stage.color,
          title: 'Affaire passée à « ${stage.label} »',
          body: [if (montant > 0) formatAmountFcfa(montant), if (note.isNotEmpty) note].join(' · '),
          meta: i.auteur,
        ));
        continue;
      }
      entries.add(_TimelineEntry(
        date: i.dateInteraction,
        kind: _Filtre.echanges,
        icon: opt.icon,
        color: opt.color,
        title: i.sujet.isEmpty ? opt.label : '${opt.label} · ${i.sujet}',
        body: i.contenu,
        meta: i.auteur,
      ));
    }
    for (final c in _commandes) {
      entries.add(_TimelineEntry(
        date: c.createdAt ?? DateTime.now(),
        kind: _Filtre.commandes,
        icon: Icons.shopping_bag_outlined,
        color: Colors.indigo,
        title: 'Commande de ${formatAmountFcfa(c.montantTotal)}',
        body: [
          c.produits.map((p) => '${p.quantite} × ${p.nom}').join(', '),
          'Statut : ${c.statut.replaceAll('_', ' ')}',
        ].where((s) => s.isNotEmpty).join('\n'),
      ));
    }
    for (final t in taches.where((t) => !isTacheOuverte(t.statut))) {
      entries.add(_TimelineEntry(
        date: t.dateEcheance,
        kind: _Filtre.taches,
        icon: t.statut == 'terminee' ? Icons.task_alt : Icons.block,
        color: t.statut == 'terminee' ? Colors.green : Colors.grey,
        title: '${tacheStatut(t.statut).label} · ${t.titre}',
        body: t.description.isEmpty ? null : t.description,
        meta: t.assigneA.isEmpty ? null : t.assigneA,
      ));
    }
    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final client = _client(context.watch<ClientsProvider>());
    final crm = context.watch<CrmProvider>();
    final deal = crm.dealPourClient(_clientId);
    final taches = crm.tachesPourClient(_clientId);
    final interactions = crm.interactionsClientId == _clientId ? crm.interactions : const <Interaction>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(client.nomComplet, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Modifier le client',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showClientFormDialog(context, client: client),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'delete') _supprimer(client);
            },
            itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Supprimer le client'))],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _charger,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final header = [
              _Header(client: client, deal: deal, commandesCount: _commandes.length),
              _QuickActions(
                onCall: () => _contact(client, 'appel'),
                onWhatsapp: () => _contact(client, 'whatsapp'),
                onEmail: client.email.isEmpty ? null : () => _contact(client, 'email'),
                onNote: () => showInteractionDialog(context, clientId: _clientId),
                onTask: () => showTacheDialog(context, clientId: _clientId),
              ),
            ];
            final timeline = _timelineSection(interactions, taches, crm.interactionsLoading);
            final relances = _relancesSection(taches);
            final commandes = _commandesSection();
            final infos = [if (deal != null) _DealCard(deal: deal), _InfosCard(client: client)];

            if (constraints.maxWidth >= 1000) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 340,
                    child: ListView(padding: const EdgeInsets.all(12), children: [...header, ...infos]),
                  ),
                  Expanded(child: ListView(padding: const EdgeInsets.all(12), children: timeline)),
                  SizedBox(
                    width: 340,
                    child: ListView(padding: const EdgeInsets.all(12), children: [...relances, ...commandes]),
                  ),
                ],
              );
            }

            final content = switch (_section) {
              _Section.activite => timeline,
              _Section.relances => relances,
              _Section.commandes => commandes,
              _Section.infos => infos,
            };
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                ...header,
                const SizedBox(height: 4),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<_Section>(
                    showSelectedIcon: false,
                    segments: [
                      const ButtonSegment(value: _Section.activite, icon: Icon(Icons.timeline), label: Text('Activité')),
                      ButtonSegment(
                        value: _Section.relances,
                        icon: const Icon(Icons.task_alt),
                        label: Text('Relances (${taches.where((t) => isTacheOuverte(t.statut)).length})'),
                      ),
                      ButtonSegment(
                        value: _Section.commandes,
                        icon: const Icon(Icons.shopping_bag_outlined),
                        label: Text('Commandes (${_commandes.length})'),
                      ),
                      const ButtonSegment(value: _Section.infos, icon: Icon(Icons.info_outline), label: Text('Infos')),
                    ],
                    selected: {_section},
                    onSelectionChanged: (v) => setState(() => _section = v.first),
                  ),
                ),
                const SizedBox(height: 12),
                ...content,
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _timelineSection(List<Interaction> interactions, List<TacheCRM> taches, bool loading) {
    final all = _timeline(interactions, taches);
    final entries = _filtre == _Filtre.tout ? all : all.where((e) => e.kind == _filtre).toList();
    const labels = {
      _Filtre.tout: 'Tout',
      _Filtre.echanges: 'Échanges',
      _Filtre.commandes: 'Commandes',
      _Filtre.taches: 'Tâches',
      _Filtre.pipeline: 'Affaire',
    };

    final widgets = <Widget>[
      CrmSectionHeader(
        "Fil d'activité",
        icon: Icons.timeline,
        trailing: TextButton.icon(
          onPressed: () => showInteractionDialog(context, clientId: _clientId),
          icon: const Icon(Icons.add_comment_outlined, size: 18),
          label: const Text('Consigner'),
        ),
      ),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final f in _Filtre.values)
            FilterChip(
              label: Text(labels[f]!),
              selected: _filtre == f,
              onSelected: (_) => setState(() => _filtre = f),
            ),
        ],
      ),
      const SizedBox(height: 12),
    ];

    if (loading && entries.isEmpty) {
      widgets.add(const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())));
      return widgets;
    }
    if (entries.isEmpty) {
      widgets.add(const CrmCard(
        child: Column(
          children: [
            Icon(Icons.forum_outlined, size: 40, color: Colors.grey),
            SizedBox(height: 8),
            Text('Aucune activité pour le moment', style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            Text('Consignez un appel, une visite ou une note pour démarrer l’historique.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          ],
        ),
      ));
      return widgets;
    }

    String? currentDay;
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      final day = timelineDayLabel(e.date);
      if (day != currentDay) {
        currentDay = day;
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6, left: 4),
          child: Text(day, style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary)),
        ));
      }
      final last = i == entries.length - 1 || timelineDayLabel(entries[i + 1].date) != day;
      widgets.add(_TimelineTile(entry: e, isLast: last));
    }
    return widgets;
  }

  List<Widget> _relancesSection(List<TacheCRM> taches) {
    final ouvertes = taches.where((t) => isTacheOuverte(t.statut)).toList()
      ..sort((a, b) => a.dateEcheance.compareTo(b.dateEcheance));
    return [
      CrmSectionHeader(
        'Relances ouvertes',
        icon: Icons.task_alt,
        trailing: IconButton(
          tooltip: 'Nouvelle tâche',
          icon: const Icon(Icons.add_task),
          onPressed: () => showTacheDialog(context, clientId: _clientId),
        ),
      ),
      if (ouvertes.isEmpty)
        const CrmCard(child: Text('Aucune relance prévue.', style: TextStyle(color: Colors.grey)))
      else
        for (final t in ouvertes)
          TacheCard(
            tache: t,
            showClient: false,
            onToggleDone: t.id == null ? null : () => toggleTacheWithUndo(context, t),
            onTap: t.id == null ? null : () => showTacheDialog(context, tache: t),
            onDelete: t.id == null ? null : () => deleteTacheWithConfirm(context, t),
          ),
    ];
  }

  List<Widget> _commandesSection() {
    final total = _commandes.where((c) => c.statut != 'annulee').fold<double>(0, (s, c) => s + c.montantTotal);
    return [
      CrmSectionHeader('Commandes', icon: Icons.shopping_bag_outlined,
          trailing: _commandes.isEmpty ? null : Text(formatCompactFcfa(total), style: const TextStyle(fontWeight: FontWeight.w700))),
      if (_commandesLoading)
        const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
      else if (_commandes.isEmpty)
        const CrmCard(child: Text('Aucune commande pour ce client.', style: TextStyle(color: Colors.grey)))
      else
        CrmCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final c in _commandes.take(20))
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text(formatAmountFcfa(c.montantTotal), style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    [if (c.createdAt != null) formatDateFr(c.createdAt!), c.produits.map((p) => p.nom).join(', ')]
                        .where((s) => s.isNotEmpty)
                        .join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: _CommandeStatut(c.statut),
                ),
            ],
          ),
        ),
    ];
  }
}

class _Header extends StatelessWidget {
  final Client client;
  final PipelineDeal? deal;
  final int commandesCount;

  const _Header({required this.client, required this.deal, required this.commandesCount});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dernier = deal?.dernierContact ?? client.dernierContactLe;
    return CrmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClientAvatar(name: client.nomComplet, radius: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(client.nomComplet, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    if (client.entreprise.isNotEmpty)
                      Text(client.entreprise, style: TextStyle(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        CrmPill(clientStatut(client.statut), dense: true),
                        CrmPill(clientType(client.typeClient), dense: true),
                        if (deal != null) CrmPill(pipelineStage(deal!.stage), dense: true),
                      ],
                    ),
                  ],
                ),
              ),
              if (deal != null) _ScoreBadge(score: deal!.score),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              _Stat(label: 'CA cumulé', value: formatCompactFcfa(client.chiffreAffairesCumul)),
              _Stat(label: 'Commandes', value: '$commandesCount'),
              _Stat(label: 'Dernier contact', value: dernier == null ? 'Jamais' : relativeDay(dernier)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final double score;
  const _ScoreBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = scoreColor(score);
    return Tooltip(
      message: 'Score calculé : engagement, commandes, chiffre d’affaires et récence',
      child: SizedBox(
        width: 54,
        height: 54,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 5,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
            Text(score.round().toString(), style: TextStyle(fontWeight: FontWeight.w800, color: color.shade700)),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final VoidCallback onCall;
  final VoidCallback onWhatsapp;
  final VoidCallback? onEmail;
  final VoidCallback onNote;
  final VoidCallback onTask;

  const _QuickActions({
    required this.onCall,
    required this.onWhatsapp,
    required this.onEmail,
    required this.onNote,
    required this.onTask,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          for (final a in [
            _QuickAction(icon: Icons.call, label: 'Appeler', color: Colors.green, onTap: onCall),
            _QuickAction(icon: Icons.chat, label: 'WhatsApp', color: Colors.teal, onTap: onWhatsapp),
            _QuickAction(icon: Icons.mail_outline, label: 'Email', color: Colors.blue, onTap: onEmail),
            _QuickAction(icon: Icons.sticky_note_2_outlined, label: 'Note', color: Colors.amber, onTap: onNote),
            _QuickAction(icon: Icons.add_task, label: 'Tâche', color: Colors.indigo, onTap: onTask),
          ])
            Expanded(child: a),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final MaterialColor color;
  final VoidCallback? onTap;

  const _QuickAction({required this.icon, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: enabled ? (isDark ? color.shade800 : color.shade50) : Colors.grey.withValues(alpha: 0.15),
                child: Icon(icon, color: enabled ? (isDark ? color.shade100 : color.shade700) : Colors.grey),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label, style: TextStyle(fontSize: 11, color: enabled ? null : Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final _TimelineEntry entry;
  final bool isLast;

  const _TimelineTile({required this.entry, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: isDark ? entry.color.shade800 : entry.color.shade50,
                  child: Icon(entry.icon, size: 16, color: isDark ? entry.color.shade100 : entry.color.shade700),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2, color: scheme.outlineVariant.withValues(alpha: 0.6))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(entry.title, style: const TextStyle(fontWeight: FontWeight.w600))),
                      Text(formatHeure(entry.date), style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                  if ((entry.body ?? '').isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(entry.body!, style: TextStyle(color: scheme.onSurfaceVariant)),
                  ],
                  if ((entry.meta ?? '').isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text('par ${entry.meta}', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DealCard extends StatelessWidget {
  final PipelineDeal deal;
  const _DealCard({required this.deal});

  @override
  Widget build(BuildContext context) {
    final stage = pipelineStage(deal.stage);
    return CrmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.handshake_outlined, size: 18),
              const SizedBox(width: 8),
              const Expanded(child: Text('Affaire en cours', style: TextStyle(fontWeight: FontWeight.w700))),
              TextButton(onPressed: () => showDealDialog(context, deal), child: const Text('Modifier')),
            ],
          ),
          const SizedBox(height: 8),
          Row(children: [CrmPill(stage), const Spacer(), Text('${deal.probabilite.round()} %')]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: deal.probabilite / 100, minHeight: 6, color: stage.color),
          ),
          const SizedBox(height: 12),
          _InfoRow(Icons.payments_outlined, 'Montant', deal.montant > 0 ? formatAmountFcfa(deal.montant) : 'Non estimé'),
          _InfoRow(Icons.flag_circle_outlined, 'Clôture prévue',
              deal.dateCloturePrevue == null ? 'Non définie' : formatDateFr(deal.dateCloturePrevue!)),
          _InfoRow(Icons.travel_explore, 'Source', deal.sourceLead == 'inconnu' ? 'Inconnue' : deal.sourceLead),
        ],
      ),
    );
  }
}

class _InfosCard extends StatelessWidget {
  final Client client;
  const _InfosCard({required this.client});

  @override
  Widget build(BuildContext context) {
    return CrmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('À propos', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _InfoRow(Icons.phone_outlined, 'Téléphone', client.telephone.isEmpty ? '—' : client.telephone),
          _InfoRow(Icons.mail_outline, 'Email', client.email.isEmpty ? '—' : client.email),
          _InfoRow(Icons.place_outlined, 'Adresse', client.adresse.isEmpty ? '—' : client.adresse),
          _InfoRow(Icons.work_outline, 'Activité', client.commentaireActivite.isEmpty ? '—' : client.commentaireActivite),
          if (client.notes.isNotEmpty) _InfoRow(Icons.notes, 'Notes', client.notes),
          if (client.createdAt != null) _InfoRow(Icons.cake_outlined, 'Client depuis', formatDateLongFr(client.createdAt!)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: muted),
          const SizedBox(width: 10),
          SizedBox(width: 100, child: Text(label, style: TextStyle(color: muted, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _CommandeStatut extends StatelessWidget {
  final String statut;
  const _CommandeStatut(this.statut);

  @override
  Widget build(BuildContext context) {
    const colors = {
      'payee': Colors.green,
      'livree': Colors.teal,
      'confirmee': Colors.blue,
      'en_preparation': Colors.indigo,
      'en_attente': Colors.orange,
      'annulee': Colors.red,
    };
    return CrmPill(
      CrmOption(statut, statut.isEmpty ? '—' : statut[0].toUpperCase() + statut.substring(1).replaceAll('_', ' '),
          colors[statut] ?? Colors.blueGrey, Icons.circle),
      dense: true,
      showIcon: false,
    );
  }
}
