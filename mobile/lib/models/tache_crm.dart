class ChecklistItem {
  final String titre;
  final bool fait;

  const ChecklistItem({required this.titre, this.fait = false});

  factory ChecklistItem.fromJson(Map<String, dynamic> json) =>
      ChecklistItem(titre: (json['titre'] ?? '').toString(), fait: json['fait'] == true);

  Map<String, dynamic> toJson() => {'titre': titre, 'fait': fait};

  ChecklistItem copyWith({String? titre, bool? fait}) => ChecklistItem(titre: titre ?? this.titre, fait: fait ?? this.fait);
}

class TacheCRM {
  final String? id;
  final String clientId;
  final String? commandeId;
  final String titre;
  final String description;
  final String type;
  final DateTime dateEcheance;
  final String statut;
  final String priorite;
  final bool rappelActive;
  final String assigneA;
  final String clientNom;
  final String clientTelephone;
  final List<ChecklistItem> checklist;

  TacheCRM({
    this.id,
    required this.clientId,
    this.commandeId,
    required this.titre,
    this.description = '',
    this.type = 'suivi',
    required this.dateEcheance,
    this.statut = 'a_faire',
    this.priorite = 'moyenne',
    this.rappelActive = true,
    this.assigneA = '',
    this.clientNom = '',
    this.clientTelephone = '',
    this.checklist = const [],
  });

  factory TacheCRM.fromJson(Map<String, dynamic> json) {
    final client = json['clientId'];
    return TacheCRM(
      id: json['_id'],
      clientId: client is String ? client : client?['_id'] ?? '',
      commandeId: json['commandeId'] is String ? json['commandeId'] : json['commandeId']?['_id'],
      titre: json['titre'] ?? '',
      description: json['description'] ?? '',
      type: json['type'] ?? 'suivi',
      dateEcheance: json['dateEcheance'] != null ? DateTime.parse(json['dateEcheance']).toLocal() : DateTime.now(),
      statut: json['statut'] ?? 'a_faire',
      priorite: json['priorite'] ?? 'moyenne',
      rappelActive: json['rappelActive'] ?? true,
      assigneA: json['assigneA'] ?? '',
      clientNom: client is Map ? '${client['prenom'] ?? ''} ${client['nom'] ?? ''}'.trim() : '',
      clientTelephone: client is Map ? (client['telephone'] ?? '').toString() : '',
      checklist: (json['checklist'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => ChecklistItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  int get checklistFaits => checklist.where((c) => c.fait).length;

  TacheCRM copyWith({
    String? statut,
    DateTime? dateEcheance,
    List<ChecklistItem>? checklist,
  }) {
    return TacheCRM(
      id: id,
      clientId: clientId,
      commandeId: commandeId,
      titre: titre,
      description: description,
      type: type,
      dateEcheance: dateEcheance ?? this.dateEcheance,
      statut: statut ?? this.statut,
      priorite: priorite,
      rappelActive: rappelActive,
      assigneA: assigneA,
      clientNom: clientNom,
      clientTelephone: clientTelephone,
      checklist: checklist ?? this.checklist,
    );
  }

  Map<String, dynamic> toJson() => {
    'clientId': clientId,
    'commandeId': commandeId,
    'titre': titre,
    'description': description,
    'type': type,
    'dateEcheance': dateEcheance.toUtc().toIso8601String(),
    'statut': statut,
    'priorite': priorite,
    'rappelActive': rappelActive,
    'assigneA': assigneA,
    'checklist': checklist.map((c) => c.toJson()).toList(),
  };
}
