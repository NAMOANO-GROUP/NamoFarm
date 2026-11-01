import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/tache_crm.dart';
import '../../providers/auth_provider.dart';
import '../../providers/crm_provider.dart';
import '../../utils/contact_launcher.dart';
import '../../utils/crm_labels.dart';
import 'interaction_dialog.dart';

/// Nom de l'utilisateur connecté (auteur des interactions, tâches "Mes tâches"), vide si inconnu.
String currentUserName(BuildContext context) {
  final AuthProvider auth;
  try {
    auth = context.read<AuthProvider>();
  } on ProviderNotFoundException {
    return '';
  }
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

/// Message en bas d'écran. Avec un bouton (Annuler, Consigner...), il reste [dureeAction] puis disparaît :
/// depuis Flutter 3.32 un message avec bouton resterait sinon affiché jusqu'à ce qu'on le touche.
void showCrmSnack(
  BuildContext context,
  String message, {
  SnackBarAction? action,
  Duration dureeAction = const Duration(seconds: 6),
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      action: action,
      behavior: SnackBarBehavior.floating,
      persist: false,
      duration: action == null ? const Duration(seconds: 4) : dureeAction,
    ));
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
      persist: false,
      duration: const Duration(seconds: 6),
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

/// Canal de contact rapide depuis une fiche.
enum ContactCanal { appel, whatsapp, email }

/// Ouvre l'appel / WhatsApp / l'email, puis propose de consigner l'échange dans le fil d'activité.
Future<void> contacterEtProposerConsignation(
  BuildContext context, {
  required String contactId,
  required String telephone,
  String email = '',
  String prenom = '',
  required ContactCanal canal,
}) async {
  switch (canal) {
    case ContactCanal.appel:
      final ok = await openContactUri(context, telUri(telephone), unavailable: 'Numéro de téléphone indisponible');
      if (ok && context.mounted) _proposerConsignation(context, contactId, 'appel', 'Appel');
    case ContactCanal.whatsapp:
      final ok = await openContactUri(
        context,
        whatsappUri(telephone, message: prenom.isEmpty ? 'Bonjour, ' : 'Bonjour $prenom, '),
        unavailable: 'Numéro WhatsApp indisponible',
      );
      if (ok && context.mounted) _proposerConsignation(context, contactId, 'whatsapp', 'Message WhatsApp');
    case ContactCanal.email:
      await openContactUri(context, mailUri(email), unavailable: 'Aucune adresse email');
  }
}

void _proposerConsignation(BuildContext context, String contactId, String type, String sujet) {
  showCrmSnack(
    context,
    'Pensez à consigner cet échange',
    action: SnackBarAction(
      label: 'Consigner',
      onPressed: () => showInteractionDialog(context, clientId: contactId, type: type, sujet: sujet),
    ),
  );
}