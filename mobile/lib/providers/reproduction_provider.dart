import 'package:flutter/material.dart';
import '../models/couvee.dart';
import '../services/api_service.dart';

class ReproductionProvider with ChangeNotifier {
  List<Couvee> _couvees = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = false;
  String? _lastError;

  List<Couvee> get couvees => _couvees;
  Map<String, dynamic> get stats => _stats;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  List<Couvee> get actives =>
      _couvees.where((c) => c.statut != 'termine' && c.statut != 'annule').toList();
  List<Couvee> get historique =>
      _couvees.where((c) => c.statut == 'termine' || c.statut == 'annule').toList();

  Future<void> charger() async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      final data = await ApiService.getCouvees();
      _couvees = data.whereType<Map>().map((e) => Couvee.fromJson(Map<String, dynamic>.from(e))).toList();
      try {
        _stats = await ApiService.getCouveesStats();
      } catch (_) {
        _stats = {};
      }
    } catch (e) {
      _lastError = e.toString().replaceFirst('Exception: ', '');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> creer(Map<String, dynamic> data) async {
    try {
      _lastError = null;
      await ApiService.creerCouvee(data);
      await charger();
      return true;
    } catch (e) {
      _lastError = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> mettreAJour(String id, Map<String, dynamic> data) async {
    try {
      _lastError = null;
      await ApiService.mettreAJourCouvee(id, data);
      await charger();
      return true;
    } catch (e) {
      _lastError = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> supprimer(String id) async {
    try {
      _lastError = null;
      await ApiService.supprimerCouvee(id);
      await charger();
      return true;
    } catch (e) {
      _lastError = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }
}
