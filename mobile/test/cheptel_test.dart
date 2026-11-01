import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namofarm/models/alerte.dart';
import 'package:namofarm/models/cheptel.dart';
import 'package:namofarm/providers/alertes_provider.dart';
import 'package:namofarm/providers/auth_provider.dart';
import 'package:namofarm/providers/cheptel_provider.dart';
import 'package:namofarm/screens/cheptel/cheptel_detail_screen.dart';
import 'package:namofarm/screens/cheptel_screen.dart';
import 'package:namofarm/utils/cheptel.dart';
import 'package:namofarm/utils/finance.dart';
import 'package:namofarm/utils/tableau_de_bord.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

DateTime _jour(int delta, {int heure = 10}) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day + delta, heure);
}

CheptelMouvement _m(String type, int q, DateTime d, {double montant = 0}) =>
    CheptelMouvement(id: '$type-$q-${d.millisecondsSinceEpoch}', type: type, quantite: q, date: d, montant: montant);

/// Chèvres : 20 comptées il y a 120 j, +4 naissances, 3 morts récentes, 2 vendues 60 000.
Cheptel _chevres({List<CheptelMouvement>? mvts}) {
  final m = mvts ??
      [
        _m('ajustement', 20, _jour(-120)),
        _m('naissance', 4, _jour(-10)),
        _m('mortalite', 3, _jour(-5)),
        _m('vente', 2, _jour(-2), montant: 60000),
      ];
  var e = 0;
  for (final x in [...m]..sort((a, b) => a.date!.compareTo(b.date!))) {
    final t = typeMouvement(x.type);
    e = t.signe == 0 ? x.quantite : e + t.signe * x.quantite;
  }
  return Cheptel(
    id: 'c1',
    nom: 'Chèvres du Sahel',
    espece: 'chevre',
    effectifActuel: e,
    naissances: 4,
    morts: 3,
    ventes: 2,
    caVentes: 60000,
    tauxMortalite: 12.5,
    mouvements: m.reversed.toList(),
  );
}

class _Auth extends AuthProvider {
  @override
  bool get isAdmin => true;
}

class _FakeCheptel extends CheptelProvider {
  _FakeCheptel(this._liste);
  List<Cheptel> _liste;
  final List<Map<String, dynamic>> mouvements = [];

  @override
  List<Cheptel> get cheptels => _liste;
  @override
  bool get isLoading => false;
  @override
  Future<void> charger() async {}
  @override
  Future<bool> ajouterMouvement(String id, Map<String, dynamic> data) async {
    mouvements.add(data);
    final c = _liste.first;
    final t = typeMouvement(data['type'] as String);
    final q = data['quantite'] as int;
    _liste = [
      Cheptel(
        id: c.id,
        nom: c.nom,
        espece: c.espece,
        effectifActuel: t.signe == 0 ? q : c.effectifActuel + t.signe * q,
        mouvements: [_m(data['type'] as String, q, DateTime.parse(data['date'] as String)), ...c.mouvements],
      ),
    ];
    notifyListeners();
    return true;
  }
}

class _FakeAlertes extends AlertesProvider {
  final List<List<Map<String, dynamic>>> lots = [];
  @override
  List<Alerte> get alertes => const [];
  @override
  Future<int> creerPlusieurs(List<Map<String, dynamic>> taches) async {
    lots.add(taches);
    return taches.length;
  }
}

Widget _app(Widget home, _FakeCheptel cheptel, {_FakeAlertes? alertes}) => MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => _Auth()),
        ChangeNotifierProvider<CheptelProvider>.value(value: cheptel),
        ChangeNotifierProvider<AlertesProvider>.value(value: alertes ?? _FakeAlertes()),
      ],
      child: MaterialApp(home: home),
    );

void _telephone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('Logique du Cheptel', () {
    test('espèces, effectif daté, évolution sur 30 jours et bilan', () {
      expect(especePour('poule_locale').libelle, 'Poules locales');
      expect(especePour('poule_locale').volaille, isTrue);
      expect(especePour('chameau').libelle, 'Chameau');

      final c = _chevres();
      expect(c.effectifActuel, 19);
      expect(effectifAu(c, _jour(-30)), 20);
      expect(effectifAu(c, _jour(-6)), 24);
      final k = kpisCheptel(c);
      expect(k.evolution30j, -1);
      expect(k.mois.naissances, 4);
      expect(k.mois.morts, 3);
      expect(k.alertes, [AlerteCheptel.mortaliteEnHausse, AlerteCheptel.recomptage]);

      final b = bilanCheptel(c);
      expect(b.prixMoyenVente, 30000);
      expect(b.solde, 60000);

      final courbe = courbeEffectif(c);
      expect(courbe.first.effectif, 20);
      expect(courbe.last.effectif, 19);
      expect(courbe.last.date, DateTime(_jour(0).year, _jour(0).month, _jour(0).day));

      final r = resumeCheptel([c]);
      expect(r.animaux, 19);
      expect(r.naissances30j, 4);
      expect(r.morts30j, 3);
    });

    test('effectif après une saisie antidatée et mouvements de même date', () {
      // Recompté à 20 il y a 120 j ; +4, −3, −2 ensuite → 19.
      final c = _chevres();
      expect(effectifApresMouvement(c, 'mortalite', 3, _jour(-130)), 19, reason: 'avant le recomptage : sans effet');
      expect(effectifApresMouvement(c, 'ajustement', 8, _jour(-3)), 6, reason: 'recomptage à 8 puis vente de 2');
      expect(effectifApresMouvement(c, 'mortalite', 2, _jour(0)), 17);

      // Même horodatage : ordre de saisie (l'API renvoie le plus récent en premier).
      final d = _jour(-1);
      final memeDate = Cheptel(id: 'x', nom: 'X', mouvements: [_m('naissance', 3, d), _m('ajustement', 20, d)]);
      expect(effectifAu(memeDate, d), 23);
    });

    test('prix moyen calculé sur les ventes chiffrées seulement', () {
      final c = _chevres(mvts: [
        _m('ajustement', 30, _jour(-20)),
        _m('vente', 10, _jour(-10)),
        _m('vente', 2, _jour(-5), montant: 100000),
        _m('entree', 4, _jour(-4)),
        _m('entree', 1, _jour(-3), montant: 20000),
      ]);
      final b = bilanCheptel(c);
      expect(b.prixMoyenVente, 50000);
      expect(b.prixMoyenAchat, 20000);
    });

    test('pas d’alerte quand le troupeau est récemment compté et stable', () {
      final c = _chevres(mvts: [_m('ajustement', 30, _jour(-40)), _m('mortalite', 1, _jour(-3))]);
      expect(kpisCheptel(c).alertes, isEmpty);
    });

    test('journal par mois filtré', () {
      final c = _chevres(mvts: [
        _m('ajustement', 10, DateTime(2026, 1, 5)),
        _m('naissance', 2, DateTime(2026, 2, 3)),
        _m('mortalite', 1, DateTime(2026, 2, 20)),
      ]);
      final j = journalParMois(c);
      expect(j.map((g) => g.mois), [DateTime(2026, 2), DateTime(2026, 1)]);
      expect(j.first.mouvements.map((m) => m.type), ['mortalite', 'naissance']);
      expect(journalParMois(c, types: {'naissance'}).single.mouvements.single.quantite, 2);
    });

    test('plan santé et mise-bas transformés en tâches Todo', () {
      final c = _chevres();
      final plan = planSante('chevre');
      expect(plan.where((r) => r.titre == 'Déparasitage').length, 4);
      final taches = tachesPlanSante(c, plan.take(2).toList(), DateTime(2026, 1, 10));
      expect(taches.first['titre'], 'Déparasitage · Chèvres du Sahel');
      expect(DateTime.parse(taches[1]['dateEcheance'] as String).toLocal(), DateTime(2026, 4, 11, 8));

      expect(dateNaissancePrevue('chevre', DateTime(2026, 1, 1)), DateTime(2026, 5, 31));
      expect(dateNaissancePrevue('lapin', DateTime(2026, 1, 1)), DateTime(2026, 2, 1));
      final mb = tachesNaissancePrevue(c, DateTime(2026, 1, 1), nbFemelles: 3);
      expect(mb.map((t) => t['titre']), [
        'Préparer la mise-bas · Chèvres du Sahel',
        'Mise-bas prévue · Chèvres du Sahel',
        'Contrôle des petits · Chèvres du Sahel',
      ]);
      expect(DateTime.parse(mb[1]['dateEcheance'] as String).toLocal(), DateTime(2026, 5, 31, 8));
      expect(mb[1]['message'], startsWith('3 femelles'));
      final autre = tachesNaissancePrevue(c, DateTime(2026, 1, 1), gestationJours: 145);
      expect(DateTime.parse(autre[1]['dateEcheance'] as String).toLocal(), DateTime(2026, 5, 26, 8));
    });

    test('intégration Finance et Tableau de bord', () {
      final achat = Mouvement.fromJson({
        'nature': 'sortie',
        'source': 'achat_cheptel',
        'type': 'Chèvres du Sahel',
        'montant': 50000,
        'date': DateTime(2026, 3, 2).toIso8601String(),
      });
      expect(achat.libelle, 'Achats d’animaux');
      expect(achat.posteCle, posteAchatCheptel);
      expect(sourceLibelle('vente_cheptel'), 'Vente d’animaux');
      expect(originesFiltre['Cheptel'], ['vente_cheptel', 'achat_cheptel']);

      final e = elementsAujourdhui(cheptels: [_chevres()]);
      expect(e.first.titre, 'Mortalité en hausse : Chèvres du Sahel');
      expect(e.first.urgent, isTrue);
      expect(e.first.module, 'cheptel');
      expect(e.map((x) => x.titre), contains('Recompter le troupeau : Chèvres du Sahel'));
    });
  });

  group('Écrans Cheptel', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('Liste sur téléphone : résumé, carte et saisie rapide d’une mort', (tester) async {
      _telephone(tester);
      final provider = _FakeCheptel([_chevres()]);
      await tester.pumpWidget(_app(const CheptelScreen(), provider));
      await tester.pumpAndSettle();

      expect(find.text('Chèvres du Sahel'), findsOneWidget);
      expect(find.text('Chèvres'), findsOneWidget);
      expect(find.text('19'), findsWidgets);
      expect(find.text('▼ -1 en 30 j'), findsOneWidget);
      expect(find.text('Mortalité en hausse'), findsOneWidget);

      await tester.tap(find.text('Mort'));
      await tester.pumpAndSettle();
      expect(find.text('Effectif après : 18'), findsOneWidget);
      await tester.tap(find.byTooltip('Plus'));
      await tester.pump();
      expect(find.text('Effectif après : 17'), findsOneWidget);
      await tester.tap(find.byKey(const Key('cheptel-enregistrer')));
      await tester.pumpAndSettle();

      expect(provider.mouvements.single['type'], 'mortalite');
      expect(provider.mouvements.single['quantite'], 2);
      expect((provider.mouvements.single['date'] as String).endsWith('Z'), isTrue);
      expect(find.text('Enregistré : mortalité'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Vente : prix par tête et total ; effectif négatif refusé', (tester) async {
      _telephone(tester);
      final provider = _FakeCheptel([_chevres()]);
      await tester.pumpWidget(_app(const CheptelScreen(), provider));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Vente'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('cheptel-quantite')), '3');
      await tester.enterText(find.widgetWithText(TextField, 'Prix de vente par tête'), '25000');
      await tester.pump();
      expect(find.textContaining('Total : 75 000 FCFA'), findsOneWidget);
      await tester.tap(find.byKey(const Key('cheptel-enregistrer')));
      await tester.pumpAndSettle();
      expect(provider.mouvements.single['montant'], 75000);

      await tester.tap(find.text('Vente'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('cheptel-quantite')), '50');
      await tester.pump();
      expect(find.textContaining('Impossible'), findsOneWidget);
      await tester.tap(find.byKey(const Key('cheptel-enregistrer')));
      await tester.pump();
      expect(provider.mouvements, hasLength(1));
    });

    testWidgets('Fiche : onglets, journal par mois, finances, plan santé et mise-bas', (tester) async {
      _telephone(tester);
      final provider = _FakeCheptel([_chevres()]);
      final alertes = _FakeAlertes();
      await tester.pumpWidget(_app(CheptelDetailScreen(cheptel: provider.cheptels.first), provider, alertes: alertes));
      await tester.pumpAndSettle();

      expect(find.text('19 animaux'), findsOneWidget);
      expect(find.text('30 000 FCFA'), findsWidgets);

      await tester.tap(find.text('Journal'));
      await tester.pumpAndSettle();
      expect(find.text('Mortalité'), findsOneWidget);
      await tester.tap(find.byTooltip('Filtres'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxMenuButton, 'Naissance / éclosion'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 820));
      await tester.pumpAndSettle();
      expect(find.text('Mortalité'), findsNothing);
      expect(find.text('Naissance'), findsOneWidget, reason: 'filtre actif rappelé sur la ligne');

      await tester.tap(find.text('Finances'));
      await tester.pumpAndSettle();
      expect(find.text('Solde du troupeau'), findsOneWidget);
      expect(find.text('+ 60 000 FCFA'), findsOneWidget);

      await tester.tap(find.byTooltip('Plus d’options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plan santé'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('rappel(s) à la Todo'));
      await tester.pumpAndSettle();
      expect(alertes.lots.single.length, planSante('chevre').length);

      await tester.tap(find.byTooltip('Plus d’options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mise à la reproduction'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Mise-bas prévue le'), findsOneWidget);
      await tester.tap(find.text('Planifier'));
      await tester.pumpAndSettle();
      expect(alertes.lots.last, hasLength(3));
      expect(tester.takeException(), isNull);
    });
  });
}
