import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/bandes_provider.dart';
import '../providers/sante_provider.dart';
import '../widgets/add_button.dart';
import '../widgets/brand_logo.dart';
import 'prophylaxie/a_faire_tab.dart';
import 'prophylaxie/protocoles_tab.dart';
import 'prophylaxie/registre_tab.dart';

/// Prophylaxie : planning des interventions, protocoles vaccinaux et registre des traitements.
class SanteScreen extends StatefulWidget {
  const SanteScreen({super.key});

  @override
  State<SanteScreen> createState() => _SanteScreenState();
}

class _SanteScreenState extends State<SanteScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this)..addListener(() => setState(() {}));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SanteProvider>().charger();
      context.read<BandesProvider>().chargerBandesActives();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final protocoles = _tabs.index == 1;
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      appBar: AppBar(
        leading: const BrandLogo(),
        title: const Text('Prophylaxie'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: AddButton(
              tooltip: protocoles ? 'Nouveau protocole' : 'Nouveau traitement',
              icon: protocoles ? Icons.vaccines : Icons.medication,
              onPressed: () => protocoles ? showProtocoleForm(context) : showTraitementForm(context),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelPadding: compact ? const EdgeInsets.symmetric(horizontal: 2) : null,
          tabs: const [
            Tab(icon: Icon(Icons.event_available_outlined, size: 20), text: 'À faire'),
            Tab(icon: Icon(Icons.vaccines_outlined, size: 20), text: 'Protocoles'),
            Tab(icon: Icon(Icons.menu_book_outlined, size: 20), text: 'Registre'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [AFaireTab(), ProtocolesTab(), RegistreTab()],
      ),
    );
  }
}
