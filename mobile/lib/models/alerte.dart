import 'tache_crm.dart' show ChecklistItem;

export 'tache_crm.dart' show ChecklistItem;

class Alerte {
  final String? id;
  final String titre;
  final String message;
  final String type;
  final DateTime dateEcheance;
  final DateTime? dateFin;
  final bool touteJournee;
  final String? bandeId;
  final String bandeNom;
  final String statut;
  final String recurrence;
  final Map<String, dynamic> recurrenceConfig;
  final String priorite;
  final String source;
  final bool automatique;
  final String assigneA;
  final List<ChecklistItem> checklist;

  /// Avancement façon Planner : 'a_faire' ou 'en_cours' (une tâche faite a le statut 'faite').
  final String progression;

  /// Objet d'origine d'une tâche automatique (pour l'ouvrir depuis la carte).
  final String? stockId;
  final String? clientId;
  final String? crmTacheId;

  Alerte({
    this.id,
    required this.titre,
    required this.message,
    required this.type,
    required this.dateEcheance,
    this.dateFin,
    this.touteJournee = false,
    this.bandeId,
    this.bandeNom = '',
    this.statut = 'active',
    this.recurrence = 'aucune',
    this.recurrenceConfig = const {},
    this.priorite = 'moyenne',
    this.source = '',
    this.automatique = false,
    this.assigneA = '',
    this.checklist = const [],
    this.progression = 'a_faire',
    this.stockId,
    this.clientId,
    this.crmTacheId,
  });

  factory Alerte.fromJson(Map<String, dynamic> json) {
    final bande = json['bandeId'];
    return Alerte(
      id: (json['_id'] ?? json['id'])?.toString(),
      titre: json['titre'],
      message: json['message'],
      type: json['type'],
      dateEcheance: DateTime.parse(json['dateEcheance']),
      dateFin: json['dateFin'] != null ? DateTime.tryParse(json['dateFin'].toString()) : null,
      touteJournee: json['touteJournee'] == true,
      bandeId: bande is String ? bande : bande?['_id']?.toString(),
      bandeNom: bande is Map ? (bande['nom'] ?? '').toString() : '',
      statut: json['statut'] ?? 'active',
      recurrence: json['recurrence'] ?? 'aucune',
      recurrenceConfig: json['recurrenceConfig'] is Map ? Map<String, dynamic>.from(json['recurrenceConfig']) : const {},
      priorite: json['priorite'] ?? 'moyenne',
      source: json['source'] ?? '',
      automatique: json['automatique'] ?? false,
      assigneA: (json['assigneA'] ?? '').toString(),
      checklist: (json['checklist'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => ChecklistItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      progression: json['progression'] == 'en_cours' ? 'en_cours' : 'a_faire',
      stockId: json['stockId']?.toString(),
      clientId: json['clientId']?.toString(),
      crmTacheId: json['crmTacheId']?.toString(),
    );
  }

  bool get estFaite => statut == 'faite';

  /// Les tâches saisies dans la Todo sont modifiables ; les automatiques sont calculées par les règles.
  bool get modifiable => !automatique && id != null;

  int get checklistFaits => checklist.where((c) => c.fait).length;

  Alerte copyWith({
    String? statut,
    String? progression,
    DateTime? dateEcheance,
    DateTime? dateFin,
    String? type,
    String? bandeId,
    String? bandeNom,
    bool clearBande = false,
    List<ChecklistItem>? checklist,
  }) {
    return Alerte(
      id: id,
      titre: titre,
      message: message,
      type: type ?? this.type,
      dateEcheance: dateEcheance ?? this.dateEcheance,
      dateFin: dateFin ?? this.dateFin,
      touteJournee: touteJournee,
      bandeId: clearBande ? null : (bandeId ?? this.bandeId),
      bandeNom: clearBande ? '' : (bandeNom ?? this.bandeNom),
      statut: statut ?? this.statut,
      recurrence: recurrence,
      recurrenceConfig: recurrenceConfig,
      priorite: priorite,
      source: source,
      automatique: automatique,
      assigneA: assigneA,
      checklist: checklist ?? this.checklist,
      progression: progression ?? this.progression,
      stockId: stockId,
      clientId: clientId,
      crmTacheId: crmTacheId,
    );
  }

  Map<String, dynamic> toJson() => {
    'titre': titre,
    'message': message,
    'type': type,
    'dateEcheance': dateEcheance.toIso8601String(),
    'dateFin': dateFin?.toIso8601String(),
    'touteJournee': touteJournee,
    'bandeId': bandeId,
    'recurrence': recurrence,
    'recurrenceConfig': recurrenceConfig,
    'priorite': priorite,
    'source': source,
    'automatique': automatique,
    'assigneA': assigneA,
    'checklist': checklist.map((c) => c.toJson()).toList(),
    'progression': progression,
  };
}
