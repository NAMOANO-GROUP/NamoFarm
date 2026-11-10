import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namofarm/models/bande.dart';
import 'package:namofarm/models/commande.dart';
import 'package:namofarm/models/sante.dart';
import 'package:namofarm/models/stock.dart';
import 'package:namofarm/screens/planification/scenarios_tab.dart';
import 'package:namofarm/screens/planification/scenario_widgets.dart' show entier;
import 'package:namofarm/screens/planification_screen.dart';
import 'package:namofarm/utils/scenario.dart';
import 'package:shared_preferences/shared_preferences.dart';

Scenario _base() => Scenario(
      id: 't',
      nom: 'Test',
      sujets: 1000,
      mortalitePct: 5,
      dureeJours: 45,
      videSanitaireJours: 14,
      poidsFinalG: 2000,
      debut: DateTime(2026, 1, 1),
      prixPoussin: 600,
      consoKgParSujet: 4.5,
      phases: [PhaseAliment(nom: 'Unique', part: 100, prixKg: 400)],
      prophylaxieParSujet: 100,
      vitaminesParSujet: 0,
      charges: [
        ChargeLigne(id: 'a', libelle: 'Forfait', montant: 10000),
        ChargeLigne(id: 'b', libelle: 'Par sujet', montant: 10, mode: ModeCharge.parSujet),
        ChargeLigne(id: 'c', libelle: 'Par jour', montant: 1000, mode: ModeCharge.parJour),
      ],
      imprevusPct: 0,
      venteParKg: true,
      prixVente: 2000,
    );

void main() {
  group('calculerScenario', () {
    test('coûts, chiffre d’affaires et marge', () {
      final r = calculerScenario(_base());
      expect(r.poussins, 1053);
      expect(r.morts, 53);
      expect(r.alimentKg, closeTo(4619.25, 0.001));
      expect(r.coutPoussins, 631800);
      expect(r.coutAliment, closeTo(1847700, 0.01));
      expect(r.coutProphylaxie, 105300);
      expect(r.montantsCharges, [10000, 10530, 45000]);
      expect(r.total, closeTo(2650330, 0.01));
      expect(r.ca, 4000000);
      expect(r.marge, closeTo(1349670, 0.01));
      expect(r.prixMinSujet, closeTo(2650.33, 0.001));
      expect(r.prixMinKg, closeTo(1325.165, 0.001));
      expect(r.ica, closeTo(4619.25 / 2000, 0.0001));
      expect(r.finLot, DateTime(2026, 2, 15));
      expect(r.prochaineBande, DateTime(2026, 3, 1));
      expect(r.postes.fold<double>(0, (t, p) => t + p.montant), closeTo(r.total, 0.01));
    });

    test('imprévus, vente par sujet et parts normalisées', () {
      final s = _base()
        ..imprevusPct = 10
        ..venteParKg = false
        ..prixVente = 4000
        ..phases = [PhaseAliment(nom: 'A', part: 1, prixKg: 400), PhaseAliment(nom: 'B', part: 1, prixKg: 600)];
      final r = calculerScenario(s);
      expect(r.coutAliment, closeTo(4619.25 * 500, 0.01));
      expect(r.imprevus, closeTo((r.total - r.imprevus) * 0.10, 0.01));
      expect(r.ca, 4000000);
    });

    test('sans sujets ni mortalité extrême : pas de division par zéro', () {
      final r = calculerScenario(_base()
        ..sujets = 0
        ..mortalitePct = 100);
      expect(r.coutParSujet, 0);
      expect(r.margePct.isFinite, isTrue);
    });

    test('la sensibilité varie dans le bon sens et garde le scénario intact', () {
      final s = _base();
      final g = sensibiliteMarge(s);
      expect(g[1][1], closeTo(calculerScenario(s).marge, 0.01));
      expect(g[0][1], greaterThan(g[1][1]));
      expect(g[2][1], lessThan(g[1][1]));
      expect(g[1][2], greaterThan(g[1][1]));
      expect(s.phases.single.prixKg, 400);
    });

    test('sérialisation JSON complète', () {
      final s = _base()..origines[Cle.mortalite] = Origine.reel;
      final c = Scenario.fromJson(s.toJson());
      expect(calculerScenario(c).total, calculerScenario(s).total);
      expect(c.origines[Cle.mortalite], Origine.reel);
      expect(c.debut, s.debut);
    });
  });

  group('scenarioPropose', () {
    test('sans données : références et estimations', () {
      final s = scenarioPropose(const DonneesScenario());
      expect(s.sujets, 1000);
      expect(s.dureeJours, 45);
      expect(s.poidsFinalG, 2000);
      expect(s.origines[Cle.duree], Origine.reference);
      expect(s.mortalitePct, Estimations.mortalitePct);
      expect(s.origines[Cle.mortalite], Origine.estime);
      expect(s.phases, hasLength(3));
      expect(s.phases.first.prixKg, Estimations.prixKgAliment);
      expect(s.venteParKg, isTrue);
      expect(s.charges, isNotEmpty);
    });

    test('avec les données de l’exploitation', () {
      final d = DonneesScenario(
        bandes: [
          Bande(
            id: 'b1',
            nom: 'B1',
            dateOuverture: DateTime(2026, 1, 1),
            typeVolaille: 'poulet_ameliore_45j',
            race: 'x',
            nombreInitial: 1000,
            nombreActuel: 920,
            mortaliteTotale: 80,
            coutPoussin: 700,
            evenementsSante: [EvenementSante(date: DateTime(2026, 1, 5), type: 'vaccin', description: 'ND', cout: 200000)],
          ),
        ],
        stocks: [
          Stock(nom: 'Aliment démarrage', categorie: 'aliment', unite: 'sac', prixUnitaire: 25000),
          Stock(nom: 'Aliment finition', categorie: 'aliment', unite: 'kg', prixUnitaire: 450),
        ],
        commandes: [
          Commande(clientId: 'c', produits: [Produit(nom: 'Poulet de chair', quantite: 10, prixUnitaire: 3500)], montantTotal: 35000),
          Commande(clientId: 'c', statut: 'annulee', produits: [Produit(nom: 'Poulet', quantite: 10, prixUnitaire: 9999)], montantTotal: 1),
        ],
        protocoles: [
          ProtocoleVaccinal(nom: 'Chair', typeVolaille: 'poulet_ameliore_45j', etapes: [ProtocoleEtape(jourAge: 1), ProtocoleEtape(jourAge: 14)]),
        ],
      );
      final s = scenarioPropose(d);
      expect(s.mortalitePct, 8);
      expect(s.origines[Cle.mortalite], Origine.reel);
      expect(s.prixPoussin, 700);
      expect(s.phases[0].prixKg, 500);
      expect(s.phases[2].prixKg, 450);
      expect(s.phases[1].prixKg, closeTo(475, 0.001));
      expect(s.origines[Cle.phase(0)], Origine.reel);
      expect(s.prophylaxieParSujet, 200);
      expect(s.origines[Cle.prophylaxie], Origine.reel);
      expect(s.protocoleNom, 'Chair');
      expect(s.nbInterventions, 2);
      expect(s.venteParKg, isFalse);
      expect(s.prixVente, 3500);
      expect(s.origines[Cle.vente], Origine.reel);
    });

    test('prixKgStock gère les unités', () {
      Stock st(String u, double p) => Stock(nom: 'x', categorie: 'aliment', unite: u, prixUnitaire: p);
      expect(prixKgStock(st('kg', 400)), 400);
      expect(prixKgStock(st('Sac', 20000)), 400);
      expect(prixKgStock(st('litre', 400)), isNull);
      expect(prixKgStock(st('kg', 0)), isNull);
    });
  });

  group('Écrans', () {
    Future<void> pump(WidgetTester tester, Widget child, {Size size = const Size(390, 844)}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
      await tester.pumpAndSettle();
    }

    testWidgets('Scénarii : proposition modifiable, résultats et enregistrement', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pump(tester, const ScenariosTab(donnees: DonneesScenario()));

      expect(find.byKey(const ValueKey('planif-resume')), findsOneWidget);
      expect(find.text('Objectif de production'), findsOneWidget);
      expect(find.textContaining('${entier(1053)} poussins'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Sujets à vendre'), '2000');
      await tester.pumpAndSettle();
      expect(find.textContaining('${entier(2000)} sujets'), findsWidgets);

      await tester.tap(find.text('Résultats'));
      await tester.pumpAndSettle();
      expect(find.text('Répartition des coûts'), findsOneWidget);
      for (final titre in ['Détail des coûts', 'Seuil de rentabilité', 'Et si les prix changeaient ?']) {
        await tester.scrollUntilVisible(find.text(titre), 400, scrollable: find.byType(Scrollable).last);
        expect(find.text(titre), findsOneWidget);
      }
      expect(tester.takeException(), isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('planification.scenarios.v1'), contains('"sujets":2000'));
    });

    testWidgets('Scénarii : nouveau scénario et comparaison', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pump(tester, const ScenariosTab(donnees: DonneesScenario()));

      await tester.tap(find.byTooltip('Nouveau scénario'));
      await tester.pumpAndSettle();
      expect(find.text('Scénario 2'), findsOneWidget);

      await tester.tap(find.text('Résultats'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Comparer les scénarios'), 400, scrollable: find.byType(Scrollable).last);
      expect(find.text('Comparer les scénarios'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Scénarii : grand écran, paramètres et résultats côte à côte', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pump(tester, const ScenariosTab(donnees: DonneesScenario()), size: const Size(1400, 900));
      expect(find.text('Objectif de production'), findsOneWidget);
      expect(find.text('Répartition des coûts'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Planification : deux onglets Roadmap et Scénarii', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pump(tester, const PlanificationScreen());
      expect(find.text('Planification'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Roadmap'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Scénarii'), findsOneWidget);
      expect(find.text('Aucun planning'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
