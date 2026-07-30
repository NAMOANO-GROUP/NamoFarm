import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/international_phone_field.dart';

/// Page d'inscription en libre-service : une nouvelle exploitation crée sa
/// propre entreprise et son premier compte administrateur. Les données seront
/// entièrement cloisonnées (multi-entreprises / SaaS).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _entrepriseCtrl = TextEditingController();
  final _prenomCtrl = TextEditingController();
  final _nomCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telephoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _secretCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _entrepriseCtrl.dispose();
    _prenomCtrl.dispose();
    _nomCtrl.dispose();
    _emailCtrl.dispose();
    _telephoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _secretCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B5D3B), Color(0xFF2E7D32), Color(0xFFE8F5E9)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isMobile ? 460 : 560),
                child: Card(
                  margin: const EdgeInsets.all(24),
                  elevation: 10,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Créer mon exploitation',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Créez votre espace : votre entreprise et votre compte administrateur.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _entrepriseCtrl,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: "Nom de l'exploitation *",
                              prefixIcon: Icon(Icons.business_outlined),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? "Nom de l'exploitation requis" : null,
                            onChanged: (_) => _clearError(),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _prenomCtrl,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: const InputDecoration(labelText: 'Prénom *'),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Prénom requis' : null,
                                  onChanged: (_) => _clearError(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _nomCtrl,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: const InputDecoration(labelText: 'Nom *'),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
                                  onChanged: (_) => _clearError(),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email *',
                              prefixIcon: Icon(Icons.alternate_email),
                            ),
                            validator: (v) {
                              final value = (v ?? '').trim();
                              if (value.isEmpty) return 'Email requis';
                              if (!value.contains('@') || !value.contains('.')) return 'Email invalide';
                              return null;
                            },
                            onChanged: (_) => _clearError(),
                          ),
                          const SizedBox(height: 12),
                          InternationalPhoneField(
                            controller: _telephoneCtrl,
                            labelText: 'Téléphone (optionnel)',
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordCtrl,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Mot de passe *',
                              helperText: 'Au moins 8 caractères',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (v) => (v == null || v.length < 8) ? 'Au moins 8 caractères' : null,
                            onChanged: (_) => _clearError(),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _confirmCtrl,
                            obscureText: _obscureConfirm,
                            decoration: InputDecoration(
                              labelText: 'Confirmer le mot de passe *',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureConfirm ? Icons.visibility : Icons.visibility_off),
                                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                              ),
                            ),
                            validator: (v) => (v != _passwordCtrl.text) ? 'Les mots de passe ne correspondent pas' : null,
                            onChanged: (_) => _clearError(),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _secretCtrl,
                            decoration: const InputDecoration(
                              labelText: "Code d'inscription *",
                              helperText: "Code fourni par l'administrateur",
                              prefixIcon: Icon(Icons.vpn_key_outlined),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? "Code d'inscription requis"
                                : null,
                            onChanged: (_) => _clearError(),
                          ),
                          const SizedBox(height: 12),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(_error!, style: const TextStyle(color: Colors.red)),
                            ),
                          ElevatedButton.icon(
                            onPressed: auth.isLoading ? null : _submit,
                            icon: const Icon(Icons.check_circle_outline),
                            label: auth.isLoading
                                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('Créer mon exploitation'),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: auth.isLoading ? null : () => Navigator.of(context).pop(),
                            child: const Text('J\'ai déjà un compte — Se connecter'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);

    final auth = context.read<AuthProvider>();
    final ok = await auth.onboarding(
      entreprise: _entrepriseCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      motDePasse: _passwordCtrl.text,
      nom: _nomCtrl.text.trim(),
      prenom: _prenomCtrl.text.trim(),
      telephone: _telephoneCtrl.text.trim(),
      secret: _secretCtrl.text.trim(),
    );

    if (!mounted) return;
    if (ok) {
      // L'utilisateur est désormais authentifié : on ferme la page d'onboarding,
      // le portail d'application (_AppGate) affichera l'accueil automatiquement.
      Navigator.of(context).pop();
    } else {
      setState(() => _error = auth.lastError ?? 'Création impossible. Réessaie.');
    }
  }
}
