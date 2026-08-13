class Achat {
  final String? id;
  final String titre;
  final String article;
  final String categorie;
  final double quantite;
  final String unite;
  final String fournisseur;
  final double prixUnitaireEstime;
  final double montantEstime;
  final String urgence;
  final String motif;
  final String statut;
  final String demandeurNom;
  final String demandeurPrenom;
  final String validateurNom;
  final String validateurPrenom;
  final String notesValidation;
  final String? stockId;
  final DateTime? dateDemande;
  final DateTime? dateValidation;
  final DateTime? dateReception;

  Achat({
    this.id,
    required this.titre,
    required this.article,
    this.categorie = 'autre',
    this.quantite = 0,
    this.unite = 'unité',
    this.fournisseur = '',
    this.prixUnitaireEstime = 0,
    this.montantEstime = 0,
    this.urgence = 'normale',
    this.motif = '',
    this.statut = 'en_attente',
    this.demandeurNom = '',
    this.demandeurPrenom = '',
    this.validateurNom = '',
    this.validateurPrenom = '',
    this.notesValidation = '',
    this.stockId,
    this.dateDemande,
    this.dateValidation,
    this.dateReception,
  });

  factory Achat.fromJson(Map<String, dynamic> json) {
    return Achat(
      id: json['_id']?.toString(),
      titre: (json['titre'] ?? '').toString(),
      article: (json['article'] ?? '').toString(),
      categorie: (json['categorie'] ?? 'autre').toString(),
      quantite: (json['quantite'] ?? 0).toDouble(),
      unite: (json['unite'] ?? 'unité').toString(),
      fournisseur: (json['fournisseur'] ?? '').toString(),
      prixUnitaireEstime: (json['prixUnitaireEstime'] ?? 0).toDouble(),
      montantEstime: (json['montantEstime'] ?? 0).toDouble(),
      urgence: (json['urgence'] ?? 'normale').toString(),
      motif: (json['motif'] ?? '').toString(),
      statut: (json['statut'] ?? 'en_attente').toString(),
      demandeurNom: (json['demandeurNom'] ?? '').toString(),
      demandeurPrenom: (json['demandeurPrenom'] ?? '').toString(),
      validateurNom: (json['validateurNom'] ?? '').toString(),
      validateurPrenom: (json['validateurPrenom'] ?? '').toString(),
      notesValidation: (json['notesValidation'] ?? '').toString(),
      stockId: json['stockId']?.toString(),
      dateDemande: json['dateDemande'] != null ? DateTime.tryParse(json['dateDemande'].toString()) : null,
      dateValidation: json['dateValidation'] != null ? DateTime.tryParse(json['dateValidation'].toString()) : null,
      dateReception: json['dateReception'] != null ? DateTime.tryParse(json['dateReception'].toString()) : null,
    );
  }
}
