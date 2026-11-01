import 'package:flutter/material.dart';
import '../../models/alerte.dart';
import '../../utils/crm_labels.dart';
import '../../utils/todo.dart';
import '../crm/crm_widgets.dart';
import '../recurrence_picker.dart';

/// Carte de tâche Todo façon Microsoft Planner : case ronde, étiquettes (catégorie, priorité,
/// bande, origine), échéance, récurrence, progression de la checklist et personne assignée.
class TodoCard extends StatelessWidget {
  final Alerte alerte;
  final VoidCallback? onToggleDone;
  final VoidCallback? onTap;
  final VoidCallback? onOpenSource;
  final bool compact;

  const TodoCard({
    super.key,
    required this.alerte,
    this.onToggleDone,
    this.onTap,
    this.onOpenSource,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final a = alerte;
    final scheme = Theme.of(context).colorScheme;
    final done = a.estFaite;
    final priorite = tachePriorite(a.priorite);
    final categorie = todoCategorie(a.type);
    final overdue = !done && daysFromToday(a.dateEcheance) < 0;
    final dueColor = overdue ? Colors.red : scheme.onSurfaceVariant;
    final total = a.checklist.length;
    final muted = TextStyle(fontSize: 12, color: scheme.onSurfaceVariant);
    final heure = a.touteJournee ? '' : ' · ${formatHeure(a.dateEcheance)}';

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
                  padding: const EdgeInsets.fromLTRB(4, 6, 8, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _RoundCheck(done: done, color: priorite.color, onTap: onToggleDone),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                a.titre,
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
                          if (a.automatique && onOpenSource != null)
                            IconButton(
                              tooltip: 'Ouvrir la source',
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.open_in_new, size: 18),
                              onPressed: onOpenSource,
                            ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 40),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            CrmPill(categorie, dense: true),
                            if (a.priorite == 'haute' || a.priorite == 'urgente') CrmPill(priorite, dense: true),
                            if (a.automatique) CrmPill(todoSource(a.source), dense: true),
                            if (a.progression == 'en_cours' && !done) CrmPill(todoProgressions[1], dense: true),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(overdue ? Icons.event_busy : Icons.event_outlined, size: 13, color: dueColor),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    '${relativeDay(a.dateEcheance)}$heure',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12, color: dueColor, fontWeight: overdue ? FontWeight.w700 : FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                            if (a.recurrence != 'aucune' && a.recurrence.isNotEmpty)
                              Tooltip(
                                message: recurrenceSummary(a.recurrence, a.recurrenceConfig),
                                child: Icon(Icons.repeat, size: 14, color: Colors.indigo.shade300),
                              ),
                            if (a.bandeNom.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.egg_outlined, size: 13, color: scheme.onSurfaceVariant),
                                  const SizedBox(width: 3),
                                  Flexible(child: Text(a.bandeNom, maxLines: 1, overflow: TextOverflow.ellipsis, style: muted)),
                                ],
                              ),
                            if (total > 0)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.checklist, size: 14, color: scheme.onSurfaceVariant),
                                  const SizedBox(width: 3),
                                  Text('${a.checklistFaits}/$total', style: muted.copyWith(fontWeight: FontWeight.w600)),
                                ],
                              ),
                          ],
                        ),
                      ),
                      if (!compact && a.message.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.only(left: 40),
                          child: Text(a.message.trim(), maxLines: 2, overflow: TextOverflow.ellipsis, style: muted),
                        ),
                      ],
                      if (total > 0) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 40, right: 4),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: a.checklistFaits / total,
                              minHeight: 4,
                              color: Colors.green,
                              backgroundColor: scheme.outlineVariant.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ],
                      if (a.assigneA.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 40),
                          child: Row(
                            children: [
                              ClientAvatar(name: a.assigneA, radius: 10),
                              const SizedBox(width: 6),
                              Flexible(child: Text(a.assigneA, maxLines: 1, overflow: TextOverflow.ellipsis, style: muted)),
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
      message: done ? 'Tâche faite' : 'Marquer comme faite',
      child: InkResponse(
        onTap: onTap,
        radius: 20,
        child: Padding(
          padding: const EdgeInsets.all(8),
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
