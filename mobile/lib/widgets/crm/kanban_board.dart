import 'package:flutter/material.dart';

/// Colonne d'un tableau Kanban.
class KanbanColumn<T> {
  final String id;
  final String title;
  final Color color;
  final IconData? icon;
  final List<T> items;
  final String? subtitle;
  final bool acceptsDrops;

  const KanbanColumn({
    required this.id,
    required this.title,
    required this.color,
    required this.items,
    this.icon,
    this.subtitle,
    this.acceptsDrops = true,
  });
}

/// Tableau à colonnes avec glisser-déposer (appui long pour saisir une carte),
/// à la manière de HubSpot (pipeline) et Microsoft Planner (compartiments).
class KanbanBoard<T extends Object> extends StatelessWidget {
  final List<KanbanColumn<T>> columns;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Future<void> Function(T item, String toColumnId) onMove;
  final String Function(T item) itemKey;
  final double columnWidth;
  final String emptyLabel;

  const KanbanBoard({
    super.key,
    required this.columns,
    required this.itemBuilder,
    required this.onMove,
    required this.itemKey,
    this.columnWidth = 290,
    this.emptyLabel = 'Déposez une carte ici',
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Sur grand écran, les colonnes s'étirent pour remplir la largeur disponible.
        final available = constraints.maxWidth - 16;
        final fitted = available / columns.length;
        final width = fitted > columnWidth ? fitted : columnWidth;
        return Scrollbar(
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            children: [
              for (final column in columns)
                SizedBox(
                  key: ValueKey('kanban-column-${column.id}'),
                  width: width,
                  child: _KanbanColumnView<T>(
                    column: column,
                    itemBuilder: itemBuilder,
                    onMove: onMove,
                    itemKey: itemKey,
                    emptyLabel: emptyLabel,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _KanbanColumnView<T extends Object> extends StatelessWidget {
  final KanbanColumn<T> column;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Future<void> Function(T item, String toColumnId) onMove;
  final String Function(T item) itemKey;
  final String emptyLabel;

  const _KanbanColumnView({
    required this.column,
    required this.itemBuilder,
    required this.onMove,
    required this.itemKey,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DragTarget<T>(
      onWillAcceptWithDetails: (details) =>
          column.acceptsDrops && !column.items.any((i) => itemKey(i) == itemKey(details.data)),
      onAcceptWithDetails: (details) => onMove(details.data, column.id),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: hovering ? column.color.withValues(alpha: 0.12) : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: hovering ? column.color : Colors.transparent, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: column.color, width: 3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (column.icon != null) ...[
                          Icon(column.icon, size: 16, color: column.color),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(column.title,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: column.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('${column.items.length}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: column.color)),
                        ),
                      ],
                    ),
                    if (column.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(column.subtitle!, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: column.items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            column.acceptsDrops ? emptyLabel : 'Rien ici',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        itemCount: column.items.length,
                        itemBuilder: (context, i) {
                          final item = column.items[i];
                          final card = itemBuilder(context, item);
                          return LongPressDraggable<T>(
                            key: ValueKey('kanban-item-${itemKey(item)}'),
                            data: item,
                            feedback: Material(
                              elevation: 8,
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(width: 260, child: card),
                            ),
                            childWhenDragging: Opacity(opacity: 0.35, child: card),
                            child: card,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
