import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Nombre de modules favoris affichés dans la barre du bas (téléphone).
const int kNavFavoris = 4;

/// Ordre final des modules : d'abord ceux de l'ordre enregistré (s'ils existent encore),
/// puis les modules jamais classés, dans leur ordre par défaut.
List<String> applyModuleOrder(List<String> defaultIds, List<String> saved) {
  final known = defaultIds.toSet();
  final ordered = <String>[];
  for (final id in saved) {
    if (known.contains(id) && !ordered.contains(id)) ordered.add(id);
  }
  for (final id in defaultIds) {
    if (!ordered.contains(id)) ordered.add(id);
  }
  return ordered;
}

/// Ordre personnalisé des modules de la navigation principale, mémorisé sur l'appareil.
class NavOrderProvider with ChangeNotifier {
  static const _prefsKey = 'nav.moduleOrder';

  List<String> _order = const [];
  bool _loaded = false;

  List<String> get order => _order;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _order = prefs.getStringList(_prefsKey) ?? const [];
    _loaded = true;
    notifyListeners();
  }

  /// Trie [items] selon l'ordre enregistré.
  List<T> sort<T>(List<T> items, String Function(T) idOf) {
    final ids = applyModuleOrder(items.map(idOf).toList(), _order);
    final byId = {for (final i in items) idOf(i): i};
    return [for (final id in ids) byId[id] as T];
  }

  /// Enregistre le nouvel ordre des modules visibles ; les modules masqués (droits) gardent leur rang relatif à la suite.
  Future<void> setOrder(List<String> visibleIds) async {
    _order = [...visibleIds, ..._order.where((id) => !visibleIds.contains(id))];
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _order);
  }

  Future<void> reset() async {
    _order = const [];
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
