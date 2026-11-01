import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Numéro au format international sans "+" ni espaces (ex : 221771234567),
/// ou null s'il est trop court pour être composé.
String? internationalDigits(String phone) {
  var digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('00')) digits = digits.substring(2);
  return digits.length >= 8 ? digits : null;
}

Uri? telUri(String phone) {
  final trimmed = phone.trim();
  final digits = internationalDigits(trimmed);
  if (digits == null) return null;
  return Uri(scheme: 'tel', path: trimmed.startsWith('+') || trimmed.startsWith('00') ? '+$digits' : digits);
}

Uri? whatsappUri(String phone, {String? message}) {
  final digits = internationalDigits(phone);
  if (digits == null) return null;
  final text = message?.trim() ?? '';
  return Uri.https('wa.me', '/$digits', text.isEmpty ? null : {'text': text});
}

Uri? mailUri(String email, {String? subject}) {
  final trimmed = email.trim();
  if (!trimmed.contains('@')) return null;
  return Uri(
    scheme: 'mailto',
    path: trimmed,
    query: subject == null || subject.isEmpty ? null : 'subject=${Uri.encodeComponent(subject)}',
  );
}

/// Ouvre l'application externe (téléphone, WhatsApp, mail) et signale un échec.
Future<bool> openContactUri(BuildContext context, Uri? uri, {String unavailable = 'Coordonnée indisponible'}) async {
  final messenger = ScaffoldMessenger.of(context);
  if (uri == null) {
    messenger.showSnackBar(SnackBar(content: Text(unavailable)));
    return false;
  }
  var ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok) {
    messenger.showSnackBar(const SnackBar(content: Text("Impossible d'ouvrir l'application sur cet appareil")));
  }
  return ok;
}
