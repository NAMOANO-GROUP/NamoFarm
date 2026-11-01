import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namofarm/models/client.dart';
import 'package:namofarm/models/crm_pipeline.dart';
import 'package:namofarm/models/interaction.dart';
import 'package:namofarm/models/tache_crm.dart';
import 'package:namofarm/providers/auth_provider.dart';
import 'package:namofarm/providers/clients_provider.dart';
import 'package:namofarm/providers/crm_provider.dart';
import 'package:namofarm/screens/crm/client_detail_screen.dart';
import 'package:namofarm/screens/crm/clients_tab.dart';
import 'package:namofarm/screens/crm/crm_dashboard_tab.dart';
import 'package:namofarm/screens/crm/pipeline_tab.dart';
import 'package:namofarm/screens/crm/relances_tab.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAuthProvider extends AuthProvider {
  @override
  String get userPrenom => 'Moussa';
  @override
  String get userNom => 'Sow';
}

class FakeClientsProvider extends ClientsProvider {
  FakeClientsProvider(this._list);
  final List<Client> _list;
  @override
  List<Client> get clients => _list;
}

/// Faux provider CRM : tout reste en mémoire, aucun appel réseau.
class FakeCrmProvider extends CrmProvider {
  FakeCrmProvider({
    List<TacheCRM> taches = const [],
    List<PipelineDeal> deals = const [],
    List<CrmSuggestion> suggestions = const [],
    List<Interaction> interactions = const [],
    this.dashboardData,
  })  : _taches = [...taches],
        _deals = [...deals],
        _suggestions = [...suggestions],
        _interactions = [...interactions];

  List<TacheCRM> _taches;
  List<PipelineDeal> _deals;
  final List<CrmSuggestion> _suggestions;
  final List<Interaction> _interactions;
  final CrmDashboardData? dashboardData;
  final List<String> statutCalls = [];
  final List<String> moves = [];
  final List<String> applied = [];

  @override
  List<TacheCRM> get taches => _taches;
  @override
  List<PipelineDeal> get deals => _deals;
  @override
  List<CrmSuggestion> get suggestions => _suggestions;
  @override
  List<Interaction> get interactions => _interactions;
  @override
  String? get interactionsClientId => 'c1';
  @override
  CrmDashboardData? get dashboard => dashboardData;
  @override
  double get montantOuvert => _deals.where((d) => d.stage != 'gagne' && d.stage != 'perdu').fold(0, (s, d) => s + d.montant);
  @override
  double get previsionPonderee => 0;

  @override
  Future<void> chargerTout() async {}
  @override
  Future<void> chargerTachesCrm() async {}
  @override
  Future<void> chargerPipelineCommercial() async {}
  @override
  Future<void> chargerInteractionsClient(String clientId) async {}

  @override
  Future<bool> changerStatutTache(TacheCRM t, String statut) async {
    statutCalls.add('${t.id}:$statut');
    _taches = [for (final x in _taches) x.id == t.id ? x.copyWith(statut: statut) : x];
    notifyListeners();
    return true;
  }

  @override
  Future<bool> deplacerDeal(PipelineDeal deal, String stage) async {
    moves.add('${deal.clientId}:$stage');
    _deals = [for (final d in _deals) d.clientId == deal.clientId ? d.copyWith(stage: stage) : d];
    notifyListeners();
    return true;
  }

  @override
  Future<bool> appliquerSuggestion(CrmSuggestion s, {String assigneA = ''}) async {
    applied.add('${s.id}:$assigneA');
    _suggestions.remove(s);
    notifyListeners();
    return true;
  }
}

Widget _app(Widget child, {required CrmProvider crm, List<Client> clients = const []}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(create: (_) => FakeAuthProvider()),
      ChangeNotifierProvider<ClientsProvider>(create: (_) => FakeClientsProvider(clients)),
      ChangeNotifierProvider<CrmProvider>.value(value: crm),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

DateTime _today() => DateUtils.dateOnly(DateTime.now());

void main() {
  testWidgets('Relances : colonnes par échéance, cocher une tâche puis annuler', (tester) async {
    _setSize(tester, const Size(1400, 900));
    final crm = FakeCrmProvider(taches: [
      TacheCRM(id: 't1', clientId: 'c1', titre: 'Rappeler Awa', dateEcheance: _today().subtract(const Duration(days: 2)), priorite: 'haute', clientNom: 'Awa Diop'),
      TacheCRM(
        id: 't2',
        clientId: 'c2',
        titre: 'Livrer Moussa',
        dateEcheance: _today(),
        assigneA: 'Moussa Sow',
        checklist: const [ChecklistItem(titre: 'Charger', fait: true), ChecklistItem(titre: 'Livrer')],
      ),
    ]);

    await tester.pumpWidget(_app(const RelancesTab(), crm: crm));
    await tester.pumpAndSettle();

    expect(find.text('En retard'), findsOneWidget);
    expect(find.text("Aujourd'hui"), findsWidgets);
    expect(find.text('Rappeler Awa'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('Haute'), findsOneWidget);

    await tester.tap(find.byTooltip('Marquer comme terminée').first);
    await tester.pumpAndSettle();
    expect(crm.statutCalls, ['t1:terminee']);
    expect(find.text('Tâche terminée 🎉'), findsOneWidget);

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(crm.statutCalls, ['t1:terminee', 't1:a_faire']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Relances : filtre Mes tâches et vue liste', (tester) async {
    _setSize(tester, const Size(1400, 900));
    final crm = FakeCrmProvider(taches: [
      TacheCRM(id: 't1', clientId: '', titre: 'Tâche de Awa', dateEcheance: _today(), assigneA: 'Awa'),
      TacheCRM(id: 't2', clientId: '', titre: 'Ma tâche', dateEcheance: _today(), assigneA: 'Moussa Sow'),
    ]);

    await tester.pumpWidget(_app(const RelancesTab(), crm: crm));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mes tâches'));
    await tester.pumpAndSettle();
    expect(find.text('Ma tâche'), findsOneWidget);
    expect(find.text('Tâche de Awa'), findsNothing);

    await tester.tap(find.byTooltip('Liste'));
    await tester.pumpAndSettle();
    expect(find.text("Aujourd'hui (1)"), findsOneWidget);
  });

  testWidgets('Relances : petit écran sans débordement', (tester) async {
    _setSize(tester, const Size(390, 844));
    final crm = FakeCrmProvider(taches: [
      TacheCRM(id: 't1', clientId: 'c1', titre: 'Une tâche au titre assez long pour tester le rendu', dateEcheance: _today(), clientNom: 'Client avec un nom long', assigneA: 'Moussa Sow'),
    ]);
    await tester.pumpWidget(_app(const RelancesTab(), crm: crm));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pipeline : colonnes avec totaux et déplacement via le menu', (tester) async {
    _setSize(tester, const Size(1600, 900));
    final crm = FakeCrmProvider(deals: const [
      PipelineDeal(clientId: 'c1', prenom: 'Awa', nom: 'Diop', stage: 'proposition', montant: 250000, probabilite: 50, score: 80),
      PipelineDeal(clientId: 'c2', prenom: 'Moussa', nom: 'Fall', stage: 'proposition', montant: 100000, probabilite: 50),
    ]);

    await tester.pumpWidget(_app(const PipelineTab(), crm: crm));
    await tester.pumpAndSettle();

    expect(find.text('Négociation'), findsOneWidget);
    expect(find.text('350k FCFA'), findsWidgets);
    expect(find.text('Awa Diop'), findsOneWidget);

    await tester.tap(find.byTooltip('Actions de l’affaire').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Déplacer vers « Négociation »'));
    await tester.pumpAndSettle();

    expect(crm.moves, ['c1:negociation']);
    expect(find.text('Awa Diop → Négociation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Accueil : indicateurs et création d’une relance suggérée', (tester) async {
    _setSize(tester, const Size(1400, 1000));
    final crm = FakeCrmProvider(
      dashboardData: const CrmDashboardData(caMois: 150000, caMoisPrecedent: 100000, clientsActifs: 4),
      suggestions: [
        CrmSuggestion(
          id: 'reachat-c1',
          kind: 'reachat',
          clientId: 'c1',
          clientNom: 'Awa Diop',
          titre: 'Proposer un réachat à Awa Diop',
          raison: 'Réachat attendu dans 2 j',
          dateEcheance: DateTime.now(),
        ),
      ],
    );

    await tester.pumpWidget(_app(const CrmDashboardTab(), crm: crm));
    await tester.pumpAndSettle();

    expect(find.text('Bonjour Moussa 👋').evaluate().isNotEmpty || find.text('Bonsoir Moussa 👋').evaluate().isNotEmpty, isTrue);
    expect(find.text('150k FCFA'), findsOneWidget);
    expect(find.text('+50 %'), findsOneWidget);
    expect(find.text('Proposer un réachat à Awa Diop'), findsOneWidget);

    await tester.tap(find.text('Créer la relance'));
    await tester.pumpAndSettle();
    expect(crm.applied, ['reachat-c1:Moussa Sow']);
    expect(find.text('Proposer un réachat à Awa Diop'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Fiche client : en-tête, actions rapides et fil d’activité', (tester) async {
    _setSize(tester, const Size(1400, 1000));
    final client = Client(
      id: 'c1',
      prenom: 'Awa',
      nom: 'Diop',
      telephone: '+221 77 12 34 56',
      statut: 'actif',
      entreprise: 'Restaurant Teranga',
      chiffreAffairesCumul: 900000,
    );
    final crm = FakeCrmProvider(
      deals: const [PipelineDeal(clientId: 'c1', prenom: 'Awa', nom: 'Diop', stage: 'negociation', montant: 300000, probabilite: 75, score: 82)],
      taches: [TacheCRM(id: 't1', clientId: 'c1', titre: 'Envoyer le devis', dateEcheance: _today())],
      interactions: [
        Interaction(clientId: 'c1', type: 'appel', sujet: 'Prix du jour', contenu: 'Intéressée par 50 poulets', auteur: 'Moussa Sow', dateInteraction: DateTime.now()),
      ],
    );

    await tester.pumpWidget(_app(ClientDetailScreen(client: client), crm: crm, clients: [client]));
    await tester.pumpAndSettle();

    expect(find.text('Restaurant Teranga'), findsOneWidget);
    expect(find.text('82'), findsOneWidget);
    for (final action in ['Appeler', 'WhatsApp', 'Email', 'Note', 'Tâche']) {
      expect(find.byTooltip(action), findsOneWidget);
    }
    expect(find.text('Appel · Prix du jour'), findsOneWidget);
    expect(find.text('par Moussa Sow'), findsOneWidget);
    expect(find.text('Envoyer le devis'), findsOneWidget);
    expect(find.text('Affaire en cours'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Fiche client : sections sur petit écran', (tester) async {
    _setSize(tester, const Size(390, 844));
    final client = Client(id: 'c1', prenom: 'Awa', nom: 'Diop', telephone: '+221 77 12 34 56', statut: 'prospect');
    final crm = FakeCrmProvider(taches: [TacheCRM(id: 't1', clientId: 'c1', titre: 'Envoyer le devis', dateEcheance: _today())]);

    await tester.pumpWidget(_app(ClientDetailScreen(client: client), crm: crm, clients: [client]));
    await tester.pumpAndSettle();

    expect(find.text('Aucune activité pour le moment'), findsOneWidget);
    await tester.ensureVisible(find.text('Relances (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Relances (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Envoyer le devis'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pipeline, accueil et clients : pas de débordement sur téléphone', (tester) async {
    SharedPreferences.setMockInitialValues({});
    _setSize(tester, const Size(390, 844));
    final crm = FakeCrmProvider(
      deals: const [
        PipelineDeal(clientId: 'c1', prenom: 'Awa', nom: 'Diop Ndiaye', entreprise: 'Restaurant Teranga', stage: 'lead', montant: 1250000, dateCloturePrevue: null),
      ],
      dashboardData: const CrmDashboardData(caMois: 1500000, caMoisPrecedent: 1000000),
      taches: [TacheCRM(id: 't1', clientId: 'c1', titre: 'Relancer', dateEcheance: _today())],
    );
    final clients = [
      Client(id: 'c1', prenom: 'Awa', nom: 'Diop Ndiaye', telephone: '+221 77 12 34 56', entreprise: 'Restaurant Teranga', statut: 'actif', chiffreAffairesCumul: 1250000),
    ];

    for (final screen in const [PipelineTab(), CrmDashboardTab(), ClientsTab()]) {
      await tester.pumpWidget(_app(screen, crm: crm, clients: clients));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '${screen.runtimeType}');
    }
    expect(find.text('Awa Diop Ndiaye'), findsOneWidget);
  });

}
