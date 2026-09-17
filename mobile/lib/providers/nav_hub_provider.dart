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

  void reset() {
    _showHub = true;
    notifyListeners();
  }
}
