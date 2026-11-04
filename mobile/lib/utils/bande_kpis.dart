import 'package:flutter/material.dart';
import '../models/bande.dart';

/// Types de volaille (mêmes clés que les références théoriques de la Configuration).
const typesVolaille = <String, String>{
  'poulet_ameliore_45j': 'Poulet amélioré 45J',
  'poulet_local_ameliore': 'Poulet local amélioré',
  'poulet_ameliore': 'Poulet amélioré',
  'poulet_local': 'Poulet local',
  'poule_pondeuse': 'Poule pondeuse',
  'canard': 'Canard',
  'dinde': 'Dinde',
  'poulet_chair': 'Poulet de chair',
  'autre': 'Autre',
};

String typeVolailleLabel(String type) {
  final known = typesVolaille[type];
  if (known != null) return known;
  if (type.trim().isEmpty) return 'Autre';
  final t = type.replaceAll('_', ' ');
  return t[0].toUpperCase() + t.substring(1);
}

/// Point d'une courbe théorique (âge en jours).
class PointCourbe {
  final int age;
  final double? poidsG;
  final double? consoCumuleeKg;

  const PointCourbe(this.age, {this.poidsG, this.consoCumuleeKg});
}

double? _toDouble(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');

/// Référence théorique d'un type de volaille (durée, poids final, consommation, courbe).
class ReferenceType {
  final int dureeJours;
  final double poidsFinalG;
  final double consoTotaleKgParTete;
  final List<PointCourbe> courbe;

  const ReferenceType({
    required this.dureeJours,
    required this.poidsFinalG,
    required this.consoTotaleKgParTete,
    this.courbe = const [],
  });

  factory ReferenceType.fromJson(Map<String, dynamic> json) {
    final pts = <PointCourbe>[];
    for (final p in (json['courbeTheorique'] as List? ?? const []).whereType<Map>()) {
      final age = _toDouble(p['age'])?.round() ?? 0;
      if (age <= 0) continue;
      pts.add(PointCourbe(age, poidsG: _toDouble(p['poidsG']), consoCumuleeKg: _toDouble(p['consoCumuleeKg'])));
    }
    pts.sort((a, b) => a.age.compareTo(b.age));
    return ReferenceType(
      dureeJours: (_toDouble(json['dureeJours']) ?? 45).round(),
      poidsFinalG: _toDouble(json['poidsFinalG']) ?? 2500,
      consoTotaleKgParTete: _toDouble(json['consoTotaleKgParTete']) ?? 5,
      courbe: pts,
    );
  }

  static double? _interpolate(List<PointCourbe> pts, int age, double? Function(PointCourbe) value) {
    final valid = pts.where((p) => value(p) != null).toList();
    if (valid.isEmpty) return null;
    PointCourbe? before;
    PointCourbe? after;
    for (final p in valid) {
      if (p.age == age) return value(p);
      if (p.age < age) before = p;
      if (p.age > age && after == null) after = p;
    }
    if (before != null && after != null) {
      final ratio = (age - before.age) / (after.age - before.age);
      return value(before)! + (value(after)! - value(before)!) * ratio;
    }
    return value(before ?? after!);
  }

  /// Poids théorique (g) à un âge : courbe saisie, sinon progression linéaire depuis le poids d'arrivée.
  double poidsA(int age, {double poidsArriveeG = 0}) {
    final fromCurve = _interpolate(courbe, age, (p) => p.poidsG);
    if (fromCurve != null) return fromCurve;
    final p = (age / (dureeJours <= 0 ? 1 : dureeJours)).clamp(0.0, 1.0);
    return poidsArriveeG + (poidsFinalG - poidsArriveeG) * p;
  }
}

/// Valeurs par défaut identiques au backend (config/default_references.js).
const defaultReferences = <String, ReferenceType>{
  'poulet_ameliore_45j': ReferenceType(dureeJours: 45, poidsFinalG: 2000, consoTotaleKgParTete: 4.5),
  'poulet_local_ameliore': ReferenceType(dureeJours: 90, poidsFinalG: 1500, consoTotaleKgParTete: 5.5),
  'poulet_ameliore': ReferenceType(dureeJours: 60, poidsFinalG: 2200, consoTotaleKgParTete: 5.5),
  'poulet_local': ReferenceType(dureeJours: 120, poidsFinalG: 1400, consoTotaleKgParTete: 6.0),
  'poule_pondeuse': ReferenceType(dureeJours: 140, poidsFinalG: 1800, consoTotaleKgParTete: 14.0),
  'canard': ReferenceType(dureeJours: 50, poidsFinalG: 3200, consoTotaleKgParTete: 6.0),
  'dinde': ReferenceType(dureeJours: 90, poidsFinalG: 7000, consoTotaleKgParTete: 18.0),
  'autre': ReferenceType(dureeJours: 45, poidsFinalG: 2500, consoTotaleKgParTete: 5.0),
};

/// Références de la Configuration (`referencesTheoriques`), complétées par les valeurs par défaut.
Map<String, ReferenceType> parseReferences(dynamic raw) {
  final out = Map<String, ReferenceType>.from(defaultReferences);
  if (raw is Map) {
    raw.forEach((k, v) {
      if (v is Map) out[k.toString()] = ReferenceType.fromJson(Map<String, dynamic>.from(v));
    });
  }
  return out;
}

ReferenceType referencePour(Map<String, ReferenceType> refs, String type) => refs[type] ?? refs['autre'] ?? defaultReferences['autre']!;

/// Alertes affichées sur la carte et la fiche d'une bande.
enum BandeAlerte { retardCroissance, mortalite, saisieManquante }

const bandeAlerteLabels = {
  BandeAlerte.retardCroissance: 'Retard de croissance',
  BandeAlerte.mortalite: 'Mortalité en hausse',
  BandeAlerte.saisieManquante: 'Saisie du jour manquante',
};

const bandeAlerteColors = {
  BandeAlerte.retardCroissance: Colors.orange,
  BandeAlerte.mortalite: Colors.red,
  BandeAlerte.saisieManquante: Colors.blueGrey,
};

const bandeAlerteIcons = {
  BandeAlerte.retardCroissance: Icons.trending_down,
  BandeAlerte.mortalite: Icons.warning_amber_rounded,
  BandeAlerte.saisieManquante: Icons.edit_calendar_outlined,
};

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Écart en jours calendaires (insensible aux changements d'heure).
int _joursEntre(DateTime debut, DateTime fin) =>
    DateTime.utc(fin.year, fin.month, fin.day).difference(DateTime.utc(debut.year, debut.month, debut.day)).inDays;

/// Indicateurs zootechniques d'une bande.
class BandeKpis {
  final int ageJours;
  final int dureeJours;
  final DateTime dateSortiePrevue;
  final int effectif;

  /// Sujets mis en place à l'ouverture.
  final int effectifInitial;

  /// Nombre de morts depuis l'ouverture et sur les 7 derniers jours.
  final int morts;
  final int morts7j;
  final double viabilitePct;
  final double mortalitePct;
  final double alimentTotalKg;

  /// Dernière pesée (null si aucune).
  final double? poidsG;
  final DateTime? datePesee;
  final int? agePesee;
  final double? poidsReferenceG;

  /// Gain moyen quotidien (g/jour) depuis l'arrivée.
  final double? gmqG;

  /// Indice de consommation : kg d'aliment par kg de poids vif (à la dernière pesée).
  final double? ic;

  /// Indice d'efficacité (IEP/EPEF) = viabilité % × poids kg / (âge × IC) × 100.
  final double? iep;

  final DateTime? derniereSaisie;
  final double mortalite7jPct;
  final List<BandeAlerte> alertes;

  const BandeKpis({
    required this.ageJours,
    required this.dureeJours,
    required this.dateSortiePrevue,
    required this.effectif,
    this.effectifInitial = 0,
    this.morts = 0,
    this.morts7j = 0,
    required this.viabilitePct,
    required this.mortalitePct,
    required this.alimentTotalKg,
    this.poidsG,
    this.datePesee,
    this.agePesee,
    this.poidsReferenceG,
    this.gmqG,
    this.ic,
    this.iep,
    this.derniereSaisie,
    this.mortalite7jPct = 0,
    this.alertes = const [],
  });

  int get joursRestants => dureeJours - ageJours;

  /// Avancement du cycle (0 à 1).
  double get progression => dureeJours <= 0 ? 1 : (ageJours / dureeJours).clamp(0.0, 1.0);

  /// Écart du poids à la référence (%), positif = en avance.
  double? get ecartReferencePct =>
      (poidsG == null || poidsReferenceG == null || poidsReferenceG! <= 0) ? null : (poidsG! - poidsReferenceG!) / poidsReferenceG! * 100;
}

/// Calcule les indicateurs d'une bande. [now] permet les tests ; une bande fermée est évaluée à sa date de fermeture.
BandeKpis computeBandeKpis(Bande b, ReferenceType ref, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final active = b.dateFermeture == null && b.statut != 'fermee';
  final fin = b.dateFermeture ?? today;
  final age = _joursEntre(b.dateOuverture, fin).clamp(0, 100000);
  // La durée vient de Config → Paramètres (référence du type) ; la valeur de la bande
  // (45 j enregistrés par défaut à la création) ne sert qu'en secours.
  final duree = ref.dureeJours > 0 ? ref.dureeJours : b.dureeElevageJours;
  final initial = b.nombreInitial;
  final effectif = b.nombreActuel;
  // Viabilité = animaux non morts : les animaux vendus (sortis de l'effectif) restent des réussites.
  final viabilite = initial > 0 ? (initial - b.mortaliteTotale).clamp(0, initial) / initial * 100 : 0.0;
  final mortalitePct = initial > 0 ? b.mortaliteTotale / initial * 100 : 0.0;

  final suivis = [...b.suiviJournalier]..sort((x, y) => x.date.compareTo(y.date));
  final alimentTotal = suivis.fold<double>(0, (s, x) => s + x.alimentationKg);

  // Dernière pesée en cours d'élevage : la pesée d'arrivée (J0) ne mesure pas la croissance.
  SuiviJournalier? pesee;
  for (final s in suivis) {
    if (s.poidsMotenG > 0 && _joursEntre(b.dateOuverture, s.date) > 0) pesee = s;
  }

  double? poids;
  int? agePesee;
  double? poidsRef;
  double? gmq;
  double? ic;
  double? iep;
  if (pesee != null) {
    poids = pesee.poidsMotenG;
    agePesee = _joursEntre(b.dateOuverture, pesee.date);
    poidsRef = ref.poidsA(agePesee, poidsArriveeG: b.poidsArriveeG);
    gmq = (poids - b.poidsArriveeG) / agePesee;
    final alimJusquPesee = suivis.where((s) => !s.date.isAfter(pesee!.date)).fold<double>(0, (s, x) => s + x.alimentationKg);
    // Animaux présents le jour de la pesée (avant les ventes) : mis en place moins morts à cette date.
    final mortsALaPesee = suivis.where((s) => !s.date.isAfter(pesee!.date)).fold<int>(0, (s, x) => s + x.mortaliteJour);
    // Morts enregistrées hors suivi journalier (anciennes saisies) : comptées dès le début.
    final mortsSuivi = suivis.fold<int>(0, (s, x) => s + x.mortaliteJour);
    final mortsHorsSuivi = (b.mortaliteTotale - mortsSuivi).clamp(0, b.mortaliteTotale);
    final morts = mortsALaPesee + mortsHorsSuivi;
    final effectifPesee = initial > 0 ? (initial - morts).clamp(0, initial) : effectif;
    final biomasseKg = effectifPesee * poids / 1000;
    if (alimJusquPesee > 0 && biomasseKg > 0) {
      ic = alimJusquPesee / biomasseKg;
      iep = viabilite * (poids / 1000) / (agePesee * ic) * 100;
    }
  }

  final derniere = suivis.isEmpty ? null : suivis.last.date;
  final depuis = DateTime(today.year, today.month, today.day - 6);
  final morts7j = suivis.where((s) => !_day(s.date).isBefore(depuis)).fold<int>(0, (s, x) => s + x.mortaliteJour);
  final mortalite7j = initial > 0 ? morts7j / initial * 100 : 0.0;

  final alertes = <BandeAlerte>[];
  if (poids != null && poidsRef != null && poidsRef > 0 && (poids - poidsRef) / poidsRef < -0.10) {
    alertes.add(BandeAlerte.retardCroissance);
  }
  if (active && mortalite7j >= 2) alertes.add(BandeAlerte.mortalite);
  if (active && (derniere == null || _day(derniere) != _day(today))) alertes.add(BandeAlerte.saisieManquante);

  return BandeKpis(
    ageJours: age,
    dureeJours: duree,
    dateSortiePrevue: DateTime(b.dateOuverture.year, b.dateOuverture.month, b.dateOuverture.day + duree),
    effectif: effectif,
    effectifInitial: initial,
    morts: b.mortaliteTotale,
    morts7j: morts7j,
    viabilitePct: viabilite,
    mortalitePct: mortalitePct,
    alimentTotalKg: alimentTotal,
    poidsG: poids,
    datePesee: pesee?.date,
    agePesee: agePesee,
    poidsReferenceG: poidsRef,
    gmqG: gmq,
    ic: ic,
    iep: iep,
    derniereSaisie: derniere,
    mortalite7jPct: mortalite7j,
    alertes: alertes,
  );
}

/// Couleur d'un écart à la référence : vert si ≥ -5 %, orange jusqu'à -10 %, rouge au-delà.
MaterialColor couleurEcart(double? ecartPct) {
  if (ecartPct == null) return Colors.grey;
  if (ecartPct >= -5) return Colors.green;
  if (ecartPct >= -10) return Colors.orange;
  return Colors.red;
}

/// Points (âge, poids moyen g) des pesées d'une bande, pour superposer les courbes.
List<({int age, double poids})> courbeCroissance(Bande b) {
  final pts = <int, double>{};
  for (final s in b.suiviJournalier) {
    if (s.poidsMotenG <= 0) continue;
    final age = _joursEntre(b.dateOuverture, s.date);
    if (age < 0) continue;
    pts[age] = s.poidsMotenG;
  }
  final ages = pts.keys.toList()..sort();
  return [for (final a in ages) (age: a, poids: pts[a]!)];
}

/// Synthèse de la liste des bandes actives.
class ResumeBandes {
  final int nbBandes;
  final int effectifTotal;
  final int sortiesProchaines;
  final int nbAlertes;

  const ResumeBandes(this.nbBandes, this.effectifTotal, this.sortiesProchaines, this.nbAlertes);
}

ResumeBandes resumeBandes(List<Bande> actives, Map<String, BandeKpis> kpis, {DateTime? now, int horizonJours = 14}) {
  final today = _day(now ?? DateTime.now());
  var sorties = 0;
  var alertes = 0;
  for (final b in actives) {
    final k = kpis[b.id];
    if (k == null) continue;
    final dans = _joursEntre(today, k.dateSortiePrevue);
    if (dans >= 0 && dans <= horizonJours) sorties++;
    alertes += k.alertes.where((a) => a != BandeAlerte.saisieManquante).length;
  }
  return ResumeBandes(actives.length, actives.fold(0, (s, b) => s + b.nombreActuel), sorties, alertes);
}

/// Performances agrégées par bâtiment (moyennes simples des bandes).
class PerfBatiment {
  final String batiment;
  final int nbBandes;
  final double viabiliteMoy;
  final double? icMoy;
  final double? iepMoy;

  const PerfBatiment(this.batiment, this.nbBandes, this.viabiliteMoy, this.icMoy, this.iepMoy);
}

List<PerfBatiment> performancesParBatiment(List<Bande> bandes, Map<String, BandeKpis> kpis) {
  final groupes = <String, List<BandeKpis>>{};
  for (final b in bandes) {
    final k = kpis[b.id];
    if (k == null) continue;
    groupes.putIfAbsent(b.batiment.trim().isEmpty ? 'Non renseigné' : b.batiment.trim(), () => []).add(k);
  }
  double? moy(Iterable<double?> v) {
    final x = v.whereType<double>().toList();
    return x.isEmpty ? null : x.reduce((a, b) => a + b) / x.length;
  }

  final out = [
    for (final e in groupes.entries)
      PerfBatiment(
        e.key,
        e.value.length,
        moy(e.value.map((k) => k.viabilitePct)) ?? 0,
        moy(e.value.map((k) => k.ic)),
        moy(e.value.map((k) => k.iep)),
      ),
  ]..sort((a, b) => (b.iepMoy ?? -1).compareTo(a.iepMoy ?? -1));
  return out;
}
