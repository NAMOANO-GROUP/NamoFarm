import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/cheptel.dart';
import '../../providers/cheptel_provider.dart';
import '../../utils/cheptel.dart';
import '../../utils/crm_labels.dart';
import '../../utils/finance.dart' show fcfa;
import '../../utils/number_input.dart';
import '../../widgets/iso_calendar_picker.dart';

/// Saisie express d'un mouvement (feuille du bas). Renvoie true si enregistré.
Future<bool?> showMouvementCheptelSheet(BuildContext context, Cheptel c, {String type = 'naissance'}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => MouvementCheptelSheet(cheptel: c, typeInitial: type),
  );
}

class MouvementCheptelSheet extends StatefulWidget {
  final Cheptel cheptel;
  final String typeInitial;

  const MouvementCheptelSheet({super.key, required this.cheptel, this.typeInitial = 'naissance'});

  @override
  State<MouvementCheptelSheet> createState() => _MouvementCheptelSheetState();
}

enum _Jour { aujourdhui, hier, autre }

class _MouvementCheptelSheetState extends State<MouvementCheptelSheet> {
  late String _type = widget.typeInitial;
  late final _quantite = TextEditingController(text: _type == 'ajustement' ? '${widget.cheptel.effectifActuel}' : '1');
  final _prix = TextEditingController();
  final _note = TextEditingController();
  _Jour _jour = _Jour.aujourdhui;
  DateTime _autreDate = DateTime.now();
  bool _enCours = false;

  @override
  void dispose() {
    _quantite.dispose();
    _prix.dispose();
    _note.dispose();
    super.dispose();
  }

  TypeMouvementCheptel get _t => typeMouvement(_type);
  int get _qte => parseInteger(_quantite.text) ?? 0;
  double get _prixUnitaire => parseAmount(_prix.text) ?? 0;

  int get _effectifApres => effectifApresMouvement(widget.cheptel, _type, _qte, _date);

  DateTime get _date {
    final now = DateTime.now();
    switch (_jour) {
      case _Jour.aujourdhui:
        return now;
      case _Jour.hier:
        return DateTime(now.year, now.month, now.day - 1, now.hour, now.minute, now.second, now.millisecond);
      case _Jour.autre:
        return DateTime(_autreDate.year, _autreDate.month, _autreDate.day, now.hour, now.minute, now.second, now.millisecond);
    }
  }

  void _changerType(String type) {
    setState(() {
      if (type == 'ajustement' && _type != 'ajustement') _quantite.text = '${widget.cheptel.effectifActuel}';
      if (type != 'ajustement' && _type == 'ajustement') _quantite.text = '1';
      _type = type;
    });
  }

  void _ajuster(int delta) {
    final v = (_qte + delta).clamp(0, 1000000);
    setState(() => _quantite.text = '$v');
  }

  Future<void> _choisirDate() async {
    final picked = await showIsoDatePicker(
      context: context,
      initialDate: _autreDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        _autreDate = picked;
        _jour = _Jour.autre;
      });
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

  Future<void> _enregistrer() async {
    if (_t.signe != 0 && _qte <= 0) return _snack('Indiquez le nombre d’animaux.');
    if (_effectifApres < 0) {
      return _snack('Impossible : l’effectif deviendrait négatif.');
    }
    if (widget.cheptel.id == null) return;
    setState(() => _enCours = true);
    final provider = context.read<CheptelProvider>();
    final ok = await provider.ajouterMouvement(widget.cheptel.id!, {
      'type': _type,
      'quantite': _qte,
      'montant': _t.avecPrix ? _qte * _prixUnitaire : 0,
      'date': _date.toUtc().toIso8601String(),
      'motif': _note.text.trim(),
    });
    if (!mounted) return;
    setState(() => _enCours = false);
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      _snack('Enregistrement impossible : ${provider.lastError ?? 'erreur inconnue'}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = _t;
    final total = _qte * _prixUnitaire;
    final apres = _effectifApres;
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
                  Text(widget.cheptel.nom, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  Text(
                    '${widget.cheptel.effectifActuel} animaux aujourd’hui',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final x in typesMouvementCheptel)
                        ChoiceChip(
                          avatar: Icon(x.icon, size: 16, color: x.color),
                          label: Text(x.court),
                          selected: _type == x.valeur,
                          onSelected: (_) => _changerType(x.valeur),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t.signe == 0 ? 'Nombre d’animaux comptés' : 'Nombre d’animaux',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filledTonal(
                        tooltip: 'Moins',
                        onPressed: _qte > 0 ? () => _ajuster(-1) : null,
                        icon: const Icon(Icons.remove),
                      ),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          key: const Key('cheptel-quantite'),
                          controller: _quantite,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          inputFormatters: [ThousandsSeparatorInputFormatter(allowDecimal: false)],
                          onChanged: (_) => setState(() {}),
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: t.color.shade700),
                          decoration: const InputDecoration(border: InputBorder.none),
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Plus',
                        onPressed: () => _ajuster(1),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  Text(
                    apres < 0
                        ? 'Impossible : l’effectif deviendrait négatif ($apres)'
                        : 'Effectif après : $apres',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w600, color: apres < 0 ? Colors.red : scheme.primary),
                  ),
                  if (t.avecPrix) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _prix,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [ThousandsSeparatorInputFormatter(allowDecimal: true)],
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: _type == 'vente' ? 'Prix de vente par tête' : 'Prix d’achat par tête',
                        suffixText: 'FCFA',
                        prefixIcon: const Icon(Icons.payments_outlined),
                        helperText: total > 0
                            ? 'Total : ${fcfa(total)} — ${_type == 'vente' ? 'ajouté en entrée' : 'ajouté en sortie'} dans la Finance'
                            : 'Facultatif',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
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
                  const SizedBox(height: 8),
                  TextField(
                    controller: _note,
                    decoration: const InputDecoration(
                      labelText: 'Note (facultatif)',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: FilledButton.icon(
              key: const Key('cheptel-enregistrer'),
              style: FilledButton.styleFrom(backgroundColor: t.color.shade700, minimumSize: const Size.fromHeight(50)),
              onPressed: _enCours ? null : _enregistrer,
              icon: _enCours
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(t.icon),
              label: Text('Enregistrer : ${t.libelle.toLowerCase()}'),
            ),
          ),
        ],
      ),
    );
  }
}
