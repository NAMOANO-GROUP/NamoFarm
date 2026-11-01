import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'tableau_de_bord_screen.dart';
import 'bandes_screen.dart';
import 'reproduction_screen.dart';
import 'sante_screen.dart';
import 'cheptel_screen.dart';
import 'alertes_screen.dart';
import 'achats_screen.dart';
import 'crm_screen.dart';
import 'finance_screen.dart';
import 'roadmap_screen.dart';
import 'profile_screen.dart';
import 'config_screen.dart';
import 'help_screen.dart';
import '../config.dart';
import '../providers/auth_provider.dart';
import '../providers/nav_hub_provider.dart';
import '../providers/nav_order_provider.dart';

class _ModuleItem {
  /// Identifiant stable (ordre personnalisé enregistré sur l'appareil).
  final String id;
  final Widget page;
  final NavigationDestination desktopDestination;
  final NavigationDestination mobileDestination;
  final String permission;
  final List<String> anyPermissions;
  final bool adminOnly;
  final bool alwaysVisible;

  const _ModuleItem({
    required this.id,
    required this.page,
    required this.desktopDestination,
    required this.mobileDestination,
    required this.permission,
    this.anyPermissions = const [],
    this.adminOnly = false,
    this.alwaysVisible = false,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _currentId;

  NavHubProvider? _navHub;

  @override
  void initState() {
    super.initState();
    // À l'entrée dans l'app (après connexion) on affiche la page hub.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NavHubProvider>().reset();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final hub = context.read<NavHubProvider>();
    if (!identical(hub, _navHub)) {
      _navHub?.removeListener(_surDemandeModule);
      _navHub = hub..addListener(_surDemandeModule);
    }
  }

  @override
  void dispose() {
    _navHub?.removeListener(_surDemandeModule);
    super.dispose();
  }

  /// Ouverture d'un module demandée depuis une page (ex. Tableau de bord).
  void _surDemandeModule() {
    final id = _navHub?.prendreModuleDemande();
    if (id == null || !mounted) return;
    if (_navHub?.peutOuvrir(id) ?? true) {
      setState(() => _currentId = id);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vous n’avez pas accès à ce module.')));
    }
  }

  final List<_ModuleItem> _modules = const [
    _ModuleItem(
      id: 'profil',
      page: ProfileScreen(),
      desktopDestination: NavigationDestination(icon: Icon(Icons.account_circle_outlined), selectedIcon: Icon(Icons.account_circle), label: 'Profil'),
      mobileDestination: NavigationDestination(icon: Icon(Icons.account_circle_outlined), selectedIcon: Icon(Icons.account_circle), label: 'Profil'),
      permission: 'dashboard:view',
    ),
    _ModuleItem(
      id: 'dashboard',
      page: TableauDeBordScreen(),
      desktopDestination: NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Tableau de bord'),
      mobileDestination: NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Tableau de bord'),
      permission: 'dashboard:view',
    ),
    _ModuleItem(
      id: 'bandes',
      page: BandesScreen(),
      desktopDestination: NavigationDestination(icon: Icon(Icons.egg_outlined), selectedIcon: Icon(Icons.egg), label: 'Bandes'),
      mobileDestination: NavigationDestination(icon: Icon(Icons.egg_outlined), selectedIcon: Icon(Icons.egg), label: 'Bandes'),
      permission: 'bandes:view',
    ),
    _ModuleItem(
      id: 'reproduction',
      page: ReproductionScreen(),
      desktopDestination: NavigationDestination(icon: Icon(Icons.egg_alt_outlined), selectedIcon: Icon(Icons.egg_alt), label: 'Couvoir'),
      mobileDestination: NavigationDestination(icon: Icon(Icons.egg_alt_outlined), selectedIcon: Icon(Icons.egg_alt), label: 'Couvoir'),
      permission: 'reproduction:view',
    ),
    _ModuleItem(
      id: 'sante',
      page: SanteScreen(),
      desktopDestination: NavigationDestination(icon: Icon(Icons.vaccines_outlined), selectedIcon: Icon(Icons.vaccines), label: 'Santé'),
      mobileDestination: NavigationDestination(icon: Icon(Icons.vaccines_outlined), selectedIcon: Icon(Icons.vaccines), label: 'Santé'),
      permission: 'sante:view',
    ),
    _ModuleItem(
      id: 'cheptel',
      page: CheptelScreen(),
      desktopDestination: NavigationDestination(icon: Icon(Icons.pets_outlined), selectedIcon: Icon(Icons.pets), label: 'Cheptel'),
      mobileDestination: NavigationDestination(icon: Icon(Icons.pets_outlined), selectedIcon: Icon(Icons.pets), label: 'Cheptel'),
      permission: 'cheptel:view',
    ),
    _ModuleItem(
      id: 'achats',
      page: AchatsScreen(),
      desktopDestination: NavigationDestination(icon: Icon(Icons.shopping_basket_outlined), selectedIcon: Icon(Icons.shopping_basket), label: 'Achats'),
      mobileDestination: NavigationDestination(icon: Icon(Icons.shopping_basket_outlined), selectedIcon: Icon(Icons.shopping_basket), label: 'Achats'),
      // Visible dès que l'une des feuilles (stocks, fournisseurs) est autorisée.
      permission: 'stocks:view',
      anyPermissions: AchatsScreen.permissions,
    ),
    _ModuleItem(
      id: 'todo',
      page: AlertesScreen(),
      desktopDestination: NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: 'Todo list'),
      mobileDestination: NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: 'Todo'),
      permission: 'alertes:view',
    ),
    _ModuleItem(
      id: 'crm',
      page: CrmScreen(),
      desktopDestination: NavigationDestination(icon: Icon(Icons.people_outlined), selectedIcon: Icon(Icons.people), label: 'CRM'),
      mobileDestination: NavigationDestination(icon: Icon(Icons.people_outlined), selectedIcon: Icon(Icons.people), label: 'CRM'),
      permission: 'crm:view',
    ),
    _ModuleItem(
      id: 'finance',
      page: FinanceScreen(),
      desktopDestination: NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Finance'),
      mobileDestination: NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Finance'),
      permission: 'finance:view',
    ),
    _ModuleItem(
      id: 'roadmap',
      page: RoadmapScreen(),
      desktopDestination: NavigationDestination(icon: Icon(Icons.timeline_outlined), selectedIcon: Icon(Icons.timeline), label: 'Roadmap'),
      mobileDestination: NavigationDestination(icon: Icon(Icons.timeline_outlined), selectedIcon: Icon(Icons.timeline), label: 'Roadmap'),
      permission: 'dashboard:view',
    ),
    _ModuleItem(
      id: 'config',
      page: ConfigScreen(),
      desktopDestination: NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Config'),
      mobileDestination: NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Config'),
      permission: 'config:view',
      adminOnly: true,
    ),
    _ModuleItem(
      id: 'aide',
      page: HelpScreen(),
      desktopDestination: NavigationDestination(icon: Icon(Icons.help_outline), selectedIcon: Icon(Icons.help), label: 'Aide'),
      mobileDestination: NavigationDestination(icon: Icon(Icons.help_outline), selectedIcon: Icon(Icons.help), label: 'Aide'),
      permission: 'dashboard:view',
      alwaysVisible: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final navHub = context.watch<NavHubProvider>();
    final navOrder = context.watch<NavOrderProvider>();
    final isWide = MediaQuery.of(context).size.width >= 1000;
    final accessibleModules = navOrder.sort<_ModuleItem>(
      _modules.where((m) {
        if (m.alwaysVisible) return true;
        if (m.adminOnly && !auth.isAdmin) return false;
        if (m.anyPermissions.isNotEmpty) return m.anyPermissions.any(auth.hasPermission);
        return auth.hasPermission(m.permission);
      }).toList(),
      (m) => m.id,
    );

    navHub.modulesAccessibles = {for (final m in accessibleModules) m.id};

    if (accessibleModules.isEmpty) {
      return const Scaffold(body: Center(child: Text('Aucun module autorisé')));
    }

    // Page d'accueil hub : grille de modules affichée après connexion.
    if (navHub.showHub) {
      return _buildHub(context, auth, accessibleModules);
    }

    var currentIndex = accessibleModules.indexWhere((m) => m.id == _currentId);
    if (currentIndex < 0) currentIndex = 0;
    final current = accessibleModules[currentIndex];

    return Scaffold(
      body: isWide
          ? Row(
              children: [
                _buildRail(accessibleModules, current),
                const VerticalDivider(width: 1),
                Expanded(child: KeyedSubtree(key: ValueKey(current.id), child: current.page)),
              ],
            )
          : KeyedSubtree(key: ValueKey(current.id), child: current.page),
      bottomNavigationBar: isWide ? null : _buildBottomNav(accessibleModules, current),
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
                      errorBuilder: (_, _, _) => const SizedBox.shrink()),
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'v$kAppVersion',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Réorganiser le menu',
                    visualDensity: VisualDensity.compact,
                    color: Colors.white,
                    icon: const Icon(Icons.swap_vert),
                    onPressed: () => _showReorganiser(context, modules),
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
                    setState(() => _currentId = m.id);
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
      color: color.withValues(alpha: isDark ? 0.06 : 0.10),
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.55 : 0.60),
              width: 1.4,
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
                  color: color.withValues(alpha: isDark ? 0.28 : 0.20),
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

  /// Barre latérale (grand écran) : comme la barre du bas, les favoris + « Menu ».
  Widget _buildRail(List<_ModuleItem> modules, _ModuleItem current) {
    final favoris = modules.take(kNavFavoris).toList();
    final selected = favoris.indexWhere((m) => m.id == current.id);
    return NavigationRail(
      selectedIndex: selected < 0 ? favoris.length : selected,
      labelType: NavigationRailLabelType.all,
      onDestinationSelected: (i) {
        if (i == favoris.length) {
          context.read<NavHubProvider>().goHub();
        } else {
          setState(() => _currentId = favoris[i].id);
        }
      },
      destinations: [
        for (final m in favoris)
          NavigationRailDestination(
            icon: m.desktopDestination.icon,
            selectedIcon: m.desktopDestination.selectedIcon,
            label: Text(m.desktopDestination.label),
          ),
        const NavigationRailDestination(icon: Icon(Icons.apps_outlined), selectedIcon: Icon(Icons.apps), label: Text('Menu')),
      ],
    );
  }

  /// Barre du bas (téléphone) : les [kNavFavoris] premiers modules + « Menu » qui ouvre la grille.
  Widget _buildBottomNav(List<_ModuleItem> modules, _ModuleItem current) {
    final favoris = modules.take(kNavFavoris).toList();
    final selected = favoris.indexWhere((m) => m.id == current.id);
    return NavigationBar(
      height: 66,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      selectedIndex: selected < 0 ? favoris.length : selected,
      onDestinationSelected: (i) {
        if (i == favoris.length) {
          context.read<NavHubProvider>().goHub();
        } else {
          setState(() => _currentId = favoris[i].id);
        }
      },
      destinations: [
        ...favoris.map((m) => m.mobileDestination),
        const NavigationDestination(icon: Icon(Icons.apps_outlined), selectedIcon: Icon(Icons.apps), label: 'Menu'),
      ],
    );
  }

  /// Feuille de réorganisation : glisser-déposer, les premiers modules vont dans la barre de navigation.
  void _showReorganiser(BuildContext context, List<_ModuleItem> modules) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ReorganiserSheet(
        items: [for (final m in modules) (id: m.id, destination: m.mobileDestination)],
      ),
    );
  }
}

typedef _ModuleEntry = ({String id, NavigationDestination destination});

class _ReorganiserSheet extends StatefulWidget {
  final List<_ModuleEntry> items;
  const _ReorganiserSheet({required this.items});

  @override
  State<_ReorganiserSheet> createState() => _ReorganiserSheetState();
}

class _ReorganiserSheetState extends State<_ReorganiserSheet> {
  late final List<_ModuleEntry> _items = [...widget.items];

  void _save() => context.read<NavOrderProvider>().setOrder(_items.map((e) => e.id).toList());

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Réorganiser le menu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  TextButton(
                    onPressed: () async {
                      await context.read<NavOrderProvider>().reset();
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Par défaut'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Maintenez et glissez pour changer l’ordre. Les $kNavFavoris premiers modules apparaissent dans la barre de navigation.',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _items.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    _items.insert(newIndex, _items.removeAt(oldIndex));
                  });
                  _save();
                },
                itemBuilder: (context, i) {
                  final e = _items[i];
                  final favori = i < kNavFavoris;
                  return Card(
                    key: ValueKey(e.id),
                    elevation: 0,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    color: favori ? scheme.primaryContainer.withValues(alpha: 0.45) : null,
                    child: ListTile(
                      leading: IconTheme(
                        data: IconThemeData(color: favori ? scheme.primary : scheme.onSurfaceVariant),
                        child: e.destination.icon,
                      ),
                      title: Text(e.destination.label),
                      subtitle: favori ? const Text('Barre de navigation', style: TextStyle(fontSize: 12)) : null,
                      trailing: ReorderableDragStartListener(
                        index: i,
                        child: const Icon(Icons.drag_handle),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Terminé')),
            ),
          ],
        ),
      ),
    );
  }
}
