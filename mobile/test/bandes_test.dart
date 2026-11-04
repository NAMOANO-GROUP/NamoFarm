import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namofarm/models/alerte.dart';
import 'package:namofarm/models/bande.dart';
import 'package:namofarm/providers/alertes_provider.dart';
import 'package:namofarm/providers/auth_provider.dart';
import 'package:namofarm/providers/bandes_provider.dart';
import 'package:namofarm/screens/bandes/bande_actions.dart';
import 'package:namofarm/screens/bandes/bande_detail_screen.dart';
import 'package:namofarm/screens/bandes_screen.dart';
import 'package:namofarm/utils/bande_kpis.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _ref45 = ReferenceType(dureeJours: 45, poidsFinalG: 2000, consoTotaleKgParTete: 4.5);

Bande _bande({
  String id = 'b1',
  String nom = 'Bande B12',
  required DateTime ouverture,
  DateTime? fermeture,
  int initial = 1000,
  int actuel = 970,
  int mortalite = 30,
  List<SuiviJournalier> suivis = const [],
  List<EvenementSante> sante = const [],
  String batiment = 'Bâtiment A',
  String type = 'poulet_ameliore_45j',
}) =>
    Bande(
      id: id,
      nom: nom,
      dateOuverture: ouverture,
      dateFermeture: fermeture,
      statut: fermeture == null ? 'ouverte' : 'fermee',
      typeVolaille: type,
      race: 'Cobb 500',
      nombreInitial: initial,
      nombreActuel: actuel,
      mortaliteTotale: mortalite,
      poidsArriveeG: 40,
      dureeElevageJours: 45,
      batiment: batiment,
      suiviJournalier: suivis,
      evenementsSante: sante,
    );

class _Auth extends AuthProvider {
  @override
  bool get isAdmin => true;
  @override
  String get userPrenom => 'Moussa';
  @override
  String get userNom => 'Sow';
}

class _FakeBandes extends BandesProvider {
  _FakeBandes({List<Bande> actives = const [], List<Bande> historique = const []})
      : _actives = [...actives],
        _historique = [...historique];

  List<Bande> _actives;
  List<Bande> _historique;
  final List<String> fermees = [];

  @override
  List<Bande> get bandesActives => _actives;
  @override
  List<Bande> get bandesHistorique => _historique;
  @override
  bool get isLoading => false;
  @override
  Future<void> chargerBandesActives() async {}
  @override
  Future<void> chargerHistorique() async {}

  @override
  Future<bool> fermerBande(String id) async {
    fermees.add(id);
    final b = _actives.firstWhere((x) => x.id == id);
    _actives = _actives.where((x) => x.id != id).toList();
    _historique = [
      Bande(
        id: b.id,
        nom: b.nom,
        dateOuverture: b.dateOuverture,
        dateFermeture: DateTime.now(),
        statut: 'fermee',
        typeVolaille: b.typeVolaille,
        race: b.race,
        nombreInitial: b.nombreInitial,
        nombreActuel: b.nombreActuel,
      ),
      ..._historique,
    ];
    notifyListeners();
    return true;
  }
}

class _FakeAlertes extends AlertesProvider {
  _FakeAlertes(this._list);
  final List<Alerte> _list;
  @override
  List<Alerte> get alertes => _list;
  @override
  List<Alerte> get alertesAutomatiques => const [];
  @override
  List<Alerte> get historiqueAlertes => const [];
  @override
  List<Alerte> get historiqueAlertesAutomatiques => const [];
  @override
  bool get isLoading => false;
  @override
  Future<void> chargerAlertes({String? period}) async {}
  @override
  Future<void> chargerHistoriqueAlertes() async {}
  @override
  Future<int> creerPlusieurs(List<Map<String, dynamic>> taches) async => taches.length;
}

Widget _app(Widget child, {required BandesProvider bandes, List<Alerte> alertes = const []}) => MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => _Auth()),
        ChangeNotifierProvider<BandesProvider>.value(value: bandes),
        ChangeNotifierProvider<AlertesProvider>(create: (_) => _FakeAlertes(alertes)),
      ],
      child: MaterialApp(home: child),
    );

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

DateTime _jour(int deltaJours) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day).add(Duration(days: deltaJours));
}

/// Bande active de 28 jours, pesée hier à 1 400 g, sans saisie aujourd'hui.
Bande _bandeActive({String id = 'b1', String nom = 'Bande B12', double poids = 1400, String batiment = 'Bâtiment A'}) => _bande(
      id: id,
      nom: nom,
      batiment: batiment,
      ouverture: _jour(-28),
      suivis: [
        SuiviJournalier(date: _jour(-18).add(const Duration(hours: 8)), alimentationKg: 400, poidsMotenG: 300),
        SuiviJournalier(date: _jour(-8).add(const Duration(hours: 8)), alimentationKg: 600),
        SuiviJournalier(date: _jour(-1).add(const Duration(hours: 8)), alimentationKg: 800, poidsMotenG: poids, mortaliteJour: 5),
      ],
      sante: [EvenementSante(date: _jour(-14), type: 'vaccination', description: 'Gumboro', cout: 15000)],
    );

void main() {
  group('Indicateurs de bande', () {
    final now = DateTime(2026, 10, 29, 10);

    test('typeVolailleLabel traduit les types', () {
      expect(typeVolailleLabel('poulet_ameliore_45j'), 'Poulet amélioré 45J');
      expect(typeVolailleLabel('poule_pondeuse'), 'Poule pondeuse');
      expect(typeVolailleLabel('caille_japonaise'), 'Caille japonaise');
      expect(typeVolailleLabel(''), 'Autre');
    });

    test('ReferenceType : courbe saisie interpolée, sinon progression linéaire', () {
      expect(_ref45.poidsA(27, poidsArriveeG: 40), closeTo(1216, 0.01));
      expect(_ref45.poidsA(90, poidsArriveeG: 40), 2000);
      final avecCourbe = ReferenceType.fromJson({
        'dureeJours': 42,
        'poidsFinalG': 2600,
        'courbeTheorique': [
          {'age': 7, 'poidsG': 180},
          {'age': 14, 'poidsG': 480},
        ],
      });
      expect(avecCourbe.poidsA(7), 180);
      expect(avecCourbe.poidsA(10), closeTo(308.57, 0.01));
      expect(avecCourbe.poidsA(3), 180, reason: 'avant le premier point : valeur du premier point');
    });

    test('parseReferences complète avec les valeurs par défaut', () {
      final refs = parseReferences({
        'canard': {'dureeJours': 55, 'poidsFinalG': 3500, 'consoTotaleKgParTete': 7},
      });
      expect(refs['canard']!.dureeJours, 55);
      expect(refs['dinde']!.poidsFinalG, 7000);
      expect(referencePour(refs, 'inconnu').dureeJours, 45);
    });

    test('computeBandeKpis : IC, gain moyen, viabilité, IEP et écart à la référence', () {
      final b = _bande(
        ouverture: DateTime(2026, 10, 1, 9),
        suivis: [
          SuiviJournalier(date: DateTime(2026, 10, 10), alimentationKg: 400),
          SuiviJournalier(date: DateTime(2026, 10, 20), alimentationKg: 600),
          SuiviJournalier(date: DateTime(2026, 10, 28), alimentationKg: 800, poidsMotenG: 1400, mortaliteJour: 5),
        ],
      );
      final k = computeBandeKpis(b, _ref45, now: now);
      expect(k.ageJours, 28);
      expect(k.dureeJours, 45);
      expect(k.joursRestants, 17);

      // La durée de Config → Paramètres prime sur les 45 j enregistrés par défaut sur la bande.
      const ref90 = ReferenceType(dureeJours: 90, poidsFinalG: 1500, consoTotaleKgParTete: 5.5);
      final local = computeBandeKpis(b, ref90, now: now);
      expect(local.dureeJours, 90);
      expect(local.joursRestants, 62);
      expect(k.dateSortiePrevue, DateTime(2026, 11, 15));
      expect(k.viabilitePct, closeTo(97, 0.001));
      expect((k.effectifInitial, k.morts), (1000, 30));
      expect(k.mortalitePct, closeTo(3, 0.001));
      expect(k.agePesee, 27);
      expect(k.gmqG, closeTo((1400 - 40) / 27, 0.001));
      expect(k.ic, closeTo(1800 / (970 * 1.4), 0.0001));

      // 300 animaux vendus ensuite : l'effectif baisse, la viabilité et l'IC ne bougent pas.
      final vendue = _bande(ouverture: b.dateOuverture, actuel: 670, suivis: b.suiviJournalier);
      final kv = computeBandeKpis(vendue, _ref45, now: now);
      expect(kv.effectif, 670);
      expect(kv.viabilitePct, closeTo(97, 0.001));
      expect(kv.ic, closeTo(k.ic!, 0.0001));
      expect(k.iep, closeTo(97 * 1.4 / (27 * (1800 / (970 * 1.4))) * 100, 0.01));
      expect(k.poidsReferenceG, closeTo(1216, 0.01));
      expect(k.ecartReferencePct, closeTo((1400 - 1216) / 1216 * 100, 0.01));
      expect(k.alertes, [BandeAlerte.saisieManquante]);
    });

    test('computeBandeKpis : l’IC ne compte que l’aliment jusqu’à la pesée', () {
      final b = _bande(ouverture: DateTime(2026, 10, 1), suivis: [
        SuiviJournalier(date: DateTime(2026, 10, 20), alimentationKg: 1000, poidsMotenG: 1000),
        SuiviJournalier(date: DateTime(2026, 10, 25), alimentationKg: 500),
      ]);
      final k = computeBandeKpis(b, _ref45, now: now);
      expect(k.ic, closeTo(1000 / 970, 0.0001));
      expect(k.alimentTotalKg, 1500);
    });

    test('alertes : retard de croissance, mortalité en hausse, saisie du jour', () {
      final b = _bande(ouverture: DateTime(2026, 10, 1), initial: 1000, suivis: [
        SuiviJournalier(date: DateTime(2026, 10, 26), mortaliteJour: 12),
        SuiviJournalier(date: DateTime(2026, 10, 29, 7), poidsMotenG: 900, mortaliteJour: 10),
      ]);
      final k = computeBandeKpis(b, _ref45, now: now);
      expect(k.alertes, containsAll([BandeAlerte.retardCroissance, BandeAlerte.mortalite]));
      expect(k.alertes, isNot(contains(BandeAlerte.saisieManquante)));
      expect(k.mortalite7jPct, closeTo(2.2, 0.001));
    });

    test('la pesée d’arrivée (J0) ne déclenche pas de retard de croissance', () {
      final b = _bande(ouverture: DateTime(2026, 10, 19, 9), suivis: [
        SuiviJournalier(date: DateTime(2026, 10, 19, 10), poidsMotenG: 40, alimentationKg: 50),
      ]);
      final k = computeBandeKpis(b, _ref45, now: now);
      expect(k.poidsG, isNull);
      expect(k.gmqG, isNull);
      expect(k.iep, isNull);
      expect(k.alertes, isNot(contains(BandeAlerte.retardCroissance)));
    });

    test('une bande fermée est évaluée à sa fermeture, sans alerte de saisie', () {
      final b = _bande(ouverture: DateTime(2026, 8, 1), fermeture: DateTime(2026, 9, 15));
      final k = computeBandeKpis(b, _ref45, now: now);
      expect(k.ageJours, 45);
      expect(k.alertes, isEmpty);
      expect(k.poidsG, isNull);
      expect(k.ic, isNull);
      expect(k.iep, isNull);
    });

    test('courbeCroissance, résumé et performances par bâtiment', () {
      final a = _bande(id: 'a', ouverture: DateTime(2026, 10, 1), batiment: 'A', suivis: [
        SuiviJournalier(date: DateTime(2026, 10, 8), poidsMotenG: 180, alimentationKg: 100),
        SuiviJournalier(date: DateTime(2026, 10, 15), poidsMotenG: 480, alimentationKg: 300),
      ]);
      final b = _bande(id: 'b', ouverture: DateTime(2026, 10, 20), batiment: '', actuel: 500, initial: 500, mortalite: 0);
      expect(courbeCroissance(a).map((p) => p.age), [7, 14]);

      final kpis = {for (final x in [a, b]) x.id!: computeBandeKpis(x, _ref45, now: now)};
      final r = resumeBandes([a, b], kpis, now: now);
      expect(r.nbBandes, 2);
      expect(r.effectifTotal, 1470);
      expect(r.sortiesProchaines, 0, reason: 'a sort le 15/11 (dans 17 j), b le 04/12');
      expect(resumeBandes([a, b], kpis, now: now, horizonJours: 20).sortiesProchaines, 1);

      final perf = performancesParBatiment([a, b], kpis);
      expect(perf.map((p) => p.batiment), ['A', 'Non renseigné']);
      expect(perf.first.icMoy, isNotNull);
    });
  });

  testWidgets('Liste des bandes : résumé, carte enrichie, prochaine tâche et ouverture de la fiche', (tester) async {
    SharedPreferences.setMockInitialValues({});
    _size(tester, const Size(1200, 1000));
    final bandes = _FakeBandes(actives: [_bandeActive()]);
    final alertes = [
      Alerte(id: 't1', titre: 'Vaccin Newcastle rappel', message: '', type: 'vaccination', dateEcheance: _jour(2), bandeId: 'b1'),
    ];
    await tester.pumpWidget(_app(const BandesScreen(), bandes: bandes, alertes: alertes));
    await tester.pumpAndSettle();

    expect(find.text('bande(s) active(s)'), findsOneWidget);
    expect(find.text('Poulet amélioré 45J • Cobb 500 • Bâtiment A'), findsOneWidget);
    expect(find.text('J28'), findsOneWidget);
    expect(find.text('1 400 g'), findsOneWidget);
    expect(find.text('Saisie du jour manquante'), findsOneWidget);
    expect(find.text('Vaccin Newcastle rappel'), findsOneWidget);
    for (final s in ['Pesée', 'Alimentation', 'Mortalité', 'Climat']) {
      expect(find.byTooltip(s), findsOneWidget);
    }

    await tester.tap(find.text('Bande B12'));
    await tester.pumpAndSettle();
    expect(find.byType(BandeDetailScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Fiche bande : indicateurs et onglets Journal, Santé et Tâches', (tester) async {
    SharedPreferences.setMockInitialValues({});
    _size(tester, const Size(1200, 1000));
    final bande = _bandeActive();
    await tester.pumpWidget(_app(
      BandeDetailScreen(bande: bande),
      bandes: _FakeBandes(actives: [bande]),
      alertes: [Alerte(id: 't1', titre: 'Peser 6 sujets', message: '', type: 'pesee', dateEcheance: _jour(1), bandeId: 'b1')],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Indice de conso.'), findsOneWidget);
    expect(find.text('Indice d’efficacité'), findsOneWidget);
    expect(find.text('Gain moyen / jour'), findsOneWidget);
    expect(find.text('Prise de poids'), findsOneWidget, reason: 'les saisies restent dans des écrans dédiés');

    await tester.tap(find.text('Journal'));
    await tester.pumpAndSettle();
    expect(find.text('Mortalité : 5 sujet(s)'), findsOneWidget);
    expect(find.textContaining('Poids moyen 1400 g'), findsOneWidget);

    await tester.tap(find.text('Santé'));
    await tester.pumpAndSettle();
    expect(find.text('Gumboro'), findsOneWidget);

    await tester.tap(find.text('Tâches'));
    await tester.pumpAndSettle();
    expect(find.text('Peser 6 sujets'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Comparer : courbes et classement par IEP', (tester) async {
    SharedPreferences.setMockInitialValues({});
    _size(tester, const Size(1200, 1000));
    final bandes = _FakeBandes(actives: [
      _bandeActive(id: 'b1', nom: 'Bande B12', poids: 1400),
      _bandeActive(id: 'b2', nom: 'Bande B13', poids: 1100, batiment: 'Bâtiment B'),
    ]);
    await tester.pumpWidget(_app(const BandesScreen(), bandes: bandes));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Comparer'));
    await tester.pumpAndSettle();
    expect(find.text('Courbes de croissance'), findsOneWidget);
    expect(find.text('Classement par indice d’efficacité (IEP)'), findsOneWidget);
    expect(find.text('Bâtiment B'), findsOneWidget);

    final rangs = tester.widgetList<Text>(find.descendant(of: find.byType(DataTable), matching: find.byType(Text))).map((t) => t.data).toList();
    expect(rangs.indexOf('Bande B12'), lessThan(rangs.indexOf('Bande B13')), reason: 'la bande la plus lourde a le meilleur IEP');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Fermeture : bilan puis proposition du vide sanitaire', (tester) async {
    SharedPreferences.setMockInitialValues({});
    _size(tester, const Size(1200, 1000));
    final bande = _bandeActive();
    final provider = _FakeBandes(actives: [bande]);
    await tester.pumpWidget(_app(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(onPressed: () => fermerBandeAvecBilan(context, bande, _ref45), child: const Text('Go')),
          ),
        ),
      ),
      bandes: provider,
    ));
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Fermer'));
    await tester.pumpAndSettle();

    expect(provider.fermees, ['b1']);
    expect(find.text('Bilan de Bande B12'), findsOneWidget);
    await tester.tap(find.text('Planifier le vide sanitaire'));
    await tester.pumpAndSettle();
    expect(find.text('Vide sanitaire du bâtiment'), findsOneWidget);
    expect(find.text('Bande B12'), findsOneWidget, reason: 'la bande fermée est présélectionnée');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Fiche d’une bande fermée : consultation seule, sans saisie', (tester) async {
    SharedPreferences.setMockInitialValues({});
    _size(tester, const Size(1200, 1000));
    final fermee = _bande(ouverture: _jour(-60), fermeture: _jour(-15));
    await tester.pumpWidget(_app(BandeDetailScreen(bande: fermee), bandes: _FakeBandes(historique: [fermee])));
    await tester.pumpAndSettle();

    expect(find.text('Prise de poids'), findsNothing);
    expect(find.text('Planifier'), findsNothing);
    expect(find.byTooltip('Nouvelle saisie'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Liste et fiche tiennent sur un téléphone', (tester) async {
    SharedPreferences.setMockInitialValues({});
    _size(tester, const Size(390, 844));
    final bande = _bandeActive(nom: 'Bande de démarrage du bâtiment principal');
    final bandes = _FakeBandes(actives: [bande]);
    await tester.pumpWidget(_app(const BandesScreen(), bandes: bandes));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'liste');

    await tester.tap(find.text('Comparer'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'comparer');

    await tester.pumpWidget(_app(BandeDetailScreen(bande: bande), bandes: bandes));
    await tester.pumpAndSettle();
    for (final onglet in ['Courbes', 'Journal', 'Santé', 'Tâches', 'Finances']) {
      await tester.tap(find.text(onglet));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: onglet);
    }
  });
}
