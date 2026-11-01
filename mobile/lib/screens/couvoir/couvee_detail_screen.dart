import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/couvee.dart';
import '../../providers/reproduction_provider.dart';
import '../../utils/couvoir.dart';
import '../../widgets/crm/crm_widgets.dart';
import 'couvee_dialogs.dart';
import 'couvee_widgets.dart';

/// Fiche d'une couvée : avancement, entonnoir, objectifs, frise des étapes, notes.
class CouveeDetailScreen extends StatelessWidget {
  final Couvee couvee;

  const CouveeDetailScreen({super.key, required this.couvee});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReproductionProvider>();
    Couvee c = couvee;
    for (final x in provider.couvees) {
      if (x.id == couvee.id) c = x;
    }
    final inc = incubationPour(c.race);
    final av = enIncubation(c) ? avancementCouvee(c) : null;
    final alertes = alertesCouvee(c);
    final statutCouleur = statutCouveeCouleur(c.statut);

    return Scaffold(
      appBar: AppBar(
        title: Text(c.code),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Plus d’options',
            onSelected: (v) async {
              switch (v) {
                case 'eclosion':
                  showSaisieEclosion(context, c);
                case 'cloturer':
                  cloturerCouvee(context, c);
                case 'modifier':
                  showModifierCouvee(context, c);
                case 'supprimer':
                  if (await confirmerSuppressionCouvee(context, c) && context.mounted) Navigator.of(context).pop();
              }
            },
            itemBuilder: (_) => [
              if (enIncubation(c))
                const PopupMenuItem(
                  value: 'eclosion',
                  child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.egg_alt), title: Text('Saisir l’éclosion')),
                ),
              if (c.statut == 'eclos')
                const PopupMenuItem(
                  value: 'cloturer',
                  child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.check_circle_outline), title: Text('Clôturer')),
                ),
              const PopupMenuItem(
                value: 'modifier',
                child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.edit_outlined), title: Text('Modifier')),
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
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.amber.shade800, Colors.amber.shade500]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  child: const Icon(Icons.egg_alt, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        [if (c.race.isNotEmpty) c.race, '${inc.espece} · ${inc.jours} j'].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.92)),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text('${c.nbOeufsIncubes} œufs',
                            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(20)),
                        child: Text(statutCouveeLibelle(c.statut),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: statutCouleur.shade800)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (alertes.isNotEmpty) ...[
            const SizedBox(height: 10),
            AlertesCouveePills(alertes),
          ],
          const SizedBox(height: 12),
          if (av != null) ...[
            CrmCard(child: AvancementIncubation(av)),
            FilledButton.icon(
              onPressed: () => showSaisieEclosion(context, c),
              icon: const Icon(Icons.egg_alt),
              label: const Text('Saisir l’éclosion'),
            ),
            const SizedBox(height: 12),
          ],
          const CrmSectionHeader('De l’œuf au poussin', icon: Icons.filter_alt_outlined),
          CrmCard(child: EntonnoirVisuel(c)),
          if (c.nbEclos != null) ...[
            const CrmSectionHeader('Résultats', icon: Icons.flag_outlined),
            CrmCard(
              child: Column(
                children: [
                  TauxObjectif(libelle: 'Taux d’éclosion', taux: tauxEclosionIncubes(c), objectif: objectifEclosionPct),
                  TauxObjectif(libelle: 'Viabilité des poussins', taux: tauxViabilite(c), objectif: objectifViabilitePct),
                ],
              ),
            ),
            if (c.statut == 'eclos')
              OutlinedButton.icon(
                onPressed: () => cloturerCouvee(context, c),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Clôturer la couvée'),
              ),
          ],
          const CrmSectionHeader('Étapes', icon: Icons.timeline),
          CrmCard(child: FriseEtapes(c)),
          if (c.notes.isNotEmpty) ...[
            const CrmSectionHeader('Notes', icon: Icons.notes_outlined),
            CrmCard(child: Text(c.notes)),
          ],
        ],
      ),
    );
  }
}
