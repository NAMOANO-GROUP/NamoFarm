import 'package:flutter/material.dart';

/// Bouton d'action « ajouter » compact et à fort contraste (visible en clair et sombre).
/// Affiche une icône thématique dans un cercle plein coloré.
class AddButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const AddButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton.filled(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: const CircleBorder(),
      ),
      // Icône thématique + petit badge "+" pour signaler l'ajout.
      icon: SizedBox(
        width: 24,
        height: 24,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 18),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(color: scheme.onPrimary, shape: BoxShape.circle),
                padding: const EdgeInsets.all(1),
                child: Icon(Icons.add, size: 10, color: scheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
