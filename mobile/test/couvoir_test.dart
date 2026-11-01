import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namofarm/models/couvee.dart';
import 'package:namofarm/providers/reproduction_provider.dart';
import 'package:namofarm/screens/couvoir/couvee_detail_screen.dart';
import 'package:namofarm/screens/reproduction_screen.dart';
import 'package:namofarm/utils/couvoir.dart';
import 'package:provider/provider.dart';

DateTime _jour(int delta) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day + delta, 12);
}

Couvee _couvee(
  String id, {
  String race = 'Poule locale',
  int age = 12,
  int oeufs = 100,
  int? fertiles,
  int? eclos,
  int? viables,
  String statut = 'en_incubation',
}) =>
    Couvee(
      id: id,
      code: 'C-$id',
      race: race,
      dateMiseIncubation: _jour(-age),
      nbOeufsIncubes: oeufs,
      nbOeufsFertiles: fertiles ?? oeufs,
      nbEclos: eclos,
      nbPoussinsViables: viables,
      dateEclosion: eclos == null ? null : _jour(-age + 21),
      statut: statut,
    );

class _FakeRepro extends ReproductionProvider {
  _FakeRepro(this._liste);
  final List<Couvee> _liste;
  final List<Map<String, dynamic>> majs = [];

  @override
  List<Couvee> get couvees => _liste;
  @override
  List<Couvee> get actives => _liste.where((c) => c.statut != 'termine' && c.statut != 'annule').toList();
  @override
  List<Couvee> get historique => _liste.where((c) => c.statut == 'termine' || c.statut == 'annule').toList();
  @override
  bool get isLoading => false;
  @override
  Future<void> charger() async {}
  @override
  Future<bool> mettreAJour(String id, Map<String, dynamic> data) async {
    majs.add({'id': id, ...data});
    return true;
  }
}

Widget _app(Widget home, ReproductionProvider p) =>
    ChangeNotifierProvider<ReproductionProvider>.value(value: p, child: MaterialApp(home: home));

void _telephone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('Logique du couvoir', () {
    test('durée selon l’espèce et calendrier des étapes', () {
      expect(incubationPour('Poule locale').jours, 21);
      expect(incubationPour('Pintade galor').jours, 27);
      expect(incubationPour('Canard de Barbarie').jours, 35);
      expect(incubationPour('canard pékin').jours, 28);
      expect(incubationPour('Caille japonaise').jours, 17);
      expect(incubationPour('').espece, 'Poule');
      expect(incubationPour('Poule soie').jours, 21, reason: '« soie » contient « oie »');
      expect(incubationPour('Soie').jours, 21);
      expect(incubationPour('Oies de Guinée').jours, 30);
      expect(incubationPour('Pintades').jours, 27);

      final c = _couvee('1', age: 12);
      final etapes = etapesCouvee(c);
      expect(etapes.map((e) => e.jour), [0, 7, 14, 18, 21]);
      final av = avancementCouvee(c)!;
      expect(av.age, 12);
      expect(av.joursRestants, 9);
      expect(av.libelleEcheance, 'Éclosion dans 9 j');
      expect(av.etapeEnCours!.titre, 'Premier mirage');
      expect(av.prochaineEtape!.titre, 'Second mirage');

      final pintade = avancementCouvee(_couvee('2', race: 'Pintade', age: 27))!;
      expect(pintade.libelleEcheance, 'Éclosion aujourd’hui');
      final retard = _couvee('3', age: 25);
      expect(avancementCouvee(retard)!.enRetard, isTrue);
      expect(alertesCouvee(retard), [AlerteCouvee.eclosionASaisir]);
    });

    test('entonnoir, taux et alertes de résultat', () {
      final c = _couvee('1', oeufs: 100, fertiles: 90, eclos: 60, viables: 50, statut: 'eclos', age: 25);
      final e = entonnoirCouvee(c);
      expect(e.map((x) => x.nombre), [100, 90, 60, 50]);
      expect(e.map((x) => x.pertes), [0, 10, 30, 10]);
      expect(e[2].pctIncubes, 60);
      expect(tauxEclosionIncubes(c), 60);
      expect(tauxViabilite(c), closeTo(83.33, 0.01));
      expect(alertesCouvee(c), [AlerteCouvee.eclosionFaible, AlerteCouvee.viabiliteFaible]);

      // Fertiles = incubés (mirage non saisi) : pas d'étage « fertiles ».
      expect(entonnoirCouvee(_couvee('2', eclos: 85, statut: 'eclos')).length, 2);
    });

    test('résumé : prochaine éclosion et taux sur 12 mois', () {
      final r = resumeCouvoir([
        _couvee('a', age: 5, oeufs: 60),
        _couvee('b', age: 15, oeufs: 40),
        _couvee('c', age: 30, oeufs: 100, eclos: 80, viables: 76, statut: 'termine'),
        _couvee('d', age: 500, oeufs: 100, eclos: 10, statut: 'termine'),
      ]);
      expect(r.enCours, 2);
      expect(r.oeufsEnIncubation, 100);
      expect(r.prochaine!.code, 'C-b');
      expect(r.tauxEclosion12Mois, 80);
      expect(r.tauxViabilite12Mois, 95);
      expect(r.poussins12Mois, 76);

      final mixte = resumeCouvoir([
        _couvee('x', age: 40, eclos: 100, statut: 'termine'),
        _couvee('y', age: 40, eclos: 50, viables: 48, statut: 'termine'),
      ]);
      expect(mixte.poussins12Mois, 148);
    });
  });

  group('Écrans du couvoir', () {
    testWidgets('Liste sur téléphone : résumé, compte à rebours et saisie de l’éclosion', (tester) async {
      _telephone(tester);
      final p = _FakeRepro([
        _couvee('1', age: 12),
        _couvee('2', age: 19, race: 'Poule'),
        _couvee('3', age: 40, eclos: 90, viables: 88, statut: 'termine'),
      ]);
      await tester.pumpWidget(_app(const ReproductionScreen(), p));
      await tester.pumpAndSettle();

      expect(find.text('En cours (2)'), findsOneWidget);
      expect(find.text('J-2'), findsOneWidget, reason: 'prochaine éclosion = couvée C-2');
      expect(find.text('90 %'), findsOneWidget);
      expect(find.text('Éclosion dans 2 j'), findsOneWidget);
      expect(find.text('Éclosion dans 9 j'), findsOneWidget);
      expect(find.textContaining('Prochaine étape : Éclosion'), findsOneWidget);

      await tester.tap(find.text('Saisir l’éclosion').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Poussins éclos'), '85');
      await tester.pump();
      expect(find.textContaining('Taux d’éclosion : 85.0 %'), findsOneWidget);
      await tester.tap(find.text('Enregistrer l’éclosion'));
      await tester.pumpAndSettle();
      expect(p.majs.single['nbEclos'], 85);
      expect(p.majs.single['statut'], 'eclos');

      await tester.tap(find.text('Historique (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Taux d’éclosion des dernières couvées'), findsOneWidget);
      expect(find.text('Éclosion 90.0 % des œufs'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Fiche couvée : entonnoir, objectifs et frise', (tester) async {
      _telephone(tester);
      final c = _couvee('1', oeufs: 100, fertiles: 90, eclos: 70, viables: 68, statut: 'eclos', age: 22);
      await tester.pumpWidget(_app(CouveeDetailScreen(couvee: c), _FakeRepro([c])));
      await tester.pumpAndSettle();

      expect(find.text('100 œufs'), findsOneWidget);
      expect(find.text('−10 œufs clairs'), findsOneWidget);
      expect(find.text('−20 non éclos'), findsOneWidget);
      await tester.dragUntilVisible(find.text('Taux d’éclosion'), find.byType(ListView), const Offset(0, -200));
      expect(find.text('70.0 %'), findsOneWidget);
      expect(find.textContaining('10.0 points en dessous'), findsOneWidget);
      await tester.dragUntilVisible(find.text('J21 · Éclosion'), find.byType(ListView), const Offset(0, -200));
      expect(find.text('J7 · Premier mirage'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
