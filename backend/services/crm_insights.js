// Logique métier CRM pure (sans accès base) : étapes du pipeline, score automatique,
// affaires et suggestions de relance. Testée par backend/tests/crm_insights.test.js.

const PIPELINE_STAGES = ['lead', 'qualifie', 'proposition', 'negociation', 'gagne', 'perdu'];

const DEFAULT_PROBABILITY = {
  lead: 10,
  qualifie: 25,
  proposition: 50,
  negociation: 75,
  gagne: 100,
  perdu: 0,
};

const DAY_MS = 24 * 60 * 60 * 1000;
const OPEN_TASK_STATUSES = ['a_faire', 'en_cours'];

function readStatus(row) {
  return (row?.statut || row?.status || '').toString();
}

function toDate(value) {
  if (!value) return null;
  const d = value instanceof Date ? value : new Date(value);
  return Number.isNaN(d.getTime()) ? null : d;
}

function daysBetween(from, to) {
  return Math.round((to.getTime() - from.getTime()) / DAY_MS);
}

function clientName(client) {
  return `${client?.prenom || ''} ${client?.nom || ''}`.trim() || 'Client';
}

function isCancelled(commande) {
  return readStatus(commande).toLowerCase() === 'annulee';
}

function inferPipelineStage(client, commandes = []) {
  const status = readStatus(client).toLowerCase();
  if (commandes.some((c) => readStatus(c).toLowerCase() === 'payee')) return 'gagne';
  if (commandes.some((c) => readStatus(c).toLowerCase() === 'annulee')) return 'perdu';
  if (commandes.some((c) => ['en_attente', 'confirmee', 'en_preparation'].includes(readStatus(c).toLowerCase()))) {
    return 'negociation';
  }
  if (status === 'actif') return 'qualifie';
  if (status === 'inactif') return 'perdu';
  return 'lead';
}

/** Date du dernier contact connu : interaction, commande ou champ client. */
function lastActivityDate(client, commandes = [], lastInteractionDate = null) {
  const candidates = [
    toDate(client?.dernier_contact_le || client?.dernierContactLe),
    toDate(lastInteractionDate),
    ...commandes.map((c) => toDate(c.created_at || c.createdAt)),
  ].filter(Boolean);
  if (!candidates.length) return null;
  return new Date(Math.max(...candidates.map((d) => d.getTime())));
}

/**
 * Score 0-100 calculé automatiquement (façon HubSpot) :
 * engagement (interactions) + fidélité (commandes) + valeur (CA) + récence du dernier contact.
 */
function computeScore({ client, interactionsCount = 0, commandes = [], lastActivity = null, now = new Date() }) {
  const validCommandes = commandes.filter((c) => !isCancelled(c));
  const ca = Number(client?.chiffre_affaires_cumul ?? client?.chiffreAffairesCumul ?? 0) || 0;

  const engagement = Math.min(20, interactionsCount * 2);
  const fidelite = Math.min(30, validCommandes.length * 6);
  const valeur = Math.min(25, Math.floor(ca / 40000));

  let recence = 0;
  const last = toDate(lastActivity);
  if (last) {
    const days = daysBetween(last, now);
    if (days <= 7) recence = 25;
    else if (days <= 30) recence = 15;
    else if (days <= 90) recence = 5;
  }

  return Math.max(0, Math.min(100, engagement + fidelite + valeur + recence));
}

/** Normalise les infos d'affaire stockées dans la dernière mise à jour pipeline. */
function normalizeDeal(meta = {}, stage = 'lead') {
  const montant = Number(meta.montant);
  const probabilite = Number(meta.probabilite);
  const cloture = toDate(meta.dateCloturePrevue);
  return {
    montant: Number.isFinite(montant) && montant > 0 ? montant : 0,
    probabilite: Number.isFinite(probabilite)
      ? Math.max(0, Math.min(100, probabilite))
      : (DEFAULT_PROBABILITY[stage] ?? 0),
    dateCloturePrevue: cloture ? cloture.toISOString() : null,
  };
}

/** Totaux par étape (nombre, montant) et prévision pondérée hors affaires perdues. */
function summarizePipeline(items = []) {
  const byStage = new Map(PIPELINE_STAGES.map((s) => [s, { stage: s, count: 0, montant: 0 }]));
  let previsionPonderee = 0;
  let montantOuvert = 0;
  for (const item of items) {
    const entry = byStage.get(item.stage);
    if (!entry) continue;
    entry.count += 1;
    entry.montant += Number(item.montant) || 0;
    if (item.stage !== 'perdu' && item.stage !== 'gagne') {
      montantOuvert += Number(item.montant) || 0;
      previsionPonderee += ((Number(item.montant) || 0) * (Number(item.probabilite) || 0)) / 100;
    }
  }
  return {
    stages: [...byStage.values()],
    montantOuvert: Math.round(montantOuvert),
    previsionPonderee: Math.round(previsionPonderee),
  };
}

function groupByClient(rows = []) {
  const map = new Map();
  for (const row of rows) {
    const id = row.client_id ? String(row.client_id) : null;
    if (!id) continue;
    const list = map.get(id) || [];
    list.push(row);
    map.set(id, list);
  }
  return map;
}

function clientsWithOpenTask(taches = []) {
  return new Set(
    taches
      .filter((t) => OPEN_TASK_STATUSES.includes(t.statut) && t.client_id)
      .map((t) => String(t.client_id)),
  );
}

function suggestion(kind, client, fields) {
  return {
    id: `${kind}-${client.id}${fields.idSuffix ? `-${fields.idSuffix}` : ''}`,
    kind,
    clientId: client.id,
    clientNom: clientName(client),
    telephone: client.telephone || '',
    titre: fields.titre,
    description: fields.description,
    raison: fields.raison,
    type: fields.type || 'relance',
    priorite: fields.priorite || 'moyenne',
    dateEcheance: fields.dateEcheance.toISOString(),
  };
}

/** Clients qui recommandent à intervalle régulier et dont le prochain achat approche. */
function reorderSuggestions({ clients = [], commandes = [], excludedClientIds = new Set(), now = new Date() }) {
  const byClient = groupByClient(commandes.filter((c) => !isCancelled(c)));
  const out = [];
  for (const client of clients) {
    const id = String(client.id);
    if (excludedClientIds.has(id) || readStatus(client) === 'fournisseur') continue;
    const dates = (byClient.get(id) || [])
      .map((c) => toDate(c.created_at || c.createdAt))
      .filter(Boolean)
      .sort((a, b) => a - b);
    if (dates.length < 2) continue;

    const intervals = [];
    for (let i = 1; i < dates.length; i += 1) intervals.push(daysBetween(dates[i - 1], dates[i]));
    const avg = Math.round(intervals.reduce((s, v) => s + v, 0) / intervals.length);
    if (avg < 3) continue;

    const last = dates[dates.length - 1];
    const next = new Date(last.getTime() + avg * DAY_MS);
    const daysUntil = daysBetween(now, next);
    if (daysUntil > 7 || daysUntil < -60) continue;

    out.push(suggestion('reachat', client, {
      titre: `Proposer un réachat à ${clientName(client)}`,
      description: `Commande en moyenne tous les ${avg} jours. Dernière commande le ${last.toISOString().slice(0, 10)}.`,
      raison: daysUntil < 0
        ? `Réachat attendu depuis ${-daysUntil} j`
        : (daysUntil === 0 ? "Réachat attendu aujourd'hui" : `Réachat attendu dans ${daysUntil} j`),
      type: 'appel',
      priorite: daysUntil < 0 ? 'haute' : 'moyenne',
      dateEcheance: daysUntil < 0 ? now : next,
    }));
  }
  return out;
}

/** Bandes qui sortent bientôt : prévenir les clients qui ont déjà acheté ce type de volaille. */
function bandeExitSuggestions({
  bandes = [],
  clients = [],
  commandes = [],
  excludedClientIds = new Set(),
  now = new Date(),
  horizonDays = 14,
  maxClientsPerBande = 5,
  dureesParType = {},
}) {
  const bandeById = new Map(bandes.map((b) => [String(b.id), b]));
  const clientById = new Map(clients.map((c) => [String(c.id), c]));
  const out = [];

  for (const bande of bandes) {
    if (readStatus(bande) !== 'ouverte') continue;
    const ouverture = toDate(bande.date_ouverture);
    if (!ouverture) continue;
    // Durée du type de volaille (Config → Paramètres), sinon celle enregistrée sur la bande.
    const duree = Number(dureesParType[bande.type_volaille]) || Number(bande.duree_elevage_jours) || 45;
    const sortie = new Date(ouverture.getTime() + duree * DAY_MS);
    const daysUntil = daysBetween(now, sortie);
    if (daysUntil < 0 || daysUntil > horizonDays) continue;

    const type = bande.type_volaille || '';
    const buyers = new Map();
    for (const c of commandes) {
      if (isCancelled(c) || !c.client_id) continue;
      const sourceType = bandeById.get(String(c.bande_id))?.type_volaille
        || c.bande_snapshot?.typeVolaille
        || c.bande_snapshot?.type_volaille;
      if (sourceType !== type) continue;
      const id = String(c.client_id);
      buyers.set(id, (buyers.get(id) || 0) + (Number(c.montant_total) || 0));
    }

    const targets = [...buyers.entries()]
      .filter(([id]) => clientById.has(id) && !excludedClientIds.has(id))
      .sort((a, b) => b[1] - a[1])
      .slice(0, maxClientsPerBande)
      .map(([id]) => clientById.get(id));

    for (const client of targets) {
      out.push(suggestion('sortie_bande', client, {
        idSuffix: bande.id,
        titre: `Annoncer la sortie de ${bande.nom} à ${clientName(client)}`,
        description: `La bande ${bande.nom} sort vers le ${sortie.toISOString().slice(0, 10)}. Ce client a déjà acheté ce type de volaille.`,
        raison: daysUntil === 0 ? "Sortie de bande aujourd'hui" : `Sortie de bande dans ${daysUntil} j`,
        type: 'appel',
        priorite: daysUntil <= 7 ? 'haute' : 'moyenne',
        dateEcheance: new Date(Math.max(now.getTime(), sortie.getTime() - 7 * DAY_MS)),
      }));
    }
  }
  return out;
}

/** Clients actifs sans aucun contact depuis longtemps. */
function dormantSuggestions({
  clients = [],
  commandes = [],
  lastInteractionByClient = new Map(),
  excludedClientIds = new Set(),
  now = new Date(),
  thresholdDays = 30,
  limit = 10,
}) {
  const byClient = groupByClient(commandes);
  return clients
    .filter((c) => readStatus(c) === 'actif' && !excludedClientIds.has(String(c.id)))
    .map((c) => {
      const last = lastActivityDate(c, byClient.get(String(c.id)) || [], lastInteractionByClient.get(String(c.id)));
      return { client: c, last, days: last ? daysBetween(last, now) : null };
    })
    .filter((x) => x.days === null || x.days >= thresholdDays)
    .sort((a, b) => Number(b.client.chiffre_affaires_cumul || 0) - Number(a.client.chiffre_affaires_cumul || 0))
    .slice(0, limit)
    .map(({ client, days }) => suggestion('sans_contact', client, {
      titre: `Reprendre contact avec ${clientName(client)}`,
      description: 'Client actif sans échange récent : prendre des nouvelles et présenter les disponibilités.',
      raison: days === null ? 'Aucun contact enregistré' : `Sans contact depuis ${days} j`,
      type: 'appel',
      priorite: days === null || days >= 60 ? 'haute' : 'moyenne',
      dateEcheance: now,
    }));
}

/** Combine toutes les suggestions, un client n'apparaissant qu'une fois par type. */
function buildSuggestions({ clients = [], commandes = [], bandes = [], taches = [], lastInteractionByClient = new Map(), now = new Date(), limit = 20, dureesParType = {} }) {
  const excludedClientIds = clientsWithOpenTask(taches);
  const all = [
    ...bandeExitSuggestions({ bandes, clients, commandes, excludedClientIds, now, dureesParType }),
    ...reorderSuggestions({ clients, commandes, excludedClientIds, now }),
    ...dormantSuggestions({ clients, commandes, lastInteractionByClient, excludedClientIds, now }),
  ];
  const priorityRank = { urgente: 0, haute: 1, moyenne: 2, basse: 3 };
  const seen = new Set();
  return all
    .filter((s) => (seen.has(s.id) ? false : seen.add(s.id)))
    .sort((a, b) => (priorityRank[a.priorite] - priorityRank[b.priorite]) || a.dateEcheance.localeCompare(b.dateEcheance))
    .slice(0, limit);
}

module.exports = {
  PIPELINE_STAGES,
  DEFAULT_PROBABILITY,
  readStatus,
  inferPipelineStage,
  lastActivityDate,
  computeScore,
  normalizeDeal,
  summarizePipeline,
  reorderSuggestions,
  bandeExitSuggestions,
  dormantSuggestions,
  buildSuggestions,
};
