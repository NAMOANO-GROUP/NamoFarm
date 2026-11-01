import 'package:flutter/material.dart';

import '../models/cheptel.dart';

/// Espèce d'un troupeau : libellé, icône, couleur et reproduction.
class EspeceCheptel {
  final String valeur;
  final String libelle;
  final IconData icon;
  final MaterialColor color;

  /// Durée de gestation ou d'incubation (jours).
  final int gestationJours;

  /// « Mise-bas » pour les mammifères, « Éclosion » pour les volailles.
  final String naissanceLibelle;

  const EspeceCheptel(this.valeur, this.libelle, this.icon, this.color, this.gestationJours, this.naissanceLibelle);

  bool get volaille => naissanceLibelle == 'Éclosion';
}

const especesCheptel = [
  EspeceCheptel('chevre', 'Chèvres', Icons.pets, Colors.brown, 150, 'Mise-bas'),
  EspeceCheptel('mouton', 'Moutons', Icons.cloud_outlined, Colors.blueGrey, 147, 'Mise-bas'),
  EspeceCheptel('poule_locale', 'Poules locales', Icons.egg_outlined, Colors.orange, 21, 'Éclosion'),
  EspeceCheptel('pintade', 'Pintades', Icons.egg_alt_outlined, Colors.indigo, 27, 'Éclosion'),
  EspeceCheptel('lapin', 'Lapins', Icons.cruelty_free_outlined, Colors.pink, 31, 'Mise-bas'),
  EspeceCheptel('porc', 'Porcs', Icons.savings_outlined, Colors.red, 114, 'Mise-bas'),
  EspeceCheptel('bovin', 'Bovins', Icons.agriculture_outlined, Colors.teal, 283, 'Mise-bas'),
  EspeceCheptel('autre', 'Autre', Icons.pets_outlined, Colors.grey, 0, 'Naissance'),
];

EspeceCheptel especePour(String valeur) {
  final v = valeur.trim().toLowerCase();
  for (final e in especesCheptel) {
    if (e.valeur == v) return e;
  }
  if (v.isEmpty) return especesCheptel.last;
  final libelle = valeur.trim().replaceAll('_', ' ');
  return EspeceCheptel(
    valeur,
    libelle[0].toUpperCase() + libelle.substring(1),
    Icons.pets_outlined,
    Colors.grey,
    0,
    'Naissance',
  );
}

/// Types de mouvement (valeurs enregistrées en base).
class TypeMouvementCheptel {
  final String valeur;
  final String libelle;

  /// Libellé court pour les boutons rapides.
  final String court;
  final IconData icon;
  final MaterialColor color;

  /// +1 ajoute des animaux, -1 en retire, 0 = recomptage (fixe l'effectif).
  final int signe;
  final bool avecPrix;

  const TypeMouvementCheptel(
    this.valeur,
    this.libelle,
    this.court,
    this.icon,
    this.color,
    this.signe, {
    this.avecPrix = false,
  });
}

const typesMouvementCheptel = [
  TypeMouvementCheptel('naissance', 'Naissance / éclosion', 'Naissance', Icons.child_care, Colors.green, 1),
  TypeMouvementCheptel('mortalite', 'Mortalité', 'Mort', Icons.heart_broken_outlined, Colors.red, -1),
  TypeMouvementCheptel('vente', 'Vente', 'Vente', Icons.sell_outlined, Colors.blue, -1, avecPrix: true),
  TypeMouvementCheptel('entree', 'Achat / entrée', 'Achat', Icons.add_shopping_cart, Colors.teal, 1, avecPrix: true),
  TypeMouvementCheptel('ajustement', 'Recomptage', 'Recompter', Icons.fact_check_outlined, Colors.blueGrey, 0),
  TypeMouvementCheptel('sortie', 'Sortie / abattage', 'Sortie', Icons.logout, Colors.orange, -1),
];

TypeMouvementCheptel typeMouvement(String valeur) => typesMouvementCheptel.firstWhere(
  (t) => t.valeur == valeur,
  orElse: () => TypeMouvementCheptel(valeur, valeur, valeur, Icons.tune, Colors.grey, 0),
);

DateTime _jour(DateTime d) => DateTime(d.year, d.month, d.day);

/// Tri chronologique stable : à date égale, ordre de saisie (comme le serveur).
List<CheptelMouvement> _chronologique(Iterable<CheptelMouvement> saisis) {
  final indexes = [for (final (i, m) in saisis.indexed) if (m.date != null) (i, m)];
  indexes.sort((a, b) {
    final c = a.$2.date!.compareTo(b.$2.date!);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return [for (final x in indexes) x.$2];
}

/// Mouvements datés, du plus ancien au plus récent (l'API les renvoie du plus récent au plus ancien).
List<CheptelMouvement> mouvementsChronologiques(Cheptel c) => _chronologique(c.mouvements.reversed);

int _rejouer(Iterable<CheptelMouvement> chrono, {DateTime? limite}) {
  var e = 0;
  for (final m in chrono) {
    if (limite != null && !m.date!.toLocal().isBefore(limite)) break;
    final t = typeMouvement(m.type);
    if (t.signe == 0) {
      e = m.quantite;
    } else {
      e += t.signe * m.quantite;
    }
  }
  return e;
}

/// Effectif à la fin du jour [jour] (même règle que le serveur : le recomptage fixe l'effectif).
int effectifAu(Cheptel c, DateTime jour) =>
    _rejouer(mouvementsChronologiques(c), limite: _jour(jour).add(const Duration(days: 1)));

/// Effectif final après ajout d'un mouvement daté [date] (rejoue tout l'historique comme le serveur,
/// y compris pour une saisie antidatée).
int effectifApresMouvement(Cheptel c, String type, int quantite, DateTime date) => _rejouer(_chronologique([
      ...c.mouvements.reversed,
      CheptelMouvement(type: type, quantite: quantite, date: date),
    ]));

/// Points (date, effectif) après chaque jour de mouvement, prolongés jusqu'à aujourd'hui.
List<({DateTime date, int effectif})> courbeEffectif(Cheptel c, {DateTime? now}) {
  final jours = <DateTime>{for (final m in mouvementsChronologiques(c)) _jour(m.date!.toLocal())}.toList()..sort();
  final out = [for (final j in jours) (date: j, effectif: effectifAu(c, j))];
  final today = _jour(now ?? DateTime.now());
  if (out.isNotEmpty && out.last.date.isBefore(today)) out.add((date: today, effectif: c.effectifActuel));
  return out;
}

/// Totaux des mouvements sur une période.
class BilanCheptel {
  final int naissances;
  final int morts;
  final int vendus;
  final int achetes;
  final int sorties;
  final double ventes;
  final double achats;

  /// Animaux des ventes et achats saisis avec un prix (pour les prix moyens).
  final int vendusChiffres;
  final int achetesChiffres;

  const BilanCheptel({
    this.naissances = 0,
    this.morts = 0,
    this.vendus = 0,
    this.achetes = 0,
    this.sorties = 0,
    this.ventes = 0,
    this.achats = 0,
    this.vendusChiffres = 0,
    this.achetesChiffres = 0,
  });

  double get solde => ventes - achats;

  /// Prix moyen par tête vendue (ventes chiffrées seulement ; null si aucune).
  double? get prixMoyenVente => vendusChiffres > 0 ? ventes / vendusChiffres : null;

  /// Prix moyen par tête achetée (achats chiffrés seulement ; null si aucun).
  double? get prixMoyenAchat => achetesChiffres > 0 ? achats / achetesChiffres : null;
}

BilanCheptel bilanCheptel(Cheptel c, {DateTime? depuis, DateTime? jusqua}) {
  var naissances = 0, morts = 0, vendus = 0, achetes = 0, sorties = 0, vendusChiffres = 0, achetesChiffres = 0;
  var ventes = 0.0, achats = 0.0;
  for (final m in c.mouvements) {
    final d = m.date?.toLocal();
    if (depuis != null && (d == null || d.isBefore(_jour(depuis)))) continue;
    if (jusqua != null && (d == null || !d.isBefore(_jour(jusqua).add(const Duration(days: 1))))) continue;
    switch (m.type) {
      case 'naissance':
        naissances += m.quantite;
      case 'mortalite':
        morts += m.quantite;
      case 'vente':
        vendus += m.quantite;
        ventes += m.montant;
        if (m.montant > 0) vendusChiffres += m.quantite;
      case 'entree':
        achetes += m.quantite;
        achats += m.montant;
        if (m.montant > 0) achetesChiffres += m.quantite;
      case 'sortie':
        sorties += m.quantite;
    }
  }
  return BilanCheptel(
    naissances: naissances,
    morts: morts,
    vendus: vendus,
    achetes: achetes,
    sorties: sorties,
    ventes: ventes,
    achats: achats,
    vendusChiffres: vendusChiffres,
    achetesChiffres: achetesChiffres,
  );
}

/// Alertes d'un troupeau.
enum AlerteCheptel { mortaliteEnHausse, recomptage }

const alerteCheptelLibelles = {
  AlerteCheptel.mortaliteEnHausse: 'Mortalité en hausse',
  AlerteCheptel.recomptage: 'À recompter',
};

const alerteCheptelCouleurs = {AlerteCheptel.mortaliteEnHausse: Colors.red, AlerteCheptel.recomptage: Colors.orange};

/// Indicateurs d'un troupeau sur les 30 derniers jours.
class KpisCheptel {
  final int effectif;
  final int effectifIlYa30j;
  final BilanCheptel mois;
  final DateTime? dernierComptage;
  final List<AlerteCheptel> alertes;

  const KpisCheptel({
    required this.effectif,
    required this.effectifIlYa30j,
    required this.mois,
    required this.dernierComptage,
    required this.alertes,
  });

  int get evolution30j => effectif - effectifIlYa30j;
}

/// Seuil de mortalité sur 30 jours (en % de l'effectif d'il y a 30 jours).
const seuilMortaliteCheptelPct = 5.0;

/// Délai au-delà duquel un recomptage est conseillé.
const delaiRecomptageJours = 90;

KpisCheptel kpisCheptel(Cheptel c, {DateTime? now}) {
  final today = _jour(now ?? DateTime.now());
  final ilYa30 = today.subtract(const Duration(days: 30));
  final avant = effectifAu(c, ilYa30);
  final mois = bilanCheptel(c, depuis: ilYa30.add(const Duration(days: 1)), jusqua: today);
  final chrono = mouvementsChronologiques(c);
  DateTime? comptage;
  for (final m in chrono) {
    if (m.type == 'ajustement') comptage = m.date!.toLocal();
  }
  final reference = comptage ?? (chrono.isEmpty ? null : chrono.first.date!.toLocal());
  final alertes = <AlerteCheptel>[
    if (mois.morts >= 2 && avant > 0 && mois.morts / avant * 100 >= seuilMortaliteCheptelPct)
      AlerteCheptel.mortaliteEnHausse,
    if (c.effectifActuel > 0 && reference != null && today.difference(_jour(reference)).inDays > delaiRecomptageJours)
      AlerteCheptel.recomptage,
  ];
  return KpisCheptel(
    effectif: c.effectifActuel,
    effectifIlYa30j: avant,
    mois: mois,
    dernierComptage: comptage,
    alertes: alertes,
  );
}

/// Résumé de tous les troupeaux.
class ResumeCheptel {
  final int animaux;
  final int troupeaux;
  final int naissances30j;
  final int morts30j;
  final int vendusMois;
  final double ventesMois;

  const ResumeCheptel({
    required this.animaux,
    required this.troupeaux,
    required this.naissances30j,
    required this.morts30j,
    required this.vendusMois,
    required this.ventesMois,
  });
}

ResumeCheptel resumeCheptel(List<Cheptel> cheptels, {DateTime? now}) {
  final today = _jour(now ?? DateTime.now());
  var animaux = 0, naissances = 0, morts = 0, vendus = 0;
  var ventes = 0.0;
  for (final c in cheptels) {
    animaux += c.effectifActuel;
    final b30 = bilanCheptel(c, depuis: today.subtract(const Duration(days: 29)), jusqua: today);
    naissances += b30.naissances;
    morts += b30.morts;
    final bm = bilanCheptel(c, depuis: DateTime(today.year, today.month, 1), jusqua: today);
    vendus += bm.vendus;
    ventes += bm.ventes;
  }
  return ResumeCheptel(
    animaux: animaux,
    troupeaux: cheptels.length,
    naissances30j: naissances,
    morts30j: morts,
    vendusMois: vendus,
    ventesMois: ventes,
  );
}

/// Journal groupé par mois (du plus récent au plus ancien), filtré par types ([types] vide = tous).
List<({DateTime mois, List<CheptelMouvement> mouvements})> journalParMois(Cheptel c, {Set<String> types = const {}}) {
  final groupes = <DateTime, List<CheptelMouvement>>{};
  for (final m in mouvementsChronologiques(c).reversed) {
    if (types.isNotEmpty && !types.contains(m.type)) continue;
    final d = m.date!.toLocal();
    groupes.putIfAbsent(DateTime(d.year, d.month), () => []).add(m);
  }
  return [for (final e in groupes.entries) (mois: e.key, mouvements: e.value)];
}

/// Rappel de santé proposé pour une espèce, planifié [jour] jours après la date de départ.
class RappelSante {
  final int jour;
  final String titre;
  final String type;
  final String recurrence;
  final String message;

  const RappelSante(this.jour, this.titre, {this.type = 'vaccination', this.recurrence = 'aucune', this.message = ''});
}

List<RappelSante> _trimestriel(String titre, String type) => [
  for (var i = 0; i < 4; i++) RappelSante(i * 91, titre, type: type),
];

/// Plan de santé type par espèce (à adapter avec le vétérinaire).
List<RappelSante> planSante(String espece) {
  switch (espece) {
    case 'chevre':
    case 'mouton':
      return [
        ..._trimestriel('Déparasitage', 'medicament'),
        const RappelSante(0, 'Vaccin PPR (peste des petits ruminants)', recurrence: 'annuel'),
        const RappelSante(14, 'Vaccin pasteurellose', recurrence: 'annuel'),
        const RappelSante(30, 'Parage des onglons', type: 'controle_sanitaire', recurrence: 'mensuel'),
      ];
    case 'poule_locale':
    case 'pintade':
      return [
        ..._trimestriel('Vaccin Newcastle', 'vaccination'),
        for (var i = 0; i < 6; i++) RappelSante(i * 61, 'Déparasitage', type: 'medicament'),
        const RappelSante(7, 'Vaccin variole aviaire', recurrence: 'annuel'),
        const RappelSante(0, 'Nettoyage du poulailler', type: 'controle_sanitaire', recurrence: 'hebdomadaire'),
      ];
    case 'lapin':
      return [
        ..._trimestriel('Déparasitage', 'medicament'),
        const RappelSante(0, 'Vaccin myxomatose', recurrence: 'annuel'),
        const RappelSante(14, 'Vaccin VHD (maladie hémorragique)', recurrence: 'annuel'),
      ];
    case 'porc':
      return [
        ..._trimestriel('Déparasitage', 'medicament'),
        const RappelSante(0, 'Vaccin rouget', recurrence: 'annuel'),
      ];
    case 'bovin':
      return [
        const RappelSante(0, 'Déparasitage', type: 'medicament'),
        const RappelSante(182, 'Déparasitage', type: 'medicament'),
        const RappelSante(0, 'Vaccin charbon', recurrence: 'annuel'),
        const RappelSante(14, 'Vaccin PPCB (péripneumonie)', recurrence: 'annuel'),
      ];
    default:
      return _trimestriel('Déparasitage', 'medicament');
  }
}

Map<String, dynamic> _tache(
  String titre,
  String type,
  DateTime date, {
  String recurrence = 'aucune',
  String message = '',
  String priorite = 'moyenne',
  List<String> etapes = const [],
}) {
  final d = DateTime(date.year, date.month, date.day, 8);
  return {
    'titre': titre,
    'message': message,
    'type': type,
    'priorite': priorite,
    'recurrence': recurrence,
    'recurrenceConfig': const <String, dynamic>{},
    'dateEcheance': d.toUtc().toIso8601String(),
    'dateFin': d.add(const Duration(hours: 1)).toUtc().toIso8601String(),
    'touteJournee': false,
    'checklist': [
      for (final e in etapes) {'titre': e, 'fait': false},
    ],
    'source': 'todo',
  };
}

/// Tâches Todo (payloads API) du plan santé choisi pour un troupeau.
List<Map<String, dynamic>> tachesPlanSante(Cheptel c, List<RappelSante> rappels, DateTime depart) => [
  for (final r in rappels)
    _tache(
      '${r.titre} · ${c.nom}',
      r.type,
      DateTime(depart.year, depart.month, depart.day + r.jour),
      recurrence: r.recurrence,
      message: r.message.isEmpty ? 'Cheptel ${c.nom}' : r.message,
    ),
];

/// Date de mise-bas (ou d'éclosion) prévue.
DateTime dateNaissancePrevue(String espece, DateTime saillie, {int? gestationJours}) {
  final g = gestationJours ?? especePour(espece).gestationJours;
  return DateTime(saillie.year, saillie.month, saillie.day + g);
}

/// Tâches Todo d'une mise-bas (ou éclosion) prévue : préparation, jour J, contrôle des petits.
List<Map<String, dynamic>> tachesNaissancePrevue(
  Cheptel c,
  DateTime saillie, {
  int nbFemelles = 1,
  int? gestationJours,
}) {
  final e = especePour(c.espece);
  final prevue = dateNaissancePrevue(c.espece, saillie, gestationJours: gestationJours);
  final qui = nbFemelles > 1 ? '$nbFemelles femelles' : '1 femelle';
  final quoi = e.naissanceLibelle.toLowerCase();
  return [
    _tache(
      e.volaille ? 'Préparer l’éclosion · ${c.nom}' : 'Préparer la mise-bas · ${c.nom}',
      'intervention_diverse',
      DateTime(prevue.year, prevue.month, prevue.day - (e.volaille ? 3 : 7)),
      message: '$qui, $quoi prévue le ${prevue.day}/${prevue.month}/${prevue.year}',
      etapes: e.volaille
          ? const ['Ne plus manipuler les œufs', 'Prévoir eau et aliment démarrage', 'Préparer un abri chaud']
          : const ['Isoler la ou les femelles', 'Préparer une litière propre', 'Prévoir le matériel de soins'],
    ),
    _tache(
      '${e.naissanceLibelle} prévue · ${c.nom}',
      'autre',
      prevue,
      priorite: 'haute',
      message: '$qui. Pensez à enregistrer les naissances dans le Cheptel.',
    ),
    _tache(
      'Contrôle des petits · ${c.nom}',
      'controle_sanitaire',
      DateTime(prevue.year, prevue.month, prevue.day + 3),
      message: 'Vérifier la prise d’aliment, l’état des petits et de la mère.',
    ),
  ];
}
