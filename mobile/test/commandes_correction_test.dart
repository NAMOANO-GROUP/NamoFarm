import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namofarm/models/bande.dart';
import 'package:namofarm/models/commande.dart';
import 'package:namofarm/providers/auth_provider.dart';
import 'package:namofarm/providers/bandes_provider.dart';
import 'package:namofarm/providers/clients_provider.dart';
import 'package:namofarm/providers/commandes_provider.dart';
import 'package:namofarm/screens/commandes_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Admin extends AuthProvider {
  @override
  bool get isAdmin => true;
}

class _FakeCommandes extends CommandesProvider {
  _FakeCommandes(this._liste);
  List<Commande> _liste;
  final List<Map<String, dynamic>> corrections = [];

  @override
  List<Commande> get commandes => _liste;
  @override
  List<Commande> get commandesActivesPage => _liste.where((c) => c.statut != 'payee').toList();
  @override
  List<Commande> get commandesHistoriquePage => _liste.where((c) => c.statut == 'payee').toList();
  @override
  bool get isLoading => false;
  @override
  Future<void> chargerCommandes() async {}
  final List<String> supprimees = [];

  @override
  Future<int> supprimerCommandes(Iterable<String> ids) async {
    supprimees.addAll(ids);
    _liste = _liste.where((c) => !ids.contains(c.id)).toList();
    notifyListeners();
    return ids.length;
  }

  @override
  Future<bool> corrigerCommande(String id, Map<String, dynamic> data) async {
    corrections.add(data);
    final p = (data['produits'] as List).first as Map;
    _liste = [
      Commande(
        id: id,
        clientId: 'c1',
        clientNom: 'Viviane TOUGMA',
        produits: [Produit(nom: p['nom'] as String, quantite: p['quantite'] as int, prixUnitaire: (p['prixUnitaire'] as num).toDouble())],
        montantTotal: (data['montantTotal'] as num).toDouble(),
        statut: 'payee',
      ),
    ];
    notifyListeners();
    return true;
  }
}

class _FakeBandes extends BandesProvider {
  @override
  List<Bande> get bandesActives => const [];
  @override
  Future<void> chargerBandesActives() async {}
}

/// Texte comparé sans tenir compte des espaces insécables du format français.
Finder _texte(String attendu) => find.byWidgetPredicate(
      (w) => w is Text && (w.data ?? '').replaceAll(RegExp('[\u00A0\u202F]'), ' ') == attendu,
    );

void main() {
  testWidgets('Commande payée saisie à l’envers : correction par un admin (quantité 6 × 3 000)', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});

    final commandes = _FakeCommandes([
      Commande(
        id: 'cmd1',
        clientId: 'c1',
        clientNom: 'Viviane TOUGMA',
        produits: [Produit(nom: 'PDF', quantite: 3000, prixUnitaire: 6)],
        montantTotal: 18000,
        statut: 'payee',
      ),
    ]);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => _Admin()),
        ChangeNotifierProvider<CommandesProvider>.value(value: commandes),
        ChangeNotifierProvider<BandesProvider>(create: (_) => _FakeBandes()),
        ChangeNotifierProvider<ClientsProvider>(create: (_) => ClientsProvider()),
      ],
      child: const MaterialApp(home: CommandesScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('commandes-historique-tile')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Quantité: 3'), findsOneWidget);

    await tester.tap(find.text('Corriger'));
    await tester.pumpAndSettle();
    expect(_texte('3 000 × 6,00 FCFA = 18 000,00 FCFA'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Quantité (nombre de sujets)'), '6');
    await tester.enterText(find.widgetWithText(TextField, 'Prix unitaire (FCFA)'), '3000');
    await tester.pump();
    expect(_texte('6 × 3 000,00 FCFA = 18 000,00 FCFA'), findsOneWidget);

    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Corriger')));
    await tester.pumpAndSettle();
    final p = (commandes.corrections.single['produits'] as List).single as Map;
    expect((p['quantite'], p['prixUnitaire'], commandes.corrections.single['montantTotal']), (6, 3000.0, 18000.0));
    expect(find.text('Commande corrigée'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Commande annulée : supprimée de la liste après confirmation', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});

    final commandes = _FakeCommandes([
      Commande(
        id: 'a1',
        clientId: 'c2',
        clientNom: 'Mr Abdoul',
        produits: [Produit(nom: 'PDF', quantite: 102, prixUnitaire: 2500)],
        montantTotal: 255000,
        statut: 'annulee',
      ),
      Commande(
        id: 'a2',
        clientId: 'c3',
        clientNom: 'Awa',
        produits: [Produit(nom: 'Poulets', quantite: 10, prixUnitaire: 3000)],
        montantTotal: 30000,
        statut: 'confirmee',
      ),
    ]);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => _Admin()),
        ChangeNotifierProvider<CommandesProvider>.value(value: commandes),
        ChangeNotifierProvider<BandesProvider>(create: (_) => _FakeBandes()),
        ChangeNotifierProvider<ClientsProvider>(create: (_) => ClientsProvider()),
      ],
      child: const MaterialApp(home: CommandesScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Supprimer la commande annulée'), findsOneWidget, reason: 'seulement sur la commande annulée');
    await tester.tap(find.byTooltip('Supprimer la commande annulée'));
    await tester.pumpAndSettle();
    expect(find.text('Supprimer la commande annulée ?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await tester.pumpAndSettle();

    expect(commandes.supprimees, ['a1']);
    expect(find.text('Mr Abdoul • -'), findsNothing);
    expect(find.text('Commande supprimée'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
