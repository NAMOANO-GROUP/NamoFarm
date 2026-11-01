# NamoFarm Backend

Ce dossier contiendra le code serveur (backend) de l'application NamoFarm.

Fonctionnalités prévues :
- Gestion des bandes (ouverture, fermeture, historique)
- Gestion des clients (CRM)
- Prise de commandes
- API REST pour communication avec le web et le mobile

Prochaines étapes :
1. Initialiser un projet backend (ex : FastAPI, Django, ou Express.js)
2. Définir les modèles de données (Bandes, Clients, Commandes)
3. Créer les routes API

## CRM

Routes sous `/api/crm` (`routes/crm.js`), logique métier pure dans `services/crm_insights.js` :

- `GET /dashboard` : indicateurs (CA du mois et du mois précédent, relances, meilleurs clients, ventes mensuelles).
- `GET /pipeline` / `POST /pipeline/:clientId` : affaires par étape avec montant, probabilité, date de clôture prévue ;
  le score (0-100) est calculé automatiquement (engagement, commandes, CA, récence du dernier contact).
- `GET /suggestions` : relances proposées automatiquement (sortie de bande prochaine, réachat attendu, client actif sans contact).
- `GET|POST|PUT|DELETE /taches` : tâches avec sous-étapes (`checklist`).

Base existante : exécuter `scripts/sql/add_crm_taches_checklist.sql` dans le SQL Editor Supabase pour activer la checklist
(sans cette migration, les tâches sont enregistrées sans checklist).

## Todo (alertes)

Routes sous `/api/alertes` (`routes/alertes.js`), utilitaires partagés avec le CRM dans `services/task_utils.js`
(checklist, récurrence, écriture tolérante aux colonnes non migrées).

- Champs façon Planner : `assigneA`, `checklist`, `progression` (`a_faire` / `en_cours`).
- `PUT /:id/fait` renvoie `prochaineId` (occurrence suivante d'une tâche périodique) pour permettre l'annulation.
- Les alertes automatiques exposent leur origine (`stockId`, `bandeId`, `crmTacheId`, `clientId`).

Base existante : exécuter `scripts/sql/add_alertes_planner.sql` (sans cette migration, ces trois champs ne sont pas enregistrés).

## Finance

Routes sous `/api/finance` (`routes/finance.js`).

- `GET /budgets` / `PUT /budgets` : budget mensuel par poste de dépense (`{ budgets: { "Alimentation": 500000 } }`,
  0 retire le budget). `GET` renvoie `disponible: false` tant que la table n'existe pas.
- `GET /mouvements` et `/mouvements/export.csv` : `dateFrom` / `dateTo` envoyés avec fuseau (ex. `...Z`) sont pris tels
  quels ; sans fuseau, début / fin de journée côté serveur (`services/finance_dates.js`).

Base existante : exécuter `scripts/sql/add_finance_budgets.sql` pour activer l'onglet Budget.

Tests : `npm test`.
