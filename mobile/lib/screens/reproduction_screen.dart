import 'package:flutter/material.dart';
import '../widgets/brand_logo.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/couvee.dart';
import '../providers/reproduction_provider.dart';
import '../widgets/iso_calendar_picker.dart';

class ReproductionScreen extends StatefulWidget {
  const ReproductionScreen({super.key});

  @override
  State<ReproductionScreen> createState() => _ReproductionScreenState();
}

class _ReproductionScreenState extends State<ReproductionScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const Map<String, String> _statutLabels = {
    'en_incubation': 'En incubation',
    'mire': 'Miré',
    'eclos': 'Éclos',
    'termine': 'Terminé',
    'annule': 'Annulé',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReproductionProvider>().charger();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime? d) => d == null ? '-' : DateFormat('dd/MM/yyyy').format(d);
  String _fmtPct(double? v) => v == null ? '-' : '${v.toStringAsFixed(1)} %';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BrandLogo(),
        title: const Text('Reproduction / Couvoir'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.egg_alt_outlined), text: 'En cours'),
            Tab(icon: Icon(Icons.history), text: 'Historique'),
          ],
        ),
      ),
      body: Consumer<ReproductionProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) return const Center(child: CircularProgressIndicator());
          return RefreshIndicator(
            onRefresh: provider.charger,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildList(provider, provider.actives, showStats: true),
                _buildList(provider, provider.historique, showStats: false),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSetupForm(),
        icon: const Icon(Icons.add),
        label: const Text('Mise en incubation'),
      ),
    );
  }

  Widget _buildList(ReproductionProvider provider, List<Couvee> couvees, {required bool showStats}) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (provider.lastError != null && provider.lastError!.isNotEmpty)
          Card(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.red.shade900.withValues(alpha: 0.30)
                : Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(provider.lastError!, style: const TextStyle(color: Colors.red)),
            ),
          ),
        if (showStats) _buildStatsCard(provider),
        if (showStats) _buildHatchChart(provider.actives),
        if (couvees.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: Text('Aucune couvée')),
          )
        else
          ...couvees.map(_buildCouveeCard),
      ],
    );
  }

  Widget _buildStatsCard(ReproductionProvider provider) {
    final s = provider.stats;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Synthèse couvoir', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _stat('Couvées', '${s['totalCouvees'] ?? 0}'),
                _stat('Œufs incubés', '${s['totalIncubes'] ?? 0}'),
                _stat('Fertiles', '${s['totalFertiles'] ?? 0}'),
                _stat('Éclos', '${s['totalEclos'] ?? 0}'),
                _stat('Taux fertilité', _fmtPct((s['tauxFertiliteMoyen'] as num?)?.toDouble())),
                _stat('Taux éclosion', _fmtPct((s['tauxEclosionMoyen'] as num?)?.toDouble())),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildHatchChart(List<Couvee> couvees) {
    final withRate = couvees.where((c) => c.tauxEclosion != null).toList();
    if (withRate.isEmpty) return const SizedBox.shrink();
    final groups = <BarChartGroupData>[];
    for (var i = 0; i < withRate.length; i++) {
      groups.add(BarChartGroupData(x: i, barRods: [
        BarChartRodData(
          toY: withRate[i].tauxEclosion ?? 0,
          width: 16,
          borderRadius: BorderRadius.circular(4),
          color: Colors.teal,
        ),
      ]));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Taux d\'éclosion par couvée (%)'),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  maxY: 100,
                  gridData: const FlGridData(show: true),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, gi, rod, ri) {
                        final i = group.x.toInt();
                        if (i < 0 || i >= withRate.length) return null;
                        return BarTooltipItem(
                          '${withRate[i].code}\n${(withRate[i].tauxEclosion ?? 0).toStringAsFixed(1)} %',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      axisNameWidget: const Text('%', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600)),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.min) return const SizedBox.shrink();
                          return Text('${value.toInt()}%', style: const TextStyle(fontSize: 9));
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= withRate.length) return const SizedBox.shrink();
                          final label = withRate[i].code;
                          final short = label.length > 6 ? '${label.substring(0, 6)}…' : label;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(short, style: const TextStyle(fontSize: 10)),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: groups,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCouveeCard(Couvee c) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: const CircleAvatar(child: Icon(Icons.egg_alt_outlined)),
        title: Text(c.code, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${_statutLabels[c.statut] ?? c.statut} • ${c.nbOeufsIncubes} œufs • Fert. ${_fmtPct(c.tauxFertilite)} • Écl. ${_fmtPct(c.tauxEclosion)}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (c.race.isNotEmpty) Text('Race: ${c.race}'),
                Text('Mise en incubation: ${_fmtDate(c.dateMiseIncubation)}'),
                Text('Mirage: ${_fmtDate(c.dateMirage)} • Fertiles: ${c.nbOeufsFertiles ?? '-'}'),
                Text('Éclosion: ${_fmtDate(c.dateEclosion)} • Éclos: ${c.nbEclos ?? '-'} • Viables: ${c.nbPoussinsViables ?? '-'}'),
                Text('Taux fertilité: ${_fmtPct(c.tauxFertilite)} | Taux éclosion: ${_fmtPct(c.tauxEclosion)} | Viabilité: ${_fmtPct(c.tauxViabilite)}'),
                if (c.notes.isNotEmpty) Text('Notes: ${c.notes}', style: const TextStyle(fontStyle: FontStyle.italic)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (c.statut == 'en_incubation')
                      FilledButton.icon(
                        onPressed: () => _showMirageForm(c),
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: const Text('Mirage'),
                      ),
                    if (c.statut == 'en_incubation' || c.statut == 'mire')
                      FilledButton.icon(
                        onPressed: () => _showEclosionForm(c),
                        icon: const Icon(Icons.egg_alt, size: 18),
                        label: const Text('Éclosion'),
                      ),
                    if (c.statut == 'eclos')
                      OutlinedButton.icon(
                        onPressed: () => _cloturer(c),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Clôturer'),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => _showForm(couvee: c),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Modifier'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _confirmDelete(c),
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                      label: const Text('Supprimer', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Couvee c) async {
    if (c.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la couvée'),
        content: Text('Supprimer "${c.code}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final done = await context.read<ReproductionProvider>().supprimer(c.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(done ? 'Couvée supprimée' : 'Suppression impossible')),
    );
  }

  Future<void> _cloturer(Couvee c) async {
    if (c.id == null) return;
    final ok = await context.read<ReproductionProvider>().mettreAJour(c.id!, {'statut': 'termine'});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Couvée clôturée' : 'Erreur clôture')),
    );
  }

  Future<void> _saveStage(
    String? id,
    Map<String, dynamic> payload,
    NavigatorState navigator,
    ScaffoldMessengerState messenger, {
    required bool isCreate,
  }) async {
    final provider = context.read<ReproductionProvider>();
    final ok = isCreate ? await provider.creer(payload) : await provider.mettreAJour(id!, payload);
    if (!mounted) return;
    navigator.pop();
    final err = provider.lastError;
    messenger.showSnackBar(
      SnackBar(content: Text(ok ? 'Enregistré' : 'Erreur${err != null && err.isNotEmpty ? ': $err' : ''}')),
    );
  }

  Widget _dateTile(String label, DateTime? date, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(_fmtDate(date)),
      trailing: const Icon(Icons.calendar_today),
      onTap: onTap,
    );
  }

  // Étape 1 — Mise en incubation (création)
  void _showSetupForm() {
    final codeCtrl = TextEditingController();
    final raceCtrl = TextEditingController();
    final incubesCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime date = DateTime.now();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialog) => AlertDialog(
          title: const Text('Mise en incubation'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Code / référence *')),
                TextField(controller: raceCtrl, decoration: const InputDecoration(labelText: 'Race')),
                TextField(controller: incubesCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Œufs mis en incubation *')),
                _dateTile('Date de mise en incubation', date, () async {
                  final picked = await showIsoDatePicker(context: dialogContext, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (picked != null) setDialog(() => date = picked);
                }),
                TextField(controller: notesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(dialogContext);
                final incubes = int.tryParse(incubesCtrl.text.trim());
                if (codeCtrl.text.trim().isEmpty || incubes == null) {
                  messenger.showSnackBar(const SnackBar(content: Text('Code et nombre d\'œufs obligatoires')));
                  return;
                }
                _saveStage(null, {
                  'code': codeCtrl.text.trim(),
                  'race': raceCtrl.text.trim(),
                  'dateMiseIncubation': date.toIso8601String(),
                  'nbOeufsIncubes': incubes,
                  'notes': notesCtrl.text.trim(),
                }, navigator, messenger, isCreate: true);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  // Étape 2 — Mirage (œufs fertiles)
  void _showMirageForm(Couvee c) {
    final fertilesCtrl = TextEditingController(text: c.nbOeufsFertiles?.toString() ?? '');
    DateTime date = c.dateMirage ?? DateTime.now();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialog) => AlertDialog(
          title: Text('Mirage — ${c.code}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Œufs mis en incubation: ${c.nbOeufsIncubes}'),
                const SizedBox(height: 8),
                TextField(controller: fertilesCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Œufs fertiles *')),
                _dateTile('Date du mirage', date, () async {
                  final picked = await showIsoDatePicker(context: dialogContext, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (picked != null) setDialog(() => date = picked);
                }),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(dialogContext);
                final fertiles = int.tryParse(fertilesCtrl.text.trim());
                if (fertiles == null) {
                  messenger.showSnackBar(const SnackBar(content: Text('Nombre d\'œufs fertiles obligatoire')));
                  return;
                }
                _saveStage(c.id, {
                  'nbOeufsFertiles': fertiles,
                  'dateMirage': date.toIso8601String(),
                  'statut': 'mire',
                }, navigator, messenger, isCreate: false);
              },
              child: const Text('Enregistrer le mirage'),
            ),
          ],
        ),
      ),
    );
  }

  // Étape 3 — Éclosion (sortie)
  void _showEclosionForm(Couvee c) {
    final eclosCtrl = TextEditingController(text: c.nbEclos?.toString() ?? '');
    final viablesCtrl = TextEditingController(text: c.nbPoussinsViables?.toString() ?? '');
    DateTime date = c.dateEclosion ?? DateTime.now();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialog) => AlertDialog(
          title: Text('Éclosion — ${c.code}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Œufs fertiles: ${c.nbOeufsFertiles ?? '-'} / incubés: ${c.nbOeufsIncubes}'),
                const SizedBox(height: 8),
                TextField(controller: eclosCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Poussins éclos *')),
                TextField(controller: viablesCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Poussins viables')),
                _dateTile('Date d\'éclosion', date, () async {
                  final picked = await showIsoDatePicker(context: dialogContext, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (picked != null) setDialog(() => date = picked);
                }),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(dialogContext);
                final eclos = int.tryParse(eclosCtrl.text.trim());
                if (eclos == null) {
                  messenger.showSnackBar(const SnackBar(content: Text('Nombre de poussins éclos obligatoire')));
                  return;
                }
                _saveStage(c.id, {
                  'nbEclos': eclos,
                  'nbPoussinsViables': int.tryParse(viablesCtrl.text.trim()),
                  'dateEclosion': date.toIso8601String(),
                  'statut': 'eclos',
                }, navigator, messenger, isCreate: false);
              },
              child: const Text('Enregistrer l\'éclosion'),
            ),
          ],
        ),
      ),
    );
  }

  void _showForm({Couvee? couvee}) {
    final isEdit = couvee != null;
    final codeCtrl = TextEditingController(text: couvee?.code ?? '');
    final raceCtrl = TextEditingController(text: couvee?.race ?? '');
    final incubesCtrl = TextEditingController(text: isEdit ? couvee.nbOeufsIncubes.toString() : '');
    final fertilesCtrl = TextEditingController(text: couvee?.nbOeufsFertiles?.toString() ?? '');
    final eclosCtrl = TextEditingController(text: couvee?.nbEclos?.toString() ?? '');
    final viablesCtrl = TextEditingController(text: couvee?.nbPoussinsViables?.toString() ?? '');
    final notesCtrl = TextEditingController(text: couvee?.notes ?? '');
    DateTime dateIncubation = couvee?.dateMiseIncubation ?? DateTime.now();
    DateTime? dateMirage = couvee?.dateMirage;
    DateTime? dateEclosion = couvee?.dateEclosion;
    String statut = couvee?.statut ?? 'en_incubation';

    int? parseIntOrNull(String s) => s.trim().isEmpty ? null : int.tryParse(s.trim());

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialog) => AlertDialog(
          title: Text(isEdit ? 'Modifier la couvée' : 'Nouvelle couvée'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Code / référence *')),
                TextField(controller: raceCtrl, decoration: const InputDecoration(labelText: 'Race')),
                TextField(
                  controller: incubesCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Œufs incubés *'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date mise en incubation'),
                  subtitle: Text(_fmtDate(dateIncubation)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showIsoDatePicker(
                      context: dialogContext,
                      initialDate: dateIncubation,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setDialog(() => dateIncubation = picked);
                  },
                ),
                const Divider(),
                const Align(alignment: Alignment.centerLeft, child: Text('Mirage', style: TextStyle(fontWeight: FontWeight.bold))),
                TextField(
                  controller: fertilesCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Œufs fertiles (au mirage)'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date mirage'),
                  subtitle: Text(_fmtDate(dateMirage)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showIsoDatePicker(
                      context: dialogContext,
                      initialDate: dateMirage ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setDialog(() => dateMirage = picked);
                  },
                ),
                const Divider(),
                const Align(alignment: Alignment.centerLeft, child: Text('Éclosion', style: TextStyle(fontWeight: FontWeight.bold))),
                TextField(
                  controller: eclosCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Poussins éclos'),
                ),
                TextField(
                  controller: viablesCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Poussins viables'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date éclosion'),
                  subtitle: Text(_fmtDate(dateEclosion)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showIsoDatePicker(
                      context: dialogContext,
                      initialDate: dateEclosion ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setDialog(() => dateEclosion = picked);
                  },
                ),
                const Divider(),
                DropdownButtonFormField<String>(
                  initialValue: statut,
                  decoration: const InputDecoration(labelText: 'Statut'),
                  items: _statutLabels.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) => setDialog(() => statut = v ?? statut),
                ),
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
                final provider = context.read<ReproductionProvider>();
                if (codeCtrl.text.trim().isEmpty || parseIntOrNull(incubesCtrl.text) == null) {
                  messenger.showSnackBar(const SnackBar(content: Text('Code et nombre d\'œufs incubés obligatoires')));
                  return;
                }
                final payload = <String, dynamic>{
                  'code': codeCtrl.text.trim(),
                  'race': raceCtrl.text.trim(),
                  'dateMiseIncubation': dateIncubation.toIso8601String(),
                  'nbOeufsIncubes': parseIntOrNull(incubesCtrl.text),
                  'nbOeufsFertiles': parseIntOrNull(fertilesCtrl.text),
                  'nbEclos': parseIntOrNull(eclosCtrl.text),
                  'nbPoussinsViables': parseIntOrNull(viablesCtrl.text),
                  'dateMirage': dateMirage?.toIso8601String(),
                  'dateEclosion': dateEclosion?.toIso8601String(),
                  'statut': statut,
                  'notes': notesCtrl.text.trim(),
                };
                final ok = isEdit
                    ? await provider.mettreAJour(couvee.id!, payload)
                    : await provider.creer(payload);
                if (!mounted) return;
                navigator.pop();
                final err = provider.lastError;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? (isEdit ? 'Couvée modifiée' : 'Couvée créée')
                        : 'Erreur${err != null && err.isNotEmpty ? ': $err' : ''}'),
                  ),
                );
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
