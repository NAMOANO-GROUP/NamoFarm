import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namofarm/models/client.dart';
import 'package:namofarm/models/interaction.dart';
import 'package:namofarm/models/stock.dart';
import 'package:namofarm/models/tache_crm.dart';
import 'package:namofarm/providers/auth_provider.dart';
import 'package:namofarm/providers/crm_provider.dart';
import 'package:namofarm/providers/fournisseurs_provider.dart';
import 'package:namofarm/providers/stocks_provider.dart';
import 'package:namofarm/screens/achats/fournisseur_detail_screen.dart';
import 'package:namofarm/screens/achats_screen.dart';
import 'package:namofarm/screens/stocks_screen.dart';
import 'package:namofarm/utils/achats.dart';
import 'package:provider/provider.dart';

class _Auth extends AuthProvider {
  _Auth({this.admin = true, this.perms = const []});
  final bool admin;
  final List<String> perms;
  @override
  bool get isAdmin => admin;
  @override
  List<dynamic> get permissions => perms;
  @override
  String get userPrenom => 'Moussa';
  @override
  String get userNom => 'Sow';
}

class _Stocks extends StocksProvider {
  @override
  List<Stock> get stocks => [_stock('Aliment démarrage', 'Provenderie du Sahel')];
  @override
  bool get isLoading => false;
  @override
  Future<void> chargerStocks() async {}
}

class _StocksVides extends StocksProvider {
  @override
  List<Stock> get stocks => const [];
  @override
  bool get isLoading => false;
  @override
  Future<void> chargerStocks() async {}
}

class _Fournisseurs extends FournisseursProvider {
  _Fournisseurs(this._list);
  final List<Client> _list;
  int chargements = 0;
  @override
  List<Client> get fournisseurs => _list;
  @override
  bool get isLoading => false;
  @override
  Future<void> chargerFournisseurs() async => chargements++;
}

class _Crm extends CrmProvider {
  _Crm({this.tachesList = const [], this.interactionsList = const []});
  final List<TacheCRM> tachesList;
  final List<Interaction> interactionsList;
  @override
  List<TacheCRM> get taches => tachesList;
  @override
  List<Interaction> get interactions => interactionsList;
  @override
  String? get interactionsClientId => 'f1';
  @override
  Future<void> chargerInteractionsClient(String clientId) async {}
  @override
  Future<void> chargerTachesCrm() async {}
}

final _sahel = Client(
  id: 'f1',
  prenom: 'Ibrahima',
  nom: 'Ba',
  telephone: '+221 77 000 00 00',
  email: 'ventes@sahel.sn',
  entreprise: 'Provenderie du Sahel',
  commentaireActivite: 'Aliment volaille',
  statut: 'fournisseur',
  typeClient: 'pro',
);

Stock _stock(String nom, String fournisseur, {double qte = 100, double seuil = 0, List<MouvementStock> mvts = const []}) => Stock(
      id: nom,
      nom: nom,
      categorie: 'aliment',
      unite: 'kg',
      quantiteActuelle: qte,
      seuilAlerte: seuil,
      prixUnitaire: 350,
      fournisseur: fournisseur,
      mouvements: mvts,
    );

Widget _app(Widget child, {required FournisseursProvider fournisseurs, CrmProvider? crm, AuthProvider? auth}) => MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => auth ?? _Auth()),
        ChangeNotifierProvider<FournisseursProvider>.value(value: fournisseurs),
        ChangeNotifierProvider<CrmProvider>.value(value: crm ?? _Crm()),
        ChangeNotifierProvider<StocksProvider>(create: (_) => _Stocks()),
      ],
      child: MaterialApp(home: child),
    );

void _phone(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('Rapprochement stock ↔ fournisseur', () {
    test('reconnaît l’entreprise ou le nom du contact, sans tenir compte de la casse', () {
      expect(stockFourniPar(_stock('A', 'provenderie du sahel'), _sahel), isTrue);
      expect(stockFourniPar(_stock('B', '  Provenderie   du Sahel (Dakar) '), _sahel), isTrue);
      expect(stockFourniPar(_stock('C', 'Ibrahima Ba'), _sahel), isTrue);
      expect(stockFourniPar(_stock('D', 'Ba Ibrahima'), _sahel), isTrue);
    });

    test('ignore les autres fournisseurs et les champs vides', () {
      expect(stockFourniPar(_stock('E', 'Couvoir de Thiès'), _sahel), isFalse);
      expect(stockFourniPar(_stock('F', ''), _sahel), isFalse);
      // Un nom court ne doit pas déclencher de faux positif par simple inclusion.
      final court = Client(id: 'x', prenom: '', nom: 'Ba', telephone: '', statut: 'fournisseur');
      expect(stockFourniPar(_stock('G', 'Baobab Distribution'), court), isFalse);
    });

    test('receptionsDe ne garde que les entrées, de la plus récente à la plus ancienne', () {
      final s = _stock('Aliment', 'Provenderie du Sahel', mvts: [
        MouvementStock(date: DateTime(2026, 10, 1), type: 'entree', quantite: 50, coutUnitaire: 300),
        MouvementStock(date: DateTime(2026, 10, 5), type: 'sortie', quantite: 10),
        MouvementStock(date: DateTime(2026, 10, 20), type: 'entree', quantite: 20),
      ]);
      final r = receptionsDe([s]);
      expect(r.map((x) => x.mouvement.quantite), [20, 50]);
      expect(r.last.montant, 15000);
      expect(r.first.montant, 7000, reason: 'sans coût unitaire, on prend le prix du stock');
    });

    test('stockBas', () {
      expect(stockBas(_stock('A', '', qte: 5, seuil: 10)), isTrue);
      expect(stockBas(_stock('B', '', qte: 50, seuil: 10)), isFalse);
      expect(stockBas(_stock('C', '', qte: 0, seuil: 0)), isFalse);
    });
  });

  testWidgets('Achats : feuilles Stocks et Fournisseurs, appel et WhatsApp, ouverture de la fiche', (tester) async {
    _phone(tester, const Size(390, 844));
    final fournisseurs = _Fournisseurs([_sahel]);
    await tester.pumpWidget(_app(const AchatsScreen(), fournisseurs: fournisseurs));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Achats'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Stocks'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Fournisseurs'), findsOneWidget);
    expect(find.text('Gestion des Stocks'), findsNothing, reason: "pas de double barre de titre");
    expect(find.text('Aliment démarrage'), findsOneWidget);

    await tester.tap(find.widgetWithText(Tab, 'Fournisseurs'));
    await tester.pumpAndSettle();
    expect(fournisseurs.chargements, 1);
    expect(find.text('Provenderie du Sahel'), findsOneWidget);
    expect(find.byTooltip('Appeler'), findsOneWidget);
    expect(find.byTooltip('WhatsApp'), findsOneWidget);

    await tester.tap(find.text('Provenderie du Sahel'));
    await tester.pumpAndSettle();
    expect(find.byType(FournisseurDetailScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Achats : seules les feuilles autorisées sont affichées', (tester) async {
    _phone(tester, const Size(390, 844));
    await tester.pumpWidget(_app(
      const AchatsScreen(),
      fournisseurs: _Fournisseurs([_sahel]),
      auth: _Auth(admin: false, perms: const ['clients.read']),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(TabBar), findsNothing);
    expect(find.text('Provenderie du Sahel'), findsOneWidget);
    expect(find.text('Aliment démarrage'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Fiche fournisseur : actions rapides, réceptions et articles à réapprovisionner', (tester) async {
    _phone(tester, const Size(1400, 1000));
    final stocks = [
      _stock('Aliment démarrage', 'Provenderie du Sahel', qte: 5, seuil: 20, mvts: [
        MouvementStock(date: DateTime.now().subtract(const Duration(days: 3)), type: 'entree', quantite: 200, coutUnitaire: 350, utilisateur: 'Moussa'),
      ]),
      _stock('Vaccin Gumboro', 'Labo Vétérinaire'),
    ];
    final crm = _Crm(
      interactionsList: [
        Interaction(clientId: 'f1', type: 'appel', sujet: 'Prix aliment', contenu: 'Hausse de 5 % le mois prochain', auteur: 'Moussa Sow', dateInteraction: DateTime.now()),
      ],
      tachesList: [TacheCRM(id: 't1', clientId: 'f1', titre: 'Négocier le prix', dateEcheance: DateTime.now())],
    );

    await tester.pumpWidget(_app(
      FournisseurDetailScreen(fournisseur: _sahel, stocksLoader: () async => stocks.map(_stockJson).toList()),
      fournisseurs: _Fournisseurs([_sahel]),
      crm: crm,
    ));
    await tester.pumpAndSettle();

    for (final action in ['Appeler', 'WhatsApp', 'Email', 'Note', 'Tâche']) {
      expect(find.byTooltip(action), findsOneWidget);
    }
    expect(find.text('Contact : Ibrahima Ba'), findsOneWidget);
    expect(find.text('Stock bas'), findsOneWidget);
    expect(find.text('Appel · Prix aliment'), findsOneWidget);
    expect(find.text('Réception · 200 kg de Aliment démarrage'), findsOneWidget);
    expect(find.text('Négocier le prix'), findsOneWidget);
    expect(find.text('Aliment démarrage'), findsOneWidget);
    expect(find.text('Vaccin Gumboro'), findsNothing);
    expect(find.text('Réassort'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Stocks : un premier article peut être créé quand la liste est vide', (tester) async {
    _phone(tester, const Size(390, 844));
    await tester.pumpWidget(ChangeNotifierProvider<StocksProvider>(
      create: (_) => _StocksVides(),
      child: const MaterialApp(home: StocksScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Aucun stock'), findsOneWidget);
    await tester.tap(find.text('Nouveau stock'));
    await tester.pumpAndSettle();
    expect(find.text('Nouveau Stock'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Fiche fournisseur : sections sur téléphone sans débordement', (tester) async {
    _phone(tester, const Size(390, 844));
    await tester.pumpWidget(_app(
      FournisseurDetailScreen(fournisseur: _sahel, stocksLoader: () async => const []),
      fournisseurs: _Fournisseurs([_sahel]),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Aucune activité pour le moment'), findsOneWidget);
    await tester.ensureVisible(find.text('Articles (0)'));
    await tester.tap(find.text('Articles (0)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Aucun article rattaché'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Map<String, dynamic> _stockJson(Stock s) => {
      '_id': s.id,
      'nom': s.nom,
      'categorie': s.categorie,
      'unite': s.unite,
      'quantiteActuelle': s.quantiteActuelle,
      'seuilAlerte': s.seuilAlerte,
      'prixUnitaire': s.prixUnitaire,
      'fournisseur': s.fournisseur,
      'mouvements': [
        for (final m in s.mouvements)
          {
            'date': m.date.toIso8601String(),
            'type': m.type,
            'quantite': m.quantite,
            'coutUnitaire': m.coutUnitaire,
            'utilisateur': m.utilisateur,
          },
      ],
    };
