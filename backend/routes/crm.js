const express = require('express');
const { getAdminClient } = require('../services/supabase');
const { getCompanyIdForUser } = require('../services/company_scope');
const { requirePermission, requireAdmin } = require('../middleware/auth');
const {
  PIPELINE_STAGES,
  readStatus,
  inferPipelineStage,
  lastActivityDate,
  computeScore,
  normalizeDeal,
  summarizePipeline,
  buildSuggestions,
} = require('../services/crm_insights');
const { normalizeChecklist, writeWithOptionalColumns } = require('../services/task_utils');

const router = express.Router();
const COMMANDES_COMPANY_COLUMNS = ['company_id', 'companyId'];

function csvEscape(value) {
  const raw = value == null ? '' : String(value);
  return `"${raw.replace(/"/g, '""')}"`;
}

function toCsv(rows) {
  return rows.map((row) => row.map(csvEscape).join(',')).join('\n');
}

function authorName(req) {
  const fromBody = (req.body?.auteur || '').toString().trim();
  if (fromBody && fromBody !== 'Utilisateur') return fromBody;
  const u = req.user || {};
  const full = `${u.prenom || ''} ${u.nom || ''}`.trim();
  return full || u.email || fromBody || 'Utilisateur';
}

// Écrit une tâche ; si la colonne checklist n'a pas encore été migrée, réessaie sans elle.
function writeTache(run, payload) {
  return writeWithOptionalColumns(run, payload, ['checklist']);
}

function mapInteraction(row, commande = null) {
  return {
    _id: row.id,
    clientId: row.client_id,
    commandeId: commande
      ? { _id: commande.id, montantTotal: Number(commande.montant_total || 0), statut: commande.statut }
      : row.commande_id,
    type: row.type || 'commentaire',
    sujet: row.sujet || '',
    contenu: row.contenu || '',
    auteur: row.auteur || 'Utilisateur',
    dateInteraction: row.date_interaction,
    piecesJointes: Array.isArray(row.pieces_jointes) ? row.pieces_jointes : [],
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function mapTache(row, client = null, commande = null) {
  return {
    _id: row.id,
    clientId: client
      ? {
          _id: client.id,
          nom: client.nom,
          prenom: client.prenom || '',
          telephone: client.telephone || '',
          statut: client.statut || 'prospect',
        }
      : row.client_id,
    commandeId: commande
      ? {
          _id: commande.id,
          montantTotal: Number(commande.montant_total || 0),
          statut: commande.statut,
        }
      : row.commande_id,
    titre: row.titre || '',
    description: row.description || '',
    type: row.type || 'suivi',
    dateEcheance: row.date_echeance,
    statut: row.statut || 'a_faire',
    priorite: row.priorite || 'moyenne',
    rappelActive: row.rappel_active !== false,
    assigneA: row.assigne_a || '',
    checklist: normalizeChecklist(row.checklist),
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function safeJsonParse(value) {
  if (!value || typeof value !== 'string') return null;
  try {
    return JSON.parse(value);
  } catch (_) {
    return null;
  }
}

async function getCommandesCompat(api, companyId, columns = 'id,client_id,statut,status,montant_total,created_at') {
  let lastError = null;
  for (const companyColumn of COMMANDES_COMPANY_COLUMNS) {
    const result = await api
      .from('commandes')
      .select(columns)
      .eq(companyColumn, companyId);
    if (!result.error) return { data: result.data || [], error: null };

    const message = (result.error.message || '').toString();
    const match = message.match(/Could not find the '([^']+)' column/i);
    const missing = match?.[1] || '';
    if (missing === companyColumn) {
      lastError = result.error;
      continue;
    }
    return { data: [], error: result.error };
  }
  return { data: [], error: lastError };
}

router.get('/dashboard', requirePermission('crm.read'), async (req, res) => {
  try {
    const api = getAdminClient();
    const companyId = await getCompanyIdForUser(api, req.user.id || req.user._id);

    const clientsRes = await api.from('clients').select('*').eq('company_id', companyId);
    if (clientsRes.error) return res.status(500).json({ message: clientsRes.error.message });
    const clients = clientsRes.data || [];

    const commandesRes = await api.from('commandes').select('*').eq('company_id', companyId);
    if (commandesRes.error) return res.status(500).json({ message: commandesRes.error.message });
    const commandes = commandesRes.data || [];

    const tachesRes = await api.from('crm_taches').select('*').eq('company_id', companyId);
    if (tachesRes.error) return res.status(500).json({ message: tachesRes.error.message });
    const taches = tachesRes.data || [];

    const interactionsRes = await api.from('crm_interactions').select('type').eq('company_id', companyId);
    if (interactionsRes.error) return res.status(500).json({ message: interactionsRes.error.message });
    const interactions = interactionsRes.data || [];

    const debutMois = new Date();
    debutMois.setDate(1);
    debutMois.setHours(0, 0, 0, 0);

    const totalClients = clients.length;
    const totalProspects = clients.filter((c) => readStatus(c) === 'prospect').length;
    const clientsActifs = clients.filter((c) => readStatus(c) === 'actif').length;
    const nouveauxClients = clients.filter((c) => new Date(c.created_at).getTime() >= debutMois.getTime()).length;
    const commandesEnAttente = commandes.filter((c) => readStatus(c) === 'en_attente').length;
    const relancesAFaire = taches.filter((t) => ['a_faire', 'en_cours'].includes(t.statut) && new Date(t.date_echeance).getTime() <= Date.now()).length;
    const relancesOuvertes = taches.filter((t) => ['a_faire', 'en_cours'].includes(t.statut)).length;

    const debutMoisPrecedent = new Date(debutMois);
    debutMoisPrecedent.setMonth(debutMoisPrecedent.getMonth() - 1);
    const sumCommandes = (from, to) => commandes
      .filter((c) => readStatus(c) !== 'annulee')
      .filter((c) => {
        const t = new Date(c.created_at).getTime();
        return t >= from.getTime() && t < to.getTime();
      })
      .reduce((s, c) => s + Number(c.montant_total || 0), 0);
    const caMois = sumCommandes(debutMois, new Date(8640000000000000));
    const caMoisPrecedent = sumCommandes(debutMoisPrecedent, debutMois);

    const topClients = [...clients]
      .sort((a, b) => Number(b.chiffre_affaires_cumul || 0) - Number(a.chiffre_affaires_cumul || 0))
      .slice(0, 5)
      .map((c) => ({
        _id: c.id,
        nom: c.nom,
        prenom: c.prenom || '',
        chiffreAffairesCumul: Number(c.chiffre_affaires_cumul ?? c.chiffreAffairesCumul ?? 0),
        statut: readStatus(c) || 'prospect',
      }));

    const byType = new Map();
    for (const i of interactions) {
      const type = i.type || 'autre';
      byType.set(type, (byType.get(type) || 0) + 1);
    }
    const interactionsParType = [...byType.entries()]
      .map(([type, count]) => ({ _id: type, count }))
      .sort((a, b) => b.count - a.count);

    const byMonth = new Map();
    for (const c of commandes) {
      const d = new Date(c.created_at);
      const y = d.getUTCFullYear();
      const m = d.getUTCMonth() + 1;
      const key = `${y}-${m}`;
      byMonth.set(key, (byMonth.get(key) || 0) + Number(c.montant_total || 0));
    }
    const ventesParMois = [...byMonth.entries()]
      .map(([k, total]) => {
        const [annee, mois] = k.split('-').map(Number);
        return { _id: { annee, mois }, total };
      })
      .sort((a, b) => (a._id.annee - b._id.annee) || (a._id.mois - b._id.mois))
      .slice(-12);

    return res.json({
      totalClients,
      totalProspects,
      clientsActifs,
      nouveauxClients,
      commandesEnAttente,
      relancesAFaire,
      relancesOuvertes,
      caMois: Math.round(caMois),
      caMoisPrecedent: Math.round(caMoisPrecedent),
      topClients,
      interactionsParType,
      ventesParMois,
    });
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

router.get('/pipeline', requirePermission('crm.read'), async (req, res) => {
  try {
    const api = getAdminClient();
    const companyId = await getCompanyIdForUser(api, req.user.id || req.user._id);

    const clientsRes = await api.from('clients').select('*').eq('company_id', companyId);
    if (clientsRes.error) return res.status(500).json({ message: clientsRes.error.message });
    const clients = clientsRes.data || [];

    const commandesRes = await getCommandesCompat(api, companyId);
    if (commandesRes.error) return res.status(500).json({ message: commandesRes.error.message });
    const commandes = commandesRes.data || [];

    const interactionsRes = await api
      .from('crm_interactions')
      .select('id,client_id,type,date_interaction,contenu,updated_at')
      .eq('company_id', companyId)
      .order('date_interaction', { ascending: false });
    if (interactionsRes.error) return res.status(500).json({ message: interactionsRes.error.message });
    const interactions = interactionsRes.data || [];

    const commandesByClient = new Map();
    for (const c of commandes) {
      const clientId = c.client_id ? String(c.client_id) : null;
      if (!clientId) continue;
      const list = commandesByClient.get(clientId) || [];
      list.push(c);
      commandesByClient.set(clientId, list);
    }

    const interactionsByClient = new Map();
    const latestPipelineMeta = new Map();
    const lastInteractionByClient = new Map();
    for (const i of interactions) {
      const clientId = i.client_id ? String(i.client_id) : null;
      if (!clientId) continue;
      interactionsByClient.set(clientId, (interactionsByClient.get(clientId) || 0) + 1);
      // Réorganiser le pipeline n'est pas un contact avec le client.
      if (i.type !== 'pipeline_update' && !lastInteractionByClient.has(clientId)) {
        lastInteractionByClient.set(clientId, i.date_interaction);
      }
      if (i.type === 'pipeline_update' && !latestPipelineMeta.has(clientId)) {
        const parsed = safeJsonParse(i.contenu);
        latestPipelineMeta.set(clientId, parsed || {});
      }
    }

    const sourceCount = new Map();
    const now = new Date();

    // La table clients contient aussi les fournisseurs : ils n'ont pas leur place dans le pipeline commercial.
    const pipeline = clients.filter((client) => readStatus(client) !== 'fournisseur').map((client) => {
      const clientId = String(client.id);
      const clientCommandes = commandesByClient.get(clientId) || [];
      const interactionCount = interactionsByClient.get(clientId) || 0;
      const meta = latestPipelineMeta.get(clientId) || {};
      const stage = PIPELINE_STAGES.includes(meta.stage) ? meta.stage : inferPipelineStage(client, clientCommandes);
      const sourceLead = (meta.sourceLead || '').toString().trim() || 'inconnu';
      const lastActivity = lastActivityDate(client, clientCommandes, lastInteractionByClient.get(clientId));
      const score = computeScore({ client, interactionsCount: interactionCount, commandes: clientCommandes, lastActivity, now });
      const deal = normalizeDeal(meta, stage);
      const ca = Number(client.chiffre_affaires_cumul || client.chiffreAffairesCumul || 0);

      sourceCount.set(sourceLead, (sourceCount.get(sourceLead) || 0) + 1);

      return {
        clientId: client.id,
        nom: client.nom || '',
        prenom: client.prenom || '',
        telephone: client.telephone || '',
        entreprise: client.entreprise || '',
        statut: readStatus(client) || 'prospect',
        stage,
        sourceLead,
        score,
        montant: deal.montant,
        probabilite: deal.probabilite,
        dateCloturePrevue: deal.dateCloturePrevue,
        dernierContact: lastActivity ? lastActivity.toISOString() : null,
        interactionsCount: interactionCount,
        commandesCount: clientCommandes.length,
        chiffreAffairesCumul: Number(ca.toFixed(2)),
      };
    });

    const summary = summarizePipeline(pipeline);
    const total = pipeline.length;
    const won = summary.stages.find((s) => s.stage === 'gagne')?.count || 0;
    const conversionRate = total > 0 ? (won / total) * 100 : 0;

    const sources = Array.from(sourceCount.entries())
      .map(([source, count]) => ({ source, count }))
      .sort((a, b) => b.count - a.count);

    return res.json({
      pipeline,
      stages: summary.stages,
      sources,
      conversionRate: Number(conversionRate.toFixed(2)),
      montantOuvert: summary.montantOuvert,
      previsionPonderee: summary.previsionPonderee,
    });
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

router.post('/pipeline/:clientId', requirePermission('crm.interaction.create'), async (req, res) => {
  try {
    const api = getAdminClient();
    const companyId = await getCompanyIdForUser(api, req.user.id || req.user._id);

    const stage = (req.body.stage || '').toString().trim().toLowerCase();
    if (!PIPELINE_STAGES.includes(stage)) {
      return res.status(400).json({ message: 'Etape pipeline invalide' });
    }

    const sourceLead = (req.body.sourceLead || '').toString().trim() || 'inconnu';
    const note = (req.body.note || '').toString().trim();
    const deal = normalizeDeal(req.body, stage);

    const clientRes = await api
      .from('clients')
      .select('id')
      .eq('company_id', companyId)
      .eq('id', req.params.clientId)
      .maybeSingle();
    if (clientRes.error) return res.status(400).json({ message: clientRes.error.message });
    if (!clientRes.data) return res.status(404).json({ message: 'Client non trouvé' });

    const payload = {
      company_id: companyId,
      client_id: req.params.clientId,
      commande_id: null,
      type: 'pipeline_update',
      sujet: `Pipeline: ${stage}`,
      // Le score est désormais calculé automatiquement : il n'est plus stocké.
      contenu: JSON.stringify({
        stage,
        sourceLead,
        note,
        ...deal,
      }),
      auteur: authorName(req),
      date_interaction: new Date().toISOString(),
      pieces_jointes: [],
      updated_at: new Date().toISOString(),
    };

    const saved = await api.from('crm_interactions').insert(payload).select('*').single();
    if (saved.error) return res.status(400).json({ message: saved.error.message });

    return res.status(201).json({
      clientId: req.params.clientId,
      stage,
      sourceLead,
      note,
      ...deal,
      interactionId: saved.data.id,
      updatedAt: saved.data.updated_at,
    });
  } catch (err) {
    return res.status(400).json({ message: err.message });
  }
});

router.get('/clients/:clientId/interactions', requirePermission('crm.read'), async (req, res) => {
  try {
    const api = getAdminClient();
    const companyId = await getCompanyIdForUser(api, req.user.id || req.user._id);

    const interactionsRes = await api
      .from('crm_interactions')
      .select('*')
      .eq('company_id', companyId)
      .eq('client_id', req.params.clientId)
      .order('date_interaction', { ascending: false });

    if (interactionsRes.error) return res.status(500).json({ message: interactionsRes.error.message });

    const commandeIds = [...new Set((interactionsRes.data || []).map((i) => i.commande_id).filter(Boolean))];
    let commandeMap = new Map();
    if (commandeIds.length) {
      const cmd = await api.from('commandes').select('id,montant_total,statut').eq('company_id', companyId).in('id', commandeIds);
      if (!cmd.error) commandeMap = new Map((cmd.data || []).map((c) => [c.id, c]));
    }

    return res.json((interactionsRes.data || []).map((i) => mapInteraction(i, commandeMap.get(i.commande_id))));
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

router.post('/clients/:clientId/interactions', requirePermission('crm.interaction.create'), async (req, res) => {
  try {
    const api = getAdminClient();
    const companyId = await getCompanyIdForUser(api, req.user.id || req.user._id);

    const payload = {
      company_id: companyId,
      client_id: req.params.clientId,
      commande_id: req.body.commandeId || null,
      type: req.body.type,
      sujet: req.body.sujet || '',
      contenu: req.body.contenu,
      auteur: authorName(req),
      date_interaction: req.body.dateInteraction || new Date().toISOString(),
      pieces_jointes: Array.isArray(req.body.piecesJointes) ? req.body.piecesJointes : [],
      updated_at: new Date().toISOString(),
    };

    const saved = await api.from('crm_interactions').insert(payload).select('*').single();
    if (saved.error) return res.status(400).json({ message: saved.error.message });

    const touchClient = await api
      .from('clients')
      .update({ dernier_contact_le: saved.data.date_interaction, updated_at: new Date().toISOString() })
      .eq('company_id', companyId)
      .eq('id', req.params.clientId);
    if (touchClient.error) return res.status(400).json({ message: touchClient.error.message });

    return res.status(201).json(mapInteraction(saved.data));
  } catch (err) {
    return res.status(400).json({ message: err.message });
  }
});

router.get('/taches', requirePermission('crm.tache.read'), async (req, res) => {
  try {
    const api = getAdminClient();
    const companyId = await getCompanyIdForUser(api, req.user.id || req.user._id);

    const tachesRes = await api.from('crm_taches').select('*').eq('company_id', companyId).order('date_echeance', { ascending: true });
    if (tachesRes.error) return res.status(500).json({ message: tachesRes.error.message });

    const clientIds = [...new Set((tachesRes.data || []).map((t) => t.client_id).filter(Boolean))];
    const commandeIds = [...new Set((tachesRes.data || []).map((t) => t.commande_id).filter(Boolean))];

    let clientMap = new Map();
    if (clientIds.length) {
      const clients = await api.from('clients').select('id,nom,prenom,telephone,statut').eq('company_id', companyId).in('id', clientIds);
      if (!clients.error) clientMap = new Map((clients.data || []).map((c) => [c.id, c]));
    }

    let commandeMap = new Map();
    if (commandeIds.length) {
      const commandes = await api.from('commandes').select('id,montant_total,statut').eq('company_id', companyId).in('id', commandeIds);
      if (!commandes.error) commandeMap = new Map((commandes.data || []).map((c) => [c.id, c]));
    }

    return res.json((tachesRes.data || []).map((t) => mapTache(t, clientMap.get(t.client_id), commandeMap.get(t.commande_id))));
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

router.post('/taches', requirePermission('crm.tache.create'), async (req, res) => {
  try {
    const api = getAdminClient();
    const companyId = await getCompanyIdForUser(api, req.user.id || req.user._id);

    const payload = {
      company_id: companyId,
      client_id: req.body.clientId || null,
      commande_id: req.body.commandeId || null,
      titre: req.body.titre,
      description: req.body.description || '',
      type: req.body.type || 'suivi',
      date_echeance: req.body.dateEcheance,
      priorite: req.body.priorite || 'moyenne',
      rappel_active: req.body.rappelActive !== false,
      assigne_a: req.body.assigneA || '',
      statut: req.body.statut || 'a_faire',
      checklist: normalizeChecklist(req.body.checklist),
      updated_at: new Date().toISOString(),
    };

    const saved = await writeTache((p) => api.from('crm_taches').insert(p).select('*').single(), payload);
    if (saved.error) return res.status(400).json({ message: saved.error.message });
    return res.status(201).json(mapTache(saved.data));
  } catch (err) {
    return res.status(400).json({ message: err.message });
  }
});

router.put('/taches/:id', requirePermission('crm.tache.update'), async (req, res) => {
  try {
    const api = getAdminClient();
    const companyId = await getCompanyIdForUser(api, req.user.id || req.user._id);

    const updates = { updated_at: new Date().toISOString() };
    const map = {
      clientId: 'client_id',
      commandeId: 'commande_id',
      titre: 'titre',
      description: 'description',
      type: 'type',
      dateEcheance: 'date_echeance',
      priorite: 'priorite',
      statut: 'statut',
      rappelActive: 'rappel_active',
      assigneA: 'assigne_a',
    };
    for (const [k, dbk] of Object.entries(map)) {
      if (Object.prototype.hasOwnProperty.call(req.body, k)) updates[dbk] = req.body[k];
    }
    if (Object.prototype.hasOwnProperty.call(req.body, 'checklist')) {
      updates.checklist = normalizeChecklist(req.body.checklist);
    }

    const saved = await writeTache((p) => api
      .from('crm_taches')
      .update(p)
      .eq('company_id', companyId)
      .eq('id', req.params.id)
      .select('*')
      .maybeSingle(), updates);

    if (saved.error) return res.status(400).json({ message: saved.error.message });
    if (!saved.data) return res.status(404).json({ message: 'Tâche non trouvée' });
    return res.json(mapTache(saved.data));
  } catch (err) {
    return res.status(400).json({ message: err.message });
  }
});

router.delete('/taches/historique/all', requireAdmin, async (req, res) => {
  try {
    const api = getAdminClient();
    const companyId = await getCompanyIdForUser(api, req.user.id || req.user._id);

    const deleted = await api.from('crm_taches').delete().eq('company_id', companyId).in('statut', ['terminee', 'annulee']);
    if (deleted.error) return res.status(500).json({ message: deleted.error.message });
    return res.json({ message: 'Historique CRM supprimé', deletedCount: 0 });
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

router.get('/taches/historique/export.csv', requirePermission('crm.tache.read'), async (req, res) => {
  try {
    const api = getAdminClient();
    const companyId = await getCompanyIdForUser(api, req.user.id || req.user._id);

    const tachesRes = await api
      .from('crm_taches')
      .select('*')
      .eq('company_id', companyId)
      .in('statut', ['terminee', 'annulee'])
      .order('updated_at', { ascending: false });
    if (tachesRes.error) return res.status(500).json({ message: tachesRes.error.message });

    const clientIds = [...new Set((tachesRes.data || []).map((t) => t.client_id).filter(Boolean))];
    let clientMap = new Map();
    if (clientIds.length) {
      const clients = await api.from('clients').select('id,nom,prenom').eq('company_id', companyId).in('id', clientIds);
      if (!clients.error) clientMap = new Map((clients.data || []).map((c) => [c.id, c]));
    }

    const header = [
      'id', 'titre', 'description', 'type', 'priorite', 'statut', 'date_echeance', 'client', 'assigne_a', 'updated_at',
    ];
    const rows = (tachesRes.data || []).map((t) => {
      const cl = t.client_id ? clientMap.get(t.client_id) : null;
      const clientNom = cl ? `${cl.prenom || ''} ${cl.nom || ''}`.trim() : '';
      return [
        t.id,
        t.titre || '',
        t.description || '',
        t.type || '',
        t.priorite || '',
        t.statut || '',
        t.date_echeance || '',
        clientNom,
        t.assigne_a || '',
        t.updated_at || '',
      ];
    });

    const csv = toCsv([header, ...rows]);
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="crm_taches_historique_${new Date().toISOString().slice(0, 10)}.csv"`);
    return res.status(200).send('\uFEFF' + csv);
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

router.get('/suggestions', requirePermission('crm.tache.read'), async (req, res) => {
  try {
    const api = getAdminClient();
    const companyId = await getCompanyIdForUser(api, req.user.id || req.user._id);

    const [clientsRes, commandesRes, bandesRes, tachesRes, interactionsRes] = await Promise.all([
      api.from('clients').select('*').eq('company_id', companyId),
      getCommandesCompat(api, companyId, '*'),
      api.from('bandes').select('id,nom,statut,type_volaille,date_ouverture,duree_elevage_jours').eq('company_id', companyId),
      api.from('crm_taches').select('client_id,statut').eq('company_id', companyId),
      api.from('crm_interactions').select('client_id,type,date_interaction').eq('company_id', companyId)
        .order('date_interaction', { ascending: false }),
    ]);
    for (const r of [clientsRes, commandesRes, tachesRes, interactionsRes]) {
      if (r.error) return res.status(500).json({ message: r.error.message });
    }

    const lastInteractionByClient = new Map();
    for (const i of interactionsRes.data || []) {
      const id = i.client_id ? String(i.client_id) : null;
      if (id && i.type !== 'pipeline_update' && !lastInteractionByClient.has(id)) {
        lastInteractionByClient.set(id, i.date_interaction);
      }
    }

    const suggestions = buildSuggestions({
      clients: (clientsRes.data || []).filter((c) => readStatus(c) !== 'fournisseur'),
      commandes: commandesRes.data || [],
      // Les bandes sont facultatives : une erreur ne doit pas bloquer les autres suggestions.
      bandes: bandesRes.error ? [] : (bandesRes.data || []),
      taches: tachesRes.data || [],
      lastInteractionByClient,
      now: new Date(),
    });
    return res.json(suggestions);
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

router.delete('/taches/:id', requirePermission('crm.tache.delete'), async (req, res) => {
  try {
    const api = getAdminClient();
    const companyId = await getCompanyIdForUser(api, req.user.id || req.user._id);
    const deleted = await api.from('crm_taches').delete().eq('company_id', companyId).eq('id', req.params.id);
    if (deleted.error) return res.status(500).json({ message: deleted.error.message });
    return res.json({ message: 'Tâche supprimée' });
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

module.exports = router;
