import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/client.dart';
import '../../providers/clients_provider.dart';
import '../../utils/crm_labels.dart';
import '../../widgets/form_section.dart';
import '../../widgets/international_phone_field.dart';

/// Création (client == null) ou modification d'un client. Renvoie true si enregistré.
Future<bool> showClientFormDialog(BuildContext context, {Client? client}) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => _ClientFormDialog(client: client),
  );
  return saved == true;
}

class _ClientFormDialog extends StatefulWidget {
  final Client? client;
  const _ClientFormDialog({this.client});

  @override
  State<_ClientFormDialog> createState() => _ClientFormDialogState();
}

class _ClientFormDialogState extends State<_ClientFormDialog> {
  late final TextEditingController _prenom = TextEditingController(text: widget.client?.prenom ?? '');
  late final TextEditingController _nom = TextEditingController(text: widget.client?.nom ?? '');
  late final TextEditingController _telephone = TextEditingController(text: widget.client?.telephone ?? '');
  late final TextEditingController _email = TextEditingController(text: widget.client?.email ?? '');
  late final TextEditingController _adresse = TextEditingController(text: widget.client?.adresse ?? '');
  late final TextEditingController _activite = TextEditingController(text: widget.client?.commentaireActivite ?? '');
  late final TextEditingController _entreprise = TextEditingController(text: widget.client?.entreprise ?? '');
  late String _typeClient = widget.client?.typeClient ?? 'particulier';
  late String _statut = widget.client?.statut ?? 'prospect';
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.client != null;

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
    final provider = context.read<ClientsProvider>();
    final data = {
      'prenom': _prenom.text.trim(),
      'nom': _nom.text.trim(),
      'telephone': _telephone.text.trim(),
      'email': _email.text.trim(),
      'adresse': _adresse.text.trim(),
      'typeClient': _typeClient,
      'commentaireActivite': _activite.text.trim(),
      'entreprise': _entreprise.text.trim(),
      'statut': _statut,
    };
    final ok = _isEdit ? await provider.mettreAJourClient(widget.client!.id!, data) : await provider.ajouterClient(data);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _saving = false;
        _error = 'Enregistrement impossible${(provider.lastError ?? '').isNotEmpty ? ' : ${provider.lastError}' : ''}';
      });
      return;
    }
    await provider.chargerClientsPourCrm();
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Modifier le client' : 'Nouveau client'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FormSection('Identité', icon: Icons.person_outline, padding: EdgeInsets.only(bottom: 4)),
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
              const FormSection('Localisation & activité', icon: Icons.place_outlined),
              TextField(controller: _adresse, decoration: const InputDecoration(labelText: 'Adresse *')),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  for (final t in clientTypes) ButtonSegment(value: t.value, label: Text(t.label), icon: Icon(t.icon)),
                ],
                selected: {_typeClient},
                onSelectionChanged: (v) => setState(() => _typeClient = v.first),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _activite,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Activité / commentaire *'),
              ),
              const SizedBox(height: 8),
              TextField(controller: _entreprise, decoration: const InputDecoration(labelText: 'Entreprise')),
              const FormSection('Statut', icon: Icons.flag_outlined),
              Wrap(
                spacing: 8,
                children: [
                  for (final s in clientStatuts)
                    ChoiceChip(
                      avatar: Icon(s.icon, size: 16, color: s.color),
                      label: Text(s.label),
                      selected: _statut == s.value,
                      onSelected: (_) => setState(() => _statut = s.value),
                    ),
                ],
              ),
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
