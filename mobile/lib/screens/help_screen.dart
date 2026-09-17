import 'package:flutter/material.dart';
import '../config.dart';
import '../widgets/brand_logo.dart';

/// Un article d'aide : titre court + contenu détaillé.
class _HelpArticle {
  final String title;
  final String body;
  const _HelpArticle(this.title, this.body);
}

/// Un chapitre regroupant plusieurs articles.
class _HelpChapter {
  final String title;
  final IconData icon;
  final Color color;
  final List<_HelpArticle> articles;
  const _HelpChapter(this.title, this.icon, this.color, this.articles);
}

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  static const List<_HelpChapter> _chapters = [
    _HelpChapter('Démarrage', Icons.rocket_launch_outlined, Color(0xFF2E7D32), [
      _HelpArticle(
        'Bienvenue sur NamoFarm',
        'NamoFarm vous aide à piloter votre exploitation avicole et votre petit élevage : '
            'suivi des bandes, santé, reproduction, cheptel, stocks, tâches, clients et finances.\n\n'
            'Depuis la page d\'accueil (le hub), touchez une tuile pour ouvrir un module. '
            'Le logo en haut à gauche vous ramène toujours à cette page d\'accueil.',
      ),
      _HelpArticle(
        'Naviguer dans l\'application',
        '• Hub : la grille de modules affichée après connexion.\n'
            '• Barre du bas : accès rapide aux modules, faites-la défiler horizontalement.\n'
            '• Bouton « + » en haut à droite d\'un écran : ajoute un nouvel élément (bande, tâche, stock...).\n'
            '• Les historiques sont repliés par défaut : touchez l\'en-tête pour les déplier.',
      ),
      _HelpArticle(
        'Rôles et permissions',
        'Chaque utilisateur possède un rôle qui détermine les modules accessibles. '
            'Un administrateur peut créer des utilisateurs et gérer la configuration '
            'depuis le module Config.',
      ),
    ]),
    _HelpChapter('Bandes', Icons.egg_outlined, Color(0xFF1565C0), [
      _HelpArticle(
        'Ouvrir une nouvelle bande',
        'Module Bandes → bouton « + » en haut à droite.\n'
            'Renseignez le nom, la date d\'ouverture, l\'effectif initial, la race et le bâtiment. '
            'Vous pouvez associer un protocole vaccinal : les tâches de vaccination seront '
            'générées automatiquement selon l\'âge des sujets.',
      ),
      _HelpArticle(
        'Suivi quotidien',
        'Ouvrez une bande pour saisir chaque jour : prise de poids, alimentation, '
            'mortalité et température/humidité. Ces relevés alimentent les courbes du '
            'tableau de bord de la bande.',
      ),
      _HelpArticle(
        'Tableau de bord de la bande',
        'Accessible depuis l\'icône en haut de l\'écran de suivi. Il affiche la performance '
            '(effectif, mortalité, conso, poids), les courbes réel vs théorique et un '
            'prévisionnel à 7 jours avec alertes.',
      ),
      _HelpArticle(
        'Clôturer une bande',
        'Une bande terminée passe dans l\'onglet Historique, où vous pouvez exporter '
            'les données en CSV.',
      ),
    ]),
    _HelpChapter('Reproduction / Couvoir', Icons.egg_alt_outlined, Color(0xFF6A1B9A), [
      _HelpArticle(
        'Mise en incubation',
        'Module Reproduction → bouton « + » (Mise en incubation). Indiquez la date et '
            'le nombre d\'œufs. La date d\'éclosion prévue est calculée automatiquement.',
      ),
      _HelpArticle(
        'Suivre l\'éclosion',
        'À l\'éclosion, saisissez le nombre de poussins obtenus pour calculer le taux '
            'd\'éclosion. Les couvées terminées passent dans l\'onglet Historique.',
      ),
    ]),
    _HelpChapter('Santé / Prophylaxie', Icons.vaccines_outlined, Color(0xFFAD1457), [
      _HelpArticle(
        'Créer un protocole vaccinal',
        'Onglet Protocoles → bouton « + ». Ajoutez les étapes (jour d\'âge, intervention, '
            'produit, voie, délai d\'attente). Le protocole peut ensuite être appliqué à une '
            'bande pour générer les tâches automatiquement.',
      ),
      _HelpArticle(
        'Enregistrer un traitement',
        'Onglet Registre → bouton « + ». Notez la vaccination ou le traitement réalisé. '
            'Le délai d\'attente avant consommation/vente est suivi automatiquement.',
      ),
    ]),
    _HelpChapter('Cheptel', Icons.pets_outlined, Color(0xFFEF6C00), [
      _HelpArticle(
        'Gérer un cheptel',
        'Le module Cheptel gère les autres élevages (chèvres, poules locales, pintades...). '
            'Bouton « + » pour créer un cheptel, puis enregistrez les mouvements : '
            'naissances, entrées, sorties, décès.',
      ),
      _HelpArticle(
        'Journal des mouvements',
        'Chaque cheptel affiche un journal des mouvements, replié par défaut, avec '
            'l\'effectif recalculé automatiquement.',
      ),
    ]),
    _HelpChapter('Stocks', Icons.inventory_2_outlined, Color(0xFF00838F), [
      _HelpArticle(
        'Ajouter un stock',
        'Module Stocks → bouton « + » en haut. Renseignez le produit, la catégorie, '
            'la quantité, le coût unitaire et le seuil d\'alerte.',
      ),
      _HelpArticle(
        'Alertes de stock bas',
        'Quand une quantité passe sous le seuil, une alerte s\'affiche en haut de la liste. '
            'Les entrées de stock (achats) génèrent une sortie de trésorerie ; la '
            'consommation d\'aliment est valorisée dans les coûts, sans mouvement d\'argent.',
      ),
    ]),
    _HelpChapter('Todo / Tâches', Icons.notifications_outlined, Color(0xFF283593), [
      _HelpArticle(
        'Gérer les tâches',
        'Le module Todo regroupe les tâches manuelles et celles générées automatiquement '
            '(vaccinations, événements prévisionnels). Bouton « + » en haut pour créer une tâche.',
      ),
      _HelpArticle(
        'Filtrer et archiver',
        'Filtrez par date et par période. Une tâche terminée part dans l\'historique, '
            'replié par défaut et exportable en CSV.',
      ),
    ]),
    _HelpChapter('CRM & Commandes', Icons.people_outlined, Color(0xFFC62828), [
      _HelpArticle(
        'Clients et prospects',
        'Onglet Pipeline pour gérer vos clients et prospects. Bouton « + » pour ajouter '
            'un client (particulier ou professionnel).',
      ),
      _HelpArticle(
        'Relances et interactions',
        'Enregistrez vos échanges dans Interactions et planifiez des relances '
            'commerciales dans l\'onglet Relances (bouton « + »).',
      ),
      _HelpArticle(
        'Commandes',
        'L\'onglet Commandes permet de créer une commande, éventuellement avec un '
            'nouveau client à la volée.',
      ),
    ]),
    _HelpChapter('Finance', Icons.account_balance_wallet_outlined, Color(0xFF00695C), [
      _HelpArticle(
        'Trésorerie',
        'Le module Finance suit les entrées et sorties d\'argent. L\'historique des '
            'mouvements est replié par défaut.',
      ),
      _HelpArticle(
        'Comptabilité par bande',
        'La vue Comptabilité calcule la marge par bande : produits des ventes moins les '
            'coûts (poussins, dépenses, aliment consommé).',
      ),
    ]),
    _HelpChapter('Prévisions', Icons.insights_outlined, Color(0xFF558B2F), [
      _HelpArticle(
        'Projections',
        'Le module Prévisions estime le poids, la consommation et la mortalité à venir '
            'à partir des références théoriques et de vos relevés réels.',
      ),
    ]),
    _HelpChapter('Configuration (Admin)', Icons.settings_outlined, Color(0xFF37474F), [
      _HelpArticle(
        'Gérer les utilisateurs',
        'Onglet Utilisateurs → bouton « + » pour créer un utilisateur, réinitialiser un '
            'mot de passe ou activer/désactiver un compte.',
      ),
      _HelpArticle(
        'Paramètres de l\'application',
        'Réglez le nom de l\'application, les références théoriques (poids final, durée '
            'd\'élevage), les notifications et le délai d\'expiration de session.',
      ),
    ]),
    _HelpChapter('FAQ & Astuces', Icons.help_outline, Color(0xFF7B1FA2), [
      _HelpArticle(
        'Le bouton « + » a disparu',
        'Il se trouve désormais en haut à droite de chaque écran (icône seule), plus en bas.',
      ),
      _HelpArticle(
        'Revenir à l\'accueil',
        'Touchez le logo NamoFarm en haut à gauche de n\'importe quel écran.',
      ),
      _HelpArticle(
        'Mode sombre',
        'L\'application s\'adapte automatiquement au thème clair ou sombre de votre appareil.',
      ),
    ]),
    _HelpChapter('À propos', Icons.info_outline, Color(0xFF455A64), [
      _HelpArticle(
        'Version de l\'application',
        'NamoFarm version $kAppVersion (V1.0).\n\n'
            'Première version stable : gestion des bandes, reproduction, santé, cheptel, '
            'stocks, tâches, CRM, commandes, finance et prévisions.',
      ),
      _HelpArticle(
        'Crédits',
        'NamoFarm est développé par NAMOANO GROUP pour accompagner les éleveurs '
            'dans la gestion quotidienne de leur exploitation.',
      ),
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final chapters = q.isEmpty
        ? _chapters
        : _chapters
            .map((c) {
              final matches = c.articles
                  .where((a) => a.title.toLowerCase().contains(q) || a.body.toLowerCase().contains(q))
                  .toList();
              return matches.isEmpty ? null : _HelpChapter(c.title, c.icon, c.color, matches);
            })
            .whereType<_HelpChapter>()
            .toList();

    return Scaffold(
      appBar: AppBar(
        leading: const BrandLogo(),
        title: const Text('Aide & Guide'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Rechercher dans l\'aide...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      ),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: chapters.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Aucun résultat pour cette recherche.', style: TextStyle(color: Colors.grey)),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: chapters.length,
                    itemBuilder: (context, i) => _chapterCard(chapters[i], expanded: q.isNotEmpty),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chapterCard(_HelpChapter chapter, {required bool expanded}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        initiallyExpanded: expanded,
        leading: CircleAvatar(
          backgroundColor: chapter.color.withValues(alpha: isDark ? 0.25 : 0.15),
          child: Icon(chapter.icon, color: isDark ? _lighten(chapter.color) : chapter.color, size: 20),
        ),
        title: Text(chapter.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${chapter.articles.length} article(s)', style: const TextStyle(fontSize: 12)),
        childrenPadding: const EdgeInsets.only(bottom: 4),
        children: chapter.articles
            .map(
              (a) => ListTile(
                dense: true,
                leading: const Icon(Icons.article_outlined, size: 18),
                title: Text(a.title),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => _openArticle(chapter, a),
              ),
            )
            .toList(),
      ),
    );
  }

  void _openArticle(_HelpChapter chapter, _HelpArticle article) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ArticleDetailScreen(chapter: chapter, article: article),
      ),
    );
  }

  Color _lighten(Color c, [double amount = 0.25]) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }
}

class _ArticleDetailScreen extends StatelessWidget {
  final _HelpChapter chapter;
  final _HelpArticle article;

  const _ArticleDetailScreen({required this.chapter, required this.article});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: Text(chapter.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: chapter.color.withValues(alpha: isDark ? 0.25 : 0.15),
                child: Icon(chapter.icon, color: isDark ? _lighten(chapter.color) : chapter.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(article.title, style: Theme.of(context).textTheme.titleLarge),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(article.body, style: const TextStyle(fontSize: 15, height: 1.5)),
        ],
      ),
    );
  }

  Color _lighten(Color c, [double amount = 0.25]) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }
}
