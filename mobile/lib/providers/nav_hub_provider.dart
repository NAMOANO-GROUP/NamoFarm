import 'package:flutter/foundation.dart';

/// Contrôle l'affichage de la page d'accueil "hub" (grille de modules).
/// Après connexion on démarre sur le hub ; taper le logo y ramène depuis
/// n'importe quelle page principale.
class NavHubProvider with ChangeNotifier {
  bool _showHub = true;

  bool get showHub => _showHub;

  void goHub() {
    if (!_showHub) {
      _showHub = true;
      notifyListeners();
    }
  }

  void goModule() {
    if (_showHub) {
      _showHub = false;
      notifyListeners();
    }
  }

  String? _moduleDemande;
  Set<String> _modulesAccessibles = const {};

  /// Modules autorisés pour l'utilisateur (renseigné par l'écran principal).
  set modulesAccessibles(Set<String> ids) => _modulesAccessibles = ids;

  /// Vrai si le module peut être ouvert (inconnu = autorisé, l'écran principal vérifie).
  bool peutOuvrir(String id) => _modulesAccessibles.isEmpty || _modulesAccessibles.contains(id);

  /// Module à ouvrir, demandé depuis une page (ex. un élément du Tableau de bord).
  String? get moduleDemande => _moduleDemande;

  void ouvrirModule(String id) {
    _moduleDemande = id;
    _showHub = false;
    notifyListeners();
  }

  /// Lit et efface la demande d'ouverture (appelé par l'écran principal).
  String? prendreModuleDemande() {
    final id = _moduleDemande;
    _moduleDemande = null;
    return id;
  }

  void reset() {
    _showHub = true;
    notifyListeners();
  }
}
