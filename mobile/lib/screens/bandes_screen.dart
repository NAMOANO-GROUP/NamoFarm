import 'package:flutter/material.dart';
import '../widgets/brand_logo.dart';
import '../widgets/add_button.dart';
import '../widgets/number_field.dart';
import '../widgets/app_form.dart';
import '../widgets/form_section.dart';
import '../widgets/empty_state.dart';
import '../widgets/bandes/bande_widgets.dart';
import '../utils/number_input.dart';
import '../utils/bande_kpis.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/alertes_provider.dart';
import '../providers/bandes_provider.dart';
import '../providers/auth_provider.dart';
import '../models/bande.dart';
import '../services/api_service.dart';
import '../services/references_service.dart';
import 'bandes/bande_actions.dart';
import 'bandes/bande_detail_screen.dart';
import 'bandes/bandes_comparaison_view.dart';
import '../utils/csv_export.dart';
import '../widgets/iso_calendar_picker.dart';

class BandesScreen extends StatefulWidget {
  const BandesScreen({super.key});

  @override
  State<BandesScreen> createState() => _BandesScreenState();
}

class _BandesScreenState extends State<BandesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, ReferenceType> _refs = Map.of(defaultReferences);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    ReferencesService.charger().then((r) {
      if (mounted) setState(() => _refs = r);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BandesProvider>().chargerBandesActives();
      context.read<BandesProvider>().chargerHistorique();
      final alertes = context.read<AlertesProvider>();
      if (alertes.alertes.isEmpty) alertes.chargerAlertes(period: 'all');
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  BandeKpis _kpis(Bande b) => computeBandeKpis(b, referencePour(_refs, b.typeVolaille));

  void _ouvrir(Bande b) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => BandeDetailScreen(bande: b)));
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
            Tab(text: 'Comparer', icon: Icon(Icons.compare_arrows)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBandesActives(),
          _buildHistorique(),
          Consumer<BandesProvider>(
            builder: (context, provider, _) => BandesComparaisonView(
              bandes: [...provider.bandesActives, ...provider.bandesHistorique],
              references: _refs,
              onOpen: _ouvrir,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBandesActives() {
    return Consumer2<BandesProvider, AlertesProvider>(
      builder: (context, provider, alertes, child) {
        if (provider.isLoading && provider.bandesActives.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.bandesActives.isEmpty) {
          return EmptyState(
            icon: Icons.egg_outlined,
            title: 'Aucune bande active',
            subtitle: 'Ouvrez une bande pour suivre sa croissance, son alimentation et sa rentabilité.',
            actionLabel: 'Nouvelle bande',
            onAction: _showAjouterBandeDialog,
          );
        }
        final kpis = {for (final b in provider.bandesActives) b.id: _kpis(b)};
        final resume = resumeBandes(provider.bandesActives, {for (final e in kpis.entries) if (e.key != null) e.key!: e.value});
        return RefreshIndicator(
          onRefresh: () => Future.wait([provider.chargerBandesActives(), alertes.chargerAlertes(period: 'all')]),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _Resume(resume: resume),
              const SizedBox(height: 12),
              for (final b in provider.bandesActives)
                BandeCard(
                  bande: b,
                  kpis: kpis[b.id]!,
                  prochaineTache: prochaineTachePour(b, alertes.alertes),
                  onOpen: () => _ouvrir(b),
                  onSaisie: (s) => ouvrirSaisie(context, b, s),
                  menuItems: const [
                    PopupMenuItem(value: 'edit', child: Text('Modifier')),
                    PopupMenuItem(value: 'fermer', child: Text('Fermer la bande')),
                  ],
                  onMenu: (v) {
                    if (v == 'edit') _showModifierBandeDialog(b);
                    if (v == 'fermer') fermerBandeAvecBilan(context, b, referencePour(_refs, b.typeVolaille));
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistorique() {
    return Consumer<BandesProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.bandesHistorique.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.bandesHistorique.isEmpty) {
          return const EmptyState(
            icon: Icons.history,
            title: 'Aucune bande dans l’historique',
            subtitle: 'Les bandes fermées apparaîtront ici avec leurs résultats.',
          );
        }
        final isAdmin = context.watch<AuthProvider>().isAdmin;
        return ListView(
          padding: const EdgeInsets.all(12),
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
            for (final b in provider.bandesHistorique)
              BandeCard(
                bande: b,
                kpis: _kpis(b),
                onOpen: () => _ouvrir(b),
                menuItems: [
                  const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                  if (isAdmin) const PopupMenuItem(value: 'delete', child: Text('Supprimer', style: TextStyle(color: Colors.redAccent))),
                ],
                onMenu: (v) {
                  if (v == 'edit') _showModifierBandeDialog(b);
                  if (v == 'delete') _confirmerSuppression(b);
                },
              ),
          ],
        );
      },
    );
  }

  void _showModifierBandeDialog(Bande bande) {
    final nomCtrl = TextEditingController(text: bande.nom);
    final raceCtrl = TextEditingController(text: bande.race);
    final batimentCtrl = TextEditingController(text: bande.batiment);
    final objectifCtrl = TextEditingController(
      text: bande.objectifPoidsG > 0 ? bande.objectifPoidsG.toStringAsFixed(0) : '',
    );
    String selectedType = bande.typeVolaille.isNotEmpty ? bande.typeVolaille : 'poulet_ameliore_45j';
    const types = ['poulet_ameliore_45j', 'poulet_local_ameliore', 'poulet_ameliore', 'poulet_local', 'poule_pondeuse', 'canard', 'dinde', 'autre'];
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
                DropdownMenuItem(value: 'poulet_ameliore_45j', child: Text('Poulet amélioré 45J')),
                DropdownMenuItem(value: 'poulet_local_ameliore', child: Text('Poulet local amélioré')),
                DropdownMenuItem(value: 'poulet_ameliore', child: Text('Poulet amélioré')),
                DropdownMenuItem(value: 'poulet_local', child: Text('Poulet local')),
                DropdownMenuItem(value: 'poule_pondeuse', child: Text('Poule pondeuse')),
                DropdownMenuItem(value: 'canard', child: Text('Canard')),
                DropdownMenuItem(value: 'dinde', child: Text('Dinde')),
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
    String selectedType = 'poulet_ameliore_45j';
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
                DropdownMenuItem(value: 'poulet_ameliore_45j', child: Text('Poulet amélioré 45J')),
                DropdownMenuItem(value: 'poulet_local_ameliore', child: Text('Poulet local amélioré')),
                DropdownMenuItem(value: 'poulet_ameliore', child: Text('Poulet amélioré')),
                DropdownMenuItem(value: 'poulet_local', child: Text('Poulet local')),
                DropdownMenuItem(value: 'poule_pondeuse', child: Text('Poule pondeuse')),
                DropdownMenuItem(value: 'canard', child: Text('Canard')),
                DropdownMenuItem(value: 'dinde', child: Text('Dinde')),
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

/// Synthèse des bandes actives (en tête de liste).
class _Resume extends StatelessWidget {
  final ResumeBandes resume;
  const _Resume({required this.resume});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.egg_alt_outlined, '${resume.nbBandes}', 'bande(s) active(s)', Colors.green),
      (Icons.groups_outlined, fmtEntier(resume.effectifTotal), 'sujets en élevage', Colors.teal),
      (Icons.local_shipping_outlined, '${resume.sortiesProchaines}', 'sortie(s) sous 14 j', Colors.indigo),
      (Icons.warning_amber_rounded, '${resume.nbAlertes}', 'alerte(s)', resume.nbAlertes > 0 ? Colors.red : Colors.blueGrey),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 700 ? 4 : 2;
        final w = (c.maxWidth - (cols - 1) * 8) / cols;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final it in items)
              SizedBox(
                width: w,
                child: KpiTile(label: it.$3, value: it.$2, icon: it.$1, color: it.$4, width: w),
              ),
          ],
        );
      },
    );
  }
}
