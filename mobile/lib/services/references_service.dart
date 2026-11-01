import '../utils/bande_kpis.dart';
import 'api_service.dart';

/// Références théoriques (Configuration), chargées une fois par session ; valeurs par défaut en cas d'échec.
class ReferencesService {
  static Future<Map<String, ReferenceType>>? _cache;

  static Future<Map<String, ReferenceType>> charger({bool forcer = false}) {
    if (forcer || _cache == null) {
      _cache = ApiService.getConfig()
          .then((cfg) => parseReferences(cfg['referencesTheoriques']))
          .catchError((_) => Map<String, ReferenceType>.from(defaultReferences));
    }
    return _cache!;
  }

  /// À appeler après modification des références dans la Configuration.
  static void invalider() => _cache = null;
}
