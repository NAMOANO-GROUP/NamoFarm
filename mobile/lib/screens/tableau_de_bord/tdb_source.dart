import '../../services/api_service.dart';
import '../../utils/tableau_de_bord.dart';

double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

/// Chiffres d'une période (réponse /dashboard/global).
class ChiffresPeriode {
  final double ventes;
  final double depenses;
  final int nbCommandes;

  const ChiffresPeriode({this.ventes = 0, this.depenses = 0, this.nbCommandes = 0});

  double get resultat => ventes - depenses;

  factory ChiffresPeriode.fromJson(Map<String, dynamic> j) => ChiffresPeriode(
    ventes: _d(j['chiffreAffairesTotal']),
    depenses: _d(j['depensesTotales']),
    nbCommandes: _d(j['nbCommandes']).round(),
  );
}

/// Données générales (hors période) du Tableau de bord ; null = indisponible (droits ou réseau).
class SocleTdb {
  final double? argentDisponible;
  final List<MoisTendance>? tendance;
  final int? relancesAFaire;
  final int? commandesEnAttente;
  final double? previsionPonderee;

  /// Marge nette par identifiant de bande (/finance/analytique).
  final Map<String, double> margesBandes;

  const SocleTdb({
    this.argentDisponible,
    this.tendance,
    this.relancesAFaire,
    this.commandesEnAttente,
    this.previsionPonderee,
    this.margesBandes = const {},
  });

  bool get commercialDisponible => relancesAFaire != null || commandesEnAttente != null || previsionPonderee != null;
}

/// Accès aux données du Tableau de bord ; chaque appel échoue sans bloquer les autres.
/// Remplaçable dans les tests.
class TdbSource {
  const TdbSource();

  Future<T?> _essai<T>(Future<T> Function() f) async {
    try {
      return await f();
    } catch (_) {
      return null;
    }
  }

  Future<ChiffresPeriode?> chiffres(Intervalle i) async {
    final j = await _essai(() => ApiService.getGlobalDashboard(dateFrom: i.from, dateTo: i.to));
    return j == null ? null : ChiffresPeriode.fromJson(j);
  }

  Future<SocleTdb> socle({DateTime? now}) async {
    final t = now ?? DateTime.now();
    final r = await Future.wait<dynamic>([
      _essai(ApiService.getSoldeTresorerie),
      _essai(() => ApiService.getTendanceMensuelle(t.year)),
      _essai(() => ApiService.getTendanceMensuelle(t.year - 1)),
      _essai(ApiService.getCrmDashboard),
      _essai(ApiService.getPipelineCommercial),
      _essai(ApiService.getComptabiliteAnalytique),
    ]);
    final solde = r[0] as Map<String, dynamic>?;
    final courante = r[1] as Map<String, dynamic>?;
    final precedente = r[2] as Map<String, dynamic>?;
    final crm = r[3] as Map<String, dynamic>?;
    final pipeline = r[4] as Map<String, dynamic>?;
    final analytique = r[5] as Map<String, dynamic>?;
    return SocleTdb(
      argentDisponible: solde == null ? null : _d(solde['soldeCaisse']),
      tendance: courante == null && precedente == null
          ? null
          : douzeDerniersMois(anneeCourante: courante, anneePrecedente: precedente, now: t),
      relancesAFaire: crm == null ? null : _d(crm['relancesAFaire']).round(),
      commandesEnAttente: crm == null ? null : _d(crm['commandesEnAttente']).round(),
      previsionPonderee: pipeline == null ? null : _d(pipeline['previsionPonderee']),
      margesBandes: {
        for (final b in (analytique?['bandes'] as List? ?? const []).whereType<Map>())
          '${b['bandeId']}': _d(b['margeNette']),
      },
    );
  }
}
