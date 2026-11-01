import 'package:flutter/material.dart';

import '../models/bande.dart';
import '../models/sante.dart';
import 'crm_labels.dart';

/// Jour civil d'une date d'événement (le serveur stocke minuit UTC : on garde ses composantes).
DateTime jourEvenement(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _jour(DateTime d) => DateTime(d.year, d.month, d.day);

int _ecart(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// Intervention prévue sur une bande (vaccin, traitement, contrôle).
class InterventionPrevue {
  final Bande bande;
  final EvenementPrevisionnel evenement;

  const InterventionPrevue(this.bande, this.evenement);

  DateTime get date => jourEvenement(evenement.datePrevue);

  /// Âge de la bande le jour prévu.
  int get ageJours => _ecart(bande.dateOuverture, date);

  DueBucket echeance({DateTime? now}) => dueBucketFor(date, now: now);
}

/// Interventions non faites des bandes ouvertes, de la plus ancienne à la plus lointaine.
List<InterventionPrevue> interventionsAFaire(List<Bande> bandes) {
  final out = <InterventionPrevue>[
    for (final b in bandes)
      if (b.dateFermeture == null && b.statut != 'fermee')
        for (final e in b.evenementsPrevisionnels)
          if (e.statut != 'termine' && e.id != null) InterventionPrevue(b, e),
  ];
  out.sort((a, b) => a.date.compareTo(b.date));
  return out;
}

/// Interventions faites sur la période (pour le résumé).
int interventionsFaites(List<Bande> bandes, {required DateTime depuis}) {
  var n = 0;
  for (final b in bandes) {
    for (final e in b.evenementsPrevisionnels) {
      final d = e.dateRealisation?.toLocal();
      if (e.statut == 'termine' && d != null && !d.isBefore(_jour(depuis))) n++;
    }
  }
  return n;
}

/// Délai d'attente d'un traitement (période pendant laquelle on ne vend pas les animaux).
class DelaiAttente {
  final TraitementSanitaire traitement;
  final DateTime fin;
  final int joursRestants;

  const DelaiAttente(this.traitement, this.fin, this.joursRestants);

  bool get enCours => joursRestants > 0;
}

DelaiAttente? delaiAttente(TraitementSanitaire t, {DateTime? now}) {
  final debut = t.dateTraitement?.toLocal();
  if (debut == null || t.delaiAttenteJours <= 0) return null;
  final fin = DateTime(debut.year, debut.month, debut.day + t.delaiAttenteJours);
  return DelaiAttente(t, fin, _ecart(now ?? DateTime.now(), fin));
}

/// Délais d'attente en cours, du plus long au plus court.
List<DelaiAttente> delaisEnCours(List<TraitementSanitaire> traitements, {DateTime? now}) {
  final out = [
    for (final t in traitements)
      ?switch (delaiAttente(t, now: now)) {
        final d? when d.enCours => d,
        _ => null,
      },
  ];
  out.sort((a, b) => b.fin.compareTo(a.fin));
  return out;
}

/// Résumé de l'écran Prophylaxie.
class ResumeProphylaxie {
  final int enRetard;
  final int aujourdhui;
  final int cetteSemaine;
  final int faitesCeMois;
  final int delais;

  const ResumeProphylaxie(this.enRetard, this.aujourdhui, this.cetteSemaine, this.faitesCeMois, this.delais);
}

ResumeProphylaxie resumeProphylaxie(List<Bande> bandes, List<TraitementSanitaire> traitements, {DateTime? now}) {
  final t = now ?? DateTime.now();
  final a = interventionsAFaire(bandes);
  int n(DueBucket b) => a.where((x) => x.echeance(now: t) == b).length;
  return ResumeProphylaxie(
    n(DueBucket.enRetard),
    n(DueBucket.aujourdhui),
    n(DueBucket.cetteSemaine),
    interventionsFaites(bandes, depuis: DateTime(t.year, t.month, 1)),
    delaisEnCours(traitements, now: t).length,
  );
}

/// Description d'un événement généré par une étape (même format que le serveur à la création de bande).
String descriptionEtape(ProtocoleEtape e) =>
    'J${e.jourAge} - ${e.intervention}${e.produit.isNotEmpty ? ' (${e.produit})' : ''}';

/// Événements à ajouter à une bande en cours pour un protocole : étapes d'aujourd'hui ou à venir,
/// sans doublon avec ce qui est déjà planifié. [ignorees] = étapes déjà passées.
({List<Map<String, dynamic>> aCreer, int ignorees, int dejaPrevues}) etapesAAppliquer(
  ProtocoleVaccinal p,
  Bande b, {
  DateTime? now,
}) {
  final today = _jour(now ?? DateTime.now());
  final existantes = {for (final e in b.evenementsPrevisionnels) e.description.trim().toLowerCase()};
  final aCreer = <Map<String, dynamic>>[];
  var ignorees = 0, deja = 0;
  for (final e in [...p.etapes]..sort((x, y) => x.jourAge.compareTo(y.jourAge))) {
    final date = DateTime(b.dateOuverture.year, b.dateOuverture.month, b.dateOuverture.day + e.jourAge);
    final desc = descriptionEtape(e);
    if (existantes.contains(desc.toLowerCase())) {
      deja++;
      continue;
    }
    if (date.isBefore(today)) {
      ignorees++;
      continue;
    }
    aCreer.add({
      'type': 'vaccination',
      'datePrevue': DateTime.utc(date.year, date.month, date.day).toIso8601String(),
      'description': desc,
      'priorite': 'haute',
      'commentaires': [if (e.dose.isNotEmpty) 'Dose: ${e.dose}', if (e.voie.isNotEmpty) 'Voie: ${e.voie}', if (e.notes.isNotEmpty) e.notes]
          .join(' • '),
    });
  }
  return (aCreer: aCreer, ignorees: ignorees, dejaPrevues: deja);
}

/// Voies d'administration proposées.
const voiesAdministration = [
  'Eau de boisson',
  'Nébulisation (spray)',
  'Goutte oculaire / nasale',
  'Injection',
  'Aliment',
  'Transfixion alaire',
];

/// Types de traitement du registre.
const typesTraitement = <String, (String, IconData, MaterialColor)>{
  'vaccination': ('Vaccination', Icons.vaccines_outlined, Colors.teal),
  'traitement': ('Traitement', Icons.medication_outlined, Colors.purple),
  'deparasitage': ('Déparasitage', Icons.bug_report_outlined, Colors.brown),
  'vitamines': ('Vitamines', Icons.local_drink_outlined, Colors.orange),
  'desinfection': ('Désinfection', Icons.cleaning_services_outlined, Colors.blueGrey),
};

(String, IconData, MaterialColor) typeTraitement(String type) =>
    typesTraitement[type] ?? (type.isEmpty ? 'Traitement' : type, Icons.medication_outlined, Colors.purple);

/// Modèle de protocole proposé (à adapter avec le vétérinaire).
class ModeleProtocole {
  final String nom;
  final String typeVolaille;
  final List<ProtocoleEtape> etapes;

  const ModeleProtocole(this.nom, this.typeVolaille, this.etapes);

  Map<String, dynamic> toPayload() => {
        'nom': nom,
        'typeVolaille': typeVolaille,
        'etapes': [for (final e in etapes) e.toJson()],
        'notes': 'Créé depuis un modèle NamoFarm : à adapter avec votre vétérinaire.',
      };
}

final modelesProtocoles = [
  ModeleProtocole('Poulet de chair 45 jours', 'poulet_ameliore_45j', [
    ProtocoleEtape(jourAge: 1, intervention: 'Vitamines et anti-stress', produit: 'Vitamines', voie: 'Eau de boisson'),
    ProtocoleEtape(jourAge: 7, intervention: 'Vaccin Newcastle + bronchite', produit: 'HB1 / H120', voie: 'Eau de boisson'),
    ProtocoleEtape(jourAge: 14, intervention: 'Vaccin Gumboro', produit: 'Gumboro', voie: 'Eau de boisson'),
    ProtocoleEtape(jourAge: 21, intervention: 'Rappel Newcastle', produit: 'La Sota', voie: 'Eau de boisson'),
    ProtocoleEtape(jourAge: 24, intervention: 'Rappel Gumboro', produit: 'Gumboro', voie: 'Eau de boisson'),
  ]),
  ModeleProtocole('Poulet local amélioré', 'poulet_local_ameliore', [
    ProtocoleEtape(jourAge: 3, intervention: 'Vaccin Newcastle', produit: 'HB1', voie: 'Goutte oculaire / nasale'),
    ProtocoleEtape(jourAge: 10, intervention: 'Vaccin Gumboro', produit: 'Gumboro', voie: 'Eau de boisson'),
    ProtocoleEtape(jourAge: 21, intervention: 'Rappel Newcastle', produit: 'La Sota', voie: 'Eau de boisson'),
    ProtocoleEtape(jourAge: 28, intervention: 'Rappel Gumboro', produit: 'Gumboro', voie: 'Eau de boisson'),
    ProtocoleEtape(jourAge: 42, intervention: 'Vaccin variole aviaire', produit: 'Variole', voie: 'Transfixion alaire'),
    ProtocoleEtape(jourAge: 56, intervention: 'Déparasitage', produit: 'Vermifuge', voie: 'Eau de boisson'),
  ]),
  ModeleProtocole('Poule pondeuse', 'poule_pondeuse', [
    ProtocoleEtape(jourAge: 1, intervention: 'Vaccin Marek', produit: 'Marek', voie: 'Injection'),
    ProtocoleEtape(jourAge: 7, intervention: 'Vaccin Newcastle + bronchite', produit: 'HB1 / H120', voie: 'Eau de boisson'),
    ProtocoleEtape(jourAge: 14, intervention: 'Vaccin Gumboro', produit: 'Gumboro', voie: 'Eau de boisson'),
    ProtocoleEtape(jourAge: 28, intervention: 'Rappel Newcastle', produit: 'La Sota', voie: 'Eau de boisson'),
    ProtocoleEtape(jourAge: 42, intervention: 'Vaccin variole aviaire', produit: 'Variole', voie: 'Transfixion alaire'),
    ProtocoleEtape(jourAge: 112, intervention: 'Rappel Newcastle avant ponte', produit: 'Newcastle inactivé', voie: 'Injection'),
  ]),
];
