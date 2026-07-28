class ProtocoleEtape {
  final int jourAge;
  final String intervention;
  final String produit;
  final String dose;
  final String voie;
  final int delaiAttenteJours;
  final String notes;

  ProtocoleEtape({
    this.jourAge = 0,
    this.intervention = '',
    this.produit = '',
    this.dose = '',
    this.voie = '',
    this.delaiAttenteJours = 0,
    this.notes = '',
  });

  factory ProtocoleEtape.fromJson(Map<String, dynamic> json) {
    return ProtocoleEtape(
      jourAge: int.tryParse((json['jourAge'] ?? 0).toString()) ?? 0,
      intervention: (json['intervention'] ?? '').toString(),
      produit: (json['produit'] ?? '').toString(),
      dose: (json['dose'] ?? '').toString(),
      voie: (json['voie'] ?? '').toString(),
      delaiAttenteJours: int.tryParse((json['delaiAttenteJours'] ?? 0).toString()) ?? 0,
      notes: (json['notes'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'jourAge': jourAge,
        'intervention': intervention,
        'produit': produit,
        'dose': dose,
        'voie': voie,
        'delaiAttenteJours': delaiAttenteJours,
        'notes': notes,
      };
}

class ProtocoleVaccinal {
  final String? id;
  final String nom;
  final String typeVolaille;
  final List<ProtocoleEtape> etapes;
  final String notes;

  ProtocoleVaccinal({
    this.id,
    required this.nom,
    this.typeVolaille = '',
    this.etapes = const [],
    this.notes = '',
  });

  factory ProtocoleVaccinal.fromJson(Map<String, dynamic> json) {
    return ProtocoleVaccinal(
      id: (json['_id'] ?? json['id'])?.toString(),
      nom: (json['nom'] ?? '').toString(),
      typeVolaille: (json['typeVolaille'] ?? '').toString(),
      etapes: (json['etapes'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => ProtocoleEtape.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      notes: (json['notes'] ?? '').toString(),
    );
  }
}

class TraitementSanitaire {
  final String? id;
  final String? bandeId;
  final DateTime? dateTraitement;
  final String type;
  final String produit;
  final String dose;
  final String voie;
  final String motif;
  final int delaiAttenteJours;
  final DateTime? dateFinDelaiAttente;
  final String statutDelai; // aucun | en_cours | termine
  final String utilisateur;
  final String notes;

  TraitementSanitaire({
    this.id,
    this.bandeId,
    this.dateTraitement,
    this.type = 'traitement',
    this.produit = '',
    this.dose = '',
    this.voie = '',
    this.motif = '',
    this.delaiAttenteJours = 0,
    this.dateFinDelaiAttente,
    this.statutDelai = 'aucun',
    this.utilisateur = '',
    this.notes = '',
  });

  factory TraitementSanitaire.fromJson(Map<String, dynamic> json) {
    return TraitementSanitaire(
      id: (json['_id'] ?? json['id'])?.toString(),
      bandeId: json['bandeId']?.toString(),
      dateTraitement: DateTime.tryParse((json['dateTraitement'] ?? '').toString()),
      type: (json['type'] ?? 'traitement').toString(),
      produit: (json['produit'] ?? '').toString(),
      dose: (json['dose'] ?? '').toString(),
      voie: (json['voie'] ?? '').toString(),
      motif: (json['motif'] ?? '').toString(),
      delaiAttenteJours: int.tryParse((json['delaiAttenteJours'] ?? 0).toString()) ?? 0,
      dateFinDelaiAttente: DateTime.tryParse((json['dateFinDelaiAttente'] ?? '').toString()),
      statutDelai: (json['statutDelai'] ?? 'aucun').toString(),
      utilisateur: (json['utilisateur'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
    );
  }
}
