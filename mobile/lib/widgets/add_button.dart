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
      icon: Icon(icon, size: 20),
    );
  }
}
