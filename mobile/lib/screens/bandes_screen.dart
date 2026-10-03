import 'package:flutter/material.dart';
import '../widgets/brand_logo.dart';
import '../widgets/add_button.dart';
import '../widgets/number_field.dart';
import '../widgets/app_form.dart';
import '../widgets/form_section.dart';
import '../utils/number_input.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/bandes_provider.dart';
import '../providers/auth_provider.dart';
import '../models/bande.dart';
import '../services/api_service.dart';
import 'suivi_screen.dart';
import 'bande_dashboard_screen.dart';
import '../utils/csv_export.dart';
import '../widgets/iso_calendar_picker.dart';

class BandesScreen extends StatefulWidget {
  const BandesScreen({super.key});

  @override
  State<BandesScreen> createState() => _BandesScreenState();
}

class _BandesScreenState extends State<BandesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BandesProvider>().chargerBandesActives();
      context.read<BandesProvider>().chargerHistorique();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BrandLogo(),
        title: const Text('Gestion des Bandes'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: AddButton(
              tooltip: 'Nouvelle bande',
              icon: Icons.egg,
              onPressed: () => _showAjouterBandeDialog(),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Actives', icon: Icon(Icons.play_circle)),
            Tab(text: 'Historique', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBandesActives(),
          _buildHistorique(),
        ],
      ),
    );
  }

  Widget _buildBandesActives() {
    return Consumer<BandesProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.bandesActives.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.egg_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Aucune bande active', style: TextStyle(fontSize: 18, color: Colors.grey)),
                Text('Appuyez sur + pour ouvrir une bande'),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: provider.bandesActives.length,
          itemBuilder: (context, index) {
            return _buildBandeCard(provider.bandesActives[index], active: true);
          },
        );
      },
    );
  }

  Widget _buildHistorique() {
    return Consumer<BandesProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.bandesHistorique.isEmpty) {
          return const Center(
            child: Text('Aucune bande dans l\'historique', style: TextStyle(color: Colors.grey)),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => exportCsvToClipboard(
                  context,
                  loader: ApiService.exportBandesHistoriqueCsv,
                  label: 'Historique bandes',
                ),
                icon: const Icon(Icons.download_outlined),
                label: const Text('Exporter CSV'),
              ),
            ),
            const SizedBox(height: 8),
            ...provider.bandesHistorique.map((bande) => _buildBandeCard(bande, active: false)),
          ],
        );
      },
    );
  }

  Widget _buildBandeCard(Bande bande, {required bool active}) {
    final isAdmin = context.watch<AuthProvider>().isAdmin;
    final dateFormat = DateFormat('dd/MM/yyyy');
    final scheme = Theme.of(context).colorScheme;
    final headerColors = active
        ? [Colors.green.shade600, Colors.green.shade400]
        : [Colors.blueGrey.shade600, Colors.blueGrey.shade400];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête premium (dégradé) : nom + race/type + menu actions.
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: headerColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  child: const Icon(Icons.egg_alt, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bande.nom,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${bande.race} • ${bande.typeVolaille}',
                        style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.92)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(active ? Icons.lock_open : Icons.lock_outline, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(active ? 'Ouverte' : 'Fermée',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  tooltip: 'Options',
                  onSelected: (v) {
                    if (v == 'edit') _showModifierBandeDialog(bande);
                    if (v == 'delete') _confirmerSuppression(bande);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.edit_outlined), title: Text('Modifier')),
                    ),
                    if (!active && isAdmin)
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.delete_outline, color: Colors.redAccent),
                          title: Text('Supprimer', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _bandeMetric(Icons.groups_outlined, 'Effectif actuel',
                        '${bande.nombreActuel}/${bande.nombreInitial}', scheme.primary),
                    const SizedBox(width: 10),
                    _bandeMetric(Icons.warning_amber_outlined, 'Mortalité',
                        '${bande.mortaliteTotale} (${bande.tauxMortalite ?? "0"}%)', Colors.orange),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (bande.batiment.isNotEmpty) _bandeInfoChip(Icons.home_work_outlined, bande.batiment),
                    _bandeInfoChip(Icons.event_available_outlined, 'Ouverte le ${dateFormat.format(bande.dateOuverture)}'),
                    if (!active && bande.dateFermeture != null)
                      _bandeInfoChip(Icons.event_busy_outlined, 'Fermée le ${dateFormat.format(bande.dateFermeture!)}'),
                  ],
                ),
                if (active) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => SuiviScreen(bande: bande)));
                        },
                        style: ElevatedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        icon: const Icon(Icons.trending_up),
                        label: const Text('Suivi'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => BandeDashboardScreen(bande: bande)));
                        },
                        style: ElevatedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        icon: const Icon(Icons.insights),
                        label: const Text('Dashboard'),
                      ),
                      TextButton.icon(
                        onPressed: () => _confirmerFermeture(bande),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        icon: const Icon(Icons.stop_circle, color: Colors.red),
                        label: const Text('Fermer', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bandeMetric(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                  Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bandeInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  void _showModifierBandeDialog(Bande bande) {
    final nomCtrl = TextEditingController(text: bande.nom);
    final raceCtrl = TextEditingController(text: bande.race);
    final batimentCtrl = TextEditingController(text: bande.batiment);
    final objectifCtrl = TextEditingController(
      text: bande.objectifPoidsG > 0 ? bande.objectifPoidsG.toStringAsFixed(0) : '',
    );
    String selectedType = bande.typeVolaille.isNotEmpty ? bande.typeVolaille : 'poulet_chair';
    const types = ['poulet_chair', 'poulet_ameliore', 'poule_pondeuse', 'dinde', 'canard', 'autre'];
    if (!types.contains(selectedType)) selectedType = 'autre';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Modifier la bande'),
          content: AppFormBody([
            const FormSection('Identité', icon: Icons.pets),
            TextField(
              controller: nomCtrl,
              decoration: const InputDecoration(labelText: 'Nom de la bande *', prefixIcon: Icon(Icons.badge_outlined)),
            ),
            DropdownButtonFormField<String>(
              initialValue: selectedType,
              decoration: const InputDecoration(labelText: 'Type de volaille', prefixIcon: Icon(Icons.category_outlined)),
              items: const [
                DropdownMenuItem(value: 'poulet_chair', child: Text('Poulet de chair')),
                DropdownMenuItem(value: 'poulet_ameliore', child: Text('Poulet amélioré')),
                DropdownMenuItem(value: 'poule_pondeuse', child: Text('Poule pondeuse')),
                DropdownMenuItem(value: 'dinde', child: Text('Dinde')),
                DropdownMenuItem(value: 'canard', child: Text('Canard')),
                DropdownMenuItem(value: 'autre', child: Text('Autre')),
              ],
              onChanged: (v) => setDialogState(() => selectedType = v ?? selectedType),
            ),
            TextField(
              controller: raceCtrl,
              decoration: const InputDecoration(labelText: 'Race *', prefixIcon: Icon(Icons.pedal_bike_outlined)),
            ),
            const FormSection('Détails', icon: Icons.tune),
            TextField(
              controller: batimentCtrl,
              decoration: const InputDecoration(labelText: 'Bâtiment', prefixIcon: Icon(Icons.home_work_outlined)),
            ),
            NumberField(controller: objectifCtrl, label: 'Objectif poids (g)', prefixIcon: Icons.flag_outlined),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(dialogContext);
                final provider = context.read<BandesProvider>();
                if (nomCtrl.text.trim().isEmpty || raceCtrl.text.trim().isEmpty) {
                  messenger.showSnackBar(const SnackBar(content: Text('Nom et race obligatoires')));
                  return;
                }
                if (bande.id == null) return;
                final ok = await provider.modifierBande(bande.id!, {
                  'nom': nomCtrl.text.trim(),
                  'typeVolaille': selectedType,
                  'race': raceCtrl.text.trim(),
                  'batiment': batimentCtrl.text.trim(),
                  'objectifPoidsG': parseAmount(objectifCtrl.text) ?? 0,
                });
                if (!mounted) return;
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(content: Text(ok ? 'Bande modifiée' : 'Erreur: ${provider.lastError ?? ''}')),
                );
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmerFermeture(Bande bande) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fermer la bande ?'),
        content: Text('Voulez-vous vraiment fermer la bande "${bande.nom}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<BandesProvider>().fermerBande(bande.id!);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Fermer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmerSuppression(Bande bande) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la bande fermée ?'),
        content: Text('Cette action est irréversible. Supprimer définitivement "${bande.nom}" de l\'historique ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await context.read<BandesProvider>().supprimerBande(bande.id ?? '');
              if (!mounted) return;
              final provider = context.read<BandesProvider>();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok ? 'Bande supprimée' : 'Erreur suppression: ${provider.lastError ?? 'cause inconnue'}'),
                  backgroundColor: ok ? Colors.green : Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Protocole dont le type correspond au type de volaille, sinon un protocole "tous types".
  String? _protocolePourType(List<Map<String, dynamic>> protocoles, String type) {
    for (final p in protocoles) {
      if ((p['typeVolaille'] ?? '').toString() == type) return (p['_id'] ?? '').toString();
    }
    for (final p in protocoles) {
      if ((p['typeVolaille'] ?? '').toString().isEmpty) return (p['_id'] ?? '').toString();
    }
    return null;
  }

  void _showAjouterBandeDialog() async {
    final nomController = TextEditingController();
    final raceController = TextEditingController();
    final nombreController = TextEditingController();
    final poidsArriveeCtrl = TextEditingController();
    final objectifPoidsCtrl = TextEditingController();
    final batimentCtrl = TextEditingController();
    String selectedType = 'poulet_chair';
    DateTime dateOuverture = DateTime.now();
    String? selectedProtocoleId;

    // Charge les protocoles vaccinaux disponibles pour l'auto-planification.
    List<Map<String, dynamic>> protocoles = const [];
    try {
      final data = await ApiService.getProtocoles();
      protocoles = data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      protocoles = const [];
    }
    if (!mounted) return;
    // Pré-sélectionne le protocole correspondant au type par défaut.
    selectedProtocoleId = _protocolePourType(protocoles, selectedType);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Ouvrir une nouvelle bande'),
          content: AppFormBody([
            const FormSection('Identité', icon: Icons.pets),
            TextField(
              controller: nomController,
              decoration: const InputDecoration(
                labelText: 'Nom de la bande *',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            DropdownButtonFormField<String>(
              initialValue: selectedType,
              decoration: const InputDecoration(
                labelText: 'Type de volaille',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 'poulet_chair', child: Text('Poulet de chair')),
                DropdownMenuItem(value: 'poulet_ameliore', child: Text('Poulet amélioré')),
                DropdownMenuItem(value: 'poule_pondeuse', child: Text('Poule pondeuse')),
                DropdownMenuItem(value: 'dinde', child: Text('Dinde')),
                DropdownMenuItem(value: 'canard', child: Text('Canard')),
                DropdownMenuItem(value: 'autre', child: Text('Autre')),
              ],
              onChanged: (v) => setDialogState(() {
                selectedType = v!;
                // Le protocole s'aligne automatiquement sur le type choisi.
                selectedProtocoleId = _protocolePourType(protocoles, selectedType);
              }),
            ),
            TextField(
              controller: raceController,
              decoration: const InputDecoration(
                labelText: 'Race *',
                prefixIcon: Icon(Icons.pedal_bike_outlined),
              ),
            ),
            const FormSection('Effectif & objectifs', icon: Icons.numbers),
            NumberField(
              controller: nombreController,
              label: 'Nombre de poussins *',
              decimal: false,
              prefixIcon: Icons.groups_outlined,
            ),
            NumberField(
              controller: poidsArriveeCtrl,
              label: 'Poids arrivée (g)',
              prefixIcon: Icons.monitor_weight_outlined,
            ),
            NumberField(
              controller: objectifPoidsCtrl,
              label: 'Objectif poids (g)',
              prefixIcon: Icons.flag_outlined,
            ),
            TextField(
              controller: batimentCtrl,
              decoration: const InputDecoration(
                labelText: 'Bâtiment',
                prefixIcon: Icon(Icons.home_work_outlined),
              ),
            ),
            const FormSection('Planification', icon: Icons.event_available),
            if (protocoles.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: selectedProtocoleId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Protocole vaccinal (optionnel)',
                  prefixIcon: Icon(Icons.vaccines_outlined),
                  helperText: 'Pré-sélectionné selon le type • génère les tâches aux bonnes dates',
                ),
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('Aucun')),
                  ...protocoles.map((p) {
                    final id = (p['_id'] ?? '').toString();
                    final nom = (p['nom'] ?? 'Protocole').toString();
                    final nb = (p['etapes'] is List) ? (p['etapes'] as List).length : 0;
                    return DropdownMenuItem<String>(value: id, child: Text('$nom ($nb étapes)', overflow: TextOverflow.ellipsis));
                  }),
                ],
                onChanged: (v) => setDialogState(() => selectedProtocoleId = v),
              ),
            FormDateTile(
              label: 'Date d\'ouverture',
              value: DateFormat('dd/MM/yyyy').format(dateOuverture),
              onTap: () async {
                final picked = await showIsoDatePicker(
                  context: dialogContext,
                  initialDate: dateOuverture,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  setDialogState(() {
                    dateOuverture = picked;
                  });
                }
              },
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                if (nomController.text.isEmpty || raceController.text.isEmpty || nombreController.text.isEmpty) return;
                Navigator.pop(ctx);
                final success = await context.read<BandesProvider>().ouvrirBande({
                  'nom': nomController.text,
                  'typeVolaille': selectedType,
                  'race': raceController.text,
                  'nombreInitial': parseInteger(nombreController.text) ?? 0,
                  'poidsArriveeG': parseAmount(poidsArriveeCtrl.text) ?? 0,
                  'objectifPoidsG': parseAmount(objectifPoidsCtrl.text) ?? 0,
                  'batiment': batimentCtrl.text,
                  'dateOuverture': dateOuverture.toIso8601String(),
                  if (selectedProtocoleId != null && selectedProtocoleId!.isNotEmpty) 'protocoleId': selectedProtocoleId,
                });
                if (!mounted) return;
                if (!success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Maximum 5 bandes ouvertes en parallèle')),
                  );
                }
              },
              child: const Text('Ouvrir'),
            ),
          ],
        ),
      ),
    );
  }
}
