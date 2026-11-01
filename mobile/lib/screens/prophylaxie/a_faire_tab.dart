import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/bandes_provider.dart';
import '../../providers/sante_provider.dart';
import '../../utils/crm_labels.dart';
import '../../utils/prophylaxie.dart';
import '../../widgets/crm/crm_widgets.dart';
import '../../widgets/empty_state.dart';
import '../bandes/bande_detail_screen.dart';

void prophylaxieSnack(BuildContext context, String m) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

/// Planning des vaccins et traitements prévus sur toutes les bandes en cours.
class AFaireTab extends StatelessWidget {
  const AFaireTab({super.key});

  Future<void> _faire(BuildContext context, InterventionPrevue i) async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Marquer comme fait ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${i.evenement.description}\n${i.bande.nom} · J${i.ageJours}'),
            const SizedBox(height: 8),
            TextField(
              controller: note,
              decoration: const InputDecoration(labelText: 'Remarque (facultatif)', prefixIcon: Icon(Icons.notes_outlined)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton.icon(onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Icons.check), label: const Text('Fait')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final provider = context.read<BandesProvider>();
    final done = await provider.terminerEvenementPrevisionnel(
      i.bande.id ?? '',
      i.evenement.id ?? '',
      commentairesRealisation: note.text.trim(),
    );
    if (context.mounted) prophylaxieSnack(context, done ? 'Intervention enregistrée' : 'Erreur : ${provider.lastError ?? ''}');
  }

  @override
  Widget build(BuildContext context) {
    final bandes = context.watch<BandesProvider>().bandesActives;
    final traitements = context.watch<SanteProvider>().traitements;
    final now = DateTime.now();
    final a = interventionsAFaire(bandes);
    final r = resumeProphylaxie(bandes, traitements, now: now);
    final delais = delaisEnCours(traitements, now: now);
    final groupes = {
      for (final b in DueBucket.values) b: a.where((x) => x.echeance(now: now) == b).toList(),
    };
    String nomBande(String? id) {
      for (final b in bandes) {
        if (b.id == id) return b.nom;
      }
      return '';
    }

    return RefreshIndicator(
      onRefresh: () => Future.wait([
        context.read<BandesProvider>().chargerBandesActives(),
        context.read<SanteProvider>().charger(),
      ]),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          _Resume(r),
          if (delais.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final d in delais)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.block, color: Colors.orange, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${nomBande(d.traitement.bandeId).isEmpty ? 'Animaux traités' : nomBande(d.traitement.bandeId)} : '
                        'ne pas vendre avant le ${formatDateFr(d.fin)} (${d.traitement.produit}, encore ${d.joursRestants} j)',
                        style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 4),
          if (a.isEmpty)
            const EmptyState(
              icon: Icons.verified_outlined,
              title: 'Rien de prévu',
              subtitle: 'Appliquez un protocole à une bande (onglet Protocoles) pour planifier ses vaccins.',
            ),
          for (final b in DueBucket.values)
            if (groupes[b]!.isNotEmpty) ...[
              CrmSectionHeader(
                '${dueBucketLabels[b]} (${groupes[b]!.length})',
                icon: b == DueBucket.enRetard ? Icons.warning_amber_rounded : Icons.event_outlined,
              ),
              CrmCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var k = 0; k < groupes[b]!.length; k++) ...[
                      if (k > 0) const Divider(height: 1, indent: 64),
                      _Ligne(
                        i: groupes[b]![k],
                        couleur: dueBucketColors[b]!,
                        onFait: () => _faire(context, groupes[b]![k]),
                      ),
                    ],
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }
}

class _Resume extends StatelessWidget {
  final ResumeProphylaxie r;
  const _Resume(this.r);

  @override
  Widget build(BuildContext context) {
    final tuiles = [
      ('En retard', r.enRetard, Icons.warning_amber_rounded, r.enRetard > 0 ? Colors.red : Colors.green),
      ('Aujourd’hui', r.aujourdhui, Icons.today, Colors.orange),
      ('Cette semaine', r.cetteSemaine, Icons.date_range, Colors.blue),
      ('Faites ce mois', r.faitesCeMois, Icons.check_circle_outline, Colors.teal),
    ];
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, cs) {
      final col = cs.maxWidth >= 640 ? 4 : 2;
      final w = (cs.maxWidth - (col - 1) * 8) / col;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final t in tuiles)
            Container(
              width: w,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: t.$4.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: t.$4.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(t.$3, color: t.$4, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                        Text('${t.$2}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    });
  }
}

class _Ligne extends StatelessWidget {
  final InterventionPrevue i;
  final MaterialColor couleur;
  final VoidCallback onFait;

  const _Ligne({required this.i, required this.couleur, required this.onFait});

  @override
  Widget build(BuildContext context) {
    final e = i.evenement;
    return ListTile(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BandeDetailScreen(bande: i.bande))),
      leading: CircleAvatar(
        backgroundColor: couleur.withValues(alpha: 0.14),
        child: Icon(e.type == 'vaccination' ? Icons.vaccines_outlined : Icons.medication_outlined, color: couleur.shade700, size: 20),
      ),
      title: Text(e.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        [i.bande.nom, 'J${i.ageJours}', relativeDay(i.date), if (e.commentaires.isNotEmpty) e.commentaires].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton.filledTonal(tooltip: 'Marquer comme fait', onPressed: onFait, icon: const Icon(Icons.check)),
    );
  }
}
