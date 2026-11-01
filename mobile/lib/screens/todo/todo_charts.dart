import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../models/alerte.dart';
import '../../utils/crm_labels.dart';
import '../../utils/todo.dart';
import '../../widgets/crm/crm_widgets.dart';

/// Vue « Graphiques » façon Planner : avancement, catégories, priorités et charge par personne.
class TodoChartsView extends StatelessWidget {
  final List<Alerte> ouvertes;
  final List<Alerte> terminees;

  const TodoChartsView({super.key, required this.ouvertes, required this.terminees});

  @override
  Widget build(BuildContext context) {
    final s = computeTodoStats(ouvertes, terminees);
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 900 ? 4 : 2;
        final cards = [
          _AvancementCard(stats: s),
          _BarsCard(
            title: 'Par catégorie',
            icon: Icons.category_outlined,
            values: {for (final e in s.parCategorie.entries) todoCategorie(e.key).label: e.value},
            colorOf: (label) => todoCategories.firstWhere((c) => c.label == label, orElse: () => todoCategorie('autre')).color,
          ),
          _BarsCard(
            title: 'Par priorité',
            icon: Icons.flag_outlined,
            values: {
              for (final p in tachePriorites)
                if ((s.parPriorite[p.value] ?? 0) > 0) p.label: s.parPriorite[p.value]!,
            },
            colorOf: (label) => tachePriorites.firstWhere((p) => p.label == label).color,
          ),
          _BarsCard(
            title: 'Par personne',
            icon: Icons.people_outline,
            values: s.parPersonne,
            colorOf: (label) => label == 'Non assignée' ? Colors.grey : avatarColor(label),
          ),
        ];
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                mainAxisExtent: 150,
              ),
              children: [
                KpiCard(label: 'Ouvertes', value: '${s.ouvertes}', icon: Icons.inbox_outlined, color: Colors.blue),
                KpiCard(
                  label: 'En retard',
                  value: '${s.enRetard}',
                  icon: Icons.warning_amber_rounded,
                  color: s.enRetard > 0 ? Colors.red : Colors.green,
                ),
                KpiCard(label: 'En cours', value: '${s.enCours}', icon: Icons.timelapse, color: Colors.indigo),
                KpiCard(
                  label: 'Terminées cette semaine',
                  value: '${s.termineesSemaine}',
                  icon: Icons.task_alt,
                  color: Colors.green,
                  caption: '${s.avancementSemaine.round()} % de la semaine',
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (constraints.maxWidth >= 900)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final c in cards) Expanded(child: Padding(padding: const EdgeInsets.all(2), child: c))],
              )
            else
              ...cards,
          ],
        );
      },
    );
  }
}

class _AvancementCard extends StatelessWidget {
  final TodoStats stats;
  const _AvancementCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final sections = [
      (label: 'En retard', value: stats.enRetard, color: Colors.red),
      (label: 'À faire', value: stats.aFaire - stats.enRetard < 0 ? 0 : stats.aFaire - stats.enRetard, color: Colors.blueGrey),
      (label: 'En cours', value: stats.enCours, color: Colors.blue),
      (label: 'Terminées (semaine)', value: stats.termineesSemaine, color: Colors.green),
    ].where((s) => s.value > 0).toList();
    return CrmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.donut_large, size: 18),
            SizedBox(width: 8),
            Text('Avancement', style: TextStyle(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          if (sections.isEmpty)
            const Text('Aucune tâche', style: TextStyle(color: Colors.grey))
          else ...[
            SizedBox(
              height: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 42,
                    sections: [
                      for (final s in sections)
                        PieChartSectionData(value: s.value.toDouble(), color: s.color, radius: 22, showTitle: false),
                    ],
                  )),
                  Text('${stats.avancementSemaine.round()} %', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            for (final s in sections)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s.label, style: const TextStyle(fontSize: 12))),
                  Text('${s.value}', style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
              ),
          ],
        ],
      ),
    );
  }
}

class _BarsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Map<String, int> values;
  final Color Function(String label) colorOf;

  const _BarsCard({required this.title, required this.icon, required this.values, required this.colorOf});

  @override
  Widget build(BuildContext context) {
    final entries = values.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final max = entries.isEmpty ? 1 : entries.first.value;
    return CrmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            const Text('Aucune tâche ouverte', style: TextStyle(color: Colors.grey))
          else
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                      Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: e.value / max, minHeight: 6, color: colorOf(e.key)),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
