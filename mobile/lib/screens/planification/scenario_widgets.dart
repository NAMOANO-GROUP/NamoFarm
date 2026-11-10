import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../utils/number_input.dart';
import '../../utils/scenario.dart';

final _entier = NumberFormat('#,##0', 'fr_FR');
final _decimal = NumberFormat('#,##0.##', 'fr_FR');

String fcfa(num v) => '${_entier.format(v.round())} FCFA';
String entier(num v) => _entier.format(v.round());
String decimal(num v) => _decimal.format(v);
String pct(num v) => '${NumberFormat('0.#', 'fr_FR').format(v)} %';

const couleurOrigine = {
  Origine.reel: Color(0xFF2E7D32),
  Origine.reference: Color(0xFF1565C0),
  Origine.estime: Color(0xFFEF6C00),
  Origine.modifie: Color(0xFF78909C),
};

/// Carte de section : pastille d'icône colorée, titre, sous-titre et contenu.
class CarteSection extends StatelessWidget {
  final IconData icone;
  final Color couleur;
  final String titre;
  final String? sousTitre;
  final Widget? action;
  final List<Widget> children;

  const CarteSection({
    super.key,
    required this.icone,
    required this.couleur,
    required this.titre,
    required this.children,
    this.sousTitre,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [couleur.withValues(alpha: 0.30), couleur.withValues(alpha: 0.12)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icone, size: 20, color: couleur),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titre, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    if (sousTitre != null)
                      Text(sousTitre!, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

/// Champs côte à côte : 2 colonnes (3 sur grand écran), qui passent à la ligne.
class GrilleChamps extends StatelessWidget {
  final List<Widget> children;
  final int? colonnes;

  const GrilleChamps({super.key, required this.children, this.colonnes});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final n = colonnes ?? (c.maxWidth >= 520 ? 3 : 2);
        const gap = 10.0;
        final w = (c.maxWidth - gap * (n - 1)) / n;
        return Wrap(
          spacing: gap,
          runSpacing: 12,
          children: [for (final f in children) SizedBox(width: w, child: f)],
        );
      },
    );
  }
}

/// Champ numérique avec séparateur de milliers et pastille de provenance (Vos données, Référence...).
class ChampNombre extends StatefulWidget {
  final String label;
  final double valeur;
  final ValueChanged<double> onChanged;
  final String? suffixe;
  final bool decimale;
  final Origine? origine;

  /// Réserve la ligne d'aide pour aligner les champs d'une même rangée.
  final bool reserverAide;

  const ChampNombre({
    super.key,
    required this.label,
    required this.valeur,
    required this.onChanged,
    this.suffixe,
    this.decimale = true,
    this.origine,
    this.reserverAide = true,
  });

  @override
  State<ChampNombre> createState() => _ChampNombreState();
}

class _ChampNombreState extends State<ChampNombre> {
  late final TextEditingController _c = TextEditingController(text: _texte(widget.valeur));

  static String _texte(double v) {
    final brut = v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '');
    return const ThousandsSeparatorInputFormatter()
        .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: brut))
        .text;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.origine;
    return TextField(
      controller: _c,
      keyboardType: TextInputType.numberWithOptions(decimal: widget.decimale),
      inputFormatters: [ThousandsSeparatorInputFormatter(allowDecimal: widget.decimale)],
      onChanged: (t) => widget.onChanged(parseAmount(t) ?? 0),
      decoration: InputDecoration(
        labelText: widget.label,
        suffixText: widget.suffixe,
        helperText: o != null ? origineLabels[o] : (widget.reserverAide ? ' ' : null),
        helperStyle: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: o == null ? null : couleurOrigine[o]),
      ),
    );
  }
}

/// Valeur qui glisse vers sa nouvelle valeur quand elle change.
class ValeurAnimee extends StatelessWidget {
  final double valeur;
  final String Function(double) format;
  final TextStyle? style;

  const ValeurAnimee({super.key, required this.valeur, required this.format, this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: valeur),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Text(format(v), style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

/// Indicateur clé : libellé, grande valeur animée et précision.
class TuileKpi extends StatelessWidget {
  final IconData icone;
  final String label;
  final double valeur;
  final String Function(double) format;
  final String? detail;
  final Color couleur;

  const TuileKpi({
    super.key,
    required this.icone,
    required this.label,
    required this.valeur,
    required this.format,
    required this.couleur,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [couleur.withValues(alpha: 0.16), couleur.withValues(alpha: 0.05)],
        ),
        border: Border.all(color: couleur.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icone, size: 16, color: couleur),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: ValeurAnimee(
              valeur: valeur,
              format: format,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: couleur),
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 2),
            Text(detail!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}
