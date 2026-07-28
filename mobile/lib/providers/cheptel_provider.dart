import 'package:flutter/material.dart';
import '../models/cheptel.dart';
import '../services/api_service.dart';

class CheptelProvider with ChangeNotifier {
  List<Cheptel> _cheptels = [];
  bool _isLoading = false;
  String? _lastError;

  List<Cheptel> get cheptels => _cheptels;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  Future<void> charger() async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      final data = await ApiService.getCheptels();
      _cheptels = data.whereType<Map>().map((e) => Cheptel.fromJson(Map<String, dynamic>.from(e))).toList();
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

  Future<bool> creerCheptel(Map<String, dynamic> data) => _run(() => ApiService.creerCheptel(data));
  Future<bool> mettreAJourCheptel(String id, Map<String, dynamic> data) => _run(() => ApiService.mettreAJourCheptel(id, data));
  Future<bool> supprimerCheptel(String id) => _run(() => ApiService.supprimerCheptel(id));
  Future<bool> ajouterMouvement(String id, Map<String, dynamic> data) => _run(() => ApiService.ajouterMouvementCheptel(id, data));
  Future<bool> supprimerMouvement(String id, String mvtId) => _run(() => ApiService.supprimerMouvementCheptel(id, mvtId));
}
