import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alerte.dart';
import '../services/api_service.dart';

class AlertesProvider with ChangeNotifier {
  List<Alerte> _alertes = [];
  List<Alerte> _alertesAutomatiques = [];
  List<Alerte> _automatiquesBrutes = [];
  List<Alerte> _historiqueAlertes = [];
  List<Alerte> _historiqueAlertesAutomatiques = [];
  Set<String> _dismissedAutoAlertKeys = {};
  bool _isLoading = false;
  String _todoPeriod = 'all';

  static const String _dismissedAutoAlertPrefsKey = 'alertes.dismissedAutoDaily';

  List<Alerte> get alertes => _alertes;
  List<Alerte> get alertesAutomatiques => _alertesAutomatiques;
  List<Alerte> get historiqueAlertes => _historiqueAlertes;
  List<Alerte> get historiqueAlertesAutomatiques => _historiqueAlertesAutomatiques;
  bool get isLoading => _isLoading;
  String get todoPeriod => _todoPeriod;

  Future<void> chargerAlertes({String? period}) async {
    await _loadDismissedAutoAlerts();
    _isLoading = true;
    if (period != null) {
      _todoPeriod = period;
    }
    notifyListeners();
    try {
      final data = await ApiService.getAlertesActives(period: _todoPeriod);
      _alertes = data.map((json) => Alerte.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Erreur: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> chargerAlertesAutomatiques() async {
    await _loadDismissedAutoAlerts();
    _isLoading = true;
    notifyListeners();
    try {
      final data = await ApiService.getAlertesAutomatiques();
      _automatiquesBrutes = data.map((json) => Alerte.fromJson(json)).toList();
      _alertesAutomatiques = _automatiquesBrutes
          .where((a) => !_dismissedAutoAlertKeys.contains(_dismissKeyForToday(a.id)))
          .toList();
    } catch (e) {
      debugPrint('Erreur: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> chargerHistoriqueAlertes() async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await ApiService.getHistoriqueAlertes();
      _historiqueAlertes = data.map((json) => Alerte.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Erreur: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> chargerHistoriqueAlertesAutomatiques() async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await ApiService.getHistoriqueAlertesAutomatiques();
      _historiqueAlertesAutomatiques = data.map((json) => Alerte.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Erreur: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> creerAlerte(Map<String, dynamic> data) async {
    try {
      await ApiService.creerAlerte(data);
      await chargerAlertes();
      await chargerHistoriqueAlertes();
      return true;
    } catch (e) {
      debugPrint('Erreur: $e');
      return false;
    }
  }

  Future<bool> marquerFaite(Alerte alerte) async {
    try {
      await _loadDismissedAutoAlerts();
      await ApiService.marquerAlerteFaite(
        alerte.id ?? '',
        data: {
          'titre': alerte.titre,
          'message': alerte.message,
          'type': alerte.type,
          'dateEcheance': alerte.dateEcheance.toIso8601String(),
          'priorite': alerte.priorite,
          'source': alerte.source,
        },
      );
      if (alerte.automatique || _isSyntheticAlerteId(alerte.id)) {
        _dismissedAutoAlertKeys.add(_dismissKeyForToday(alerte.id));
        await _saveDismissedAutoAlerts();
      }
      await chargerAlertes();
      await chargerAlertesAutomatiques();
      await chargerHistoriqueAlertes();
      await chargerHistoriqueAlertesAutomatiques();
      return true;
    } catch (e) {
      debugPrint('Erreur: $e');
      return false;
    }
  }

  Future<bool> mettreAJourAlerte(String id, Map<String, dynamic> data) async {
    try {
      await ApiService.mettreAJourAlerte(id, data);
      await chargerAlertes(period: _todoPeriod);
      await chargerHistoriqueAlertes();
      return true;
    } catch (e) {
      debugPrint('Erreur MAJ alerte: $e');
      return false;
    }
  }

  Future<bool> effacerHistorique() async {
    try {
      await ApiService.effacerHistoriqueAlertes();
      await chargerHistoriqueAlertes();
      await chargerAlertes(period: _todoPeriod);
      return true;
    } catch (e) {
      debugPrint('Erreur: $e');
      return false;
    }
  }

  Future<void> chargerTout() async {
    await Future.wait([
      chargerAlertes(period: 'all'),
      chargerAlertesAutomatiques(),
      chargerHistoriqueAlertes(),
      chargerHistoriqueAlertesAutomatiques(),
    ]);
  }

  void _remplacer(Alerte a) {
    final i = _alertes.indexWhere((x) => x.id == a.id);
    if (i >= 0) _alertes = [..._alertes]..[i] = a;
  }

  /// Mise à jour optimiste d'une tâche manuelle : affichage immédiat, retour arrière en cas d'échec.
  Future<bool> modifierLocalement(Alerte avant, Alerte apres, Map<String, dynamic> payload) async {
    if (!avant.modifiable) return false;
    _remplacer(apres);
    notifyListeners();
    try {
      await ApiService.mettreAJourAlerte(avant.id!, payload);
      return true;
    } catch (e) {
      debugPrint('Erreur MAJ alerte: $e');
      _remplacer(avant);
      notifyListeners();
      return false;
    }
  }

  Future<bool> changerProgression(Alerte a, String progression) =>
      modifierLocalement(a, a.copyWith(progression: progression), {'progression': progression});

  /// Déplace l'échéance en conservant la durée de la tâche.
  Future<bool> changerEcheance(Alerte a, DateTime debut) {
    final duree = a.dateFin?.difference(a.dateEcheance);
    final fin = duree == null ? null : debut.add(duree);
    return modifierLocalement(
      a,
      a.copyWith(dateEcheance: debut, dateFin: fin),
      {'dateEcheance': debut.toIso8601String(), if (fin != null) 'dateFin': fin.toIso8601String()},
    );
  }

  Future<bool> reporterADemain(Alerte a) => changerEcheance(a, a.dateEcheance.add(const Duration(days: 1)));

  Future<bool> changerType(Alerte a, String type) => modifierLocalement(a, a.copyWith(type: type), {'type': type});

  Future<bool> changerBande(Alerte a, String? bandeId, String bandeNom) => modifierLocalement(
        a,
        bandeId == null ? a.copyWith(clearBande: true) : a.copyWith(bandeId: bandeId, bandeNom: bandeNom),
        {'bandeId': bandeId},
      );

  Future<bool> basculerChecklist(Alerte a, int index) {
    final items = [...a.checklist];
    items[index] = items[index].copyWith(fait: !items[index].fait);
    return modifierLocalement(a, a.copyWith(checklist: items), {'checklist': items.map((c) => c.toJson()).toList()});
  }

  /// Termine une tâche. Renvoie (ok, id de l'occurrence suivante créée pour une tâche périodique).
  Future<({bool ok, String? prochaineId})> terminer(Alerte a) async {
    if (!a.modifiable) return (ok: await marquerFaite(a), prochaineId: null);
    _alertes = _alertes.where((x) => x.id != a.id).toList();
    _historiqueAlertes = [a.copyWith(statut: 'faite'), ..._historiqueAlertes];
    notifyListeners();
    try {
      final res = await ApiService.marquerAlerteFaite(a.id!);
      await Future.wait([chargerAlertes(), chargerHistoriqueAlertes()]);
      return (ok: true, prochaineId: res['prochaineId']?.toString());
    } catch (e) {
      debugPrint('Erreur: $e');
      await Future.wait([chargerAlertes(), chargerHistoriqueAlertes()]);
      return (ok: false, prochaineId: null);
    }
  }

  /// Annule une fin de tâche : la rouvre et supprime l'occurrence suivante éventuellement créée (un seul appel).
  Future<bool> rouvrir(Alerte a, {String? prochaineId}) async {
    if (a.id == null) return false;
    if (a.automatique) return _rouvrirAutomatique(a);
    var ok = true;
    try {
      await ApiService.rouvrirAlerte(a.id!, prochaineId: prochaineId);
    } catch (e) {
      debugPrint('Erreur: $e');
      ok = false;
    }
    await Future.wait([chargerAlertes(), chargerHistoriqueAlertes()]);
    return ok;
  }

  /// Décoche une tâche automatique terminée : supprime son archive et la fait réapparaître dès aujourd'hui.
  Future<bool> _rouvrirAutomatique(Alerte a) async {
    if (_isSyntheticAlerteId(a.id)) return false;
    try {
      await ApiService.rouvrirAlerte(a.id!);
    } catch (e) {
      debugPrint('Erreur: $e');
      return false;
    }
    await _loadDismissedAutoAlerts();
    final memes = _automatiquesBrutes.where((x) => x.titre == a.titre && x.source == a.source).toList();
    final memeDate = memes.where((x) => x.dateEcheance.isAtSameMomentAs(a.dateEcheance)).toList();
    for (final x in memeDate.isNotEmpty ? memeDate : memes) {
      _dismissedAutoAlertKeys.remove(_dismissKeyForToday(x.id));
    }
    await _saveDismissedAutoAlerts();
    await Future.wait([chargerAlertesAutomatiques(), chargerHistoriqueAlertesAutomatiques()]);
    return true;
  }

  Future<bool> supprimer(Alerte a) async {
    if (a.id == null || a.automatique) return false;
    try {
      await ApiService.supprimerAlerte(a.id!);
      await Future.wait([chargerAlertes(), chargerHistoriqueAlertes()]);
      return true;
    } catch (e) {
      debugPrint('Erreur suppression alerte: $e');
      return false;
    }
  }

  /// Crée plusieurs tâches d'un coup (modèles) puis recharge une seule fois. Renvoie le nombre créé.
  Future<int> creerPlusieurs(List<Map<String, dynamic>> taches) async {
    var created = 0;
    for (final t in taches) {
      try {
        await ApiService.creerAlerte(t);
        created++;
      } catch (e) {
        debugPrint('Erreur création (modèle): $e');
      }
    }
    await chargerAlertes();
    return created;
  }

  bool _isSyntheticAlerteId(String? id) {
    if (id == null || id.isEmpty) return false;
    return id.startsWith('stock-')
        || id.startsWith('sanitaire-')
        || id.startsWith('prevision-')
        || id.startsWith('commercial-')
        || id.startsWith('crm-task-');
  }

  String _todayStamp() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  String _dismissKeyForToday(String? id) {
    return '${id ?? ''}|${_todayStamp()}';
  }

  Future<void> _loadDismissedAutoAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_dismissedAutoAlertPrefsKey) ?? const [];
    final today = _todayStamp();
    _dismissedAutoAlertKeys = stored.where((x) => x.endsWith('|$today')).toSet();
    await prefs.setStringList(_dismissedAutoAlertPrefsKey, _dismissedAutoAlertKeys.toList());
  }

  Future<void> _saveDismissedAutoAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_dismissedAutoAlertPrefsKey, _dismissedAutoAlertKeys.toList());
  }
}
