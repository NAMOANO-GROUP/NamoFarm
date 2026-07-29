import 'package:flutter/material.dart';

/// Style de texte commun à TOUS les filtres de l'application.
/// C'est la plus petite taille déjà utilisée dans l'app afin d'uniformiser
/// l'apparence des filtres partout.
const double kFilterFontSize = 13;
const TextStyle kFilterTextStyle = TextStyle(fontSize: kFilterFontSize);

/// Hauteur de contenu compacte commune à tous les filtres.
const EdgeInsets kFilterContentPadding =
    EdgeInsets.symmetric(horizontal: 10, vertical: 8);

/// Décoration compacte commune à tous les champs de filtre
/// (dropdowns, champs de recherche, etc.).
InputDecoration filterDecoration(
  String label, {
  String? hintText,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hintText,
    isDense: true,
    contentPadding: kFilterContentPadding,
    border: const OutlineInputBorder(),
    labelStyle: kFilterTextStyle,
    hintStyle: kFilterTextStyle,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
  );
}
