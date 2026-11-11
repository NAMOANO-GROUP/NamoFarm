import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namofarm/screens/roadmap_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

RoadmapTask _t(String id, DateTime debut, DateTime fin, {List<RoadmapTask> sous = const [], bool groupe = true}) =>
    RoadmapTask(id: id, title: 'Tâche $id', start: debut, end: fin, color: Colors.blue, group: groupe, subTasks: sous);

void main() {
  group('Logique de la roadmap', () {
    test('dates courtes, durée et période en français', () {
      expect(roadmapDateCourte(DateTime(2026, 8, 7)), '7 août');
      expect(roadmapDureeJours(DateTime(2026, 8, 7), DateTime(2026, 11, 4)), 90);
      expect(roadmapPeriode(DateTime(2026, 8, 7), DateTime(2026, 11, 4)), '7 août → 4 nov. · 90 j');
      expect(roadmapPeriode(DateTime(2026, 12, 1), DateTime(2027, 1, 31)), '1 déc. 2026 → 31 janv. 2027 · 62 j');
      expect(roadmapMoisCourts[7], 'AOÛT');
    });

    test('avancement d’une tâche', () {
      final t = _t('a', DateTime(2026, 1, 1), DateTime(2026, 1, 10));
      expect(roadmapAvancement(t, now: DateTime(2025, 12, 31)), 0);
      expect(roadmapAvancement(t, now: DateTime(2026, 1, 5, 18)), 0.45);
      expect(roadmapAvancement(t, now: DateTime(2026, 1, 10)), lessThan(1), reason: 'dernier jour : pas encore terminée');
      expect(roadmapAvancement(t, now: DateTime(2026, 1, 11)), 1);
    });

    test('charge par mois : tâches feuilles qui couvrent chaque mois', () {
      final plan = ProductionPlan(
        id: 'p',
        name: 'P',
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 4, 30),
        tasks: [
          _t('a', DateTime(2026, 1, 15), DateTime(2026, 2, 10)),
          _t('g', DateTime(2026, 1, 1), DateTime(2026, 4, 30), sous: [
            _t('s1', DateTime(2026, 2, 1), DateTime(2026, 3, 31), groupe: false),
            _t('s2', DateTime(2026, 3, 15), DateTime(2026, 3, 20), groupe: false),
          ]),
        ],
      );
      expect(roadmapFeuilles(plan.tasks).map((t) => t.id), ['a', 's1', 's2']);
      expect(roadmapChargeParMois(plan), [1, 2, 2, 0]);
    });
  });

  group('Écran Roadmap', () {
    void taille(WidgetTester tester, Size s) {
      tester.view.physicalSize = s;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    Map<String, Object> plan(DateTime debut, DateTime fin, List<Map<String, dynamic>> taches) => {
          'roadmap.productionPlans': jsonEncode([
            {
              'id': 'plan-1',
              'name': 'Production',
              'start': debut.toIso8601String(),
              'end': fin.toIso8601String(),
              'tasks': taches,
              'highlightedDates': [],
            },
          ]),
          'roadmap.selectedPlanId': 'plan-1',
        };

    Map<String, dynamic> tache(String id, DateTime d, DateTime f, {List<Map<String, dynamic>> jalons = const []}) => {
          'id': id,
          'title': 'Bande $id',
          'start': d.toIso8601String(),
          'end': f.toIso8601String(),
          'color': Colors.blue.toARGB32(),
          'group': true,
          'milestones': jalons,
          'subTasks': [],
        };

    testWidgets('Téléphone : icônes seules, aujourd’hui, dates sur la barre, charge et fiche de tâche', (tester) async {
      taille(tester, const Size(390, 844));
      final n = DateTime.now();
      final debut = DateTime(n.year, n.month - 2, 1);
      final fin = DateTime(n.year, n.month + 9, 28);
      final t1d = DateTime(n.year, n.month - 1, 5);
      final t1f = DateTime(n.year, n.month + 1, 20);
      SharedPreferences.setMockInitialValues(plan(debut, fin, [tache('B1', t1d, t1f)]));

      await tester.pumpWidget(const MaterialApp(home: RoadmapScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Production'), findsOneWidget);
      expect(find.byTooltip('Ajouter une tâche, un jalon ou une date clé'), findsOneWidget);
      expect(find.byTooltip('Aller à aujourd’hui'), findsOneWidget);
      expect(find.byTooltip('Aujourd’hui'), findsOneWidget);

      // Bouton « + » lisible : icône de la couleur « sur primaire », pas celle de la barre du haut.
      final plus = find.descendant(
        of: find.byTooltip('Ajouter une tâche, un jalon ou une date clé'),
        matching: find.byIcon(Icons.add),
      );
      final ctx = tester.element(plus);
      expect(IconTheme.of(ctx).color, Theme.of(ctx).colorScheme.onPrimary);
      expect(find.textContaining(roadmapPeriode(t1d, t1f)), findsWidgets);
      expect(find.byKey(const ValueKey('roadmap-charge')), findsOneWidget);
      expect(find.text('1'), findsWidgets);

      // Barre alignée sur l'en-tête : début du planning = bord gauche du premier mois.
      final mois0 = tester.getRect(find.byKey(ValueKey('roadmap-month-${debut.year}-${debut.month}')));
      final ligne = tester.getRect(find.byKey(const ValueKey('roadmap-task-timeline-B1')));
      expect((ligne.left - mois0.left).abs(), lessThan(0.5));
      expect(find.text('Supprimer tous les plannings'), findsNothing);

      // Zoom par liste de choix.
      final avant = tester.getSize(find.byKey(ValueKey('roadmap-month-${n.year}-${n.month}'))).width;
      await tester.tap(find.byTooltip('Zoom'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckedPopupMenuItem<double>, 'Trimestre'));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(ValueKey('roadmap-month-${n.year}-${n.month}'))).width, closeTo(avant / 2, 0.1));

      // Toucher la tâche ouvre sa fiche avec les actions.
      await tester.tap(find.text('Bande B1'));
      await tester.pumpAndSettle();
      expect(find.textContaining('En cours ·'), findsOneWidget);
      expect(find.text('Modifier'), findsOneWidget);
      expect(find.text('Ajouter un jalon'), findsOneWidget);
      // Fiche au milieu de l'écran, pas collée en bas.
      final fiche = find.byKey(const ValueKey('roadmap-fiche-tache'));
      final ecran = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(tester.getCenter(fiche).dy, closeTo(ecran.height / 2, 40));
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Supprimer'));
      await tester.pumpAndSettle();
      expect(find.text('Bande B1'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Changer de planning depuis le titre', (tester) async {
      taille(tester, const Size(390, 844));
      final prefs = {
        'roadmap.productionPlans': jsonEncode([
          {'id': 'a', 'name': 'Production', 'start': '2026-01-01T00:00:00.000', 'end': '2026-12-31T00:00:00.000', 'tasks': [], 'highlightedDates': []},
          {'id': 'b', 'name': 'Investissements', 'start': '2027-01-01T00:00:00.000', 'end': '2027-06-30T00:00:00.000', 'tasks': [], 'highlightedDates': []},
        ]),
        'roadmap.selectedPlanId': 'a',
      };
      SharedPreferences.setMockInitialValues(prefs);
      await tester.pumpWidget(const MaterialApp(home: RoadmapScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Changer de planning'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckedPopupMenuItem<String>, 'Investissements'));
      await tester.pumpAndSettle();
      expect(find.text('Investissements'), findsOneWidget);
      expect(find.text('1 janv. 2027 → 30 juin 2027'), findsOneWidget);

      await tester.tap(find.byTooltip('Plus d’options'));
      await tester.pumpAndSettle();
      expect(find.text('Supprimer tous les plannings'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
