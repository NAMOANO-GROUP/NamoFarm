import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/finance_provider.dart';
import '../../utils/crm_labels.dart';
import '../../utils/finance.dart';
import '../../utils/number_input.dart';
import '../../widgets/iso_calendar_picker.dart';
import 'finance_common.dart';

/// Saisie express d'une dépense ou d'une entrée d'argent (feuille du bas).
/// [modele] pré-remplit une dépense à refaire. Renvoie true si l'opération est enregistrée.
Future<bool?> showOperationSheet(BuildContext context, {bool entree = false, Mouvement? modele}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => OperationSheet(entree: entree, modele: modele),
  );
}

class OperationSheet extends StatefulWidget {
  final bool entree;
  final Mouvement? modele;

  const OperationSheet({super.key, this.entree = false, this.modele});

  @override
  State<OperationSheet> createState() => _OperationSheetState();
}

enum _Jour { aujourdhui, hier, autre }

class _OperationSheetState extends State<OperationSheet> {
  final _montant = TextEditingController();
  final _prenom = TextEditingController();
  final _nom = TextEditingController();
  final _commentaire = TextEditingController();
  late bool _entree = widget.entree;
  String? _poste;
  String _activite = activiteParDefaut;
  String _bandeId = '';
  _Jour _jour = _Jour.aujourdhui;
  DateTime _autreDate = DateTime.now();
  bool _detailsOuverts = false;
  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    final user = utilisateurConnecte(context);
    _prenom.text = user.prenom;
    _nom.text = user.nom;
    _detailsOuverts = user.prenom.isEmpty || user.nom.isEmpty;
    final m = widget.modele;
    if (m != null) _appliquerModele(m);
  }

  @override
  void dispose() {
    _montant.dispose();
    _prenom.dispose();
    _nom.dispose();
    _commentaire.dispose();
    super.dispose();
  }

  void _appliquerModele(Mouvement m) {
    _entree = false;
    _montant.text = montantSaisie(m.montant);
    _poste = m.type.trim().isEmpty ? 'Divers' : m.type.trim();
    _activite = m.categorie.trim().isEmpty ? activiteParDefaut : m.categorie.trim();
    // Une bande fermée n'est plus proposée : la dépense refaite part sans bande.
    final ouverte = context.read<FinanceProvider>().bandesOuvertes.any(
      (b) => (b['_id'] ?? b['id'] ?? '').toString() == m.bandeId,
    );
    _bandeId = ouverte ? m.bandeId : '';
  }

  DateTime get _date {
    final now = DateTime.now();
    switch (_jour) {
      case _Jour.aujourdhui:
        return now;
      case _Jour.hier:
        return DateTime(now.year, now.month, now.day - 1, now.hour, now.minute);
      case _Jour.autre:
        return DateTime(_autreDate.year, _autreDate.month, _autreDate.day, now.hour, now.minute);
    }
  }

  Future<void> _choisirDate() async {
    final picked = await showIsoDatePicker(
      context: context,
      initialDate: _autreDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() {
        _autreDate = picked;
        _jour = _Jour.autre;
      });
    }
  }

  Future<void> _enregistrer() async {
    final montant = parseAmount(_montant.text) ?? 0;
    String? erreur;
    if (montant <= 0) {
      erreur = 'Indiquez le montant.';
    } else if (!_entree && _poste == null) {
      erreur = 'Choisissez à quoi correspond la dépense.';
    } else if (_prenom.text.trim().isEmpty || _nom.text.trim().isEmpty) {
      erreur = 'Indiquez le prénom et le nom de la personne.';
      setState(() => _detailsOuverts = true);
    }
    if (erreur != null) {
      financeSnack(context, erreur);
      return;
    }

    setState(() => _enCours = true);
    final provider = context.read<FinanceProvider>();
    final payload = <String, dynamic>{
      'quiPrenom': _prenom.text.trim(),
      'quiNom': _nom.text.trim(),
      'montant': montant,
      'date': _date.toUtc().toIso8601String(),
      'commentaire': _commentaire.text.trim(),
    };
    final ok = _entree
        ? await provider.ajouterApprovisionnement(payload)
        : await provider.ajouterDepense({
            ...payload,
            'categorie': _activite,
            'type': _poste,
            if (_bandeId.isNotEmpty) 'bandeId': _bandeId,
          });
    if (!mounted) return;
    setState(() => _enCours = false);
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      financeSnack(context, 'Enregistrement impossible : ${provider.lastError ?? 'erreur inconnue'}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final scheme = Theme.of(context).colorScheme;
    final couleur = _entree ? Colors.green.shade700 : Colors.red.shade700;
    final poste = _poste == null ? null : postePour(_poste!);
    final bandes = provider.bandesOuvertes;
    final recents = _entree ? const <Mouvement>[] : depensesRecentes(provider.mouvementsRecents);

    // Bouton Enregistrer épinglé en bas : toujours visible, même sur un petit écran.
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, icon: Icon(Icons.remove_circle_outline), label: Text('Dépense')),
                      ButtonSegment(value: true, icon: Icon(Icons.add_circle_outline), label: Text('Entrée d’argent')),
                    ],
                    selected: {_entree},
                    onSelectionChanged: (s) => setState(() => _entree = s.first),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('operation-montant'),
                    controller: _montant,
                    autofocus: widget.modele == null,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [ThousandsSeparatorInputFormatter(allowDecimal: true)],
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: couleur),
                    decoration: InputDecoration(
                      hintText: '0',
                      suffixText: 'FCFA',
                      border: InputBorder.none,
                      filled: true,
                      fillColor: couleur.withValues(alpha: 0.06),
                      labelText: _entree ? 'Montant reçu' : 'Montant payé',
                      floatingLabelAlignment: FloatingLabelAlignment.center,
                    ),
                  ),
                  if (_entree)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Apport en caisse (argent déposé par vous ou un associé). '
                        'Les ventes sont enregistrées automatiquement depuis les commandes payées.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ),
                  if (recents.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text('Refaire une dépense récente', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final m in recents)
                          ActionChip(
                            avatar: Icon(m.icon, size: 16, color: m.color),
                            label: Text('${m.libelle} · ${fcfa(m.montant)}', overflow: TextOverflow.ellipsis),
                            onPressed: () => setState(() => _appliquerModele(m)),
                          ),
                      ],
                    ),
                  ],
                  if (!_entree) ...[
                    const SizedBox(height: 14),
                    Text(
                      'À quoi correspond cette dépense ?',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 6),
                    LayoutBuilder(
                      builder: (context, c) {
                        final colonnes = c.maxWidth >= 520 ? 5 : 3;
                        final largeur = (c.maxWidth - (colonnes - 1) * 6) / colonnes;
                        final postes = [...postesDepense];
                        if (_poste != null && !postes.any((p) => p.valeur == _poste)) {
                          postes.insert(0, postePour(_poste!));
                        }
                        return Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final p in postes)
                              SizedBox(
                                width: largeur,
                                child: _PosteTuile(
                                  poste: p,
                                  selectionne: _poste == p.valeur,
                                  onTap: () => setState(() => _poste = p.valeur),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    if (bandes.isNotEmpty && ((poste?.lieABande ?? false) || _bandeId.isNotEmpty)) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey('bande-$_bandeId'),
                        initialValue: bandes.any((b) => (b['_id'] ?? b['id'] ?? '').toString() == _bandeId)
                            ? _bandeId
                            : '',
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Pour quelle bande ?',
                          prefixIcon: Icon(Icons.layers_outlined),
                        ),
                        items: [
                          const DropdownMenuItem(value: '', child: Text('Aucune bande en particulier')),
                          for (final b in bandes)
                            DropdownMenuItem(
                              value: (b['_id'] ?? b['id'] ?? '').toString(),
                              child: Text((b['nom'] ?? 'Bande').toString(), overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        onChanged: (v) => setState(() => _bandeId = v ?? ''),
                      ),
                    ],
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text('Aujourd’hui'),
                        selected: _jour == _Jour.aujourdhui,
                        onSelected: (_) => setState(() => _jour = _Jour.aujourdhui),
                      ),
                      ChoiceChip(
                        label: const Text('Hier'),
                        selected: _jour == _Jour.hier,
                        onSelected: (_) => setState(() => _jour = _Jour.hier),
                      ),
                      ChoiceChip(
                        avatar: const Icon(Icons.event_outlined, size: 16),
                        label: Text(_jour == _Jour.autre ? formatDateFr(_autreDate) : 'Autre date'),
                        selected: _jour == _Jour.autre,
                        onSelected: (_) => _choisirDate(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      key: ValueKey('details-$_detailsOuverts'),
                      initiallyExpanded: _detailsOuverts,
                      onExpansionChanged: (v) => _detailsOuverts = v,
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Plus de détails', style: TextStyle(fontSize: 14)),
                      subtitle: Text(
                        [
                          '${_entree ? 'Apporté' : 'Payé'} par ${'${_prenom.text} ${_nom.text}'.trim().isEmpty ? '—' : '${_prenom.text} ${_nom.text}'.trim()}',
                          if (!_entree) activiteLibelle(_activite),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                      childrenPadding: const EdgeInsets.only(bottom: 8),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _prenom,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(labelText: 'Prénom'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _nom,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(labelText: 'Nom'),
                              ),
                            ),
                          ],
                        ),
                        if (!_entree) ...[
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _activite,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Activité',
                              prefixIcon: Icon(Icons.category_outlined),
                            ),
                            items: [
                              if (!activites.containsKey(_activite))
                                DropdownMenuItem(value: _activite, child: Text(_activite)),
                              for (final e in activites.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                            ],
                            onChanged: (v) => setState(() => _activite = v ?? _activite),
                          ),
                        ],
                        const SizedBox(height: 8),
                        TextField(
                          controller: _commentaire,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Note (facultatif)',
                            prefixIcon: Icon(Icons.notes_outlined),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: FilledButton.icon(
              key: const Key('operation-enregistrer'),
              style: FilledButton.styleFrom(backgroundColor: couleur, minimumSize: const Size.fromHeight(50)),
              onPressed: _enCours ? null : _enregistrer,
              icon: _enCours
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check),
              label: Text(_entree ? 'Enregistrer l’entrée' : 'Enregistrer la dépense'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PosteTuile extends StatelessWidget {
  final FinancePoste poste;
  final bool selectionne;
  final VoidCallback onTap;

  const _PosteTuile({required this.poste, required this.selectionne, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final couleur = poste.color;
    return Material(
      color: selectionne ? couleur.withValues(alpha: 0.16) : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selectionne ? couleur : Colors.transparent, width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(poste.icon, size: 20, color: couleur),
              const SizedBox(height: 4),
              Text(
                poste.libelle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, fontWeight: selectionne ? FontWeight.w700 : FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
