import 'package:flutter/material.dart';

import '../models/couvee.dart';

/// Durée d'incubation selon l'espèce, déduite de la race saisie (la poule par défaut).
({int jours, String espece}) incubationPour(String race) {
  final mots = race.toLowerCase().split(RegExp(r"[^a-zàâäéèêëîïôöùûüç]+")).where((m) => m.isNotEmpty).toSet();
  // Mots entiers (« soie » ne doit pas être pris pour « oie ») ; pluriels acceptés.
  bool a(List<String> cles) => cles.any((k) => mots.contains(k) || mots.contains('${k}s'));
  if (a(['poule', 'coq', 'poulet', 'soie'])) return (jours: 21, espece: 'Poule');
  if (a(['caille'])) return (jours: 17, espece: 'Caille');
  if (a(['pintade'])) return (jours: 27, espece: 'Pintade');
  if (a(['barbarie'])) return (jours: 35, espece: 'Canard de Barbarie');
  if (a(['canard'])) return (jours: 28, espece: 'Canard');
  if (a(['dinde', 'dindon'])) return (jours: 28, espece: 'Dinde');
  if (a(['oie'])) return (jours: 30, espece: 'Oie');
  return (jours: 21, espece: 'Poule');
}

DateTime _jour(DateTime d) => DateTime(d.year, d.month, d.day);

/// Couvée encore dans l'incubateur (éclosion pas encore saisie).
bool enIncubation(Couvee c) => c.statut == 'en_incubation' || c.statut == 'mire';

int _ecart(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// Objectifs de référence du couvoir.
const objectifEclosionPct = 80.0;
const objectifViabilitePct = 95.0;

/// Étape du calendrier d'incubation.
class EtapeCouvee {
  final int jour;
  final String titre;
  final String conseil;
  final IconData icon;
  final DateTime date;

  const EtapeCouvee(this.jour, this.titre, this.conseil, this.icon, this.date);
}

/// Calendrier type : mise en incubation, mirages, arrêt du retournement, éclosion.
List<EtapeCouvee> etapesCouvee(Couvee c) {
  final debut = c.dateMiseIncubation?.toLocal();
  if (debut == null) return const [];
  final d = incubationPour(c.race).jours;
  DateTime le(int j) => DateTime(debut.year, debut.month, debut.day + j);
  final mirage2 = (d * 2 / 3).round();
  return [
    EtapeCouvee(0, 'Mise en incubation', 'Œufs propres, température et humidité stables.', Icons.egg_outlined, le(0)),
    EtapeCouvee(7, 'Premier mirage', 'Retirer les œufs clairs (non fécondés).', Icons.flashlight_on_outlined, le(7)),
    if (mirage2 > 9 && mirage2 < d - 3)
      EtapeCouvee(mirage2, 'Second mirage', 'Retirer les embryons arrêtés.', Icons.flashlight_on_outlined, le(mirage2)),
    EtapeCouvee(d - 3, 'Arrêt du retournement', 'Passer en éclosoir, augmenter l’humidité.', Icons.pause_circle_outline, le(d - 3)),
    EtapeCouvee(d, 'Éclosion', 'Laisser sécher les poussins avant de les sortir.', Icons.egg_alt, le(d)),
  ];
}

/// Avancement d'une couvée en incubation.
class AvancementCouvee {
  final int age;
  final int duree;
  final String espece;
  final DateTime eclosionPrevue;

  /// Étape en cours (dernière étape atteinte) et prochaine étape.
  final EtapeCouvee? etapeEnCours;
  final EtapeCouvee? prochaineEtape;

  const AvancementCouvee({
    required this.age,
    required this.duree,
    required this.espece,
    required this.eclosionPrevue,
    required this.etapeEnCours,
    required this.prochaineEtape,
  });

  int get joursRestants => duree - age;
  double get progression => duree <= 0 ? 1 : (age / duree).clamp(0.0, 1.0);

  /// Éclosion dépassée de plus d'un jour sans saisie.
  bool get enRetard => joursRestants < -1;

  String get libelleEcheance {
    final r = joursRestants;
    if (r > 1) return 'Éclosion dans $r j';
    if (r == 1) return 'Éclosion demain';
    if (r == 0) return 'Éclosion aujourd’hui';
    return 'Éclosion à saisir (prévue il y a ${-r} j)';
  }
}

AvancementCouvee? avancementCouvee(Couvee c, {DateTime? now}) {
  final debut = c.dateMiseIncubation?.toLocal();
  if (debut == null) return null;
  final today = _jour(now ?? DateTime.now());
  final inc = incubationPour(c.race);
  final age = _ecart(debut, today).clamp(0, 100000);
  final etapes = etapesCouvee(c);
  EtapeCouvee? enCours;
  EtapeCouvee? prochaine;
  for (final e in etapes) {
    if (e.jour <= age) {
      enCours = e;
    } else {
      prochaine ??= e;
    }
  }
  return AvancementCouvee(
    age: age,
    duree: inc.jours,
    espece: inc.espece,
    eclosionPrevue: DateTime(debut.year, debut.month, debut.day + inc.jours),
    etapeEnCours: enCours,
    prochaineEtape: prochaine,
  );
}

/// Étape de l'entonnoir (œufs puis poussins).
class EtageEntonnoir {
  final String libelle;
  final int nombre;

  /// Part par rapport aux œufs incubés (0-100).
  final double pctIncubes;

  /// Pertes par rapport à l'étage précédent.
  final int pertes;
  final String libellePertes;

  const EtageEntonnoir(this.libelle, this.nombre, this.pctIncubes, this.pertes, this.libellePertes);
}

/// Entonnoir incubés → (fertiles) → éclos → viables, selon ce qui a été saisi.
List<EtageEntonnoir> entonnoirCouvee(Couvee c) {
  final incubes = c.nbOeufsIncubes;
  double pct(int n) => incubes <= 0 ? 0 : n / incubes * 100;
  final out = [EtageEntonnoir('Œufs incubés', incubes, 100, 0, '')];
  var precedent = incubes;
  final fertiles = c.nbOeufsFertiles;
  if (fertiles != null && fertiles < incubes) {
    out.add(EtageEntonnoir('Œufs fertiles', fertiles, pct(fertiles), incubes - fertiles, 'œufs clairs'));
    precedent = fertiles;
  }
  final eclos = c.nbEclos;
  if (eclos != null) {
    out.add(EtageEntonnoir('Poussins éclos', eclos, pct(eclos), (precedent - eclos).clamp(0, precedent), 'non éclos'));
    final viables = c.nbPoussinsViables;
    if (viables != null) {
      out.add(EtageEntonnoir('Poussins viables', viables, pct(viables), (eclos - viables).clamp(0, eclos), 'non viables'));
    }
  }
  return out;
}

/// Taux d'éclosion rapporté aux œufs incubés (indicateur principal du couvoir).
double? tauxEclosionIncubes(Couvee c) {
  if (c.nbEclos == null || c.nbOeufsIncubes <= 0) return null;
  return c.nbEclos! / c.nbOeufsIncubes * 100;
}

double? tauxViabilite(Couvee c) {
  final e = c.nbEclos;
  if (e == null || e <= 0 || c.nbPoussinsViables == null) return null;
  return c.nbPoussinsViables! / e * 100;
}

/// Alertes d'une couvée.
enum AlerteCouvee { eclosionASaisir, eclosionFaible, viabiliteFaible }

const alerteCouveeLibelles = {
  AlerteCouvee.eclosionASaisir: 'Éclosion à saisir',
  AlerteCouvee.eclosionFaible: 'Éclosion faible',
  AlerteCouvee.viabiliteFaible: 'Viabilité faible',
};

const alerteCouveeCouleurs = {
  AlerteCouvee.eclosionASaisir: Colors.orange,
  AlerteCouvee.eclosionFaible: Colors.red,
  AlerteCouvee.viabiliteFaible: Colors.red,
};

List<AlerteCouvee> alertesCouvee(Couvee c, {DateTime? now}) {
  final av = enIncubation(c) ? avancementCouvee(c, now: now) : null;
  final te = tauxEclosionIncubes(c);
  final tv = tauxViabilite(c);
  return [
    if (av != null && av.enRetard) AlerteCouvee.eclosionASaisir,
    if (te != null && te < objectifEclosionPct - 15) AlerteCouvee.eclosionFaible,
    if (tv != null && tv < objectifViabilitePct - 10) AlerteCouvee.viabiliteFaible,
  ];
}

/// Résumé du couvoir.
class ResumeCouvoir {
  final int enCours;
  final int oeufsEnIncubation;

  /// Couvée en incubation dont l'éclosion est la plus proche.
  final Couvee? prochaine;
  final AvancementCouvee? prochaineAvancement;

  /// Sur les couvées éclos des 12 derniers mois (null si aucune).
  final double? tauxEclosion12Mois;
  final double? tauxViabilite12Mois;
  final int poussins12Mois;

  const ResumeCouvoir({
    required this.enCours,
    required this.oeufsEnIncubation,
    required this.prochaine,
    required this.prochaineAvancement,
    required this.tauxEclosion12Mois,
    required this.tauxViabilite12Mois,
    required this.poussins12Mois,
  });
}

ResumeCouvoir resumeCouvoir(List<Couvee> couvees, {DateTime? now}) {
  final today = _jour(now ?? DateTime.now());
  final incubation = couvees.where(enIncubation).toList();
  Couvee? prochaine;
  AvancementCouvee? prochaineAv;
  for (final c in incubation) {
    final av = avancementCouvee(c, now: today);
    if (av == null) continue;
    if (prochaineAv == null || av.eclosionPrevue.isBefore(prochaineAv.eclosionPrevue)) {
      prochaine = c;
      prochaineAv = av;
    }
  }
  final depuis = DateTime(today.year - 1, today.month, today.day);
  var incubes = 0, eclos = 0, viables = 0, eclosAvecViables = 0, poussins = 0;
  for (final c in couvees) {
    if (c.nbEclos == null || c.statut == 'annule') continue;
    final d = (c.dateEclosion ?? c.dateMiseIncubation)?.toLocal();
    if (d == null || d.isBefore(depuis)) continue;
    incubes += c.nbOeufsIncubes;
    eclos += c.nbEclos!;
    poussins += c.nbPoussinsViables ?? c.nbEclos!;
    if (c.nbPoussinsViables != null) {
      viables += c.nbPoussinsViables!;
      eclosAvecViables += c.nbEclos!;
    }
  }
  return ResumeCouvoir(
    enCours: incubation.length,
    oeufsEnIncubation: incubation.fold(0, (s, c) => s + c.nbOeufsIncubes),
    prochaine: prochaine,
    prochaineAvancement: prochaineAv,
    tauxEclosion12Mois: incubes > 0 ? eclos / incubes * 100 : null,
    tauxViabilite12Mois: eclosAvecViables > 0 ? viables / eclosAvecViables * 100 : null,
    poussins12Mois: poussins,
  );
}

const statutsCouvee = {
  'en_incubation': ('En incubation', Colors.amber),
  'mire': ('Mirée', Colors.amber),
  'eclos': ('Éclose', Colors.green),
  'termine': ('Terminée', Colors.blueGrey),
  'annule': ('Annulée', Colors.grey),
};

String statutCouveeLibelle(String s) => statutsCouvee[s]?.$1 ?? s;
MaterialColor statutCouveeCouleur(String s) => statutsCouvee[s]?.$2 ?? Colors.grey;
