import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../utils/finance.dart';
import '../../utils/number_input.dart';
import '../../widgets/number_field.dart';
import 'finance_common.dart';

double _n(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

/// Saisie du coût fixe et de l'amortissement par sujet d'une bande (données /finance/analytique).
/// Renvoie true si les montants ont été enregistrés.
Future<bool> modifierCoutsBande(BuildContext context, Map<String, dynamic> b) async {
  final bandeId = (b['bandeId'] ?? '').toString();
  if (bandeId.isEmpty) return false;
  final fixe = _n(b['coutFixeParSujet']);
  final amort = _n(b['amortissementParSujet']);
  final coutFixeCtrl = TextEditingController(text: fixe == 0 ? '' : montantSaisie(fixe));
  final amortCtrl = TextEditingController(text: amort == 0 ? '' : montantSaisie(amort));
  final effectif = _n(b['effectifVivant']);

  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Coût fixe & amortissement · ${(b['bandeNom'] ?? 'Bande')}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Montants par sujet, appliqués à ${effectif.toStringAsFixed(0)} sujets.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            NumberField(controller: coutFixeCtrl, label: 'Coût fixe / sujet', suffixText: 'FCFA', prefixIcon: Icons.home_work_outlined),
            NumberField(controller: amortCtrl, label: 'Amortissement / sujet', suffixText: 'FCFA', prefixIcon: Icons.timelapse),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Enregistrer')),
      ],
    ),
  );

  final coutFixe = parseAmount(coutFixeCtrl.text) ?? 0;
  final amortissement = parseAmount(amortCtrl.text) ?? 0;
  if (ok != true || !context.mounted) return false;
  try {
    await ApiService.mettreAJourBande(bandeId, {
      'coutFixeParSujet': coutFixe,
      'amortissementParSujet': amortissement,
    });
    if (context.mounted) financeSnack(context, 'Coûts mis à jour');
    return true;
  } catch (e) {
    if (context.mounted) financeSnack(context, 'Erreur : ${e.toString().replaceFirst('Exception: ', '')}');
    return false;
  }
}
