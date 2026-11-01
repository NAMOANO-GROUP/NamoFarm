import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/client.dart';
import '../../models/interaction.dart';
import '../../models/stock.dart';
import '../../models/tache_crm.dart';
import '../../providers/crm_provider.dart';
import '../../providers/fournisseurs_provider.dart';
import '../../services/api_service.dart';
import '../../utils/achats.dart';
import '../../utils/contact_launcher.dart';
import '../../utils/crm_labels.dart';
import '../../utils/money_format.dart';
import '../../widgets/crm/contact_widgets.dart';
import '../../widgets/crm/crm_widgets.dart';
import '../../widgets/crm/tache_card.dart';
import '../crm/crm_common.dart';
import '../crm/interaction_dialog.dart';
import '../crm/tache_dialog.dart';
import 'fournisseur_form_dialog.dart';

const fournisseurOption = CrmOption('fournisseur', 'Fournisseur', Colors.brown, Icons.local_shipping_outlined);

/// Fiche fournisseur : en-tête, actions rapides (appel, WhatsApp...), fil d'activité
/// avec les réceptions de stock, relances et articles fournis.
class FournisseurDetailScreen extends StatefulWidget {
  final Client fournisseur;

  /// Source des stocks (l'API par défaut ; remplaçable dans les tests).
  final Future<List<dynamic>> Function() stocksLoader;

  const FournisseurDetailScreen({super.key, required this.fournisseur, this.stocksLoader = ApiService.getStocks});

  @override
  State<FournisseurDetailScreen> createState() => _FournisseurDetailScreenState();
}

enum _Section { activite, relances, articles, infos }

class _FournisseurDetailScreenState extends State<FournisseurDetailScreen> {
  List<Stock> _stocks = [];
  bool _stocksLoading = true;
  _Section _section = _Section.activite;

  String get _id => widget.fournisseur.id ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  Future<void> _charger() async {
    final crm = context.read<CrmProvider>();
    await Future.wait([
      crm.chargerInteractionsClient(_id),
      if (crm.taches.isEmpty) crm.chargerTachesCrm(),
      _chargerStocks(),
    ]);
  }

  Future<void> _chargerStocks() async {
    try {
      final data = await widget.stocksLoader();
      final all = data.whereType<Map>().map((e) => Stock.fromJson(Map<String, dynamic>.from(e))).toList();
      if (mounted) setState(() => _stocks = all);
    } catch (_) {
      // Les articles sont un complément : la fiche reste utilisable sans eux.
    } finally {
      if (mounted) setState(() => _stocksLoading = false);
    }
  }

  Client _fournisseur(FournisseursProvider provider) {
    for (final f in provider.fournisseurs) {
      if (f.id == _id) return f;
    }
    return widget.fournisseur;
  }

  Future<void> _contact(Client f, ContactCanal canal) => contacterEtProposerConsignation(
        context,
        contactId: _id,
        telephone: f.telephone,
        email: f.email,
        prenom: f.prenom,
        canal: canal,
      );

  Future<void> _commander(Client f, Stock s) async {
    final message = 'Bonjour ${f.prenom}, je souhaite commander du ${s.nom}. '
        'Pouvez-vous me confirmer votre prix et le délai de livraison ? Merci.';
    final ok = await openContactUri(context, whatsappUri(f.telephone, message: message), unavailable: 'Numéro WhatsApp indisponible');
    if (ok && mounted) {
      showCrmSnack(
        context,
        'Pensez à consigner la commande',
        action: SnackBarAction(
          label: 'Consigner',
          onPressed: () => showInteractionDialog(context, clientId: _id, type: 'whatsapp', sujet: 'Commande ${s.nom}'),
        ),
      );
    }
  }

  Future<void> _supprimer(Client f) async {
    final ok = await confirmAction(
      context,
      title: 'Supprimer le fournisseur',
      message: 'Supprimer « ${f.nomComplet} » ?',
      confirmLabel: 'Supprimer',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final deleted = await context.read<FournisseursProvider>().supprimerFournisseur(_id);
    if (!mounted) return;
    if (deleted) {
      Navigator.pop(context);
    } else {
      showCrmSnack(context, 'Suppression impossible');
    }
  }

  List<TimelineEntry> _timeline(List<Interaction> interactions, List<TacheCRM> taches, List<Reception> receptions) {
    return [
      for (final i in interactions.where((i) => !i.isPipelineUpdate))
        () {
          final opt = interactionType(i.type);
          return TimelineEntry(
            date: i.dateInteraction,
            kind: 'echange',
            icon: opt.icon,
            color: opt.color,
            title: i.sujet.isEmpty ? opt.label : '${opt.label} · ${i.sujet}',
            body: i.contenu,
            meta: i.auteur,
          );
        }(),
      for (final r in receptions)
        TimelineEntry(
          date: r.mouvement.date,
          kind: 'reception',
          icon: Icons.inventory_2_outlined,
          color: Colors.brown,
          title: 'Réception · ${_qte(r.mouvement.quantite)} ${r.stock.unite} de ${r.stock.nom}',
          body: [if (r.montant > 0) formatAmountFcfa(r.montant), if (r.mouvement.motif.isNotEmpty) r.mouvement.motif].join(' · '),
          meta: r.mouvement.utilisateur,
        ),
      for (final t in taches.where((t) => !isTacheOuverte(t.statut)))
        TimelineEntry(
          date: t.dateEcheance,
          kind: 'tache',
          icon: t.statut == 'terminee' ? Icons.task_alt : Icons.block,
          color: t.statut == 'terminee' ? Colors.green : Colors.grey,
          title: '${tacheStatut(t.statut).label} · ${t.titre}',
          body: t.description.isEmpty ? null : t.description,
          meta: t.assigneA.isEmpty ? null : t.assigneA,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final f = _fournisseur(context.watch<FournisseursProvider>());
    final crm = context.watch<CrmProvider>();
    final taches = crm.tachesPourClient(_id);
    final interactions = crm.interactionsClientId == _id ? crm.interactions : const <Interaction>[];
    final articles = _stocks.where((s) => stockFourniPar(s, f)).toList()..sort((a, b) => a.nom.compareTo(b.nom));
    final receptions = receptionsDe(articles);

    return Scaffold(
      appBar: AppBar(
        title: Text(f.entreprise.isNotEmpty ? f.entreprise : f.nomComplet, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Modifier le fournisseur',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showFournisseurFormDialog(context, fournisseur: f),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'delete') _supprimer(f);
            },
            itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Supprimer le fournisseur'))],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _charger,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final header = [
              _Header(fournisseur: f, articles: articles, receptions: receptions),
              ContactQuickActions(
                onCall: () => _contact(f, ContactCanal.appel),
                onWhatsapp: () => _contact(f, ContactCanal.whatsapp),
                onEmail: f.email.isEmpty ? null : () => _contact(f, ContactCanal.email),
                onNote: () => showInteractionDialog(context, clientId: _id),
                onTask: () => showTacheDialog(context, clientId: _id),
              ),
            ];
            final activite = _activiteSection(_timeline(interactions, taches, receptions), crm.interactionsLoading);
            final relances = _relancesSection(taches);
            final articlesSection = _articlesSection(f, articles);
            final infos = [_InfosCard(fournisseur: f)];

            if (constraints.maxWidth >= 1000) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 340, child: ListView(padding: const EdgeInsets.all(12), children: [...header, ...infos])),
                  Expanded(child: ListView(padding: const EdgeInsets.all(12), children: activite)),
                  SizedBox(
                    width: 360,
                    child: ListView(padding: const EdgeInsets.all(12), children: [...relances, ...articlesSection]),
                  ),
                ],
              );
            }

            final content = switch (_section) {
              _Section.activite => activite,
              _Section.relances => relances,
              _Section.articles => articlesSection,
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
                        value: _Section.articles,
                        icon: const Icon(Icons.inventory_2_outlined),
                        label: Text('Articles (${articles.length})'),
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

  List<Widget> _activiteSection(List<TimelineEntry> entries, bool loading) {
    return [
      CrmSectionHeader(
        "Fil d'activité",
        icon: Icons.timeline,
        trailing: TextButton.icon(
          onPressed: () => showInteractionDialog(context, clientId: _id),
          icon: const Icon(Icons.add_comment_outlined, size: 18),
          label: const Text('Consigner'),
        ),
      ),
      if ((loading || _stocksLoading) && entries.isEmpty)
        const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
      else if (entries.isEmpty)
        const EmptyTimeline(message: 'Consignez un appel, une commande ou une note pour démarrer l’historique.')
      else
        ...buildActivityTimeline(context, entries),
    ];
  }

  List<Widget> _relancesSection(List<TacheCRM> taches) {
    final ouvertes = taches.where((t) => isTacheOuverte(t.statut)).toList()..sort((a, b) => a.dateEcheance.compareTo(b.dateEcheance));
    return [
      CrmSectionHeader(
        'Relances ouvertes',
        icon: Icons.task_alt,
        trailing: IconButton(
          tooltip: 'Nouvelle tâche',
          icon: const Icon(Icons.add_task),
          onPressed: () => showTacheDialog(context, clientId: _id),
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

  List<Widget> _articlesSection(Client f, List<Stock> articles) {
    return [
      const CrmSectionHeader('Articles fournis', icon: Icons.inventory_2_outlined),
      if (_stocksLoading)
        const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
      else if (articles.isEmpty)
        const CrmCard(
          child: Text(
            'Aucun article rattaché. Renseignez ce fournisseur dans le champ « Fournisseur » d’un stock.',
            style: TextStyle(color: Colors.grey),
          ),
        )
      else
        CrmCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final s in articles)
                ListTile(
                  leading: Icon(stockBas(s) ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
                      color: stockBas(s) ? Colors.orange : null),
                  title: Text(s.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${_qte(s.quantiteActuelle)} ${s.unite} en stock'
                    '${s.prixUnitaire > 0 ? ' · ${formatAmountFcfa(s.prixUnitaire)} / ${s.unite}' : ''}',
                  ),
                  trailing: TextButton.icon(
                    onPressed: () => _commander(f, s),
                    icon: const Icon(Icons.chat_outlined, size: 18),
                    label: Text(stockBas(s) ? 'Réassort' : 'Commander'),
                  ),
                ),
            ],
          ),
        ),
    ];
  }
}

String _qte(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

class _Header extends StatelessWidget {
  final Client fournisseur;
  final List<Stock> articles;
  final List<Reception> receptions;

  const _Header({required this.fournisseur, required this.articles, required this.receptions});

  @override
  Widget build(BuildContext context) {
    final f = fournisseur;
    final scheme = Theme.of(context).colorScheme;
    final depuis = DateTime.now().subtract(const Duration(days: 90));
    final achats90 = receptions.where((r) => r.mouvement.date.isAfter(depuis)).fold<double>(0, (s, r) => s + r.montant);
    final derniere = receptions.isEmpty ? null : receptions.first.mouvement.date;
    final titre = f.entreprise.isNotEmpty ? f.entreprise : f.nomComplet;
    return CrmCard(
      child: Column(
        children: [
          Row(
            children: [
              ClientAvatar(name: titre, radius: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titre, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    if (f.entreprise.isNotEmpty) Text('Contact : ${f.nomComplet}', style: TextStyle(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        const CrmPill(fournisseurOption, dense: true),
                        CrmPill(clientType(f.typeClient), dense: true),
                        if (articles.any(stockBas))
                          const CrmPill(CrmOption('bas', 'Stock bas', Colors.orange, Icons.warning_amber_rounded), dense: true),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              HeaderStat(label: 'Articles fournis', value: '${articles.length}'),
              HeaderStat(label: 'Achats 90 j', value: formatCompactFcfa(achats90)),
              HeaderStat(label: 'Dernière réception', value: derniere == null ? '—' : relativeDay(derniere)),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfosCard extends StatelessWidget {
  final Client fournisseur;
  const _InfosCard({required this.fournisseur});

  @override
  Widget build(BuildContext context) {
    final f = fournisseur;
    return CrmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('À propos', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          InfoRow(Icons.person_outline, 'Contact', f.nomComplet),
          InfoRow(Icons.phone_outlined, 'Téléphone', f.telephone.isEmpty ? '—' : f.telephone),
          InfoRow(Icons.mail_outline, 'Email', f.email.isEmpty ? '—' : f.email),
          InfoRow(Icons.place_outlined, 'Adresse', f.adresse.isEmpty ? '—' : f.adresse),
          InfoRow(Icons.category_outlined, 'Produits', f.commentaireActivite.isEmpty ? '—' : f.commentaireActivite),
          if (f.dernierContactLe != null) InfoRow(Icons.history, 'Dernier contact', relativeDay(f.dernierContactLe!)),
          if (f.createdAt != null) InfoRow(Icons.handshake_outlined, 'Partenaire depuis', formatDateLongFr(f.createdAt!)),
        ],
      ),
    );
  }
}
