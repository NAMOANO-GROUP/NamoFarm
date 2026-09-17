import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'global_dashboard_screen.dart';
import 'bandes_screen.dart';
import 'stocks_screen.dart';
import 'reproduction_screen.dart';
import 'sante_screen.dart';
import 'cheptel_screen.dart';
import 'previsions_screen.dart';
import 'alertes_screen.dart';
import 'crm_screen.dart';
import 'finance_screen.dart';
import 'roadmap_screen.dart';
import 'profile_screen.dart';
import 'config_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/nav_hub_provider.dart';

class _ModuleItem {
  final Widget page;
  final NavigationDestination desktopDestination;
  final NavigationDestination mobileDestination;
  final String permission;
  final bool adminOnly;

  const _ModuleItem({
    required this.page,
    required this.desktopDestination,
    required this.mobileDestination,
    required this.permission,
    this.adminOnly = false,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // À l'entrée dans l'app (après connexion) on affiche la page hub.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NavHubProvider>().reset();
    });
  }

  final List<_ModuleItem> _modules = const [
    _ModuleItem(
      page: GlobalDashboardScreen(),
      desktopDestination: NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
      mobileDestination: NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
      permission: 'dashboard:view',
    ),
    _ModuleItem(
      page: BandesScreen(),
      desktopDestination: NavigationDestination(icon: Icon(Icons.egg_outlined), selectedIcon: Icon(Icons.egg), label: 'Bandes'),
      mobileDestination: NavigationDestination(icon: Icon(Icons.egg_outlined), selectedIcon: Icon(Icons.egg), label: 'Bandes'),
      permission: 'bandes:view',
    ),
    _ModuleItem(
      page: ReproductionScreen(),
      desktopDestination: NavigationDestination(icon: Icon(Icons.egg_alt_outlined), selectedIcon: Icon(Icons.egg_alt), label: 'Reproduction'),
      mobileDestination: NavigationDestination(icon: Icon(Icons.egg_alt_outlined), selectedIcon: Icon(Icons.egg_alt), label: 'Couvoir'),
      permission: 'reproduction:view',
    ),
    _ModuleItem(
      page: SanteScreen(),
      desktopDestination: NavigationDestination(icon: Icon(Icons.vaccines_outlined), selectedIcon: Icon(Icons.vaccines), label: 'Santé'),
      mobileDestination: NavigationDestination(icon: Icon(Icons.vaccines_outlined), selectedIcon: Icon(Icons.vaccines), label: 'Santé'),
      permission: 'sante:view',
    ),
    _ModuleItem(
      page: CheptelScreen(),
      desktopDestination: NavigationDestination(icon: Icon(Icons.pets_outlined), selectedIcon: Icon(Icons.pets), label: 'Cheptel'),
      mobileDestination: NavigationDestination(icon: Icon(Icons.pets_outlined), selectedIcon: Icon(Icons.pets), label: 'Cheptel'),
      permission: 'cheptel:view',
    ),
    _ModuleItem(
      page: PrevisionsScreen(),
      desktopDestination: NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Prévisions'),
      mobileDestination: NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Prévisions'),
      permission: 'bandes:view',
    ),
    _ModuleItem(
      page: StocksScreen(),
      desktopDestination: NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Stocks'),
      mobileDestination: NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Stocks'),
      permission: 'stocks:view',
    ),
    _ModuleItem(
      page: AlertesScreen(),
      desktopDestination: NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: 'Todo list'),
      mobileDestination: NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: 'Todo'),
      permission: 'alertes:view',
    ),
    _ModuleItem(
      page: CrmScreen(),
      desktopDestination: NavigationDestination(icon: Icon(Icons.people_outlined), selectedIcon: Icon(Icons.people), label: 'CRM'),
      mobileDestination: NavigationDestination(icon: Icon(Icons.people_outlined), selectedIcon: Icon(Icons.people), label: 'CRM'),
      permission: 'crm:view',
    ),
    _ModuleItem(
      page: FinanceScreen(),
      desktopDestination: NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Finance'),
      mobileDestination: NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Finance'),
      permission: 'finance:view',
    ),
    _ModuleItem(
      page: RoadmapScreen(),
      desktopDestination: NavigationDestination(icon: Icon(Icons.timeline_outlined), selectedIcon: Icon(Icons.timeline), label: 'Roadmap'),
      mobileDestination: NavigationDestination(icon: Icon(Icons.timeline_outlined), selectedIcon: Icon(Icons.timeline), label: 'Roadmap'),
      permission: 'dashboard:view',
    ),
    _ModuleItem(
      page: ProfileScreen(),
      desktopDestination: NavigationDestination(icon: Icon(Icons.account_circle_outlined), selectedIcon: Icon(Icons.account_circle), label: 'Profil'),
      mobileDestination: NavigationDestination(icon: Icon(Icons.account_circle_outlined), selectedIcon: Icon(Icons.account_circle), label: 'Profil'),
      permission: 'dashboard:view',
    ),
    _ModuleItem(
      page: ConfigScreen(),
      desktopDestination: NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Config'),
      mobileDestination: NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Config'),
      permission: 'config:view',
      adminOnly: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final navHub = context.watch<NavHubProvider>();
    final isWide = MediaQuery.of(context).size.width >= 1000;
    final accessibleModules = _modules.where((m) {
      if (m.adminOnly && !auth.isAdmin) return false;
      return auth.hasPermission(m.permission);
    }).toList();

    if (accessibleModules.isEmpty) {
      return const Scaffold(body: Center(child: Text('Aucun module autorisé')));
    }

    // Page d'accueil hub : grille de modules affichée après connexion.
    if (navHub.showHub) {
      return _buildHub(context, auth, accessibleModules);
    }

    if (_currentIndex >= accessibleModules.length) {
      _currentIndex = 0;
    }

    final destinations = isWide
        ? accessibleModules.map((m) => m.desktopDestination).toList()
        : accessibleModules.map((m) => m.mobileDestination).toList();

    return Scaffold(
      body: isWide
          ? Row(
              children: [
                // Scrollable rail so all modules stay reachable even when they exceed
                // the screen height.
                LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: IntrinsicHeight(
                        child: NavigationRail(
                          selectedIndex: _currentIndex,
                          onDestinationSelected: (index) => setState(() => _currentIndex = index),
                          labelType: NavigationRailLabelType.all,
                          destinations: destinations
                              .map(
                                (d) => NavigationRailDestination(
                                  icon: d.icon,
                                  selectedIcon: d.selectedIcon,
                                  label: Text(d.label),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: accessibleModules[_currentIndex].page),
              ],
            )
          : accessibleModules[_currentIndex].page,
      bottomNavigationBar: isWide ? null : _buildBottomNav(accessibleModules),
    );
  }

  // Palette de couleurs pour les tuiles de modules du hub (cyclique).
  static const List<Color> _hubColors = [
    Color(0xFF2E7D32), // vert
    Color(0xFF1565C0), // bleu
    Color(0xFF6A1B9A), // violet
    Color(0xFFAD1457), // rose
    Color(0xFFEF6C00), // orange
    Color(0xFF00838F), // cyan
    Color(0xFF4E342E), // brun
    Color(0xFF283593), // indigo
    Color(0xFFC62828), // rouge
    Color(0xFF00695C), // teal
    Color(0xFF558B2F), // vert olive
    Color(0xFF37474F), // bleu-gris
    Color(0xFF7B1FA2), // violet foncé
  ];

  Widget _buildHub(BuildContext context, AuthProvider auth, List<_ModuleItem> modules) {
    final prenom = (auth.user?['prenom'] ?? '').toString().trim();
    final size = MediaQuery.of(context).size;
    final crossAxisCount = size.width > 900 ? 5 : (size.width > 600 ? 4 : 3);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0B5D3B), Color(0xFF2E7D32)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Image.asset('assets/logo/namofarm.png', height: 40,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            auth.appName,
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      prenom.isNotEmpty ? 'Bienvenue, $prenom 👋' : 'Bienvenue 👋',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Choisissez un module pour commencer.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.95,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final m = modules[i];
                    final color = _hubColors[i % _hubColors.length];
                    return _hubTile(context, m.mobileDestination, color, () {
                      setState(() => _currentIndex = i);
                      context.read<NavHubProvider>().goModule();
                    });
                  },
                  childCount: modules.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hubTile(BuildContext context, NavigationDestination dest, Color color, VoidCallback onTap) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: IconTheme(
                  data: IconThemeData(color: color, size: 26),
                  child: dest.selectedIcon ?? dest.icon,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                dest.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(List<_ModuleItem> modules) {
    // Material recommends 3-5 bottom destinations. When there are more modules than
    // can fit comfortably on a phone, keep the first ones and gather the rest under a
    // "Plus" entry that opens a bottom sheet. This adapts to any screen / module count.
    const maxSlots = 5;

    if (modules.length <= maxSlots) {
      return NavigationBar(
        selectedIndex: _currentIndex.clamp(0, modules.length - 1),
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: modules.map((m) => m.mobileDestination).toList(),
      );
    }

    final primaryCount = maxSlots - 1;
    final primary = modules.take(primaryCount).toList();
    final overflow = modules.skip(primaryCount).toList();
    final isOverflowSelected = _currentIndex >= primaryCount;

    return NavigationBar(
      selectedIndex: isOverflowSelected ? primaryCount : _currentIndex,
      onDestinationSelected: (index) {
        if (index < primaryCount) {
          setState(() => _currentIndex = index);
        } else {
          _showMoreModules(overflow, primaryCount);
        }
      },
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      destinations: [
        ...primary.map((m) => m.mobileDestination),
        const NavigationDestination(
          icon: Icon(Icons.more_horiz),
          selectedIcon: Icon(Icons.more_horiz),
          label: 'Plus',
        ),
      ],
    );
  }

  void _showMoreModules(List<_ModuleItem> overflow, int primaryCount) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 8),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text('Autres modules', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              for (var i = 0; i < overflow.length; i++)
                ListTile(
                  leading: overflow[i].mobileDestination.icon,
                  title: Text(overflow[i].mobileDestination.label),
                  selected: _currentIndex == primaryCount + i,
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _currentIndex = primaryCount + i);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
