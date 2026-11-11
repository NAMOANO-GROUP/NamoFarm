import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/finance_provider.dart';
import '../services/api_service.dart';
import '../utils/csv_export.dart';
import '../widgets/brand_logo.dart';
import 'finance/configuration_tab.dart';
import 'finance/finance_accueil_tab.dart';
import 'finance/finance_common.dart';
import 'finance/mouvements_tab.dart';
import 'finance/par_bande_tab.dart';

/// Finance : Accueil (où en est mon argent), Mouvements, Par bande, Configuration (coûts des bandes).
class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<FinanceProvider>();
      provider.chargerAccueil();
      provider.appliquerFiltresJournal();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _effacerHistorique() async {
    final provider = context.read<FinanceProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Effacer tout l’historique ?'),
        content: const Text('Tous les mouvements de trésorerie seront supprimés. Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final done = await provider.effacerHistoriqueMouvements();
    if (mounted) financeSnack(context, done ? 'Historique effacé' : 'Suppression impossible');
  }

  void _menu(String action) {
    final provider = context.read<FinanceProvider>();
    switch (action) {
      case 'pdf':
        shareReportFile(context,
            loader: ApiService.downloadGlobalPdfReport, filename: 'rapport_namofarm.pdf', mimeType: 'application/pdf');
      case 'excel':
        shareReportFile(context,
            loader: ApiService.downloadGlobalExcelReport,
            filename: 'rapport_namofarm.xlsx',
            mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      case 'csv':
        exportCsvToClipboard(
          context,
          loader: () => ApiService.exportHistoriqueMouvementsTresorerieCsv(
            sources: provider.sourceFilters.toList(),
            dateFrom: provider.dateFrom,
            dateTo: provider.dateTo,
          ),
          label: 'Mouvements de trésorerie',
        );
      case 'effacer':
        _effacerHistorique();
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = estAdminFinance(context);
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      appBar: AppBar(
        leading: const BrandLogo(),
        title: const Text('Finance'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Plus d’options',
            onSelected: _menu,
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'pdf',
                child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.picture_as_pdf_outlined), title: Text('Rapport PDF')),
              ),
              const PopupMenuItem(
                value: 'excel',
                child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.table_chart_outlined), title: Text('Rapport Excel')),
              ),
              const PopupMenuItem(
                value: 'csv',
                child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.download_outlined), title: Text('Exporter les mouvements (CSV)')),
              ),
              if (admin)
                const PopupMenuItem(
                  value: 'effacer',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_sweep_outlined, color: Colors.red),
                    title: Text('Effacer l’historique', style: TextStyle(color: Colors.red)),
                  ),
                ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          // Les onglets restent visibles sur un téléphone (libellés plus petits).
          labelPadding: compact ? const EdgeInsets.symmetric(horizontal: 2) : null,
          labelStyle: compact ? const TextStyle(fontSize: 12, fontWeight: FontWeight.w600) : null,
          tabs: const [
            Tab(icon: Icon(Icons.home_outlined, size: 20), text: 'Accueil'),
            Tab(icon: Icon(Icons.receipt_long_outlined, size: 20), text: 'Mouvements'),
            Tab(icon: Icon(Icons.egg_outlined, size: 20), text: 'Par bande'),
            Tab(icon: Icon(Icons.tune, size: 20), text: 'Configuration'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          const FinanceAccueilTab(),
          const MouvementsTab(),
          const ParBandeTab(),
          const ConfigurationTab(),
        ],
      ),
    );
  }
}
