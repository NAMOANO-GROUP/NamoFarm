const express = require('express');
const { getAdminClient } = require('../services/supabase');
const { getCompanyIdForUser } = require('../services/company_scope');
const { requirePermission } = require('../middleware/auth');

const router = express.Router();

const ALLOWED_STATUTS = new Set(['en_incubation', 'mire', 'eclos', 'termine', 'annule']);

function isMissingTableError(error) {
  const msg = (error?.message || '').toString().toLowerCase();
  return msg.includes('couvees')
    && (msg.includes('does not exist') || msg.includes('could not find') || msg.includes('schema cache') || msg.includes('relation'));
}

function num(value) {
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

function pct(numerator, denominator) {
  if (!denominator || denominator <= 0 || numerator == null) return null;
  return Number(((numerator / denominator) * 100).toFixed(2));
}

function mapCouveeRow(row) {
  const incubes = Number(row.nb_oeufs_incubes || 0);
  const fertiles = row.nb_oeufs_fertiles == null ? null : Number(row.nb_oeufs_fertiles);
  const eclos = row.nb_eclos == null ? null : Number(row.nb_eclos);
  const viables = row.nb_poussins_viables == null ? null : Number(row.nb_poussins_viables);

  return {
    _id: row.id,
    code: row.code || '',
    race: row.race || '',
    bandeId: row.bande_id || null,
    dateMiseIncubation: row.date_mise_incubation || null,
    nbOeufsIncubes: incubes,
    dateMirage: row.date_mirage || null,
    nbOeufsFertiles: fertiles,
    dateEclosion: row.date_eclosion || null,
    nbEclos: eclos,
    nbPoussinsViables: viables,
    statut: row.statut || 'en_incubation',
    notes: row.notes || '',
    // Key hatchery KPIs.
    tauxFertilite: pct(fertiles, incubes),
    tauxEclosion: pct(eclos, fertiles != null ? fertiles : incubes),
    tauxEclosionSurIncubes: pct(eclos, incubes),
    tauxViabilite: pct(viables, eclos),
    createdAt: row.created_at || null,
    updatedAt: row.updated_at || null,
  };
}

router.get('/', requirePermission('reproduction.read'), async (req, res) => {
  try {
    const client = getAdminClient();
    const companyId = await getCompanyIdForUser(client, req.user.id || req.user._id);

    let query = client
      .from('couvees')
      .select('*')
      .eq('company_id', companyId)
      .order('date_mise_incubation', { ascending: false });

    const statut = (req.query.statut || '').toString().trim();
    if (statut && ALLOWED_STATUTS.has(statut)) query = query.eq('statut', statut);

    const result = await query;
    if (result.error) {
      if (isMissingTableError(result.error)) return res.json([]);
      return res.status(500).json({ message: result.error.message });
    }
    return res.json((result.data || []).map(mapCouveeRow));
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

router.get('/stats', requirePermission('reproduction.read'), async (req, res) => {
  try {
    const client = getAdminClient();
    const companyId = await getCompanyIdForUser(client, req.user.id || req.user._id);

    const result = await client.from('couvees').select('*').eq('company_id', companyId);
    if (result.error) {
      if (isMissingTableError(result.error)) {
        return res.json({ totalCouvees: 0, totalIncubes: 0, totalFertiles: 0, totalEclos: 0, tauxFertiliteMoyen: null, tauxEclosionMoyen: null });
      }
      return res.status(500).json({ message: result.error.message });
    }

    const rows = result.data || [];
    let totalIncubes = 0;
    let totalFertiles = 0;
    let totalEclos = 0;
    for (const r of rows) {
      totalIncubes += Number(r.nb_oeufs_incubes || 0);
      totalFertiles += Number(r.nb_oeufs_fertiles || 0);
      totalEclos += Number(r.nb_eclos || 0);
    }

    return res.json({
      totalCouvees: rows.length,
      totalIncubes,
      totalFertiles,
      totalEclos,
      tauxFertiliteMoyen: pct(totalFertiles, totalIncubes),
      tauxEclosionMoyen: pct(totalEclos, totalFertiles > 0 ? totalFertiles : totalIncubes),
    });
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

router.post('/', requirePermission('reproduction.create'), async (req, res) => {
  try {
    const client = getAdminClient();
    const companyId = await getCompanyIdForUser(client, req.user.id || req.user._id);

    const code = (req.body.code || '').toString().trim();
    const nbOeufsIncubes = num(req.body.nbOeufsIncubes);
    if (!code) return res.status(400).json({ message: 'Le code de la couvée est obligatoire' });
    if (nbOeufsIncubes == null || nbOeufsIncubes < 0) return res.status(400).json({ message: "Nombre d'œufs incubés invalide" });

    const payload = {
      company_id: companyId,
      code,
      race: (req.body.race || '').toString().trim(),
      bande_id: req.body.bandeId || null,
      date_mise_incubation: req.body.dateMiseIncubation || new Date().toISOString(),
      nb_oeufs_incubes: nbOeufsIncubes,
      statut: 'en_incubation',
      notes: (req.body.notes || '').toString(),
      updated_at: new Date().toISOString(),
    };

    const saved = await client.from('couvees').insert(payload).select('*').single();
    if (saved.error) {
      if (isMissingTableError(saved.error)) {
        return res.status(503).json({ message: "Table 'couvees' absente. Exécutez la migration SQL add_couvees_table.sql." });
      }
      return res.status(400).json({ message: saved.error.message });
    }
    return res.status(201).json(mapCouveeRow(saved.data));
  } catch (err) {
    return res.status(400).json({ message: err.message });
  }
});

router.put('/:id', requirePermission('reproduction.update'), async (req, res) => {
  try {
    const client = getAdminClient();
    const companyId = await getCompanyIdForUser(client, req.user.id || req.user._id);

    const updates = { updated_at: new Date().toISOString() };
    if (req.body.code !== undefined) updates.code = (req.body.code || '').toString().trim();
    if (req.body.race !== undefined) updates.race = (req.body.race || '').toString().trim();
    if (req.body.bandeId !== undefined) updates.bande_id = req.body.bandeId || null;
    if (req.body.dateMiseIncubation !== undefined) updates.date_mise_incubation = req.body.dateMiseIncubation;
    if (req.body.nbOeufsIncubes !== undefined) updates.nb_oeufs_incubes = num(req.body.nbOeufsIncubes) || 0;
    if (req.body.dateMirage !== undefined) updates.date_mirage = req.body.dateMirage || null;
    if (req.body.nbOeufsFertiles !== undefined) updates.nb_oeufs_fertiles = num(req.body.nbOeufsFertiles);
    if (req.body.dateEclosion !== undefined) updates.date_eclosion = req.body.dateEclosion || null;
    if (req.body.nbEclos !== undefined) updates.nb_eclos = num(req.body.nbEclos);
    if (req.body.nbPoussinsViables !== undefined) updates.nb_poussins_viables = num(req.body.nbPoussinsViables);
    if (req.body.notes !== undefined) updates.notes = (req.body.notes || '').toString();
    if (req.body.statut !== undefined) {
      const statut = (req.body.statut || '').toString().trim();
      if (!ALLOWED_STATUTS.has(statut)) return res.status(400).json({ message: 'Statut couvée invalide' });
      updates.statut = statut;
    }

    const saved = await client
      .from('couvees')
      .update(updates)
      .eq('company_id', companyId)
      .eq('id', req.params.id)
      .select('*')
      .maybeSingle();

    if (saved.error) return res.status(400).json({ message: saved.error.message });
    if (!saved.data) return res.status(404).json({ message: 'Couvée non trouvée' });
    return res.json(mapCouveeRow(saved.data));
  } catch (err) {
    return res.status(400).json({ message: err.message });
  }
});

router.delete('/:id', requirePermission('reproduction.delete'), async (req, res) => {
  try {
    const client = getAdminClient();
    const companyId = await getCompanyIdForUser(client, req.user.id || req.user._id);

    const removed = await client
      .from('couvees')
      .delete()
      .eq('company_id', companyId)
      .eq('id', req.params.id)
      .select('id')
      .maybeSingle();

    if (removed.error) return res.status(500).json({ message: removed.error.message });
    if (!removed.data) return res.status(404).json({ message: 'Couvée non trouvée' });
    return res.json({ message: 'Couvée supprimée' });
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

module.exports = router;
