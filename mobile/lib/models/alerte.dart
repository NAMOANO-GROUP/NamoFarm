class Alerte {
  final String? id;
  final String titre;
  final String message;
  final String type;
  final DateTime dateEcheance;
  final DateTime? dateFin;
  final bool touteJournee;
  final String? bandeId;
  final String statut;
  final String recurrence;
  final Map<String, dynamic> recurrenceConfig;
  final String priorite;
  final String source;
  final bool automatique;

  Alerte({
    this.id,
    required this.titre,
    required this.message,
    required this.type,
    required this.dateEcheance,
    this.dateFin,
    this.touteJournee = false,
    this.bandeId,
    this.statut = 'active',
    this.recurrence = 'aucune',
    this.recurrenceConfig = const {},
    this.priorite = 'moyenne',
    this.source = '',
    this.automatique = false,
  });

  factory Alerte.fromJson(Map<String, dynamic> json) {
    return Alerte(
      id: (json['_id'] ?? json['id'])?.toString(),
      titre: json['titre'],
      message: json['message'],
      type: json['type'],
      dateEcheance: DateTime.parse(json['dateEcheance']),
      dateFin: json['dateFin'] != null ? DateTime.tryParse(json['dateFin'].toString()) : null,
      touteJournee: json['touteJournee'] == true,
      bandeId: json['bandeId'] is String ? json['bandeId'] : json['bandeId']?['_id'],
      statut: json['statut'] ?? 'active',
      recurrence: json['recurrence'] ?? 'aucune',
      recurrenceConfig: json['recurrenceConfig'] is Map ? Map<String, dynamic>.from(json['recurrenceConfig']) : const {},
      priorite: json['priorite'] ?? 'moyenne',
      source: json['source'] ?? '',
      automatique: json['automatique'] ?? false,
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
  };
}
