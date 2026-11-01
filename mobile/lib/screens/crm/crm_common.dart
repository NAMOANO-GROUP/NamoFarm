import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/tache_crm.dart';
import '../../providers/auth_provider.dart';
import '../../providers/crm_provider.dart';
import '../../utils/crm_labels.dart';

/// Nom de l'utilisateur connecté (auteur des interactions, tâches "Mes tâches").
String currentUserName(BuildContext context) {
  final auth = context.read<AuthProvider>();
  final full = '${auth.userPrenom} ${auth.userNom}'.trim();
  if (full.isNotEmpty) return full;
  return (auth.user?['email'] ?? '').toString();
}

/// Confirmation avant une action irréversible.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmer',
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: Colors.red) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok == true;
}

void showCrmSnack(BuildContext context, String message, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), action: action, behavior: SnackBarBehavior.floating));
}

/// Coche / décoche une tâche (mise à jour instantanée) avec un bouton "Annuler" façon Planner.
Future<void> toggleTacheWithUndo(BuildContext context, TacheCRM tache) async {
  final crm = context.read<CrmProvider>();
  final messenger = ScaffoldMessenger.of(context);
  final nouveau = isTacheOuverte(tache.statut) ? 'terminee' : 'a_faire';
  final ok = await crm.changerStatutTache(tache, nouveau);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(ok
          ? (nouveau == 'terminee' ? 'Tâche terminée 🎉' : 'Tâche rouverte')
          : 'Mise à jour impossible, réessayez'),
      action: ok
          ? SnackBarAction(
              label: 'Annuler',
              onPressed: () => crm.changerStatutTache(tache.copyWith(statut: nouveau), tache.statut),
            )
          : null,
    ));
}

Future<void> deleteTacheWithConfirm(BuildContext context, TacheCRM tache) async {
  if (tache.id == null) return;
  final crm = context.read<CrmProvider>();
  final ok = await confirmAction(
    context,
    title: 'Supprimer la tâche',
    message: 'Supprimer « ${tache.titre} » ? Cette action est définitive.',
    confirmLabel: 'Supprimer',
    destructive: true,
  );
  if (!ok) return;
  final deleted = await crm.supprimerTache(tache.id!);
  if (context.mounted) showCrmSnack(context, deleted ? 'Tâche supprimée' : 'Suppression impossible');
}
