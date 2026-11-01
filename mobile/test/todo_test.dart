import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namofarm/models/alerte.dart';
import 'package:namofarm/providers/alertes_provider.dart';
import 'package:namofarm/providers/auth_provider.dart';
import 'package:namofarm/screens/alertes_screen.dart';
import 'package:namofarm/screens/todo/todo_dialog.dart';
import 'package:namofarm/utils/todo.dart';
import 'package:provider/provider.dart';

DateTime _today() => DateUtils.dateOnly(DateTime.now());

class _Auth extends AuthProvider {
  @override
  String get userPrenom => 'Moussa';
  @override
  String get userNom => 'Sow';
}

/// Faux provider : listes en mémoire et enregistrement des actions, aucun appel réseau.
class _FakeTodo extends AlertesProvider {
  _FakeTodo({List<Alerte> ouvertes = const [], List<Alerte> auto = const [], List<Alerte> terminees = const []})
      : _ouvertes = [...ouvertes],
        _auto = [...auto],
        _terminees = [...terminees];

  List<Alerte> _ouvertes;
  final List<Alerte> _auto;
  List<Alerte> _terminees;
  final List<String> calls = [];
  final List<Map<String, dynamic>> created = [];

  @override
  List<Alerte> get alertes => _ouvertes;
  @override
  List<Alerte> get alertesAutomatiques => _auto;
  @override
  List<Alerte> get historiqueAlertes => _terminees;
  @override
  List<Alerte> get historiqueAlertesAutomatiques => const [];
  @override
  bool get isLoading => false;

  @override
  Future<void> chargerAlertes({String? period}) async {}
  @override
  Future<void> chargerAlertesAutomatiques() async {}
  @override
  Future<void> chargerHistoriqueAlertes() async {}
  @override
  Future<void> chargerHistoriqueAlertesAutomatiques() async {}

  @override
  Future<({bool ok, String? prochaineId})> terminer(Alerte a) async {
    calls.add('terminer:${a.id}');
    _ouvertes = _ouvertes.where((x) => x.id != a.id).toList();
    _terminees = [a.copyWith(statut: 'faite'), ..._terminees];
    notifyListeners();
    return (ok: true, prochaineId: 'next-1');
  }

  @override
  Future<bool> rouvrir(Alerte a, {String? prochaineId}) async {
    calls.add('rouvrir:${a.id}:$prochaineId');
    return true;
  }

  @override
  Future<bool> reporterADemain(Alerte a) async {
    calls.add('reporter:${a.id}');
    return true;
  }

  @override
  Future<bool> changerProgression(Alerte a, String progression) async {
    calls.add('progression:${a.id}:$progression');
    _ouvertes = [for (final x in _ouvertes) x.id == a.id ? x.copyWith(progression: progression) : x];
    notifyListeners();
    return true;
  }

  @override
  Future<bool> creerAlerte(Map<String, dynamic> data) async {
    created.add(data);
    return true;
  }

  @override
  Future<int> creerPlusieurs(List<Map<String, dynamic>> taches) async {
    created.addAll(taches);
    return taches.length;
  }
}

Widget _app(AlertesProvider provider) => MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => _Auth()),
        ChangeNotifierProvider<AlertesProvider>.value(value: provider),
      ],
      child: const MaterialApp(home: AlertesScreen()),
    );

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Alerte _tache(String id, String titre, DateTime date,
        {String type = 'autre', String assigne = '', String progression = 'a_faire', List<ChecklistItem> checklist = const [], String bandeNom = ''}) =>
    Alerte(
      id: id,
      titre: titre,
      message: '',
      type: type,
      dateEcheance: date,
      assigneA: assigne,
      progression: progression,
      checklist: checklist,
      bandeId: bandeNom.isEmpty ? null : 'b1',
      bandeNom: bandeNom,
    );

void main() {
  final now = DateTime(2026, 10, 28, 10); // mercredi

  group('Logique Todo', () {
    test('filtrerTodo : échéances et Mes tâches', () {
      final taches = [
        _tache('1', 'Retard', DateTime(2026, 10, 26)),
        _tache('2', 'Aujourd’hui', DateTime(2026, 10, 28, 15), assigne: 'Moussa Sow'),
        _tache('3', 'Dimanche', DateTime(2026, 11, 1)),
        _tache('4', 'Plus tard', DateTime(2026, 11, 10)),
      ];
      List<String> ids(TodoFiltre f, {bool mine = false}) =>
          filtrerTodo(taches, f, now: now, mesTaches: mine, me: 'moussa sow').map((a) => a.id!).toList();
      expect(ids(TodoFiltre.tout), ['1', '2', '3', '4']);
      expect(ids(TodoFiltre.enRetard), ['1']);
      expect(ids(TodoFiltre.aujourdhui), ['2']);
      expect(ids(TodoFiltre.semaine), ['1', '2', '3']);
      expect(ids(TodoFiltre.tout, mine: true), ['2']);
    });

    test('computeTodoStats', () {
      final s = computeTodoStats(
        [
          _tache('1', 'A', DateTime(2026, 10, 20), type: 'vaccination', assigne: 'Awa'),
          _tache('2', 'B', DateTime(2026, 10, 29), progression: 'en_cours'),
        ],
        [_tache('3', 'C', DateTime(2026, 10, 27))],
        now: now,
      );
      expect(s.aFaire, 1);
      expect(s.enCours, 1);
      expect(s.enRetard, 1);
      expect(s.termineesSemaine, 1);
      expect(s.avancementSemaine, closeTo(33.3, 0.1));
      expect(s.parCategorie, {'vaccination': 1, 'autre': 1});
      expect(s.parPersonne, {'Awa': 1, 'Non assignée': 1});
    });

    test('genererTachesModele planifie à partir de J0', () {
      final modele = todoModeles.firstWhere((m) => m.id == 'bande_chair');
      final taches = genererTachesModele(modele, DateTime(2026, 11, 10), bandeId: 'b1', assigneA: 'Moussa');
      expect(taches, hasLength(modele.taches.length));
      expect(taches.first['dateEcheance'], DateTime(2026, 11, 7, 8).toIso8601String());
      expect(taches.first['checklist'], hasLength(4));
      expect(taches.every((t) => t['bandeId'] == 'b1' && t['assigneA'] == 'Moussa'), isTrue);
      expect(taches.firstWhere((t) => t['titre'] == 'Pesée hebdomadaire')['recurrence'], 'hebdomadaire');
    });

    test('computeTodoEcheances : toute la journée et durée conservée', () {
      final allDay = computeTodoEcheances('aucune', const {}, DateTime(2026, 11, 2, 9), DateTime(2026, 11, 2, 10), true);
      expect(allDay.debut, DateTime(2026, 11, 2));
      expect(allDay.fin, DateTime(2026, 11, 2, 23, 59));
      final fixe = computeTodoEcheances('aucune', const {}, DateTime(2026, 11, 2, 9), DateTime(2026, 11, 2, 8), false);
      expect(fixe.fin, DateTime(2026, 11, 2, 10), reason: 'une fin avant le début est corrigée à +1 h');
    });

    test('Alerte lit les champs Planner et la bande peuplée', () {
      final a = Alerte.fromJson({
        '_id': 'a1',
        'titre': 'Vaccin',
        'message': '',
        'type': 'vaccination',
        'dateEcheance': '2026-11-02T08:00:00.000Z',
        'bandeId': {'_id': 'b1', 'nom': 'B12'},
        'assigneA': 'Awa',
        'progression': 'en_cours',
        'checklist': [
          {'titre': 'Préparer', 'fait': true},
        ],
        'stockId': 's1',
      });
      expect(a.bandeId, 'b1');
      expect(a.bandeNom, 'B12');
      expect(a.progression, 'en_cours');
      expect(a.checklistFaits, 1);
      expect(a.stockId, 's1');
      expect(a.copyWith(clearBande: true).bandeId, isNull);
      expect(a.toJson()['checklist'], hasLength(1));
      expect(Alerte.fromJson({...a.toJson(), '_id': 'a1'}).assigneA, 'Awa');
    });
  });

  testWidgets('Liste : sections, carte riche, terminer avec Annuler et report par glissement', (tester) async {
    _size(tester, const Size(1200, 1000));
    final provider = _FakeTodo(
      ouvertes: [
        _tache('t1', 'Vacciner la bande', _today().subtract(const Duration(days: 1)),
            type: 'vaccination', bandeNom: 'B12', checklist: const [ChecklistItem(titre: 'A', fait: true), ChecklistItem(titre: 'B')]),
        _tache('t2', 'Peser les poulets', _today().add(const Duration(hours: 9)), type: 'pesee'),
      ],
      auto: [
        Alerte(id: 'stock-s1', titre: 'Stock bas: Aliment', message: '', type: 'stock_bas', dateEcheance: _today(), source: 'stock', automatique: true),
      ],
    );
    await tester.pumpWidget(_app(provider));
    await tester.pumpAndSettle();

    expect(find.text('En retard (1)'), findsOneWidget);
    expect(find.text("Aujourd'hui (2)"), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('B12'), findsOneWidget);
    expect(find.text('Stock'), findsWidgets);
    expect(find.byTooltip('Ouvrir la source'), findsOneWidget);

    await tester.tap(find.byTooltip('Marquer comme faite').first);
    await tester.pumpAndSettle();
    expect(provider.calls, ['terminer:t1']);
    expect(find.text('Tâche terminée 🎉'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(provider.calls.last, 'rouvrir:t1:next-1');

    await tester.drag(find.text('Peser les poulets'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(provider.calls.last, 'reporter:t2');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ajout rapide et filtre Mes tâches', (tester) async {
    _size(tester, const Size(1200, 1000));
    final provider = _FakeTodo(ouvertes: [
      _tache('t1', 'Tâche de Awa', _today(), assigne: 'Awa'),
      _tache('t2', 'Ma tâche', _today(), assigne: 'Moussa Sow'),
    ]);
    await tester.pumpWidget(_app(provider));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Demain'));
    await tester.enterText(find.widgetWithText(TextField, 'Ajouter une tâche…'), 'Commander de l’aliment');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(provider.created.single['titre'], 'Commander de l’aliment');
    expect(provider.created.single['touteJournee'], isTrue);
    expect(provider.created.single['assigneA'], 'Moussa Sow');
    expect(DateTime.parse(provider.created.single['dateEcheance']), _today().add(const Duration(days: 1)));

    await tester.tap(find.text('Mes tâches'));
    await tester.pumpAndSettle();
    expect(find.text('Ma tâche'), findsOneWidget);
    expect(find.text('Tâche de Awa'), findsNothing);
  });

  testWidgets('Tableau par avancement : glisser une carte vers « En cours »', (tester) async {
    _size(tester, const Size(1600, 1000));
    final provider = _FakeTodo(ouvertes: [_tache('t1', 'Nettoyer les abreuvoirs', _today())]);
    await tester.pumpWidget(_app(provider));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Tableau'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Par avancement'));
    await tester.pumpAndSettle();
    expect(find.text('En cours'), findsOneWidget);
    expect(find.text('Terminées'), findsOneWidget);

    final gesture = await tester.startGesture(tester.getCenter(find.text('Nettoyer les abreuvoirs')), kind: PointerDeviceKind.touch);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveTo(tester.getCenter(find.byKey(const ValueKey('kanban-column-en_cours'))));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(provider.calls, ['progression:t1:en_cours']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Graphiques et modèles de plan', (tester) async {
    _size(tester, const Size(1400, 1000));
    final provider = _FakeTodo(ouvertes: [
      _tache('t1', 'A', _today().subtract(const Duration(days: 2)), type: 'vaccination'),
      _tache('t2', 'B', _today(), progression: 'en_cours'),
    ]);
    await tester.pumpWidget(_app(provider));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Graphiques'));
    await tester.pumpAndSettle();
    expect(find.text('Ouvertes'), findsOneWidget);
    expect(find.text('Par catégorie'), findsOneWidget);
    expect(find.text('Vaccination'), findsOneWidget);

    await tester.tap(find.byTooltip('Modèles de plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vide sanitaire du bâtiment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Créer 4 tâches'));
    await tester.pumpAndSettle();
    expect(provider.created, hasLength(4));
    expect(find.text('4 tâches créées à partir du modèle'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Toutes les vues tiennent sur un téléphone', (tester) async {
    _size(tester, const Size(390, 844));
    final provider = _FakeTodo(ouvertes: [
      _tache('t1', 'Une tâche au titre assez long pour vérifier le rendu sur téléphone', _today(),
          type: 'controle_sanitaire', bandeNom: 'Bande de démarrage', assigne: 'Moussa Sow',
          checklist: const [ChecklistItem(titre: 'A')]),
    ]);
    await tester.pumpWidget(_app(provider));
    await tester.pumpAndSettle();
    for (final vue in ['Tableau', 'Planning', 'Graphiques', 'Liste']) {
      await tester.tap(find.byTooltip(vue));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: vue);
    }
  });
}
