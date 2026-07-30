import 'package:intl/intl.dart';

/// Affiche un montant/nombre avec toujours 2 décimales (ex: 1 234,56).
String formatAmount(num value) {
  return NumberFormat('#,##0.00', 'fr_FR').format(value);
}

String formatAmountFcfa(num value) {
  return '${formatAmount(value)} FCFA';
}

String formatCompactNumber(num value) {
  final abs = value.abs().toDouble();
  final sign = value < 0 ? '-' : '';

  if (abs < 1000) return '$sign${abs.toStringAsFixed(0)}';
  if (abs < 1000000) return '$sign${(abs / 1000).toStringAsFixed(abs >= 100000 ? 0 : 1)}k';
  if (abs < 1000000000) return '$sign${(abs / 1000000).toStringAsFixed(abs >= 100000000 ? 0 : 1)}M';
  return '$sign${(abs / 1000000000).toStringAsFixed(abs >= 100000000000 ? 0 : 1)}B';
}

String formatCompactFcfa(num value) {
  return '${formatCompactNumber(value)} FCFA';
}
