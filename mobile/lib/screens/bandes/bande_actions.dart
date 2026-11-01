import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/alerte.dart';
import '../../models/bande.dart';
import '../../providers/bandes_provider.dart';
import '../../utils/bande_kpis.dart';
import '../../utils/todo.dart';
import '../../widgets/bandes/bande_widgets.dart';
import '../alimentation_screen.dart';
import '../climat_screen.dart';
import '../crm/crm_common.dart';
import '../mortalite_screen.dart';
import '../poids_screen.dart';
import '../todo/todo_modeles_sheet.dart';

/// Ouvre l'écran de saisie correspondant (écrans séparés), puis rafraîchit les bandes.
Future<void> ouvrirSaisie(BuildContext context, Bande bande, SaisieBande saisie) async {
  final provider = context.read<BandesProvider>();
  final Widget page = switch (saisie) {
    SaisieBande.poids => PoidsScreen(bande: bande),
    SaisieBande.alimentation => AlimentationScreen(bande: bande),
    SaisieBande.mortalite => MortaliteScreen(bande: bande),
    SaisieBande.climat => ClimatScreen(bande: bande),
  };
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  await provider.chargerBandesActives();
}

/// Prochaine tâche ouverte d'une bande : tâches de suivi planifiées et tâches Todo liées.
ProchaineTache? prochaineTachePour(Bande bande, List<Alerte> todo) {
  final candidates = <ProchaineTache>[
    for (final e in bande.evenementsPrevisionnels)
      if (e.statut != 'termine') (titre: e.description.isEmpty ? 'Tâche de suivi' : e.description, date: e.datePrevue),
    for (final a in todo)
      if (a.bandeId == bande.id && !a.estFaite) (titre: a.titre, date: a.dateEcheance),
  ]..sort((a, b) => a.date.compareTo(b.date));
  return candidates.isEmpty ? null : candidates.first;
}

/// Confirme et ferme une bande, affiche son bilan puis propose de planifier le vide sanitaire.
Future<bool> fermerBandeAvecBilan(BuildContext context, Bande bande, ReferenceType ref) async {
  final provider = context.read<BandesProvider>();
  final ok = await confirmAction(
    context,
    title: 'Fermer la bande ?',
    message: 'Fermer « ${bande.nom} » ? Elle passera dans l’historique.',
    confirmLabel: 'Fermer',
    destructive: true,
  );
  if (!ok || bande.id == null) return false;
  final kpis = computeBandeKpis(bande, ref);
  final closed = await provider.fermerBande(bande.id!);
  if (!context.mounted) return closed;
  if (!closed) {
    showCrmSnack(context, 'Fermeture impossible : ${provider.lastError ?? 'erreur inconnue'}');
    return false;
  }
  final planifier = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.flag_circle_outlined, size: 36),
      title: Text('Bilan de ${bande.nom}'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Bande fermée après ${kpis.ageJours} jours.', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: bandeKpiTiles(kpis, width: 130)),
            const SizedBox(height: 12),
            Text(
              'Planifiez maintenant le vide sanitaire du bâtiment pour préparer la prochaine bande.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Plus tard')),
        FilledButton.icon(
          onPressed: () => Navigator.pop(ctx, true),
          icon: const Icon(Icons.cleaning_services_outlined),
          label: const Text('Planifier le vide sanitaire'),
        ),
      ],
    ),
  );
  if (planifier == true && context.mounted) {
    await showAppliquerModeleDialog(
      context,
      todoModeles.firstWhere((m) => m.id == 'vide_sanitaire'),
      bandeId: bande.id,
      bandeNom: bande.nom,
      depart: DateTime.now(),
    );
  }
  return true;
}
