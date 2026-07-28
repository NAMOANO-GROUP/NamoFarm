import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/money_format.dart';

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
                    Card(color: Colors.red.shade50, child: Padding(padding: const EdgeInsets.all(12), child: Text(_error!, style: const TextStyle(color: Colors.red)))),
                  _buildTotauxCard(),
                  const SizedBox(height: 8),
                  if (_bandes.isEmpty)
                    const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: Text('Aucune bande')))
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: marge >= 0 ? Colors.green.shade100 : Colors.red.shade100,
          child: Icon(marge >= 0 ? Icons.trending_up : Icons.trending_down, color: marge >= 0 ? Colors.green.shade700 : Colors.red),
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
                _row('Statut', '${b['statut'] ?? ''}${type.isNotEmpty ? ' • $type' : ''}'),
                _row('Effectif', '${b['effectifVivant'] ?? 0} / ${b['nombreInitial'] ?? 0}'),
                _row('Mortalité', '${b['mortalite'] ?? 0} (${_n(b['tauxMortalite']).toStringAsFixed(1)} %)'),
                const Divider(),
                _row('Coût poussins', formatAmountFcfa(_n(b['coutPoussins']))),
                _row('Dépenses bande', formatAmountFcfa(_n(b['depenses']))),
                _row('Coût total', formatAmountFcfa(_n(b['coutTotal'])), bold: true),
                _row('Revenus', formatAmountFcfa(_n(b['revenus']))),
                _row('Marge nette', '${formatAmountFcfa(marge)} (${_n(b['tauxMarge']).toStringAsFixed(1)} %)', bold: true),
                const Divider(),
                _row('Coût de revient / sujet', formatAmountFcfa(_n(b['coutParSujet']))),
                _row('Seuil rentabilité / sujet', formatAmountFcfa(_n(b['seuilRentabiliteParSujet']))),
                if (coutParKg != null) _row('Coût de revient / kg', formatAmountFcfa(_n(coutParKg))),
                if (_n(b['poidsMoyenKg']) > 0) _row('Poids moyen', '${_n(b['poidsMoyenKg']).toStringAsFixed(2)} kg'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.grey))),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal),
            ),
          ),
        ],
      ),
    );
  }
}
