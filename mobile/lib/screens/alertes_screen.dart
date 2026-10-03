import 'package:flutter/material.dart';
import '../widgets/brand_logo.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/alertes_provider.dart';
import '../models/alerte.dart';
import '../services/api_service.dart';
import '../utils/csv_export.dart';
import '../widgets/iso_calendar_picker.dart';
import '../widgets/filter_styles.dart';
import '../widgets/status_pill.dart';
import '../widgets/recurrence_picker.dart';
import '../widgets/week_calendar_view.dart';

class AlertesScreen extends StatefulWidget {
  const AlertesScreen({super.key});

  @override
  State<AlertesScreen> createState() => _AlertesScreenState();
}

class _AlertesScreenState extends State<AlertesScreen> {
  bool _showHistory = false;
  bool _vueSemaine = false;
  String _dateFilter = 'all';
  DateTime? _selectedDate;
  DateTimeRange? _selectedRange;

  static const List<Map<String, String>> _dateFilterOptions = [
    {'value': 'all', 'label': 'Toutes les dates'},
    {'value': 'tomorrow', 'label': 'Demain'},
    {'value': 'date', 'label': 'Date précise'},
    {'value': 'range', 'label': 'Intervalle'},
  ];

  static const List<Map<String, String>> _periodOptions = [
    {'value': 'today', 'label': 'Ma journée'},
    {'value': 'week', 'label': 'Cette semaine'},
    {'value': 'month', 'label': 'Ce mois'},
    {'value': 'all', 'label': 'Toutes les tâches'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AlertesProvider>().chargerAlertes(period: 'all');
      context.read<AlertesProvider>().chargerAlertesAutomatiques();
      context.read<AlertesProvider>().chargerHistoriqueAlertes();
      context.read<AlertesProvider>().chargerHistoriqueAlertesAutomatiques();
    });
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _matchesDateFilter(Alerte alerte) {
    final d = alerte.dateEcheance;
    if (_dateFilter == 'all') return true;
    if (_dateFilter == 'tomorrow') {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      return _sameDay(d, tomorrow);
    }
    if (_dateFilter == 'date' && _selectedDate != null) {
      return _sameDay(d, _selectedDate!);
    }
    if (_dateFilter == 'range' && _selectedRange != null) {
      final start = DateTime(_selectedRange!.start.year, _selectedRange!.start.month, _selectedRange!.start.day);
      final end = DateTime(_selectedRange!.end.year, _selectedRange!.end.month, _selectedRange!.end.day, 23, 59, 59);
      return !d.isBefore(start) && !d.isAfter(end);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BrandLogo(),
        title: const Text('Todo list'),
        actions: [
          IconButton(
            tooltip: _vueSemaine ? 'Vue liste' : 'Vue semaine',
            icon: Icon(_vueSemaine ? Icons.view_list_outlined : Icons.calendar_view_week_outlined),
            onPressed: () => setState(() => _vueSemaine = !_vueSemaine),
          ),
        ],
      ),
      body: Consumer<AlertesProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final maintenant = DateTime.now();
          final base = [...provider.alertes, ...provider.alertesAutomatiques];
          final historique = [...provider.historiqueAlertes, ...provider.historiqueAlertesAutomatiques];

          if (_vueSemaine) {
            return WeekCalendarView(
              alertes: base,
              onTap: (a) {
                if (!a.automatique && a.id != null) _showModifierAlerteDialog(a);
              },
              onMove: (a, newStart) async {
                if (a.automatique || a.id == null) return;
                final duree = (a.dateFin ?? a.dateEcheance.add(const Duration(hours: 1))).difference(a.dateEcheance);
                final newFin = newStart.add(duree.inMinutes > 0 ? duree : const Duration(hours: 1));
                final prov = context.read<AlertesProvider>();
                await prov.mettreAJourAlerte(a.id!, {
                  'dateEcheance': newStart.toIso8601String(),
                  'dateFin': newFin.toIso8601String(),
                });
                await prov.chargerAlertes(period: 'all');
              },
            );
          }

          final filtered = base.where(_matchesDateFilter).toList()
            ..sort((a, b) => a.dateEcheance.compareTo(b.dateEcheance));

          final enRetard = filtered.where((a) => a.dateEcheance.isBefore(maintenant)).toList();
          final aVenir = filtered.where((a) => !a.dateEcheance.isBefore(maintenant)).toList();
          final isEmpty = base.isEmpty && historique.isEmpty;

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _dateFilter,
                      isExpanded: true,
                      isDense: true,
                      style: kFilterTextStyle.copyWith(color: Theme.of(context).colorScheme.onSurface),
                      decoration: const InputDecoration(
                        labelText: 'Date',
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      items: _dateFilterOptions
                          .map(
                            (opt) => DropdownMenuItem<String>(
                              value: opt['value'],
                              child: Text(opt['label'] ?? '', style: kFilterTextStyle),
                            ),
                          )
                          .toList(),
                      onChanged: (value) async {
                        if (value == null) return;
                        if (value == 'date') {
                          final picked = await showIsoDatePicker(
                            context: context,
                            initialDate: _selectedDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() {
                              _selectedDate = picked;
                              _dateFilter = 'date';
                            });
                          }
                          return;
                        }
                        if (value == 'range') {
                          final picked = await showIsoDateRangePicker(
                            context: context,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            initialDateRange: _selectedRange,
                          );
                          if (picked != null) {
                            setState(() {
                              _selectedRange = picked;
                              _dateFilter = 'range';
                            });
                          }
                          return;
                        }
                        setState(() => _dateFilter = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: provider.todoPeriod,
                      isExpanded: true,
                      isDense: true,
                      style: kFilterTextStyle.copyWith(color: Theme.of(context).colorScheme.onSurface),
                      decoration: const InputDecoration(
                        labelText: 'Période',
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      items: _periodOptions
                          .map(
                            (opt) => DropdownMenuItem<String>(
                              value: opt['value'],
                              child: Text(opt['label'] ?? '', style: kFilterTextStyle),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null && value.isNotEmpty) {
                          provider.chargerAlertes(period: value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: IconButton.filled(
                    tooltip: 'Nouvelle tâche',
                    onPressed: () => _showAjouterAlerteDialog(),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.add_alert, size: 18),
                  ),
                ),
              ),
              if (_dateFilter == 'date' && _selectedDate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Date: ${DateFormat('dd/MM/yyyy').format(_selectedDate!)}'),
                ),
              if (_dateFilter == 'range' && _selectedRange != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Du ${DateFormat('dd/MM').format(_selectedRange!.start)} au ${DateFormat('dd/MM').format(_selectedRange!.end)}'),
                ),
              const SizedBox(height: 12),
              if (historique.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => exportCsvToClipboard(
                          context,
                          loader: ApiService.exportHistoriqueAlertesCsv,
                          label: 'Historique alertes',
                        ),
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('Exporter CSV'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => context.read<AlertesProvider>().effacerHistorique(),
                        icon: const Icon(Icons.delete_sweep),
                        label: const Text('Effacer historique'),
                      ),
                    ],
                  ),
                ),
              if (historique.isNotEmpty) const SizedBox(height: 8),
              if (isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text('Aucune tâche active', style: TextStyle(fontSize: 18, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              if (enRetard.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.red),
                    const SizedBox(width: 8),
                    Text('En retard (${enRetard.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                  ],
                ),
                const SizedBox(height: 8),
                ...enRetard.map((a) => _buildAlerteCard(a, enRetard: true)),
                const SizedBox(height: 16),
              ],
              if (aVenir.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.schedule, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text('À venir (${aVenir.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                ...aVenir.map((a) => _buildAlerteCard(a, enRetard: false)),
              ],
              if (historique.isNotEmpty) ...[
                const SizedBox(height: 16),
                ExpansionTile(
                  initiallyExpanded: _showHistory,
                  onExpansionChanged: (expanded) => setState(() => _showHistory = expanded),
                  leading: const Icon(Icons.history, color: Colors.blueGrey),
                  title: Text('Historique (${historique.length})'),
                  children: [
                    ...historique.map((a) => _buildAlerteCard(a, enRetard: false, allowComplete: false)),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildAlerteCard(Alerte alerte, {required bool enRetard, bool allowComplete = true}) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    MaterialColor prioriteColor;
    switch (alerte.priorite) {
      case 'urgente': prioriteColor = Colors.red; break;
      case 'haute': prioriteColor = Colors.orange; break;
      case 'moyenne': prioriteColor = Colors.blue; break;
      default: prioriteColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: enRetard
          ? (Theme.of(context).brightness == Brightness.dark
              ? Colors.red.shade900.withValues(alpha: 0.30)
              : Colors.red.shade50)
          : null,
      child: ListTile(
        leading: Icon(
          _typeIcon(alerte.type),
          color: enRetard ? Colors.red : Colors.green,
        ),
        title: Text(alerte.titre, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alerte.message),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  label: Text(dateFormat.format(alerte.dateEcheance), style: const TextStyle(fontSize: 11)),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                StatusPill(label: alerte.priorite, color: prioriteColor),
                if (alerte.recurrence != 'aucune' && alerte.recurrence.isNotEmpty)
                  Chip(
                    avatar: Icon(Icons.repeat, size: 14, color: Colors.indigo.shade400),
                    label: Text(recurrenceSummary(alerte.recurrence, alerte.recurrenceConfig), style: const TextStyle(fontSize: 11)),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (allowComplete && alerte.id != null) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showModifierAlerteDialog(alerte),
                    icon: const Icon(Icons.edit_outlined, color: Colors.blueGrey),
                    label: const Text('Modifier'),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      context.read<AlertesProvider>().marquerFaite(alerte);
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Tâche faite'),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: null,
        isThreeLine: true,
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'vaccination': return Icons.vaccines;
      case 'alimentation': return Icons.restaurant;
      case 'stock_bas': return Icons.inventory;
      case 'vente': return Icons.sell;
      case 'medicament': return Icons.medication;
      case 'controle_sanitaire': return Icons.health_and_safety;
      case 'pesee': return Icons.monitor_weight;
      case 'intervention_diverse': return Icons.build_circle;
      default: return Icons.notifications;
    }
  }

  DateTime _defaultDebut() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1, 8);
  }

  String _fmtDateTime(DateTime d, bool allDay) {
    return allDay ? DateFormat('dd/MM/yyyy').format(d) : DateFormat('dd/MM/yyyy HH:mm').format(d);
  }

  Future<DateTime?> _pickDateTime(DateTime initial, bool allDay) async {
    final date = await showIsoDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) return null;
    if (allDay) return DateTime(date.year, date.month, date.day);
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    final tt = t ?? TimeOfDay.fromDateTime(initial);
    return DateTime(date.year, date.month, date.day, tt.hour, tt.minute);
  }

  // Calcule les échéances début/fin finales selon la récurrence et le mode "toute la journée".
  ({DateTime debut, DateTime fin}) _computeEcheances(
      String rec, Map<String, dynamic> config, DateTime debut, DateTime fin, bool allDay) {
    if (rec != 'aucune' && rec != 'quotidien') {
      final first = computeFirstEcheance(rec, config, debut);
      final d = allDay
          ? DateTime(first.year, first.month, first.day)
          : DateTime(first.year, first.month, first.day, debut.hour, debut.minute);
      final durMin = fin.difference(debut).inMinutes;
      final f = allDay
          ? DateTime(first.year, first.month, first.day, 23, 59)
          : d.add(Duration(minutes: durMin > 0 ? durMin : 60));
      return (debut: d, fin: f);
    }
    final d = allDay ? DateTime(debut.year, debut.month, debut.day) : debut;
    final f = allDay
        ? DateTime(fin.year, fin.month, fin.day, 23, 59)
        : (fin.isAfter(d) ? fin : d.add(const Duration(hours: 1)));
    return (debut: d, fin: f);
  }

  void _showAjouterAlerteDialog() {
    final titreCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    String selectedType = 'vaccination';
    String selectedPriorite = 'moyenne';
    String selectedRecurrence = 'aucune';
    Map<String, dynamic> recurrenceConfig = {};
    bool touteJournee = false;
    DateTime debut = _defaultDebut();
    DateTime fin = _defaultDebut().add(const Duration(hours: 1));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nouvelle tâche'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titreCtrl, decoration: const InputDecoration(labelText: 'Titre *')),
                TextField(controller: messageCtrl, decoration: const InputDecoration(labelText: 'Message')),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  items: const [
                    DropdownMenuItem(value: 'vaccination', child: Text('Vaccination')),
                    DropdownMenuItem(value: 'alimentation', child: Text('Alimentation')),
                    DropdownMenuItem(value: 'stock_bas', child: Text('Stock bas')),
                    DropdownMenuItem(value: 'vente', child: Text('Vente')),
                    DropdownMenuItem(value: 'medicament', child: Text('Médicament')),
                    DropdownMenuItem(value: 'autre', child: Text('Autre')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedType = v!),
                  decoration: const InputDecoration(labelText: 'Type'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: selectedPriorite,
                  items: const [
                    DropdownMenuItem(value: 'basse', child: Text('Basse')),
                    DropdownMenuItem(value: 'moyenne', child: Text('Moyenne')),
                    DropdownMenuItem(value: 'haute', child: Text('Haute')),
                    DropdownMenuItem(value: 'urgente', child: Text('Urgente')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedPriorite = v!),
                  decoration: const InputDecoration(labelText: 'Priorité'),
                ),
                const SizedBox(height: 8),
                RecurrencePicker(
                  recurrence: selectedRecurrence,
                  config: recurrenceConfig,
                  onChanged: (r, c) => setDialogState(() {
                    selectedRecurrence = r;
                    recurrenceConfig = c;
                  }),
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Toute la journée'),
                  value: touteJournee,
                  onChanged: (v) => setDialogState(() => touteJournee = v),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Début'),
                  subtitle: Text(_fmtDateTime(debut, touteJournee)),
                  trailing: const Icon(Icons.schedule),
                  onTap: () async {
                    final picked = await _pickDateTime(debut, touteJournee);
                    if (picked != null) {
                      setDialogState(() {
                        debut = picked;
                        if (!fin.isAfter(debut)) fin = debut.add(const Duration(hours: 1));
                      });
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Fin'),
                  subtitle: Text(_fmtDateTime(fin, touteJournee)),
                  trailing: const Icon(Icons.schedule),
                  onTap: () async {
                    final picked = await _pickDateTime(fin, touteJournee);
                    if (picked != null) setDialogState(() => fin = picked);
                  },
                ),
                if (selectedRecurrence != 'aucune' && selectedRecurrence != 'quotidien')
                  const Padding(
                    padding: EdgeInsets.only(top: 4, left: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('La date de début s\'aligne sur la récurrence ; l\'heure est conservée.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                if (titreCtrl.text.isEmpty) return;
                Navigator.pop(ctx);
                final e = _computeEcheances(selectedRecurrence, recurrenceConfig, debut, fin, touteJournee);
                context.read<AlertesProvider>().creerAlerte({
                  'titre': titreCtrl.text,
                  'message': messageCtrl.text,
                  'type': selectedType,
                  'priorite': selectedPriorite,
                  'recurrence': selectedRecurrence,
                  'recurrenceConfig': recurrenceConfig,
                  'dateEcheance': e.debut.toIso8601String(),
                  'dateFin': e.fin.toIso8601String(),
                  'touteJournee': touteJournee,
                });
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }

  void _showModifierAlerteDialog(Alerte alerte) {
    if (alerte.id == null) return;

    final titreCtrl = TextEditingController(text: alerte.titre);
    final messageCtrl = TextEditingController(text: alerte.message);
    String selectedType = alerte.type;
    String selectedPriorite = alerte.priorite;
    String selectedRecurrence = alerte.recurrence.isEmpty ? 'aucune' : alerte.recurrence;
    Map<String, dynamic> recurrenceConfig = Map<String, dynamic>.from(alerte.recurrenceConfig);
    bool touteJournee = alerte.touteJournee;
    DateTime debut = alerte.dateEcheance;
    DateTime fin = alerte.dateFin ?? alerte.dateEcheance.add(const Duration(hours: 1));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Modifier tâche'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titreCtrl, decoration: const InputDecoration(labelText: 'Titre *')),
                TextField(controller: messageCtrl, decoration: const InputDecoration(labelText: 'Message')),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  items: const [
                    DropdownMenuItem(value: 'vaccination', child: Text('Vaccination')),
                    DropdownMenuItem(value: 'alimentation', child: Text('Alimentation')),
                    DropdownMenuItem(value: 'stock_bas', child: Text('Stock bas')),
                    DropdownMenuItem(value: 'vente', child: Text('Vente')),
                    DropdownMenuItem(value: 'medicament', child: Text('Médicament')),
                    DropdownMenuItem(value: 'autre', child: Text('Autre')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedType = v ?? selectedType),
                  decoration: const InputDecoration(labelText: 'Type'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: selectedPriorite,
                  items: const [
                    DropdownMenuItem(value: 'basse', child: Text('Basse')),
                    DropdownMenuItem(value: 'moyenne', child: Text('Moyenne')),
                    DropdownMenuItem(value: 'haute', child: Text('Haute')),
                    DropdownMenuItem(value: 'urgente', child: Text('Urgente')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedPriorite = v ?? selectedPriorite),
                  decoration: const InputDecoration(labelText: 'Priorité'),
                ),
                const SizedBox(height: 8),
                RecurrencePicker(
                  recurrence: selectedRecurrence,
                  config: recurrenceConfig,
                  onChanged: (r, c) => setDialogState(() {
                    selectedRecurrence = r;
                    recurrenceConfig = c;
                  }),
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Toute la journée'),
                  value: touteJournee,
                  onChanged: (v) => setDialogState(() => touteJournee = v),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Début'),
                  subtitle: Text(_fmtDateTime(debut, touteJournee)),
                  trailing: const Icon(Icons.schedule),
                  onTap: () async {
                    final picked = await _pickDateTime(debut, touteJournee);
                    if (picked != null) {
                      setDialogState(() {
                        debut = picked;
                        if (!fin.isAfter(debut)) fin = debut.add(const Duration(hours: 1));
                      });
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Fin'),
                  subtitle: Text(_fmtDateTime(fin, touteJournee)),
                  trailing: const Icon(Icons.schedule),
                  onTap: () async {
                    final picked = await _pickDateTime(fin, touteJournee);
                    if (picked != null) setDialogState(() => fin = picked);
                  },
                ),
                if (selectedRecurrence != 'aucune' && selectedRecurrence != 'quotidien')
                  const Padding(
                    padding: EdgeInsets.only(top: 4, left: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('La date de début s\'aligne sur la récurrence ; l\'heure est conservée.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                if (titreCtrl.text.trim().isEmpty) return;
                final navigator = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(this.context);
                final provider = context.read<AlertesProvider>();
                bool ok;
                final e = _computeEcheances(selectedRecurrence, recurrenceConfig, debut, fin, touteJournee);
                if (alerte.automatique) {
                  // Automatic alerts are generated by rules; convert to a manual editable task.
                  ok = await provider.creerAlerte({
                    'titre': titreCtrl.text.trim(),
                    'message': messageCtrl.text.trim(),
                    'type': selectedType,
                    'priorite': selectedPriorite,
                    'recurrence': selectedRecurrence,
                    'recurrenceConfig': recurrenceConfig,
                    'dateEcheance': e.debut.toIso8601String(),
                    'dateFin': e.fin.toIso8601String(),
                    'touteJournee': touteJournee,
                    'source': 'todo',
                    'automatique': false,
                  });
                  if (ok) {
                    await provider.marquerFaite(alerte);
                  }
                } else {
                  ok = await provider.mettreAJourAlerte(
                    alerte.id!,
                    {
                      'titre': titreCtrl.text.trim(),
                      'message': messageCtrl.text.trim(),
                      'type': selectedType,
                      'priorite': selectedPriorite,
                      'recurrence': selectedRecurrence,
                      'recurrenceConfig': recurrenceConfig,
                      'dateEcheance': e.debut.toIso8601String(),
                      'dateFin': e.fin.toIso8601String(),
                      'touteJournee': touteJournee,
                    },
                  );
                }
                if (!mounted) return;
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(content: Text(ok
                      ? (alerte.automatique ? 'Alerte convertie en tâche modifiable' : 'Tâche modifiée')
                      : 'Erreur modification tâche')),
                );
              },
              child: Text(alerte.automatique ? 'Convertir en tâche' : 'Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
