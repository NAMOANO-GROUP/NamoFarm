import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/client.dart';
import '../../models/crm_pipeline.dart';
import '../../models/tache_crm.dart';
import '../../providers/crm_provider.dart';
import '../../utils/contact_launcher.dart';
import '../../utils/crm_labels.dart';
import '../../utils/money_format.dart';
import '../../widgets/crm/crm_charts.dart';
import '../../widgets/crm/crm_widgets.dart';
import '../../widgets/crm/tache_card.dart';
import 'client_detail_screen.dart';
import 'crm_common.dart';
import 'tache_dialog.dart';

const _suggestionStyles = {
  'sortie_bande': (Icons.egg_outlined, Colors.orange, 'Sortie de bande'),
  'reachat': (Icons.autorenew, Colors.indigo, 'Réachat prévu'),
  'sans_contact': (Icons.hourglass_bottom, Colors.blueGrey, 'Client à relancer'),
};

/// Tableau de bord CRM : indicateurs, suggestions automatiques et priorités du jour.
class CrmDashboardTab extends StatelessWidget {
  /// Bascule vers un autre onglet du CRM (ex : relances, pipeline).
  final ValueChanged<int>? onNavigate;

  const CrmDashboardTab({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final crm = context.watch<CrmProvider>();
    final d = crm.dashboard ?? const CrmDashboardData();
    final today = crm.taches
        .where((t) => isTacheOuverte(t.statut) && daysFromToday(t.dateEcheance) <= 0)
        .toList()
      ..sort((a, b) => a.dateEcheance.compareTo(b.dateEcheance));
    final enRetard = today.where((t) => daysFromToday(t.dateEcheance) < 0).length;

    return RefreshIndicator(
      onRefresh: crm.chargerTout,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1000;
          final kpiColumns = constraints.maxWidth >= 900 ? 6 : (constraints.maxWidth >= 560 ? 3 : 2);
          final kpis = [
            KpiCard(
              label: 'CA du mois',
              value: formatCompactFcfa(d.caMois),
              icon: Icons.payments_outlined,
              color: Colors.green,
              trend: d.evolutionCa,
              caption: d.caMoisPrecedent > 0 ? 'vs ${formatCompactFcfa(d.caMoisPrecedent)}' : null,
            ),
            KpiCard(
              label: 'Prévision pondérée',
              value: formatCompactFcfa(crm.previsionPonderee),
              icon: Icons.insights_outlined,
              color: Colors.indigo,
              caption: 'sur ${formatCompactFcfa(crm.montantOuvert)} en cours',
              onTap: () => onNavigate?.call(2),
            ),
            KpiCard(
              label: 'Taux de conversion',
              value: '${crm.conversionRate.toStringAsFixed(1)} %',
              icon: Icons.percent,
              color: Colors.purple,
              onTap: () => onNavigate?.call(2),
            ),
            KpiCard(
              label: 'Relances en retard',
              value: '$enRetard',
              icon: Icons.warning_amber_rounded,
              color: enRetard > 0 ? Colors.red : Colors.green,
              caption: '${crm.taches.where((t) => isTacheOuverte(t.statut)).length} ouvertes',
              onTap: () => onNavigate?.call(3),
            ),
            KpiCard(
              label: 'Clients actifs',
              value: '${d.clientsActifs}',
              icon: Icons.verified_outlined,
              color: Colors.teal,
              caption: '${d.totalProspects} prospects',
              onTap: () => onNavigate?.call(1),
            ),
            KpiCard(
              label: 'Nouveaux ce mois',
              value: '${d.nouveauxClients}',
              icon: Icons.person_add_alt,
              color: Colors.orange,
              caption: '${d.commandesEnAttente} commande(s) en attente',
            ),
          ];

          final kpiGrid = GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            // Hauteur fixe : un ratio largeur/hauteur coupait le contenu sur les petits écrans.
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: kpiColumns,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              mainAxisExtent: 148,
            ),
            children: kpis,
          );

          final left = <Widget>[
            _SuggestionsCard(suggestions: crm.suggestions),
            _AujourdhuiCard(taches: today, onSeeAll: () => onNavigate?.call(3)),
          ];
          final right = <Widget>[
            _TopClientsCard(clients: d.topClients),
            if (d.ventesParMois.isNotEmpty)
              CrmCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ventes des 12 derniers mois', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    VentesMensuellesChart(ventes: d.ventesParMois),
                  ],
                ),
              ),
          ];

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _Greeting(name: currentUserName(context), aFaire: today.length),
              kpiGrid,
              const SizedBox(height: 8),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: Column(children: left)),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: Column(children: right)),
                  ],
                )
              else ...[
                ...left,
                ...right,
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  final String name;
  final int aFaire;
  const _Greeting({required this.name, required this.aFaire});

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final salut = hour < 18 ? 'Bonjour' : 'Bonsoir';
    final prenom = name.split(' ').first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$salut${prenom.isEmpty ? '' : ' $prenom'} 👋', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(
            aFaire == 0 ? 'Aucune relance urgente aujourd’hui.' : '$aFaire relance${aFaire > 1 ? 's' : ''} à traiter aujourd’hui.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _SuggestionsCard extends StatelessWidget {
  final List<CrmSuggestion> suggestions;
  const _SuggestionsCard({required this.suggestions});

  Future<void> _creer(BuildContext context, CrmSuggestion s) async {
    final crm = context.read<CrmProvider>();
    final ok = await crm.appliquerSuggestion(s, assigneA: currentUserName(context));
    if (context.mounted) showCrmSnack(context, ok ? 'Relance créée pour ${s.clientNom}' : 'Création impossible');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CrmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              const Expanded(child: Text('Suggestions intelligentes', style: TextStyle(fontWeight: FontWeight.w700))),
              if (suggestions.isNotEmpty)
                Text('${suggestions.length}', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Calculées à partir des sorties de bande, du rythme de réachat et des clients sans contact.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          if (suggestions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Tout est à jour, aucune relance à proposer. ✅'),
            )
          else
            for (final s in suggestions.take(8))
              _SuggestionTile(
                suggestion: s,
                onCreate: () => _creer(context, s),
                onCall: () => openContactUri(context, telUri(s.telephone), unavailable: 'Numéro indisponible'),
                onDismiss: () => context.read<CrmProvider>().ignorerSuggestion(s),
              ),
        ],
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final CrmSuggestion suggestion;
  final VoidCallback onCreate;
  final VoidCallback onCall;
  final VoidCallback onDismiss;

  const _SuggestionTile({required this.suggestion, required this.onCreate, required this.onCall, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final style = _suggestionStyles[suggestion.kind] ?? (Icons.lightbulb_outline, Colors.blue, 'Suggestion');
    final (icon, color, label) = style;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 10, 4, 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(radius: 16, backgroundColor: color.withValues(alpha: 0.15), child: Icon(icon, size: 18, color: color)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(suggestion.titre, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('$label · ${suggestion.raison}', style: TextStyle(fontSize: 12, color: color.shade700, fontWeight: FontWeight.w600)),
                    if (suggestion.description.isNotEmpty)
                      Text(suggestion.description, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Ignorer',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 18),
                onPressed: onDismiss,
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 4,
              children: [
                if (suggestion.telephone.isNotEmpty)
                  TextButton.icon(onPressed: onCall, icon: const Icon(Icons.call_outlined, size: 18), label: const Text('Appeler')),
                FilledButton.tonalIcon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_task, size: 18),
                  label: const Text('Créer la relance'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AujourdhuiCard extends StatelessWidget {
  final List<TacheCRM> taches;
  final VoidCallback onSeeAll;
  const _AujourdhuiCard({required this.taches, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return CrmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.today_outlined, size: 18),
              const SizedBox(width: 8),
              const Expanded(child: Text("À faire aujourd'hui", style: TextStyle(fontWeight: FontWeight.w700))),
              TextButton(onPressed: onSeeAll, child: const Text('Tout voir')),
            ],
          ),
          const SizedBox(height: 4),
          if (taches.isEmpty)
            Row(
              children: [
                const Expanded(child: Text('Rien d’urgent. Profitez-en pour prospecter !')),
                TextButton.icon(
                  onPressed: () => showTacheDialog(context, echeance: DateTime.now()),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Tâche'),
                ),
              ],
            )
          else
            for (final t in taches.take(6))
              TacheCard(
                tache: t,
                onToggleDone: t.id == null ? null : () => toggleTacheWithUndo(context, t),
                onTap: t.id == null ? null : () => showTacheDialog(context, tache: t),
              ),
        ],
      ),
    );
  }
}

class _TopClientsCard extends StatelessWidget {
  final List<CrmTopClient> clients;
  const _TopClientsCard({required this.clients});

  @override
  Widget build(BuildContext context) {
    final max = clients.isEmpty ? 1.0 : clients.map((c) => c.chiffreAffaires).reduce((a, b) => a > b ? a : b);
    return CrmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.emoji_events_outlined, size: 18),
              SizedBox(width: 8),
              Text('Meilleurs clients', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          if (clients.isEmpty)
            const Text('Pas encore de ventes enregistrées.', style: TextStyle(color: Colors.grey))
          else
            for (final c in clients)
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) {
                    final parts = c.nomComplet.split(' ');
                    return ClientDetailScreen(
                      client: Client(
                        id: c.id,
                        prenom: parts.length > 1 ? parts.first : '',
                        nom: parts.length > 1 ? parts.sublist(1).join(' ') : c.nomComplet,
                        telephone: '',
                        statut: c.statut,
                        chiffreAffairesCumul: c.chiffreAffaires,
                      ),
                    );
                  },
                )),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                  child: Row(
                    children: [
                      ClientAvatar(name: c.nomComplet, radius: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.nomComplet, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(value: max <= 0 ? 0 : c.chiffreAffaires / max, minHeight: 5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(formatCompactFcfa(c.chiffreAffaires), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
