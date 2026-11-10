import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namofarm/screens/planification/roadmap_calendrier.dart';
import 'package:namofarm/screens/roadmap_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

RoadmapTask _t(String id, DateTime d, DateTime f, {List<RoadmapMilestone> jalons = const [], List<RoadmapTask> sous = const []}) =>
    RoadmapTask(id: id, title: 'Tâche $id', start: d, end: f, color: Colors.blue, milestones: jalons, subTasks: sous);

void main() {
  group('Logique du calendrier', () {
    test('cases d’un mois : lundi en premier, 6 semaines', () {
      final cases = roadmapCasesMois(2026, 2); // 1er février 2026 = dimanche
      expect(cases, hasLength(42));
      expect(cases.take(6).every((c) => c == null), isTrue);
      expect(cases[6], DateTime(2026, 2, 1));
      expect(cases.whereType<DateTime>(), hasLength(28));
      expect(roadmapCasesMois(2026, 6).first, DateTime(2026, 6, 1)); // lundi
    });

    test('tâches du jour : bornes incluses', () {
      final t = _t('a', DateTime(2026, 3, 10), DateTime(2026, 3, 12));
      expect(roadmapTachesDuJour([t], DateTime(2026, 3, 9)), isEmpty);
      expect(roadmapTachesDuJour([t], DateTime(2026, 3, 10)), [t]);
      expect(roadmapTachesDuJour([t], DateTime(2026, 3, 12, 18)), [t]);
      expect(roadmapTachesDuJour([t], DateTime(2026, 3, 13)), isEmpty);
    });

    test('jalons du jour : y compris sur les sous-tâches', () {
      final m = RoadmapMilestone(id: 'm', title: 'Vaccin', date: DateTime(2026, 3, 11), color: Colors.red);
      final sous = _t('s', DateTime(2026, 3, 1), DateTime(2026, 3, 30), jalons: [m]);
      final parent = _t('p', DateTime(2026, 3, 1), DateTime(2026, 3, 30), sous: [sous]);
      expect(roadmapJalonsDuJour([parent], DateTime(2026, 3, 11)), [m]);
      expect(roadmapJalonsDuJour([parent], DateTime(2026, 3, 12)), isEmpty);
    });

    test('numéro de semaine ISO 8601', () {
      expect(roadmapNumeroSemaine(DateTime(2026, 1, 1)), 1); // jeudi
      expect(roadmapNumeroSemaine(DateTime(2026, 12, 31)), 53);
      expect(roadmapNumeroSemaine(DateTime(2027, 1, 1)), 53); // vendredi : encore la semaine 53 de 2026
      expect(roadmapNumeroSemaine(DateTime(2027, 1, 4)), 1);
      expect(roadmapNumeroSemaine(DateTime(2025, 12, 29)), 1); // lundi, semaine 1 de 2026
      expect(roadmapNumeroSemaine(DateTime(2026, 3, 13)), 11);
      expect(roadmapLundi(DateTime(2026, 3, 15)), DateTime(2026, 3, 9)); // dimanche
    });

    test('semaine marquée : couverture, JSON et conservation dans le planning', () {
      final m = RoadmapWeekMark(id: 'x', start: DateTime(2026, 3, 11), weeks: 2, color: Colors.orange, label: 'Tabaski');
      expect(m.start, DateTime(2026, 3, 11)); // brut tant qu'il n'est pas relu
      final relu = RoadmapWeekMark.fromJson(m.toJson());
      expect(relu.start, DateTime(2026, 3, 9)); // ramené au lundi
      expect(relu.couvre(DateTime(2026, 3, 2)), isFalse);
      expect(relu.couvre(DateTime(2026, 3, 9)), isTrue);
      expect(relu.couvre(DateTime(2026, 3, 16)), isTrue);
      expect(relu.couvre(DateTime(2026, 3, 23)), isFalse);
      expect(relu.label, 'Tabaski');
      expect(relu.color.toARGB32(), Colors.orange.toARGB32());

      final plan = ProductionPlan(id: 'p', name: 'P', start: DateTime(2026, 1, 1), end: DateTime(2026, 12, 31), weekMarks: [relu]);
      final copie = ProductionPlan.fromJson(plan.toJson());
      expect(copie.weekMarks, hasLength(1));
      expect(plan.copyWith(weekMarks: const []).weekMarks, isEmpty);
      expect(ProductionPlan.fromJson({'id': 'a', 'name': 'a'}).weekMarks, isEmpty);
    });
  });

  testWidgets('Roadmap : bascule en calendrier annuel et détail d’un jour', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final n = DateTime.now();
    final debut = DateTime(n.year, 1, 1);
    final t1 = DateTime(n.year, 1, 10);
    final t1f = DateTime(n.year, 1, 20);
    SharedPreferences.setMockInitialValues({
      'roadmap.productionPlans': jsonEncode([
        {
          'id': 'plan-1',
          'name': 'Production',
          'start': debut.toIso8601String(),
          'end': DateTime(n.year + 1, 12, 31).toIso8601String(),
          'tasks': [
            {'id': 'B1', 'title': 'Bande B1', 'start': t1.toIso8601String(), 'end': t1f.toIso8601String(), 'color': Colors.green.toARGB32(), 'group': true, 'milestones': [], 'subTasks': []},
          ],
          'highlightedDates': [],
        },
      ]),
      'roadmap.selectedPlanId': 'plan-1',
    });

    await tester.pumpWidget(const MaterialApp(home: RoadmapScreen()));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('roadmap-calendrier')), findsNothing);

    await tester.tap(find.byTooltip('Vue calendrier'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('roadmap-calendrier')), findsOneWidget);
    expect(find.text('${n.year}'), findsOneWidget);
    expect(find.text('Janvier'), findsOneWidget);
    expect(find.byType(FilterChip), findsNothing);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('roadmap.vue'), 'calendrier');

    final jour = find.byKey(ValueKey('roadmap-cal-jour-${n.year}-1-12'));
    final decoration = tester.widget<Container>(jour).decoration! as BoxDecoration;
    expect(decoration.color, isNotNull);

    await tester.tap(jour);
    await tester.pumpAndSettle();
    expect(find.text('Bande B1'), findsWidgets);
    expect(find.text('Ajouter une tâche à cette date'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Année suivante'));
    await tester.pumpAndSettle();
    expect(find.text('${n.year + 1}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Calendrier : numéros de semaine et trait de couleur sur une semaine', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final n = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'roadmap.vue': 'calendrier',
      'roadmap.productionPlans': jsonEncode([
        {
          'id': 'plan-1',
          'name': 'Production',
          'start': DateTime(n.year, 1, 1).toIso8601String(),
          'end': DateTime(n.year, 12, 31).toIso8601String(),
          'tasks': [],
          'highlightedDates': [],
        },
      ]),
      'roadmap.selectedPlanId': 'plan-1',
    });
    await tester.pumpWidget(const MaterialApp(home: RoadmapScreen()));
    await tester.pumpAndSettle();

    final lundi = roadmapLundi(DateTime(n.year, 3, 15));
    final cle = ValueKey('roadmap-cal-sem-${lundi.year}-${lundi.month}-${lundi.day}');
    final trait = ValueKey('roadmap-cal-trait-${lundi.year}-${lundi.month}-${lundi.day}');
    expect(find.text('${roadmapNumeroSemaine(lundi)}'), findsWidgets);
    expect(find.byKey(trait), findsNothing);

    await tester.ensureVisible(find.byKey(cle));
    await tester.tap(find.byKey(cle));
    await tester.pumpAndSettle();
    expect(find.text('Semaine ${roadmapNumeroSemaine(lundi)}'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Tabaski');
    await tester.tap(find.byKey(ValueKey('roadmap-couleur-${roadmapCouleursMarques[5].toARGB32()}')));
    await tester.pump();
    await tester.tap(find.byTooltip('Plus de semaines'));
    await tester.pump();
    expect(find.text('Semaines ${roadmapNumeroSemaine(lundi)} à ${roadmapNumeroSemaine(lundi) + 1}'), findsOneWidget);
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.byKey(trait), findsOneWidget);
    final suivante = DateTime(lundi.year, lundi.month, lundi.day + 7);
    expect(find.byKey(ValueKey('roadmap-cal-trait-${suivante.year}-${suivante.month}-${suivante.day}')), findsWidgets);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('roadmap.productionPlans'), contains('Tabaski'));

    // Un jour de cette semaine rappelle le libellé ; le trait se retire depuis la fiche de la semaine.
    await tester.ensureVisible(find.byKey(cle));
    await tester.tap(find.byKey(cle));
    await tester.pumpAndSettle();
    expect(find.text('Retirer le trait'), findsOneWidget);
    await tester.tap(find.text('Retirer le trait'));
    await tester.pumpAndSettle();
    expect(find.byKey(trait), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
