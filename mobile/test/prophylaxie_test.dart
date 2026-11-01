import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namofarm/models/alerte.dart';
import 'package:namofarm/models/bande.dart';
import 'package:namofarm/models/sante.dart';
import 'package:namofarm/providers/alertes_provider.dart';
import 'package:namofarm/providers/auth_provider.dart';
import 'package:namofarm/providers/bandes_provider.dart';
import 'package:namofarm/providers/sante_provider.dart';
import 'package:namofarm/screens/sante_screen.dart';
import 'package:namofarm/utils/crm_labels.dart';
import 'package:namofarm/utils/prophylaxie.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

DateTime _jour(int delta, {int heure = 0}) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day + delta, heure);
}

EvenementPrevisionnel _ev(String id, int delta, String desc, {String statut = 'planifie', DateTime? fait}) =>
    EvenementPrevisionnel(
      id: id,
      type: 'vaccination',
      datePrevue: DateTime.utc(_jour(delta).year, _jour(delta).month, _jour(delta).day),
      description: desc,
      statut: statut,
      dateRealisation: fait,
    );

Bande _bande({List<EvenementPrevisionnel> evs = const [], int age = 10, String id = 'b1', String nom = 'B-001'}) => Bande(
      id: id,
      nom: nom,
      dateOuverture: _jour(-age),
      statut: 'ouverte',
      typeVolaille: 'poulet_local_ameliore',
      race: '',
      nombreInitial: 400,
      nombreActuel: 380,
      evenementsPrevisionnels: evs,
    );

TraitementSanitaire _traitement(String id, int delta, int delai, {String produit = 'Amoxicilline', String? bandeId = 'b1'}) =>
    TraitementSanitaire(id: id, bandeId: bandeId, dateTraitement: _jour(delta, heure: 12), produit: produit, delaiAttenteJours: delai);

class _Auth extends AuthProvider {
  @override
  bool get isAdmin => true;
}

class _FakeBandes extends BandesProvider {
  _FakeBandes(this._liste);
  final List<Bande> _liste;
  final List<String> terminees = [];
  @override
  List<Bande> get bandesActives => _liste;
  @override
  List<Bande> get bandesHistorique => const [];
  @override
  Future<void> chargerBandesActives() async {}
  @override
  Future<bool> terminerEvenementPrevisionnel(
    String bandeId,
    String eventId, {
    String commentairesRealisation = '',
    String? prophylaxieStockId,
    String prophylaxieType = '',
    double prophylaxieQuantite = 0,
  }) async {
    terminees.add('$bandeId/$eventId');
    return true;
  }
}

class _FakeSante extends SanteProvider {
  _FakeSante({this.protos = const [], this.traits = const []});
  List<ProtocoleVaccinal> protos;
  final List<TraitementSanitaire> traits;
  final List<Map<String, dynamic>> crees = [];
  final List<Map<String, dynamic>> traitementsCrees = [];
  @override
  List<ProtocoleVaccinal> get protocoles => protos;
  @override
  List<TraitementSanitaire> get traitements => traits;
  @override
  bool get isLoading => false;
  @override
  Future<void> charger() async {}
  @override
  Future<bool> creerProtocole(Map<String, dynamic> data) async {
    crees.add(data);
    return true;
  }

  @override
  Future<bool> creerTraitement(Map<String, dynamic> data) async {
    traitementsCrees.add(data);
    return true;
  }
}

class _FakeAlertes extends AlertesProvider {
  @override
  List<Alerte> get alertes => const [];
}

Widget _app(_FakeBandes bandes, _FakeSante sante) => MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => _Auth()),
        ChangeNotifierProvider<BandesProvider>.value(value: bandes),
        ChangeNotifierProvider<SanteProvider>.value(value: sante),
        ChangeNotifierProvider<AlertesProvider>(create: (_) => _FakeAlertes()),
      ],
      child: const MaterialApp(home: SanteScreen()),
    );

void _telephone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('Logique de la prophylaxie', () {
    test('interventions à faire, échéances et âge', () {
      final b = _bande(age: 10, evs: [
        _ev('e1', -2, 'J8 - Vaccin Newcastle'),
        _ev('e2', 0, 'J10 - Vitamines'),
        _ev('e3', 30, 'J40 - Variole'),
        _ev('e4', -5, 'J5 - Fait', statut: 'termine', fait: _jour(-5, heure: 9)),
      ]);
      final a = interventionsAFaire([b]);
      expect(a.map((x) => x.evenement.id), ['e1', 'e2', 'e3']);
      expect(a.first.ageJours, 8);
      expect(a.first.echeance(), DueBucket.enRetard);
      expect(a[1].echeance(), DueBucket.aujourdhui);
      expect(a.last.echeance(), DueBucket.plusTard);

      final r = resumeProphylaxie([b], [_traitement('t1', -1, 7)]);
      expect(r.enRetard, 1);
      expect(r.aujourdhui, 1);
      expect(r.delais, 1);
      expect(r.faitesCeMois, _jour(-5).month == DateTime.now().month ? 1 : 0);
    });

    test('délai d’attente : date de fin et jours restants', () {
      final d = delaiAttente(_traitement('t', -2, 7))!;
      expect(d.fin, DateTime(_jour(5).year, _jour(5).month, _jour(5).day));
      expect(d.joursRestants, 5);
      expect(d.enCours, isTrue);
      expect(delaiAttente(_traitement('t', -10, 7))!.enCours, isFalse);
      expect(delaiAttente(_traitement('t', 0, 0)), isNull);
      expect(delaisEnCours([_traitement('a', -1, 3), _traitement('b', -1, 10), _traitement('c', -20, 3)]).map((x) => x.traitement.id),
          ['b', 'a']);
    });

    test('appliquer un protocole : étapes à venir seulement, sans doublon', () {
      final p = ProtocoleVaccinal(nom: 'Local', etapes: [
        ProtocoleEtape(jourAge: 3, intervention: 'Vaccin Newcastle', produit: 'HB1'),
        ProtocoleEtape(jourAge: 14, intervention: 'Vaccin Gumboro', produit: 'Gumboro', voie: 'Eau de boisson'),
        ProtocoleEtape(jourAge: 21, intervention: 'Rappel Newcastle', produit: 'La Sota'),
      ]);
      final b = _bande(age: 10, evs: [_ev('x', 11, 'J21 - Rappel Newcastle (La Sota)')]);
      final r = etapesAAppliquer(p, b);
      expect(r.ignorees, 1);
      expect(r.dejaPrevues, 1);
      expect(r.aCreer.single['description'], 'J14 - Vaccin Gumboro (Gumboro)');
      expect(r.aCreer.single['commentaires'], 'Voie: Eau de boisson');
      final d = DateTime.parse(r.aCreer.single['datePrevue'] as String);
      expect(d.isUtc, isTrue);
      expect((d.year, d.month, d.day), (_jour(4).year, _jour(4).month, _jour(4).day));

      expect(modelesProtocoles.length, 3);
      expect(modelesProtocoles.first.toPayload()['etapes'], hasLength(5));
    });
  });

  group('Écran Prophylaxie', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('À faire : résumé, délai d’attente et intervention marquée faite', (tester) async {
      _telephone(tester);
      final bandes = _FakeBandes([
        _bande(evs: [_ev('e1', -2, 'J8 - Vaccin Newcastle'), _ev('e2', 3, 'J13 - Gumboro')]),
      ]);
      final sante = _FakeSante(traits: [_traitement('t1', -1, 7)]);
      await tester.pumpWidget(_app(bandes, sante));
      await tester.pumpAndSettle();

      expect(find.text('Prophylaxie'), findsOneWidget);
      expect(find.text('En retard (1)'), findsOneWidget);
      expect(find.textContaining('ne pas vendre avant le'), findsOneWidget);
      expect(find.textContaining('B-001 · J8'), findsOneWidget);

      await tester.tap(find.byTooltip('Marquer comme fait').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fait'));
      await tester.pumpAndSettle();
      expect(bandes.terminees, ['b1/e1']);
      expect(find.text('Intervention enregistrée'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Protocoles : modèle, carte lisible et nouveau traitement au registre', (tester) async {
      _telephone(tester);
      final sante = _FakeSante(protos: [
        ProtocoleVaccinal(id: 'p1', nom: 'Locale Amélioré', typeVolaille: 'poulet_local_ameliore', etapes: [
          ProtocoleEtape(jourAge: 14, intervention: 'Vaccin Gumboro', produit: 'Gumboro'),
          ProtocoleEtape(jourAge: 7, intervention: 'Vaccin Newcastle', produit: 'HB1', voie: 'Eau de boisson'),
        ]),
      ]);
      await tester.pumpWidget(_app(_FakeBandes([_bande()]), sante));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Protocoles'));
      await tester.pumpAndSettle();
      expect(find.text('Poulet local amélioré · 2 étapes · J7 à J14'), findsOneWidget);
      expect(find.text('J7'), findsOneWidget);
      expect(find.text('HB1 · Eau de boisson'), findsOneWidget);
      expect(find.byTooltip('Nouveau protocole'), findsOneWidget);

      await tester.tap(find.text('Partir d’un modèle'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Poulet de chair 45 jours'));
      await tester.pumpAndSettle();
      expect(sante.crees.single['nom'], 'Poulet de chair 45 jours');

      await tester.tap(find.text('Registre'));
      await tester.pumpAndSettle();
      expect(find.text('Registre vide'), findsOneWidget);
      await tester.tap(find.byTooltip('Nouveau traitement'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Produit'), 'Oxytétracycline');
      await tester.enterText(find.widgetWithText(TextField, 'Délai d’attente avant vente'), '5');
      await tester.pump();
      expect(find.textContaining('Vente possible à partir du'), findsOneWidget);
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(sante.traitementsCrees.single['produit'], 'Oxytétracycline');
      expect(sante.traitementsCrees.single['delaiAttenteJours'], 5);
      expect(sante.traitementsCrees.single['bandeId'], 'b1');
      expect(tester.takeException(), isNull);
    });
  });
}
