import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../services/api_service.dart';
import '../utils/money_format.dart';
import '../widgets/empty_state.dart';
import '../widgets/stat_tile.dart';

class ComptabiliteScreen extends StatefulWidget {
  const ComptabiliteScreen({super.key});

  @override
  State<ComptabiliteScreen> createState() => _ComptabiliteScreenState();
}

class _ComptabiliteScreenState extends State<ComptabiliteScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _bandes = [];
  Map<String, dynamic> _totaux = {};

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.getComptabiliteAnalytique();
      final bandes = (data['bandes'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (!mounted) return;
      setState(() {
        _bandes = bandes;
        _totaux = Map<String, dynamic>.from(data['totaux'] ?? {});
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  num _n(dynamic v) => (v ?? 0) as num;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comptabilité par bande')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _charger,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (_error != null && _error!.isNotEmpty)
                    Card(color: Theme.of(context).brightness == Brightness.dark ? Colors.red.shade900.withValues(alpha: 0.30) : Colors.red.shade50, child: Padding(padding: const EdgeInsets.all(12), child: Text(_error!, style: const TextStyle(color: Colors.red)))),
                  _buildTotauxCard(),
                  const SizedBox(height: 8),
                  if (_bandes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: EmptyState(
                        icon: Icons.calculate_outlined,
                        title: 'Aucune bande',
                        subtitle: 'La comptabilité par bande apparaîtra ici une fois des bandes créées.',
                      ),
                    )
                  else
                    ..._bandes.map(_buildBandeCard),
                ],
              ),
            ),
    );
  }

  Widget _buildTotauxCard() {
    final marge = _n(_totaux['margeNette']);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: marge >= 0
          ? (isDark ? Colors.green.shade900.withValues(alpha: 0.30) : Colors.green.shade50)
          : (isDark ? Colors.red.shade900.withValues(alpha: 0.30) : Colors.red.shade50),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Synthèse globale', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Coût total: ${formatAmountFcfa(_n(_totaux['coutTotal']))}'),
            Text('Revenus: ${formatAmountFcfa(_n(_totaux['revenus']))}'),
            Text('Marge nette: ${formatAmountFcfa(marge)}  (${_n(_totaux['tauxMarge']).toStringAsFixed(1)} %)',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildBandeCard(Map<String, dynamic> b) {
    final marge = _n(b['margeNette']);
    final coutParKg = b['coutParKg'];
    final type = (b['typeVolaille'] ?? '').toString();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final margeColor = marge >= 0 ? Colors.green : Colors.red;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: margeColor.withValues(alpha: isDark ? 0.25 : 0.15),
          child: Icon(marge >= 0 ? Icons.trending_up : Icons.trending_down,
              color: isDark ? (marge >= 0 ? Colors.green.shade300 : Colors.red.shade300) : (marge >= 0 ? Colors.green.shade700 : Colors.red)),
        ),
        title: Text((b['bandeNom'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          'Marge: ${formatAmountFcfa(marge)} • Coût/sujet: ${formatAmountFcfa(_n(b['coutParSujet']))}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _infoChip(Icons.flag_outlined, '${b['statut'] ?? ''}${type.isNotEmpty ? ' • $type' : ''}'),
                    _infoChip(Icons.groups_outlined, 'Effectif ${b['effectifVivant'] ?? 0}/${b['nombreInitial'] ?? 0}'),
                    _infoChip(Icons.warning_amber_outlined, 'Mortalité ${b['mortalite'] ?? 0} (${_n(b['tauxMortalite']).toStringAsFixed(1)}%)'),
                  ],
                ),
                const SizedBox(height: 16),
                _coutPie(b),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _metricTile('Coût total', formatCompactFcfa(_n(b['coutTotal'])), Colors.blueGrey),
                    const SizedBox(width: 8),
                    _metricTile('Revenus', formatCompactFcfa(_n(b['revenus'])), Colors.green),
                    const SizedBox(width: 8),
                    _metricTile('Marge', formatCompactFcfa(marge), margeColor),
                  ],
                ),
                const SizedBox(height: 10),
                _row('Marge nette', '${formatAmountFcfa(marge)} (${_n(b['tauxMarge']).toStringAsFixed(1)} %)', bold: true, valueColor: margeColor),
                const Divider(height: 24),
                _row('Coût de revient / sujet', formatAmountFcfa(_n(b['coutParSujet']))),
                _row('Seuil rentabilité / sujet', formatAmountFcfa(_n(b['seuilRentabiliteParSujet']))),
                if (coutParKg != null) _row('Coût de revient / kg', formatAmountFcfa(_n(coutParKg))),
                if (_n(b['poidsMoyenKg']) > 0) _row('Poids moyen', '${_n(b['poidsMoyenKg']).toStringAsFixed(2)} kg'),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () => _showCoutsForm(b),
                    icon: const Icon(Icons.tune, size: 18),
                    label: const Text('Coût Fixe & Amortissement'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Camembert (donut) premium de la répartition des postes de coût de la bande.
  Widget _coutPie(Map<String, dynamic> b) {
    final autresDepenses = b.containsKey('autresDepenses')
        ? _n(b['autresDepenses'])
        : (_n(b['depenses']) - _n(b['prophylaxie']));
    final posts = <(String, double, Color)>[
      ('Poussins', _n(b['coutPoussins']).toDouble(), Colors.teal),
      ('Aliment/conso', _n(b['coutAliment']).toDouble(), Colors.brown),
      ('Prophylaxie', _n(b['prophylaxie']).toDouble(), Colors.purple),
      ('Autre dépense', autresDepenses.toDouble(), Colors.orange),
      ('Coût fixe', _n(b['coutFixe']).toDouble(), Colors.indigo),
      ('Amortissement', _n(b['coutAmortissement']).toDouble(), Colors.blueGrey),
    ].where((p) => p.$2 > 0).toList();
    final total = posts.fold<double>(0, (s, p) => s + p.$2);
    if (total <= 0) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final sections = posts.map((p) {
      final pct = p.$2 / total * 100;
      return PieChartSectionData(
        value: p.$2,
        color: p.$3,
        radius: 52,
        title: pct >= 7 ? '${pct.toStringAsFixed(0)}%' : '',
        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.pie_chart_outline, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            const Text('Répartition des coûts', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 170,
          child: PieChart(
            PieChartData(
              sections: sections,
              sectionsSpace: 2,
              centerSpaceRadius: 34,
              startDegreeOffset: -90,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...posts.map((p) {
          final pct = p.$2 / total * 100;
          return Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: p.$3, borderRadius: BorderRadius.circular(3)),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(p.$1, maxLines: 1, overflow: TextOverflow.ellipsis)),
                Text(
                  '${formatAmountFcfa(p.$2)}  •  ${pct.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _infoChip(IconData icon, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _metricTile(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false, Color? valueColor}) {
    return StatRow(label, value, bold: bold, valueColor: valueColor);
  }

  Future<void> _showCoutsForm(Map<String, dynamic> b) async {
    final bandeId = (b['bandeId'] ?? '').toString();
    if (bandeId.isEmpty) return;
    final coutFixeCtrl = TextEditingController(text: _n(b['coutFixeParSujet']) == 0 ? '' : _n(b['coutFixeParSujet']).toString());
    final amortCtrl = TextEditingController(text: _n(b['amortissementParSujet']) == 0 ? '' : _n(b['amortissementParSujet']).toString());
    final effectif = _n(b['effectifVivant']);

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Coût Fixe & Amortissement'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Montants par sujet (appliqués à ${effectif.toStringAsFixed(0)} sujets).',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              TextField(
                controller: coutFixeCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Coût Fixe / sujet (FCFA)'),
              ),
              TextField(
                controller: amortCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amortissement / sujet (FCFA)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Enregistrer')),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ApiService.mettreAJourBande(bandeId, {
        'coutFixeParSujet': double.tryParse(coutFixeCtrl.text.trim().replaceAll(',', '.')) ?? 0,
        'amortissementParSujet': double.tryParse(amortCtrl.text.trim().replaceAll(',', '.')) ?? 0,
      });
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Coûts mis à jour')));
      await _charger();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Erreur: ${e.toString().replaceFirst('Exception: ', '')}')));
    }
  }
}
