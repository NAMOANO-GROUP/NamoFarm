import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/crm_provider.dart';
import '../widgets/brand_logo.dart';
import 'commandes_screen.dart';
import 'crm/clients_tab.dart';
import 'crm/crm_dashboard_tab.dart';
import 'crm/pipeline_tab.dart';
import 'crm/relances_tab.dart';

/// Module CRM : coquille à onglets. Chaque onglet vit dans `screens/crm/`.
class CrmScreen extends StatefulWidget {
  const CrmScreen({super.key});

  @override
  State<CrmScreen> createState() => _CrmScreenState();
}

class _CrmScreenState extends State<CrmScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 5, vsync: this);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<CrmProvider>().chargerTout());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enRetard = context.select<CrmProvider, int>(
      (crm) => crm.taches.where((t) => (t.statut == 'a_faire' || t.statut == 'en_cours') && t.dateEcheance.isBefore(DateUtils.dateOnly(DateTime.now()))).length,
    );
    return Scaffold(
      appBar: AppBar(
        leading: const BrandLogo(),
        title: const Text('CRM'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            const Tab(icon: Icon(Icons.space_dashboard_outlined), text: 'Accueil'),
            const Tab(icon: Icon(Icons.people_outline), text: 'Clients'),
            const Tab(icon: Icon(Icons.view_kanban_outlined), text: 'Pipeline'),
            Tab(
              icon: Badge(
                isLabelVisible: enRetard > 0,
                label: Text('$enRetard'),
                child: const Icon(Icons.task_alt_outlined),
              ),
              text: 'Relances',
            ),
            const Tab(icon: Icon(Icons.shopping_cart_outlined), text: 'Commandes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        // Les tableaux Kanban défilent horizontalement : on navigue entre onglets par la barre.
        physics: const NeverScrollableScrollPhysics(),
        children: [
          CrmDashboardTab(onNavigate: _tabController.animateTo),
          const ClientsTab(),
          const PipelineTab(),
          const RelancesTab(),
          const CommandesScreen(embedded: true),
        ],
      ),
    );
  }
}
