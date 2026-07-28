import 'package:flutter/material.dart';
import '../models/sante.dart';
import '../services/api_service.dart';

class SanteProvider with ChangeNotifier {
  List<ProtocoleVaccinal> _protocoles = [];
  List<TraitementSanitaire> _traitements = [];
  bool _isLoading = false;
  String? _lastError;

  List<ProtocoleVaccinal> get protocoles => _protocoles;
  List<TraitementSanitaire> get traitements => _traitements;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  Future<void> charger() async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      final protos = await ApiService.getProtocoles();
      final traits = await ApiService.getTraitements();
      _protocoles = protos.whereType<Map>().map((e) => ProtocoleVaccinal.fromJson(Map<String, dynamic>.from(e))).toList();
      _traitements = traits.whereType<Map>().map((e) => TraitementSanitaire.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      _lastError = e.toString().replaceFirst('Exception: ', '');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> _run(Future<void> Function() action) async {
    try {
      _lastError = null;
      await action();
      await charger();
      return true;
    } catch (e) {
      _lastError = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> creerProtocole(Map<String, dynamic> data) => _run(() => ApiService.creerProtocole(data));
  Future<bool> mettreAJourProtocole(String id, Map<String, dynamic> data) => _run(() => ApiService.mettreAJourProtocole(id, data));
  Future<bool> supprimerProtocole(String id) => _run(() => ApiService.supprimerProtocole(id));

  Future<bool> creerTraitement(Map<String, dynamic> data) => _run(() => ApiService.creerTraitement(data));
  Future<bool> mettreAJourTraitement(String id, Map<String, dynamic> data) => _run(() => ApiService.mettreAJourTraitement(id, data));
  Future<bool> supprimerTraitement(String id) => _run(() => ApiService.supprimerTraitement(id));
}
