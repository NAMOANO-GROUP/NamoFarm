import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namofarm/providers/auth_provider.dart';
import 'package:namofarm/providers/nav_hub_provider.dart';
import 'package:namofarm/providers/nav_order_provider.dart';
import 'package:namofarm/screens/help_screen.dart';
import 'package:namofarm/screens/home_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Admin extends AuthProvider {
  @override
  bool get isAdmin => true;
}

Future<NavOrderProvider> _pumpHome(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  Size size = const Size(390, 844),
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final order = NavOrderProvider();
  await order.load();
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(create: (_) => _Admin()),
      ChangeNotifierProvider(create: (_) => NavHubProvider()),
      ChangeNotifierProvider<NavOrderProvider>.value(value: order),
    ],
    child: const MaterialApp(home: HomeScreen()),
  ));
  await tester.pumpAndSettle();
  return order;
}

List<String> _hubLabels(WidgetTester tester) => tester
    .widgetList<Text>(find.descendant(of: find.byType(GridView), matching: find.byType(Text)))
    .map((t) => t.data ?? '')
    .toList();

void main() {
  group('applyModuleOrder', () {
    test('respecte l’ordre enregistré puis ajoute les nouveaux modules', () {
      expect(applyModuleOrder(['a', 'b', 'c', 'd'], ['c', 'a']), ['c', 'a', 'b', 'd']);
    });

    test('ignore les modules disparus et les doublons', () {
      expect(applyModuleOrder(['a', 'b'], ['x', 'b', 'b', 'a']), ['b', 'a']);
      expect(applyModuleOrder(['a', 'b'], const []), ['a', 'b']);
    });
  });

  test('NavOrderProvider mémorise l’ordre et garde le rang des modules masqués', () async {
    SharedPreferences.setMockInitialValues({'nav.moduleOrder': ['a', 'z', 'b']});
    final p = NavOrderProvider();
    await p.load();
    expect(p.sort<String>(['a', 'b', 'c'], (s) => s), ['a', 'b', 'c']);

    await p.setOrder(['c', 'b', 'a']);
    expect(p.order, ['c', 'b', 'a', 'z']);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('nav.moduleOrder'), ['c', 'b', 'a', 'z']);

    await p.reset();
    expect(prefs.getStringList('nav.moduleOrder'), isNull);
  });

  testWidgets('Grille d’accueil : suit l’ordre enregistré et propose de réorganiser', (tester) async {
    await _pumpHome(tester, prefs: {'nav.moduleOrder': ['aide', 'crm']});

    final labels = _hubLabels(tester);
    expect(labels.take(2), ['Aide', 'CRM']);

    await tester.tap(find.byTooltip('Réorganiser le menu'));
    await tester.pumpAndSettle();
    expect(find.text('Réorganiser le menu'), findsOneWidget);
    expect(find.text('Barre de navigation'), findsNWidgets(kNavFavoris));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Barre du bas : 4 favoris + Menu qui ramène à la grille', (tester) async {
    await _pumpHome(tester, prefs: {'nav.moduleOrder': ['aide', 'crm', 'bandes', 'finance']});

    await tester.tap(find.text('Aide').first);
    await tester.pumpAndSettle();
    expect(find.byType(HelpScreen), findsOneWidget);

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations, hasLength(kNavFavoris + 1));
    expect(bar.selectedIndex, 0);
    expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('Menu')), findsOneWidget);
    expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('Roadmap')), findsNothing);

    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Menu')));
    await tester.pumpAndSettle();
    expect(find.byType(GridView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Grand écran : barre latérale avec 4 favoris + Menu', (tester) async {
    await _pumpHome(
      tester,
      prefs: {'nav.moduleOrder': ['aide', 'crm', 'bandes', 'finance']},
      size: const Size(1400, 900),
    );

    await tester.tap(find.text('Aide').first);
    await tester.pumpAndSettle();
    expect(find.byType(HelpScreen), findsOneWidget);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.destinations, hasLength(kNavFavoris + 1));
    expect(rail.selectedIndex, 0);
    expect(find.descendant(of: find.byType(NavigationRail), matching: find.text('Roadmap')), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('Menu')));
    await tester.pumpAndSettle();
    expect(find.byType(GridView), findsOneWidget);
  });

  testWidgets('Libellé « Tableau de bord » dans la barre du bas sans débordement', (tester) async {
    await _pumpHome(tester, prefs: {'nav.moduleOrder': ['dashboard', 'aide', 'crm', 'finance']});
    await tester.tap(find.text('Aide').first);
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('Tableau de bord')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
