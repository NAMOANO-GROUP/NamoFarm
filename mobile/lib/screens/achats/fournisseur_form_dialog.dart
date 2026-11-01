import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/client.dart';
import '../../providers/fournisseurs_provider.dart';
import '../../utils/crm_labels.dart';
import '../../widgets/form_section.dart';
import '../../widgets/international_phone_field.dart';

/// Création (fournisseur == null) ou modification d'un fournisseur. Renvoie true si enregistré.
Future<bool> showFournisseurFormDialog(BuildContext context, {Client? fournisseur}) async {
  final saved = await showDialog<bool>(context: context, builder: (_) => _FournisseurFormDialog(fournisseur: fournisseur));
  return saved == true;
}

class _FournisseurFormDialog extends StatefulWidget {
  final Client? fournisseur;
  const _FournisseurFormDialog({this.fournisseur});

  @override
  State<_FournisseurFormDialog> createState() => _FournisseurFormDialogState();
}

class _FournisseurFormDialogState extends State<_FournisseurFormDialog> {
  late final TextEditingController _prenom = TextEditingController(text: widget.fournisseur?.prenom ?? '');
  late final TextEditingController _nom = TextEditingController(text: widget.fournisseur?.nom ?? '');
  late final TextEditingController _telephone = TextEditingController(text: widget.fournisseur?.telephone ?? '');
  late final TextEditingController _email = TextEditingController(text: widget.fournisseur?.email ?? '');
  late final TextEditingController _adresse = TextEditingController(text: widget.fournisseur?.adresse ?? '');
  late final TextEditingController _activite = TextEditingController(text: widget.fournisseur?.commentaireActivite ?? '');
  late final TextEditingController _entreprise = TextEditingController(text: widget.fournisseur?.entreprise ?? '');
  late String _type = widget.fournisseur?.typeClient ?? 'pro';
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.fournisseur != null;

  @override
  void dispose() {
    for (final c in [_prenom, _nom, _telephone, _email, _adresse, _activite, _entreprise]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if ([_prenom, _nom, _adresse, _activite].any((c) => c.text.trim().isEmpty)) {
      setState(() => _error = 'Renseignez tous les champs obligatoires (*)');
      return;
    }
    if (!isValidInternationalPhone(_telephone.text.trim())) {
      setState(() => _error = 'Téléphone invalide. Exemple : +221 77 12 34 56');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final provider = context.read<FournisseursProvider>();
    final data = {
      'prenom': _prenom.text.trim(),
      'nom': _nom.text.trim(),
      'telephone': _telephone.text.trim(),
      'email': _email.text.trim(),
      'adresse': _adresse.text.trim(),
      'typeClient': _type,
      'commentaireActivite': _activite.text.trim(),
      'entreprise': _entreprise.text.trim(),
    };
    final ok = _isEdit
        ? await provider.mettreAJourFournisseur(widget.fournisseur!.id!, data)
        : await provider.ajouterFournisseur(data);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = 'Enregistrement impossible, réessayez';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Modifier le fournisseur' : 'Nouveau fournisseur'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FormSection('Société', icon: Icons.storefront_outlined, padding: EdgeInsets.only(bottom: 4)),
              TextField(controller: _entreprise, decoration: const InputDecoration(labelText: 'Entreprise')),
              const SizedBox(height: 8),
              TextField(
                controller: _activite,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Produits / activité *', hintText: 'Aliment, poussins, vaccins...'),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  for (final t in clientTypes) ButtonSegment(value: t.value, label: Text(t.label), icon: Icon(t.icon)),
                ],
                selected: {_type},
                onSelectionChanged: (v) => setState(() => _type = v.first),
              ),
              const FormSection('Contact', icon: Icons.person_outline),
              TextField(controller: _prenom, decoration: const InputDecoration(labelText: 'Prénom *')),
              const SizedBox(height: 8),
              TextField(controller: _nom, decoration: const InputDecoration(labelText: 'Nom *')),
              const SizedBox(height: 8),
              InternationalPhoneField(controller: _telephone, labelText: 'Téléphone *'),
              const SizedBox(height: 8),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 8),
              TextField(controller: _adresse, decoration: const InputDecoration(labelText: 'Adresse *')),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Annuler')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Enregistrement…' : (_isEdit ? 'Enregistrer' : 'Créer')),
        ),
      ],
    );
  }
}
