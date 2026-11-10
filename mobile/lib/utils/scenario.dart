import 'dart:math' as math;

import '../models/bande.dart';
import '../models/commande.dart';
import '../models/sante.dart';
import '../models/stock.dart';
import 'bande_kpis.dart';

/// Provenance d'une valeur proposée dans un scénario.
enum Origine { reel, reference, estime, modifie }

const origineLabels = {
  Origine.reel: 'Vos données',
  Origine.reference: 'Référence',
  Origine.estime: 'Estimation',
  Origine.modifie: 'Modifié',
};

/// Clés des valeurs dont on suit la provenance.
class Cle {
  static const mortalite = 'mortalite';
  static const duree = 'duree';
  static const poids = 'poids';
  static const conso = 'conso';
  static const prixPoussin = 'prixPoussin';
  static const prophylaxie = 'prophylaxie';
  static const vitamines = 'vitamines';
  static const vente = 'vente';
  static String phase(int i) => 'phase$i';
}

enum ModeCharge { forfait, parSujet, parJour }

const modeChargeLabels = {
  ModeCharge.forfait: 'Forfait',
  ModeCharge.parSujet: 'Par sujet',
  ModeCharge.parJour: 'Par jour',
};

/// Estimations utilisées quand l'exploitation n'a pas (encore) de données (FCFA).
class Estimations {
  static const mortalitePct = 5.0;
  static const prixPoussin = 600.0;
  static const prixKgAliment = 400.0;
  static const prixVenteKgVif = 2000.0;
  static const prophylaxieParSujet = 150.0;
  static const prophylaxieParIntervention = 25.0;
  static const vitaminesParSujet = 40.0;
  static const imprevusPct = 3.0;
  static const videSanitaireJours = 14;
  static const sacKg = 50.0;
}

double _num(dynamic v, [double def = 0]) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? def;

class PhaseAliment {
  String nom;

  /// Part de la consommation totale (en %, normalisée au calcul).
  double part;
  double prixKg;

  PhaseAliment({required this.nom, required this.part, required this.prixKg});

  factory PhaseAliment.fromJson(Map<String, dynamic> j) =>
      PhaseAliment(nom: '${j['nom'] ?? ''}', part: _num(j['part']), prixKg: _num(j['prixKg']));

  Map<String, dynamic> toJson() => {'nom': nom, 'part': part, 'prixKg': prixKg};
}

class ChargeLigne {
  String id;
  String libelle;
  double montant;
  ModeCharge mode;

  ChargeLigne({required this.id, required this.libelle, required this.montant, this.mode = ModeCharge.forfait});

  factory ChargeLigne.fromJson(Map<String, dynamic> j) => ChargeLigne(
        id: '${j['id'] ?? DateTime.now().microsecondsSinceEpoch}',
        libelle: '${j['libelle'] ?? ''}',
        montant: _num(j['montant']),
        mode: ModeCharge.values.firstWhere((m) => m.name == j['mode'], orElse: () => ModeCharge.forfait),
      );

  Map<String, dynamic> toJson() => {'id': id, 'libelle': libelle, 'montant': montant, 'mode': mode.name};
}

/// Simulation de production : toutes les valeurs sont modifiables.
class Scenario {
  String id;
  String nom;
  String typeVolaille;

  /// Sujets à vendre en fin de bande (les poussins à commander s'en déduisent avec la mortalité).
  int sujets;
  double mortalitePct;
  int dureeJours;
  int videSanitaireJours;
  double poidsFinalG;
  DateTime debut;

  double prixPoussin;

  /// Consommation d'aliment d'un sujet mené à terme (kg).
  double consoKgParSujet;
  double sacKg;
  List<PhaseAliment> phases;

  double prophylaxieParSujet;
  double vitaminesParSujet;
  String protocoleNom;
  int nbInterventions;

  List<ChargeLigne> charges;
  double imprevusPct;

  bool venteParKg;
  double prixVente;

  Map<String, Origine> origines;

  Scenario({
    required this.id,
    required this.nom,
    this.typeVolaille = 'poulet_ameliore_45j',
    this.sujets = 1000,
    this.mortalitePct = Estimations.mortalitePct,
    this.dureeJours = 45,
    this.videSanitaireJours = Estimations.videSanitaireJours,
    this.poidsFinalG = 2000,
    DateTime? debut,
    this.prixPoussin = Estimations.prixPoussin,
    this.consoKgParSujet = 4.5,
    this.sacKg = Estimations.sacKg,
    List<PhaseAliment>? phases,
    this.prophylaxieParSujet = Estimations.prophylaxieParSujet,
    this.vitaminesParSujet = Estimations.vitaminesParSujet,
    this.protocoleNom = '',
    this.nbInterventions = 0,
    List<ChargeLigne>? charges,
    this.imprevusPct = Estimations.imprevusPct,
    this.venteParKg = true,
    this.prixVente = Estimations.prixVenteKgVif,
    Map<String, Origine>? origines,
  })  : debut = debut ?? DateTime.now(),
        phases = phases ?? [],
        charges = charges ?? [],
        origines = origines ?? {};

  factory Scenario.fromJson(Map<String, dynamic> j) {
    final origines = <String, Origine>{};
    (j['origines'] as Map? ?? const {}).forEach((k, v) {
      final o = Origine.values.where((e) => e.name == v);
      if (o.isNotEmpty) origines['$k'] = o.first;
    });
    return Scenario(
      id: '${j['id'] ?? DateTime.now().microsecondsSinceEpoch}',
      nom: '${j['nom'] ?? 'Scénario'}',
      typeVolaille: '${j['typeVolaille'] ?? 'autre'}',
      sujets: _num(j['sujets'], 1000).round(),
      mortalitePct: _num(j['mortalitePct'], Estimations.mortalitePct),
      dureeJours: _num(j['dureeJours'], 45).round(),
      videSanitaireJours: _num(j['videSanitaireJours'], Estimations.videSanitaireJours.toDouble()).round(),
      poidsFinalG: _num(j['poidsFinalG'], 2000),
      debut: DateTime.tryParse('${j['debut'] ?? ''}'),
      prixPoussin: _num(j['prixPoussin']),
      consoKgParSujet: _num(j['consoKgParSujet']),
      sacKg: _num(j['sacKg'], Estimations.sacKg),
      phases: [for (final p in (j['phases'] as List? ?? const []).whereType<Map>()) PhaseAliment.fromJson(Map<String, dynamic>.from(p))],
      prophylaxieParSujet: _num(j['prophylaxieParSujet']),
      vitaminesParSujet: _num(j['vitaminesParSujet']),
      protocoleNom: '${j['protocoleNom'] ?? ''}',
      nbInterventions: _num(j['nbInterventions']).round(),
      charges: [for (final c in (j['charges'] as List? ?? const []).whereType<Map>()) ChargeLigne.fromJson(Map<String, dynamic>.from(c))],
      imprevusPct: _num(j['imprevusPct']),
      venteParKg: j['venteParKg'] != false,
      prixVente: _num(j['prixVente']),
      origines: origines,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nom': nom,
        'typeVolaille': typeVolaille,
        'sujets': sujets,
        'mortalitePct': mortalitePct,
        'dureeJours': dureeJours,
        'videSanitaireJours': videSanitaireJours,
        'poidsFinalG': poidsFinalG,
        'debut': debut.toIso8601String(),
        'prixPoussin': prixPoussin,
        'consoKgParSujet': consoKgParSujet,
        'sacKg': sacKg,
        'phases': [for (final p in phases) p.toJson()],
        'prophylaxieParSujet': prophylaxieParSujet,
        'vitaminesParSujet': vitaminesParSujet,
        'protocoleNom': protocoleNom,
        'nbInterventions': nbInterventions,
        'charges': [for (final c in charges) c.toJson()],
        'imprevusPct': imprevusPct,
        'venteParKg': venteParKg,
        'prixVente': prixVente,
        'origines': {for (final e in origines.entries) e.key: e.value.name},
      };

  Scenario copie({String? id, String? nom}) {
    final c = Scenario.fromJson(toJson());
    if (id != null) c.id = id;
    if (nom != null) c.nom = nom;
    return c;
  }
}

/// Poste de coût du résultat (pour la répartition).
class PosteCout {
  final String cle;
  final String libelle;
  final double montant;

  const PosteCout(this.cle, this.libelle, this.montant);
}

class ResultatScenario {
  final int poussins;
  final int morts;
  final int sujetsVendus;
  final double poidsTotalKg;
  final double alimentKg;
  final double sacs;
  final List<double> alimentKgParPhase;
  final List<double> coutParPhase;
  final List<double> montantsCharges;
  final double coutPoussins;
  final double coutAliment;
  final double coutProphylaxie;
  final double coutVitamines;
  final double coutCharges;
  final double imprevus;
  final double total;
  final double coutParSujet;
  final double coutParKg;
  final double ca;
  final double marge;
  final double margePct;
  final double prixMinSujet;
  final double prixMinKg;

  /// Indice de consommation : kg d'aliment par kg de poids vif produit.
  final double ica;
  final DateTime finLot;
  final DateTime prochaineBande;

  const ResultatScenario({
    required this.poussins,
    required this.morts,
    required this.sujetsVendus,
    required this.poidsTotalKg,
    required this.alimentKg,
    required this.sacs,
    required this.alimentKgParPhase,
    required this.coutParPhase,
    required this.montantsCharges,
    required this.coutPoussins,
    required this.coutAliment,
    required this.coutProphylaxie,
    required this.coutVitamines,
    required this.coutCharges,
    required this.imprevus,
    required this.total,
    required this.coutParSujet,
    required this.coutParKg,
    required this.ca,
    required this.marge,
    required this.margePct,
    required this.prixMinSujet,
    required this.prixMinKg,
    required this.ica,
    required this.finLot,
    required this.prochaineBande,
  });

  double get coutProphylaxieTotal => coutProphylaxie + coutVitamines;

  List<PosteCout> get postes => [
        PosteCout('poussins', 'Poussins', coutPoussins),
        PosteCout('aliment', 'Aliment', coutAliment),
        PosteCout('prophylaxie', 'Prophylaxie', coutProphylaxieTotal),
        PosteCout('charges', 'Charges d’exploitation', coutCharges),
        PosteCout('imprevus', 'Imprévus', imprevus),
      ];
}

/// Les sujets morts consomment en moyenne la moitié d'un cycle complet.
const _partConsoMorts = 0.5;

ResultatScenario calculerScenario(Scenario s) {
  final sujets = math.max(0, s.sujets);
  final m = (s.mortalitePct / 100).clamp(0.0, 0.95);
  final poussins = (sujets / (1 - m)).ceil();
  final morts = poussins - sujets;

  final alimentKg = math.max(0.0, s.consoKgParSujet) * (sujets + morts * _partConsoMorts);
  final somme = s.phases.fold<double>(0, (t, p) => t + math.max(0, p.part));
  final parts = [
    for (final p in s.phases) somme > 0 ? math.max(0.0, p.part) / somme : 1 / s.phases.length,
  ];
  final kgPhase = [for (final p in parts) alimentKg * p];
  final coutPhase = [for (var i = 0; i < s.phases.length; i++) kgPhase[i] * s.phases[i].prixKg];
  final coutAliment = coutPhase.fold<double>(0, (t, c) => t + c);

  final coutPoussins = poussins * s.prixPoussin;
  final coutProphylaxie = poussins * s.prophylaxieParSujet;
  final coutVitamines = poussins * s.vitaminesParSujet;
  final montantsCharges = [
    for (final c in s.charges)
      switch (c.mode) {
        ModeCharge.forfait => c.montant,
        ModeCharge.parSujet => c.montant * poussins,
        ModeCharge.parJour => c.montant * math.max(0, s.dureeJours),
      },
  ];
  final coutCharges = montantsCharges.fold<double>(0, (t, c) => t + c);

  final sousTotal = coutPoussins + coutAliment + coutProphylaxie + coutVitamines + coutCharges;
  final imprevus = sousTotal * math.max(0.0, s.imprevusPct) / 100;
  final total = sousTotal + imprevus;

  final poidsTotalKg = sujets * s.poidsFinalG / 1000;
  final ca = s.venteParKg ? poidsTotalKg * s.prixVente : sujets * s.prixVente;
  final marge = ca - total;
  final fin = DateTime(s.debut.year, s.debut.month, s.debut.day + s.dureeJours);

  return ResultatScenario(
    poussins: poussins,
    morts: morts,
    sujetsVendus: sujets,
    poidsTotalKg: poidsTotalKg,
    alimentKg: alimentKg,
    sacs: s.sacKg > 0 ? alimentKg / s.sacKg : 0,
    alimentKgParPhase: kgPhase,
    coutParPhase: coutPhase,
    montantsCharges: montantsCharges,
    coutPoussins: coutPoussins,
    coutAliment: coutAliment,
    coutProphylaxie: coutProphylaxie,
    coutVitamines: coutVitamines,
    coutCharges: coutCharges,
    imprevus: imprevus,
    total: total,
    coutParSujet: sujets > 0 ? total / sujets : 0,
    coutParKg: poidsTotalKg > 0 ? total / poidsTotalKg : 0,
    ca: ca,
    marge: marge,
    margePct: ca > 0 ? marge / ca * 100 : 0,
    prixMinSujet: sujets > 0 ? total / sujets : 0,
    prixMinKg: poidsTotalKg > 0 ? total / poidsTotalKg : 0,
    ica: poidsTotalKg > 0 ? alimentKg / poidsTotalKg : 0,
    finLot: fin,
    prochaineBande: DateTime(fin.year, fin.month, fin.day + math.max(0, s.videSanitaireJours)),
  );
}

/// Marge pour chaque combinaison (variation du coût de l'aliment en ligne, du prix de vente en colonne), en %.
List<List<double>> sensibiliteMarge(
  Scenario s, {
  List<double> variationsAliment = const [-10, 0, 10],
  List<double> variationsVente = const [-10, 0, 10],
}) {
  return [
    for (final va in variationsAliment)
      [
        for (final vv in variationsVente)
          () {
            final c = s.copie();
            for (final p in c.phases) {
              p.prixKg *= 1 + va / 100;
            }
            c.prixVente *= 1 + vv / 100;
            return calculerScenario(c).marge;
          }(),
      ],
  ];
}

/// Données de l'exploitation à partir desquelles on propose un scénario.
class DonneesScenario {
  final Map<String, ReferenceType> references;
  final List<Bande> bandes;
  final List<Stock> stocks;
  final List<Commande> commandes;
  final List<ProtocoleVaccinal> protocoles;

  const DonneesScenario({
    this.references = const {},
    this.bandes = const [],
    this.stocks = const [],
    this.commandes = const [],
    this.protocoles = const [],
  });
}

/// Prix d'un kg d'aliment d'après l'unité du stock (null si inconnue ou sans prix).
double? prixKgStock(Stock s, {double sacKg = Estimations.sacKg}) {
  if (s.prixUnitaire <= 0) return null;
  switch (s.unite.trim().toLowerCase()) {
    case 'kg':
    case 'kilo':
    case 'kilos':
      return s.prixUnitaire;
    case 'sac':
    case 'sacs':
      return s.prixUnitaire / sacKg;
    case 'g':
      return s.prixUnitaire * 1000;
    case 't':
    case 'tonne':
    case 'tonnes':
      return s.prixUnitaire / 1000;
  }
  return null;
}

String _sans(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[àâä]'), 'a')
    .replaceAll(RegExp('[ôö]'), 'o')
    .replaceAll(RegExp('[ûùü]'), 'u')
    .replaceAll(RegExp('[îï]'), 'i');

const _phasesDefaut = [
  ('Démarrage', 20.0, ['demarrage', 'starter', 'chair 1']),
  ('Croissance', 35.0, ['croissance', 'grower']),
  ('Finition', 45.0, ['finition', 'finisher']),
];

/// Propose un scénario d'après ce que l'application sait déjà ; chaque valeur garde sa provenance.
Scenario scenarioPropose(
  DonneesScenario d, {
  String type = 'poulet_ameliore_45j',
  int sujets = 1000,
  String nom = 'Scénario réaliste',
  DateTime? debut,
}) {
  final s = Scenario(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    nom: nom,
    typeVolaille: type,
    sujets: sujets,
    debut: debut,
  );
  s.origines
    ..[Cle.duree] = Origine.reference
    ..[Cle.poids] = Origine.reference
    ..[Cle.conso] = Origine.reference;
  appliquerReference(s, d.references);

  // Mortalité observée sur les bandes (même type de préférence).
  final avecEffectif = d.bandes.where((b) => b.nombreInitial > 0).toList();
  final memeType = avecEffectif.where((b) => b.typeVolaille == type).toList();
  final base = memeType.isNotEmpty ? memeType : avecEffectif;
  final initiaux = base.fold<int>(0, (t, b) => t + b.nombreInitial);
  final morts = base.fold<int>(0, (t, b) => t + b.mortaliteTotale);
  if (initiaux > 0 && morts > 0) {
    s.mortalitePct = double.parse((morts / initiaux * 100).clamp(0.5, 40).toStringAsFixed(1));
    s.origines[Cle.mortalite] = Origine.reel;
  } else {
    s.mortalitePct = Estimations.mortalitePct;
    s.origines[Cle.mortalite] = Origine.estime;
  }

  // Dernier prix de poussin saisi.
  final avecPrix = d.bandes.where((b) => b.coutPoussin > 0).toList()..sort((a, b) => b.dateOuverture.compareTo(a.dateOuverture));
  if (avecPrix.isNotEmpty) {
    s.prixPoussin = avecPrix.first.coutPoussin;
    s.origines[Cle.prixPoussin] = Origine.reel;
  } else {
    s.prixPoussin = Estimations.prixPoussin;
    s.origines[Cle.prixPoussin] = Origine.estime;
  }

  // Aliment : prix des stocks (par phase si le nom l'indique, sinon moyenne).
  final aliments = d.stocks.where((x) => x.categorie == 'aliment').toList();
  final prixMoyen = () {
    final prix = [for (final x in aliments) ?prixKgStock(x, sacKg: s.sacKg)];
    return prix.isEmpty ? null : prix.reduce((a, b) => a + b) / prix.length;
  }();
  for (var i = 0; i < _phasesDefaut.length; i++) {
    final (nomPhase, part, mots) = _phasesDefaut[i];
    final trouve = aliments.where((x) => mots.any(_sans(x.nom).contains)).map((x) => prixKgStock(x, sacKg: s.sacKg)).whereType<double>();
    final prix = trouve.isNotEmpty ? trouve.first : prixMoyen;
    s.phases.add(PhaseAliment(nom: nomPhase, part: part, prixKg: prix ?? Estimations.prixKgAliment));
    s.origines[Cle.phase(i)] = prix != null ? Origine.reel : Origine.estime;
  }

  // Prophylaxie : protocole du type, coût réel par tête sur l'historique des soins.
  final protocole = protocolePour(type, d.protocoles);
  s.protocoleNom = protocole?.nom ?? '';
  s.nbInterventions = protocole?.etapes.length ?? 0;
  final bandesSoins = d.bandes.where((b) => b.nombreInitial > 0 && b.evenementsSante.any((e) => e.cout > 0)).toList();
  if (bandesSoins.isNotEmpty) {
    final cout = bandesSoins.fold<double>(0, (t, b) => t + b.evenementsSante.fold<double>(0, (u, e) => u + e.cout));
    final tetes = bandesSoins.fold<int>(0, (t, b) => t + b.nombreInitial);
    s.prophylaxieParSujet = (cout / tetes).roundToDouble();
    s.origines[Cle.prophylaxie] = Origine.reel;
  } else {
    s.prophylaxieParSujet = s.nbInterventions > 0
        ? s.nbInterventions * Estimations.prophylaxieParIntervention
        : Estimations.prophylaxieParSujet;
    s.origines[Cle.prophylaxie] = Origine.estime;
  }
  s.vitaminesParSujet = Estimations.vitaminesParSujet;
  s.origines[Cle.vitamines] = Origine.estime;

  // Prix de vente : moyenne pondérée des ventes de poulets, sinon estimation au kg vif.
  var qte = 0, montant = 0.0;
  for (final c in d.commandes.where((c) => c.statut != 'annulee')) {
    for (final p in c.produits) {
      final n = _sans(p.nom);
      if (p.prixUnitaire > 0 && p.quantite > 0 && (n.contains('poulet') || n.contains('poule') || n.contains('chair'))) {
        qte += p.quantite;
        montant += p.quantite * p.prixUnitaire;
      }
    }
  }
  if (qte > 0) {
    s.venteParKg = false;
    s.prixVente = (montant / qte).roundToDouble();
    s.origines[Cle.vente] = Origine.reel;
  } else {
    s.venteParKg = true;
    s.prixVente = Estimations.prixVenteKgVif;
    s.origines[Cle.vente] = Origine.estime;
  }

  s.charges = chargesParDefaut();
  return s;
}

/// Protocole vaccinal du type de volaille, sinon le premier protocole renseigné.
ProtocoleVaccinal? protocolePour(String type, List<ProtocoleVaccinal> protocoles) {
  final avecEtapes = protocoles.where((p) => p.etapes.isNotEmpty).toList();
  return avecEtapes.where((p) => p.typeVolaille == type).firstOrNull ?? avecEtapes.firstOrNull;
}

/// Durée, poids final et consommation d'après les références théoriques du type.
void appliquerReference(Scenario s, Map<String, ReferenceType> refs) {
  final r = referencePour({...defaultReferences, ...refs}, s.typeVolaille);
  s.dureeJours = r.dureeJours;
  s.poidsFinalG = r.poidsFinalG;
  s.consoKgParSujet = r.consoTotaleKgParTete;
  s.origines
    ..[Cle.duree] = Origine.reference
    ..[Cle.poids] = Origine.reference
    ..[Cle.conso] = Origine.reference;
}

List<ChargeLigne> chargesParDefaut() => [
      ChargeLigne(id: 'litiere', libelle: 'Litière et copeaux', montant: 35, mode: ModeCharge.parSujet),
      ChargeLigne(id: 'eau', libelle: 'Eau et électricité', montant: 2500, mode: ModeCharge.parJour),
      ChargeLigne(id: 'mo', libelle: 'Main-d’œuvre', montant: 3000, mode: ModeCharge.parJour),
      ChargeLigne(id: 'desinfection', libelle: 'Désinfection et vide sanitaire', montant: 15000),
      ChargeLigne(id: 'divers', libelle: 'Transport et divers', montant: 20, mode: ModeCharge.parSujet),
    ];
