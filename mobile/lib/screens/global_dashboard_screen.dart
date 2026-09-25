import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/dashboard_provider.dart';
import '../services/api_service.dart';
import '../utils/csv_export.dart';
import '../utils/money_format.dart';
import '../widgets/brand_logo.dart';
import 'tendance_screen.dart';
import 'bande_bilan_screen.dart';

class GlobalDashboardScreen extends StatefulWidget {
  const GlobalDashboardScreen({super.key});

  @override
  State<GlobalDashboardScreen> createState() => _GlobalDashboardScreenState();
}

class _GlobalDashboardScreenState extends State<GlobalDashboardScreen> {
  static const List<String> _moisFr = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ];

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _bandes = [];
  Map<String, dynamic> _totaux = {};
  Map<String, dynamic> _global = {}; // Totaux ferme-wide (toutes ventes/depenses, all-time).

  int? _filtreAnnee; // null = toutes
  int? _filtreMois; // null = tous

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().chargerDashboards();
    });
    _chargerAnalytique();
  }

  Future<void> _chargerAnalytique() async {
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
      // Totaux de toute la ferme (all-time) : toutes les ventes et dépenses, pas seulement par bande.
      Map<String, dynamic> global = {};
      try {
        global = await ApiService.getGlobalDashboard(
          dateFrom: DateTime(2000, 1, 1),
          dateTo: DateTime.now(),
        );
      } catch (_) {
        global = {};
      }
      if (!mounted) return;
      setState(() {
        _bandes = bandes;
        _totaux = Map<String, dynamic>.from(data['totaux'] ?? {});
        _global = global;
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

  DateTime? _dateOuverture(Map<String, dynamic> b) => DateTime.tryParse((b['dateOuverture'] ?? '').toString());

  List<Map<String, dynamic>> get _bandesActives {
    return _bandes.where((b) {
      if ((b['statut'] ?? '').toString() != 'ouverte') return false;
      final d = _dateOuverture(b);
      if (_filtreAnnee != null && (d == null || d.year != _filtreAnnee)) return false;
      if (_filtreMois != null && (d == null || d.month != _filtreMois)) return false;
      return true;
    }).toList()
      ..sort((a, b) => (_dateOuverture(b) ?? DateTime(2000)).compareTo(_dateOuverture(a) ?? DateTime(2000)));
  }

  List<int> get _anneesDispo {
    final years = _bandes
        .where((b) => (b['statut'] ?? '').toString() == 'ouverte')
        .map((b) => _dateOuverture(b)?.year)
        .whereType<int>()
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    return years;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BrandLogo(),
        title: const Text('Tableau de Bord Global'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Rapport',
            onPressed: _showExportLinks,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _chargerAnalytique();
                if (mounted) await context.read<DashboardProvider>().chargerDashboards();
              },
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (_error != null && _error!.isNotEmpty)
                    Card(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.red.shade900.withValues(alpha: 0.30)
                          : Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _error!,
                          style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.red.shade200 : Colors.red),
                        ),
                      ),
                    ),
                  _sectionTitle('Bandes actives', Icons.egg_outlined),
                  const SizedBox(height: 8),
                  _bandesFiltres(),
                  const SizedBox(height: 8),
                  _bandesListe(),
                  const SizedBox(height: 20),
                  _boutonsTendance(),
                  const SizedBox(height: 20),
                  _sectionTitle('CRM & Commercial', Icons.people_outline),
                  const SizedBox(height: 8),
                  Consumer<DashboardProvider>(builder: (_, provider, __) => _crmBloc(provider)),
                  const SizedBox(height: 20),
                  _sectionTitle('Totaux globaux', Icons.summarize_outlined),
                  const SizedBox(height: 8),
                  _totauxBloc(),
                  const SizedBox(height: 12),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _bandesFiltres() {
    final annees = _anneesDispo;
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int?>(
            initialValue: _filtreAnnee,
            isDense: true,
            decoration: const InputDecoration(labelText: 'Année', isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Toutes')),
              ...annees.map((y) => DropdownMenuItem<int?>(value: y, child: Text('$y'))),
            ],
            onChanged: (v) => setState(() => _filtreAnnee = v),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonFormField<int?>(
            initialValue: _filtreMois,
            isDense: true,
            decoration: const InputDecoration(labelText: 'Mois', isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Tous')),
              for (var i = 1; i <= 12; i++) DropdownMenuItem<int?>(value: i, child: Text(_moisFr[i - 1])),
            ],
            onChanged: (v) => setState(() => _filtreMois = v),
          ),
        ),
      ],
    );
  }

  Widget _bandesListe() {
    final bandes = _bandesActives;
    if (bandes.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text('Aucune bande active pour ce filtre', style: TextStyle(color: Colors.grey))),
        ),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        // Zone scrollable : la liste défile même avec de nombreuses bandes.
        constraints: const BoxConstraints(maxHeight: 320),
        child: Scrollbar(
          child: ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: bandes.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => _bandeTile(bandes[i]),
          ),
        ),
      ),
    );
  }

  Widget _bandeTile(Map<String, dynamic> b) {
    final marge = _n(b['margeNette']);
    final positif = marge >= 0;
    final color = positif ? Colors.green : Colors.red;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final d = _dateOuverture(b);
    final effectif = _n(b['effectifVivant']).toStringAsFixed(0);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: isDark ? 0.25 : 0.15),
        child: Icon(positif ? Icons.trending_up : Icons.trending_down,
            color: isDark ? (positif ? Colors.green.shade300 : Colors.red.shade300) : (positif ? Colors.green.shade700 : Colors.red)),
      ),
      title: Text((b['bandeNom'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('$effectif sujets${d != null ? ' • ouverte le ${DateFormat('dd/MM/yyyy').format(d)}' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(formatCompactFcfa(marge),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: positif
                    ? (isDark ? Colors.green.shade300 : Colors.green.shade700)
                    : (isDark ? Colors.red.shade300 : Colors.red),
                fontSize: 13,
              )),
          const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
        ],
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => BandeBilanScreen(bande: b)),
      ),
    );
  }

  Widget _boutonsTendance() {
    return Row(
      children: [
        Expanded(
          child: _tendanceCard(
            'Tendance des ventes',
            Icons.trending_up,
            const [Color(0xFF0B5D3B), Color(0xFF2E7D32)],
            () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const TendanceScreen(titre: 'Tendance des ventes', kind: 'ventes', color: Colors.green),
            )),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _tendanceCard(
            'Tendance des dépenses',
            Icons.trending_down,
            const [Color(0xFF7A1F1F), Color(0xFFC62828)],
            () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const TendanceScreen(titre: 'Tendance des dépenses', kind: 'depenses', color: Colors.red),
            )),
          ),
        ),
      ],
    );
  }

  Widget _tendanceCard(String titre, IconData icon, List<Color> gradient, VoidCallback onTap) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.20), shape: BoxShape.circle),
                    child: Icon(icon, color: Colors.white, size: 20),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right, color: Colors.white70, size: 20),
                ],
              ),
              const SizedBox(height: 10),
              Text(titre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('Histogramme 12 mois', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _crmBloc(DashboardProvider provider) {
    final g = _global.isNotEmpty ? _global : provider.global;
    final crm = provider.crm;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = [
      _MiniStat('Clients actifs', '${g['clientsActifs'] ?? crm['totalClients'] ?? 0}', Icons.people, Colors.teal),
      _MiniStat('Commandes', '${g['nbCommandes'] ?? 0}', Icons.shopping_cart, Colors.purple),
      _MiniStat('Prospects', '${crm['totalProspects'] ?? 0}', Icons.person_search, Colors.indigo),
      _MiniStat('Nouveaux', '${crm['nouveauxClients'] ?? 0}', Icons.person_add, Colors.blue),
      _MiniStat('Relances à faire', '${crm['relancesAFaire'] ?? 0}', Icons.notifications_active, Colors.orange),
      _MiniStat('Cmd. en attente', '${crm['commandesEnAttente'] ?? g['commandesEnAttente'] ?? 0}', Icons.hourglass_bottom, Colors.brown),
    ];
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: 74,
      ),
      children: items.map((it) => _statTile(it.label, it.value, it.icon, it.color, isDark)).toList(),
    );
  }

  Widget _totauxBloc() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Totaux de toute la ferme : CA = toutes les ventes, Dépense = toutes les sorties de trésorerie.
    final ca = _n(_global['chiffreAffairesTotal']);
    final depense = _n(_global['depensesTotales']);
    final benefice = _n(_global['beneficeNet']);
    final marge = _n(_global['marge']);
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: 84,
      ),
      children: [
        _statTile('CA Total', formatAmountFcfa(ca), Icons.point_of_sale, Colors.green, isDark),
        _statTile('Dépense Total', formatAmountFcfa(depense), Icons.trending_down, Colors.red, isDark),
        _statTile('Bénéfice Total', formatAmountFcfa(benefice), Icons.account_balance_wallet, Colors.blue, isDark),
        _statTile('Marge Total', '${marge.toStringAsFixed(1)} %', Icons.percent, Colors.orange, isDark),
      ],
    );
  }

  Widget _statTile(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.35 : 0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.28 : 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isDark ? _lighten(color) : color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _lighten(Color c, [double amount = 0.25]) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }

  void _showExportLinks() {
    final today = DateTime.now().toIso8601String().split('T').first;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Partager le rapport global', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('Rapport PDF'),
              subtitle: const Text('Synthèse finances, élevage, reproduction, santé'),
              onTap: () {
                Navigator.pop(ctx);
                shareReportFile(
                  context,
                  loader: ApiService.downloadGlobalPdfReport,
                  filename: 'rapport-global-$today.pdf',
                  mimeType: 'application/pdf',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green),
              title: const Text('Rapport Excel'),
              subtitle: const Text('Synthèse + performance par bande'),
              onTap: () {
                Navigator.pop(ctx);
                shareReportFile(
                  context,
                  loader: ApiService.downloadGlobalExcelReport,
                  filename: 'rapport-global-$today.xlsx',
                  mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _MiniStat(this.label, this.value, this.icon, this.color);
}
