import 'package:flutter/material.dart';

import 'brand_logo.dart';

/// Une page d'un module présentée comme une grande carte sur l'accueil du module.
class ModuleCarte {
  final Key? cle;
  final IconData icone;
  final Color couleur;
  final String titre;
  final String description;

  /// Construit la page complète ; [retour] ramène à l'accueil du module.
  final Widget Function(BuildContext context, VoidCallback retour) page;

  const ModuleCarte({
    this.cle,
    required this.icone,
    required this.couleur,
    required this.titre,
    required this.description,
    required this.page,
  });
}

/// Page d'un module avec barre du haut (flèche de retour + titre) : pour les écrans qui n'ont pas la leur.
Widget moduleSousPage({
  required VoidCallback retour,
  required String titre,
  required Widget body,
  List<Widget>? actions,
}) {
  return Scaffold(
    appBar: AppBar(
      leading: IconButton(tooltip: 'Retour', icon: const Icon(Icons.arrow_back), onPressed: retour),
      title: Text(titre),
      actions: actions,
    ),
    body: body,
  );
}

/// Accueil d'un module : une carte par page (Roadmap / Scénarii, Stocks / Fournisseurs...).
/// Toucher une carte ouvre la page, la flèche de retour (ou le bouton retour du téléphone) revient aux cartes.
/// Avec une seule carte, la page s'affiche directement.
class ModuleCartesScreen extends StatefulWidget {
  final String titre;
  final List<ModuleCarte> cartes;

  const ModuleCartesScreen({super.key, required this.titre, required this.cartes});

  @override
  State<ModuleCartesScreen> createState() => _ModuleCartesScreenState();
}

class _ModuleCartesScreenState extends State<ModuleCartesScreen> {
  int? _page;

  void _retour() => setState(() => _page = null);

  @override
  Widget build(BuildContext context) {
    final cartes = widget.cartes;
    if (cartes.isEmpty) return Scaffold(appBar: AppBar(leading: const BrandLogo(), title: Text(widget.titre)), body: const Center(child: Text('Aucune page autorisée')));
    if (cartes.length == 1) {
      return Scaffold(appBar: AppBar(leading: const BrandLogo(), title: Text(widget.titre)), body: cartes.first.page(context, () {}));
    }

    final page = _page != null && _page! < cartes.length ? _page : null;
    return PopScope(
      canPop: page == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _retour();
      },
      child: page != null
          ? cartes[page].page(context, _retour)
          : Scaffold(
              appBar: AppBar(leading: const BrandLogo(), title: Text(widget.titre)),
              body: LayoutBuilder(
                builder: (context, c) {
                  final widgets = [
                    for (var i = 0; i < cartes.length; i++) _Carte(carte: cartes[i], onTap: () => setState(() => _page = i)),
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
                                  children: [for (final w in widgets) Expanded(child: Padding(padding: const EdgeInsets.all(6), child: w))],
                                ),
                              )
                            : Column(children: [for (final w in widgets) Padding(padding: const EdgeInsets.only(bottom: 14), child: w)]),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _Carte extends StatelessWidget {
  final ModuleCarte carte;
  final VoidCallback onTap;

  const _Carte({required this.carte, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sombre = Theme.of(context).brightness == Brightness.dark;
    final couleur = carte.couleur;
    return Material(
      key: carte.cle,
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
                    child: Icon(carte.icone, size: 28, color: couleur),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward, color: couleur),
                ],
              ),
              const SizedBox(height: 16),
              Text(carte.titre, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(carte.description, style: TextStyle(fontSize: 13.5, height: 1.35, color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
