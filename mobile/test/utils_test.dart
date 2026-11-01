import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namofarm/utils/money_format.dart';
import 'package:namofarm/utils/number_input.dart';

// Le séparateur de milliers fr_FR varie selon la version d'intl (espace insécable fine ou non).
String _normalizeSpaces(String s) => s.replaceAll(RegExp(r'[\s\u00A0\u202F]'), ' ');

String _format(String input, {bool allowDecimal = true}) {
  return ThousandsSeparatorInputFormatter(allowDecimal: allowDecimal)
      .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: input))
      .text;
}

void main() {
  group('formatAmount', () {
    test('affiche toujours 2 décimales avec virgule et séparateur de milliers', () {
      expect(_normalizeSpaces(formatAmount(1234.5)), '1 234,50');
      expect(formatAmount(0), '0,00');
      expect(_normalizeSpaces(formatAmount(-1000000)), '-1 000 000,00');
    });

    test('formatAmountFcfa ajoute la devise', () {
      expect(_normalizeSpaces(formatAmountFcfa(2500)), '2 500,00 FCFA');
    });
  });

  group('formatCompactNumber', () {
    test('garde les petits nombres entiers', () {
      expect(formatCompactNumber(0), '0');
      expect(formatCompactNumber(999), '999');
    });

    test('abrège en k, M et B', () {
      expect(formatCompactNumber(1500), '1.5k');
      expect(formatCompactNumber(250000), '250k');
      expect(formatCompactNumber(2500000), '2.5M');
      expect(formatCompactNumber(3000000000), '3.0B');
    });

    test('conserve le signe négatif', () {
      expect(formatCompactNumber(-1500), '-1.5k');
      expect(formatCompactFcfa(-2500000), '-2.5M FCFA');
    });
  });

  group('ThousandsSeparatorInputFormatter', () {
    test('groupe la partie entière par milliers', () {
      expect(_format('1000000'), '1 000 000');
      expect(_format('999'), '999');
    });

    test('normalise la virgule et ne garde qu’un séparateur décimal', () {
      expect(_format('1234,5'), '1 234.5');
      expect(_format('12.3.4'), '12.34');
    });

    test('ignore la décimale si non autorisée', () {
      expect(_format('12.5', allowDecimal: false), '125');
    });

    test('retire les caractères non numériques et les zéros de tête', () {
      expect(_format('a1b2c'), '12');
      expect(_format('000123'), '123');
      expect(_format('0'), '0');
      expect(_format('abc'), '');
    });

    test('place le curseur en fin de texte', () {
      final value = const ThousandsSeparatorInputFormatter()
          .formatEditUpdate(TextEditingValue.empty, const TextEditingValue(text: '12345'));
      expect(value.selection, const TextSelection.collapsed(offset: 6));
    });
  });

  group('parseAmount / parseInteger', () {
    test('retire les espaces (y compris insécables) et accepte la virgule', () {
      expect(parseAmount('1 234,5'), 1234.5);
      expect(parseAmount('1\u00A0000'), 1000);
    });

    test('renvoie null si vide ou invalide', () {
      expect(parseAmount(''), isNull);
      expect(parseAmount('   '), isNull);
      expect(parseAmount('abc'), isNull);
      expect(parseInteger(''), isNull);
    });

    test('parseInteger arrondit', () {
      expect(parseInteger('2,6'), 3);
      expect(parseInteger('1 000'), 1000);
    });

    test('aller-retour formatter -> parse', () {
      expect(parseAmount(_format('1234567,89')), 1234567.89);
    });
  });
}
