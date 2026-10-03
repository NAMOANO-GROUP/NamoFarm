import 'package:flutter/material.dart';

import 'form_section.dart';

/// Corps de formulaire premium : pleine largeur, défilable et espacement
/// automatique entre les champs. Les en-têtes [FormSection] conservent leur
/// propre marge (pas de double espacement).
///
/// Remplace le motif habituel :
/// `SingleChildScrollView(child: Column(mainAxisSize: min, children: [...]))`.
class AppFormBody extends StatelessWidget {
  final List<Widget> children;
  final double gap;

  const AppFormBody(this.children, {super.key, this.gap = 12});

  @override
  Widget build(BuildContext context) {
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0 && children[i - 1] is! FormSection) {
        spaced.add(SizedBox(height: gap));
      }
      spaced.add(children[i]);
    }
    return SizedBox(
      width: double.maxFinite,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: spaced,
        ),
      ),
    );
  }
}

/// Sélecteur de date/heure présenté comme un champ premium (même style que les
/// [TextField] grâce au thème global). Remplace les `ListTile` de date basiques.
class FormDateTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  final IconData icon;

  const FormDateTile({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.icon = Icons.calendar_today,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
        child: Text(value),
      ),
    );
  }
}
