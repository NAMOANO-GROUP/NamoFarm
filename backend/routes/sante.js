const express = require('express');
const { getAdminClient } = require('../services/supabase');
const { getCompanyIdForUser } = require('../services/company_scope');
const { requirePermission } = require('../middleware/auth');

const router = express.Router();

function isMissingTableError(error, table) {
  const msg = (error?.message || '').toString().toLowerCase();
  return msg.includes(table)
    && (msg.includes('does not exist') || msg.includes('could not find') || msg.includes('schema cache') || msg.includes('relation'));
}

function toArray(value) {
  return Array.isArray(value) ? value : [];
}

function getActorLabel(req) {
  const prenom = (req.user?.prenom || '').toString().trim();
  const nom = (req.user?.nom || '').toString().trim();
  const full = `${prenom} ${nom}`.trim();
  return full || req.user?.email || 'Utilisateur';
}

// ---------------------------------------------------------------------------
// Protocoles vaccinaux (reusable vaccination calendar templates)
// ---------------------------------------------------------------------------

function mapProtocole(row) {
  return {
    _id: row.id,
    nom: row.nom || '',
    typeVolaille: row.type_volaille || '',
    etapes: toArray(row.etapes).map((e) => ({
      jourAge: Number(e.jourAge || 0),
      intervention: (e.intervention || '').toString(),
      produit: (e.produit || '').toString(),
      dose: (e.dose || '').toString(),
      voie: (e.voie || '').toString(),
      delaiAttenteJours: Number(e.delaiAttenteJours || 0),
      notes: (e.notes || '').toString(),
    })),
    notes: row.notes || '',
    createdAt: row.created_at || null,
    updatedAt: row.updated_at || null,
  };
}

router.get('/protocoles', requirePermission('sante.read'), async (req, res) => {
  try {
    const client = getAdminClient();
    const companyId = await getCompanyIdForUser(client, req.user.id || req.user._id);
    const result = await client
      .from('protocoles_vaccinaux')
      .select('*')
      .eq('company_id', companyId)
      .order('type_volaille', { ascending: true })
      .order('nom', { ascending: true });
    if (result.error) {
      if (isMissingTableError(result.error, 'protocoles_vaccinaux')) return res.json([]);
      return res.status(500).json({ message: result.error.message });
    }
    return res.json((result.data || []).map(mapProtocole));
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

router.post('/protocoles', requirePermission('sante.write'), async (req, res) => {
  try {
    const client = getAdminClient();
    const companyId = await getCompanyIdForUser(client, req.user.id || req.user._id);
    const nom = (req.body.nom || '').toString().trim();
    if (!nom) return res.status(400).json({ message: 'Le nom du protocole est obligatoire' });

    const payload = {
      company_id: companyId,
      nom,
      type_volaille: (req.body.typeVolaille || '').toString().trim(),
      etapes: toArray(req.body.etapes),
      notes: (req.body.notes || '').toString(),
      updated_at: new Date().toISOString(),
    };

    const saved = await client.from('protocoles_vaccinaux').insert(payload).select('*').single();
    if (saved.error) {
      if (isMissingTableError(saved.error, 'protocoles_vaccinaux')) {
        return res.status(503).json({ message: "Table 'protocoles_vaccinaux' absente. Exécutez add_sante_tables.sql." });
      }
      return res.status(400).json({ message: saved.error.message });
    }
    return res.status(201).json(mapProtocole(saved.data));
  } catch (err) {
    return res.status(400).json({ message: err.message });
  }
});

router.put('/protocoles/:id', requirePermission('sante.write'), async (req, res) => {
  try {
    const client = getAdminClient();
    const companyId = await getCompanyIdForUser(client, req.user.id || req.user._id);
    const updates = { updated_at: new Date().toISOString() };
    if (req.body.nom !== undefined) updates.nom = (req.body.nom || '').toString().trim();
    if (req.body.typeVolaille !== undefined) updates.type_volaille = (req.body.typeVolaille || '').toString().trim();
    if (req.body.etapes !== undefined) updates.etapes = toArray(req.body.etapes);
    if (req.body.notes !== undefined) updates.notes = (req.body.notes || '').toString();

    const saved = await client
      .from('protocoles_vaccinaux')
      .update(updates)
      .eq('company_id', companyId)
      .eq('id', req.params.id)
      .select('*')
      .maybeSingle();
    if (saved.error) return res.status(400).json({ message: saved.error.message });
    if (!saved.data) return res.status(404).json({ message: 'Protocole non trouvé' });
    return res.json(mapProtocole(saved.data));
  } catch (err) {
    return res.status(400).json({ message: err.message });
  }
});

router.delete('/protocoles/:id', requirePermission('sante.delete'), async (req, res) => {
  try {
    const client = getAdminClient();
    const companyId = await getCompanyIdForUser(client, req.user.id || req.user._id);
    const removed = await client
      .from('protocoles_vaccinaux')
      .delete()
      .eq('company_id', companyId)
      .eq('id', req.params.id)
      .select('id')
      .maybeSingle();
    if (removed.error) return res.status(500).json({ message: removed.error.message });
    if (!removed.data) return res.status(404).json({ message: 'Protocole non trouvé' });
    return res.json({ message: 'Protocole supprimé' });
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

// ---------------------------------------------------------------------------
// Registre des traitements sanitaires (with withdrawal-period tracking)
// ---------------------------------------------------------------------------

function mapTraitement(row) {
  const date = row.date_traitement ? new Date(row.date_traitement) : null;
  const delai = Number(row.delai_attente_jours || 0);
  let dateFinDelai = null;
  let statutDelai = 'aucun';
  if (date && delai > 0) {
    const fin = new Date(date.getTime());
    fin.setDate(fin.getDate() + delai);
    dateFinDelai = fin.toISOString();
    statutDelai = Date.now() < fin.getTime() ? 'en_cours' : 'termine';
  } else if (date) {
    statutDelai = 'termine';
  }

  return {
    _id: row.id,
    bandeId: row.bande_id || null,
    dateTraitement: row.date_traitement || null,
    type: row.type || 'traitement',
    produit: row.produit || '',
    dose: row.dose || '',
    voie: row.voie || '',
    motif: row.motif || '',
    delaiAttenteJours: delai,
    dateFinDelaiAttente: dateFinDelai,
    statutDelai, // 'aucun' | 'en_cours' | 'termine'
    utilisateur: row.utilisateur || '',
    notes: row.notes || '',
    createdAt: row.created_at || null,
    updatedAt: row.updated_at || null,
  };
}

router.get('/traitements', requirePermission('sante.read'), async (req, res) => {
  try {
    const client = getAdminClient();
    const companyId = await getCompanyIdForUser(client, req.user.id || req.user._id);
    let query = client
      .from('traitements_sanitaires')
      .select('*')
      .eq('company_id', companyId)
      .order('date_traitement', { ascending: false });

    const bandeId = (req.query.bandeId || '').toString().trim();
    if (bandeId) query = query.eq('bande_id', bandeId);

    const result = await query;
    if (result.error) {
      if (isMissingTableError(result.error, 'traitements_sanitaires')) return res.json([]);
      return res.status(500).json({ message: result.error.message });
    }
    return res.json((result.data || []).map(mapTraitement));
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

router.post('/traitements', requirePermission('sante.write'), async (req, res) => {
  try {
    const client = getAdminClient();
    const companyId = await getCompanyIdForUser(client, req.user.id || req.user._id);
    const produit = (req.body.produit || '').toString().trim();
    if (!produit) return res.status(400).json({ message: 'Le produit est obligatoire' });

    const payload = {
      company_id: companyId,
      bande_id: req.body.bandeId || null,
      date_traitement: req.body.dateTraitement || new Date().toISOString(),
      type: (req.body.type || 'traitement').toString(),
      produit,
      dose: (req.body.dose || '').toString(),
      voie: (req.body.voie || '').toString(),
      motif: (req.body.motif || '').toString(),
      delai_attente_jours: Number(req.body.delaiAttenteJours || 0),
      utilisateur: getActorLabel(req),
      notes: (req.body.notes || '').toString(),
      updated_at: new Date().toISOString(),
    };

    const saved = await client.from('traitements_sanitaires').insert(payload).select('*').single();
    if (saved.error) {
      if (isMissingTableError(saved.error, 'traitements_sanitaires')) {
        return res.status(503).json({ message: "Table 'traitements_sanitaires' absente. Exécutez add_sante_tables.sql." });
      }
      return res.status(400).json({ message: saved.error.message });
    }
    return res.status(201).json(mapTraitement(saved.data));
  } catch (err) {
    return res.status(400).json({ message: err.message });
  }
});

router.put('/traitements/:id', requirePermission('sante.write'), async (req, res) => {
  try {
    const client = getAdminClient();
    const companyId = await getCompanyIdForUser(client, req.user.id || req.user._id);
    const updates = { updated_at: new Date().toISOString() };
    if (req.body.bandeId !== undefined) updates.bande_id = req.body.bandeId || null;
    if (req.body.dateTraitement !== undefined) updates.date_traitement = req.body.dateTraitement;
    if (req.body.type !== undefined) updates.type = (req.body.type || 'traitement').toString();
    if (req.body.produit !== undefined) updates.produit = (req.body.produit || '').toString().trim();
    if (req.body.dose !== undefined) updates.dose = (req.body.dose || '').toString();
    if (req.body.voie !== undefined) updates.voie = (req.body.voie || '').toString();
    if (req.body.motif !== undefined) updates.motif = (req.body.motif || '').toString();
    if (req.body.delaiAttenteJours !== undefined) updates.delai_attente_jours = Number(req.body.delaiAttenteJours || 0);
    if (req.body.notes !== undefined) updates.notes = (req.body.notes || '').toString();

    const saved = await client
      .from('traitements_sanitaires')
      .update(updates)
      .eq('company_id', companyId)
      .eq('id', req.params.id)
      .select('*')
      .maybeSingle();
    if (saved.error) return res.status(400).json({ message: saved.error.message });
    if (!saved.data) return res.status(404).json({ message: 'Traitement non trouvé' });
    return res.json(mapTraitement(saved.data));
  } catch (err) {
    return res.status(400).json({ message: err.message });
  }
});

router.delete('/traitements/:id', requirePermission('sante.delete'), async (req, res) => {
  try {
    const client = getAdminClient();
    const companyId = await getCompanyIdForUser(client, req.user.id || req.user._id);
    const removed = await client
      .from('traitements_sanitaires')
      .delete()
      .eq('company_id', companyId)
      .eq('id', req.params.id)
      .select('id')
      .maybeSingle();
    if (removed.error) return res.status(500).json({ message: removed.error.message });
    if (!removed.data) return res.status(404).json({ message: 'Traitement non trouvé' });
    return res.json({ message: 'Traitement supprimé' });
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

module.exports = router;
