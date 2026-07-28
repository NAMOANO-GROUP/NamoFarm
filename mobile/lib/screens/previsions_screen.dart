import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';

class PrevisionsScreen extends StatefulWidget {
  const PrevisionsScreen({super.key});

  @override
  State<PrevisionsScreen> createState() => _PrevisionsScreenState();
}

class _PrevisionsScreenState extends State<PrevisionsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _bandes = [];
  List<Map<String, dynamic>> _cheptels = [];

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
      final data = await ApiService.getPrevisions();
      if (!mounted) return;
      setState(() {
        _bandes = (data['bandes'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        _cheptels = (data['cheptels'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
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

  String _fmtDate(dynamic iso) {
    if (iso == null) return '-';
    final d = DateTime.tryParse(iso.toString());
    return d == null ? '-' : DateFormat('dd/MM/yyyy').format(d);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prévisions')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _charger,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (_error != null && _error!.isNotEmpty)
                    Card(color: Colors.red.shade50, child: Padding(padding: const EdgeInsets.all(12), child: Text(_error!, style: const TextStyle(color: Colors.red)))),
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Estimations basées sur la tendance de tes données réelles (croissance, mortalité, mouvements). Plus tu saisis de relevés, plus les prévisions sont fiables.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Bandes en cours', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  if (_bandes.isEmpty)
                    const Padding(padding: EdgeInsets.all(8), child: Text('Aucune bande active', style: TextStyle(color: Colors.grey)))
                  else
                    ..._bandes.map(_bandeCard),
                  const SizedBox(height: 16),
                  const Text('Cheptels', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  if (_cheptels.isEmpty)
                    const Padding(padding: EdgeInsets.all(8), child: Text('Aucun cheptel', style: TextStyle(color: Colors.grey)))
                  else
                    ..._cheptels.map(_cheptelCard),
                ],
              ),
            ),
    );
  }

  Widget _bandeCard(Map<String, dynamic> b) {
    final gain = b['gainMoyenParJour'];
    final jours = b['joursAvantObjectif'];
    final assez = (b['nbPointsPoids'] ?? 0) as num;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text((b['nom'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('${b['typeVolaille'] ?? ''} • ${b['ageActuel'] ?? 0} jours', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 6),
            if (assez < 2)
              const Text('Pas assez de relevés de poids pour prévoir (saisir au moins 2 pesées).', style: TextStyle(color: Colors.orange))
            else ...[
              _row('Gain moyen', gain == null ? '-' : '$gain g/jour'),
              _row('Poids estimé actuel', b['poidsEstimeActuel'] == null ? '-' : '${b['poidsEstimeActuel']} g'),
              _row('Poids projeté (7j)', b['poidsProjete7j'] == null ? '-' : '${b['poidsProjete7j']} g'),
              _row('Objectif', '${b['objectifPoidsG'] ?? 0} g'),
              _row(
                'Abattage estimé',
                jours == null ? 'Croissance insuffisante' : '${_fmtDate(b['dateAbattageEstimee'])} (dans $jours j)',
                bold: true,
              ),
              _row('Mortalité actuelle / projetée', '${b['tauxMortaliteActuel'] ?? 0}% → ${b['tauxMortaliteProjete'] ?? 0}%'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cheptelCard(Map<String, dynamic> c) {
    final tendance = c['tendanceParJour'];
    final proj = c['effectifProjete30j'];
    String tendanceLabel;
    if (tendance == null) {
      tendanceLabel = 'Pas assez de données';
    } else {
      final t = (tendance as num).toDouble();
      tendanceLabel = t > 0 ? '+${t.toStringAsFixed(2)} /jour (croissance)' : (t < 0 ? '${t.toStringAsFixed(2)} /jour (baisse)' : 'stable');
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text((c['nom'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            _row('Effectif actuel', '${c['effectifActuel'] ?? 0}'),
            _row('Tendance', tendanceLabel),
            _row('Effectif projeté (30j)', proj == null ? '-' : '$proj', bold: true),
          ],
        ),
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
          Flexible(child: Text(value, textAlign: TextAlign.right, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal))),
        ],
      ),
    );
  }
}
