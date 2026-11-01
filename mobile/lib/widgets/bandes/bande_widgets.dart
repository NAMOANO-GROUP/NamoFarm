import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/bande.dart';
import '../../utils/bande_kpis.dart';
import '../../utils/crm_labels.dart';

final _nf0 = NumberFormat('#,##0', 'fr_FR');
final _nf1 = NumberFormat('#,##0.0', 'fr_FR');
final _nf2 = NumberFormat('#,##0.00', 'fr_FR');

String _clean(String s) => s.replaceAll('\u202F', ' ').replaceAll('\u00A0', ' ');
String fmtEntier(num v) => _clean(_nf0.format(v));
String fmt1(num v) => _clean(_nf1.format(v));
String fmt2(num v) => _clean(_nf2.format(v));

String fmtEcart(double? pct) => pct == null ? '' : '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(0)} %';

/// Tuile d'indicateur compacte (libellé, valeur, info secondaire).
class KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final IconData icon;
  final Color color;
  final String? tooltip;
  final double width;

  const KpiTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.sub,
    this.tooltip,
    this.width = 128,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tile = Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          if (sub != null)
            Text(sub!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
    return tooltip == null ? tile : Tooltip(message: tooltip!, child: tile);
  }
}

/// Tuiles des indicateurs zootechniques d'une bande.
List<Widget> bandeKpiTiles(BandeKpis k, {double width = 128}) {
  final ecart = k.ecartReferencePct;
  return [
    KpiTile(
      width: width,
      label: 'Effectif',
      value: fmtEntier(k.effectif),
      sub: 'Viabilité ${fmt1(k.viabilitePct)} %',
      icon: Icons.groups_outlined,
      color: k.viabilitePct >= 95 ? Colors.teal : (k.viabilitePct >= 90 ? Colors.orange : Colors.red),
      tooltip: 'Sujets vivants et part des sujets de départ encore en vie',
    ),
    KpiTile(
      width: width,
      label: 'Poids moyen',
      value: k.poidsG == null ? '—' : '${fmtEntier(k.poidsG!)} g',
      sub: k.poidsReferenceG == null ? 'Aucune pesée' : 'Réf. ${fmtEntier(k.poidsReferenceG!)} g ${fmtEcart(ecart)}',
      icon: Icons.monitor_weight_outlined,
      color: couleurEcart(ecart),
      tooltip: 'Dernière pesée comparée à la courbe de référence du type de volaille',
    ),
    KpiTile(
      width: width,
      label: 'Gain moyen / jour',
      value: k.gmqG == null ? '—' : '${fmt1(k.gmqG!)} g',
      icon: Icons.trending_up,
      color: Colors.indigo,
      tooltip: 'Gain de poids moyen quotidien depuis l’arrivée (GMQ)',
    ),
    KpiTile(
      width: width,
      label: 'Indice de conso.',
      value: k.ic == null ? '—' : fmt2(k.ic!),
      sub: 'kg aliment / kg vif',
      icon: Icons.restaurant_outlined,
      color: Colors.brown,
      tooltip: 'Aliment consommé jusqu’à la dernière pesée ÷ poids vif total (IC). Plus il est bas, mieux c’est.',
    ),
    KpiTile(
      width: width,
      label: 'Indice d’efficacité',
      value: k.iep == null ? '—' : fmtEntier(k.iep!),
      sub: 'IEP',
      icon: Icons.emoji_events_outlined,
      color: Colors.deepPurple,
      tooltip: 'IEP = viabilité % × poids kg ÷ (âge × IC) × 100. Plus il est élevé, plus la bande est performante.',
    ),
    KpiTile(
      width: width,
      label: 'Mortalité',
      value: '${fmt1(k.mortalitePct)} %',
      sub: '7 j : ${fmt1(k.mortalite7jPct)} %',
      icon: Icons.warning_amber_outlined,
      color: k.mortalite7jPct >= 2 ? Colors.red : Colors.orange,
    ),
    KpiTile(
      width: width,
      label: 'Aliment consommé',
      value: '${fmtEntier(k.alimentTotalKg)} kg',
      icon: Icons.inventory_2_outlined,
      color: Colors.blueGrey,
    ),
  ];
}

/// Barre d'avancement du cycle (J23 / 45, sortie prévue).
class CycleProgress extends StatelessWidget {
  final Bande bande;
  final BandeKpis kpis;
  const CycleProgress({super.key, required this.bande, required this.kpis});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final closed = bande.dateFermeture != null;
    final restant = kpis.joursRestants;
    final droite = closed
        ? 'Fermée le ${formatDateFr(bande.dateFermeture!)}'
        : (restant > 0 ? 'Sortie dans $restant j' : (restant == 0 ? "Sortie aujourd'hui" : 'Sortie dépassée de ${-restant} j'));
    final color = closed ? Colors.blueGrey : (restant < 0 ? Colors.orange : scheme.primary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('J${kpis.ageJours}', style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(' / ${kpis.dureeJours}', style: TextStyle(color: scheme.onSurfaceVariant)),
            const Spacer(),
            Flexible(
              child: Text(droite,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: kpis.progression,
            minHeight: 6,
            color: color,
            backgroundColor: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}

/// Pastilles d'alerte d'une bande.
class BandeAlertesPills extends StatelessWidget {
  final List<BandeAlerte> alertes;
  const BandeAlertesPills({super.key, required this.alertes});

  @override
  Widget build(BuildContext context) {
    if (alertes.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final a in alertes)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: bandeAlerteColors[a]!.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: bandeAlerteColors[a]!.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(bandeAlerteIcons[a], size: 12, color: bandeAlerteColors[a]),
                const SizedBox(width: 4),
                Text(bandeAlerteLabels[a]!,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: bandeAlerteColors[a]!.shade700)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Saisies d'une bande (chaque saisie garde son écran dédié).
enum SaisieBande { poids, alimentation, mortalite, climat }

const saisieLabels = {
  SaisieBande.poids: 'Pesée',
  SaisieBande.alimentation: 'Alimentation',
  SaisieBande.mortalite: 'Mortalité',
  SaisieBande.climat: 'Climat',
};

const saisieIcons = {
  SaisieBande.poids: Icons.monitor_weight_outlined,
  SaisieBande.alimentation: Icons.restaurant_outlined,
  SaisieBande.mortalite: Icons.health_and_safety_outlined,
  SaisieBande.climat: Icons.thermostat_outlined,
};

const saisieColors = {
  SaisieBande.poids: Colors.blue,
  SaisieBande.alimentation: Colors.brown,
  SaisieBande.mortalite: Colors.red,
  SaisieBande.climat: Colors.teal,
};

/// Prochaine tâche liée à une bande (Todo ou tâche de suivi).
typedef ProchaineTache = ({String titre, DateTime date});

/// Carte premium d'une bande dans la liste.
class BandeCard extends StatelessWidget {
  final Bande bande;
  final BandeKpis kpis;
  final ProchaineTache? prochaineTache;
  final VoidCallback onOpen;
  final ValueChanged<SaisieBande>? onSaisie;
  final List<PopupMenuEntry<String>> menuItems;
  final ValueChanged<String>? onMenu;

  const BandeCard({
    super.key,
    required this.bande,
    required this.kpis,
    required this.onOpen,
    this.prochaineTache,
    this.onSaisie,
    this.menuItems = const [],
    this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = bande.dateFermeture == null;
    final headerColors = active ? [Colors.green.shade700, Colors.green.shade400] : [Colors.blueGrey.shade600, Colors.blueGrey.shade400];
    final ecart = kpis.ecartReferencePct;
    final tache = prochaineTache;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
              decoration: BoxDecoration(gradient: LinearGradient(colors: headerColors)),
              child: Row(
                children: [
                  CircleAvatar(backgroundColor: Colors.white.withValues(alpha: 0.25), child: const Icon(Icons.egg_alt, color: Colors.white)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(bande.nom,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text(
                          [typeVolailleLabel(bande.typeVolaille), if (bande.race.isNotEmpty) bande.race, if (bande.batiment.isNotEmpty) bande.batiment]
                              .join(' • '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.92)),
                        ),
                      ],
                    ),
                  ),
                  if (menuItems.isNotEmpty)
                    PopupMenuButton<String>(
                      tooltip: 'Options',
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      onSelected: onMenu,
                      itemBuilder: (_) => menuItems,
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CycleProgress(bande: bande, kpis: kpis),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _Metric(label: 'Effectif', value: fmtEntier(kpis.effectif), sub: '${fmt1(kpis.viabilitePct)} % vivants'),
                      _Metric(
                        label: 'Poids',
                        value: kpis.poidsG == null ? '—' : '${fmtEntier(kpis.poidsG!)} g',
                        sub: ecart == null ? 'pas de pesée' : '${fmtEcart(ecart)} vs réf.',
                        color: couleurEcart(ecart),
                      ),
                      _Metric(label: 'IC', value: kpis.ic == null ? '—' : fmt2(kpis.ic!), sub: 'IEP ${kpis.iep == null ? '—' : fmtEntier(kpis.iep!)}'),
                    ],
                  ),
                  if (kpis.alertes.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    BandeAlertesPills(alertes: kpis.alertes),
                  ],
                  if (tache != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.event_note_outlined, size: 16, color: scheme.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(tache.titre, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                        ),
                        Text(relativeDay(tache.date),
                            style: TextStyle(
                              fontSize: 12,
                              color: daysFromToday(tache.date) < 0 ? Colors.red : scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            )),
                      ],
                    ),
                  ],
                  if (active && onSaisie != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (final s in SaisieBande.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: IconButton.filledTonal(
                              tooltip: saisieLabels[s],
                              visualDensity: VisualDensity.compact,
                              icon: Icon(saisieIcons[s], size: 18, color: saisieColors[s]),
                              onPressed: () => onSaisie!(s),
                            ),
                          ),
                        const Spacer(),
                        TextButton(onPressed: onOpen, child: const Text('Ouvrir')),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color? color;

  const _Metric({required this.label, required this.value, required this.sub, this.color});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: muted)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: color ?? muted, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
