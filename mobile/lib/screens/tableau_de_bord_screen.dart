import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/alerte.dart';
import '../models/bande.dart';
import '../models/cheptel.dart';
import '../providers/alertes_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/bandes_provider.dart';
import '../providers/cheptel_provider.dart';
import '../providers/nav_hub_provider.dart';
import '../services/api_service.dart';
import '../services/references_service.dart';
import '../utils/bande_kpis.dart';
import '../utils/cheptel.dart';
import '../utils/csv_export.dart';
import '../utils/tableau_de_bord.dart';
import '../widgets/brand_logo.dart';
import 'bandes/bande_detail_screen.dart';
import 'tableau_de_bord/tdb_blocs.dart';
import 'tableau_de_bord/tdb_source.dart';

const _cleOrdre = 'tdb.ordre';
const _cleMasques = 'tdb.masques';

const _joursFr = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
const _moisFr = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

String dateDuJour(DateTime d) => '${_joursFr[d.weekday - 1]} ${d.day} ${_moisFr[d.month - 1]} ${d.year}';

/// Tableau de bord : ce qu'il faut savoir et faire aujourd'hui, en un écran.
class TableauDeBordScreen extends StatefulWidget {
  final TdbSource source;

  const TableauDeBordScreen({super.key, this.source = const TdbSource()});

  @override
  State<TableauDeBordScreen> createState() => _TableauDeBordScreenState();
}

class _TableauDeBordScreenState extends State<TableauDeBordScreen> {
  List<BlocTdb> _ordre = BlocTdb.values;
  Set<BlocTdb> _masques = {};
  PeriodeTdb _periode = PeriodeTdb.mois;
  Map<String, ReferenceType> _refs = defaultReferences;
  SocleTdb? _socle;
  ChiffresPeriode? _actuel;
  ChiffresPeriode? _precedent;
  bool _chiffresCharges = false;

  @override
  void initState() {
    super.initState();
    _chargerPreferences();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  T? _lire<T>() {
    try {
      return context.read<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  Future<void> _chargerPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _ordre = ordreBlocs(prefs.getStringList(_cleOrdre) ?? const []);
      _masques = {
        for (final n in prefs.getStringList(_cleMasques) ?? const <String>[])
          ...BlocTdb.values.where((b) => b.name == n),
      };
    });
  }

  Future<void> _enregistrerPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_cleOrdre, _ordre.map((b) => b.name).toList());
    await prefs.setStringList(_cleMasques, _masques.map((b) => b.name).toList());
  }

  Future<void> _charger() async {
    final bandes = _lire<BandesProvider>();
    final alertes = _lire<AlertesProvider>();
    final cheptel = _lire<CheptelProvider>();
    await Future.wait([
      if (cheptel != null) cheptel.charger(),
      ReferencesService.charger().then((r) {
        if (mounted) setState(() => _refs = r);
      }),
      if (bandes != null) bandes.chargerBandesActives(),
      if (alertes != null) alertes.chargerAlertes(period: 'all'),
      if (alertes != null) alertes.chargerAlertesAutomatiques(),
      widget.source.socle().then((s) {
        if (mounted) setState(() => _socle = s);
      }),
      _chargerChiffres(),
    ]);
  }

  Future<void> _chargerChiffres() async {
    final periode = _periode;
    final i = intervallesTdb(periode);
    final r = await Future.wait([
      widget.source.chiffres(i.actuel),
      if (i.precedent != null) widget.source.chiffres(i.precedent!),
    ]);
    if (!mounted || periode != _periode) return;
    setState(() {
      _actuel = r[0];
      _precedent = r.length > 1 ? r[1] : null;
      _chiffresCharges = true;
    });
  }

  void _changerPeriode(PeriodeTdb p) {
    setState(() => _periode = p);
    _chargerChiffres();
  }

  void _ouvrirModule(String id) {
    final hub = _lire<NavHubProvider>();
    if (hub == null) return;
    if (hub.peutOuvrir(id)) {
      hub.ouvrirModule(id);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vous n’avez pas accès à ce module.')));
    }
  }

  void _ouvrirBande(Bande b) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => BandeDetailScreen(bande: b)));

  void _ouvrirElement(ElementAujourdhui e, List<Bande> bandes) {
    if (e.bandeId != null) {
      for (final b in bandes) {
        if (b.id == e.bandeId) return _ouvrirBande(b);
      }
    }
    _ouvrirModule(e.module);
  }

  Future<void> _personnaliser() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => PersonnaliserTdbSheet(
        ordre: _ordre,
        masques: _masques,
        onChange: (ordre, masques) {
          setState(() {
            _ordre = ordre;
            _masques = masques;
          });
          _enregistrerPreferences();
        },
      ),
    );
  }

  void _menu(String action) {
    switch (action) {
      case 'personnaliser':
        _personnaliser();
      case 'pdf':
        shareReportFile(
          context,
          loader: ApiService.downloadGlobalPdfReport,
          filename: 'rapport_namofarm.pdf',
          mimeType: 'application/pdf',
        );
      case 'excel':
        shareReportFile(
          context,
          loader: ApiService.downloadGlobalExcelReport,
          filename: 'rapport_namofarm.xlsx',
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    List<Bande> bandes = const [];
    List<Alerte> taches = const [];
    List<Alerte> automatiques = const [];
    try {
      bandes = context.watch<BandesProvider>().bandesActives;
    } on ProviderNotFoundException {
      // Écran utilisé hors de l'application complète.
    }
    List<Cheptel> cheptels = const [];
    try {
      cheptels = context.watch<CheptelProvider>().cheptels;
    } on ProviderNotFoundException {
      // Idem.
    }
    try {
      final a = context.watch<AlertesProvider>();
      taches = a.alertes;
      automatiques = a.alertesAutomatiques;
    } on ProviderNotFoundException {
      // Idem.
    }
    final kpis = <String, BandeKpis>{
      for (final b in bandes)
        if (b.id != null) b.id!: computeBandeKpis(b, referencePour(_refs, b.typeVolaille), now: now),
    };
    final elements = elementsAujourdhui(
      taches: taches,
      automatiques: automatiques,
      cheptels: cheptels,
      now: now,
    );
    String prenom = '';
    try {
      prenom = context.watch<AuthProvider>().userPrenom.trim();
    } on ProviderNotFoundException {
      prenom = '';
    }

    Widget bloc(BlocTdb b) {
      switch (b) {
        case BlocTdb.aujourdhui:
          return AujourdhuiBloc(elements: elements, onOuvrir: (e) => _ouvrirElement(e, bandes));
        case BlocTdb.indicateurs:
          return IndicateursBloc(
            periode: _periode,
            onPeriode: _changerPeriode,
            actuel: _actuel,
            precedent: _precedent,
            charge: _chiffresCharges,
            argentDisponible: _socle?.argentDisponible,
            elevage: resumeElevage(bandes, kpis),
            cheptel: cheptels.isEmpty ? null : resumeCheptel(cheptels, now: now),
            onCheptel: () => _ouvrirModule('cheptel'),
            onFinance: () => _ouvrirModule('finance'),
            onBandes: () => _ouvrirModule('bandes'),
          );
        case BlocTdb.bandes:
          return BandesTdbBloc(
            bandes: bandes,
            kpis: kpis,
            marges: _socle?.margesBandes ?? const {},
            onOuvrir: _ouvrirBande,
            onToutes: () => _ouvrirModule('bandes'),
          );
        case BlocTdb.tendance:
          return TendanceBloc(mois: _socle?.tendance, charge: _socle != null);
        case BlocTdb.commercial:
          return CommercialBloc(socle: _socle, onCrm: () => _ouvrirModule('crm'));
      }
    }

    final visibles = _ordre.where((b) => !_masques.contains(b)).toList();
    final large = MediaQuery.sizeOf(context).width >= 1100;

    return Scaffold(
      appBar: AppBar(
        leading: const BrandLogo(),
        title: const Text('Tableau de bord'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Plus d’options',
            onSelected: _menu,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'personnaliser',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.dashboard_customize_outlined),
                  title: Text('Personnaliser'),
                ),
              ),
              PopupMenuItem(
                value: 'pdf',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.picture_as_pdf_outlined),
                  title: Text('Rapport PDF'),
                ),
              ),
              PopupMenuItem(
                value: 'excel',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.table_chart_outlined),
                  title: Text('Rapport Excel'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prenom.isEmpty ? salutation(now) : '${salutation(now)} $prenom',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  Text(dateDuJour(now), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (visibles.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: TextButton.icon(
                    onPressed: _personnaliser,
                    icon: const Icon(Icons.dashboard_customize_outlined),
                    label: const Text('Tous les blocs sont masqués : personnaliser'),
                  ),
                ),
              )
            else if (large)
              // Grand écran : deux colonnes, les blocs alternent.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Column(children: [for (var i = 0; i < visibles.length; i += 2) bloc(visibles[i])])),
                  const SizedBox(width: 12),
                  Expanded(child: Column(children: [for (var i = 1; i < visibles.length; i += 2) bloc(visibles[i])])),
                ],
              )
            else
              ...visibles.map(bloc),
          ],
        ),
      ),
    );
  }
}
