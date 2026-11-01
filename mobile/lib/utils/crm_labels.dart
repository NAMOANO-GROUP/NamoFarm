import 'package:flutter/material.dart';

/// Option affichable d'une valeur technique du CRM (libellé, couleur, icône).
class CrmOption {
  final String value;
  final String label;
  final MaterialColor color;
  final IconData icon;

  const CrmOption(this.value, this.label, this.color, this.icon);
}

String _humanize(String value) {
  final text = value.replaceAll('_', ' ').trim();
  if (text.isEmpty) return '—';
  return text[0].toUpperCase() + text.substring(1);
}

CrmOption _find(List<CrmOption> options, String value, {MaterialColor color = Colors.blueGrey, IconData icon = Icons.label_outline}) {
  for (final o in options) {
    if (o.value == value) return o;
  }
  return CrmOption(value, _humanize(value), color, icon);
}

const clientStatuts = [
  CrmOption('prospect', 'Prospect', Colors.amber, Icons.person_search_outlined),
  CrmOption('actif', 'Actif', Colors.green, Icons.verified_outlined),
  CrmOption('inactif', 'Inactif', Colors.blueGrey, Icons.pause_circle_outline),
];

const clientTypes = [
  CrmOption('particulier', 'Particulier', Colors.indigo, Icons.person_outline),
  CrmOption('pro', 'Professionnel', Colors.deepPurple, Icons.storefront_outlined),
];

const pipelineStages = [
  CrmOption('lead', 'Prospect', Colors.blueGrey, Icons.lightbulb_outline),
  CrmOption('qualifie', 'Qualifié', Colors.blue, Icons.how_to_reg_outlined),
  CrmOption('proposition', 'Proposition', Colors.indigo, Icons.request_quote_outlined),
  CrmOption('negociation', 'Négociation', Colors.orange, Icons.handshake_outlined),
  CrmOption('gagne', 'Gagné', Colors.green, Icons.emoji_events_outlined),
  CrmOption('perdu', 'Perdu', Colors.red, Icons.cancel_outlined),
];

/// Probabilité de conclusion par défaut de chaque étape (identique au backend).
const defaultStageProbability = {
  'lead': 10,
  'qualifie': 25,
  'proposition': 50,
  'negociation': 75,
  'gagne': 100,
  'perdu': 0,
};

const tacheTypes = [
  CrmOption('relance', 'Relance', Colors.indigo, Icons.replay_circle_filled_outlined),
  CrmOption('appel', 'Appel', Colors.green, Icons.call_outlined),
  CrmOption('rendez_vous', 'Rendez-vous', Colors.purple, Icons.event_available_outlined),
  CrmOption('suivi', 'Suivi', Colors.teal, Icons.track_changes_outlined),
  CrmOption('autre', 'Autre', Colors.blueGrey, Icons.more_horiz),
];

const tachePriorites = [
  CrmOption('urgente', 'Urgente', Colors.red, Icons.priority_high),
  CrmOption('haute', 'Haute', Colors.deepOrange, Icons.keyboard_double_arrow_up),
  CrmOption('moyenne', 'Moyenne', Colors.blue, Icons.drag_handle),
  CrmOption('basse', 'Basse', Colors.grey, Icons.keyboard_arrow_down),
];

const tacheStatuts = [
  CrmOption('a_faire', 'À faire', Colors.blueGrey, Icons.radio_button_unchecked),
  CrmOption('en_cours', 'En cours', Colors.blue, Icons.timelapse),
  CrmOption('terminee', 'Terminée', Colors.green, Icons.check_circle),
  CrmOption('annulee', 'Annulée', Colors.grey, Icons.block),
];

const interactionTypes = [
  CrmOption('commentaire', 'Note', Colors.amber, Icons.sticky_note_2_outlined),
  CrmOption('appel', 'Appel', Colors.green, Icons.call_outlined),
  CrmOption('whatsapp', 'WhatsApp', Colors.teal, Icons.chat_outlined),
  CrmOption('visite', 'Visite', Colors.purple, Icons.directions_walk),
  CrmOption('email', 'Email', Colors.blue, Icons.mail_outline),
  CrmOption('reunion', 'Réunion', Colors.indigo, Icons.groups_outlined),
  CrmOption('pipeline_update', 'Pipeline', Colors.deepOrange, Icons.account_tree_outlined),
  CrmOption('autre', 'Autre', Colors.blueGrey, Icons.more_horiz),
];

const leadSources = ['Bouche-à-oreille', 'WhatsApp', 'Facebook', 'Marché', 'Recommandation', 'Appel entrant', 'Visite à la ferme'];

CrmOption clientStatut(String v) => _find(clientStatuts, v);
CrmOption clientType(String v) => _find(clientTypes, v);
CrmOption pipelineStage(String v) => _find(pipelineStages, v);
CrmOption tacheType(String v) => _find(tacheTypes, v);
CrmOption tachePriorite(String v) => _find(tachePriorites, v);
CrmOption tacheStatut(String v) => _find(tacheStatuts, v);
CrmOption interactionType(String v) => _find(interactionTypes, v);

bool isTacheOuverte(String statut) => statut == 'a_faire' || statut == 'en_cours';

/// Couleur associée à un score 0-100.
MaterialColor scoreColor(num score) => score >= 70 ? Colors.green : (score >= 40 ? Colors.orange : Colors.red);

/// Initiales (2 lettres max) d'un nom complet, "?" si vide.
String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}

const _avatarPalette = [
  Colors.indigo, Colors.teal, Colors.deepPurple, Colors.orange, Colors.pink,
  Colors.blue, Colors.green, Colors.brown, Colors.cyan, Colors.deepOrange,
];

/// Couleur d'avatar stable pour une même personne.
MaterialColor avatarColor(String seed) {
  var hash = 0;
  for (final unit in seed.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return _avatarPalette[hash % _avatarPalette.length];
}

const _moisFr = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

String _two(int v) => v.toString().padLeft(2, '0');

String formatDateFr(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

String formatDateLongFr(DateTime d) => '${d.day} ${_moisFr[d.month - 1]} ${d.year}';

String formatHeure(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

/// Écart en jours calendaires (positif = futur).
int daysFromToday(DateTime date, {DateTime? now}) {
  return _day(date).difference(_day(now ?? DateTime.now())).inDays;
}

/// "Aujourd'hui", "Demain", "Hier", "Dans 3 j", "Il y a 5 j" puis date courte.
String relativeDay(DateTime date, {DateTime? now}) {
  final diff = daysFromToday(date, now: now);
  if (diff == 0) return "Aujourd'hui";
  if (diff == 1) return 'Demain';
  if (diff == -1) return 'Hier';
  if (diff > 1 && diff <= 30) return 'Dans $diff j';
  if (diff < -1 && diff >= -30) return 'Il y a ${-diff} j';
  return formatDateFr(date);
}

/// En-tête de groupe pour un fil d'activité : "Aujourd'hui", "Hier" ou "12 octobre 2026".
String timelineDayLabel(DateTime date, {DateTime? now}) {
  final diff = daysFromToday(date, now: now);
  if (diff == 0) return "Aujourd'hui";
  if (diff == -1) return 'Hier';
  return formatDateLongFr(date);
}

/// Colonnes d'échéance façon Planner.
enum DueBucket { enRetard, aujourdhui, cetteSemaine, plusTard }

const dueBucketLabels = {
  DueBucket.enRetard: 'En retard',
  DueBucket.aujourdhui: "Aujourd'hui",
  DueBucket.cetteSemaine: 'Cette semaine',
  DueBucket.plusTard: 'Plus tard',
};

const dueBucketColors = {
  DueBucket.enRetard: Colors.red,
  DueBucket.aujourdhui: Colors.orange,
  DueBucket.cetteSemaine: Colors.blue,
  DueBucket.plusTard: Colors.blueGrey,
};

/// Fin de la semaine ISO (dimanche) contenant [now].
DateTime endOfWeek(DateTime now) => _day(now).add(Duration(days: DateTime.sunday - now.weekday));

DueBucket dueBucketFor(DateTime due, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final diff = daysFromToday(due, now: today);
  if (diff < 0) return DueBucket.enRetard;
  if (diff == 0) return DueBucket.aujourdhui;
  if (!_day(due).isAfter(endOfWeek(today))) return DueBucket.cetteSemaine;
  return DueBucket.plusTard;
}

/// Nouvelle échéance quand une tâche est déposée dans une colonne (null = refusé).
DateTime? dueDateForBucket(DueBucket bucket, {DateTime? now}) {
  final today = _day(now ?? DateTime.now());
  switch (bucket) {
    case DueBucket.enRetard:
      return null;
    case DueBucket.aujourdhui:
      return today;
    case DueBucket.cetteSemaine:
      final end = endOfWeek(today);
      final tomorrow = today.add(const Duration(days: 1));
      return end.isAfter(today) ? (tomorrow.isAfter(end) ? end : tomorrow) : today;
    case DueBucket.plusTard:
      return endOfWeek(today).add(const Duration(days: 1));
  }
}
