class CheptelMouvement {
  final String? id;
  final DateTime? date;
  final String type;
  final int quantite;
  final double montant;
  final String motif;
  final String utilisateur;

  CheptelMouvement({
    this.id,
    this.date,
    this.type = 'naissance',
    this.quantite = 0,
    this.montant = 0,
    this.motif = '',
    this.utilisateur = '',
  });

  factory CheptelMouvement.fromJson(Map<String, dynamic> json) {
    return CheptelMouvement(
      id: (json['_id'] ?? json['id'])?.toString(),
      date: DateTime.tryParse((json['date'] ?? '').toString()),
      type: (json['type'] ?? '').toString(),
      quantite: int.tryParse((json['quantite'] ?? 0).toString()) ?? 0,
      montant: double.tryParse((json['montant'] ?? 0).toString()) ?? 0,
      motif: (json['motif'] ?? '').toString(),
      utilisateur: (json['utilisateur'] ?? '').toString(),
    );
  }
}

class Cheptel {
  final String? id;
  final String nom;
  final String espece;
  final String notes;
  final int effectifActuel;
  final int naissances;
  final int entrees;
  final int morts;
  final int ventes;
  final int sorties;
  final double caVentes;
  final double tauxMortalite;
  final List<CheptelMouvement> mouvements;

  Cheptel({
    this.id,
    required this.nom,
    this.espece = '',
    this.notes = '',
    this.effectifActuel = 0,
    this.naissances = 0,
    this.entrees = 0,
    this.morts = 0,
    this.ventes = 0,
    this.sorties = 0,
    this.caVentes = 0,
    this.tauxMortalite = 0,
    this.mouvements = const [],
  });

  factory Cheptel.fromJson(Map<String, dynamic> json) {
    return Cheptel(
      id: (json['_id'] ?? json['id'])?.toString(),
      nom: (json['nom'] ?? '').toString(),
      espece: (json['espece'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
      effectifActuel: int.tryParse((json['effectifActuel'] ?? 0).toString()) ?? 0,
      naissances: int.tryParse((json['naissances'] ?? 0).toString()) ?? 0,
      entrees: int.tryParse((json['entrees'] ?? 0).toString()) ?? 0,
      morts: int.tryParse((json['morts'] ?? 0).toString()) ?? 0,
      ventes: int.tryParse((json['ventes'] ?? 0).toString()) ?? 0,
      sorties: int.tryParse((json['sorties'] ?? 0).toString()) ?? 0,
      caVentes: double.tryParse((json['caVentes'] ?? 0).toString()) ?? 0,
      tauxMortalite: double.tryParse((json['tauxMortalite'] ?? 0).toString()) ?? 0,
      mouvements: (json['mouvements'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => CheptelMouvement.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
