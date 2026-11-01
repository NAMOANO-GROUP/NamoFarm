import 'package:flutter/material.dart';

/// Poste de dépense : `valeur` est le « type » déjà enregistré en base (inchangé),
/// `libelle` est le nom affiché à l'utilisateur.
class FinancePoste {
  final String valeur;
  final String libelle;
  final IconData icon;
  final MaterialColor color;

  /// Poste généralement rattaché à une bande (aliment, poussins, soins...).
  final bool lieABande;

  const FinancePoste(this.valeur, this.libelle, this.icon, this.color, {this.lieABande = false});
}

/// Postes de dépense, du plus courant au plus rare pour un élevage.
const postesDepense = [
  FinancePoste('Alimentation', 'Aliment', Icons.grass, Colors.brown, lieABande: true),
  FinancePoste('Achat de sujet', 'Poussins / sujets', Icons.egg_outlined, Colors.orange, lieABande: true),
  FinancePoste('Prophylaxie', 'Vaccins & soins', Icons.vaccines_outlined, Colors.purple, lieABande: true),
  FinancePoste('Vétérinaire', 'Vétérinaire', Icons.medical_services_outlined, Colors.teal, lieABande: true),
  FinancePoste('Salaire Prime etc', 'Salaires & primes', Icons.badge_outlined, Colors.indigo),
  FinancePoste('Transport', 'Transport', Icons.local_shipping_outlined, Colors.blueGrey),
  FinancePoste('Materiel', 'Matériel', Icons.handyman_outlined, Colors.deepOrange),
  FinancePoste('Consomable', 'Consommables', Icons.shopping_basket_outlined, Colors.green),
  FinancePoste('Fourniture', 'Fournitures', Icons.inventory_2_outlined, Colors.amber),
  FinancePoste('Travaux', 'Travaux', Icons.construction_outlined, Colors.red),
  FinancePoste('Prestation', 'Prestations', Icons.handshake_outlined, Colors.cyan),
  FinancePoste('Communication', 'Communication', Icons.phone_in_talk_outlined, Colors.blue),
  FinancePoste('Formation', 'Formation', Icons.school_outlined, Colors.deepPurple),
  FinancePoste('Immobilier', 'Immobilier', Icons.home_work_outlined, Colors.lime),
  FinancePoste('Divers', 'Divers', Icons.more_horiz, Colors.grey),
];

/// Clé de regroupement des achats de stock (pas un « type » de dépense saisi).
const posteAchatStock = '__achat_stock';

const _posteAchatStock = FinancePoste(posteAchatStock, 'Achats de stock', Icons.inventory_outlined, Colors.brown);

/// Clé de regroupement des achats d'animaux du Cheptel.
const posteAchatCheptel = '__achat_cheptel';

const _posteAchatCheptel = FinancePoste(posteAchatCheptel, 'Achats d’animaux', Icons.pets, Colors.teal);

FinancePoste postePour(String valeur) {
  if (valeur == posteAchatStock) return _posteAchatStock;
  if (valeur == posteAchatCheptel) return _posteAchatCheptel;
  final v = valeur.trim().toLowerCase();
  for (final p in postesDepense) {
    if (p.valeur.toLowerCase() == v) return p;
  }
  final libelle = valeur.trim().isEmpty ? 'Divers' : valeur.trim();
  return FinancePoste(valeur, libelle[0].toUpperCase() + libelle.substring(1), Icons.label_outline, Colors.grey);
}

/// Activité (« catégorie » enregistrée en base, valeurs inchangées).
const activites = <String, String>{
  'AVICOLE': 'Avicole',
  'AGRICOLE': 'Agricole',
  'PISICOLE': 'Piscicole',
  'TRANSVERSE': 'Transverse',
  'DIVERS': 'Divers',
  'HORS BUSINESS': 'Hors activité',
};

const activiteParDefaut = 'AVICOLE';

String activiteLibelle(String valeur) => activites[valeur.trim().toUpperCase()] ?? (valeur.trim().isEmpty ? '—' : valeur.trim());

/// Libellés des origines de mouvement (« source » en base).
const sourcesMouvement = <String, String>{
  'depense': 'Dépense',
  'approvisionnement': 'Apport en caisse',
  'vente': 'Vente',
  'vente_commande_payee': 'Vente',
  'stock_entree': 'Achat de stock',
  'stock_sortie': 'Sortie de stock',
  'vente_cheptel': 'Vente d’animaux',
  'achat_cheptel': 'Achat d’animaux',
  'correction': 'Correction',
};

String sourceLibelle(String source) => sourcesMouvement[source] ?? (source.isEmpty ? 'Mouvement' : source.replaceAll('_', ' '));

/// Retire les préfixes techniques ([Bande: ...], [Categorie: ...]) d'un commentaire.
String nettoyerCommentaire(String c) => c
    .replaceFirst(RegExp(r'^\s*\[Bande:[^\]]*\]\s*'), '')
    .replaceFirst(RegExp(r'^\s*\[Categorie:[^\]]*\]\s*'), '')
    .trim();

double _num(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

/// Mouvement de trésorerie lisible (à partir de la réponse /finance/mouvements).
class Mouvement {
  final String id;
  final String nature;
  final String source;
  final String type;
  final String categorie;
  final double montant;
  final DateTime? date;
  final String quiPrenom;
  final String quiNom;
  final String commentaire;
  final String bandeId;
  final Map<String, dynamic> raw;

  const Mouvement({
    required this.id,
    required this.nature,
    required this.source,
    required this.type,
    required this.categorie,
    required this.montant,
    required this.date,
    this.quiPrenom = '',
    this.quiNom = '',
    this.commentaire = '',
    this.bandeId = '',
    this.raw = const {},
  });

  factory Mouvement.fromJson(Map<String, dynamic> m) => Mouvement(
        id: (m['_id'] ?? m['id'] ?? '').toString(),
        nature: (m['nature'] ?? '').toString(),
        source: (m['source'] ?? '').toString(),
        type: (m['type'] ?? '').toString(),
        categorie: (m['categorie'] ?? '').toString(),
        montant: _num(m['montant']),
        date: m['date'] == null ? null : DateTime.tryParse(m['date'].toString())?.toLocal(),
        quiPrenom: (m['quiPrenom'] ?? '').toString(),
        quiNom: (m['quiNom'] ?? '').toString(),
        commentaire: nettoyerCommentaire((m['commentaire'] ?? '').toString()),
        bandeId: (m['bandeId'] ?? '').toString(),
        raw: m,
      );

  bool get entree => nature == 'entree';
  bool get estDepense => source == 'depense';

  /// Montant signé (+ entrée, − sortie).
  double get signe => entree ? montant : -montant;

  String get qui => '$quiPrenom $quiNom'.trim();

  /// Clé de poste pour les sorties (type saisi, ou « Achats de stock »).
  String get posteCle {
    if (source == 'stock_entree') return posteAchatStock;
    if (source == 'achat_cheptel') return posteAchatCheptel;
    if (estDepense) return type.trim().isEmpty ? 'Divers' : type.trim();
    return type.trim().isNotEmpty ? type.trim() : source;
  }

  FinancePoste get poste => postePour(posteCle);

  /// Titre affiché : poste pour une dépense, origine sinon.
  String get libelle {
    if (estDepense || source == 'stock_entree' || source == 'achat_cheptel') return poste.libelle;
    return sourceLibelle(source);
  }

  IconData get icon {
    if (estDepense || source == 'stock_entree' || source == 'achat_cheptel') return poste.icon;
    if (source == 'vente_cheptel') return Icons.pets;
    if (source == 'approvisionnement') return Icons.savings_outlined;
    if (source.startsWith('vente')) return Icons.point_of_sale;
    return entree ? Icons.call_received : Icons.call_made;
  }

  MaterialColor get color {
    if (estDepense || source == 'stock_entree' || source == 'achat_cheptel') return poste.color;
    return entree ? Colors.green : Colors.red;
  }
}

List<Mouvement> parseMouvements(Iterable<dynamic> raw) =>
    raw.whereType<Map>().map((e) => Mouvement.fromJson(Map<String, dynamic>.from(e))).toList();

const moisFr = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
const moisCourts = ['Janv', 'Févr', 'Mars', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sept', 'Oct', 'Nov', 'Déc'];

/// Totaux d'un mois.
class MoisFinance {
  final int annee;
  final int mois;
  final double entrees;
  final double sorties;

  const MoisFinance(this.annee, this.mois, this.entrees, this.sorties);

  double get net => entrees - sorties;
  String get libelle => '${moisFr[mois - 1]} $annee';
  String get court => moisCourts[mois - 1];
}

bool _dansMois(DateTime? d, int annee, int mois) => d != null && d.year == annee && d.month == mois;

MoisFinance totauxMois(List<Mouvement> mvts, int annee, int mois) {
  var e = 0.0;
  var s = 0.0;
  for (final m in mvts) {
    if (!_dansMois(m.date, annee, mois)) continue;
    if (m.entree) {
      e += m.montant;
    } else {
      s += m.montant;
    }
  }
  return MoisFinance(annee, mois, e, s);
}

/// Les [n] derniers mois (du plus ancien au mois en cours).
List<MoisFinance> derniersMois(List<Mouvement> mvts, {int n = 6, DateTime? now}) {
  final today = now ?? DateTime.now();
  return [
    for (var i = n - 1; i >= 0; i--)
      () {
        final d = DateTime(today.year, today.month - i, 1);
        return totauxMois(mvts, d.year, d.month);
      }(),
  ];
}

/// Dépenses d'un mois par poste, triées de la plus grosse à la plus petite.
List<MapEntry<String, double>> depensesParPoste(List<Mouvement> mvts, int annee, int mois) {
  final out = <String, double>{};
  for (final m in mvts) {
    if (m.entree || !_dansMois(m.date, annee, mois)) continue;
    out[m.posteCle] = (out[m.posteCle] ?? 0) + m.montant;
  }
  return out.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
}

/// Variation en % de [actuel] par rapport à [precedent] (null si pas de référence).
double? variationPct(double actuel, double precedent) => precedent <= 0 ? null : (actuel - precedent) / precedent * 100;

/// Conseil affiché sur l'accueil Finance, en phrase simple.
class ConseilFinance {
  final String texte;
  final IconData icon;
  final MaterialColor color;

  const ConseilFinance(this.texte, this.icon, this.color);
}

/// Montant avec espaces entre les milliers, sans décimale inutile (« 12 500 »).
String montantSaisie(double v) {
  final arrondi = (v * 100).round() / 100;
  final entier = arrondi.truncate().abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < entier.length; i++) {
    if (i > 0 && (entier.length - i) % 3 == 0) buf.write(' ');
    buf.write(entier[i]);
  }
  final cents = ((arrondi.abs() - arrondi.abs().truncate()) * 100).round();
  final decimales = cents == 0 ? '' : ',${cents.toString().padLeft(2, '0').replaceFirst(RegExp(r'0$'), '')}';
  return '${arrondi < 0 ? '-' : ''}$buf$decimales';
}

/// Montant lisible en FCFA (« 12 500 FCFA »).
String fcfa(double v) => '${montantSaisie(v)} FCFA';

/// Conseils en langage simple à partir des mouvements, de la projection et des bandes.
List<ConseilFinance> conseilsFinance({
  required List<Mouvement> mouvements,
  DateTime? now,
  double? soldeDans3Mois,
  List<Map<String, dynamic>> bandes = const [],
}) {
  final today = now ?? DateTime.now();
  final ce = totauxMois(mouvements, today.year, today.month);
  final prevDate = DateTime(today.year, today.month - 1, 1);
  final out = <ConseilFinance>[];

  if (ce.entrees > 0 || ce.sorties > 0) {
    out.add(ce.net >= 0
        ? ConseilFinance('Ce mois-ci, vous avez encaissé ${fcfa(ce.net)} de plus que vous n’avez dépensé.', Icons.thumb_up_alt_outlined, Colors.green)
        : ConseilFinance('Ce mois-ci, vous avez dépensé ${fcfa(-ce.net)} de plus que vous n’avez encaissé.', Icons.warning_amber_rounded, Colors.orange));
  }

  // Plus forte hausse d'un poste significatif par rapport au mois précédent.
  final courant = depensesParPoste(mouvements, today.year, today.month);
  final precedent = {for (final e in depensesParPoste(mouvements, prevDate.year, prevDate.month)) e.key: e.value};
  ConseilFinance? hausse;
  var meilleure = 0.0;
  for (final e in courant) {
    final v = variationPct(e.value, precedent[e.key] ?? 0);
    if (v == null || v < 15 || e.value < ce.sorties * 0.05) continue;
    if (v > meilleure) {
      meilleure = v;
      hausse = ConseilFinance(
        'Vous avez dépensé ${v.round()} % de plus en ${postePour(e.key).libelle.toLowerCase()} qu’en ${moisFr[prevDate.month - 1]}.',
        Icons.trending_up,
        Colors.orange,
      );
    }
  }
  if (hausse != null) out.add(hausse);

  if (soldeDans3Mois != null) {
    out.add(soldeDans3Mois < 0
        ? ConseilFinance('Dans 3 mois, si rien ne change, votre solde serait négatif : ${fcfa(soldeDans3Mois)}.', Icons.trending_down, Colors.red)
        : ConseilFinance('Dans 3 mois, si rien ne change, votre solde serait de ${fcfa(soldeDans3Mois)}.', Icons.insights_outlined, Colors.blue));
  }

  final enPerte = bandes.where((b) => (b['statut'] ?? '') == 'fermee' && _num(b['margeNette']) < 0).toList();
  if (enPerte.isNotEmpty) {
    out.add(ConseilFinance(
      enPerte.length == 1
          ? 'La bande ${enPerte.first['bandeNom']} s’est terminée en perte (${fcfa(_num(enPerte.first['margeNette']))}).'
          : '${enPerte.length} bandes fermées se sont terminées en perte.',
      Icons.egg_outlined,
      Colors.red,
    ));
  }
  return out;
}

/// Dépenses récentes distinctes (même poste, montant et bande) à proposer en « Refaire ».
List<Mouvement> depensesRecentes(List<Mouvement> mvts, {int max = 3}) {
  final vus = <String>{};
  final out = <Mouvement>[];
  final tries = mvts.where((m) => m.estDepense).toList()
    ..sort((a, b) => (b.date ?? DateTime(2000)).compareTo(a.date ?? DateTime(2000)));
  for (final m in tries) {
    final cle = '${m.type}|${m.montant}|${m.bandeId}';
    if (vus.add(cle)) out.add(m);
    if (out.length >= max) break;
  }
  return out;
}

/// Totaux d'une liste de mouvements (journal filtré).
({double entrees, double sorties}) totaux(Iterable<Mouvement> mvts) {
  var e = 0.0;
  var s = 0.0;
  for (final m in mvts) {
    if (m.entree) {
      e += m.montant;
    } else {
      s += m.montant;
    }
  }
  return (entrees: e, sorties: s);
}

/// Périodes proposées dans le menu Filtres du journal.
enum PeriodeFinance { tout, ceMois, moisDernier, troisMois, annee, intervalle }

const periodeLibelles = {
  PeriodeFinance.tout: 'Tout',
  PeriodeFinance.ceMois: 'Ce mois-ci',
  PeriodeFinance.moisDernier: 'Le mois dernier',
  PeriodeFinance.troisMois: 'Les 3 derniers mois',
  PeriodeFinance.annee: 'Cette année',
  PeriodeFinance.intervalle: 'Choisir des dates…',
};

/// Bornes (jours inclus) d'une période ; null = sans limite.
({DateTime? from, DateTime? to}) bornesPeriode(PeriodeFinance p, {DateTime? now, DateTime? debut, DateTime? fin}) {
  final t = now ?? DateTime.now();
  switch (p) {
    case PeriodeFinance.tout:
      return (from: null, to: null);
    case PeriodeFinance.ceMois:
      return (from: DateTime(t.year, t.month, 1), to: null);
    case PeriodeFinance.moisDernier:
      return (from: DateTime(t.year, t.month - 1, 1), to: DateTime(t.year, t.month, 0));
    case PeriodeFinance.troisMois:
      return (from: DateTime(t.year, t.month - 2, 1), to: null);
    case PeriodeFinance.annee:
      return (from: DateTime(t.year, 1, 1), to: null);
    case PeriodeFinance.intervalle:
      return (from: debut, to: fin);
  }
}

/// Origines regroupées pour le menu Filtres (une case = plusieurs « source » en base).
const originesFiltre = <String, List<String>>{
  'Dépenses': ['depense'],
  'Apports en caisse': ['approvisionnement'],
  'Ventes': ['vente', 'vente_commande_payee'],
  'Achats de stock': ['stock_entree'],
  'Cheptel': ['vente_cheptel', 'achat_cheptel'],
  'Autres': ['stock_sortie', 'correction'],
};

String _sansAccents(String s) {
  const a = 'àâäéèêëîïôöùûüçÀÂÄÉÈÊËÎÏÔÖÙÛÜÇ';
  const b = 'aaaeeeeiioouuucAAAEEEEIIOOUUUC';
  final buf = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    final i = a.indexOf(c);
    buf.write(i >= 0 ? b[i] : c);
  }
  return buf.toString().toLowerCase();
}

/// Filtre local du journal : sens (entrées / sorties) et recherche libre.
List<Mouvement> filtrerJournal(
  List<Mouvement> mvts, {
  Set<String> natures = const {},
  String recherche = '',
  String Function(String bandeId)? nomBande,
}) {
  final q = _sansAccents(recherche.trim());
  return mvts.where((m) {
    if (natures.isNotEmpty && !natures.contains(m.entree ? 'entree' : 'sortie')) return false;
    if (q.isEmpty) return true;
    final texte = _sansAccents([
      m.libelle,
      m.type,
      m.commentaire,
      m.qui,
      sourceLibelle(m.source),
      activiteLibelle(m.categorie),
      nomBande?.call(m.bandeId) ?? '',
      m.montant.round().toString(),
    ].join(' '));
    return q.split(RegExp(r'\s+')).every(texte.contains);
  }).toList();
}

/// Regroupe les mouvements par jour (du plus récent au plus ancien).
List<({DateTime jour, List<Mouvement> mouvements})> grouperParJour(List<Mouvement> mvts) {
  final groupes = <DateTime, List<Mouvement>>{};
  final sansDate = <Mouvement>[];
  for (final m in mvts) {
    final d = m.date;
    if (d == null) {
      sansDate.add(m);
      continue;
    }
    groupes.putIfAbsent(DateTime(d.year, d.month, d.day), () => []).add(m);
  }
  final jours = groupes.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final j in jours)
      (jour: j, mouvements: groupes[j]!..sort((a, b) => b.date!.compareTo(a.date!))),
    if (sansDate.isNotEmpty) (jour: DateTime(1970), mouvements: sansDate),
  ];
}

