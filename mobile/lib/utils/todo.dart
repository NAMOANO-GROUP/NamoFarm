import 'package:flutter/material.dart';
import '../models/alerte.dart';
import 'crm_labels.dart';

/// Catégories (types) de tâches de la Todo : elles servent aussi de colonnes « par catégorie ».
const todoCategories = [
  CrmOption('vaccination', 'Vaccination', Colors.teal, Icons.vaccines_outlined),
  CrmOption('medicament', 'Traitement', Colors.purple, Icons.medication_outlined),
  CrmOption('alimentation', 'Alimentation', Colors.brown, Icons.restaurant_outlined),
  CrmOption('pesee', 'Pesée', Colors.indigo, Icons.monitor_weight_outlined),
  CrmOption('stock_bas', 'Stock', Colors.orange, Icons.inventory_2_outlined),
  CrmOption('vente', 'Ventes', Colors.green, Icons.sell_outlined),
  CrmOption('controle_sanitaire', 'Contrôle sanitaire', Colors.cyan, Icons.health_and_safety_outlined),
  CrmOption('intervention_diverse', 'Intervention', Colors.blueGrey, Icons.build_circle_outlined),
  CrmOption('autre', 'Autre', Colors.grey, Icons.label_outline),
];

CrmOption todoCategorie(String type) {
  for (final c in todoCategories) {
    if (c.value == type) return c;
  }
  return CrmOption(type, type.isEmpty ? 'Autre' : type[0].toUpperCase() + type.substring(1).replaceAll('_', ' '),
      Colors.grey, Icons.label_outline);
}

/// Origine d'une tâche automatique (badge sur la carte).
const _todoSources = {
  'stock': CrmOption('stock', 'Stock', Colors.orange, Icons.inventory_2_outlined),
  'sanitaire': CrmOption('sanitaire', 'Santé', Colors.teal, Icons.health_and_safety_outlined),
  'planification': CrmOption('planification', 'Planning bande', Colors.indigo, Icons.event_note_outlined),
  'commercial': CrmOption('commercial', 'Commandes', Colors.green, Icons.shopping_cart_outlined),
  'crm_tache': CrmOption('crm_tache', 'CRM', Colors.deepPurple, Icons.people_outline),
};

CrmOption todoSource(String source) =>
    _todoSources[source] ?? const CrmOption('auto', 'Automatique', Colors.blueGrey, Icons.bolt_outlined);

const todoProgressions = [
  CrmOption('a_faire', 'À faire', Colors.blueGrey, Icons.radio_button_unchecked),
  CrmOption('en_cours', 'En cours', Colors.blue, Icons.timelapse),
  CrmOption('faite', 'Terminée', Colors.green, Icons.check_circle),
];

bool _isMine(Alerte a, String me) => me.trim().isNotEmpty && a.assigneA.trim().toLowerCase() == me.trim().toLowerCase();

/// Filtre multi-choix : tâches dont l'échéance est dans l'une des colonnes cochées
/// ([echeances] vide = toutes), éventuellement limité à « Mes tâches ». Trié par échéance.
List<Alerte> filtrerTodo(
  List<Alerte> taches, {
  Set<DueBucket> echeances = const {},
  bool mesTaches = false,
  String me = '',
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  return taches.where((a) {
    if (mesTaches && !_isMine(a, me)) return false;
    return echeances.isEmpty || echeances.contains(dueBucketFor(a.dateEcheance, now: today));
  }).toList()
    ..sort((a, b) => a.dateEcheance.compareTo(b.dateEcheance));
}

/// Statistiques de la vue « Graphiques » (façon Planner).
class TodoStats {
  final int aFaire;
  final int enCours;
  final int enRetard;
  final int termineesSemaine;
  final Map<String, int> parCategorie;
  final Map<String, int> parPriorite;
  final Map<String, int> parPersonne;

  const TodoStats({
    required this.aFaire,
    required this.enCours,
    required this.enRetard,
    required this.termineesSemaine,
    required this.parCategorie,
    required this.parPriorite,
    required this.parPersonne,
  });

  int get ouvertes => aFaire + enCours;

  /// Part des tâches de la semaine déjà terminées (0-100).
  double get avancementSemaine {
    final total = termineesSemaine + ouvertes;
    return total == 0 ? 0 : termineesSemaine * 100 / total;
  }
}

TodoStats computeTodoStats(List<Alerte> ouvertes, List<Alerte> terminees, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final debutSemaine = DateTime(today.year, today.month, today.day).subtract(Duration(days: today.weekday - 1));
  Map<String, int> count(Iterable<String> keys) {
    final m = <String, int>{};
    for (final k in keys) {
      m[k] = (m[k] ?? 0) + 1;
    }
    return m;
  }

  return TodoStats(
    aFaire: ouvertes.where((a) => a.progression != 'en_cours').length,
    enCours: ouvertes.where((a) => a.progression == 'en_cours').length,
    enRetard: ouvertes.where((a) => dueBucketFor(a.dateEcheance, now: today) == DueBucket.enRetard).length,
    termineesSemaine: terminees.where((a) => !a.dateEcheance.isBefore(debutSemaine)).length,
    parCategorie: count(ouvertes.map((a) => a.type)),
    parPriorite: count(ouvertes.map((a) => a.priorite)),
    parPersonne: count(ouvertes.map((a) => a.assigneA.trim().isEmpty ? 'Non assignée' : a.assigneA.trim())),
  );
}

/// Une tâche d'un modèle, planifiée [jour] jours après la date de départ (négatif = avant).
class TodoModeleTache {
  final int jour;
  final String titre;
  final String type;
  final String priorite;
  final String message;
  final String recurrence;
  final List<String> etapes;

  const TodoModeleTache(
    this.jour,
    this.titre, {
    this.type = 'autre',
    this.priorite = 'moyenne',
    this.message = '',
    this.recurrence = 'aucune',
    this.etapes = const [],
  });
}

/// Modèle de plan façon Planner : une série de tâches générées en un clic.
class TodoModele {
  final String id;
  final String titre;
  final String description;
  final IconData icon;
  final String libelleDate;
  final List<TodoModeleTache> taches;

  const TodoModele({
    required this.id,
    required this.titre,
    required this.description,
    required this.icon,
    required this.libelleDate,
    required this.taches,
  });
}

const todoModeles = [
  TodoModele(
    id: 'bande_chair',
    titre: 'Démarrer une bande de poulets de chair',
    description: 'Préparation, réception, vaccins, pesées et transitions d’aliment jusqu’à la vente. '
        'Calendrier indicatif : adaptez-le au protocole de votre vétérinaire.',
    icon: Icons.egg_outlined,
    libelleDate: 'Date d’arrivée des poussins (J0)',
    taches: [
      TodoModeleTache(-3, 'Préparer le bâtiment', type: 'intervention_diverse', priorite: 'haute', etapes: [
        'Nettoyer et désinfecter',
        'Installer la litière',
        'Vérifier abreuvoirs et mangeoires',
        'Préchauffer le bâtiment',
      ]),
      TodoModeleTache(0, 'Réception des poussins', type: 'autre', priorite: 'urgente', etapes: [
        'Compter les poussins',
        'Peser un échantillon',
        'Contrôler la température',
        'Eau sucrée + vitamines',
      ]),
      TodoModeleTache(7, 'Vaccin Newcastle (1re dose)', type: 'vaccination', priorite: 'haute'),
      TodoModeleTache(7, 'Pesée hebdomadaire', type: 'pesee', recurrence: 'hebdomadaire'),
      TodoModeleTache(14, 'Vaccin Gumboro', type: 'vaccination', priorite: 'haute'),
      TodoModeleTache(21, 'Rappel Newcastle', type: 'vaccination', priorite: 'haute'),
      TodoModeleTache(21, 'Passer à l’aliment croissance', type: 'alimentation'),
      TodoModeleTache(35, 'Passer à l’aliment finition', type: 'alimentation'),
      TodoModeleTache(40, 'Préparer la vente', type: 'vente', priorite: 'haute', etapes: [
        'Prévenir les clients',
        'Fixer la date d’enlèvement',
        'Mettre à jeun la veille',
      ]),
    ],
  ),
  TodoModele(
    id: 'vide_sanitaire',
    titre: 'Vide sanitaire du bâtiment',
    description: 'Nettoyage complet entre deux bandes.',
    icon: Icons.cleaning_services_outlined,
    libelleDate: 'Date de sortie de la bande',
    taches: [
      TodoModeleTache(0, 'Retirer la litière et le matériel', type: 'intervention_diverse', priorite: 'haute'),
      TodoModeleTache(1, 'Laver et désinfecter le bâtiment', type: 'controle_sanitaire', priorite: 'haute', etapes: [
        'Dépoussiérer',
        'Laver à haute pression',
        'Désinfecter',
        'Nettoyer les abords',
      ]),
      TodoModeleTache(3, 'Désinsectisation et dératisation', type: 'controle_sanitaire'),
      TodoModeleTache(10, 'Contrôle avant remise en place', type: 'controle_sanitaire', priorite: 'haute'),
    ],
  ),
  TodoModele(
    id: 'routine_pondeuses',
    titre: 'Routine pondeuses',
    description: 'Tâches récurrentes de l’élevage de pondeuses.',
    icon: Icons.egg_alt_outlined,
    libelleDate: 'Date de début',
    taches: [
      TodoModeleTache(0, 'Ramassage des œufs', type: 'autre', recurrence: 'quotidien'),
      TodoModeleTache(0, 'Nettoyage des abreuvoirs', type: 'controle_sanitaire', recurrence: 'hebdomadaire'),
      TodoModeleTache(0, 'Pesée d’un échantillon', type: 'pesee', recurrence: 'bihebdomadaire'),
      TodoModeleTache(0, 'Inventaire de l’aliment', type: 'alimentation', recurrence: 'hebdomadaire'),
    ],
  ),
];

/// Tâches (payloads API) générées par un modèle à partir d'une date de départ.
List<Map<String, dynamic>> genererTachesModele(
  TodoModele modele,
  DateTime depart, {
  String? bandeId,
  String assigneA = '',
}) {
  final base = DateTime(depart.year, depart.month, depart.day, 8);
  return [
    for (final t in modele.taches)
      {
        'titre': t.titre,
        'message': t.message,
        'type': t.type,
        'priorite': t.priorite,
        'recurrence': t.recurrence,
        'recurrenceConfig': const <String, dynamic>{},
        'dateEcheance': base.add(Duration(days: t.jour)).toIso8601String(),
        'dateFin': base.add(Duration(days: t.jour, hours: 1)).toIso8601String(),
        'touteJournee': false,
        'bandeId': bandeId,
        'assigneA': assigneA,
        'checklist': [for (final e in t.etapes) ChecklistItem(titre: e).toJson()],
        'source': 'todo',
      },
  ];
}
