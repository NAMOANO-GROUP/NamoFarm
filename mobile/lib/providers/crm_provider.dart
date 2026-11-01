import 'package:flutter/material.dart';
import '../models/crm_pipeline.dart';
import '../models/interaction.dart';
import '../models/tache_crm.dart';
import '../services/api_service.dart';
import '../utils/crm_labels.dart';

class CrmProvider with ChangeNotifier {
  List<Interaction> _interactions = [];
  String? _interactionsClientId;
  List<TacheCRM> _taches = [];
  List<PipelineDeal> _deals = [];
  List<Map<String, dynamic>> _pipelineStages = [];
  List<Map<String, dynamic>> _leadSources = [];
  double _conversionRate = 0;
  double _montantOuvert = 0;
  double _previsionPonderee = 0;
  CrmDashboardData? _dashboard;
  List<CrmSuggestion> _suggestions = [];
  final Set<String> _suggestionsIgnorees = {};
  bool _isLoading = false;
  bool _tachesLoading = false;
  bool _interactionsLoading = false;
  String? _lastError;

  List<Interaction> get interactions => _interactions;
  String? get interactionsClientId => _interactionsClientId;
  List<TacheCRM> get taches => _taches;
  List<PipelineDeal> get deals => _deals;
  List<Map<String, dynamic>> get pipelineStages => _pipelineStages;
  List<Map<String, dynamic>> get leadSources => _leadSources;
  double get conversionRate => _conversionRate;
  double get montantOuvert => _montantOuvert;
  double get previsionPonderee => _previsionPonderee;
  CrmDashboardData? get dashboard => _dashboard;
  List<CrmSuggestion> get suggestions => _suggestions.where((s) => !_suggestionsIgnorees.contains(s.id)).toList();
  bool get isLoading => _isLoading;
  bool get tachesLoading => _tachesLoading;
  bool get interactionsLoading => _interactionsLoading;
  String? get lastError => _lastError;

  PipelineDeal? dealPourClient(String clientId) {
    for (final d in deals) {
      if (d.clientId == clientId) return d;
    }
    return null;
  }

  List<TacheCRM> tachesPourClient(String clientId) => taches.where((t) => t.clientId == clientId).toList();

  Future<void> chargerTout() async {
    await Future.wait([chargerTachesCrm(), chargerPipelineCommercial(), chargerDashboard(), chargerSuggestions()]);
  }

  Future<void> chargerInteractionsClient(String clientId) async {
    if (_interactionsClientId != clientId) _interactions = [];
    _interactionsClientId = clientId;
    _interactionsLoading = true;
    notifyListeners();
    try {
      final data = await ApiService.getInteractionsClient(clientId);
      // Une autre fiche a pu être ouverte entre-temps : on ignore cette réponse périmée.
      if (_interactionsClientId != clientId) return;
      _interactions = data.map((j) => Interaction.fromJson(j)).toList();
      _lastError = null;
    } catch (e) {
      if (_interactionsClientId != clientId) return;
      _lastError = e.toString();
      debugPrint('Erreur interactions: $e');
    }
    _interactionsLoading = false;
    notifyListeners();
  }

  Future<bool> ajouterInteractionClient(String clientId, Map<String, dynamic> data) async {
    try {
      await ApiService.ajouterInteractionClient(clientId, data);
      await chargerInteractionsClient(clientId);
      return true;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Erreur ajout interaction: $e');
      return false;
    }
  }

  Future<void> chargerTachesCrm() async {
    _tachesLoading = true;
    notifyListeners();
    try {
      final data = await ApiService.getTachesCrm();
      _taches = data.map((j) => TacheCRM.fromJson(j)).toList();
      _lastError = null;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Erreur tâches: $e');
    }
    _tachesLoading = false;
    notifyListeners();
  }

  Future<bool> creerTache(Map<String, dynamic> data) async {
    try {
      await ApiService.creerTacheCrm(data);
      await chargerTachesCrm();
      return true;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Erreur création tâche: $e');
      return false;
    }
  }

  Future<bool> mettreAJourTache(String id, Map<String, dynamic> data) async {
    try {
      await ApiService.mettreAJourTacheCrm(id, data);
      await chargerTachesCrm();
      return true;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Erreur MAJ tâche: $e');
      return false;
    }
  }

  void _remplacerTache(TacheCRM t) {
    final i = _taches.indexWhere((x) => x.id == t.id);
    if (i >= 0) _taches = [..._taches]..[i] = t;
  }

  /// Mise à jour optimiste : l'écran change tout de suite, puis revient en arrière en cas d'échec.
  Future<bool> modifierTacheLocalement(TacheCRM avant, TacheCRM apres, Map<String, dynamic> payload) async {
    if (avant.id == null) return false;
    _remplacerTache(apres);
    notifyListeners();
    try {
      await ApiService.mettreAJourTacheCrm(avant.id!, payload);
      return true;
    } catch (e) {
      _lastError = e.toString();
      _remplacerTache(avant);
      notifyListeners();
      return false;
    }
  }

  Future<bool> changerStatutTache(TacheCRM t, String statut) =>
      modifierTacheLocalement(t, t.copyWith(statut: statut), {'statut': statut});

  Future<bool> changerEcheanceTache(TacheCRM t, DateTime date) =>
      modifierTacheLocalement(t, t.copyWith(dateEcheance: date), {'dateEcheance': date.toUtc().toIso8601String()});

  Future<bool> basculerChecklist(TacheCRM t, int index) {
    final items = [...t.checklist];
    items[index] = items[index].copyWith(fait: !items[index].fait);
    return modifierTacheLocalement(
      t,
      t.copyWith(checklist: items),
      {'checklist': items.map((c) => c.toJson()).toList()},
    );
  }

  Future<bool> supprimerTache(String id) async {
    try {
      await ApiService.supprimerTacheCrm(id);
      await chargerTachesCrm();
      return true;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Erreur suppression tâche: $e');
      return false;
    }
  }

  Future<bool> effacerHistoriqueTaches() async {
    try {
      await ApiService.effacerHistoriqueTachesCrm();
      await chargerTachesCrm();
      return true;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Erreur historique CRM: $e');
      return false;
    }
  }

  Future<void> chargerPipelineCommercial() async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await ApiService.getPipelineCommercial();
      _deals = (data['pipeline'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => PipelineDeal.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      _pipelineStages = List<Map<String, dynamic>>.from(
        (data['stages'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
      );
      _leadSources = List<Map<String, dynamic>>.from(
        (data['sources'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
      );
      _conversionRate = ((data['conversionRate'] ?? 0) as num).toDouble();
      _montantOuvert = ((data['montantOuvert'] ?? 0) as num).toDouble();
      _previsionPonderee = ((data['previsionPonderee'] ?? 0) as num).toDouble();
      _lastError = null;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Erreur pipeline: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> mettreAJourPipelineClient(String clientId, Map<String, dynamic> payload) async {
    try {
      await ApiService.mettreAJourPipelineClient(clientId, payload);
      await chargerPipelineCommercial();
      return true;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Erreur mise a jour pipeline: $e');
      return false;
    }
  }

  /// Déplacement d'une carte du tableau : affichage immédiat, puis synchronisation.
  Future<bool> deplacerDeal(PipelineDeal deal, String stage) async {
    if (deal.stage == stage) return true;
    final index = _deals.indexWhere((d) => d.clientId == deal.clientId);
    if (index < 0) return false;
    // Comme dans HubSpot, la probabilité suit l'étape lors d'un déplacement.
    final moved = deal.copyWith(stage: stage, probabilite: (defaultStageProbability[stage] ?? deal.probabilite).toDouble());
    _deals = [..._deals]..[index] = moved;
    notifyListeners();
    final ok = await mettreAJourPipelineClient(deal.clientId, moved.toUpdatePayload());
    if (!ok) {
      final i = _deals.indexWhere((d) => d.clientId == deal.clientId);
      if (i >= 0) _deals = [..._deals]..[i] = deal;
      notifyListeners();
    }
    return ok;
  }

  /// Rétablit une affaire telle qu'elle était (annulation d'un déplacement), probabilité comprise.
  Future<bool> restaurerDeal(PipelineDeal original) async {
    final index = deals.indexWhere((d) => d.clientId == original.clientId);
    if (index >= 0) {
      _deals = [...deals]..[index] = original;
      notifyListeners();
    }
    return mettreAJourPipelineClient(original.clientId, original.toUpdatePayload());
  }

  Future<void> chargerDashboard() async {
    try {
      _dashboard = CrmDashboardData.fromJson(await ApiService.getCrmDashboard());
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Erreur dashboard CRM: $e');
    }
    notifyListeners();
  }

  Future<void> chargerSuggestions() async {
    try {
      final data = await ApiService.getSuggestionsCrm();
      _suggestions = data.whereType<Map>().map((e) => CrmSuggestion.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      debugPrint('Erreur suggestions CRM: $e');
    }
    notifyListeners();
  }

  void ignorerSuggestion(CrmSuggestion s) {
    _suggestionsIgnorees.add(s.id);
    notifyListeners();
  }

  Future<bool> appliquerSuggestion(CrmSuggestion s, {String assigneA = ''}) async {
    final ok = await creerTache(s.toTachePayload(assigneA: assigneA));
    if (ok) {
      _suggestions = _suggestions.where((x) => x.clientId != s.clientId).toList();
      notifyListeners();
    }
    return ok;
  }
}
