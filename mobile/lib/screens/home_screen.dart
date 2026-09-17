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
        child: Column(
          children: [
            // Bandeau de bienvenue compact, fixe en haut.
            Container(
              margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0B5D3B), Color(0xFF2E7D32)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Image.asset('assets/logo/namofarm.png', height: 30,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          auth.appName,
                          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          prenom.isNotEmpty ? 'Bienvenue, $prenom 👋' : 'Bienvenue 👋',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Grille de modules scrollable.
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.95,
                ),
                itemCount: modules.length,
                itemBuilder: (context, i) {
                  final m = modules[i];
                  final color = _hubColors[i % _hubColors.length];
                  return _hubTile(context, m.mobileDestination, color, () {
                    setState(() => _currentIndex = i);
                    context.read<NavHubProvider>().goModule();
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hubTile(BuildContext context, NavigationDestination dest, Color color, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? Colors.white.withValues(alpha: 0.06) : Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      elevation: isDark ? 0 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? color.withValues(alpha: 0.55) : Colors.grey.withValues(alpha: 0.20),
              width: isDark ? 1.2 : 1,
            ),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.25 : 0.15),
                  shape: BoxShape.circle,
                ),
                child: IconTheme(
                  data: IconThemeData(color: isDark ? _lighten(color) : color, size: 26),
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

  // Éclaircit une couleur pour un meilleur contraste sur fond sombre.
  Color _lighten(Color c, [double amount = 0.25]) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }

  Widget _buildBottomNav(List<_ModuleItem> modules) {
    // Barre de navigation horizontale scrollable : tous les modules sont visibles
    // en défilant, sans entrée "Plus".
    final theme = Theme.of(context);
    return Material(
      elevation: 8,
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            itemCount: modules.length,
            itemBuilder: (context, i) {
              final selected = _currentIndex == i;
              final dest = modules[i].mobileDestination;
              final color = selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _currentIndex = i),
                child: Container(
                  constraints: const BoxConstraints(minWidth: 68),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: selected ? theme.colorScheme.primary.withValues(alpha: 0.12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconTheme(
                        data: IconThemeData(color: color, size: 24),
                        child: selected ? (dest.selectedIcon ?? dest.icon) : dest.icon,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dest.label,
                        style: TextStyle(fontSize: 11, color: color, fontWeight: selected ? FontWeight.w700 : FontWeight.w400),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
