import 'package:flutter/material.dart';

import '../widgets/brand_logo.dart';
import 'planification/scenarios_tab.dart';
import 'roadmap_screen.dart';

/// Planification : Roadmap (planning mois par mois) et Scénarii (simulation des coûts de production).
class PlanificationScreen extends StatelessWidget {
  const PlanificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: const BrandLogo(),
          title: const Text('Planification'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.view_timeline_outlined, size: 20), text: 'Roadmap'),
              Tab(icon: Icon(Icons.auto_graph, size: 20), text: 'Scénarii'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            RoadmapScreen(embedded: true),
            ScenariosTab(),
          ],
        ),
      ),
    );
  }
}
