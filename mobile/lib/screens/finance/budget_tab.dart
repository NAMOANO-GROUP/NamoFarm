import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/finance_provider.dart';
import '../../utils/finance.dart';
import '../../utils/number_input.dart';
import '../../widgets/crm/crm_widgets.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/number_field.dart';
import 'finance_common.dart';

/// Budget mensuel par poste : barres de progression, alerte à 80 %, dépassement.
class BudgetTab extends StatelessWidget {
  const BudgetTab({super.key});

  Future<void> _modifier(BuildContext context) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _BudgetsSheet(),
    );
    if (ok == true && context.mounted) financeSnack(context, 'Budgets enregistrés');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    if (!provider.accueilCharge) return const Center(child: CircularProgressIndicator());
    final peutModifier = peutEcrireFinance(context);

    if (provider.budgetsErreur) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Budgets non chargés',
        subtitle: 'Vérifiez la connexion puis réessayez.',
        actionLabel: 'Réessayer',
        actionIcon: Icons.refresh,
        onAction: () => provider.chargerAccueil(),
      );
    }

    if (!provider.budgetsDisponibles) {
      return const EmptyState(
        icon: Icons.pie_chart_outline,
        title: 'Budgets pas encore activés',
        subtitle: 'L’administrateur doit exécuter la migration add_finance_budgets.sql dans Supabase.',
      );
    }

    final now = DateTime.now();
    final mvts = provider.mouvementsRecents;
    final usages = usageBudgets(provider.budgets, mvts, now: now);
    if (usages.isEmpty) {
      return EmptyState(
        icon: Icons.savings_outlined,
        title: 'Aucun budget défini',
        subtitle: 'Fixez un plafond mensuel par poste (aliment, salaires…) : l’application vous prévient à 80 %.',
        actionLabel: peutModifier ? 'Définir mes budgets' : null,
        actionIcon: Icons.edit_outlined,
        onAction: peutModifier ? () => _modifier(context) : null,
      );
    }

    final totalBudget = usages.fold<double>(0, (s, u) => s + u.budget);
    final totalDepense = usages.fold<double>(0, (s, u) => s + u.depense);
    final global = UsageBudget('', totalBudget, totalDepense);
    final sansBudget = depensesParPoste(
      mvts,
      now.year,
      now.month,
    ).where((e) => !provider.budgets.containsKey(e.key)).toList();
    final mois = totauxMois(const [], now.year, now.month).libelle;

    return RefreshIndicator(
      onRefresh: () => provider.chargerAccueil(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          CrmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Budget de $mois', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    if (peutModifier)
                      IconButton.filledTonal(
                        tooltip: 'Modifier les budgets',
                        onPressed: () => _modifier(context),
                        icon: const Icon(Icons.edit_outlined, size: 20),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('${fcfa(totalDepense)} dépensés sur ${fcfa(totalBudget)}'),
                const SizedBox(height: 8),
                _Barre(global),
                const SizedBox(height: 6),
                Text(
                  global.depasse ? 'Dépassé de ${fcfa(-global.reste)}' : 'Il reste ${fcfa(global.reste)} ce mois-ci',
                  style: TextStyle(fontSize: 12, color: _couleur(global)),
                ),
              ],
            ),
          ),
          for (final u in usages) _BudgetLigne(u),
          if (sansBudget.isNotEmpty) ...[
            const CrmSectionHeader('Dépenses sans budget ce mois-ci', icon: Icons.help_outline),
            CrmCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final e in sansBudget)
                    ListTile(
                      dense: true,
                      leading: Icon(postePour(e.key).icon, color: postePour(e.key).color),
                      title: Text(postePour(e.key).libelle),
                      trailing: Text(fcfa(e.value), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Color _couleur(UsageBudget u) =>
    u.depasse ? Colors.red.shade700 : (u.alerte ? Colors.orange.shade800 : Colors.green.shade700);

class _Barre extends StatelessWidget {
  final UsageBudget u;
  const _Barre(this.u);

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(5),
    child: LinearProgressIndicator(
      value: u.ratio.clamp(0, 1).toDouble(),
      minHeight: 10,
      color: _couleur(u),
      backgroundColor: _couleur(u).withValues(alpha: 0.12),
    ),
  );
}

class _BudgetLigne extends StatelessWidget {
  final UsageBudget u;
  const _BudgetLigne(this.u);

  @override
  Widget build(BuildContext context) {
    final poste = postePour(u.poste);
    return CrmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(poste.icon, color: poste.color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(poste.libelle, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Text(
                '${(u.ratio * 100).round()} %',
                style: TextStyle(fontWeight: FontWeight.w800, color: _couleur(u)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _Barre(u),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${fcfa(u.depense)} sur ${fcfa(u.budget)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                u.depasse ? 'Dépassé de ${fcfa(-u.reste)}' : 'Reste ${fcfa(u.reste)}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _couleur(u)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Saisie des budgets mensuels de tous les postes (0 ou vide = pas de budget).
class _BudgetsSheet extends StatefulWidget {
  const _BudgetsSheet();

  @override
  State<_BudgetsSheet> createState() => _BudgetsSheetState();
}

class _BudgetsSheetState extends State<_BudgetsSheet> {
  late final Map<String, TextEditingController> _ctrls;
  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    final budgets = context.read<FinanceProvider>().budgets;
    final postes = [
      ...postesDepense.map((p) => p.valeur),
      ...budgets.keys.where((k) => !postesDepense.any((p) => p.valeur == k)),
    ];
    _ctrls = {
      for (final p in postes) p: TextEditingController(text: (budgets[p] ?? 0) > 0 ? montantSaisie(budgets[p]!) : ''),
    };
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _enregistrer() async {
    setState(() => _enCours = true);
    final provider = context.read<FinanceProvider>();
    final ok = await provider.enregistrerBudgets({
      for (final e in _ctrls.entries) e.key: parseAmount(e.value.text) ?? 0,
    });
    if (!mounted) return;
    setState(() => _enCours = false);
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      financeSnack(context, 'Enregistrement impossible : ${provider.lastError ?? ''}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text('Budget mensuel par poste', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Laissez vide pour ne pas suivre un poste.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              children: [
                for (final e in _ctrls.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: NumberField(
                      controller: e.value,
                      label: postePour(e.key).libelle,
                      prefixIcon: postePour(e.key).icon,
                      suffixText: 'FCFA / mois',
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: _enCours ? null : _enregistrer,
              icon: const Icon(Icons.check),
              label: const Text('Enregistrer les budgets'),
            ),
          ),
        ],
      ),
    );
  }
}
