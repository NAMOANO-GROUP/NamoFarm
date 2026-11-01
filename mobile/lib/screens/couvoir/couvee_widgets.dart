import 'package:flutter/material.dart';

import '../../models/couvee.dart';
import '../../utils/couvoir.dart';
import '../../utils/crm_labels.dart';

/// Barre d'avancement de l'incubation (J12 / 21, compte à rebours).
class AvancementIncubation extends StatelessWidget {
  final AvancementCouvee av;
  const AvancementIncubation(this.av, {super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final couleur = av.enRetard ? Colors.orange : (av.joursRestants <= 3 ? Colors.green : Colors.amber.shade800);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('J${av.age}', style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(' / ${av.duree}', style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                av.libelleEcheance,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: couleur),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: av.progression,
            minHeight: 6,
            color: couleur,
            backgroundColor: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        if (av.prochaineEtape != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(av.prochaineEtape!.icon, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Prochaine étape : ${av.prochaineEtape!.titre} (${relativeDay(av.prochaineEtape!.date)})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Entonnoir compact sur une ligne : 120 → 96 → 94.
class EntonnoirMini extends StatelessWidget {
  final Couvee c;
  const EntonnoirMini(this.c, {super.key});

  @override
  Widget build(BuildContext context) {
    final etages = entonnoirCouvee(c);
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var i = 0; i < etages.length; i++) ...[
          if (i > 0) Icon(Icons.chevron_right, size: 16, color: scheme.onSurfaceVariant),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${etages[i].nombre}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                Text(
                  etages[i].libelle.replaceFirst('Poussins ', '').replaceFirst('Œufs ', ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Entonnoir visuel : barres décroissantes avec pertes à chaque étape.
class EntonnoirVisuel extends StatelessWidget {
  final Couvee c;
  const EntonnoirVisuel(this.c, {super.key});

  static const _couleurs = [Colors.amber, Colors.orange, Colors.green, Colors.teal];

  @override
  Widget build(BuildContext context) {
    final etages = entonnoirCouvee(c);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (var i = 0; i < etages.length; i++) ...[
          if (etages[i].pertes > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Icon(Icons.south, size: 14, color: Colors.red.shade400),
                  const SizedBox(width: 4),
                  Text('−${etages[i].pertes} ${etages[i].libellePertes}',
                      style: TextStyle(fontSize: 12, color: Colors.red.shade400)),
                ],
              ),
            ),
          LayoutBuilder(builder: (context, cs) {
            final largeur = (cs.maxWidth * (etages[i].pctIncubes / 100)).clamp(56.0, cs.maxWidth);
            final couleur = _couleurs[i % _couleurs.length];
            return Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: largeur,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: couleur.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: couleur.withValues(alpha: 0.5)),
                ),
                child: Text('${etages[i].nombre}', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            );
          }),
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 2, bottom: 4),
            child: Row(
              children: [
                Expanded(child: Text(etages[i].libelle, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant))),
                if (i > 0)
                  Text('${etages[i].pctIncubes.toStringAsFixed(1)} % des œufs',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Frise des étapes de l'incubation (faites, aujourd'hui, à venir).
class FriseEtapes extends StatelessWidget {
  final Couvee c;
  const FriseEtapes(this.c, {super.key});

  @override
  Widget build(BuildContext context) {
    final etapes = etapesCouvee(c);
    final today = DateTime.now();
    final aujourdhui = DateTime(today.year, today.month, today.day);
    final eclose = !enIncubation(c);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (var i = 0; i < etapes.length; i++)
          () {
            final e = etapes[i];
            final faite = eclose || e.date.isBefore(aujourdhui);
            final jour = !eclose && e.date == aujourdhui;
            final couleur = jour ? Colors.amber.shade800 : (faite ? Colors.green : scheme.outline);
            final derniere = i == etapes.length - 1;
            final date = derniere && c.dateEclosion != null ? c.dateEclosion!.toLocal() : e.date;
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 32,
                    child: Column(
                      children: [
                        Icon(faite ? Icons.check_circle : (jour ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                            size: 20, color: couleur),
                        if (!derniere) Expanded(child: Container(width: 2, color: couleur.withValues(alpha: 0.4))),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('J${e.jour} · ${e.titre}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            '${formatDateFr(date)}${jour ? ' · aujourd’hui' : ''}',
                            style: TextStyle(fontSize: 12, color: jour ? Colors.amber.shade800 : scheme.onSurfaceVariant),
                          ),
                          if (!faite) Text(e.conseil, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }(),
      ],
    );
  }
}

/// Pastilles d'alerte d'une couvée.
class AlertesCouveePills extends StatelessWidget {
  final List<AlerteCouvee> alertes;
  const AlertesCouveePills(this.alertes, {super.key});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final a in alertes)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: alerteCouveeCouleurs[a]!.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: alerteCouveeCouleurs[a]!.withValues(alpha: 0.4)),
              ),
              child: Text(alerteCouveeLibelles[a]!,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: alerteCouveeCouleurs[a]!.shade700)),
            ),
        ],
      );
}

/// Taux comparé à un objectif (barre et écart).
class TauxObjectif extends StatelessWidget {
  final String libelle;
  final double? taux;
  final double objectif;

  const TauxObjectif({super.key, required this.libelle, required this.taux, required this.objectif});

  @override
  Widget build(BuildContext context) {
    final t = taux;
    final scheme = Theme.of(context).colorScheme;
    final atteint = t != null && t >= objectif;
    final couleur = t == null ? scheme.outline : (atteint ? Colors.green.shade700 : (t >= objectif - 15 ? Colors.orange.shade800 : Colors.red.shade700));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(libelle, style: const TextStyle(fontWeight: FontWeight.w600))),
              Text(t == null ? '—' : '${t.toStringAsFixed(1)} %', style: TextStyle(fontWeight: FontWeight.w800, color: couleur)),
            ],
          ),
          const SizedBox(height: 4),
          LayoutBuilder(builder: (context, cs) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ((t ?? 0) / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    color: couleur,
                    backgroundColor: scheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                Positioned(
                  left: cs.maxWidth * objectif / 100 - 1,
                  top: -3,
                  child: Container(width: 2, height: 14, color: scheme.onSurface),
                ),
              ],
            );
          }),
          const SizedBox(height: 2),
          Text(
            t == null
                ? 'Objectif ${objectif.round()} %'
                : (atteint ? 'Objectif ${objectif.round()} % atteint' : 'Objectif ${objectif.round()} % : ${(objectif - t).toStringAsFixed(1)} points en dessous'),
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
