const express = require('express');
const crypto = require('crypto');
const { getAdminClient } = require('../services/supabase');
const { getCompanyIdForUser } = require('../services/company_scope');
const { requirePermission } = require('../middleware/auth');

const router = express.Router();

const ADD_TYPES = new Set(['naissance', 'entree']);
const SUB_TYPES = new Set(['mortalite', 'vente', 'sortie']);
const ALL_TYPES = new Set(['naissance', 'entree', 'mortalite', 'vente', 'sortie', 'ajustement']);

function isMissingTableError(error) {
  const msg = (error?.message || '').toString().toLowerCase();
  return msg.includes('cheptel')
    && (msg.includes('does not exist') || msg.includes('could not find') || msg.includes('schema cache') || msg.includes('relation'));
}

function readMouvements(row) {
  return Array.isArray(row?.mouvements) ? row.mouvements : [];
}

function sortedByDate(mvts) {
  return [...mvts].sort((a, b) => new Date(a.date || 0).getTime() - new Date(b.date || 0).getTime());
}

function recomputeEffectif(mvts) {
  let e = 0;
  for (const m of sortedByDate(mvts)) {
    const q = Number(m.quantite || 0);
    if (m.type === 'ajustement') e = q;
    else if (ADD_TYPES.has(m.type)) e += q;
    else if (SUB_TYPES.has(m.type)) e -= q;
  }
  return e;
}

function computeStats(mvts) {
  let naissances = 0, entrees = 0, morts = 0, ventes = 0, sorties = 0, caVentes = 0, baseAjustements = 0;
  for (const m of mvts) {
    const q = Number(m.quantite || 0);
    switch (m.type) {
      case 'naissance': naissances += q; break;
      case 'entree': entrees += q; break;
      case 'mortalite': morts += q; break;
      case 'vente': ventes += q; caVentes += Number(m.montant || 0); break;
      case 'sortie': sorties += q; break;
      case 'ajustement': baseAjustements += q; break;
      default: break;
    }
  }
  const effectifActuel = recomputeEffectif(mvts);
  const denom = effectifActuel + morts + ventes + sorties;
  const tauxMortalite = denom > 0 ? Number(((morts / denom) * 100).toFixed(2)) : 0;
  return { naissances, entrees, morts, ventes, sorties, caVentes, baseAjustements, effectifActuel, tauxMortalite };
}

function mapMouvement(m) {
  return {
    _id: m._id,
    date: m.date,
    type: m.type,
    quantite: Number(m.quantite || 0),
    montant: Number(m.montant || 0),
    motif: m.motif || '',
    utilisateur: m.utilisateur || '',
  };
}

function mapCheptelRow(row) {
  const mvts = readMouvements(row);
  const stats = computeStats(mvts);
  return {
    _id: row.id,
    nom: row.nom || '',
    espece: row.espece || '',
    notes: row.notes || '',
    effectifActuel: stats.effectifActuel,
    naissances: stats.naissances,
    entrees: stats.entrees,
    morts: stats.morts,
    ventes: stats.ventes,
    sorties: stats.sorties,
    caVentes: stats.caVentes,
    tauxMortalite: stats.tauxMortalite,
    mouvements: sortedByDate(mvts).reverse().map(mapMouvement),
    createdAt: row.created_at || null,
    updatedAt: row.updated_at || null,
  };
}

function getActorLabel(req) {
  const prenom = (req.user?.prenom || '').toString().trim();
  const nom = (req.user?.nom || '').toString().trim();
  const full = `${prenom} ${nom}`.trim();
  return full || req.user?.email || 'Utilisateur';
}

router.get('/', requirePermission('cheptel.read'), async (req, res) => {
  try {
    const client = getAdminClient();
    const companyId = await getCompanyIdForUser(client, req.user.id || req.user._id);
    const result = await client
      .from('cheptels')
      .select('*')
      .eq('company_id', companyId)
      .order('nom', { ascending: true });
    if (result.error) {
      if (isMissingTableError(result.error)) return res.json([]);
      return res.status(500).json({ message: result.error.message });
    }
    return res.json((result.data || []).map(mapCheptelRow));
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

router.post('/', requirePermission('cheptel.write'), async (req, res) => {
  try {
    const client = getAdminClient();
    const companyId = await getCompanyIdForUser(client, req.user.id || req.user._id);
    const nom = (req.body.nom || '').toString().trim();
    if (!nom) return res.status(400).json({ message: 'Le nom du cheptel est obligatoire' });

    const effectifInitial = Number(req.body.effectifInitial || 0);
    const mouvements = [];
    if (effectifInitial > 0) {
      mouvements.push({
        _id: crypto.randomUUID(),
        date: new Date().toISOString(),
        type: 'ajustement',
        quantite: effectifInitial,
        motif: 'Effectif initial',
        utilisateur: getActorLabel(req),
      });
    }

    const payload = {
      company_id: companyId,
      nom,
      espece: (req.body.espece || '').toString().trim(),
      effectif_actuel: recomputeEffectif(mouvements),
      mouvements,
      notes: (req.body.notes || '').toString(),
      updated_at: new Date().toISOString(),
    };

    const saved = await client.from('cheptels').insert(payload).select('*').single();
    if (saved.error) {
      if (isMissingTableError(saved.error)) {
        return res.status(503).json({ message: "Table 'cheptels' absente. Exécutez la migration SQL add_cheptel_table.sql." });
      }
      return res.status(400).json({ message: saved.error.message });
    }
    return res.status(201).json(mapCheptelRow(saved.data));
  } catch (err) {
    return res.status(400).json({ message: err.message });
  }
});

router.put('/:id', requirePermission('cheptel.write'), async (req, res) => {
  try {
    const client = getAdminClient();
    const companyId = await getCompanyIdForUser(client, req.user.id || req.user._id);
    const updates = { updated_at: new Date().toISOString() };
    if (req.body.nom !== undefined) updates.nom = (req.body.nom || '').toString().trim();
    if (req.body.espece !== undefined) updates.espece = (req.body.espece || '').toString().trim();
    if (req.body.notes !== undefined) updates.notes = (req.body.notes || '').toString();

    const saved = await client
      .from('cheptels')
      .update(updates)
      .eq('company_id', companyId)
      .eq('id', req.params.id)
      .select('*')
      .maybeSingle();
    if (saved.error) return res.status(400).json({ message: saved.error.message });
    if (!saved.data) return res.status(404).json({ message: 'Cheptel non trouvé' });
    return res.json(mapCheptelRow(saved.data));
  } catch (err) {
    return res.status(400).json({ message: err.message });
  }
});

router.delete('/:id', requirePermission('cheptel.delete'), async (req, res) => {
  try {
    const client = getAdminClient();
    const companyId = await getCompanyIdForUser(client, req.user.id || req.user._id);
    const removed = await client
      .from('cheptels')
      .delete()
      .eq('company_id', companyId)
      .eq('id', req.params.id)
      .select('id')
      .maybeSingle();
    if (removed.error) return res.status(500).json({ message: removed.error.message });
    if (!removed.data) return res.status(404).json({ message: 'Cheptel non trouvé' });
    return res.json({ message: 'Cheptel supprimé' });
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

router.post('/:id/mouvements', requirePermission('cheptel.write'), async (req, res) => {
  try {
    const client = getAdminClient();
    const companyId = await getCompanyIdForUser(client, req.user.id || req.user._id);

    const type = (req.body.type || '').toString();
    if (!ALL_TYPES.has(type)) return res.status(400).json({ message: 'Type de mouvement invalide' });
    const quantite = Number(req.body.quantite || 0);
    if (Number.isNaN(quantite) || quantite < 0) return res.status(400).json({ message: 'Quantité invalide' });

    const current = await client
      .from('cheptels')
      .select('*')
      .eq('company_id', companyId)
      .eq('id', req.params.id)
      .maybeSingle();
    if (current.error) return res.status(400).json({ message: current.error.message });
    if (!current.data) return res.status(404).json({ message: 'Cheptel non trouvé' });

    const mouvements = readMouvements(current.data);
    mouvements.push({
      _id: crypto.randomUUID(),
      date: req.body.date || new Date().toISOString(),
      type,
      quantite,
      montant: Number(req.body.montant || 0),
      motif: (req.body.motif || '').toString(),
      utilisateur: getActorLabel(req),
    });

    const effectif = recomputeEffectif(mouvements);
    if (effectif < 0) return res.status(400).json({ message: 'Mouvement invalide: l\'effectif deviendrait négatif' });

    const saved = await client
      .from('cheptels')
      .update({ mouvements, effectif_actuel: effectif, updated_at: new Date().toISOString() })
      .eq('company_id', companyId)
      .eq('id', req.params.id)
      .select('*')
      .maybeSingle();
    if (saved.error) return res.status(400).json({ message: saved.error.message });
    if (!saved.data) return res.status(404).json({ message: 'Cheptel non trouvé' });
    return res.status(201).json(mapCheptelRow(saved.data));
  } catch (err) {
    return res.status(400).json({ message: err.message });
  }
});

router.delete('/:id/mouvements/:mvtId', requirePermission('cheptel.write'), async (req, res) => {
  try {
    const client = getAdminClient();
    const companyId = await getCompanyIdForUser(client, req.user.id || req.user._id);

    const current = await client
      .from('cheptels')
      .select('*')
      .eq('company_id', companyId)
      .eq('id', req.params.id)
      .maybeSingle();
    if (current.error) return res.status(400).json({ message: current.error.message });
    if (!current.data) return res.status(404).json({ message: 'Cheptel non trouvé' });

    const mouvements = readMouvements(current.data).filter((m) => String(m._id) !== String(req.params.mvtId));
    const effectif = recomputeEffectif(mouvements);
    if (effectif < 0) return res.status(400).json({ message: 'Suppression impossible: l\'effectif deviendrait négatif' });

    const saved = await client
      .from('cheptels')
      .update({ mouvements, effectif_actuel: effectif, updated_at: new Date().toISOString() })
      .eq('company_id', companyId)
      .eq('id', req.params.id)
      .select('*')
      .maybeSingle();
    if (saved.error) return res.status(400).json({ message: saved.error.message });
    if (!saved.data) return res.status(404).json({ message: 'Cheptel non trouvé' });
    return res.json(mapCheptelRow(saved.data));
  } catch (err) {
    return res.status(400).json({ message: err.message });
  }
});

module.exports = router;
