import 'package:flutter/material.dart';
import '../../models/tache_crm.dart';
import '../../utils/crm_labels.dart';
import 'crm_widgets.dart';

/// Carte de tâche façon Microsoft Planner : case ronde, étiquettes colorées,
/// échéance, client, progression de la checklist et personne assignée.
class TacheCard extends StatelessWidget {
  final TacheCRM tache;
  final VoidCallback? onToggleDone;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool showClient;

  const TacheCard({
    super.key,
    required this.tache,
    this.onToggleDone,
    this.onTap,
    this.onDelete,
    this.showClient = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = !isTacheOuverte(tache.statut);
    final priorite = tachePriorite(tache.priorite);
    final type = tacheType(tache.type);
    final overdue = !done && daysFromToday(tache.dateEcheance) < 0;
    final dueColor = overdue ? Colors.red : scheme.onSurfaceVariant;
    final total = tache.checklist.length;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: priorite.color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 8, 4, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _RoundCheck(done: done, color: priorite.color, onTap: onToggleDone),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 9),
                              child: Text(
                                tache.titre,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  decoration: done ? TextDecoration.lineThrough : null,
                                  color: done ? scheme.onSurfaceVariant : null,
                                ),
                              ),
                            ),
                          ),
                          if (onDelete != null)
                            PopupMenuButton<String>(
                              tooltip: 'Plus d’actions',
                              icon: const Icon(Icons.more_vert, size: 18),
                              onSelected: (v) {
                                if (v == 'edit') onTap?.call();
                                if (v == 'delete') onDelete?.call();
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'edit', child: Text('Modifier')),
                                PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                              ],
                            ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 42, right: 8),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            CrmPill(priorite, dense: true),
                            CrmPill(type, dense: true),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(overdue ? Icons.event_busy : Icons.event_outlined, size: 13, color: dueColor),
                                const SizedBox(width: 3),
                                Text(
                                  relativeDay(tache.dateEcheance),
                                  style: TextStyle(fontSize: 12, color: dueColor, fontWeight: overdue ? FontWeight.w700 : FontWeight.w500),
                                ),
                              ],
                            ),
                            if (total > 0)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.checklist, size: 14, color: scheme.onSurfaceVariant),
                                  const SizedBox(width: 3),
                                  Text('${tache.checklistFaits}/$total',
                                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                                ],
                              ),
                          ],
                        ),
                      ),
                      if (total > 0) ...[
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.only(left: 42, right: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: tache.checklistFaits / total,
                              minHeight: 4,
                              color: Colors.green,
                              backgroundColor: scheme.outlineVariant.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ],
                      if ((showClient && tache.clientNom.isNotEmpty) || tache.assigneA.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 42, right: 8),
                          child: Row(
                            children: [
                              if (showClient && tache.clientNom.isNotEmpty) ...[
                                Icon(Icons.person_outline, size: 14, color: scheme.onSurfaceVariant),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(tache.clientNom,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                                ),
                              ] else
                                const Spacer(),
                              if (tache.assigneA.isNotEmpty)
                                Tooltip(
                                  message: 'Assignée à ${tache.assigneA}',
                                  child: ClientAvatar(name: tache.assigneA, radius: 11),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundCheck extends StatelessWidget {
  final bool done;
  final Color color;
  final VoidCallback? onTap;

  const _RoundCheck({required this.done, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: done ? 'Rouvrir la tâche' : 'Marquer comme terminée',
      child: InkResponse(
        onTap: onTap,
        radius: 20,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? Colors.green : Colors.transparent,
              border: Border.all(color: done ? Colors.green : color, width: 2),
            ),
            child: done ? const Icon(Icons.check, size: 15, color: Colors.white) : null,
          ),
        ),
      ),
    );
  }
}
