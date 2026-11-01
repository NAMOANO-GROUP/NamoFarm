import 'package:flutter/material.dart';
import '../../utils/crm_labels.dart';
import 'crm_widgets.dart';

/// Barre d'actions rapides d'une fiche contact (client ou fournisseur).
class ContactQuickActions extends StatelessWidget {
  final VoidCallback onCall;
  final VoidCallback onWhatsapp;
  final VoidCallback? onEmail;
  final VoidCallback onNote;
  final VoidCallback onTask;

  const ContactQuickActions({
    super.key,
    required this.onCall,
    required this.onWhatsapp,
    required this.onEmail,
    required this.onNote,
    required this.onTask,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          for (final a in [
            _QuickAction(icon: Icons.call, label: 'Appeler', color: Colors.green, onTap: onCall),
            _QuickAction(icon: Icons.chat, label: 'WhatsApp', color: Colors.teal, onTap: onWhatsapp),
            _QuickAction(icon: Icons.mail_outline, label: 'Email', color: Colors.blue, onTap: onEmail),
            _QuickAction(icon: Icons.sticky_note_2_outlined, label: 'Note', color: Colors.amber, onTap: onNote),
            _QuickAction(icon: Icons.add_task, label: 'Tâche', color: Colors.indigo, onTap: onTask),
          ])
            Expanded(child: a),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final MaterialColor color;
  final VoidCallback? onTap;

  const _QuickAction({required this.icon, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: enabled ? (isDark ? color.shade800 : color.shade50) : Colors.grey.withValues(alpha: 0.15),
                child: Icon(icon, color: enabled ? (isDark ? color.shade100 : color.shade700) : Colors.grey),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label, style: TextStyle(fontSize: 11, color: enabled ? null : Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Élément du fil d'activité d'une fiche contact.
class TimelineEntry {
  final DateTime date;
  final String kind;
  final IconData icon;
  final MaterialColor color;
  final String title;
  final String? body;
  final String? meta;

  const TimelineEntry({
    required this.date,
    required this.kind,
    required this.icon,
    required this.color,
    required this.title,
    this.body,
    this.meta,
  });
}

/// Fil d'activité groupé par jour ("Aujourd'hui", "Hier", "12 octobre 2026"), du plus récent au plus ancien.
List<Widget> buildActivityTimeline(BuildContext context, List<TimelineEntry> entries) {
  final sorted = [...entries]..sort((a, b) => b.date.compareTo(a.date));
  final widgets = <Widget>[];
  String? currentDay;
  for (var i = 0; i < sorted.length; i++) {
    final e = sorted[i];
    final day = timelineDayLabel(e.date);
    if (day != currentDay) {
      currentDay = day;
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 6, left: 4),
        child: Text(day, style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary)),
      ));
    }
    final last = i == sorted.length - 1 || timelineDayLabel(sorted[i + 1].date) != day;
    widgets.add(_TimelineTile(entry: e, isLast: last));
  }
  return widgets;
}

class _TimelineTile extends StatelessWidget {
  final TimelineEntry entry;
  final bool isLast;

  const _TimelineTile({required this.entry, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: isDark ? entry.color.shade800 : entry.color.shade50,
                  child: Icon(entry.icon, size: 16, color: isDark ? entry.color.shade100 : entry.color.shade700),
                ),
                if (!isLast) Expanded(child: Container(width: 2, color: scheme.outlineVariant.withValues(alpha: 0.6))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(entry.title, style: const TextStyle(fontWeight: FontWeight.w600))),
                      Text(formatHeure(entry.date), style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                  if ((entry.body ?? '').isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(entry.body!, style: TextStyle(color: scheme.onSurfaceVariant)),
                  ],
                  if ((entry.meta ?? '').isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text('par ${entry.meta}', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// État vide du fil d'activité.
class EmptyTimeline extends StatelessWidget {
  final String message;
  const EmptyTimeline({super.key, this.message = 'Consignez un appel, une visite ou une note pour démarrer l’historique.'});

  @override
  Widget build(BuildContext context) {
    return CrmCard(
      child: Column(
        children: [
          const Icon(Icons.forum_outlined, size: 40, color: Colors.grey),
          const SizedBox(height: 8),
          const Text('Aucune activité pour le moment', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

/// Ligne "icône · libellé · valeur" des blocs d'informations.
class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const InfoRow(this.icon, this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: muted),
          const SizedBox(width: 10),
          SizedBox(width: 100, child: Text(label, style: TextStyle(color: muted, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

/// Statistique centrée (valeur en gras, libellé dessous) pour l'en-tête d'une fiche.
class HeaderStat extends StatelessWidget {
  final String label;
  final String value;
  const HeaderStat({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
