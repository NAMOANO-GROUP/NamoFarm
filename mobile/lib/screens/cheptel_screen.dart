import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cheptel.dart';
import '../providers/cheptel_provider.dart';
import '../utils/cheptel.dart';
import '../utils/money_format.dart';
import '../widgets/add_button.dart';
import '../widgets/brand_logo.dart';
import '../widgets/empty_state.dart';
import 'cheptel/cheptel_detail_screen.dart';
import 'cheptel/cheptel_dialogs.dart';
import 'cheptel/cheptel_widgets.dart';

/// Cheptel : troupeaux suivis en effectif (chèvres, moutons, poules locales...).
class CheptelScreen extends StatefulWidget {
  const CheptelScreen({super.key});

  @override
  State<CheptelScreen> createState() => _CheptelScreenState();
}

class _CheptelScreenState extends State<CheptelScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CheptelProvider>().charger();
    });
  }

  void _ouvrir(Cheptel c) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => CheptelDetailScreen(cheptel: c)));

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CheptelProvider>();
    final cheptels = provider.cheptels;
    return Scaffold(
      appBar: AppBar(
        leading: const BrandLogo(),
        title: const Text('Cheptel'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: AddButton(tooltip: 'Nouveau troupeau', icon: Icons.pets, onPressed: () => showTroupeauForm(context)),
          ),
        ],
      ),
      body: provider.isLoading && cheptels.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: provider.charger,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
                children: [
                  if (provider.lastError != null && provider.lastError!.isNotEmpty)
                    Card(
                      color: Colors.red.withValues(alpha: 0.12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(provider.lastError!, style: const TextStyle(color: Colors.red)),
                      ),
                    ),
                  if (cheptels.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: EmptyState(
                        icon: Icons.pets_outlined,
                        title: 'Aucun troupeau',
                        subtitle:
                            'Créez un troupeau (chèvres, moutons, poules locales, pintades...) pour suivre son effectif.',
                        actionLabel: 'Créer un troupeau',
                        onAction: () => showTroupeauForm(context),
                      ),
                    )
                  else ...[
                    _Resume(resumeCheptel(cheptels)),
                    const SizedBox(height: 12),
                    for (final c in cheptels) _TroupeauCarte(c, onOpen: () => _ouvrir(c)),
                  ],
                ],
              ),
            ),
    );
  }
}

class _Resume extends StatelessWidget {
  final ResumeCheptel r;
  const _Resume(this.r);

  @override
  Widget build(BuildContext context) {
    final tuiles = [
      (
        'Animaux',
        '${r.animaux}',
        r.troupeaux <= 1 ? '${r.troupeaux} troupeau' : '${r.troupeaux} troupeaux',
        Icons.pets,
        Colors.brown,
      ),
      ('Naissances', '${r.naissances30j}', '30 derniers jours', Icons.child_care, Colors.green),
      (
        'Morts',
        '${r.morts30j}',
        '30 derniers jours',
        Icons.heart_broken_outlined,
        r.morts30j > 0 ? Colors.red : Colors.blueGrey,
      ),
      (
        'Vendus',
        '${r.vendusMois}',
        r.ventesMois > 0 ? formatCompactFcfa(r.ventesMois) : 'ce mois-ci',
        Icons.sell_outlined,
        Colors.blue,
      ),
    ];
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, cs) {
        final col = cs.maxWidth >= 640 ? 4 : 2;
        final w = (cs.maxWidth - (col - 1) * 8) / col;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in tuiles)
              Container(
                width: w,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: t.$5.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: t.$5.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Icon(t.$4, color: t.$5, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.$1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                          ),
                          Text(t.$2, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                          Text(
                            t.$3,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TroupeauCarte extends StatelessWidget {
  final Cheptel c;
  final VoidCallback onOpen;

  const _TroupeauCarte(this.c, {required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final e = especePour(c.espece);
    final k = kpisCheptel(c);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(gradient: LinearGradient(colors: [e.color.shade700, e.color.shade400])),
              child: Row(
                children: [
                  EspeceAvatar(c.espece, surFonce: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.nom,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(e.libelle, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.92))),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${c.effectifActuel}',
                              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                            ),
                            Text('animaux', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                            const SizedBox(height: 2),
                            EvolutionCheptel(k.evolution30j),
                          ],
                        ),
                      ),
                      SizedBox(width: 130, height: 56, child: CourbeEffectif(c, mini: true, couleur: e.color)),
                    ],
                  ),
                  if (k.alertes.isNotEmpty) ...[const SizedBox(height: 8), AlertesCheptelPills(k.alertes)],
                  const SizedBox(height: 10),
                  ActionsRapidesCheptel(c),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
