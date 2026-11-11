import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/finance_provider.dart';
import '../../utils/finance.dart';
import '../../utils/number_input.dart';
import '../../widgets/crm/crm_widgets.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_styles.dart';
import '../../widgets/number_field.dart';
import 'caisses_carte.dart';
import 'finance_common.dart';

double _n(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

/// Sujets sur lesquels sont répartis les coûts par sujet (vendus ou encore présents).
double sujetsCoutsBande(Map<String, dynamic> b) =>
    b['effectifProduit'] != null ? _n(b['effectifProduit']) : _n(b['effectifVivant']);

String? _unCout(double parSujet, double forfait) {
  if (forfait > 0 && parSujet > 0) return '${fcfa(parSujet)} / sujet + ${fcfa(forfait)}';
  if (forfait > 0) return '${fcfa(forfait)} forfait';
  if (parSujet > 0) return '${fcfa(parSujet)} / sujet';
  return null;
}

/// Résumé du coût fixe et de l'amortissement d'une bande (null si aucun n'est saisi).
String? resumeCoutsBande(Map<String, dynamic> b) {
  final fixe = _unCout(_n(b['coutFixeParSujet']), _n(b['coutFixeForfait']));
  final amort = _unCout(_n(b['amortissementParSujet']), _n(b['amortissementForfait']));
  if (fixe == null && amort == null) return null;
  return 'Coût fixe ${fixe ?? '—'} · Amort. ${amort ?? '—'}';
}

/// Configuration de la Finance : répartition des deux caisses, puis coût fixe et amortissement de chaque bande.
class ConfigurationTab extends StatefulWidget {
  const ConfigurationTab({super.key});

  @override
  State<ConfigurationTab> createState() => _ConfigurationTabState();
}

class _ConfigurationTabState extends State<ConfigurationTab> {
  String? _bandeId;
  bool _fixeForfait = false;
  bool _amortForfait = false;
  bool _enregistrement = false;
  final _fixe = TextEditingController();
  final _amort = TextEditingController();

  @override
  void dispose() {
    _fixe.dispose();
    _amort.dispose();
    super.dispose();
  }

  void _charger(Map<String, dynamic> b) {
    _bandeId = (b['bandeId'] ?? '').toString();
    final fixeForfait = _n(b['coutFixeForfait']);
    final amortForfait = _n(b['amortissementForfait']);
    _fixeForfait = fixeForfait > 0;
    _amortForfait = amortForfait > 0;
    final f = _fixeForfait ? fixeForfait : _n(b['coutFixeParSujet']);
    final a = _amortForfait ? amortForfait : _n(b['amortissementParSujet']);
    _fixe.text = f == 0 ? '' : montantSaisie(f);
    _amort.text = a == 0 ? '' : montantSaisie(a);
  }

  Future<void> _enregistrer(Map<String, dynamic> b) async {
    final fixe = parseAmount(_fixe.text) ?? 0;
    final amort = parseAmount(_amort.text) ?? 0;
    setState(() => _enregistrement = true);
    final erreur = await context.read<FinanceProvider>().enregistrerCoutsBande(_bandeId!, {
      'coutFixeParSujet': _fixeForfait ? 0 : fixe,
      'coutFixeForfait': _fixeForfait ? fixe : 0,
      'amortissementParSujet': _amortForfait ? 0 : amort,
      'amortissementForfait': _amortForfait ? amort : 0,
    });
    if (!mounted) return;
    setState(() => _enregistrement = false);
    financeSnack(context, erreur == null ? 'Coûts de ${b['bandeNom'] ?? 'la bande'} enregistrés' : 'Erreur : $erreur');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    if (!provider.accueilCharge) return const Center(child: CircularProgressIndicator());
    final scheme = Theme.of(context).colorScheme;

    bool fermee(Map<String, dynamic> b) => b['statut'] == 'fermee';
    final toutes = provider.analytiqueBandes.where((b) => (b['bandeId'] ?? '').toString().isNotEmpty);
    final bandes = [...toutes.where((b) => !fermee(b)), ...toutes.where(fermee)];
    if (bandes.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: const [
          CaissesCarte(),
          EmptyState(
            icon: Icons.tune,
            title: 'Aucune bande',
            subtitle: 'Créez une bande pour lui affecter un coût fixe et un amortissement.',
          ),
        ],
      );
    }
    var bande = bandes.where((b) => b['bandeId'].toString() == _bandeId).firstOrNull;
    if (bande == null) {
      final premiere = bandes.first;
      bande = premiere;
      if (_bandeId == null) {
        _charger(premiere);
      } else {
        // Bande choisie disparue après un rechargement : on bascule après ce dessin (les champs ont des écouteurs).
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _charger(premiere));
        });
      }
    }
    final sujets = sujetsCoutsBande(bande);

    return RefreshIndicator(
      onRefresh: () => provider.chargerAccueil(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          const CaissesCarte(),
          CrmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.tune, color: scheme.primary),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Coût fixe & amortissement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Choisissez une bande, puis saisissez chaque coût par sujet ou en forfait pour toute la bande.',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  key: ValueKey('config-bande-$_bandeId'),
                  initialValue: _bandeId,
                  isExpanded: true,
                  style: kFilterTextStyle.copyWith(color: scheme.onSurface),
                  decoration: filterDecoration('Bande', prefixIcon: const Icon(Icons.egg_outlined, size: 20)),
                  items: [
                    for (final b in bandes)
                      DropdownMenuItem(
                        value: b['bandeId'].toString(),
                        child: Text(
                          '${b['bandeNom'] ?? 'Bande'}${fermee(b) ? ' · terminée' : ''}',
                          overflow: TextOverflow.ellipsis,
                          style: kFilterTextStyle,
                        ),
                      ),
                  ],
                  onChanged: (id) => setState(() => _charger(bandes.firstWhere((b) => b['bandeId'].toString() == id))),
                ),
                const SizedBox(height: 6),
                Text(
                  '${sujets.toStringAsFixed(0)} sujets élevés (vendus ou présents)',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          _CoutSaisie(
            titre: 'Coût fixe',
            aide: 'Salaires, loyer, électricité…',
            icon: Icons.home_work_outlined,
            couleur: Colors.indigo,
            forfait: _fixeForfait,
            controller: _fixe,
            sujets: sujets,
            onMode: (v) => setState(() => _fixeForfait = v),
          ),
          _CoutSaisie(
            titre: 'Amortissement',
            aide: 'Bâtiment, mangeoires, matériel…',
            icon: Icons.timelapse,
            couleur: Colors.blueGrey,
            forfait: _amortForfait,
            controller: _amort,
            sujets: sujets,
            onMode: (v) => setState(() => _amortForfait = v),
          ),
          FilledButton.icon(
            onPressed: _enregistrement ? null : () => _enregistrer(bande!),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Enregistrer'),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 6),
            child: Text('Toutes les bandes', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          CrmCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final b in bandes)
                  ListTile(
                    dense: true,
                    selected: b['bandeId'].toString() == _bandeId,
                    leading: Icon(fermee(b) ? Icons.check_circle_outline : Icons.egg_outlined, size: 20),
                    title: Text((b['bandeNom'] ?? 'Bande').toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(resumeCoutsBande(b) ?? 'Aucun coût fixe ni amortissement'),
                    onTap: () => setState(() => _charger(b)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Saisie d'un coût : par sujet ou forfait, avec l'équivalent dans l'autre unité.
class _CoutSaisie extends StatelessWidget {
  final String titre;
  final String aide;
  final IconData icon;
  final Color couleur;
  final bool forfait;
  final TextEditingController controller;
  final double sujets;
  final ValueChanged<bool> onMode;

  const _CoutSaisie({
    required this.titre,
    required this.aide,
    required this.icon,
    required this.couleur,
    required this.forfait,
    required this.controller,
    required this.sujets,
    required this.onMode,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CrmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: couleur.withValues(alpha: 0.15),
                child: Icon(icon, size: 18, color: couleur),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titre, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(aide, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, label: Text('Par sujet')),
              ButtonSegment(value: true, label: Text('Forfait')),
            ],
            selected: {forfait},
            onSelectionChanged: (s) => onMode(s.first),
          ),
          const SizedBox(height: 8),
          NumberField(
            controller: controller,
            label: forfait ? '$titre · forfait pour la bande' : '$titre · par sujet',
            suffixText: 'FCFA',
          ),
          const SizedBox(height: 6),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, v, _) {
              final montant = parseAmount(v.text) ?? 0;
              final String texte;
              if (montant <= 0) {
                texte = forfait ? 'Montant total pour toute la bande.' : 'Montant appliqué à chaque sujet.';
              } else if (forfait) {
                texte = sujets > 0 ? 'Soit ${fcfa(montant / sujets)} par sujet' : 'Aucun sujet pour répartir ce forfait';
              } else {
                texte = 'Soit ${fcfa(montant * sujets)} pour la bande';
              }
              return Text(texte, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant));
            },
          ),
        ],
      ),
    );
  }
}
