import 'package:flutter/material.dart';

import '../widgets/module_cartes.dart';
import 'planification/scenarios_tab.dart';
import 'roadmap_screen.dart';

/// Planification : un accueil à deux cartes, chacune ouvrant sa propre page
/// (Roadmap : planning mois par mois ; Scénarii : simulation des coûts de production).
class PlanificationScreen extends StatelessWidget {
  const PlanificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ModuleCartesScreen(
      titre: 'Planification',
      cartes: [
        ModuleCarte(
          cle: const ValueKey('planif-carte-roadmap'),
          icone: Icons.view_timeline_outlined,
          couleur: const Color(0xFF00838F),
          titre: 'Roadmap',
          description: 'Votre planning mois par mois : bandes, tâches, jalons et calendrier annuel.',
          page: (context, retour) => RoadmapScreen(onRetour: retour),
        ),
        ModuleCarte(
          cle: const ValueKey('planif-carte-scenarii'),
          icone: Icons.auto_graph,
          couleur: const Color(0xFF2E7D32),
          titre: 'Scénarii',
          description: 'Simulez une production : combien coûtent 1 000 poulets en aliment, prophylaxie, poussins… et quelle marge.',
          page: (context, retour) => moduleSousPage(retour: retour, titre: 'Scénarii', body: const ScenariosTab()),
        ),
      ],
    );
  }
}
