double _num(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

/// Une affaire du pipeline commercial (un client à une étape, avec montant et probabilité).
class PipelineDeal {
  final String clientId;
  final String prenom;
  final String nom;
  final String telephone;
  final String entreprise;
  final String statut;
  final String stage;
  final String sourceLead;
  final double score;
  final double montant;
  final double probabilite;
  final DateTime? dateCloturePrevue;
  final DateTime? dernierContact;
  final int interactionsCount;
  final int commandesCount;
  final double chiffreAffairesCumul;

  const PipelineDeal({
    required this.clientId,
    this.prenom = '',
    this.nom = '',
    this.telephone = '',
    this.entreprise = '',
    this.statut = 'prospect',
    this.stage = 'lead',
    this.sourceLead = 'inconnu',
    this.score = 0,
    this.montant = 0,
    this.probabilite = 0,
    this.dateCloturePrevue,
    this.dernierContact,
    this.interactionsCount = 0,
    this.commandesCount = 0,
    this.chiffreAffairesCumul = 0,
  });

  factory PipelineDeal.fromJson(Map<String, dynamic> json) => PipelineDeal(
        clientId: (json['clientId'] ?? '').toString(),
        prenom: (json['prenom'] ?? '').toString(),
        nom: (json['nom'] ?? '').toString(),
        telephone: (json['telephone'] ?? '').toString(),
        entreprise: (json['entreprise'] ?? '').toString(),
        statut: (json['statut'] ?? 'prospect').toString(),
        stage: (json['stage'] ?? 'lead').toString(),
        sourceLead: (json['sourceLead'] ?? 'inconnu').toString(),
        score: _num(json['score']),
        montant: _num(json['montant']),
        probabilite: _num(json['probabilite']),
        dateCloturePrevue: _date(json['dateCloturePrevue']),
        dernierContact: _date(json['dernierContact']),
        interactionsCount: _num(json['interactionsCount']).toInt(),
        commandesCount: _num(json['commandesCount']).toInt(),
        chiffreAffairesCumul: _num(json['chiffreAffairesCumul']),
      );

  String get nomComplet {
    final n = '$prenom $nom'.trim();
    return n.isEmpty ? 'Client' : n;
  }

  double get montantPondere => montant * probabilite / 100;

  PipelineDeal copyWith({
    String? stage,
    double? montant,
    double? probabilite,
    DateTime? dateCloturePrevue,
    bool clearDateCloture = false,
    String? sourceLead,
  }) {
    return PipelineDeal(
      clientId: clientId,
      prenom: prenom,
      nom: nom,
      telephone: telephone,
      entreprise: entreprise,
      statut: statut,
      stage: stage ?? this.stage,
      sourceLead: sourceLead ?? this.sourceLead,
      score: score,
      montant: montant ?? this.montant,
      probabilite: probabilite ?? this.probabilite,
      dateCloturePrevue: clearDateCloture ? null : (dateCloturePrevue ?? this.dateCloturePrevue),
      dernierContact: dernierContact,
      interactionsCount: interactionsCount,
      commandesCount: commandesCount,
      chiffreAffairesCumul: chiffreAffairesCumul,
    );
  }

  /// Corps attendu par POST /crm/pipeline/:clientId (conserve les infos de l'affaire).
  Map<String, dynamic> toUpdatePayload({String note = ''}) => {
        'stage': stage,
        'sourceLead': sourceLead,
        'montant': montant,
        'probabilite': probabilite,
        'dateCloturePrevue': dateCloturePrevue?.toUtc().toIso8601String(),
        'note': note,
      };
}

/// Relance proposée automatiquement par le backend (réachat, sortie de bande, client inactif).
class CrmSuggestion {
  final String id;
  final String kind;
  final String clientId;
  final String clientNom;
  final String telephone;
  final String titre;
  final String description;
  final String raison;
  final String type;
  final String priorite;
  final DateTime dateEcheance;

  const CrmSuggestion({
    required this.id,
    required this.kind,
    required this.clientId,
    required this.clientNom,
    this.telephone = '',
    required this.titre,
    this.description = '',
    this.raison = '',
    this.type = 'relance',
    this.priorite = 'moyenne',
    required this.dateEcheance,
  });

  factory CrmSuggestion.fromJson(Map<String, dynamic> json) => CrmSuggestion(
        id: (json['id'] ?? '').toString(),
        kind: (json['kind'] ?? '').toString(),
        clientId: (json['clientId'] ?? '').toString(),
        clientNom: (json['clientNom'] ?? '').toString(),
        telephone: (json['telephone'] ?? '').toString(),
        titre: (json['titre'] ?? '').toString(),
        description: (json['description'] ?? '').toString(),
        raison: (json['raison'] ?? '').toString(),
        type: (json['type'] ?? 'relance').toString(),
        priorite: (json['priorite'] ?? 'moyenne').toString(),
        dateEcheance: _date(json['dateEcheance']) ?? DateTime.now(),
      );

  Map<String, dynamic> toTachePayload({String assigneA = ''}) => {
        'clientId': clientId,
        'titre': titre,
        'description': description,
        'type': type,
        'priorite': priorite,
        'statut': 'a_faire',
        'dateEcheance': dateEcheance.toUtc().toIso8601String(),
        'assigneA': assigneA,
      };
}

class CrmTopClient {
  final String id;
  final String nomComplet;
  final double chiffreAffaires;
  final String statut;

  const CrmTopClient({required this.id, required this.nomComplet, this.chiffreAffaires = 0, this.statut = 'prospect'});
}

class CrmVenteMois {
  final int annee;
  final int mois;
  final double total;

  const CrmVenteMois(this.annee, this.mois, this.total);
}

class CrmDashboardData {
  final int totalClients;
  final int totalProspects;
  final int clientsActifs;
  final int nouveauxClients;
  final int commandesEnAttente;
  final int relancesEnRetard;
  final int relancesOuvertes;
  final double caMois;
  final double caMoisPrecedent;
  final List<CrmTopClient> topClients;
  final List<CrmVenteMois> ventesParMois;

  const CrmDashboardData({
    this.totalClients = 0,
    this.totalProspects = 0,
    this.clientsActifs = 0,
    this.nouveauxClients = 0,
    this.commandesEnAttente = 0,
    this.relancesEnRetard = 0,
    this.relancesOuvertes = 0,
    this.caMois = 0,
    this.caMoisPrecedent = 0,
    this.topClients = const [],
    this.ventesParMois = const [],
  });

  factory CrmDashboardData.fromJson(Map<String, dynamic> json) => CrmDashboardData(
        totalClients: _num(json['totalClients']).toInt(),
        totalProspects: _num(json['totalProspects']).toInt(),
        clientsActifs: _num(json['clientsActifs']).toInt(),
        nouveauxClients: _num(json['nouveauxClients']).toInt(),
        commandesEnAttente: _num(json['commandesEnAttente']).toInt(),
        relancesEnRetard: _num(json['relancesAFaire']).toInt(),
        relancesOuvertes: _num(json['relancesOuvertes']).toInt(),
        caMois: _num(json['caMois']),
        caMoisPrecedent: _num(json['caMoisPrecedent']),
        topClients: (json['topClients'] as List? ?? const []).whereType<Map>().map((c) {
          return CrmTopClient(
            id: (c['_id'] ?? '').toString(),
            nomComplet: '${c['prenom'] ?? ''} ${c['nom'] ?? ''}'.trim(),
            chiffreAffaires: _num(c['chiffreAffairesCumul']),
            statut: (c['statut'] ?? 'prospect').toString(),
          );
        }).toList(),
        ventesParMois: (json['ventesParMois'] as List? ?? const []).whereType<Map>().map((v) {
          final id = v['_id'] is Map ? v['_id'] as Map : const {};
          return CrmVenteMois(_num(id['annee']).toInt(), _num(id['mois']).toInt(), _num(v['total']));
        }).toList(),
      );

  /// Évolution du CA du mois en % vs le mois précédent (null si pas de référence).
  double? get evolutionCa => caMoisPrecedent <= 0 ? null : (caMois - caMoisPrecedent) / caMoisPrecedent * 100;
}
