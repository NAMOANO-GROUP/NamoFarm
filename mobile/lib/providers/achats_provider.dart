import 'package:flutter/foundation.dart';
import '../models/achat.dart';
import '../services/api_service.dart';

class AchatsProvider with ChangeNotifier {
  List<Achat> _achats = [];
  bool _loading = false;
  String? _error;

  List<Achat> get achats => _achats;
  bool get loading => _loading;
  String? get error => _error;

  List<Achat> get enAttente => _achats.where((a) => a.statut == 'en_attente').toList();
  List<Achat> get valides => _achats.where((a) => a.statut == 'valide').toList();
  List<Achat> get recus => _achats.where((a) => a.statut == 'recu').toList();
  List<Achat> get refuses => _achats.where((a) => a.statut == 'refuse').toList();

  Future<void> charger() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await ApiService.getAchats();
      _achats = data.map((e) => Achat.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    }
    _loading = false;
    notifyListeners();
  }

  Future<bool> creer(Map<String, dynamic> body) async {
    try {
      await ApiService.creerAchat(body);
      await charger();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> modifier(String id, Map<String, dynamic> body) async {
    try {
      await ApiService.modifierAchat(id, body);
      await charger();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> valider(String id, {String notes = ''}) async {
    try {
      await ApiService.validerAchat(id, notes: notes);
      await charger();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> refuser(String id, {String notes = ''}) async {
    try {
      await ApiService.refuserAchat(id, notes: notes);
      await charger();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> marquerRecu(String id, {required double quantiteRecue, double prixReel = 0, String notes = ''}) async {
    try {
      await ApiService.recevoirAchat(id, quantiteRecue: quantiteRecue, prixReel: prixReel, notes: notes);
      await charger();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> supprimer(String id) async {
    try {
      await ApiService.supprimerAchat(id);
      await charger();
      return true;
    } catch (_) {
      return false;
    }
  }
}
