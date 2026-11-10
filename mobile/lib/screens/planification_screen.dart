import 'package:flutter/material.dart';

import '../widgets/brand_logo.dart';
import 'planification/scenarios_tab.dart';
import 'roadmap_screen.dart';

enum _Page { roadmap, scenarii }

/// Planification : un accueil à deux cartes, chacune ouvrant sa propre page
/// (Roadmap : planning mois par mois ; Scénarii : simulation des coûts de production).
class PlanificationScreen extends StatefulWidget {
  const PlanificationScreen({super.key});

  @override
  State<PlanificationScreen> createState() => _PlanificationScreenState();
}

class _PlanificationScreenState extends State<PlanificationScreen> {
  _Page? _page;

  void _retour() => setState(() => _page = null);

  @override
  Widget build(BuildContext context) {
    final page = _page;
    return PopScope(
      canPop: page == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _retour();
      },
      child: switch (page) {
        _Page.roadmap => RoadmapScreen(onRetour: _retour),
        _Page.scenarii => Scaffold(
            appBar: AppBar(
              leading: IconButton(tooltip: 'Retour à Planification', icon: const Icon(Icons.arrow_back), onPressed: _retour),
              title: const Text('Scénarii'),
            ),
            body: const ScenariosTab(),
          ),
        null => Scaffold(
            appBar: AppBar(leading: const BrandLogo(), title: const Text('Planification')),
            body: LayoutBuilder(
              builder: (context, c) {
                final cartes = [
                  _Carte(
                    key: const ValueKey('planif-carte-roadmap'),
                    icone: Icons.view_timeline_outlined,
                    couleur: const Color(0xFF00838F),
                    titre: 'Roadmap',
                    description: 'Votre planning mois par mois : bandes, tâches, jalons et calendrier annuel.',
                    onTap: () => setState(() => _page = _Page.roadmap),
                  ),
                  _Carte(
                    key: const ValueKey('planif-carte-scenarii'),
                    icone: Icons.auto_graph,
                    couleur: const Color(0xFF2E7D32),
                    titre: 'Scénarii',
                    description: 'Simulez une production : combien coûtent 1 000 poulets en aliment, prophylaxie, poussins… et quelle marge.',
                    onTap: () => setState(() => _page = _Page.scenarii),
                  ),
                ];
                final large = c.maxWidth >= 700;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: large
                          ? IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (final carte in cartes) Expanded(child: Padding(padding: const EdgeInsets.all(6), child: carte)),
                                ],
                              ),
                            )
                          : Column(
                              children: [
                                for (final carte in cartes) Padding(padding: const EdgeInsets.only(bottom: 14), child: carte),
                              ],
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
      },
    );
  }
}

class _Carte extends StatelessWidget {
  final IconData icone;
  final Color couleur;
  final String titre;
  final String description;
  final VoidCallback onTap;

  const _Carte({super.key, required this.icone, required this.couleur, required this.titre, required this.description, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sombre = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: couleur.withValues(alpha: sombre ? 0.07 : 0.10),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), border: Border.all(color: couleur.withValues(alpha: 0.55), width: 1.4)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [couleur.withValues(alpha: 0.40), couleur.withValues(alpha: 0.15)]),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(icone, size: 28, color: couleur),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward, color: couleur),
                ],
              ),
              const SizedBox(height: 16),
              Text(titre, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(description, style: TextStyle(fontSize: 13.5, height: 1.35, color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
