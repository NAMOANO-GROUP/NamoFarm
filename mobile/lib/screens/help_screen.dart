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
            '• Barre de navigation (en bas sur téléphone, à gauche sur grand écran) : vos 4 modules favoris et « Menu » pour revenir à la grille.\n'
            '• Réorganiser : sur le hub, bouton ⇅ en haut à droite. Glissez les modules dans l\'ordre voulu ; '
            'les 4 premiers vont dans la barre de navigation. L\'ordre est mémorisé sur cet appareil.\n'
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
    _HelpChapter('Tableau de bord', Icons.dashboard_outlined, Color(0xFF0277BD), [
      _HelpArticle(
        'À faire aujourd\'hui',
        'En tête du Tableau de bord : tâches en retard ou du jour, stocks bas, vaccinations, relances '
            'clients, commandes à préparer et bandes qui sortent dans les 7 jours. Les points en retard '
            'passent en premier. Touchez une ligne pour ouvrir le bon module ou la fiche de la bande.',
      ),
      _HelpArticle(
        'Indicateurs clés',
        'Choisissez la période (Ce mois, 3 mois, Cette année, Tout) : argent disponible, ventes, dépenses '
            'et résultat, avec l\'évolution par rapport à la période précédente. Les indicateurs d\'élevage '
            '(sujets, mortalité, IC moyen, alertes) portent sur les bandes en cours.',
      ),
      _HelpArticle(
        'Personnaliser',
        'Menu ⋮ → Personnaliser : glissez les blocs pour changer leur ordre et masquez ceux dont vous '
            'n\'avez pas besoin. Le réglage est mémorisé sur cet appareil. Les rapports PDF et Excel sont '
            'aussi dans ce menu.',
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
        'Liste des bandes',
        'Chaque carte montre l\'avancement du cycle (J23 / 45), l\'effectif et la viabilité, le poids comparé à la '
            'courbe de référence (vert, orange ou rouge), l\'indice de consommation, la prochaine tâche et les '
            'alertes (retard de croissance, mortalité en hausse, saisie du jour manquante). Les quatre boutons ronds '
            'ouvrent directement la saisie de pesée, d\'alimentation, de mortalité ou de climat.',
      ),
      _HelpArticle(
        'Suivi quotidien',
        'Chaque saisie a son écran : pesée, alimentation, mortalité et température/humidité. Elles sont '
            'accessibles depuis la carte de la bande ou le bouton ✎ de sa fiche, et alimentent courbes et indicateurs.',
      ),
      _HelpArticle(
        'Fiche de la bande',
        'Touchez une bande pour ouvrir sa fiche : les indicateurs en tête, puis les onglets Aperçu (tâches de suivi, '
            'saisies, prévisionnel 7 jours), Courbes (réel vs théorique), Journal (saisies jour par jour), Santé, '
            'Tâches (liées à la Todo, avec modèles de plan) et Finances (coûts, ventes, marge).',
      ),
      _HelpArticle(
        'Indicateurs',
        '• Viabilité : part des sujets de départ encore vivants.\n'
            '• Gain moyen / jour : prise de poids quotidienne moyenne depuis l\'arrivée.\n'
            '• Indice de consommation (IC) : kg d\'aliment consommés pour produire 1 kg de poids vif. Plus il est bas, mieux c\'est.\n'
            '• Indice d\'efficacité (IEP) : viabilité % × poids kg ÷ (âge × IC) × 100. Plus il est élevé, plus la bande est performante.\n'
            'La courbe de référence de chaque type de volaille se règle dans Configuration.',
      ),
      _HelpArticle(
        'Comparer les bandes',
        'Onglet Comparer : choisissez les bandes à superposer (courbes de croissance), consultez le classement par '
            'IEP et les performances moyennes par bâtiment.',
      ),
      _HelpArticle(
        'Clôturer une bande',
        'Menu ⋮ de la carte ou de la fiche → « Fermer la bande ». Un bilan s\'affiche et l\'application propose de '
            'planifier le vide sanitaire dans la Todo. La bande passe dans l\'onglet Historique (export CSV possible).',
      ),
    ]),
    _HelpChapter('Couvoir', Icons.egg_alt_outlined, Color(0xFF6A1B9A), [
      _HelpArticle(
        'Mise en incubation',
        'Module Couvoir → bouton « + ». Indiquez le code, la race ou l\'espèce, le nombre d\'œufs et la date. '
            'La durée d\'incubation est déduite de l\'espèce (poule 21 j, pintade 27 j, canard 28 j, caille 17 j, '
            'dinde 28 j, oie 30 j) et la date d\'éclosion prévue est affichée.',
      ),
      _HelpArticle(
        'Suivre les couvées',
        'En tête : œufs en incubation, prochaine éclosion, taux d\'éclosion et poussins sur 12 mois. Chaque carte '
            'montre l\'avancement (J12 / 21), le compte à rebours et la prochaine étape (mirage, arrêt du '
            'retournement). Une couvée non saisie après la date prévue est signalée « Éclosion à saisir ».',
      ),
      _HelpArticle(
        'Fiche couvée',
        'Touchez une carte : entonnoir des œufs aux poussins avec les pertes à chaque étape, taux d\'éclosion '
            'et de viabilité comparés aux objectifs (80 % et 95 %), frise des étapes datées et notes. Saisir '
            'l\'éclosion, clôturer, modifier ou supprimer depuis la fiche.',
      ),
    ]),
    _HelpChapter('Prophylaxie', Icons.vaccines_outlined, Color(0xFFAD1457), [
      _HelpArticle(
        'À faire',
        'Tous les vaccins et traitements prévus sur les bandes en cours, classés En retard, Aujourd\'hui, '
            'Cette semaine et Plus tard, avec le nom de la bande et son âge. Le bouton ✓ marque l\'intervention '
            'comme faite. En haut, les délais d\'attente en cours rappellent les bandes à ne pas vendre.',
      ),
      _HelpArticle(
        'Protocoles vaccinaux',
        'Un protocole est un calendrier de vaccins par âge (J7 Newcastle, J14 Gumboro...). « Partir d\'un modèle » '
            'crée un calendrier courant à adapter avec votre vétérinaire. Il est appliqué automatiquement à la '
            'création d\'une bande, ou à une bande en cours avec « Appliquer à une bande » (seules les étapes à venir '
            'sont planifiées, sans doublon). Menu ⋮ : modifier, dupliquer, supprimer.',
      ),
      _HelpArticle(
        'Registre des traitements',
        'Bouton « + » : notez chaque traitement (type, bande, produit, dose, voie, motif, date). Avec le délai '
            'd\'attente, l\'application affiche la date à partir de laquelle les animaux peuvent être vendus.',
      ),
    ]),
    _HelpChapter('Cheptel', Icons.pets_outlined, Color(0xFFEF6C00), [
      _HelpArticle(
        'Troupeaux',
        'Le Cheptel suit les autres élevages en effectif : chèvres, moutons, poules locales, pintades, lapins, '
            'porcs, bovins. En tête, le résumé (animaux, naissances et morts sur 30 jours, ventes du mois). '
            'Chaque carte montre l\'effectif, son évolution sur 30 jours, une mini-courbe et les alertes '
            '(mortalité en hausse, troupeau à recompter après 90 jours). Bouton « + » pour créer un troupeau.',
      ),
      _HelpArticle(
        'Saisie rapide',
        'Boutons Naissance, Mort, Vente, Achat et Recompter sur chaque carte et dans la fiche. Réglez le nombre '
            'avec − et +, indiquez le prix par tête pour une vente ou un achat (le total va dans la Finance), '
            'choisissez Aujourd\'hui, Hier ou une autre date. L\'effectif après la saisie est affiché.',
      ),
      _HelpArticle(
        'Fiche du troupeau',
        'Touchez une carte : Aperçu (indicateurs, prix moyen par tête, dernier comptage), Courbe de l\'effectif '
            'datée, Journal groupé par mois avec filtres, Finances (ventes, achats, solde).',
      ),
      _HelpArticle(
        'Santé et reproduction',
        'Plan santé : rappels types de l\'espèce (vaccins, déparasitage) à cocher, ajoutés à la Todo. '
            'Mise à la reproduction ou en couvaison : la date de mise-bas ou d\'éclosion est calculée et trois '
            'tâches sont créées (préparation, jour J, contrôle des petits).',
      ),
    ]),
    _HelpChapter('Achats : stocks et fournisseurs', Icons.shopping_basket_outlined, Color(0xFF00838F), [
      _HelpArticle(
        'Ajouter un stock',
        'Module Achats → onglet Stocks → bouton « + ». Renseignez le produit, la catégorie, '
            'la quantité, le coût unitaire, le seuil d\'alerte et le fournisseur.',
      ),
      _HelpArticle(
        'Alertes de stock bas',
        'Quand une quantité passe sous le seuil, une alerte s\'affiche en haut de la liste. '
            'Les entrées de stock (achats) génèrent une sortie de trésorerie ; la '
            'consommation d\'aliment est valorisée dans les coûts, sans mouvement d\'argent.',
      ),
      _HelpArticle(
        'Fiche fournisseur',
        'Module Achats → onglet Fournisseurs → touchez un fournisseur. Appelez-le ou écrivez-lui sur '
            'WhatsApp, consignez vos échanges et retrouvez ses réceptions de stock. Les articles dont le '
            'champ « Fournisseur » contient son entreprise ou son nom y sont listés, avec un bouton '
            '« Commander » qui prépare le message WhatsApp.',
      ),
    ]),
    _HelpChapter('Todo / Tâches', Icons.notifications_outlined, Color(0xFF283593), [
      _HelpArticle(
        'Gérer les tâches',
        'La Todo regroupe vos tâches et celles générées automatiquement (stock bas, santé, planning des bandes, '
            'commandes, relances CRM). Le bouton ✓+ ouvre le formulaire de tâche '
            '(catégorie, priorité, bande, personne assignée, récurrence, checklist).',
      ),
      _HelpArticle(
        'Vues Liste, Tableau, Planning et Graphiques',
        '• Liste : tâches groupées par échéance ; glissez à droite pour terminer, à gauche pour reporter à demain.\n'
            '• Tableau : colonnes par échéance, avancement, catégorie ou bande ; maintenez une carte pour la déplacer.\n'
            '• Planning : la semaine heure par heure.\n'
            '• Graphiques : avancement, catégories, priorités et charge par personne.\n'
            'Le bouton « Filtres » ouvre une liste à choix multiples : cochez une ou plusieurs échéances '
            '(En retard, Aujourd\'hui, Cette semaine, Plus tard) et « Mes tâches » ; en vue Tableau il permet aussi '
            'de choisir les colonnes. Le chiffre sur le bouton indique le nombre de filtres actifs.',
      ),
      _HelpArticle(
        'Terminer, annuler et historique',
        'Touchez le rond d\'une tâche pour la terminer ; « Annuler » apparaît quelques secondes. '
            'Une tâche périodique crée automatiquement sa prochaine occurrence. Les tâches terminées sont '
            'regroupées dans « Terminées » ; menu ⋮ pour exporter l\'historique en CSV ou l\'effacer.',
      ),
      _HelpArticle(
        'Modèles de plan',
        'Bouton « Modèles de plan » en haut : créez en un clic toutes les tâches d\'une nouvelle bande de poulets '
            'de chair (préparation, vaccins, pesées, transitions d\'aliment, vente), d\'un vide sanitaire ou d\'une '
            'routine pondeuses. Le calendrier est indicatif : ajustez-le au protocole de votre vétérinaire.',
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
            'nouveau client à la volée. Quand une commande liée à une bande est déclarée payée, '
            'les animaux vendus (quantité de la commande) sont retirés de l\'effectif de la bande.',
      ),
    ]),
    _HelpChapter('Finance', Icons.account_balance_wallet_outlined, Color(0xFF00695C), [
      _HelpArticle(
        'Accueil : où en est mon argent ?',
        'L\'onglet Accueil montre l\'argent disponible, les entrées et sorties du mois '
            '(avec l\'évolution par rapport au mois dernier), des conseils en phrases simples, '
            'un graphique sur 6 mois et les postes où part l\'argent.',
      ),
      _HelpArticle(
        'Saisir une dépense ou une entrée d\'argent',
        'Boutons Dépense / Entrée d\'argent de l\'accueil. '
            'Tapez le montant, touchez le poste (Aliment, Salaires…), choisissez la bande si besoin, '
            'puis Enregistrer. « Refaire » reprend une dépense récente en un geste. '
            'Les ventes arrivent automatiquement depuis les commandes payées.',
      ),
      _HelpArticle(
        'Mouvements',
        'Le journal est groupé par jour avec les totaux en haut. Cherchez un mot, un nom ou un '
            'montant, et utilisez le menu Filtres (sens, origine, période). Touchez un mouvement '
            'pour le détail ; Modifier et Supprimer sont réservés aux administrateurs.',
      ),
      _HelpArticle(
        'Par bande',
        'Résultat de chaque bande (dépensé, vendu, coût au kg) et prix minimum de vente par '
            'sujet pour ne pas perdre d\'argent. Le bouton « Coût fixe & amortissement » de chaque '
            'bande permet de saisir ces montants par sujet.',
      ),
    ]),
    _HelpChapter('Planification', Icons.event_note_outlined, Color(0xFF00838F), [
      _HelpArticle(
        'Roadmap : lire le planning',
        'Carte Roadmap de Planification. Chaque tâche est une barre sur les mois, avec ses dates et sa durée. Le trait rouge marque aujourd\'hui et '
            'le mois en cours est mis en avant ; la partie foncée d\'une barre indique l\'avancement, une barre '
            'terminée est grisée. La ligne du bas compte les tâches en cours chaque mois (charge).',
      ),
      _HelpArticle(
        'Roadmap : boutons',
        '« + » : ajouter une tâche, une sous-tâche, un jalon ou une date clé. Calendrier : revenir à aujourd\'hui. '
            'Loupe : zoom Mois, Trimestre ou Année. Touchez le titre pour changer de planning ; menu ⋮ pour '
            'créer, renommer ou supprimer un planning.',
      ),
      _HelpArticle(
        'Roadmap : vue calendrier',
        'Le bouton calendrier de la barre bascule vers une vue annuelle : un mois par grille, chaque jour coloré '
            'selon la tâche en cours (bandes de couleur en bas si plusieurs tâches se chevauchent, drapeau pour '
            'un jalon, point rouge pour une date clé). Touchez un jour pour son détail ou pour y ajouter une tâche. '
            'La colonne S donne le numéro de semaine : touchez-le pour le colorer, avec la couleur de votre choix, '
            'et un libellé (fêtes, périodes où l\'on vend mal…). Pour plusieurs semaines, maintenez le doigt sur un '
            'numéro puis touchez les autres (même non consécutives) et « Colorer ». '
            'Les flèches changent d\'année.',
      ),
      _HelpArticle(
        'Roadmap : modifier une tâche',
        'Touchez une barre ou son nom : période, avancement, Modifier, Ajouter un jalon, Supprimer. Touchez un '
            'drapeau pour modifier ou supprimer un jalon. Maintenez le doigt sur le planning pour créer une tâche '
            'à cette date.',
      ),
      _HelpArticle(
        'Scénarii : simuler une production',
        'Carte Scénarii de Planification : indiquez combien de sujets vous voulez vendre (ex. 1 000 poulets) et obtenez le coût '
            'd\'aliment, de poussins, de prophylaxie et des autres charges, le coût par sujet, la marge et le prix '
            'minimum de vente. Les valeurs sont proposées d\'après vos bandes, stocks, ventes et références ; '
            'chaque champ indique sa provenance (Vos données, Référence, Estimation) et reste modifiable.',
      ),
      _HelpArticle(
        'Scénarii : comparer et enregistrer',
        'Le bouton « + » à droite des scénarios en crée un, le menu ⋮ permet de renommer, dupliquer ou revenir aux valeurs proposées. '
            'Les scénarios sont enregistrés sur l\'appareil. Dès qu\'il y en a plusieurs, « Comparer les scénarios » '
            'met leurs marges côte à côte.',
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
            'stocks, tâches, CRM, commandes et finance.',
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
