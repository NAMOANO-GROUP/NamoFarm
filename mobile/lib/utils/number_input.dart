import 'package:flutter/services.dart';

/// Formate la partie entière avec des espaces (séparateur de milliers) pendant
/// la saisie : "1000000" devient "1 000 000". Gère un séparateur décimal.
///
/// À la lecture, utilisez [parseAmount] / [parseInteger] pour retirer les espaces.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  final bool allowDecimal;
  const ThousandsSeparatorInputFormatter({this.allowDecimal = true});

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    // Normaliser le séparateur décimal et ne garder que chiffres + un point.
    final raw = newValue.text.replaceAll(',', '.');
    final buffer = StringBuffer();
    var hasDot = false;
    for (final ch in raw.split('')) {
      if (ch == '.') {
        if (!allowDecimal || hasDot) continue;
        hasDot = true;
        buffer.write('.');
      } else {
        final code = ch.codeUnitAt(0);
        if (code >= 48 && code <= 57) buffer.write(ch);
      }
    }

    final cleaned = buffer.toString();
    if (cleaned.isEmpty) return const TextEditingValue(text: '');

    String intPart = cleaned;
    String decPart = '';
    final dotIndex = cleaned.indexOf('.');
    final hasDecimal = dotIndex >= 0;
    if (hasDecimal) {
      intPart = cleaned.substring(0, dotIndex);
      decPart = cleaned.substring(dotIndex + 1);
    }

    final formattedInt = _group(intPart);
    final result = hasDecimal ? '$formattedInt.$decPart' : formattedInt;
    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }

  String _group(String digits) {
    if (digits.isEmpty) return '';
    // Retirer les zéros de tête (mais garder un "0" seul).
    final n = digits.replaceAll(RegExp(r'^0+(?=\d)'), '');
    final out = <String>[];
    var count = 0;
    for (var i = n.length - 1; i >= 0; i--) {
      out.insert(0, n[i]);
      count++;
      if (count % 3 == 0 && i != 0) out.insert(0, ' ');
    }
    return out.join();
  }
}

/// Retire les espaces (séparateurs de milliers) et normalise la virgule,
/// puis renvoie un double, ou null si vide/invalide.
double? parseAmount(String text) {
  if (text.trim().isEmpty) return null;
  final cleaned = text.replaceAll('\u00A0', '').replaceAll(' ', '').replaceAll(',', '.');
  return double.tryParse(cleaned);
}

/// Idem que [parseAmount] mais renvoie un entier arrondi.
int? parseInteger(String text) {
  final v = parseAmount(text);
  return v?.round();
}
