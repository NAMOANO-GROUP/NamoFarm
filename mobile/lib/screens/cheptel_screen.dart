import 'package:flutter/material.dart';
import '../widgets/brand_logo.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/cheptel.dart';
import '../providers/cheptel_provider.dart';
import '../utils/money_format.dart';
import '../widgets/iso_calendar_picker.dart';

class CheptelScreen extends StatefulWidget {
  const CheptelScreen({super.key});

  @override
  State<CheptelScreen> createState() => _CheptelScreenState();
}

class _CheptelScreenState extends State<CheptelScreen> {
  static const Map<String, String> _mvtLabels = {
    'naissance': 'Naissance / éclosion',
    'entree': 'Entrée / achat',
    'mortalite': 'Mortalité',
    'vente': 'Vente',
    'sortie': 'Sortie / abattage',
    'ajustement': 'Ajustement (recomptage)',
  };

  static const List<String> _especes = ['chevre', 'poule_locale', 'pintade', 'mouton', 'lapin', 'autre'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CheptelProvider>().charger();
    });
  }

  String _fmtDate(DateTime? d) => d == null ? '-' : DateFormat('dd/MM/yyyy').format(d);

  IconData _mvtIcon(String type) {
    switch (type) {
      case 'naissance': return Icons.child_care;
      case 'entree': return Icons.add_circle_outline;
      case 'mortalite': return Icons.heart_broken;
      case 'vente': return Icons.sell;
      case 'sortie': return Icons.logout;
      default: return Icons.tune;
    }
  }

  Color _mvtColor(String type) {
    switch (type) {
      case 'naissance':
      case 'entree': return Colors.green;
      case 'mortalite': return Colors.red;
      case 'vente': return Colors.blue;
      case 'sortie': return Colors.orange;
      default: return Colors.blueGrey;
    }
  }

  bool _isAdd(String type) => type == 'naissance' || type == 'entree';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BrandLogo(), title: const Text('Cheptel')),
      body: Consumer<CheptelProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) return const Center(child: CircularProgressIndicator());
          return RefreshIndicator(
            onRefresh: provider.charger,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (provider.lastError != null && provider.lastError!.isNotEmpty)
                  Card(color: Theme.of(context).brightness == Brightness.dark ? Colors.red.shade900.withValues(alpha: 0.30) : Colors.red.shade50, child: Padding(padding: const EdgeInsets.all(12), child: Text(provider.lastError!, style: const TextStyle(color: Colors.red)))),
                if (provider.cheptels.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(child: Text('Aucun cheptel. Créez-en un (chèvres, poules locales, pintades...).')),
                  )
                else
                  ...provider.cheptels.map(_buildCheptelCard),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCheptelForm(),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau cheptel'),
      ),
    );
  }

  Widget _buildCheptelCard(Cheptel c) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text('${c.effectifActuel}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        title: Text(c.nom, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${c.espece.isEmpty ? 'Cheptel' : c.espece} • Effectif: ${c.effectifActuel}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    _stat('Naissances', '${c.naissances}'),
                    _stat('Entrées', '${c.entrees}'),
                    _stat('Mortalité', '${c.morts} (${c.tauxMortalite.toStringAsFixed(1)}%)'),
                    _stat('Vendus', '${c.ventes}'),
                    if (c.caVentes > 0) _stat('CA ventes', formatAmountFcfa(c.caVentes)),
                  ],
                ),
                _buildEffectifChart(c),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _showMouvementForm(c),
                      icon: const Icon(Icons.playlist_add, size: 18),
                      label: const Text('Mouvement'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _showCheptelForm(cheptel: c),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Modifier'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _confirmDeleteCheptel(c),
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                      label: const Text('Supprimer', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
                const Divider(),
                const Text('Journal des mouvements', style: TextStyle(fontWeight: FontWeight.bold)),
                if (c.mouvements.isEmpty)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Aucun mouvement', style: TextStyle(color: Colors.grey)))
                else
                  ...c.mouvements.map((m) => _buildMouvementTile(c, m)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildEffectifChart(Cheptel c) {
    // Movements come from the API most-recent first; reverse to chronological order
    // and accumulate the running headcount.
    final asc = c.mouvements.reversed.toList();
    if (asc.length < 2) return const SizedBox.shrink();
    final spots = <FlSpot>[];
    int eff = 0;
    for (var i = 0; i < asc.length; i++) {
      final m = asc[i];
      if (m.type == 'ajustement') {
        eff = m.quantite;
      } else if (m.type == 'naissance' || m.type == 'entree') {
        eff += m.quantite;
      } else {
        eff -= m.quantite;
      }
      spots.add(FlSpot(i.toDouble(), eff.toDouble()));
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Évolution de l\'effectif'),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: 0,
                gridData: const FlGridData(show: true),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots.map((s) {
                      final i = s.x.toInt();
                      final d = (i >= 0 && i < asc.length) ? asc[i].date : null;
                      return LineTooltipItem(
                        '${d != null ? _fmtDate(d) : ''}\nEffectif: ${s.y.toInt()}',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      );
                    }).toList(),
                  ),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= asc.length) return const SizedBox.shrink();
                        final d = asc[i].date;
                        if (d == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(DateFormat('dd/MM').format(d), style: const TextStyle(fontSize: 10)),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    barWidth: 3,
                    color: Theme.of(context).colorScheme.primary,
                    dotData: const FlDotData(show: true),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMouvementTile(Cheptel c, CheptelMouvement m) {
    final sign = _isAdd(m.type) ? '+' : (m.type == 'ajustement' ? '=' : '−');
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(_mvtIcon(m.type), color: _mvtColor(m.type)),
      title: Text('${_mvtLabels[m.type] ?? m.type} : $sign${m.quantite}', maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${_fmtDate(m.date)}${m.montant > 0 ? ' • ${formatAmountFcfa(m.montant)}' : ''}${m.motif.isNotEmpty ? ' • ${m.motif}' : ''}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.close, size: 18),
        tooltip: 'Supprimer le mouvement',
        onPressed: () async {
          if (c.id == null || m.id == null) return;
          final ok = await context.read<CheptelProvider>().supprimerMouvement(c.id!, m.id!);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Mouvement supprimé' : 'Suppression impossible')));
        },
      ),
    );
  }

  Future<void> _confirmDeleteCheptel(Cheptel c) async {
    if (c.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le cheptel'),
        content: Text('Supprimer "${c.nom}" et tout son historique ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final done = await context.read<CheptelProvider>().supprimerCheptel(c.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done ? 'Cheptel supprimé' : 'Suppression impossible')));
  }

  void _showCheptelForm({Cheptel? cheptel}) {
    final isEdit = cheptel != null;
    final nomCtrl = TextEditingController(text: cheptel?.nom ?? '');
    final effectifCtrl = TextEditingController();
    final notesCtrl = TextEditingController(text: cheptel?.notes ?? '');
    String espece = cheptel?.espece.isNotEmpty == true ? cheptel!.espece : 'chevre';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialog) => AlertDialog(
          title: Text(isEdit ? 'Modifier le cheptel' : 'Nouveau cheptel'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nomCtrl, decoration: const InputDecoration(labelText: 'Nom (ex: Chèvres, Poules locales) *')),
                DropdownButtonFormField<String>(
                  initialValue: _especes.contains(espece) ? espece : 'autre',
                  decoration: const InputDecoration(labelText: 'Espèce'),
                  items: _especes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setDialog(() => espece = v ?? espece),
                ),
                if (!isEdit)
                  TextField(controller: effectifCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Effectif initial (optionnel)')),
                TextField(controller: notesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(dialogContext);
                final provider = context.read<CheptelProvider>();
                if (nomCtrl.text.trim().isEmpty) {
                  messenger.showSnackBar(const SnackBar(content: Text('Le nom est obligatoire')));
                  return;
                }
                final ok = isEdit
                    ? await provider.mettreAJourCheptel(cheptel.id!, {
                        'nom': nomCtrl.text.trim(),
                        'espece': espece,
                        'notes': notesCtrl.text.trim(),
                      })
                    : await provider.creerCheptel({
                        'nom': nomCtrl.text.trim(),
                        'espece': espece,
                        'effectifInitial': int.tryParse(effectifCtrl.text.trim()) ?? 0,
                        'notes': notesCtrl.text.trim(),
                      });
                if (!mounted) return;
                navigator.pop();
                messenger.showSnackBar(SnackBar(content: Text(ok ? 'Enregistré' : 'Erreur: ${provider.lastError ?? ''}')));
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMouvementForm(Cheptel c) {
    String type = 'naissance';
    final qteCtrl = TextEditingController();
    final montantCtrl = TextEditingController();
    final motifCtrl = TextEditingController();
    DateTime date = DateTime.now();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialog) => AlertDialog(
          title: Text('Mouvement — ${c.nom}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Effectif actuel: ${c.effectifActuel}', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Type de mouvement'),
                  items: _mvtLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                  onChanged: (v) => setDialog(() => type = v ?? type),
                ),
                TextField(
                  controller: qteCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: type == 'ajustement' ? 'Nouvel effectif *' : 'Quantité *',
                  ),
                ),
                if (type == 'vente' || type == 'entree')
                  TextField(controller: montantCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Montant (FCFA)')),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date'),
                  subtitle: Text(_fmtDate(date)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showIsoDatePicker(context: dialogContext, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (picked != null) setDialog(() => date = picked);
                  },
                ),
                TextField(controller: motifCtrl, decoration: const InputDecoration(labelText: 'Motif / commentaire')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(dialogContext);
                final provider = context.read<CheptelProvider>();
                final qte = int.tryParse(qteCtrl.text.trim());
                if (qte == null || qte < 0) {
                  messenger.showSnackBar(const SnackBar(content: Text('Quantité invalide')));
                  return;
                }
                final ok = await provider.ajouterMouvement(c.id!, {
                  'type': type,
                  'quantite': qte,
                  'montant': double.tryParse(montantCtrl.text.trim().replaceAll(',', '.')) ?? 0,
                  'date': date.toIso8601String(),
                  'motif': motifCtrl.text.trim(),
                });
                if (!mounted) return;
                navigator.pop();
                messenger.showSnackBar(SnackBar(content: Text(ok ? 'Mouvement enregistré' : 'Erreur: ${provider.lastError ?? ''}')));
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
