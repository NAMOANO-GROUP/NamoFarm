import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class DashboardProvider with ChangeNotifier {
  DashboardProvider() {
    _restaurerFiltres();
  }

  Map<String, dynamic> _global = {};
  Map<String, dynamic> _crm = {};
  List<Map<String, dynamic>> _bandes = [];
  bool _isLoading = false;
  String? _lastError;
  bool _filtresRestaures = false;
  String _period = 'mois';
  String _selectedBandeId = '';
  String _selectedBatiment = '';
  DateTime? _specificDate;
  int? _specificMonth;
  int? _specificYear;

  Map<String, dynamic> get global => _global;
  Map<String, dynamic> get crm => _crm;
  List<Map<String, dynamic>> get bandes => _bandes;
  String? get lastError => _lastError;
  List<String> get batiments => _bandes
      .map((b) => (b['batiment'] ?? '').toString())
      .where((b) => b.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
  List<Map<String, dynamic>> get bandesFiltreesPourBatiment {
    if (_selectedBatiment.isEmpty) return _bandes;
    return _bandes.where((b) => (b['batiment'] ?? '').toString() == _selectedBatiment).toList();
  }
  bool get isLoading => _isLoading;
  String get period => _period;
  String get selectedBandeId => _selectedBandeId;
  String get selectedBatiment => _selectedBatiment;
  DateTime? get specificDate => _specificDate;
  int? get specificMonth => _specificMonth;
  int? get specificYear => _specificYear;
  bool get hasSpecificSelection => _specificDate != null || _specificMonth != null || _specificYear != null;

  Future<void> chargerDashboards({String? period, String? bandeId, String? batiment}) async {
    if (!_filtresRestaures) {
      await _restaurerFiltres(notify: false);
    }

    _isLoading = true;
    _lastError = null;
    if (period != null && period != _period) {
      _period = period;
      // Changing the granularity invalidates any exact day/month/year previously chosen.
      _specificDate = null;
      _specificMonth = null;
      _specificYear = null;
    }
    if (bandeId != null) {
      _selectedBandeId = bandeId;
    }
    if (batiment != null) {
      _selectedBatiment = batiment;
    }
    notifyListeners();

    if (_bandes.isEmpty) {
      try {
        final actives = await ApiService.getBandesActives();
        final historiques = await ApiService.getBandesHistorique();
        _bandes = [...actives, ...historiques]
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } catch (e) {
        _lastError = e.toString().replaceFirst('Exception: ', '').trim();
        debugPrint('Erreur chargement bandes dashboard: $e');
      }
    }

    _validerFiltresSelectionnes();
    await _sauvegarderFiltres();

    try {
      _global = await ApiService.getGlobalDashboard(
        period: _period,
        bandeId: _selectedBandeId.isEmpty ? null : _selectedBandeId,
        batiment: _selectedBatiment.isEmpty ? null : _selectedBatiment,
        date: _specificDate,
        month: _specificMonth,
        year: _specificYear,
      );
    } catch (e) {
      _global = {};
      _lastError = e.toString().replaceFirst('Exception: ', '').trim();
      debugPrint('Erreur dashboard global: $e');
    }

    try {
      _crm = await ApiService.getCrmDashboard();
    } catch (e) {
      _crm = {};
      _lastError ??= e.toString().replaceFirst('Exception: ', '').trim();
      debugPrint('Erreur dashboard CRM: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Sets an exact day (used when period == 'jour') and reloads.
  Future<void> definirJourPrecis(DateTime? date) async {
    _specificDate = date;
    _specificMonth = null;
    _specificYear = null;
    await chargerDashboards();
  }

  /// Sets an exact month + year (used when period == 'mois') and reloads.
  Future<void> definirMoisPrecis(int month, int year) async {
    _specificMonth = month;
    _specificYear = year;
    _specificDate = null;
    await chargerDashboards();
  }

  /// Sets an exact year (used when period == 'annee') and reloads.
  Future<void> definirAnneePrecise(int year) async {
    _specificYear = year;
    _specificMonth = null;
    _specificDate = null;
    await chargerDashboards();
  }

  /// Clears any exact day/month/year selection, reverting to the relative period.
  Future<void> effacerSelectionPrecise() async {
    _specificDate = null;
    _specificMonth = null;
    _specificYear = null;
    await chargerDashboards();
  }

  void _validerFiltresSelectionnes() {
    if (_selectedBatiment.isNotEmpty) {
      final batimentExiste = _bandes.any(
        (b) => (b['batiment'] ?? '').toString() == _selectedBatiment,
      );
      if (!batimentExiste) {
        _selectedBatiment = '';
      }
    }

    if (_selectedBatiment.isNotEmpty && _selectedBandeId.isNotEmpty) {
      final bandeToujoursValide = _bandes.any(
        (b) => (b['batiment'] ?? '').toString() == _selectedBatiment &&
            (b['id'] ?? b['_id']).toString() == _selectedBandeId,
      );
      if (!bandeToujoursValide) {
        _selectedBandeId = '';
      }
    }
  }

  Future<void> _restaurerFiltres({bool notify = true}) async {
    final prefs = await SharedPreferences.getInstance();
    _period = prefs.getString('dashboard.period') ?? 'mois';
    _selectedBatiment = prefs.getString('dashboard.selectedBatiment') ?? '';
    _selectedBandeId = prefs.getString('dashboard.selectedBandeId') ?? '';
    final savedDate = prefs.getString('dashboard.specificDate');
    _specificDate = savedDate != null && savedDate.isNotEmpty ? DateTime.tryParse(savedDate) : null;
    _specificMonth = prefs.getInt('dashboard.specificMonth');
    _specificYear = prefs.getInt('dashboard.specificYear');
    _filtresRestaures = true;
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> _sauvegarderFiltres() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dashboard.period', _period);
    await prefs.setString('dashboard.selectedBatiment', _selectedBatiment);
    await prefs.setString('dashboard.selectedBandeId', _selectedBandeId);
    if (_specificDate != null) {
      await prefs.setString('dashboard.specificDate', _specificDate!.toIso8601String());
    } else {
      await prefs.remove('dashboard.specificDate');
    }
    if (_specificMonth != null) {
      await prefs.setInt('dashboard.specificMonth', _specificMonth!);
    } else {
      await prefs.remove('dashboard.specificMonth');
    }
    if (_specificYear != null) {
      await prefs.setInt('dashboard.specificYear', _specificYear!);
    } else {
      await prefs.remove('dashboard.specificYear');
    }
  }
}
