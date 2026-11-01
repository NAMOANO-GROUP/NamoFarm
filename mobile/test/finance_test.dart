import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namofarm/providers/auth_provider.dart';
import 'package:namofarm/providers/finance_provider.dart';
import 'package:namofarm/screens/finance_screen.dart';
import 'package:namofarm/services/api_service.dart';
import 'package:namofarm/utils/finance.dart';
import 'package:namofarm/screens/bande_bilan_screen.dart';
import 'package:namofarm/widgets/repartition_couts_chart.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _mvt({
  String id = 'm',
  String nature = 'sortie',
  String source = 'depense',
  String type = 'Alimentation',
  String categorie = 'AVICOLE',
  double montant = 1000,
  required DateTime date,
  String bandeId = '',
  String commentaire = '',
}) => {
  '_id': id,
  'nature': nature,
  'source': source,
  'type': type,
  'categorie': categorie,
  'montant': montant,
  'date': date.toUtc().toIso8601String(),
  'quiPrenom': 'Awa',
  'quiNom': 'Diop',
  'bandeId': bandeId,
  'commentaire': commentaire,
};

class _Auth extends AuthProvider {
  @override
  bool get isAdmin => true;
  @override
  String get userPrenom => 'Moussa';
  @override
  String get userNom => 'Sow';
}

class _FakeFinance extends FinanceProvider {
  _FakeFinance({this.raw = const [], this.analytique = const []});

  final List<Map<String, dynamic>> raw;
  final double soldeCaisse = 250000;
  final List<Map<String, dynamic>> analytique;
  final List<Map<String, dynamic>> depenses = [];
  final List<Map<String, dynamic>> apports = [];
  List<String>? sourcesDemandees;

  @override
  bool get accueilCharge => true;
  @override
  bool get isLoading => false;
  @override
  Map<String, dynamic> get solde => {'totalEntrees': 0.0, 'totalSorties': 0.0, 'soldeCaisse': soldeCaisse};
  @override
  List<Map<String, dynamic>> get mouvements => raw;
  @override
  List<Mouvement> get mouvementsRecents => parseMouvements(raw);
  @override
  List<Map<String, dynamic>> get analytiqueBandes => analytique;
  @override
  List<Map<String, dynamic>> get bandes => const [
    {'_id': 'b1', 'nom': 'Bande B12', 'statut': 'ouverte'},
    {'_id': 'b0', 'nom': 'Bande B11', 'statut': 'fermee'},
  ];
  @override
  double? get soldeDans3Mois => -50000;

  @override
  Future<void> chargerAccueil({DateTime? now}) async {}
  @override
  Future<void> chargerTresorerie() async {}
  @override
  Future<void> appliquerFiltresJournal({Iterable<String> sources = const [], DateTime? from, DateTime? to}) async {
    sourcesDemandees = sources.toList();
  }

  @override
  Future<bool> ajouterDepense(Map<String, dynamic> payload) async {
    depenses.add(payload);
    return true;
  }

  @override
  Future<bool> ajouterApprovisionnement(Map<String, dynamic> payload) async {
    apports.add(payload);
    return true;
  }
}

Widget _app(FinanceProvider finance) => MultiProvider(
  providers: [
    ChangeNotifierProvider<AuthProvider>(create: (_) => _Auth()),
    ChangeNotifierProvider<FinanceProvider>.value(value: finance),
  ],
  child: const MaterialApp(home: FinanceScreen()),
);

void _telephone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

DateTime _ilYa(int jours, {int heure = 10}) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day - jours, heure);
}

void main() {
  group('Logique Finance', () {
    final now = DateTime(2026, 3, 15, 12);
    final mvts = parseMouvements([
      _mvt(id: '1', montant: 120000, date: DateTime(2026, 3, 2)),
      _mvt(id: '2', type: 'Transport', montant: 10000, date: DateTime(2026, 3, 5)),
      _mvt(id: '3', nature: 'entree', source: 'vente', type: '', montant: 100000, date: DateTime(2026, 3, 6)),
      _mvt(id: '4', montant: 60000, date: DateTime(2026, 2, 10)),
      _mvt(
        id: '5',
        nature: 'entree',
        source: 'approvisionnement',
        type: '',
        montant: 300000,
        date: DateTime(2026, 2, 1),
      ),
      _mvt(id: '6', source: 'stock_entree', type: 'Aliment démarrage', montant: 5000, date: DateTime(2026, 3, 7)),
    ]);

    test('libellés lisibles pour les postes et les origines', () {
      expect(mvts[0].libelle, 'Aliment');
      expect(mvts[2].libelle, 'Vente');
      expect(mvts[4].libelle, 'Apport en caisse');
      expect(mvts[5].posteCle, posteAchatStock);
      expect(mvts[5].libelle, 'Achats de stock');
      expect(postePour('Salaire Prime etc').libelle, 'Salaires & primes');
      expect(postePour('autre chose').libelle, 'Autre chose');
      expect(activiteLibelle('HORS BUSINESS'), 'Hors activité');
      expect(mvts[1].signe, -10000);
    });

    test('totaux du mois, 6 derniers mois, postes et variation', () {
      final mars = totauxMois(mvts, 2026, 3);
      expect(mars.entrees, 100000);
      expect(mars.sorties, 135000);
      expect(mars.net, -35000);
      expect(mars.libelle, 'mars 2026');

      final six = derniersMois(mvts, now: now);
      expect(six.length, 6);
      expect(six.first.court, 'Oct');
      expect(six.last.mois, 3);
      expect(six[4].entrees, 300000);

      final postes = depensesParPoste(mvts, 2026, 3);
      expect(postes.first.key, 'Alimentation');
      expect(postes.first.value, 120000);
      expect(variationPct(120000, 60000), 100);
      expect(variationPct(10, 0), isNull);
    });

    test('conseils en phrases simples', () {
      final c = conseilsFinance(
        mouvements: mvts,
        now: now,
        soldeDans3Mois: -15000,
        bandes: [
          {'bandeNom': 'B9', 'statut': 'fermee', 'margeNette': -42000},
          {'bandeNom': 'B10', 'statut': 'ouverte', 'margeNette': -1000},
        ],
      ).map((e) => e.texte).toList();
      expect(c, contains('Ce mois-ci, vous avez dépensé 35 000 FCFA de plus que vous n’avez encaissé.'));
      expect(c, contains('Vous avez dépensé 100 % de plus en aliment qu’en février.'));
      expect(c, contains('Dans 3 mois, si rien ne change, votre solde serait négatif : -15 000 FCFA.'));
      expect(c, contains('La bande B9 s’est terminée en perte (-42 000 FCFA).'));
    });

    test('dépenses à refaire, montants et périodes', () {
      final dup = parseMouvements([
        _mvt(id: 'a', montant: 5000, date: DateTime(2026, 3, 3)),
        _mvt(id: 'b', montant: 5000, date: DateTime(2026, 3, 2)),
        _mvt(id: 'c', type: 'Transport', montant: 2000, date: DateTime(2026, 3, 1)),
        _mvt(id: 'd', nature: 'entree', source: 'vente', montant: 9000, date: DateTime(2026, 3, 4)),
      ]);
      expect(depensesRecentes(dup).map((m) => m.id), ['a', 'c']);

      expect(montantSaisie(12500), '12 500');
      expect(montantSaisie(1234.5), '1 234,5');
      expect(fcfa(-1500000), '-1 500 000 FCFA');

      final janvier = DateTime(2026, 1, 20);
      final dernier = bornesPeriode(PeriodeFinance.moisDernier, now: janvier);
      expect(dernier.from, DateTime(2025, 12, 1));
      expect(dernier.to, DateTime(2025, 12, 31));
      expect(bornesPeriode(PeriodeFinance.troisMois, now: janvier).from, DateTime(2025, 11, 1));
      expect(bornesPeriode(PeriodeFinance.tout).from, isNull);
    });

    test('répartition des coûts : 6 postes, somme de plusieurs bandes', () {
      final b = {
        'coutPoussins': 100,
        'prophylaxie': 20,
        'coutAliment': 300,
        'coutFixe': 10,
        'coutAmortissement': 5,
        'autresDepenses': 15,
      };
      expect(postesCoutBande(b).map((p) => p.$1), [
        'Prix des poussins',
        'Prophylaxie',
        'Alimentation',
        'Coût fixe',
        'Amortissement',
        'Autres',
      ]);
      expect(postesCoutBandes([b, b]).map((p) => p.$2), [200, 40, 600, 20, 10, 30]);
      // Sans « autresDepenses » : dépenses manuelles moins prophylaxie et poussins.
      expect(postesCoutBande({'depenses': 150, 'prophylaxie': 20, 'coutPoussins': 100}).last.$2, 30);
    });

    test('bornes de filtre envoyées avec fuseau : journée locale complète', () {
      final debut = DateTime.parse(ApiService.debutJourUtc(DateTime(2026, 3, 1, 15))).toLocal();
      final fin = DateTime.parse(ApiService.finJourUtc(DateTime(2026, 3, 31))).toLocal();
      expect(ApiService.debutJourUtc(DateTime(2026, 3, 1)), endsWith('Z'));
      expect(debut, DateTime(2026, 3, 1));
      expect(fin, DateTime(2026, 3, 31, 23, 59, 59, 999));
    });

    test('journal : recherche sans accents, sens et regroupement par jour', () {
      final j = parseMouvements([
        _mvt(id: '1', type: 'Vétérinaire', montant: 7000, date: DateTime(2026, 3, 2, 9), commentaire: 'Visite'),
        _mvt(id: '2', type: 'Transport', montant: 3000, date: DateTime(2026, 3, 2, 15)),
        _mvt(id: '3', nature: 'entree', source: 'vente', montant: 9000, date: DateTime(2026, 3, 1)),
      ]);
      expect(filtrerJournal(j, recherche: 'veterinaire visite').map((m) => m.id), ['1']);
      expect(filtrerJournal(j, recherche: '3000').map((m) => m.id), ['2']);
      expect(filtrerJournal(j, natures: {'entree'}).map((m) => m.id), ['3']);
      expect(filtrerJournal(j, recherche: 'b12', nomBande: (_) => 'Bande B12').length, 3);

      final g = grouperParJour(j);
      expect(g.length, 2);
      expect(g.first.jour, DateTime(2026, 3, 2));
      expect(g.first.mouvements.map((m) => m.id), ['2', '1']);
    });
  });

  group('Écrans Finance', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('Accueil sur téléphone : solde, mois en cours, conseils et postes', (tester) async {
      _telephone(tester);
      final finance = _FakeFinance(
        raw: [
          _mvt(id: '1', montant: 80000, date: _ilYa(0)),
          _mvt(id: '2', nature: 'entree', source: 'approvisionnement', type: '', montant: 150000, date: _ilYa(0)),
        ],
      );
      await tester.pumpWidget(_app(finance));
      await tester.pumpAndSettle();

      expect(find.text('250 000 FCFA'), findsOneWidget);
      expect(find.text('Argent disponible'), findsOneWidget);
      expect(find.textContaining('Ce mois-ci, vous avez encaissé 70 000 FCFA'), findsOneWidget);
      expect(find.textContaining('solde serait négatif'), findsOneWidget);
      await tester.dragUntilVisible(
        find.text('Où part l’argent ce mois-ci'),
        find.byType(ListView).first,
        const Offset(0, -200),
      );
      expect(find.text('Aliment'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Saisie express : montant, poste en tuile, bande puis enregistrement', (tester) async {
      _telephone(tester);
      final finance = _FakeFinance();
      await tester.pumpWidget(_app(finance));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dépense'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('operation-montant')), '12500');
      await tester.tap(find.byKey(const Key('operation-enregistrer')));
      await tester.pump();
      expect(find.text('Choisissez à quoi correspond la dépense.'), findsOneWidget);
      expect(finance.depenses, isEmpty);

      await tester.tap(find.text('Aliment'));
      await tester.pumpAndSettle();
      expect(find.text('Pour quelle bande ?'), findsOneWidget);
      await tester.tap(find.text('Aucune bande en particulier'));
      await tester.pumpAndSettle();
      expect(find.text('Bande B11'), findsNothing, reason: 'les bandes fermées ne sont pas proposées');
      await tester.tap(find.text('Bande B12').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('operation-enregistrer')));
      await tester.pumpAndSettle();
      expect(finance.depenses, hasLength(1));
      final p = finance.depenses.single;
      expect(p['montant'], 12500);
      expect(p['type'], 'Alimentation');
      expect(p['categorie'], 'AVICOLE');
      expect(p['bandeId'], 'b1');
      expect(p['quiPrenom'], 'Moussa');
      expect(p['quiNom'], 'Sow');
      expect(find.text('Dépense enregistrée'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Entrée d’argent : enregistrée comme apport en caisse', (tester) async {
      _telephone(tester);
      final finance = _FakeFinance();
      await tester.pumpWidget(_app(finance));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Entrée d’argent'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('operation-montant')), '50000');
      await tester.tap(find.byKey(const Key('operation-enregistrer')));
      await tester.pumpAndSettle();
      expect(finance.apports.single['montant'], 50000);
      expect(finance.depenses, isEmpty);
    });

    testWidgets('Mouvements : groupés par jour, recherche, filtres et fiche détail', (tester) async {
      _telephone(tester);
      final finance = _FakeFinance(
        raw: [
          _mvt(id: '1', montant: 80000, date: _ilYa(0), bandeId: 'b1'),
          _mvt(id: '2', type: 'Transport', montant: 3000, date: _ilYa(1)),
          _mvt(id: '3', nature: 'entree', source: 'vente', type: '', montant: 90000, date: _ilYa(1, heure: 16)),
        ],
      );
      await tester.pumpWidget(_app(finance));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mouvements'));
      await tester.pumpAndSettle();

      expect(find.text('Aujourd\'hui'), findsOneWidget);
      expect(find.text('Hier'), findsOneWidget);
      expect(find.text('− 80 000 FCFA'), findsWidgets);
      expect(find.text('+ 90 000 FCFA'), findsWidgets);

      await tester.enterText(find.byType(TextField).first, 'transport');
      await tester.pumpAndSettle();
      expect(find.text('Aliment'), findsNothing);
      expect(find.text('Transport'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Filtres'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ventes'));
      await tester.pumpAndSettle();
      expect(finance.sourcesDemandees, ['vente', 'vente_commande_payee']);
      await tester.tapAt(const Offset(5, 400));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Aliment'));
      await tester.pumpAndSettle();
      expect(find.text('Bande B12'), findsOneWidget);
      expect(find.text('Refaire'), findsOneWidget);
      expect(find.text('Modifier'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Refaire une dépense d’une bande fermée : enregistrée sans bande', (tester) async {
      _telephone(tester);
      final finance = _FakeFinance(
        raw: [_mvt(id: '1', montant: 40000, date: _ilYa(2), bandeId: 'b0', categorie: 'AGRICOLE')],
      );
      await tester.pumpWidget(_app(finance));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mouvements'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aliment'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refaire'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byKey(const Key('operation-montant'))).controller!.text, '40 000');
      expect(find.text('Pour quelle bande ?'), findsOneWidget);
      expect(find.text('Aucune bande en particulier'), findsOneWidget);
      await tester.tap(find.byKey(const Key('operation-enregistrer')));
      await tester.pumpAndSettle();
      final p = finance.depenses.single;
      expect(p['montant'], 40000);
      expect(p['type'], 'Alimentation');
      expect(p['categorie'], 'AGRICOLE');
      expect(p.containsKey('bandeId'), isFalse);
      expect((p['date'] as String).endsWith('Z'), isTrue);
    });

    testWidgets('Par bande : résultat, prix minimum et bandes terminées', (tester) async {
      _telephone(tester);
      final finance = _FakeFinance(
        analytique: [
          {
            'bandeId': 'b1',
            'bandeNom': 'Bande B12',
            'statut': 'ouverte',
            'coutTotal': 900000,
            'revenus': 0,
            'margeNette': -900000,
            'coutParKg': 1100,
          'coutFixeParSujet': 50,
          'amortissementParSujet': 20,
            'coutPoussins': 300000,
            'coutAliment': 600000,
            'seuilRentabiliteParSujet': 1850,
            'effectifVivant': 486,
          },
          {
            'bandeId': 'b0',
            'bandeNom': 'Bande B11',
            'statut': 'fermee',
            'coutTotal': 800000,
            'revenus': 950000,
            'margeNette': 150000,
          },
        ],
      );
      await tester.pumpWidget(_app(finance));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Par bande'));
      await tester.pumpAndSettle();

      expect(find.text('Bande B12'), findsOneWidget);
      expect(find.text('Pas encore de vente : dépenses engagées'), findsOneWidget);
      expect(find.textContaining('1 850 FCFA par sujet', findRichText: true), findsOneWidget);
      expect(find.text('1 100 FCFA'), findsOneWidget);

      expect(find.text('Coûts des bandes en cours'), findsOneWidget);
      expect(find.text('Coût fixe 50 FCFA · Amort. 20 FCFA / sujet'), findsOneWidget);
      await tester.ensureVisible(find.text('Coût fixe 50 FCFA · Amort. 20 FCFA / sujet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coût fixe 50 FCFA · Amort. 20 FCFA / sujet'));
      await tester.pumpAndSettle();
      expect(find.text('Coût fixe & amortissement · Bande B12'), findsOneWidget);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Coût fixe / sujet')).controller!.text, '50');
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView).first, const Offset(0, 3000));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Terminées'));
      await tester.pumpAndSettle();
      expect(find.text('Bande B11'), findsOneWidget);
      expect(find.text('Terminée avec un bénéfice'), findsOneWidget);
      expect(find.text('Ajouter coût fixe & amortissement'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Bilan de bande : camembert de répartition des coûts', (tester) async {
      _telephone(tester);
      await tester.pumpWidget(
        const MaterialApp(
          home: BandeBilanScreen(
            bande: {
              'bandeNom': 'B-001',
              'coutTotal': 432914,
              'coutPoussins': 150000,
              'prophylaxie': 30000,
              'coutAliment': 200000,
              'coutFixe': 20000,
              'coutAmortissement': 10000,
              'autresDepenses': 22914,
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(find.text('Autres'), find.byType(ListView), const Offset(0, -200));
      for (final l in ['Prix des poussins', 'Prophylaxie', 'Alimentation', 'Coût fixe', 'Amortissement', 'Autres']) {
        expect(find.text(l), findsOneWidget);
      }
      expect(find.byType(RepartitionCoutsChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
