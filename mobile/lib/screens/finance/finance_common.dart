import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../utils/finance.dart';

AuthProvider? _auth(BuildContext context) {
  try {
    return context.read<AuthProvider>();
  } on ProviderNotFoundException {
    return null;
  }
}

/// Droit de saisir ou modifier des budgets (finance.write).
bool peutEcrireFinance(BuildContext context) => _auth(context)?.hasPermission('finance.write') ?? false;

/// Modification et suppression d'un mouvement : réservées aux administrateurs.
bool estAdminFinance(BuildContext context) {
  final auth = _auth(context);
  return auth != null && (auth.isAdmin || auth.isSuperadmin);
}

/// Prénom et nom de l'utilisateur connecté (vides si inconnus).
({String prenom, String nom}) utilisateurConnecte(BuildContext context) {
  final auth = _auth(context);
  return (prenom: auth?.userPrenom ?? '', nom: auth?.userNom ?? '');
}

/// Montant signé : « + 12 000 FCFA » en vert, « − 5 000 FCFA » en rouge.
String montantSigne(double montant, bool entree) => '${entree ? '+' : '−'} ${fcfa(montant)}';

Color couleurMontant(bool entree) => entree ? Colors.green.shade700 : Colors.red.shade700;

void financeSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}
