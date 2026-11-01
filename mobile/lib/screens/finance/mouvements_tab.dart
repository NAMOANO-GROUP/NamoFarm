import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/finance_provider.dart';
import '../../utils/crm_labels.dart';
import '../../utils/finance.dart';
import '../../widgets/empty_state.dart';
import 'finance_common.dart';
import 'mouvement_dialogs.dart';

/// Journal des mouvements : recherche, menu Filtres (multi-choix), totaux, regroupement par jour.
class MouvementsTab extends StatefulWidget {
  const MouvementsTab({super.key});

  @override
  State<MouvementsTab> createState() => _MouvementsTabState();
}

// Garde recherche et filtres quand on change d'onglet (ils doivent rester alignés sur le provider).
class _MouvementsTabState extends State<MouvementsTab> with AutomaticKeepAliveClientMixin {
  final _recherche = TextEditingController();
  final Set<String> _natures = {};
  final Set<String> _origines = {};
  PeriodeFinance _periode = PeriodeFinance.tout;
  DateTimeRange? _intervalle;

  @override
  bool get wantKeepAlive => true;

  List<String> get _sources => [for (final o in _origines) ...?originesFiltre[o]];

  int get _nbFiltres => _natures.length + _origines.length + (_periode == PeriodeFinance.tout ? 0 : 1);

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  Future<void> _recharger() {
    final b = bornesPeriode(_periode, debut: _intervalle?.start, fin: _intervalle?.end);
    return context.read<FinanceProvider>().appliquerFiltresJournal(sources: _sources, from: b.from, to: b.to);
  }

  Future<void> _choisirPeriode(PeriodeFinance p) async {
    if (p == PeriodeFinance.intervalle) {
      final now = DateTime.now();
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(now.year + 1, 12, 31),
        initialDateRange: _intervalle,
        helpText: 'Choisir la période',
      );
      if (picked == null || !mounted) return;
      _intervalle = picked;
    }
    setState(() => _periode = p);
    await _recharger();
  }

  void _reinitialiser() {
    setState(() {
      _natures.clear();
      _origines.clear();
      _periode = PeriodeFinance.tout;
      _intervalle = null;
    });
    _recharger();
  }

  String _libellePeriode() {
    if (_periode == PeriodeFinance.intervalle && _intervalle != null) {
      return 'Du ${formatDateFr(_intervalle!.start)} au ${formatDateFr(_intervalle!.end)}';
    }
    return periodeLibelles[_periode]!;
  }

  Widget _filtreMenu() {
    final actifs = _nbFiltres;
    return MenuAnchor(
      alignmentOffset: const Offset(0, 4),
      menuChildren: [
        const _MenuTitre('Sens'),
        for (final e in const {'entree': 'Entrées d’argent', 'sortie': 'Sorties d’argent'}.entries)
          CheckboxMenuButton(
            closeOnActivate: false,
            value: _natures.contains(e.key),
            onChanged: (v) => setState(() => v == true ? _natures.add(e.key) : _natures.remove(e.key)),
            child: Text(e.value),
          ),
        const Divider(height: 8),
        const _MenuTitre('Origine'),
        for (final o in originesFiltre.keys)
          CheckboxMenuButton(
            closeOnActivate: false,
            value: _origines.contains(o),
            onChanged: (v) {
              setState(() => v == true ? _origines.add(o) : _origines.remove(o));
              _recharger();
            },
            child: Text(o),
          ),
        const Divider(height: 8),
        const _MenuTitre('Période'),
        for (final p in PeriodeFinance.values)
          RadioMenuButton<PeriodeFinance>(
            value: p,
            groupValue: _periode,
            onChanged: (v) => _choisirPeriode(v ?? p),
            child: Text(p == PeriodeFinance.intervalle && _periode == p ? _libellePeriode() : periodeLibelles[p]!),
          ),
        if (actifs > 0) ...[
          const Divider(height: 8),
          MenuItemButton(
            leadingIcon: const Icon(Icons.filter_alt_off_outlined, size: 18),
            onPressed: _reinitialiser,
            child: const Text('Réinitialiser les filtres'),
          ),
        ],
      ],
      builder: (context, controller, _) {
        void toggle() => controller.isOpen ? controller.close() : controller.open();
        final icon = Badge(
          isLabelVisible: actifs > 0,
          label: Text('$actifs'),
          child: const Icon(Icons.filter_list, size: 20),
        );
        if (MediaQuery.sizeOf(context).width < 600) {
          return IconButton.outlined(tooltip: 'Filtres', onPressed: toggle, icon: icon);
        }
        return OutlinedButton.icon(onPressed: toggle, icon: icon, label: const Text('Filtres'));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = context.watch<FinanceProvider>();
    final tous = parseMouvements(provider.mouvements);
    final visibles = filtrerJournal(tous, natures: _natures, recherche: _recherche.text, nomBande: provider.nomBande);
    final t = totaux(visibles);
    final groupes = grouperParJour(visibles);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _recherche,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Rechercher (aliment, nom, montant…)',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _recherche.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Effacer',
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(_recherche.clear),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _filtreMenu(),
            ],
          ),
        ),
        if (provider.isLoading) const LinearProgressIndicator(minHeight: 2),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: Row(
            children: [
              _Total('Entrées', t.entrees, Colors.green.shade700),
              _Total('Sorties', t.sorties, Colors.red.shade700),
              _Total(
                'Reste',
                t.entrees - t.sorties,
                (t.entrees - t.sorties) >= 0 ? scheme.primary : Colors.red.shade700,
              ),
            ],
          ),
        ),
        if (_periode != PeriodeFinance.tout || provider.mouvements.length >= 1000)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                [
                  if (_periode != PeriodeFinance.tout) _libellePeriode(),
                  if (provider.mouvements.length >= 1000) '1000 mouvements les plus récents',
                ].join(' · '),
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _recharger,
            child: visibles.isEmpty
                ? ListView(
                    children: [
                      EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: tous.isEmpty ? 'Aucun mouvement' : 'Aucun résultat',
                        subtitle: tous.isEmpty
                            ? 'Les dépenses, apports et ventes apparaîtront ici.'
                            : 'Modifiez la recherche ou les filtres.',
                        actionLabel: _nbFiltres > 0 ? 'Réinitialiser les filtres' : null,
                        actionIcon: Icons.filter_alt_off_outlined,
                        onAction: _nbFiltres > 0 ? _reinitialiser : null,
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: groupes.length,
                    itemBuilder: (context, i) => _JourGroupe(groupe: groupes[i], nomBande: provider.nomBande),
                  ),
          ),
        ),
      ],
    );
  }
}

class _MenuTitre extends StatelessWidget {
  final String texte;
  const _MenuTitre(this.texte);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
    child: Text(
      texte,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary),
    ),
  );
}

class _Total extends StatelessWidget {
  final String label;
  final double valeur;
  final Color couleur;

  const _Total(this.label, this.valeur, this.couleur);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: couleur.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              fcfa(valeur),
              style: TextStyle(fontWeight: FontWeight.w800, color: couleur),
            ),
          ),
        ],
      ),
    ),
  );
}

class _JourGroupe extends StatelessWidget {
  final ({DateTime jour, List<Mouvement> mouvements}) groupe;
  final String Function(String) nomBande;

  const _JourGroupe({required this.groupe, required this.nomBande});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = totaux(groupe.mouvements);
    final net = t.entrees - t.sorties;
    final sansDate = groupe.jour.year == 1970;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  sansDate ? 'Sans date' : timelineDayLabel(groupe.jour),
                  style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant),
                ),
              ),
              Text(
                montantSigne(net.abs(), net >= 0),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: couleurMontant(net >= 0)),
              ),
            ],
          ),
        ),
        Card(
          elevation: 0,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < groupe.mouvements.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 64),
                _MouvementLigne(m: groupe.mouvements[i], bande: nomBande(groupe.mouvements[i].bandeId)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MouvementLigne extends StatelessWidget {
  final Mouvement m;
  final String bande;

  const _MouvementLigne({required this.m, required this.bande});

  @override
  Widget build(BuildContext context) {
    final details = [
      if (bande.isNotEmpty) bande,
      if (m.qui.isNotEmpty) m.qui,
      if (m.commentaire.isNotEmpty) m.commentaire,
    ].join(' · ');
    return ListTile(
      onTap: () => showMouvementDetail(context, m),
      leading: CircleAvatar(
        backgroundColor: m.color.withValues(alpha: 0.14),
        child: Icon(m.icon, color: m.color, size: 20),
      ),
      title: Text(
        m.libelle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: details.isEmpty ? null : Text(details, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            montantSigne(m.montant, m.entree),
            style: TextStyle(fontWeight: FontWeight.w700, color: couleurMontant(m.entree)),
          ),
          if (m.date != null) Text(formatHeure(m.date!), style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}
