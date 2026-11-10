import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/bandes_provider.dart';
import '../../providers/commandes_provider.dart';
import '../../providers/sante_provider.dart';
import '../../providers/stocks_provider.dart';
import '../../services/references_service.dart';
import '../../utils/bande_kpis.dart';
import '../../utils/money_format.dart';
import '../../utils/scenario.dart';
import '../../widgets/iso_calendar_picker.dart';
import '../roadmap_screen.dart' show roadmapDateCourte;
import 'scenario_widgets.dart';

const _vert = Color(0xFF2E7D32);
const _couleursPostes = {
  'poussins': Color(0xFF00897B),
  'aliment': Color(0xFFEF6C00),
  'prophylaxie': Color(0xFF8E24AA),
  'charges': Color(0xFF3949AB),
  'imprevus': Color(0xFF78909C),
};

/// Simulation de production : combien coûte (et rapporte) une bande de N sujets.
/// Les valeurs sont proposées d'après les données de l'application, toutes modifiables.
class ScenariosTab extends StatefulWidget {
  /// Données déjà connues (tests) : évite de les charger depuis les modules.
  final DonneesScenario? donnees;

  const ScenariosTab({super.key, this.donnees});

  @override
  State<ScenariosTab> createState() => _ScenariosTabState();
}

class _ScenariosTabState extends State<ScenariosTab> {
  static const _cleScenarios = 'planification.scenarios.v1';
  static const _cleSelection = 'planification.scenarioSelectionne';
  static const _maxScenarios = 6;

  final List<Scenario> _scenarios = [];
  String? _selId;
  DonneesScenario _donnees = const DonneesScenario();

  /// Change quand les champs doivent relire leurs valeurs (type, réinitialisation...).
  int _version = 0;

  /// Écran étroit : 0 = paramètres, 1 = résultats.
  int _vue = 0;

  Scenario get _sel => _scenarios.firstWhere((s) => s.id == _selId, orElse: () => _scenarios.first);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _restaurer(prefs);
    if (mounted && _scenarios.isNotEmpty) setState(() {});
    _donnees = widget.donnees ?? await _chargerDonnees();
    if (!mounted) return;
    if (_scenarios.isEmpty) {
      final s = scenarioPropose(_donnees);
      _scenarios.add(s);
      _selId = s.id;
      _sauver();
    }
    setState(() {});
  }

  void _restaurer(SharedPreferences p) {
    try {
      final raw = p.getString(_cleScenarios);
      if (raw != null) {
        for (final e in (jsonDecode(raw) as List).whereType<Map>()) {
          _scenarios.add(Scenario.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    } catch (_) {
      _scenarios.clear();
    }
    final id = p.getString(_cleSelection);
    _selId = _scenarios.any((s) => s.id == id) ? id : _scenarios.firstOrNull?.id;
  }

  Future<void> _sauver() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_cleScenarios, jsonEncode([for (final s in _scenarios) s.toJson()]));
    if (_selId != null) await p.setString(_cleSelection, _selId!);
  }

  T? _lire<T>() {
    try {
      return context.read<T>();
    } catch (_) {
      return null;
    }
  }

  Future<DonneesScenario> _chargerDonnees() async {
    final bandes = _lire<BandesProvider>();
    final stocks = _lire<StocksProvider>();
    final commandes = _lire<CommandesProvider>();
    final sante = _lire<SanteProvider>();
    final chargements = <Future<void>>[
      if (bandes != null && bandes.bandesActives.isEmpty) bandes.chargerBandesActives(),
      if (bandes != null && bandes.bandesHistorique.isEmpty) bandes.chargerHistorique(),
      if (stocks != null && stocks.stocks.isEmpty) stocks.chargerStocks(),
      if (commandes != null && commandes.commandes.isEmpty) commandes.chargerCommandes(),
      if (sante != null && sante.protocoles.isEmpty) sante.charger(),
    ];
    await Future.wait([for (final f in chargements) f.catchError((_) {})]);
    final refs = await ReferencesService.charger();
    final toutes = {
      for (final b in [...?bandes?.bandesActives, ...?bandes?.bandesHistorique]) b.id ?? b.nom: b,
    };
    return DonneesScenario(
      references: refs,
      bandes: toutes.values.toList(),
      stocks: stocks?.stocks ?? const [],
      commandes: commandes?.commandes ?? const [],
      protocoles: sante?.protocoles ?? const [],
    );
  }

  void _maj(void Function(Scenario s) f, {String? cle}) {
    setState(() {
      f(_sel);
      if (cle != null) _sel.origines[cle] = Origine.modifie;
    });
    _sauver();
  }

  void _selectionner(String id) {
    setState(() => _selId = id);
    _sauver();
  }

  void _nouveau() {
    if (_scenarios.length >= _maxScenarios) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('6 scénarios au maximum.')));
      return;
    }
    final base = _sel;
    final s = scenarioPropose(_donnees, type: base.typeVolaille, sujets: base.sujets, nom: 'Scénario ${_scenarios.length + 1}');
    setState(() {
      _scenarios.add(s);
      _selId = s.id;
      _version++;
    });
    _sauver();
  }

  void _dupliquer() {
    if (_scenarios.length >= _maxScenarios) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('6 scénarios au maximum.')));
      return;
    }
    final c = _sel.copie(id: DateTime.now().microsecondsSinceEpoch.toString(), nom: '${_sel.nom} (copie)');
    setState(() {
      _scenarios.add(c);
      _selId = c.id;
      _version++;
    });
    _sauver();
  }

  Future<void> _renommer() async {
    final c = TextEditingController(text: _sel.nom);
    final nom = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renommer le scénario'),
        content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(labelText: 'Nom')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (nom == null || nom.isEmpty || !mounted) return;
    _maj((s) => s.nom = nom);
  }

  Future<bool> _confirmer(String titre, String message, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titre),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
        ],
      ),
    );
    return ok == true && mounted;
  }

  Future<void> _reinitialiser() async {
    if (!await _confirmer('Revenir aux valeurs proposées ?', 'Toutes vos modifications de ce scénario seront remplacées.', 'Réinitialiser')) return;
    final s = _sel;
    final neuf = scenarioPropose(_donnees, type: s.typeVolaille, sujets: s.sujets, nom: s.nom, debut: s.debut)..id = s.id;
    setState(() {
      _scenarios[_scenarios.indexWhere((x) => x.id == s.id)] = neuf;
      _version++;
    });
    _sauver();
  }

  Future<void> _supprimer() async {
    if (_scenarios.length < 2) return;
    if (!await _confirmer('Supprimer « ${_sel.nom} » ?', 'Cette simulation sera définitivement supprimée.', 'Supprimer')) return;
    setState(() {
      _scenarios.removeWhere((s) => s.id == _selId);
      _selId = _scenarios.first.id;
      _version++;
    });
    _sauver();
  }

  @override
  Widget build(BuildContext context) {
    if (_scenarios.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Analyse de vos données…', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }
    final s = _sel;
    final r = calculerScenario(s);
    return Column(
      children: [
        _selecteur(),
        _barreResume(s, r),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final large = c.maxWidth >= 900;
              if (large) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: (c.maxWidth * 0.42).clamp(380, 520),
                      child: ListView(padding: const EdgeInsets.fromLTRB(12, 4, 6, 24), children: _parametres(s, r)),
                    ),
                    Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(6, 4, 12, 24), children: _resultats(s, r))),
                  ],
                );
              }
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<int>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: 0, icon: Icon(Icons.tune), label: Text('Paramètres')),
                          ButtonSegment(value: 1, icon: Icon(Icons.insights_outlined), label: Text('Résultats')),
                        ],
                        selected: {_vue},
                        onSelectionChanged: (v) => setState(() => _vue = v.first),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      key: PageStorageKey('planif-vue-$_vue'),
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      children: _vue == 0 ? _parametres(s, r) : _resultats(s, r),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _selecteur() {
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              children: [
                for (final s in _scenarios)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(s.nom),
                      selected: s.id == _selId,
                      onSelected: (_) => _selectionner(s.id),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(tooltip: 'Nouveau scénario', icon: const Icon(Icons.add_circle_outline), onPressed: _nouveau),
          PopupMenuButton<String>(
            tooltip: 'Options du scénario',
            onSelected: (v) {
              switch (v) {
                case 'renommer':
                  _renommer();
                case 'dupliquer':
                  _dupliquer();
                case 'reinit':
                  _reinitialiser();
                case 'supprimer':
                  _supprimer();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'renommer', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.edit_outlined), title: Text('Renommer'))),
              const PopupMenuItem(value: 'dupliquer', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.copy_outlined), title: Text('Dupliquer'))),
              const PopupMenuItem(value: 'reinit', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.auto_fix_high_outlined), title: Text('Valeurs proposées'))),
              if (_scenarios.length > 1) ...[
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'supprimer', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.delete_outline, color: Colors.redAccent), title: Text('Supprimer'))),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Bandeau toujours visible : le résultat bouge en direct pendant qu'on modifie les valeurs.
  Widget _barreResume(Scenario s, ResultatScenario r) {
    final gain = r.marge >= 0;
    final couleurMarge = gain ? const Color(0xFFB9F6CA) : const Color(0xFFFF8A80);
    const blanc = Colors.white;
    return Container(
      key: const ValueKey('planif-resume'),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0B5D3B), Color(0xFF2E7D32)]),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: const Color(0xFF0B5D3B).withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entier(s.sujets)} sujets · ${s.dureeJours} j · ${typeVolailleLabel(s.typeVolaille)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: blanc.withValues(alpha: 0.8), fontSize: 12),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: ValeurAnimee(valeur: r.total, format: fcfa, style: const TextStyle(color: blanc, fontSize: 24, fontWeight: FontWeight.w800)),
                ),
                Text('Coût total estimé', style: TextStyle(color: blanc.withValues(alpha: 0.8), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Marge', style: TextStyle(color: blanc.withValues(alpha: 0.8), fontSize: 12)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: ValeurAnimee(valeur: r.marge, format: (v) => '${v >= 0 ? '+' : '−'}${formatCompactFcfa(v.abs())}', style: TextStyle(color: couleurMarge, fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: blanc.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
                  child: Text('${entier(r.coutParSujet)} / sujet', style: const TextStyle(color: blanc, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── Paramètres ─────────────────────────

  List<Widget> _parametres(Scenario s, ResultatScenario r) {
    final k = '${s.id}-$_version';
    return [
      CarteSection(
        icone: Icons.flag_outlined,
        couleur: _vert,
        titre: 'Objectif de production',
        sousTitre: 'Combien de sujets voulez-vous vendre ?',
        children: [
          DropdownButtonFormField<String>(
            key: ValueKey('$k-type'),
            initialValue: typesVolaille.containsKey(s.typeVolaille) ? s.typeVolaille : 'autre',
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Type de volaille',
              prefixIcon: Icon(Icons.category_outlined),
              helperText: 'Remplit la durée, le poids et la consommation de référence',
              helperMaxLines: 2,
            ),
            items: [for (final e in typesVolaille.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                s.typeVolaille = v;
                appliquerReference(s, _donnees.references);
                final p = protocolePour(v, _donnees.protocoles);
                s.protocoleNom = p?.nom ?? '';
                s.nbInterventions = p?.etapes.length ?? 0;
                if (s.origines[Cle.prophylaxie] == Origine.estime) {
                  s.prophylaxieParSujet = s.nbInterventions > 0 ? s.nbInterventions * Estimations.prophylaxieParIntervention : Estimations.prophylaxieParSujet;
                }
                _version++;
              });
              _sauver();
            },
          ),
          const SizedBox(height: 12),
          GrilleChamps(children: [
            ChampNombre(key: ValueKey('$k-sujets'), label: 'Sujets à vendre', valeur: s.sujets.toDouble(), decimale: false, suffixe: 'sujets', onChanged: (v) => _maj((s) => s.sujets = v.round())),
            ChampNombre(key: ValueKey('$k-mort'), label: 'Mortalité', valeur: s.mortalitePct, suffixe: '%', origine: s.origines[Cle.mortalite], onChanged: (v) => _maj((s) => s.mortalitePct = v, cle: Cle.mortalite)),
            ChampNombre(key: ValueKey('$k-duree'), label: 'Durée d’élevage', valeur: s.dureeJours.toDouble(), decimale: false, suffixe: 'jours', origine: s.origines[Cle.duree], onChanged: (v) => _maj((s) => s.dureeJours = v.round(), cle: Cle.duree)),
            ChampNombre(key: ValueKey('$k-poids'), label: 'Poids final', valeur: s.poidsFinalG, suffixe: 'g', origine: s.origines[Cle.poids], onChanged: (v) => _maj((s) => s.poidsFinalG = v, cle: Cle.poids)),
            ChampNombre(key: ValueKey('$k-vide'), label: 'Vide sanitaire', valeur: s.videSanitaireJours.toDouble(), decimale: false, suffixe: 'jours', onChanged: (v) => _maj((s) => s.videSanitaireJours = v.round())),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final d = await showIsoDatePicker(context: context, initialDate: s.debut, firstDate: DateTime(2020), lastDate: DateTime(2100), title: 'Début de la bande');
                if (d != null && mounted) _maj((s) => s.debut = d);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Début de bande', helperText: ' ', suffixIcon: Icon(Icons.calendar_month_outlined, size: 20)),
                child: Text(roadmapDateCourte(s.debut, annee: true)),
              ),
            ),
          ]),
          _bandeau(
            Icons.info_outline,
            'Pour vendre ${entier(s.sujets)} sujets avec ${pct(s.mortalitePct)} de pertes, il faut commander ${entier(r.poussins)} poussins.',
            _vert,
          ),
        ],
      ),
      CarteSection(
        icone: Icons.egg_outlined,
        couleur: _couleursPostes['poussins']!,
        titre: 'Poussins',
        children: [
          GrilleChamps(children: [
            ChampNombre(key: ValueKey('$k-pp'), label: 'Prix du poussin', valeur: s.prixPoussin, suffixe: 'FCFA', origine: s.origines[Cle.prixPoussin], onChanged: (v) => _maj((s) => s.prixPoussin = v, cle: Cle.prixPoussin)),
            _Lecture('Total poussins', fcfa(r.coutPoussins)),
          ]),
        ],
      ),
      CarteSection(
        icone: Icons.restaurant_outlined,
        couleur: _couleursPostes['aliment']!,
        titre: 'Alimentation',
        sousTitre: 'Consommation et prix par phase',
        children: [
          GrilleChamps(children: [
            ChampNombre(key: ValueKey('$k-conso'), label: 'Consommation', valeur: s.consoKgParSujet, suffixe: 'kg/sujet', origine: s.origines[Cle.conso], onChanged: (v) => _maj((s) => s.consoKgParSujet = v, cle: Cle.conso)),
            ChampNombre(key: ValueKey('$k-sac'), label: 'Poids d’un sac', valeur: s.sacKg, suffixe: 'kg', onChanged: (v) => _maj((s) => s.sacKg = v)),
          ]),
          for (var i = 0; i < s.phases.length; i++) ...[
            const SizedBox(height: 4),
            Text(
              '${s.phases[i].nom} · ${decimal(r.alimentKgParPhase[i])} kg · ${fcfa(r.coutParPhase[i])}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            GrilleChamps(colonnes: 2, children: [
              ChampNombre(key: ValueKey('$k-part$i'), label: 'Part de l’aliment', valeur: s.phases[i].part, suffixe: '%', reserverAide: false, onChanged: (v) => _maj((s) => s.phases[i].part = v)),
              ChampNombre(key: ValueKey('$k-prix$i'), label: 'Prix du kg', valeur: s.phases[i].prixKg, suffixe: 'FCFA', origine: s.origines[Cle.phase(i)], onChanged: (v) => _maj((s) => s.phases[i].prixKg = v, cle: Cle.phase(i))),
            ]),
          ],
          if ((s.phases.fold<double>(0, (t, p) => t + p.part) - 100).abs() > 0.01)
            _bandeau(Icons.balance_outlined, 'Les parts font ${pct(s.phases.fold<double>(0, (t, p) => t + p.part))} : elles sont ramenées à 100 % pour le calcul.', Colors.orange),
        ],
      ),
      CarteSection(
        icone: Icons.vaccines_outlined,
        couleur: _couleursPostes['prophylaxie']!,
        titre: 'Prophylaxie',
        sousTitre: 'Vaccins, traitements et vitamines',
        children: [
          GrilleChamps(children: [
            ChampNombre(key: ValueKey('$k-vacc'), label: 'Vaccins et soins', valeur: s.prophylaxieParSujet, suffixe: 'FCFA/pouss.', origine: s.origines[Cle.prophylaxie], onChanged: (v) => _maj((s) => s.prophylaxieParSujet = v, cle: Cle.prophylaxie)),
            ChampNombre(key: ValueKey('$k-vit'), label: 'Vitamines', valeur: s.vitaminesParSujet, suffixe: 'FCFA/pouss.', origine: s.origines[Cle.vitamines], onChanged: (v) => _maj((s) => s.vitaminesParSujet = v, cle: Cle.vitamines)),
            _Lecture('Total prophylaxie', fcfa(r.coutProphylaxieTotal)),
          ]),
          if (s.nbInterventions > 0)
            _bandeau(Icons.event_note_outlined, 'Protocole « ${s.protocoleNom} » : ${s.nbInterventions} interventions prévues sur la bande.', _couleursPostes['prophylaxie']!),
        ],
      ),
      CarteSection(
        icone: Icons.receipt_long_outlined,
        couleur: _couleursPostes['charges']!,
        titre: 'Autres charges',
        sousTitre: 'Forfait, par sujet ou par jour',
        children: [
          for (final c in s.charges) _ligneCharge(s, c, r, k),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _maj((s) => s.charges.add(ChargeLigne(id: DateTime.now().microsecondsSinceEpoch.toString(), libelle: 'Nouvelle charge', montant: 0))),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une charge'),
            ),
          ),
          const SizedBox(height: 4),
          GrilleChamps(children: [
            ChampNombre(key: ValueKey('$k-imp'), label: 'Imprévus', valeur: s.imprevusPct, suffixe: '%', onChanged: (v) => _maj((s) => s.imprevusPct = v)),
            _Lecture('Provision', fcfa(r.imprevus)),
          ]),
        ],
      ),
      CarteSection(
        icone: Icons.sell_outlined,
        couleur: const Color(0xFF1565C0),
        titre: 'Vente',
        sousTitre: 'À quel prix pensez-vous vendre ?',
        children: [
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: true, label: Text('Au kg vif')),
                ButtonSegment(value: false, label: Text('Par sujet')),
              ],
              selected: {s.venteParKg},
              onSelectionChanged: (v) {
                final kg = s.poidsFinalG / 1000;
                setState(() {
                  // Le prix est converti pour que le chiffre d'affaires reste le même.
                  if (kg > 0) s.prixVente = v.first ? s.prixVente / kg : s.prixVente * kg;
                  s.venteParKg = v.first;
                  _version++;
                });
                _sauver();
              },
            ),
          ),
          const SizedBox(height: 12),
          GrilleChamps(children: [
            ChampNombre(key: ValueKey('$k-vente'), label: 'Prix de vente', valeur: s.prixVente, suffixe: s.venteParKg ? 'FCFA/kg' : 'FCFA/sujet', origine: s.origines[Cle.vente], onChanged: (v) => _maj((s) => s.prixVente = v, cle: Cle.vente)),
            _Lecture('Chiffre d’affaires', fcfa(r.ca)),
          ]),
        ],
      ),
    ];
  }

  Widget _ligneCharge(Scenario s, ChargeLigne c, ResultatScenario r, String k) {
    final scheme = Theme.of(context).colorScheme;
    final i = s.charges.indexOf(c);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 4),
      decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: ValueKey('$k-${c.id}-nom'),
                  initialValue: c.libelle,
                  decoration: const InputDecoration(labelText: 'Libellé'),
                  onChanged: (v) => _maj((s) => c.libelle = v),
                ),
              ),
              IconButton(tooltip: 'Supprimer la charge', icon: const Icon(Icons.close), onPressed: () => _maj((s) => s.charges.remove(c))),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GrilleChamps(colonnes: 2, children: [
              ChampNombre(key: ValueKey('$k-${c.id}-montant'), label: 'Montant', valeur: c.montant, suffixe: 'FCFA', reserverAide: false, onChanged: (v) => _maj((s) => c.montant = v)),
              DropdownButtonFormField<ModeCharge>(
                key: ValueKey('$k-${c.id}-mode'),
                initialValue: c.mode,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Calcul'),
                items: [for (final e in modeChargeLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (v) {
                  if (v != null) _maj((s) => c.mode = v);
                },
              ),
            ]),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 12, top: 6, bottom: 6),
              child: Text(
                '= ${i >= 0 && i < r.montantsCharges.length ? fcfa(r.montantsCharges[i]) : ''}',
                style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant, fontSize: 12.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bandeau(IconData icone, String texte, Color couleur) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: couleur.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12), border: Border.all(color: couleur.withValues(alpha: 0.30))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 18, color: couleur),
          const SizedBox(width: 10),
          Expanded(child: Text(texte, style: const TextStyle(fontSize: 12.5, height: 1.3))),
        ],
      ),
    );
  }

  // ───────────────────────── Résultats ─────────────────────────

  List<Widget> _resultats(Scenario s, ResultatScenario r) {
    final gain = r.marge >= 0;
    final couleurMarge = gain ? _vert : Colors.red.shade600;
    final prixVenteSujet = r.sujetsVendus > 0 ? r.ca / r.sujetsVendus : 0.0;
    final securite = prixVenteSujet > 0 ? (prixVenteSujet - r.prixMinSujet) / prixVenteSujet * 100 : 0.0;
    final total = r.total <= 0 ? 1.0 : r.total;

    return [
      GrilleChamps(colonnes: 2, children: [
        TuileKpi(icone: Icons.payments_outlined, label: 'Coût total', valeur: r.total, format: fcfa, couleur: const Color(0xFFEF6C00), detail: '${fcfa(r.coutParKg)} / kg vif'),
        TuileKpi(icone: Icons.person_pin_outlined, label: 'Coût par sujet', valeur: r.coutParSujet, format: fcfa, couleur: const Color(0xFF00897B), detail: '${entier(r.sujetsVendus)} sujets vendus'),
        TuileKpi(icone: Icons.trending_up, label: 'Chiffre d’affaires', valeur: r.ca, format: fcfa, couleur: const Color(0xFF1565C0), detail: '${fcfa(prixVenteSujet)} / sujet'),
        TuileKpi(icone: gain ? Icons.savings_outlined : Icons.warning_amber_rounded, label: gain ? 'Marge' : 'Perte', valeur: r.marge, format: (v) => '${v >= 0 ? '' : '−'}${fcfa(v.abs())}', couleur: couleurMarge, detail: '${r.margePct.toStringAsFixed(1)} % du chiffre d’affaires'),
      ]),
      const SizedBox(height: 14),
      CarteSection(
        icone: Icons.pie_chart_outline,
        couleur: const Color(0xFF8E24AA),
        titre: 'Répartition des coûts',
        children: [_repartition(r)],
      ),
      CarteSection(
        icone: Icons.list_alt_outlined,
        couleur: const Color(0xFFEF6C00),
        titre: 'Détail des coûts',
        children: [
          _ligneCout('Poussins', '${entier(r.poussins)} × ${fcfa(s.prixPoussin)}', r.coutPoussins, total, _couleursPostes['poussins']!),
          _ligneCout('Aliment', '${decimal(r.alimentKg)} kg · ${decimal(r.sacs)} sacs de ${decimal(s.sacKg)} kg', r.coutAliment, total, _couleursPostes['aliment']!),
          for (var i = 0; i < s.phases.length; i++)
            _ligneCout(s.phases[i].nom, '${decimal(r.alimentKgParPhase[i])} kg × ${fcfa(s.phases[i].prixKg)}', r.coutParPhase[i], total, _couleursPostes['aliment']!, niveau: 1),
          _ligneCout('Vaccins et soins', '${entier(r.poussins)} × ${fcfa(s.prophylaxieParSujet)}', r.coutProphylaxie, total, _couleursPostes['prophylaxie']!),
          _ligneCout('Vitamines', '${entier(r.poussins)} × ${fcfa(s.vitaminesParSujet)}', r.coutVitamines, total, _couleursPostes['prophylaxie']!),
          for (var i = 0; i < s.charges.length && i < r.montantsCharges.length; i++)
            _ligneCout(s.charges[i].libelle, _detailCharge(s.charges[i], r), r.montantsCharges[i], total, _couleursPostes['charges']!),
          _ligneCout('Imprévus', pct(s.imprevusPct), r.imprevus, total, _couleursPostes['imprevus']!),
          const Divider(height: 24),
          Row(
            children: [
              const Expanded(child: Text('Coût total', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
              Text(fcfa(r.total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ],
          ),
        ],
      ),
      CarteSection(
        icone: Icons.inventory_2_outlined,
        couleur: const Color(0xFF00838F),
        titre: 'Besoins et calendrier',
        sousTitre: 'Ce qu’il faut prévoir pour cette bande',
        children: [
          GrilleChamps(colonnes: 2, children: [
            _Fait(Icons.egg_outlined, 'Poussins à commander', entier(r.poussins)),
            _Fait(Icons.heart_broken_outlined, 'Pertes prévues', entier(r.morts)),
            _Fait(Icons.restaurant_outlined, 'Aliment', '${entier(r.alimentKg)} kg'),
            _Fait(Icons.shopping_bag_outlined, 'Sacs d’aliment', decimal(r.sacs.ceilToDouble())),
            _Fait(Icons.scale_outlined, 'Poids vif total', '${entier(r.poidsTotalKg)} kg'),
            _Fait(Icons.speed_outlined, 'Indice de conso.', decimal(double.parse(r.ica.toStringAsFixed(2)))),
            if (s.nbInterventions > 0) _Fait(Icons.vaccines_outlined, 'Interventions', '${s.nbInterventions} / sujet'),
            _Fait(Icons.play_circle_outline, 'Mise en place', roadmapDateCourte(s.debut, annee: true)),
            _Fait(Icons.flag_circle_outlined, 'Fin de bande', roadmapDateCourte(r.finLot, annee: true)),
            _Fait(Icons.cleaning_services_outlined, 'Prochaine bande', roadmapDateCourte(r.prochaineBande, annee: true)),
          ]),
        ],
      ),
      CarteSection(
        icone: Icons.shield_outlined,
        couleur: couleurMarge,
        titre: 'Seuil de rentabilité',
        sousTitre: 'Prix minimum pour ne pas perdre d’argent',
        children: [
          GrilleChamps(colonnes: 2, children: [
            _Fait(Icons.person_outline, 'Par sujet', fcfa(r.prixMinSujet)),
            _Fait(Icons.scale_outlined, 'Par kg vif', fcfa(r.prixMinKg)),
          ]),
          _bandeau(
            gain ? Icons.check_circle_outline : Icons.error_outline,
            gain
                ? 'Votre prix de vente couvre le coût avec ${securite.toStringAsFixed(1)} % de marge de sécurité.'
                : 'À ce prix de vente, chaque sujet est vendu ${fcfa(r.prixMinSujet - prixVenteSujet)} sous son coût.',
            couleurMarge,
          ),
        ],
      ),
      CarteSection(
        icone: Icons.grid_on_outlined,
        couleur: const Color(0xFF3949AB),
        titre: 'Et si les prix changeaient ?',
        sousTitre: 'Marge selon le coût de l’aliment et le prix de vente',
        children: [_sensibilite(s)],
      ),
      if (_scenarios.length > 1)
        CarteSection(
          icone: Icons.compare_arrows,
          couleur: const Color(0xFF6A1B9A),
          titre: 'Comparer les scénarios',
          sousTitre: 'Touchez une ligne pour l’ouvrir',
          children: [for (final x in _scenarios) _ligneComparaison(x)],
        ),
    ];
  }

  String _detailCharge(ChargeLigne c, ResultatScenario r) => switch (c.mode) {
        ModeCharge.forfait => 'Forfait',
        ModeCharge.parSujet => '${entier(r.poussins)} × ${fcfa(c.montant)}',
        ModeCharge.parJour => '${_sel.dureeJours} j × ${fcfa(c.montant)}',
      };

  Widget _repartition(ResultatScenario r) {
    final scheme = Theme.of(context).colorScheme;
    final postes = r.postes.where((p) => p.montant > 0).toList();
    if (postes.isEmpty) return const Text('Renseignez des valeurs pour voir la répartition.');
    final total = postes.fold<double>(0, (t, p) => t + p.montant);
    final donut = SizedBox(
      height: 190,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 58,
              startDegreeOffset: -90,
              sections: [
                for (final p in postes)
                  PieChartSectionData(
                    value: p.montant,
                    color: _couleursPostes[p.cle],
                    radius: 28,
                    showTitle: false,
                  ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Coût total', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              Text(formatCompactFcfa(total), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
    final legende = Column(
      children: [
        for (final p in postes)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(color: _couleursPostes[p.cle], borderRadius: BorderRadius.circular(4))),
                const SizedBox(width: 10),
                Expanded(child: Text(p.libelle, maxLines: 1, overflow: TextOverflow.ellipsis)),
                Text(fcfa(p.montant), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                SizedBox(width: 52, child: Text(pct(p.montant / total * 100), textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant))),
              ],
            ),
          ),
      ],
    );
    return Column(children: [donut, const SizedBox(height: 10), legende]);
  }

  Widget _ligneCout(String libelle, String detail, double montant, double total, Color couleur, {int niveau = 0}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(left: niveau * 16.0, bottom: niveau > 0 ? 8 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(libelle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: niveau > 0 ? FontWeight.w500 : FontWeight.w700, fontSize: niveau > 0 ? 13 : 14))),
              Text(fcfa(montant), style: TextStyle(fontWeight: niveau > 0 ? FontWeight.w500 : FontWeight.w700, fontSize: niveau > 0 ? 13 : 14)),
            ],
          ),
          const SizedBox(height: 2),
          Text(detail, style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: (montant / total).clamp(0.0, 1.0), minHeight: niveau > 0 ? 3 : 5, color: couleur, backgroundColor: couleur.withValues(alpha: 0.12)),
          ),
        ],
      ),
    );
  }

  Widget _sensibilite(Scenario s) {
    final scheme = Theme.of(context).colorScheme;
    const deltas = <double>[-10, 0, 10];
    final grille = sensibiliteMarge(s);
    String libelle(double d) => d == 0 ? 'Prévu' : '${d > 0 ? '+' : '−'}${d.abs().toStringAsFixed(0)} %';
    Widget entete(String t) => Expanded(child: Center(child: Text(t, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant))));
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 78),
            for (final d in deltas) entete(libelle(d)),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 78, bottom: 6),
          child: Center(child: Text('Prix de vente', style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant))),
        ),
        for (var i = 0; i < deltas.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(width: 78, child: Text('Aliment ${libelle(deltas[i])}', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant))),
                for (var j = 0; j < deltas.length; j++)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: (grille[i][j] >= 0 ? _vert : Colors.red).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                        border: i == 1 && j == 1 ? Border.all(color: scheme.primary, width: 1.6) : null,
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${grille[i][j] >= 0 ? '+' : '−'}${formatCompactNumber(grille[i][j].abs())}',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: grille[i][j] >= 0 ? _vert : Colors.red.shade600),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _ligneComparaison(Scenario x) {
    final scheme = Theme.of(context).colorScheme;
    final r = calculerScenario(x);
    final actif = x.id == _selId;
    final gain = r.marge >= 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _selectionner(x.id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: actif ? scheme.primary.withValues(alpha: 0.10) : null,
            border: Border.all(color: actif ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.6)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(x.nom, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${entier(x.sujets)} sujets · coût ${fcfa(r.total)}', style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${gain ? '+' : '−'}${formatCompactFcfa(r.marge.abs())}', style: TextStyle(fontWeight: FontWeight.w800, color: gain ? _vert : Colors.red.shade600)),
                  Text('${r.margePct.toStringAsFixed(1)} %', style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Valeur calculée, en lecture seule, présentée comme un champ.
class _Lecture extends StatelessWidget {
  final String label;
  final String valeur;

  const _Lecture(this.label, this.valeur);

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, helperText: ' ', enabled: false),
      child: Text(valeur, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _Fait extends StatelessWidget {
  final IconData icone;
  final String label;
  final String valeur;

  const _Fait(this.icone, this.label, this.valeur);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(icone, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(valeur, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
