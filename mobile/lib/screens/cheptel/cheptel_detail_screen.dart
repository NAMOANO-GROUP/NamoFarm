import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/cheptel.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cheptel_provider.dart';
import '../../utils/cheptel.dart';
import '../../utils/crm_labels.dart';
import '../../utils/finance.dart' show fcfa, moisFr;
import '../../widgets/crm/crm_widgets.dart';
import 'cheptel_dialogs.dart';
import 'cheptel_widgets.dart';
import 'mouvement_sheet.dart';

/// Fiche d'un troupeau : Aperçu, Courbe, Journal, Finances.
class CheptelDetailScreen extends StatelessWidget {
  final Cheptel cheptel;

  const CheptelDetailScreen({super.key, required this.cheptel});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CheptelProvider>().cheptelParId(cheptel.id) ?? cheptel;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(c.nom),
          actions: [
            IconButton.filled(
              tooltip: 'Nouveau mouvement',
              visualDensity: VisualDensity.compact,
              onPressed: () => showMouvementCheptelSheet(context, c),
              icon: const Icon(Icons.add),
            ),
            PopupMenuButton<String>(
              tooltip: 'Plus d’options',
              onSelected: (v) async {
                switch (v) {
                  case 'sante':
                    showPlanSanteSheet(context, c);
                  case 'repro':
                    showMiseBasDialog(context, c);
                  case 'modifier':
                    showTroupeauForm(context, cheptel: c);
                  case 'supprimer':
                    if (await confirmerSuppressionTroupeau(context, c) && context.mounted) Navigator.of(context).pop();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'sante',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.vaccines_outlined),
                    title: Text('Plan santé'),
                  ),
                ),
                PopupMenuItem(
                  value: 'repro',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.favorite_border),
                    title: Text(especePour(c.espece).volaille ? 'Mise en couvaison' : 'Mise à la reproduction'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'modifier',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Modifier'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'supprimer',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline, color: Colors.red),
                    title: Text('Supprimer', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ),
          ],
          bottom: const TabBar(
            labelPadding: EdgeInsets.symmetric(horizontal: 2),
            tabs: [
              Tab(icon: Icon(Icons.dashboard_outlined, size: 20), text: 'Aperçu'),
              Tab(icon: Icon(Icons.show_chart, size: 20), text: 'Courbe'),
              Tab(icon: Icon(Icons.list_alt_outlined, size: 20), text: 'Journal'),
              Tab(icon: Icon(Icons.payments_outlined, size: 20), text: 'Finances'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _Apercu(c),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 24, 20, 24),
              child: CourbeEffectif(c, couleur: especePour(c.espece).color),
            ),
            _Journal(c),
            _Finances(c),
          ],
        ),
      ),
    );
  }
}

class _Apercu extends StatelessWidget {
  final Cheptel c;
  const _Apercu(this.c);

  @override
  Widget build(BuildContext context) {
    final e = especePour(c.espece);
    final k = kpisCheptel(c);
    final total = bilanCheptel(c);
    final taux = c.tauxMortalite;
    final tuiles = [
      KpiCard(
        label: 'Naissances (30 j)',
        value: '${k.mois.naissances}',
        icon: Icons.child_care,
        color: Colors.green,
        caption: '${total.naissances} au total',
      ),
      KpiCard(
        label: 'Morts (30 j)',
        value: '${k.mois.morts}',
        icon: Icons.heart_broken_outlined,
        color: k.alertes.contains(AlerteCheptel.mortaliteEnHausse) ? Colors.red : Colors.blueGrey,
        caption: '${total.morts} au total · ${taux.toStringAsFixed(1)} %',
      ),
      KpiCard(
        label: 'Vendus',
        value: '${total.vendus}',
        icon: Icons.sell_outlined,
        color: Colors.blue,
        caption: '${k.mois.vendus} sur 30 j',
      ),
      KpiCard(
        label: 'Prix moyen / tête',
        value: total.prixMoyenVente == null ? '—' : fcfa(total.prixMoyenVente!),
        icon: Icons.payments_outlined,
        color: Colors.indigo,
        caption: 'ventes chiffrées',
      ),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [e.color.shade700, e.color.shade400]),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              EspeceAvatar(c.espece, radius: 26, surFonce: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.libelle, style: TextStyle(color: Colors.white.withValues(alpha: 0.9))),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${c.effectifActuel} animaux',
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      k.evolution30j == 0
                          ? 'Stable sur 30 jours'
                          : '${k.evolution30j > 0 ? '+' : ''}${k.evolution30j} sur 30 jours',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (k.alertes.isNotEmpty) ...[const SizedBox(height: 10), AlertesCheptelPills(k.alertes)],
        const SizedBox(height: 12),
        ActionsRapidesCheptel(c),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, cs) {
            final col = cs.maxWidth >= 640 ? 4 : 2;
            final w = (cs.maxWidth - (col - 1) * 8) / col;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final t in tuiles) SizedBox(width: w, child: t)],
            );
          },
        ),
        const SizedBox(height: 12),
        CrmCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.fact_check_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      k.dernierComptage == null
                          ? 'Aucun recomptage enregistré'
                          : 'Dernier comptage : ${relativeDay(k.dernierComptage!)}',
                    ),
                  ),
                ],
              ),
              if (c.notes.isNotEmpty) ...[const Divider(height: 20), Text(c.notes)],
            ],
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => showPlanSanteSheet(context, c),
              icon: const Icon(Icons.vaccines_outlined, size: 18),
              label: const Text('Plan santé'),
            ),
            OutlinedButton.icon(
              onPressed: () => showMiseBasDialog(context, c),
              icon: const Icon(Icons.favorite_border, size: 18),
              label: Text(e.volaille ? 'Mise en couvaison' : 'Mise à la reproduction'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Journal extends StatefulWidget {
  final Cheptel c;
  const _Journal(this.c);

  @override
  State<_Journal> createState() => _JournalState();
}

class _JournalState extends State<_Journal> {
  final Set<String> _types = {};

  Future<void> _supprimer(CheptelMouvement m) async {
    final t = typeMouvement(m.type);
    final provider = context.read<CheptelProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce mouvement ?'),
        content: Text('${t.libelle} : ${m.quantite} animaux. L’effectif sera recalculé.'),
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
    if (ok != true || widget.c.id == null || m.id == null) return;
    final done = await provider.supprimerMouvement(widget.c.id!, m.id!);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(done ? 'Mouvement supprimé' : 'Suppression impossible')));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool admin = false;
    try {
      admin = context.watch<AuthProvider>().isAdmin;
    } on ProviderNotFoundException {
      admin = false;
    }
    final groupes = journalParMois(widget.c, types: _types);
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _types.isEmpty
                    ? 'Tous les mouvements'
                    : [for (final t in typesMouvementCheptel) if (_types.contains(t.valeur)) t.court].join(', '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
            _filtreMenu(),
          ],
        ),
        const SizedBox(height: 8),
        if (groupes.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text('Aucun mouvement', style: TextStyle(color: Colors.grey)),
            ),
          ),
        for (final g in groupes) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
            child: Text(
              '${moisFr[g.mois.month - 1][0].toUpperCase()}${moisFr[g.mois.month - 1].substring(1)} ${g.mois.year}',
              style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          CrmCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < g.mouvements.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 64),
                  _ligne(g.mouvements[i], admin),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Filtre multi-choix par type de mouvement (menu déroulant compact).
  Widget _filtreMenu() => MenuAnchor(
        alignmentOffset: const Offset(0, 4),
        menuChildren: [
          for (final t in typesMouvementCheptel)
            CheckboxMenuButton(
              closeOnActivate: false,
              value: _types.contains(t.valeur),
              onChanged: (v) => setState(() => v == true ? _types.add(t.valeur) : _types.remove(t.valeur)),
              child: Text(t.libelle),
            ),
          if (_types.isNotEmpty) ...[
            const Divider(height: 8),
            MenuItemButton(
              leadingIcon: const Icon(Icons.filter_alt_off_outlined, size: 18),
              onPressed: () => setState(_types.clear),
              child: const Text('Réinitialiser'),
            ),
          ],
        ],
        builder: (context, controller, _) => IconButton.outlined(
          tooltip: 'Filtres',
          onPressed: () => controller.isOpen ? controller.close() : controller.open(),
          icon: Badge(
            isLabelVisible: _types.isNotEmpty,
            label: Text('${_types.length}'),
            child: const Icon(Icons.filter_list, size: 20),
          ),
        ),
      );

  Widget _ligne(CheptelMouvement m, bool admin) {
    final t = typeMouvement(m.type);
    final signe = t.signe > 0 ? '+' : (t.signe < 0 ? '−' : '=');
    final d = m.date!.toLocal();
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: t.color.withValues(alpha: 0.14),
        child: Icon(t.icon, color: t.color, size: 20),
      ),
      title: Text(
        t.libelle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        [
          formatDateFr(d),
          if (m.montant > 0) fcfa(m.montant),
          if (m.motif.isNotEmpty) m.motif,
          if (m.utilisateur.isNotEmpty) m.utilisateur,
        ].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$signe${m.quantite}',
            style: TextStyle(fontWeight: FontWeight.w800, color: t.color.shade700),
          ),
          if (admin)
            IconButton(
              tooltip: 'Supprimer',
              visualDensity: VisualDensity.compact,
              onPressed: () => _supprimer(m),
              icon: const Icon(Icons.close, size: 18),
            ),
        ],
      ),
    );
  }
}

class _Finances extends StatelessWidget {
  final Cheptel c;
  const _Finances(this.c);

  @override
  Widget build(BuildContext context) {
    final b = bilanCheptel(c);
    final chiffres = mouvementsChronologiques(c).reversed.where((m) => m.montant > 0).toList();
    final achatMoyen = b.prixMoyenAchat;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      children: [
        CrmCard(
          child: Column(
            children: [
              _ligneTotal('Ventes', b.ventes, Colors.green.shade700, sous: '${b.vendus} animaux vendus'),
              const Divider(),
              _ligneTotal('Achats', b.achats, Colors.red.shade700, sous: '${b.achetes} animaux achetés'),
              const Divider(),
              _ligneTotal(
                'Solde du troupeau',
                b.solde,
                b.solde >= 0 ? Colors.teal.shade700 : Colors.orange.shade800,
                gras: true,
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: KpiCard(
                label: 'Prix moyen de vente',
                value: b.prixMoyenVente == null ? '—' : fcfa(b.prixMoyenVente!),
                icon: Icons.trending_up,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: KpiCard(
                label: 'Prix moyen d’achat',
                value: achatMoyen == null ? '—' : fcfa(achatMoyen),
                icon: Icons.shopping_cart_outlined,
                color: Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 8, 4, 4),
          child: Text('Ventes et achats', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        if (chiffres.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Aucune vente ni achat chiffré. Indiquez un prix lors de la saisie.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          CrmCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final m in chiffres)
                  ListTile(
                    dense: true,
                    leading: Icon(typeMouvement(m.type).icon, color: typeMouvement(m.type).color),
                    title: Text('${typeMouvement(m.type).court} de ${m.quantite} animaux'),
                    subtitle: Text(formatDateFr(m.date!.toLocal())),
                    trailing: Text(
                      '${m.type == 'vente' ? '+' : '−'} ${fcfa(m.montant)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: m.type == 'vente' ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(
            'Les ventes et achats chiffrés sont aussi enregistrés dans la Finance.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _ligneTotal(String label, double v, Color couleur, {String? sous, bool gras = false}) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontWeight: gras ? FontWeight.w700 : FontWeight.w500)),
            if (sous != null) Text(sous, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
      Text(
        fcfa(v),
        style: TextStyle(fontWeight: FontWeight.w800, color: couleur, fontSize: gras ? 17 : 15),
      ),
    ],
  );
}
