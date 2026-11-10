import 'package:flutter/material.dart';

import '../models/alerte.dart';
import '../models/bande.dart';
import 'bande_kpis.dart';

/// Période des indicateurs du Tableau de bord.
enum PeriodeTdb { mois, troisMois, annee, tout }

const periodeTdbLibelles = {
  PeriodeTdb.mois: 'Ce mois',
  PeriodeTdb.troisMois: '3 mois',
  PeriodeTdb.annee: 'Cette année',
  PeriodeTdb.tout: 'Tout',
};

/// Libellé de la comparaison affichée sous les indicateurs.
const periodeTdbComparaison = {
  PeriodeTdb.mois: 'vs même période le mois dernier',
  PeriodeTdb.troisMois: 'vs les 3 mois précédents',
  PeriodeTdb.annee: 'vs même période l’an dernier',
  PeriodeTdb.tout: '',
};

typedef Intervalle = ({DateTime from, DateTime to});

DateTime _jour(DateTime d) => DateTime(d.year, d.month, d.day);

/// Intervalle de la période (jusqu'à aujourd'hui) et intervalle de comparaison de même durée.
/// « Tout » n'a pas de comparaison.
({Intervalle actuel, Intervalle? precedent}) intervallesTdb(PeriodeTdb p, {DateTime? now}) {
  final t = _jour(now ?? DateTime.now());
  switch (p) {
    case PeriodeTdb.mois:
      // Du 1er au jour J, comparé au 1er..J du mois précédent (borné à la fin de ce mois).
      final finPrec = DateTime(t.year, t.month, 0);
      final jourPrec = t.day > finPrec.day ? finPrec.day : t.day;
      return (
        actuel: (from: DateTime(t.year, t.month, 1), to: t),
        precedent: (from: DateTime(t.year, t.month - 1, 1), to: DateTime(t.year, t.month - 1, jourPrec)),
      );
    case PeriodeTdb.troisMois:
      // Du 1er de M-2 au jour J, comparé au 1er de M-5 .. jour J de M-3 (même durée).
      final finRef = DateTime(t.year, t.month - 2, 0);
      final jourRef = t.day > finRef.day ? finRef.day : t.day;
      return (
        actuel: (from: DateTime(t.year, t.month - 2, 1), to: t),
        precedent: (from: DateTime(t.year, t.month - 5, 1), to: DateTime(t.year, t.month - 3, jourRef)),
      );
    case PeriodeTdb.annee:
      final finPrec = DateTime(t.year - 1, t.month + 1, 0);
      final jourPrec = t.day > finPrec.day ? finPrec.day : t.day;
      return (
        actuel: (from: DateTime(t.year, 1, 1), to: t),
        precedent: (from: DateTime(t.year - 1, 1, 1), to: DateTime(t.year - 1, t.month, jourPrec)),
      );
    case PeriodeTdb.tout:
      return (actuel: (from: DateTime(2000, 1, 1), to: t), precedent: null);
  }
}

/// Variation en % (null si la référence est nulle).
double? evolutionPct(num actuel, num? precedent) {
  if (precedent == null || precedent == 0) return null;
  return (actuel - precedent) / precedent.abs() * 100;
}

/// Élément de la liste « À faire aujourd'hui ».
class ElementAujourdhui {
  final String titre;
  final String detail;
  final IconData icon;
  final MaterialColor color;

  /// Module à ouvrir au toucher (identifiants de la navigation).
  final String module;
  final bool urgent;
  final DateTime date;

  /// Bande concernée, ouverte directement au toucher.
  final String? bandeId;

  const ElementAujourdhui({
    required this.titre,
    required this.detail,
    required this.icon,
    required this.color,
    required this.module,
    required this.date,
    this.urgent = false,
    this.bandeId,
  });
}

String _module(Alerte a) {
  if (!a.automatique) return 'todo';
  switch (a.source) {
    case 'stock':
      return 'achats';
    case 'commercial':
    case 'crm_tache':
      return 'crm';
    case 'sanitaire':
    case 'planification':
      return 'bandes';
    default:
      return 'todo';
  }
}

({IconData icon, MaterialColor color}) _style(Alerte a, bool enRetard) {
  if (a.type == 'stock_bas') return (icon: Icons.inventory_2_outlined, color: Colors.orange);
  if (a.source == 'crm_tache') return (icon: Icons.phone_in_talk_outlined, color: enRetard ? Colors.red : Colors.blue);
  if (a.source == 'commercial') return (icon: Icons.local_shipping_outlined, color: Colors.purple);
  if (a.type == 'vaccination' || a.source == 'sanitaire' || a.source == 'planification') {
    return (icon: Icons.vaccines_outlined, color: enRetard ? Colors.red : Colors.teal);
  }
  return (icon: Icons.check_circle_outline, color: enRetard ? Colors.red : Colors.indigo);
}

/// Ce qui demande une action : les tâches en retard et les tâches urgentes (Todo et automatiques).
/// Les stocks bas et les livraisons n'y figurent jamais. Les plus anciennes échéances passent en tête.
List<ElementAujourdhui> elementsAujourdhui({
  List<Alerte> taches = const [],
  List<Alerte> automatiques = const [],
  DateTime? now,
}) {
  final today = _jour(now ?? DateTime.now());
  final out = <ElementAujourdhui>[];
  final vus = <String>{};

  for (final a in [...taches, ...automatiques]) {
    if (a.estFaite || a.type == 'stock_bas' || a.source == 'commercial') continue;
    final jour = _jour(a.dateEcheance.toLocal());
    final enRetard = jour.isBefore(today);
    final urgente = a.priorite == 'urgente';
    if (!enRetard && !urgente) continue;
    final cle = a.id ?? '${a.titre}|${a.dateEcheance}';
    if (!vus.add(cle)) continue;
    final s = _style(a, true);
    final retard = today.difference(jour).inDays;
    final ecart = jour.difference(today).inDays;
    out.add(
      ElementAujourdhui(
        titre: a.titre,
        detail: [
          if (enRetard)
            'En retard de $retard j'
          else
            ecart == 0 ? 'Urgente · aujourd’hui' : (ecart == 1 ? 'Urgente · demain' : 'Urgente · dans $ecart j'),
          if (a.bandeNom.isNotEmpty && !a.titre.contains(a.bandeNom)) a.bandeNom,
          if (a.message.isNotEmpty) a.message,
        ].join(' · '),
        icon: s.icon,
        color: s.color,
        module: _module(a),
        date: a.dateEcheance,
        urgent: true,
        bandeId: a.automatique ? null : a.bandeId,
      ),
    );
  }

  out.sort((a, b) => a.date.compareTo(b.date));
  return out;
}

/// Résumé de l'élevage en cours (bandes ouvertes).
class ResumeElevage {
  final int nbBandes;
  final int sujets;

  /// Morts cumulés ÷ sujets mis en place, toutes bandes ouvertes.
  final double mortalitePct;

  /// Moyenne des IC disponibles (null si aucune pesée).
  final double? icMoyen;
  final int nbAlertes;

  const ResumeElevage({
    required this.nbBandes,
    required this.sujets,
    required this.mortalitePct,
    required this.icMoyen,
    required this.nbAlertes,
  });
}

ResumeElevage resumeElevage(List<Bande> bandes, Map<String, BandeKpis> kpis) {
  final ouvertes = bandes.where((b) => b.dateFermeture == null && b.statut != 'fermee').toList();
  var sujets = 0;
  var initial = 0;
  var morts = 0;
  var alertes = 0;
  final ics = <double>[];
  for (final b in ouvertes) {
    sujets += b.nombreActuel;
    initial += b.nombreInitial;
    morts += b.mortaliteTotale;
    final k = kpis[b.id];
    if (k?.ic != null) ics.add(k!.ic!);
    alertes += k?.alertes.length ?? 0;
  }
  return ResumeElevage(
    nbBandes: ouvertes.length,
    sujets: sujets,
    mortalitePct: initial > 0 ? morts / initial * 100 : 0,
    icMoyen: ics.isEmpty ? null : ics.reduce((a, b) => a + b) / ics.length,
    nbAlertes: alertes,
  );
}

/// Ventes et dépenses d'un mois.
class MoisTendance {
  final int annee;
  final int mois;
  final double ventes;
  final double depenses;

  const MoisTendance(this.annee, this.mois, this.ventes, this.depenses);

  double get resultat => ventes - depenses;
}

double _valeurMois(Map<String, dynamic>? data, String cle, int mois) {
  for (final e in (data?[cle] as List? ?? const []).whereType<Map>()) {
    if ((e['mois'] as num?)?.toInt() == mois) {
      final v = e['total'];
      return v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    }
  }
  return 0;
}

/// Les 12 derniers mois (jusqu'au mois en cours) à partir des réponses /dashboard/tendance-mensuelle
/// de l'année en cours et de l'année précédente.
List<MoisTendance> douzeDerniersMois({
  Map<String, dynamic>? anneeCourante,
  Map<String, dynamic>? anneePrecedente,
  DateTime? now,
}) {
  final t = now ?? DateTime.now();
  return [
    for (var i = 11; i >= 0; i--)
      () {
        final d = DateTime(t.year, t.month - i, 1);
        final data = d.year == t.year ? anneeCourante : anneePrecedente;
        return MoisTendance(
          d.year,
          d.month,
          _valeurMois(data, 'ventes', d.month),
          _valeurMois(data, 'depenses', d.month),
        );
      }(),
  ];
}

/// Blocs du Tableau de bord (ordre et visibilité personnalisables).
enum BlocTdb { aujourdhui, indicateurs, bandes, tendance, commercial }

const blocTdbLibelles = {
  BlocTdb.aujourdhui: 'Aujourd’hui',
  BlocTdb.indicateurs: 'Indicateurs clés',
  BlocTdb.bandes: 'Bandes en cours',
  BlocTdb.tendance: 'Ventes et dépenses sur 12 mois',
  BlocTdb.commercial: 'Commercial',
};

const blocTdbIcons = {
  BlocTdb.aujourdhui: Icons.today_outlined,
  BlocTdb.indicateurs: Icons.insights_outlined,
  BlocTdb.bandes: Icons.egg_outlined,
  BlocTdb.tendance: Icons.bar_chart,
  BlocTdb.commercial: Icons.people_outline,
};

/// Ordre enregistré appliqué aux blocs connus ; les blocs absents (nouveaux) sont ajoutés à la fin.
List<BlocTdb> ordreBlocs(List<String> enregistre) {
  final out = <BlocTdb>[];
  for (final nom in enregistre) {
    for (final b in BlocTdb.values) {
      if (b.name == nom && !out.contains(b)) out.add(b);
    }
  }
  for (final b in BlocTdb.values) {
    if (!out.contains(b)) out.add(b);
  }
  return out;
}

/// Salutation selon l'heure.
String salutation(DateTime now) => now.hour < 18 ? 'Bonjour' : 'Bonsoir';
