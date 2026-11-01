import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namofarm/models/alerte.dart';
import 'package:namofarm/models/bande.dart';
import 'package:namofarm/providers/alertes_provider.dart';
import 'package:namofarm/providers/auth_provider.dart';
import 'package:namofarm/providers/bandes_provider.dart';
import 'package:namofarm/providers/nav_hub_provider.dart';
import 'package:namofarm/screens/bandes/bande_detail_screen.dart';
import 'package:namofarm/screens/tableau_de_bord/tdb_source.dart';
import 'package:namofarm/screens/tableau_de_bord_screen.dart';
import 'package:namofarm/utils/bande_kpis.dart';
import 'package:namofarm/utils/tableau_de_bord.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

DateTime _jour(int delta, {int heure = 9}) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day + delta, heure);
}

Bande _bande(
  String id,
  String nom, {
  required int age,
  String type = 'poulet_ameliore_45j',
  int initial = 1000,
  int actuel = 960,
  int morts = 40,
}) => Bande(
  id: id,
  nom: nom,
  dateOuverture: _jour(-age, heure: 0),
  statut: 'ouverte',
  typeVolaille: type,
  race: 'Cobb 500',
  nombreInitial: initial,
  nombreActuel: actuel,
  mortaliteTotale: morts,
  poidsArriveeG: 40,
  batiment: 'A',
);

Alerte _tache(
  String id,
  String titre,
  DateTime echeance, {
  bool auto = false,
  String source = '',
  String type = 'autre',
  String statut = 'active',
  String? bandeId,
  String priorite = 'moyenne',
}) => Alerte(
  id: id,
  titre: titre,
  message: '',
  type: type,
  dateEcheance: echeance,
  automatique: auto,
  source: source,
  statut: statut,
  bandeId: bandeId,
  priorite: priorite,
);

class _Auth extends AuthProvider {
  @override
  bool get isAdmin => true;
  @override
  String get userPrenom => 'Moussa';
}

class _FakeBandes extends BandesProvider {
  _FakeBandes(this._actives);
  final List<Bande> _actives;
  @override
  List<Bande> get bandesActives => _actives;
  @override
  List<Bande> get bandesHistorique => const [];
  @override
  Future<void> chargerBandesActives() async {}
  @override
  Future<void> chargerHistorique() async {}
}

class _FakeAlertes extends AlertesProvider {
  _FakeAlertes(this._taches, this._auto);
  final List<Alerte> _taches;
  final List<Alerte> _auto;
  @override
  List<Alerte> get alertes => _taches;
  @override
  List<Alerte> get alertesAutomatiques => _auto;
  @override
  List<Alerte> get historiqueAlertes => const [];
  @override
  List<Alerte> get historiqueAlertesAutomatiques => const [];
  @override
  Future<void> chargerAlertes({String? period}) async {}
  @override
  Future<void> chargerAlertesAutomatiques() async {}
  @override
  Future<void> chargerHistoriqueAlertes() async {}
}

class _Source extends TdbSource {
  _Source({this.commercial = true});
  final bool commercial;
  final List<Intervalle> demandes = [];

  @override
  Future<ChiffresPeriode?> chiffres(Intervalle i) async {
    demandes.add(i);
    // Période actuelle (la plus récente) : 1 200 000 de ventes ; précédente : 1 000 000.
    final recent = demandes.length.isOdd;
    return recent
        ? const ChiffresPeriode(ventes: 1200000, depenses: 800000)
        : const ChiffresPeriode(ventes: 1000000, depenses: 1000000);
  }

  @override
  Future<SocleTdb> socle({DateTime? now}) async => SocleTdb(
    argentDisponible: 350000,
    tendance: [for (var i = 0; i < 12; i++) MoisTendance(2026, i + 1, 100000.0 * i, 50000)],
    relancesAFaire: commercial ? 3 : null,
    commandesEnAttente: commercial ? 2 : null,
    previsionPonderee: commercial ? 450000 : null,
    margesBandes: const {'b1': -120000},
  );
}

Widget _app({
  required List<Bande> bandes,
  List<Alerte> taches = const [],
  List<Alerte> auto = const [],
  TdbSource? source,
  NavHubProvider? hub,
}) => MultiProvider(
  providers: [
    ChangeNotifierProvider<AuthProvider>(create: (_) => _Auth()),
    ChangeNotifierProvider<BandesProvider>(create: (_) => _FakeBandes(bandes)),
    ChangeNotifierProvider<AlertesProvider>(create: (_) => _FakeAlertes(taches, auto)),
    ChangeNotifierProvider<NavHubProvider>.value(value: hub ?? NavHubProvider()),
  ],
  child: MaterialApp(home: TableauDeBordScreen(source: source ?? _Source())),
);

void _taille(WidgetTester tester, Size s) {
  tester.view.physicalSize = s;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('Logique du Tableau de bord', () {
    test('périodes et périodes de comparaison', () {
      final now = DateTime(2026, 3, 31, 15);
      final m = intervallesTdb(PeriodeTdb.mois, now: now);
      expect(m.actuel.from, DateTime(2026, 3, 1));
      expect(m.actuel.to, DateTime(2026, 3, 31));
      expect(m.precedent!.from, DateTime(2026, 2, 1));
      expect(m.precedent!.to, DateTime(2026, 2, 28), reason: 'borné à la fin de février');

      final t = intervallesTdb(PeriodeTdb.troisMois, now: now);
      expect(t.actuel.from, DateTime(2026, 1, 1));
      expect(t.precedent!.from, DateTime(2025, 10, 1));
      expect(t.precedent!.to, DateTime(2025, 12, 31));

      final mi = intervallesTdb(PeriodeTdb.troisMois, now: DateTime(2026, 5, 15));
      expect(mi.actuel.from, DateTime(2026, 3, 1));
      expect(mi.precedent!.from, DateTime(2025, 12, 1));
      expect(mi.precedent!.to, DateTime(2026, 2, 15), reason: 'même durée que la période en cours');
      expect(intervallesTdb(PeriodeTdb.troisMois, now: DateTime(2026, 5, 31)).precedent!.to, DateTime(2026, 2, 28));

      final a = intervallesTdb(PeriodeTdb.annee, now: now);
      expect(a.actuel.from, DateTime(2026, 1, 1));
      expect(a.precedent!.to, DateTime(2025, 3, 31));
      expect(intervallesTdb(PeriodeTdb.tout, now: now).precedent, isNull);

      expect(evolutionPct(120, 100), 20);
      expect(evolutionPct(-50, -100), 50, reason: 'perte réduite = amélioration');
      expect(evolutionPct(10, 0), isNull);
    });

    test('à faire aujourd’hui : échues, du jour, sorties proches ; urgences en tête', () {
      final now = _jour(0, heure: 12);
      final b1 = _bande('b1', 'B-001', age: 40); // 45 j → sortie dans 5 j
      final b2 = _bande('b2', 'B-002', age: 50); // sortie dépassée de 5 j
      final b3 = _bande('b3', 'B-003', age: 5);
      const ref = ReferenceType(dureeJours: 45, poidsFinalG: 2000, consoTotaleKgParTete: 4.5);
      final kpis = {
        for (final b in [b1, b2, b3]) b.id!: computeBandeKpis(b, ref, now: now),
      };

      final e = elementsAujourdhui(
        taches: [
          _tache('t1', 'Nettoyer le bâtiment', _jour(0)),
          _tache('t2', 'Vacciner B-001', _jour(-2), bandeId: 'b1'),
          _tache('t3', 'Plus tard', _jour(3)),
          _tache('t4', 'Déjà fait', _jour(-1), statut: 'faite'),
        ],
        automatiques: [
          _tache(
            'stock-1',
            'Stock bas: Aliment',
            _jour(0),
            auto: true,
            source: 'stock',
            type: 'stock_bas',
            priorite: 'haute',
          ),
          _tache('crm-task-1', 'Rappeler Awa', _jour(-1), auto: true, source: 'crm_tache', type: 'vente'),
        ],
        bandes: [b1, b2, b3],
        kpis: kpis,
        now: now,
      );
      final titres = e.map((x) => x.titre).toList();
      expect(titres, isNot(contains('Plus tard')));
      expect(titres, isNot(contains('Déjà fait')));
      expect(titres, contains('Sortie dans 5 j : B-001'));
      expect(titres.where((t) => t.contains('B-003')), isEmpty);

      final urgents = e.takeWhile((x) => x.urgent).map((x) => x.titre).toSet();
      expect(urgents, {'Vacciner B-001', 'Rappeler Awa', 'Stock bas: Aliment', 'Sortie dépassée : B-002'});
      expect(e.firstWhere((x) => x.titre == 'Vacciner B-001').detail, startsWith('En retard de 2 j'));
      expect(e.firstWhere((x) => x.titre == 'Vacciner B-001').bandeId, 'b1');
      expect(e.firstWhere((x) => x.titre == 'Stock bas: Aliment').module, 'achats');
      expect(e.firstWhere((x) => x.titre == 'Rappeler Awa').module, 'crm');
      expect(e.firstWhere((x) => x.titre == 'Nettoyer le bâtiment').module, 'todo');
    });

    test('résumé élevage, 12 derniers mois et ordre des blocs', () {
      final bandes = [
        _bande('b1', 'B1', age: 10, initial: 1000, actuel: 950, morts: 50),
        _bande('b2', 'B2', age: 20, initial: 500, actuel: 450, morts: 50),
      ];
      final r = resumeElevage(bandes, const {});
      expect(r.nbBandes, 2);
      expect(r.sujets, 1400);
      expect(r.mortalitePct, closeTo(100 / 1500 * 100, 0.001));
      expect(r.icMoyen, isNull);

      final mois = douzeDerniersMois(
        anneeCourante: {
          'ventes': [
            {'mois': 1, 'total': 10},
            {'mois': 3, 'total': 30},
          ],
          'depenses': [
            {'mois': 3, 'total': 5},
          ],
        },
        anneePrecedente: {
          'ventes': [
            {'mois': 4, 'total': 40},
            {'mois': 3, 'total': 999},
          ],
        },
        now: DateTime(2026, 3, 10),
      );
      expect(mois.length, 12);
      expect((mois.first.annee, mois.first.mois, mois.first.ventes), (2025, 4, 40));
      expect((mois.last.annee, mois.last.mois, mois.last.ventes, mois.last.depenses), (2026, 3, 30, 5));

      expect(ordreBlocs(['tendance', 'inconnu', 'aujourdhui', 'tendance']), [
        BlocTdb.tendance,
        BlocTdb.aujourdhui,
        BlocTdb.indicateurs,
        BlocTdb.bandes,
        BlocTdb.commercial,
      ]);
    });
  });

  group('Écran Tableau de bord', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('Téléphone : salutation, à faire, indicateurs avec évolution, bandes, tendance, commercial', (
      tester,
    ) async {
      _taille(tester, const Size(390, 844));
      final source = _Source();
      await tester.pumpWidget(
        _app(
          bandes: [_bande('b1', 'B-001', age: 40)],
          taches: [_tache('t1', 'Vacciner', _jour(-1), bandeId: 'b1')],
          source: source,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tableau de bord'), findsOneWidget);
      expect(
        find.text('Bonjour Moussa').evaluate().isNotEmpty || find.text('Bonsoir Moussa').evaluate().isNotEmpty,
        isTrue,
      );
      expect(find.text('À faire aujourd’hui (2)'), findsOneWidget);
      expect(find.text('1 point demande votre attention en priorité'), findsOneWidget);
      expect(find.text('Sortie dans 5 j : B-001'), findsOneWidget);

      await tester.dragUntilVisible(find.text('Résultat'), find.byType(ListView).first, const Offset(0, -200));
      expect(find.text('350k FCFA'), findsOneWidget);
      expect(find.text('▲ 20 %'), findsOneWidget, reason: 'ventes 1,2 M vs 1 M');
      expect(find.text('▼ 20 %'), findsOneWidget, reason: 'dépenses en baisse : bonne nouvelle');
      expect(source.demandes, hasLength(2));

      await tester.tap(find.byTooltip('Période'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cette année'));
      await tester.pumpAndSettle();
      expect(find.text('Cette année'), findsOneWidget, reason: 'période affichée dans la liste de choix');
      expect(source.demandes, hasLength(4));
      expect(source.demandes[2].from, DateTime(DateTime.now().year, 1, 1));

      await tester.dragUntilVisible(
        find.text('Bandes en cours (1)'),
        find.byType(ListView).first,
        const Offset(0, -200),
      );
      await tester.dragUntilVisible(find.text('-120k FCFA'), find.byType(ListView).first, const Offset(0, -200));
      await tester.dragUntilVisible(find.text('Détail des ventes'), find.byType(ListView).first, const Offset(0, -200));
      await tester.dragUntilVisible(find.text('Affaires en cours'), find.byType(ListView).first, const Offset(0, -200));
      expect(find.text('450k FCFA'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Toucher un élément ouvre la bande ou le module', (tester) async {
      _taille(tester, const Size(390, 844));
      final hub = NavHubProvider();
      await tester.pumpWidget(
        _app(
          bandes: [_bande('b1', 'B-001', age: 40)],
          auto: [
            _tache(
              'stock-1',
              'Stock bas: Aliment',
              _jour(0),
              auto: true,
              source: 'stock',
              type: 'stock_bas',
              priorite: 'haute',
            ),
          ],
          hub: hub,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Stock bas: Aliment'));
      await tester.pumpAndSettle();
      expect(hub.prendreModuleDemande(), 'achats');

      hub.modulesAccessibles = {'dashboard', 'bandes'};
      await tester.tap(find.text('Stock bas: Aliment'));
      await tester.pumpAndSettle();
      expect(hub.prendreModuleDemande(), isNull);
      expect(find.text('Vous n’avez pas accès à ce module.'), findsOneWidget);

      await tester.tap(find.text('Sortie dans 5 j : B-001'));
      await tester.pumpAndSettle();
      expect(find.byType(BandeDetailScreen), findsOneWidget);
    });

    testWidgets('Personnaliser : masquer et réordonner, mémorisé', (tester) async {
      _taille(tester, const Size(390, 844));
      await tester.pumpWidget(_app(bandes: const [], source: _Source(commercial: false)));
      await tester.pumpAndSettle();
      expect(find.text('Rien d’urgent aujourd’hui'), findsOneWidget);
      expect(find.text('Ouvrir le CRM'), findsNothing, reason: 'bloc commercial masqué sans droits CRM');

      await tester.tap(find.byTooltip('Plus d’options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Personnaliser'));
      await tester.pumpAndSettle();
      final interrupteur = find.descendant(
        of: find.ancestor(of: find.text('Aujourd’hui'), matching: find.byType(ListTile)),
        matching: find.byType(Switch),
      );
      await tester.tap(interrupteur);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terminé'));
      await tester.pumpAndSettle();

      expect(find.text('Rien d’urgent aujourd’hui'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('tdb.masques'), ['aujourdhui']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Grand écran : deux colonnes sans débordement', (tester) async {
      _taille(tester, const Size(1400, 900));
      await tester.pumpWidget(_app(bandes: [_bande('b1', 'B-001', age: 40), _bande('b2', 'B-002', age: 12)]));
      await tester.pumpAndSettle();
      expect(find.text('Indicateurs clés'), findsOneWidget);
      expect(find.text('Bandes en cours (2)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
