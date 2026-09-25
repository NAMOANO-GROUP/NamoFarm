import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/bandes_provider.dart';
import '../models/bande.dart';
import '../services/api_service.dart';
import 'alimentation_screen.dart';
import 'poids_screen.dart';
import 'climat_screen.dart';
import 'mortalite_screen.dart';
import '../widgets/iso_calendar_picker.dart';
import '../widgets/stat_tile.dart';
import '../widgets/number_field.dart';
import '../widgets/async_button.dart';
import '../utils/number_input.dart';

class SuiviScreen extends StatefulWidget {
  final Bande bande;
  const SuiviScreen({super.key, required this.bande});

  @override
  State<SuiviScreen> createState() => _SuiviScreenState();
}

class _SuiviScreenState extends State<SuiviScreen> {
  List<Map<String, dynamic>> _stocksProphylaxie = [];

  Map<String, dynamic>? _dashboardData;
  bool _loadingForecast = true;
  List<EvenementPrevisionnel> _eventsPrevisionnels = [];
  bool _loadingEvents = true;
  bool _showEvents = false;

  @override
  void initState() {
    super.initState();
    _loadForecast();
    _loadEvents();
    _loadStocks();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadStocks() async {
    try {
      final data = await ApiService.getStocks();
      if (!mounted) return;

      final normalized = data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final prophylaxie = normalized
          .where((s) => (s['categorie'] ?? '').toString() != 'aliment' && (s['categorie'] ?? '').toString() != 'materiel')
          .toList();

      setState(() {
        _stocksProphylaxie = prophylaxie;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _stocksProphylaxie = [];
      });
    }
  }

  String _stockNameById(List<Map<String, dynamic>> list, String? id) {
    if (id == null || id.isEmpty) return '';
    for (final s in list) {
      if (s['_id']?.toString() == id) {
        return (s['nom'] ?? '').toString();
      }
    }
    return '';
  }

  Future<void> _loadForecast() async {
    try {
      final data = await ApiService.getSuiviDashboardBande(widget.bande.id!);
      if (!mounted) return;
      setState(() {
        _dashboardData = data;
        _loadingForecast = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _dashboardData = null;
        _loadingForecast = false;
      });
    }
  }

  Future<void> _loadEvents() async {
    try {
      final data = await ApiService.getEvenementsPrevisionnels(widget.bande.id!);
      if (!mounted) return;
      setState(() {
        _eventsPrevisionnels = data.map((e) => EvenementPrevisionnel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
        _loadingEvents = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _eventsPrevisionnels = [];
        _loadingEvents = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final bande = widget.bande;

    return Scaffold(
      appBar: AppBar(
        title: Text('Suivi bande - ${bande.nom}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.event_note),
            tooltip: 'Planifier événement',
            onPressed: _showPlanifierEvenementDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // RÉSUMÉ
            Card(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.green.shade900.withValues(alpha: 0.30)
                  : Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Résumé', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _statRow('Âge', '${bande.ageJours ?? _calcAge(bande)} jours'),
                    _statRow('Effectif actuel', '${bande.nombreActuel}'),
                    _statRow('Mortalité totale', '${bande.mortaliteTotale} (${bande.tauxMortalite ?? "0"}%)'),
                    _statRow('Race', bande.race),
                    _statRow('Type', _typeLabel(bande.typeVolaille)),
                    _statRow('Bâtiment', bande.batiment.isEmpty ? '-' : bande.batiment),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildEventsPrevisionnels(),
            const SizedBox(height: 16),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => PoidsScreen(bande: bande)));
                  },
                  icon: const Icon(Icons.monitor_weight),
                  label: const Text('Prise de poids'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => AlimentationScreen(bande: bande)));
                    if (!mounted) return;
                    await _loadForecast();
                  },
                  icon: const Icon(Icons.restaurant),
                  label: const Text('Suivi alimentation'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => MortaliteScreen(bande: bande)));
                    if (!mounted) return;
                    await _loadForecast();
                  },
                  icon: const Icon(Icons.health_and_safety),
                  label: const Text('Mortalité'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ClimatScreen(bande: bande)));
                  },
                  icon: const Icon(Icons.thermostat),
                  label: const Text('Température/Humidité'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 8),

            // SUIVI JOURNALIER (replié par défaut)
            Card(
              child: ExpansionTile(
                initiallyExpanded: false,
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                title: Text('Suivi journalier', style: Theme.of(context).textTheme.titleMedium),
                subtitle: Text('${bande.suiviJournalier.length} entrée(s)', style: const TextStyle(color: Colors.grey)),
                children: [
                  if (bande.suiviJournalier.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('Aucun suivi enregistré', style: TextStyle(color: Colors.grey))),
                    )
                  else
                    ...bande.suiviJournalier.reversed.map((suivi) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).brightness == Brightness.dark
                            ? Colors.green.shade900.withValues(alpha: 0.45)
                            : Colors.green.shade100,
                        child: Text('J${_ageJour(suivi.date)}',
                            style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.green.shade200 : Colors.green.shade800,
                              fontWeight: FontWeight.bold,
                            )),
                      ),
                      title: Text(dateFormat.format(suivi.date)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Poids: ${suivi.poidsMotenG}g | Alim: ${suivi.alimentationKg}kg | Eau: ${suivi.eauLitres}L'),
                          if (suivi.mortaliteJour > 0)
                            Text('Mortalité: ${suivi.mortaliteJour}', style: const TextStyle(color: Colors.red)),
                          if (suivi.observations.isNotEmpty)
                            Text(suivi.observations, style: const TextStyle(fontStyle: FontStyle.italic)),
                        ],
                      ),
                      isThreeLine: true,
                    )),
                ],
              ),
            ),

            const SizedBox(height: 24),
            _buildForecastCard(),

          ],
        ),
      ),
    );
  }

  Widget _buildEventsPrevisionnels() {
    final pending = _eventsPrevisionnels.where((e) => e.statut != 'termine').toList();
    final df = DateFormat('dd/MM/yyyy');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.event_available_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Événements prévisionnels', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        if (_loadingEvents)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (pending.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Aucune tâche planifiée à venir'),
            ),
          )
        else
          Card(
            child: ExpansionTile(
              initiallyExpanded: _showEvents,
              onExpansionChanged: (expanded) => setState(() => _showEvents = expanded),
              leading: const Icon(Icons.event, color: Colors.orange),
              title: Text('Tâches planifiées (${pending.length})'),
              children: pending.map((evt) {
                return ListTile(
                  leading: const Icon(Icons.event, color: Colors.orange),
                  title: Text(evt.description),
                  subtitle: Text('Prévu le ${df.format(evt.datePrevue)} • ${evt.priorite}'),
                  trailing: TextButton(
                    onPressed: () => _terminerEvenement(evt),
                    child: const Text('Terminer'),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  void _showPlanifierEvenementDialog() {
    final descCtrl = TextEditingController();
    final comCtrl = TextEditingController();
    final prophylaxieQteCtrl = TextEditingController();
    String type = 'vaccination';
    String priorite = 'moyenne';
    DateTime datePrevue = DateTime.now().add(const Duration(days: 1));
    String? prophylaxieStockId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Planifier un événement'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'vaccination', child: Text('Vaccination')),
                    DropdownMenuItem(value: 'traitement', child: Text('Traitement')),
                    DropdownMenuItem(value: 'controle_sanitaire', child: Text('Contrôle sanitaire')),
                    DropdownMenuItem(value: 'pesee', child: Text('Pesée')),
                    DropdownMenuItem(value: 'intervention_diverse', child: Text('Intervention diverse')),
                  ],
                  onChanged: (v) => setDialogState(() => type = v ?? 'vaccination'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date prévue'),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(datePrevue)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final d = await showIsoDatePicker(
                      context: dialogContext,
                      initialDate: datePrevue,
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) setDialogState(() => datePrevue = d);
                  },
                ),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description *')),
                DropdownButtonFormField<String>(
                  initialValue: priorite,
                  decoration: const InputDecoration(labelText: 'Priorité'),
                  items: const [
                    DropdownMenuItem(value: 'basse', child: Text('Basse')),
                    DropdownMenuItem(value: 'moyenne', child: Text('Moyenne')),
                    DropdownMenuItem(value: 'haute', child: Text('Haute')),
                    DropdownMenuItem(value: 'urgente', child: Text('Urgente')),
                  ],
                  onChanged: (v) => setDialogState(() => priorite = v ?? 'moyenne'),
                ),
                TextField(
                  controller: comCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Commentaires'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: prophylaxieStockId,
                  items: [
                    const DropdownMenuItem<String>(value: '', child: Text('Aucun consommable prophylaxie')),
                    ..._stocksProphylaxie.map(
                      (s) => DropdownMenuItem<String>(
                        value: s['_id']?.toString(),
                        child: Text('${s['nom']} (${s['quantiteActuelle']} ${s['unite']})'),
                      ),
                    ),
                  ],
                  onChanged: (v) => setDialogState(() => prophylaxieStockId = (v == null || v.isEmpty) ? null : v),
                  decoration: const InputDecoration(labelText: 'Consommable prophylaxie lié (optionnel)'),
                ),
                NumberField(
                  controller: prophylaxieQteCtrl,
                  label: 'Quantité prophylaxie prévue (optionnel)',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
            AsyncButton(
              label: const Text('Planifier'),
              onPressed: () async {
                if (widget.bande.id == null || widget.bande.id!.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bande introuvable, recharge la liste des bandes')),
                  );
                  return;
                }
                if (descCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Description obligatoire pour planifier un événement')),
                  );
                  return;
                }
                final prophylaxieQte = parseAmount(prophylaxieQteCtrl.text) ?? 0;
                if (prophylaxieStockId != null && prophylaxieQte <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Renseigne une quantité prophylaxie > 0 ou enlève le consommable sélectionné')),
                  );
                  return;
                }
                if (prophylaxieStockId == null && prophylaxieQte > 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sélectionne un consommable prophylaxie avant de saisir la quantité')),
                  );
                  return;
                }
                final provider = context.read<BandesProvider>();
                final navigator = Navigator.of(dialogContext);
                final messenger = ScaffoldMessenger.of(context);
                final prophylaxieType = _stockNameById(_stocksProphylaxie, prophylaxieStockId);
                final ok = await provider.ajouterEvenementPrevisionnel(widget.bande.id!, {
                  'type': type,
                  'datePrevue': datePrevue.toIso8601String(),
                  'description': descCtrl.text.trim(),
                  'priorite': priorite,
                  'commentaires': comCtrl.text.trim(),
                  'prophylaxieStockId': prophylaxieStockId,
                  'prophylaxieType': prophylaxieType,
                  'prophylaxieQuantite': prophylaxieQte,
                });
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(content: Text(ok ? 'Événement planifié' : 'Erreur planification: ${provider.lastError ?? 'cause inconnue'}')),
                );
                if (ok) {
                  _loadEvents();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _terminerEvenement(EvenementPrevisionnel evt) async {
    if (widget.bande.id == null || widget.bande.id!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bande introuvable, recharge la liste des bandes')),
      );
      return;
    }
    if (evt.id == null || evt.id!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Événement invalide, recharge les événements prévisionnels')),
      );
      return;
    }

    final commentaireCtrl = TextEditingController();
    String? prophylaxieStockId = evt.prophylaxieStockId;
    final prophylaxieQteCtrl = TextEditingController(
      text: evt.prophylaxieQuantite > 0 ? evt.prophylaxieQuantite.toString() : '',
    );

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Marquer comme terminé'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: commentaireCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Commentaires de réalisation'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: prophylaxieStockId,
                  items: [
                    const DropdownMenuItem<String>(value: '', child: Text('Aucun consommable prophylaxie')),
                    ..._stocksProphylaxie.map(
                      (s) => DropdownMenuItem<String>(
                        value: s['_id']?.toString(),
                        child: Text('${s['nom']} (${s['quantiteActuelle']} ${s['unite']})'),
                      ),
                    ),
                  ],
                  onChanged: (v) => setDialogState(() => prophylaxieStockId = (v == null || v.isEmpty) ? null : v),
                  decoration: const InputDecoration(labelText: 'Consommable prophylaxie utilisé (optionnel)'),
                ),
                NumberField(
                  controller: prophylaxieQteCtrl,
                  label: 'Quantité prophylaxie consommée (optionnel)',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            AsyncButton(
              label: const Text('Confirmer'),
              onPressed: () async {
                final prophylaxieQte = parseAmount(prophylaxieQteCtrl.text) ?? 0;
                if (prophylaxieStockId != null && prophylaxieQte <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Renseigne une quantité prophylaxie > 0 ou enlève le consommable sélectionné')),
                  );
                  return;
                }
                if (prophylaxieStockId == null && prophylaxieQte > 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sélectionne un consommable prophylaxie avant de saisir la quantité')),
                  );
                  return;
                }

                final provider = context.read<BandesProvider>();
                final navigator = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                final ok = await provider.terminerEvenementPrevisionnel(
                      widget.bande.id!,
                      evt.id!,
                      commentairesRealisation: commentaireCtrl.text.trim(),
                      prophylaxieStockId: prophylaxieStockId,
                      prophylaxieType: _stockNameById(_stocksProphylaxie, prophylaxieStockId),
                      prophylaxieQuantite: prophylaxieQte,
                    );
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(content: Text(ok ? 'Événement terminé' : 'Erreur mise à jour événement: ${provider.lastError ?? 'cause inconnue'}')),
                );
                if (ok) {
                  _loadEvents();
                  _loadStocks();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForecastCard() {
    if (_loadingForecast) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 10),
              Text('Chargement du prévisionnel...'),
            ],
          ),
        ),
      );
    }

    final forecast = (_dashboardData?['forecast7j'] as List<dynamic>?) ?? const [];
    final events = (_dashboardData?['eventsPrevisionnels'] as List<dynamic>?) ?? const [];
    final horizon = forecast.isNotEmpty ? forecast.last as Map<String, dynamic> : null;
    final consoReelle = (_dashboardData?['conso'] as List<dynamic>?) ?? const [];
    final consoTheorique = (_dashboardData?['theoriqueConso'] as List<dynamic>?) ?? const [];
    final consoReelleCourante = consoReelle.isNotEmpty
        ? ((consoReelle.last as Map<String, dynamic>)['cumulKg'] as num?)?.toDouble() ?? 0
        : 0;
    final ageCourant = consoReelle.length;
    double consoTheoriqueCourante = 0;
    if (ageCourant > 0 && consoTheorique.isNotEmpty) {
      final row = consoTheorique.whereType<Map<String, dynamic>>().firstWhere(
            (e) => (e['age'] ?? 0) == ageCourant,
            orElse: () => consoTheorique.last as Map<String, dynamic>,
          );
      consoTheoriqueCourante = ((row['cumulKg'] ?? 0) as num).toDouble();
    }
    final ratioReelTheorique = consoTheoriqueCourante > 0
        ? consoReelleCourante / consoTheoriqueCourante
        : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights_outlined, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text('Prévisionnel 7 jours', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            if (horizon != null)
              Row(
                children: [
                  _forecastStat('Poids projeté', '${_fmt(horizon['poidsProjete'], digits: 0)} g', Icons.monitor_weight_outlined, Colors.green),
                  _forecastStat('Conso cumulée', '${_fmt(horizon['consoCumulProjeteeKg'])} kg', Icons.restaurant, Colors.brown),
                  _forecastStat('Mortalité/j', _fmt(horizon['mortaliteJourProjetee']), Icons.warning_amber_outlined, Colors.red),
                ],
              )
            else
              Text('Pas assez de données pour une prévision fiable.', style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            // Ratio conso réel/théorique : > 1 = surconsommation (orange), sinon vert.
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (ratioReelTheorique > 1.1 ? Colors.orange : Colors.green).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: (ratioReelTheorique > 1.1 ? Colors.orange : Colors.green).withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(
                    ratioReelTheorique > 1.1 ? Icons.trending_up : Icons.check_circle_outline,
                    size: 18,
                    color: ratioReelTheorique > 1.1 ? Colors.orange.shade800 : Colors.green.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Conso réel/théorique: ${_fmt(consoReelleCourante)} / ${_fmt(consoTheoriqueCourante)} kg (ratio ${_fmt(ratioReelTheorique)})',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            if (events.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Alertes prévisionnelles', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700, fontSize: 13)),
              const SizedBox(height: 6),
              ...events.map((evt) {
                final e = evt as Map<String, dynamic>;
                final sev = (e['severite'] ?? '').toString();
                final color = sev == 'haute' ? Colors.red : Colors.orange;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border(left: BorderSide(color: color, width: 3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: color, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text((e['message'] ?? '').toString(), style: const TextStyle(fontSize: 12.5))),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _forecastStat(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(dynamic value, {int digits = 2}) {
    if (value is num) return value.toStringAsFixed(digits);
    return '0';
  }

  int _calcAge(Bande bande) {
    return DateTime.now().difference(bande.dateOuverture).inDays;
  }

  // Âge (en jours) des sujets à la date d'une entrée de suivi = jours depuis l'ouverture.
  int _ageJour(DateTime d) {
    final a = DateUtils.dateOnly(d).difference(DateUtils.dateOnly(widget.bande.dateOuverture)).inDays;
    return a < 0 ? 0 : a;
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'poulet_chair': return 'Poulet de chair';
      case 'poule_pondeuse': return 'Poule pondeuse';
      case 'dinde': return 'Dinde';
      case 'canard': return 'Canard';
      default: return type;
    }
  }

  Widget _statRow(String label, String value) {
    return StatRow(label, value);
  }
}
