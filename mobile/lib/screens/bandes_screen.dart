import 'package:flutter/material.dart';
import '../widgets/brand_logo.dart';
import '../widgets/add_button.dart';
import '../widgets/number_field.dart';
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
import '../widgets/status_pill.dart';

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
              icon: Icons.post_add,
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    bande.nom,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                StatusPill(
                  label: active ? 'Ouverte' : 'Fermée',
                  color: active ? Colors.green : Colors.red,
                  icon: active ? Icons.lock_open : Icons.lock_outline,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Race: ${bande.race}'),
            Text('Type: ${bande.typeVolaille}'),
            Row(
              children: [
                Icon(Icons.groups_outlined, size: 15, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text('Effectif: ${bande.nombreActuel}/${bande.nombreInitial}'),
              ],
            ),
            Row(
              children: [
                Icon(Icons.warning_amber_outlined, size: 15, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text('Mortalité: ${bande.mortaliteTotale} (${bande.tauxMortalite ?? "0"}%)'),
              ],
            ),
            Text('Ouverture: ${dateFormat.format(bande.dateOuverture)}'),
            if (!active && bande.dateFermeture != null)
              Text('Fermeture: ${dateFormat.format(bande.dateFermeture!)}'),
            if (active) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.start,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => SuiviScreen(bande: bande),
                      ));
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
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => BandeDashboardScreen(bande: bande),
                      ));
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
            if (!active && isAdmin) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: bande.id == null ? null : () => _confirmerSuppression(bande),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  label: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
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

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Ouvrir une nouvelle bande'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nomController, decoration: const InputDecoration(labelText: 'Nom de la bande *')),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  items: const [
                    DropdownMenuItem(value: 'poulet_chair', child: Text('Poulet de chair')),
                    DropdownMenuItem(value: 'poule_pondeuse', child: Text('Poule pondeuse')),
                    DropdownMenuItem(value: 'dinde', child: Text('Dinde')),
                    DropdownMenuItem(value: 'canard', child: Text('Canard')),
                    DropdownMenuItem(value: 'autre', child: Text('Autre')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedType = v!),
                  decoration: const InputDecoration(labelText: 'Type de volaille'),
                ),
                TextField(controller: raceController, decoration: const InputDecoration(labelText: 'Race *')),
                NumberField(controller: nombreController, label: 'Nombre de poussins *', decimal: false),
                NumberField(controller: poidsArriveeCtrl, label: 'Poids arrivée (g)'),
                NumberField(controller: objectifPoidsCtrl, label: 'Objectif poids (g)'),
                TextField(controller: batimentCtrl, decoration: const InputDecoration(labelText: 'Bâtiment')),
                if (protocoles.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: selectedProtocoleId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Protocole vaccinal (optionnel)',
                      helperText: 'Génère les tâches de suivi aux bonnes dates',
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
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date d\'ouverture'),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(dateOuverture)),
                  trailing: const Icon(Icons.calendar_today),
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
              ],
            ),
          ),
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
