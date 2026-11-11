import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/finance_provider.dart';
import '../../utils/finance.dart';
import '../../utils/number_input.dart';
import '../../widgets/crm/crm_widgets.dart';
import '../../widgets/number_field.dart';
import 'finance_common.dart';

/// Montant de l'autre caisse pour que les deux fassent toujours l'argent disponible.
double autreCaisse(double total, double montant) => total - montant;

/// Erreur de répartition (null si les deux montants sont possibles).
String? erreurCaisses(double total, double caisse1, double caisse2) {
  if (caisse2 < 0) return 'La caisse 2 ne peut pas être négative.';
  if (total <= 0 && caisse2 > 0) return 'Aucun argent disponible à mettre dans la caisse 2.';
  if (caisse1 < 0) return 'La caisse 2 ne peut pas dépasser l’argent disponible.';
  return null;
}

/// Répartition de l'argent disponible : caisse 1 (toutes les opérations) et caisse 2 (sous-caisse).
/// Modifier une caisse met l'autre à jour pour garder le total.
class CaissesCarte extends StatefulWidget {
  const CaissesCarte({super.key});

  @override
  State<CaissesCarte> createState() => _CaissesCarteState();
}

class _CaissesCarteState extends State<CaissesCarte> {
  final _c1 = TextEditingController();
  final _c2 = TextEditingController();
  bool _modifie = false;
  bool _enregistrement = false;
  ({double total, double caisse2})? _synchro;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FinanceProvider>().chargerCaisses();
    });
  }

  @override
  void dispose() {
    _c1.dispose();
    _c2.dispose();
    super.dispose();
  }

  void _remplir(double total, double caisse2) {
    _c1.text = montantSaisie(autreCaisse(total, caisse2));
    _c2.text = montantSaisie(caisse2);
    _synchro = (total: total, caisse2: caisse2);
  }

  void _saisie(TextEditingController source, TextEditingController autre, double total) {
    final v = parseAmount(source.text) ?? 0;
    autre.text = montantSaisie(autreCaisse(total, v));
    setState(() => _modifie = true);
  }

  Future<void> _enregistrer() async {
    final montant = parseAmount(_c2.text) ?? 0;
    setState(() => _enregistrement = true);
    final erreur = await context.read<FinanceProvider>().enregistrerCaisse2(montant);
    if (!mounted) return;
    setState(() {
      _enregistrement = false;
      if (erreur == null) _modifie = false;
    });
    financeSnack(context, erreur == null ? 'Répartition des caisses enregistrée' : 'Erreur : $erreur');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final scheme = Theme.of(context).colorScheme;
    final total = ((provider.solde['soldeCaisse'] ?? 0) as num).toDouble();
    // Tant que l'utilisateur ne modifie rien, les champs suivent l'argent disponible et la caisse 2 enregistrée.
    if (!_modifie && (_synchro?.total != total || _synchro?.caisse2 != provider.caisse2)) {
      _remplir(total, provider.caisse2);
    }
    final c1 = parseAmount(_c1.text) ?? 0;
    final c2 = parseAmount(_c2.text) ?? 0;
    final erreur = erreurCaisses(total, c1, c2);
    final part2 = total > 0 ? (c2 / total).clamp(0.0, 1.0) : 0.0;

    final champ1 = NumberField(
      key: const ValueKey('caisse-1'),
      controller: _c1,
      label: 'Caisse 1 · principale',
      suffixText: 'FCFA',
      helperText: 'Toutes les opérations passent ici',
      onChanged: (_) => _saisie(_c1, _c2, total),
    );
    final champ2 = NumberField(
      key: const ValueKey('caisse-2'),
      controller: _c2,
      label: 'Caisse 2 · sous-caisse',
      suffixText: 'FCFA',
      helperText: 'Aucune opération directe',
      onChanged: (_) => _saisie(_c2, _c1, total),
    );

    return CrmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: scheme.primary),
              const SizedBox(width: 10),
              const Expanded(child: Text('Caisses', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
              Text(fcfa(total), style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Répartition de l’argent disponible. Changez une caisse : l’autre s’ajuste pour garder le total.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          if (provider.caissesChargees && !provider.caissesActives) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: const Text(
                'À activer : lancez le script add_finance_caisses.sql dans Supabase pour enregistrer la caisse 2.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (part2 < 1) Expanded(flex: ((1 - part2) * 1000).round().clamp(1, 1000), child: Container(color: scheme.primary)),
                  if (part2 > 0) Expanded(flex: (part2 * 1000).round().clamp(1, 1000), child: Container(color: Colors.amber.shade700)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) => c.maxWidth >= 520
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Expanded(child: champ1), const SizedBox(width: 12), Expanded(child: champ2)],
                  )
                : Column(children: [champ1, const SizedBox(height: 8), champ2]),
          ),
          if (erreur != null) ...[
            const SizedBox(height: 8),
            Text(erreur, style: TextStyle(fontSize: 12, color: scheme.error)),
          ],
          if (_modifie) ...[
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    _modifie = false;
                    _remplir(total, provider.caisse2);
                  }),
                  child: const Text('Annuler'),
                ),
                FilledButton.icon(
                  onPressed: erreur != null || _enregistrement ? null : _enregistrer,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Enregistrer'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
