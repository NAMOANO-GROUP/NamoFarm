import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/finance.dart';

class FinanceProvider with ChangeNotifier {
  bool _isLoading = false;
  String? _lastError;
  Map<String, dynamic> _solde = {'totalEntrees': 0.0, 'totalSorties': 0.0, 'soldeCaisse': 0.0};
  List<Map<String, dynamic>> _mouvements = [];
  final Set<String> _sourceFilters = <String>{};
  final Set<int> _weekdayFilters = <int>{};
  int? _monthFilter;
  int? _yearFilter;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  Map<String, dynamic> _rapprochement = {};
  Map<String, dynamic> _budgetPrevisionnel = {};
  List<Map<String, dynamic>> _margesBandes = [];
  Map<String, dynamic> _projectionTresorerie = {};
  Map<String, dynamic> _depensesParCategorie = {};

  // Accueil Finance (6 derniers mois) et bandes.
  bool _accueilLoading = false;
  bool _accueilCharge = false;
  List<Mouvement> _mouvementsRecents = [];
  List<Map<String, dynamic>> _analytiqueBandes = [];
  Map<String, dynamic> _analytiqueTotaux = {};
  List<Map<String, dynamic>> _bandes = [];
  bool _soldeErreur = false;
  bool _mouvementsErreur = false;
  bool _accueilTronque = false;

  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  Map<String, dynamic> get solde => _solde;
  List<Map<String, dynamic>> get mouvements => _mouvements;
  Set<String> get sourceFilters => _sourceFilters;
  Set<int> get weekdayFilters => _weekdayFilters;
  int? get monthFilter => _monthFilter;
  int? get yearFilter => _yearFilter;
  DateTime? get dateFrom => _dateFrom;
  DateTime? get dateTo => _dateTo;
  Map<String, dynamic> get rapprochement => _rapprochement;
  Map<String, dynamic> get budgetPrevisionnel => _budgetPrevisionnel;
  List<Map<String, dynamic>> get margesBandes => _margesBandes;
  Map<String, dynamic> get projectionTresorerie => _projectionTresorerie;
  Map<String, dynamic> get depensesParCategorie => _depensesParCategorie;
  bool get accueilLoading => _accueilLoading;
  bool get accueilCharge => _accueilCharge;
  List<Mouvement> get mouvementsRecents => _mouvementsRecents;
  List<Map<String, dynamic>> get analytiqueBandes => _analytiqueBandes;
  Map<String, dynamic> get analytiqueTotaux => _analytiqueTotaux;

  /// Bandes actives puis historiques (pour l'affectation d'une dépense).
  List<Map<String, dynamic>> get bandes => _bandes;
  List<Map<String, dynamic>> get bandesOuvertes =>
      bandes.where((b) => (b['statut'] ?? 'ouverte').toString() != 'fermee').toList();
  bool get soldeErreur => _soldeErreur;
  bool get mouvementsErreur => _mouvementsErreur;

  /// Un des 6 mois a atteint la limite de 1000 mouvements : totaux de ce mois incomplets.
  bool get accueilTronque => _accueilTronque;

  String nomBande(String id) {
    if (id.isEmpty) return '';
    for (final b in bandes) {
      if ((b['_id'] ?? b['id'] ?? '').toString() == id) return (b['nom'] ?? 'Bande').toString();
    }
    return '';
  }

  /// Solde projeté dans 3 mois (null si la projection n'est pas disponible).
  double? get soldeDans3Mois {
    final list = _projectionTresorerie['projection'];
    if (list is! List || list.length < 3 || list[2] is! Map) return null;
    final v = (list[2] as Map)['soldeProjete'];
    return v is num ? v.toDouble() : null;
  }

  static double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

  int _accueilSeq = 0;
  int _journalSeq = 0;

  /// Charge tout ce dont l'accueil a besoin ; chaque bloc échoue sans bloquer les autres.
  /// Les mouvements sont demandés mois par mois (1000 au plus par mois) pour que les
  /// totaux des 6 mois restent justes même pour une ferme très active.
  Future<void> chargerAccueil({DateTime? now}) async {
    final seq = ++_accueilSeq;
    _accueilLoading = true;
    notifyListeners();
    final today = now ?? DateTime.now();
    Future<T?> essai<T>(Future<T> Function() f) async {
      try {
        return await f();
      } catch (_) {
        return null;
      }
    }

    final mois = [for (var i = 5; i >= 0; i--) DateTime(today.year, today.month - i, 1)];
    final results = await Future.wait<dynamic>([
      essai(ApiService.getSoldeTresorerie),
      essai(() => ApiService.getProjectionTresorerie(months: 3)),
      essai(ApiService.getComptabiliteAnalytique),
      essai(ApiService.getBandesActives),
      essai(ApiService.getBandesHistorique),
      for (final m in mois)
        essai(
          () => ApiService.getMouvementsTresorerie(limit: 1000, dateFrom: m, dateTo: DateTime(m.year, m.month + 1, 0)),
        ),
    ]);
    if (seq != _accueilSeq) return;

    final soldeData = results[0];
    _soldeErreur = soldeData is! Map;
    if (soldeData is Map) {
      _solde = {
        'totalEntrees': _d(soldeData['totalEntrees']),
        'totalSorties': _d(soldeData['totalSorties']),
        'soldeCaisse': _d(soldeData['soldeCaisse']),
      };
    }
    if (results[1] is Map) _projectionTresorerie = Map<String, dynamic>.from(results[1] as Map);
    if (results[2] is Map) {
      final a = results[2] as Map;
      _analytiqueBandes = (a['bandes'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      _analytiqueTotaux = a['totaux'] is Map ? Map<String, dynamic>.from(a['totaux'] as Map) : {};
    }
    if (results[3] is List || results[4] is List) {
      final vus = <String>{};
      _bandes = [...(results[3] as List? ?? const []), ...(results[4] as List? ?? const [])]
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((b) => vus.add((b['_id'] ?? b['id'] ?? '').toString()))
          .toList();
    }
    final pages = results.sublist(5);
    _mouvementsErreur = pages.any((r) => r is! List);
    if (!_mouvementsErreur) {
      _mouvementsRecents = [for (final r in pages) ...parseMouvements(r as List)];
      _accueilTronque = pages.any((r) => (r as List).length >= 1000);
    }
    _accueilLoading = false;
    _accueilCharge = true;
    notifyListeners();
  }

  /// Applique d'un coup les filtres du journal (un seul rechargement).
  Future<void> appliquerFiltresJournal({Iterable<String> sources = const [], DateTime? from, DateTime? to}) async {
    _sourceFilters
      ..clear()
      ..addAll(sources.where((s) => s.trim().isNotEmpty));
    _weekdayFilters.clear();
    _monthFilter = null;
    _yearFilter = null;
    _dateFrom = from;
    _dateTo = to;
    await chargerTresorerie();
  }

  /// Recharge le journal et l'accueil après une saisie.
  Future<void> _rafraichir() => Future.wait([chargerTresorerie(), if (_accueilCharge) chargerAccueil()]);

  Future<void> chargerTresorerie() async {
    final seq = ++_journalSeq;
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      final soldeData = await ApiService.getSoldeTresorerie();
      final mouvementsData = await ApiService.getMouvementsTresorerie(
        limit: 1000,
        sources: _sourceFilters.toList(),
        weekdays: _weekdayFilters.toList(),
        month: _monthFilter,
        year: _yearFilter,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      );
      // Une demande plus récente (autre filtre) est en cours : sa réponse fera foi.
      if (seq != _journalSeq) return;
      _solde = {
        'totalEntrees': _d(soldeData['totalEntrees']),
        'totalSorties': _d(soldeData['totalSorties']),
        'soldeCaisse': _d(soldeData['soldeCaisse']),
      };
      _mouvements = mouvementsData.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      if (seq != _journalSeq) return;
      _lastError = e.toString().replaceFirst('Exception: ', '');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> chargerAnalysesAvancees({int months = 6}) async {
    _lastError = null;
    notifyListeners();
    try {
      final rapprochementData = await ApiService.getRapprochementCaisseBanques(dateFrom: _dateFrom, dateTo: _dateTo);
      final budgetData = await ApiService.getBudgetPrevisionnel(months: months);
      final margesData = await ApiService.getMargeParBande();
      final projectionData = await ApiService.getProjectionTresorerie(months: months);
      final categoriesData = await ApiService.getDepensesParCategorie(dateFrom: _dateFrom, dateTo: _dateTo);

      _rapprochement = Map<String, dynamic>.from(rapprochementData);
      _budgetPrevisionnel = Map<String, dynamic>.from(budgetData);
      _margesBandes = margesData.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      _projectionTresorerie = Map<String, dynamic>.from(projectionData);
      _depensesParCategorie = Map<String, dynamic>.from(categoriesData);
    } catch (e) {
      _lastError = e.toString().replaceFirst('Exception: ', '');
    }
    notifyListeners();
  }

  Future<void> toggleSourceFilter(String source) async {
    if (_sourceFilters.contains(source)) {
      _sourceFilters.remove(source);
    } else {
      _sourceFilters.add(source);
    }
    await chargerTresorerie();
  }

  Future<void> setSourceFilters(Iterable<String> sources) async {
    _sourceFilters
      ..clear()
      ..addAll(sources.where((s) => s.trim().isNotEmpty));
    await chargerTresorerie();
  }

  Future<void> toggleWeekdayFilter(int isoWeekday) async {
    if (_weekdayFilters.contains(isoWeekday)) {
      _weekdayFilters.remove(isoWeekday);
    } else {
      _weekdayFilters.add(isoWeekday);
    }
    await chargerTresorerie();
  }

  Future<void> setWeekdayFilters(Iterable<int> weekdays) async {
    _weekdayFilters
      ..clear()
      ..addAll(weekdays.where((d) => d >= 1 && d <= 7));
    await chargerTresorerie();
  }

  Future<void> setMonthFilter(int? month) async {
    _monthFilter = month;
    await chargerTresorerie();
  }

  Future<void> setYearFilter(int? year) async {
    _yearFilter = year;
    await chargerTresorerie();
  }

  Future<void> setDateRange(DateTime? from, DateTime? to) async {
    _dateFrom = from;
    _dateTo = to;
    await chargerTresorerie();
  }

  Future<void> clearDateRange() async {
    _dateFrom = null;
    _dateTo = null;
    await chargerTresorerie();
  }

  Future<void> clearAllFilters() async {
    _sourceFilters.clear();
    _weekdayFilters.clear();
    _monthFilter = null;
    _yearFilter = null;
    _dateFrom = null;
    _dateTo = null;
    await chargerTresorerie();
  }

  Future<bool> ajouterDepense(Map<String, dynamic> payload) async {
    try {
      await ApiService.creerDepenseTresorerie(payload);
      await _rafraichir();
      return true;
    } catch (e) {
      _lastError = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> ajouterApprovisionnement(Map<String, dynamic> payload) async {
    try {
      await ApiService.creerApprovisionnementTresorerie(payload);
      await _rafraichir();
      return true;
    } catch (e) {
      _lastError = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> effacerHistoriqueMouvements() async {
    try {
      _lastError = null;
      await ApiService.effacerHistoriqueMouvementsTresorerie();
      await _rafraichir();
      return true;
    } catch (e) {
      _lastError = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> supprimerMouvement(String id) async {
    try {
      _lastError = null;
      await ApiService.supprimerMouvementTresorerie(id);
      await _rafraichir();
      return true;
    } catch (e) {
      _lastError = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> modifierMouvement(String id, Map<String, dynamic> payload) async {
    try {
      _lastError = null;
      await ApiService.modifierMouvementTresorerie(id, payload);
      await _rafraichir();
      return true;
    } catch (e) {
      _lastError = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }
}
