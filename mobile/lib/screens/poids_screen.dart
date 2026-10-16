import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/bande.dart';
import '../providers/bandes_provider.dart';
import '../services/api_service.dart';
import '../widgets/iso_calendar_picker.dart';
import '../widgets/number_field.dart';
import '../utils/number_input.dart';

class PoidsScreen extends StatefulWidget {
  final Bande bande;

  const PoidsScreen({super.key, required this.bande});

  @override
  State<PoidsScreen> createState() => _PoidsScreenState();
}

class _PoidsScreenState extends State<PoidsScreen> {
  DateTime _date = DateTime.now();
  final List<TextEditingController> _poidsCtrls = List.generate(6, (_) => TextEditingController());
  final TextEditingController _obsCtrl = TextEditingController();
  bool _loading = false;
  List<Map<String, dynamic>> _historique = [];
  bool _showHistory = false;

  @override
  void initState() {
    super.initState();
    for (final c in _poidsCtrls) {
      c.addListener(() {
        if (mounted) setState(() {});
      });
    }
    _chargerHistorique();
  }

  @override
  void dispose() {
    for (final c in _poidsCtrls) {
      c.dispose();
    }
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _chargerHistorique() async {
    try {
      final data = await ApiService.getRelevesPoids(widget.bande.id!);
      if (!mounted) return;
      setState(() {
        _historique = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _historique = []);
    }
  }

  List<double> _valeurs() =>
      _poidsCtrls.map((c) => parseAmount(c.text) ?? 0).where((v) => v > 0).toList();

  Future<void> _enregistrer() async {
    final valeurs = _valeurs();
    if (valeurs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saisis au moins une pesée')),
      );
      return;
    }
    final moyenne = valeurs.reduce((a, b) => a + b) / valeurs.length;

    setState(() => _loading = true);
    final ok = await context.read<BandesProvider>().ajouterRelevePoids(widget.bande.id!, {
      'date': _date.toIso8601String(),
      'poidsValeurs': valeurs,
      'poidsMotenG': moyenne,
      'observations': _obsCtrl.text.trim(),
    });

    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Prise de poids enregistrée' : 'Erreur enregistrement')),
    );
    if (ok) {
      for (final c in _poidsCtrls) {
        c.clear();
      }
      _obsCtrl.clear();
      await _chargerHistorique();
    }
  }

  Future<void> _supprimerReleve(Map<String, dynamic> row) async {
    final suiviId = (row['id'] ?? row['_id'] ?? '').toString();
    if (suiviId.isEmpty) return;
    final date = row['date'] != null ? DateTime.tryParse(row['date'].toString()) : null;
    final label = '${row['poidsMotenG']} g${date != null ? ' du ${DateFormat('dd/MM/yyyy').format(date)}' : ''}';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce relevé ?'),
        content: Text('Le relevé de poids ($label) sera supprimé. Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final error = await context.read<BandesProvider>().supprimerRelevePoids(widget.bande.id!, suiviId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error == null ? 'Relevé supprimé' : 'Erreur: $error')),
    );
    if (error == null) await _chargerHistorique();
  }

  Widget _apercuMinMax() {
    final v = _valeurs();
    if (v.isEmpty) return const SizedBox.shrink();
    final mn = v.reduce((a, b) => a < b ? a : b);
    final mx = v.reduce((a, b) => a > b ? a : b);
    final moy = v.reduce((a, b) => a + b) / v.length;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _apercuItem('Min', '${mn.toStringAsFixed(0)} g', Colors.teal),
          _apercuItem('Moyenne', '${moy.toStringAsFixed(0)} g', scheme.onSurfaceVariant),
          _apercuItem('Max', '${mx.toStringAsFixed(0)} g', Colors.green),
        ],
      ),
    );
  }

  Widget _apercuItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(title: Text('Poids - ${widget.bande.nom}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Enregistrer une prise de poids', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          ListTile(
            title: const Text('Date'),
            subtitle: Text(df.format(_date)),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final d = await showIsoDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2000),
                lastDate: DateTime.now().add(const Duration(days: 30)),
              );
              if (d != null) setState(() => _date = d);
            },
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Pesées individuelles (jusqu\'à 6) *', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: 56,
            ),
            children: List.generate(6, (i) {
              return NumberField(
                controller: _poidsCtrls[i],
                label: 'Poids ${i + 1} (g)',
                decimal: false,
                prefixIcon: Icons.monitor_weight_outlined,
              );
            }),
          ),
          const SizedBox(height: 10),
          _apercuMinMax(),
          const SizedBox(height: 10),
          TextField(
            controller: _obsCtrl,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Observations'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _loading ? null : _enregistrer,
            icon: const Icon(Icons.save),
            label: Text(_loading ? 'Enregistrement...' : 'Enregistrer'),
          ),
          const SizedBox(height: 20),
          if (_historique.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Historique des relevés', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Aucun relevé de poids'),
                  ),
                ),
              ],
            )
          else
            Card(
              child: ExpansionTile(
                initiallyExpanded: _showHistory,
                onExpansionChanged: (expanded) => setState(() => _showHistory = expanded),
                leading: const Icon(Icons.history),
                title: Text('Historique des relevés (${_historique.length})'),
                children: _historique.map((row) {
                  final date = row['date'] != null ? DateTime.tryParse(row['date'].toString()) : null;
                  final mn = (row['poidsMinG'] ?? row['poidsMotenG'] ?? 0);
                  final mx = (row['poidsMaxG'] ?? row['poidsMotenG'] ?? 0);
                  final moy = (row['poidsMotenG'] ?? 0);
                  return ListTile(
                    leading: const Icon(Icons.monitor_weight),
                    title: Text('Min $mn g • Max $mx g'),
                    subtitle: Text('Moy. $moy g • ${date != null ? df.format(date) : '-'}${(row['observations'] ?? '').toString().isNotEmpty ? ' • ${row['observations']}' : ''}'),
                    trailing: IconButton(
                      tooltip: 'Supprimer ce relevé',
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => _supprimerReleve(row),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
