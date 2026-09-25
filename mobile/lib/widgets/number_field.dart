import 'package:flutter/material.dart';
import '../utils/number_input.dart';

/// Champ de saisie numérique avec séparateur de milliers automatique.
/// Utilisez parseAmount / parseInteger (utils/number_input.dart) pour lire la valeur.
class NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool decimal;
  final String? suffixText;
  final String? helperText;

  const NumberField({
    super.key,
    required this.controller,
    required this.label,
    this.decimal = true,
    this.suffixText,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [ThousandsSeparatorInputFormatter(allowDecimal: decimal)],
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffixText,
        helperText: helperText,
      ),
    );
  }
}
