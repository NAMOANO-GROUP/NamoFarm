class Couvee {
  final String? id;
  final String code;
  final String race;
  final String? bandeId;
  final DateTime? dateMiseIncubation;
  final int nbOeufsIncubes;
  final DateTime? dateMirage;
  final int? nbOeufsFertiles;
  final DateTime? dateEclosion;
  final int? nbEclos;
  final int? nbPoussinsViables;
  final String statut;
  final String notes;
  final double? tauxFertilite;
  final double? tauxEclosion;
  final double? tauxEclosionSurIncubes;
  final double? tauxViabilite;

  Couvee({
    this.id,
    required this.code,
    this.race = '',
    this.bandeId,
    this.dateMiseIncubation,
    this.nbOeufsIncubes = 0,
    this.dateMirage,
    this.nbOeufsFertiles,
    this.dateEclosion,
    this.nbEclos,
    this.nbPoussinsViables,
    this.statut = 'en_incubation',
    this.notes = '',
    this.tauxFertilite,
    this.tauxEclosion,
    this.tauxEclosionSurIncubes,
    this.tauxViabilite,
  });

  static DateTime? _date(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  static int? _intOrNull(dynamic v) {
    if (v == null) return null;
    return int.tryParse(v.toString()) ?? (v is num ? v.toInt() : null);
  }

  static double? _doubleOrNull(dynamic v) {
    if (v == null) return null;
    return double.tryParse(v.toString()) ?? (v is num ? v.toDouble() : null);
  }

  factory Couvee.fromJson(Map<String, dynamic> json) {
    return Couvee(
      id: (json['_id'] ?? json['id'])?.toString(),
      code: (json['code'] ?? '').toString(),
      race: (json['race'] ?? '').toString(),
      bandeId: json['bandeId']?.toString(),
      dateMiseIncubation: _date(json['dateMiseIncubation']),
      nbOeufsIncubes: _intOrNull(json['nbOeufsIncubes']) ?? 0,
      dateMirage: _date(json['dateMirage']),
      nbOeufsFertiles: _intOrNull(json['nbOeufsFertiles']),
      dateEclosion: _date(json['dateEclosion']),
      nbEclos: _intOrNull(json['nbEclos']),
      nbPoussinsViables: _intOrNull(json['nbPoussinsViables']),
      statut: (json['statut'] ?? 'en_incubation').toString(),
      notes: (json['notes'] ?? '').toString(),
      tauxFertilite: _doubleOrNull(json['tauxFertilite']),
      tauxEclosion: _doubleOrNull(json['tauxEclosion']),
      tauxEclosionSurIncubes: _doubleOrNull(json['tauxEclosionSurIncubes']),
      tauxViabilite: _doubleOrNull(json['tauxViabilite']),
    );
  }
}
