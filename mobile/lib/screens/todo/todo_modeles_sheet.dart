import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/bande.dart';
import '../../providers/alertes_provider.dart';
import '../../utils/crm_labels.dart';
import '../../utils/todo.dart';
import '../../widgets/iso_calendar_picker.dart';
import '../crm/crm_common.dart';
import 'todo_dialog.dart';

/// Liste des modèles de plan ; un modèle ouvre ensuite sa fenêtre de création.
Future<void> showTodoModelesSheet(BuildContext context) async {
  final modele = await showModalBottomSheet<TodoModele>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            const Text('Modèles de plan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Créez en un clic une série de tâches planifiées.',
                style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            for (final m in todoModeles)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Theme.of(ctx).colorScheme.outlineVariant),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  leading: CircleAvatar(child: Icon(m.icon)),
                  title: Text(m.titre, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${m.taches.length} tâches · ${m.description}', maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(ctx, m),
                ),
              ),
          ],
        ),
      ),
    ),
  );
  if (modele != null && context.mounted) await showAppliquerModeleDialog(context, modele);
}

/// Fenêtre de création des tâches d'un modèle, éventuellement pré-remplie (bande, date de départ).
Future<void> showAppliquerModeleDialog(
  BuildContext context,
  TodoModele modele, {
  String? bandeId,
  String bandeNom = '',
  DateTime? depart,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AppliquerModeleDialog(modele: modele, bandeId: bandeId, bandeNom: bandeNom, depart: depart),
  );
}

class _AppliquerModeleDialog extends StatefulWidget {
  final TodoModele modele;
  final String? bandeId;
  final String bandeNom;
  final DateTime? depart;

  const _AppliquerModeleDialog({required this.modele, this.bandeId, this.bandeNom = '', this.depart});

  @override
  State<_AppliquerModeleDialog> createState() => _AppliquerModeleDialogState();
}

class _AppliquerModeleDialogState extends State<_AppliquerModeleDialog> {
  late DateTime _depart = DateUtils.dateOnly(widget.depart ?? DateTime.now());
  late String? _bandeId = widget.bandeId;
  List<Bande> _bandes = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    chargerBandesOuvertes().then((b) {
      if (mounted) setState(() => _bandes = b);
    });
  }

  void _choisirBande(String? id) {
    setState(() {
      _bandeId = id;
      // Pour une bande, J0 = date d'ouverture : le calendrier se cale automatiquement.
      final bande = _bandes.where((b) => b.id == id).firstOrNull;
      if (bande != null && widget.modele.id == 'bande_chair') _depart = DateUtils.dateOnly(bande.dateOuverture);
    });
  }

  Future<void> _creer() async {
    setState(() => _saving = true);
    final provider = context.read<AlertesProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final taches = genererTachesModele(widget.modele, _depart, bandeId: _bandeId, assigneA: currentUserName(context));
    final created = await provider.creerPlusieurs(taches);
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(created == taches.length
          ? '$created tâches créées à partir du modèle'
          : '$created tâche(s) sur ${taches.length} créée(s)'),
    ));
    if (mounted) navigator.pop();
  }

  String _jour(int j) => j == 0 ? 'J0' : (j > 0 ? 'J+$j' : 'J$j');

  @override
  Widget build(BuildContext context) {
    final m = widget.modele;
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(m.titre),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(m.description, style: TextStyle(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _bandeId,
                isExpanded: true,
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Aucune bande')),
                  ..._bandes.map((b) => DropdownMenuItem<String?>(value: b.id, child: Text(b.nom, overflow: TextOverflow.ellipsis))),
                  // Bande fournie mais absente des bandes ouvertes (ex. bande qu'on vient de fermer).
                  if (widget.bandeId != null && !_bandes.any((b) => b.id == widget.bandeId))
                    DropdownMenuItem<String?>(
                      value: widget.bandeId,
                      child: Text(widget.bandeNom.isEmpty ? 'Bande' : widget.bandeNom, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: _choisirBande,
                decoration: const InputDecoration(labelText: 'Bande concernée', prefixIcon: Icon(Icons.egg_outlined)),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(m.libelleDate),
                subtitle: Text(formatDateLongFr(_depart)),
                onTap: () async {
                  final d = await showIsoDatePicker(
                    context: context,
                    initialDate: _depart,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (d != null) setState(() => _depart = DateUtils.dateOnly(d));
                },
              ),
              const Divider(),
              for (final t in m.taches)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 48,
                        child: Text(_jour(t.jour), style: TextStyle(fontWeight: FontWeight.w700, color: scheme.primary)),
                      ),
                      Icon(todoCategorie(t.type).icon, size: 16, color: todoCategorie(t.type).color),
                      const SizedBox(width: 8),
                      Expanded(child: Text(t.titre)),
                      if (t.recurrence != 'aucune') const Icon(Icons.repeat, size: 14),
                      if (t.etapes.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text('${t.etapes.length} étapes', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                      ],
                      const SizedBox(width: 8),
                      Text(formatDateFr(_depart.add(Duration(days: t.jour))),
                          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton.icon(
          onPressed: _saving ? null : _creer,
          icon: const Icon(Icons.playlist_add),
          label: Text(_saving ? 'Création…' : 'Créer ${m.taches.length} tâches'),
        ),
      ],
    );
  }
}
