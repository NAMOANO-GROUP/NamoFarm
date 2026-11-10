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
    test('suites de semaines consécutives', () {
      final l = DateTime(2026, 3, 2);
      DateTime s(int n) => DateTime(l.year, l.month, l.day + 7 * n);
      final suites = roadmapSuitesDeSemaines([s(4), s(0), s(1), s(1), s(6), s(5)]);
      expect(suites.map((x) => x.length).toList(), [2, 3]);
      expect(suites.first.first, s(0));
      expect(suites.last.first, s(4));
      expect(roadmapSuitesDeSemaines([DateTime(2026, 3, 4)]).single.single, DateTime(2026, 3, 2)); // ramené au lundi
    });

    test('colorer plusieurs semaines : une marque par suite, et remplacement des couleurs existantes', () {
      DateTime s(int n) => DateTime(2026, 3, 2 + 7 * n);
      final existantes = [RoadmapWeekMark(id: 'a', start: s(0), weeks: 4, color: Colors.red, label: 'Fête')];

      // Retirer la 2e semaine scinde la marque en deux.
      final coupee = roadmapRetirerSemaines(existantes, [s(1)]);
      expect(coupee.map((m) => (m.start, m.weeks)).toList(), [(s(0), 1), (s(2), 2)]);
      expect(coupee.map((m) => m.id).toSet(), hasLength(2));
      expect(coupee.every((m) => m.label == 'Fête' && m.color == Colors.red), isTrue);

      // Colorer s1, s2 et s5 en vert : s1 et s2 remplacent le rouge, s5 est à part.
      final res = roadmapAppliquerCouleur(existantes, [s(5), s(1), s(2)], color: Colors.green, label: 'Calme', idBase: 'n');
      bool verte(DateTime l) => res.any((m) => m.couvre(l) && m.color == Colors.green);
      bool rouge(DateTime l) => res.any((m) => m.couvre(l) && m.color == Colors.red);
      expect([verte(s(1)), verte(s(2)), verte(s(5))], [true, true, true]);
      expect([rouge(s(0)), rouge(s(3))], [true, true]);
      expect([rouge(s(1)), rouge(s(2))], [false, false]);
      expect(res.where((m) => m.color == Colors.green), hasLength(2));
      expect(res.map((m) => m.id).toSet(), hasLength(res.length));
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
    // Pop-up au milieu de l'écran (et non une feuille collée en bas).
    final centre = tester.getCenter(find.byType(Dialog));
    expect(centre.dy, closeTo(844 / 2, 80));
    expect(centre.dx, closeTo(390 / 2, 1));

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Année suivante'));
    await tester.pumpAndSettle();
    expect(find.text('${n.year + 1}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Calendrier : numéros de semaine colorés pour les semaines marquées', (tester) async {
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
    final suivante = DateTime(lundi.year, lundi.month, lundi.day + 7);
    final cleSuivante = ValueKey('roadmap-cal-sem-${suivante.year}-${suivante.month}-${suivante.day}');
    Color? fond(Key k) => ((tester.widget<Container>(find.descendant(of: find.byKey(k), matching: find.byType(Container)).first)).decoration! as BoxDecoration).color;
    final bleu = roadmapCouleursMarques[5];

    expect(find.text('${roadmapNumeroSemaine(lundi)}'), findsWidgets);
    expect(fond(cle), isNot(bleu.withValues(alpha: 0.9)));

    await tester.ensureVisible(find.byKey(cle));
    await tester.tap(find.byKey(cle));
    await tester.pumpAndSettle();
    expect(find.text('Semaine ${roadmapNumeroSemaine(lundi)}'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Tabaski');
    await tester.tap(find.byKey(ValueKey('roadmap-couleur-${bleu.toARGB32()}')));
    await tester.pump();
    await tester.tap(find.byTooltip('Plus de semaines'));
    await tester.pump();
    expect(find.text('Semaines ${roadmapNumeroSemaine(lundi)} à ${roadmapNumeroSemaine(lundi) + 1}'), findsOneWidget);
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    // Seul le numéro est coloré (et assez foncé) : plus de trait sous la semaine.
    expect(fond(cle), bleu.withValues(alpha: 0.9));
    await tester.ensureVisible(find.byKey(cleSuivante));
    expect(fond(cleSuivante), bleu.withValues(alpha: 0.9));
    expect(find.byKey(ValueKey('roadmap-cal-trait-${lundi.year}-${lundi.month}-${lundi.day}')), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('roadmap.productionPlans'), contains('Tabaski'));

    // La couleur se retire depuis la fiche de la semaine.
    await tester.ensureVisible(find.byKey(cle));
    await tester.tap(find.byKey(cle));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Retirer la couleur'), findsOneWidget);
    await tester.tap(find.byTooltip('Retirer la couleur'));
    await tester.pumpAndSettle();
    expect(fond(cle), isNot(bleu.withValues(alpha: 0.9)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Calendrier : sélection de plusieurs semaines puis couleur commune', (tester) async {
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

    ValueKey<String> cleSemaine(DateTime l) => ValueKey('roadmap-cal-sem-${l.year}-${l.month}-${l.day}');
    Finder sem(DateTime l) => find.byKey(cleSemaine(l)).first; // une semaine à cheval sur deux mois apparaît deux fois
    Color? fond(DateTime l) =>
        ((tester.widget<Container>(find.descendant(of: sem(l), matching: find.byType(Container)).first)).decoration! as BoxDecoration).color;
    final a = roadmapLundi(DateTime(n.year, 3, 15));
    final b = DateTime(a.year, a.month, a.day + 7);
    final c = DateTime(a.year, a.month, a.day + 21); // non consécutive
    final vert = roadmapCouleursMarques[3];

    expect(find.byKey(const ValueKey('roadmap-cal-selection')), findsNothing);
    await tester.ensureVisible(sem(a));
    await tester.longPress(sem(a));
    await tester.pumpAndSettle();
    expect(find.text('1 semaine sélectionnée'), findsOneWidget);

    // Une fois la sélection commencée, un simple toucher ajoute ou retire une semaine.
    for (final l in [b, c]) {
      await tester.ensureVisible(sem(l));
      await tester.tap(sem(l));
      await tester.pumpAndSettle();
    }
    expect(find.text('3 semaines sélectionnées'), findsOneWidget);
    await tester.tap(sem(b));
    await tester.pumpAndSettle();
    expect(find.text('2 semaines sélectionnées'), findsOneWidget);
    // Les boutons sont en haut : barre d'action au-dessus du calendrier.
    expect(tester.getTopLeft(find.byKey(const ValueKey('roadmap-cal-selection'))).dy, lessThan(120));
    await tester.tap(sem(b));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Colorer'));
    await tester.pumpAndSettle();
    expect(find.text('3 semaines sélectionnées'), findsOneWidget); // la fiche remplace la barre du bas
    expect(find.byKey(const ValueKey('roadmap-cal-selection')), findsNothing);
    expect(find.byTooltip('Plus de semaines'), findsNothing);
    await tester.enterText(find.byType(TextField), 'Fêtes');
    await tester.tap(find.byKey(ValueKey('roadmap-couleur-${vert.toARGB32()}')));
    await tester.pump();
    // « Enregistrer » est en haut de la fiche, au-dessus des couleurs.
    expect(tester.getCenter(find.text('Enregistrer')).dy, lessThan(tester.getCenter(find.byKey(ValueKey('roadmap-couleur-${vert.toARGB32()}'))).dy));
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('roadmap-cal-selection')), findsNothing);
    for (final l in [a, b, c]) {
      await tester.ensureVisible(sem(l));
      expect(fond(l), vert.withValues(alpha: 0.9));
    }
    final entre = DateTime(a.year, a.month, a.day + 14);
    await tester.ensureVisible(sem(entre));
    expect(fond(entre), isNot(vert.withValues(alpha: 0.9)));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('roadmap.productionPlans'), contains('Fêtes'));

    // Annuler la sélection n'enregistre rien.
    await tester.longPress(sem(entre));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('roadmap-cal-selection')), findsNothing);
    expect(fond(entre), isNot(vert.withValues(alpha: 0.9)));
    expect(tester.takeException(), isNull);
  });
}
