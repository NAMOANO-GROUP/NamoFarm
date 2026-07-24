const express = require('express');
const { getAdminClient, logAudit } = require('../services/supabase');
const { getCompanyIdForUser } = require('../services/company_scope');
const { requirePermission, requireAnyPermission } = require('../middleware/auth');

const router = express.Router();

function normalizeInternationalPhone(value) {
  const input = String(value || '').trim();
  if (!input) return '';

  const match = input.match(/^\+(\d{1,4})\s*(.*)$/);
  if (!match) return null;

  const countryCode = `+${match[1]}`;
  const localDigits = (match[2] || '').replace(/\D/g, '');
  if (localDigits.length < 6) return null;

  const grouped = localDigits.match(/.{1,2}/g) || [];
  return `${countryCode} ${grouped.join(' ')}`.trim();
}

function extractMissingColumn(error) {
  const message = (error?.message || '').toString();
  const match = message.match(/Could not find the '([^']+)' column/i);
  return match?.[1] || '';
}

function str(value) {
  return (value ?? '').toString().trim();
}

function pickFirstNonEmpty(...values) {
  for (const value of values) {
    const candidate = str(value);
    if (candidate) return candidate;
  }
  return '';
}

// The `clients` table (which also stores fournisseurs) may lack dedicated columns for
// adresse / type_client / commentaire_activite / entreprise on minimal prod schemas.
// To avoid silently losing those fields, persist them inside the always-present `notes`
// column as a JSON envelope, while also writing canonical columns for forward-compat.
// Envelope format is shared with clients.js: {"_cx":1, notes, adresse, typeClient, ...}.
const EXT_MARKER = '_cx';

function encodeExtNotes(ext, defaultType) {
  const notes = str(ext.notes);
  const adresse = str(ext.adresse);
  const typeClient = str(ext.typeClient);
  const commentaireActivite = str(ext.commentaireActivite);
  const entreprise = str(ext.entreprise);
  const hasExtended = adresse || commentaireActivite || entreprise
    || (typeClient && typeClient !== defaultType);
  if (!hasExtended) return notes;
  return JSON.stringify({
    [EXT_MARKER]: 1,
    notes,
    adresse,
    typeClient: typeClient || defaultType,
    commentaireActivite,
    entreprise,
  });
}

function decodeExtNotes(raw) {
  const empty = { notes: '', adresse: '', typeClient: '', commentaireActivite: '', entreprise: '' };
  const value = raw == null ? '' : String(raw);
  const trimmed = value.trim();
  if (!trimmed.startsWith('{')) return { ...empty, notes: value };
  try {
    const obj = JSON.parse(trimmed);
    if (obj && obj[EXT_MARKER] === 1) {
      return {
        notes: str(obj.notes),
        adresse: str(obj.adresse),
        typeClient: str(obj.typeClient),
        commentaireActivite: str(obj.commentaireActivite),
        entreprise: str(obj.entreprise),
      };
    }
  } catch (_) {
    // Not an envelope, treat as plain notes.
  }
  return { ...empty, notes: value };
}

async function insertFournisseurCompat(client, payload) {
  let candidate = { ...payload };
  let lastMissingColumn = '';

  for (let i = 0; i < 15; i += 1) {
    const result = await client.from('clients').insert(candidate).select('*').single();
    if (!result.error) return result;

    const missingColumn = extractMissingColumn(result.error);
    if (!missingColumn) return result;
    lastMissingColumn = missingColumn;

    if (!Object.prototype.hasOwnProperty.call(candidate, missingColumn)) {
      return result;
    }

    delete candidate[missingColumn];
  }

  return {
    data: null,
    error: {
      message: `Creation fournisseur impossible: schema incompatible apres tentatives de fallback (derniere colonne: ${lastMissingColumn || 'inconnue'})`,
    },
  };
}

async function updateFournisseurCompat(client, companyId, fournisseurId, updates) {
  let candidate = { ...updates };
  let lastMissingColumn = '';

  for (let i = 0; i < 15; i += 1) {
    const result = await client
      .from('clients')
      .update(candidate)
      .eq('company_id', companyId)
      .eq('id', fournisseurId)
      .select('*')
      .single();

    if (!result.error) return result;

    const missingColumn = extractMissingColumn(result.error);
    if (!missingColumn) return result;
    lastMissingColumn = missingColumn;

    if (!Object.prototype.hasOwnProperty.call(candidate, missingColumn)) {
      return result;
    }

    delete candidate[missingColumn];
  }

  return {
    data: null,
    error: {
      message: `Modification fournisseur impossible: schema incompatible apres tentatives de fallback (derniere colonne: ${lastMissingColumn || 'inconnue'})`,
    },
  };
}

function mapFournisseurRow(row) {
  const decoded = decodeExtNotes(row.notes);
  const adresse = pickFirstNonEmpty(row.adresse, row.address, decoded.adresse);
  const commentaireActivite = pickFirstNonEmpty(
    row.commentaire_activite,
    row.commentaireActivite,
    row.activite_entreprise,
    row.activiteEntreprise,
    row.activite,
    row.activity_comment,
    row.company_activity,
    decoded.commentaireActivite,
  );
  const entreprise = pickFirstNonEmpty(
    row.entreprise,
    row.company,
    row.societe,
    row.societe_nom,
    decoded.entreprise,
  );

  return {
    _id: row.id,
    nom: row.nom,
    prenom: row.prenom || '',
    telephone: row.telephone || '',
    email: row.email || '',
    adresse,
    typeClient: row.type_client || row.typeClient || decoded.typeClient || 'pro',
    commentaireActivite,
    entreprise,
    notes: decoded.notes,
    statut: 'fournisseur',
    createdAt: row.created_at || row.createdAt,
    updatedAt: row.updated_at || row.updatedAt,
    dernierContactLe: row.dernier_contact_le || row.dernierContactLe,
    chiffreAffairesCumul: Number(row.chiffre_affaires_cumul || row.chiffreAffairesCumul || 0),
  };
}

function isFournisseurRow(row) {
  const statut = str(row?.statut || row?.status).toLowerCase();
  return statut === 'fournisseur';
}

async function safeAudit(client, payload) {
  try {
    await logAudit(client, payload);
  } catch (e) {
    console.warn('fournisseur audit log failed:', e?.message || e);
  }
}

router.get('/', requirePermission('clients.read'), async (req, res) => {
  try {
    const client = getAdminClient();
    const companyId = await getCompanyIdForUser(client, req.user.id || req.user._id);

    const { data, error } = await client
      .from('clients')
      .select('*')
      .eq('company_id', companyId)
      .order('nom', { ascending: true });

    if (error) return res.status(500).json({ message: error.message });

    const q = str(req.query.q).toLowerCase();
    let rows = (data || []).filter((row) => isFournisseurRow(row));
    if (q) {
      rows = rows.filter((row) => {
        const fields = [
          row.nom,
          row.prenom,
          row.telephone,
          row.entreprise,
          row.company,
          row.adresse,
          row.address,
          row.commentaire_activite,
          row.commentaireActivite,
          row.activite_entreprise,
          row.activiteEntreprise,
          row.activite,
          row.activity_comment,
          row.company_activity,
        ];
        return fields.some((v) => (v || '').toString().toLowerCase().includes(q));
      });
    }

    return res.json(rows.map(mapFournisseurRow));
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

router.get('/recherche', requirePermission('clients.read'), async (req, res) => {
  try {
    const client = getAdminClient();
    const companyId = await getCompanyIdForUser(client, req.user.id || req.user._id);

    const { data, error } = await client
      .from('clients')
      .select('*')
      .eq('company_id', companyId)
      .order('nom', { ascending: true });

    if (error) return res.status(500).json({ message: error.message });

    const q = str(req.query.q).toLowerCase();
    const rows = (data || [])
      .filter((row) => isFournisseurRow(row))
      .filter((row) => {
        const fields = [
          row.nom,
          row.prenom,
          row.telephone,
          row.entreprise,
          row.company,
          row.adresse,
          row.address,
          row.commentaire_activite,
          row.commentaireActivite,
          row.activite_entreprise,
          row.activiteEntreprise,
          row.activite,
          row.activity_comment,
          row.company_activity,
        ];
        return fields.some((v) => (v || '').toString().toLowerCase().includes(q));
      });

    return res.json(rows.map(mapFournisseurRow));
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

router.get('/:id', requirePermission('clients.read'), async (req, res) => {
  try {
    const client = getAdminClient();
    const companyId = await getCompanyIdForUser(client, req.user.id || req.user._id);

    const { data, error } = await client
      .from('clients')
      .select('*')
      .eq('company_id', companyId)
      .eq('id', req.params.id)
      .maybeSingle();

    if (error) return res.status(500).json({ message: error.message });
    if (!data || !isFournisseurRow(data)) return res.status(404).json({ message: 'Fournisseur non trouvé' });

    return res.json(mapFournisseurRow(data));
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

router.post('/', requirePermission('clients.create'), async (req, res) => {
  try {
    const nom = str(req.body.nom);
    const prenom = str(req.body.prenom);
    const telephone = normalizeInternationalPhone(req.body.telephone || '');
    if (!nom || !prenom || !telephone) {
      return res.status(400).json({ message: 'Les champs obligatoires fournisseur sont: nom, prenom, telephone' });
    }

    const adresse = pickFirstNonEmpty(req.body.adresse, req.body.address);
    const rawTypeClient = str(req.body.typeClient || req.body.type_client).toLowerCase();
    const typeClient = rawTypeClient === 'professionnel' ? 'pro' : (rawTypeClient || 'pro');
    const commentaireActivite = pickFirstNonEmpty(
      req.body.commentaireActivite,
      req.body.commentaire_activite,
      req.body.activiteEntreprise,
      req.body.activite_entreprise,
      req.body.activite,
      req.body.activityComment,
      req.body.companyActivity,
    );
    const entreprise = pickFirstNonEmpty(req.body.entreprise, req.body.company, req.body.societe);

    if (!['pro', 'particulier'].includes(typeClient)) {
      return res.status(400).json({ message: 'typeClient invalide (pro ou particulier)' });
    }

    const client = getAdminClient();
    const companyId = await getCompanyIdForUser(client, req.user.id || req.user._id);

    const payload = {
      company_id: companyId,
      nom,
      prenom,
      telephone,
      email: str(req.body.email),
      type_client: typeClient,
      statut: 'fournisseur',
      // Extended fields live in a notes envelope so they survive minimal prod schemas.
      notes: encodeExtNotes({
        notes: str(req.body.notes),
        adresse,
        typeClient,
        commentaireActivite,
        entreprise,
      }, 'pro'),
      dernier_contact_le: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    if (adresse) payload.adresse = adresse;
    if (commentaireActivite) payload.commentaire_activite = commentaireActivite;
    if (entreprise) payload.entreprise = entreprise;

    const { data, error } = await insertFournisseurCompat(client, payload);
    if (error) return res.status(400).json({ message: error.message });

    await safeAudit(client, {
      userId: req.user.id || req.user._id,
      userEmail: req.user.email,
      action: 'fournisseur.create',
      targetType: 'Fournisseur',
      targetId: data.id,
      metadata: {
        before: null,
        after: mapFournisseurRow(data),
      },
      ip: '',
    });

    return res.status(201).json(mapFournisseurRow(data));
  } catch (err) {
    return res.status(400).json({ message: err.message });
  }
});

router.put('/:id', requirePermission('clients.update'), async (req, res) => {
  try {
    const client = getAdminClient();
    const companyId = await getCompanyIdForUser(client, req.user.id || req.user._id);

    const existing = await client
      .from('clients')
      .select('*')
      .eq('company_id', companyId)
      .eq('id', req.params.id)
      .maybeSingle();

    if (existing.error) return res.status(400).json({ message: existing.error.message });
    if (!existing.data || !isFournisseurRow(existing.data)) {
      return res.status(404).json({ message: 'Fournisseur non trouvé' });
    }

    if (req.body.typeClient && !['pro', 'particulier'].includes(req.body.typeClient)) {
      return res.status(400).json({ message: 'typeClient invalide (pro ou particulier)' });
    }

    const updates = {
      updated_at: new Date().toISOString(),
      statut: 'fournisseur',
    };

    if (req.body.nom !== undefined) updates.nom = req.body.nom;
    if (req.body.prenom !== undefined) updates.prenom = req.body.prenom;
    if (req.body.telephone !== undefined) {
      const telephone = normalizeInternationalPhone(req.body.telephone);
      if (!telephone) return res.status(400).json({ message: 'Téléphone invalide. Format attendu: +221 77 12 34 56' });
      updates.telephone = telephone;
    }
    if (req.body.email !== undefined) updates.email = req.body.email;
    if (req.body.entreprise !== undefined || req.body.company !== undefined || req.body.societe !== undefined) {
      const entreprise = pickFirstNonEmpty(req.body.entreprise, req.body.company, req.body.societe);
      updates.entreprise = entreprise;
    }
    if (req.body.notes !== undefined) updates.notes = req.body.notes;

    if (req.body.adresse !== undefined || req.body.address !== undefined) {
      const adresse = pickFirstNonEmpty(req.body.adresse, req.body.address);
      if (!adresse) return res.status(400).json({ message: 'Adresse obligatoire' });
      updates.adresse = adresse;
    }

    if (
      req.body.commentaireActivite !== undefined ||
      req.body.commentaire_activite !== undefined ||
      req.body.activiteEntreprise !== undefined ||
      req.body.activite_entreprise !== undefined ||
      req.body.activite !== undefined ||
      req.body.activityComment !== undefined ||
      req.body.companyActivity !== undefined
    ) {
      const commentaire = pickFirstNonEmpty(
        req.body.commentaireActivite,
        req.body.commentaire_activite,
        req.body.activiteEntreprise,
        req.body.activite_entreprise,
        req.body.activite,
        req.body.activityComment,
        req.body.companyActivity,
      );
      if (!commentaire) return res.status(400).json({ message: 'Commentaire activité obligatoire' });
      updates.commentaire_activite = commentaire;
    }

    if (req.body.typeClient !== undefined) {
      updates.type_client = req.body.typeClient;
    }

    const before = mapFournisseurRow(existing.data);

    // Always re-encode the full extended state into the notes envelope (merging any
    // fields not provided in this partial update) so nothing is lost on minimal schemas.
    updates.notes = encodeExtNotes({
      notes: req.body.notes !== undefined ? str(req.body.notes) : before.notes,
      adresse: updates.adresse !== undefined ? updates.adresse : before.adresse,
      typeClient: updates.type_client !== undefined ? updates.type_client : before.typeClient,
      commentaireActivite: updates.commentaire_activite !== undefined
        ? updates.commentaire_activite
        : before.commentaireActivite,
      entreprise: updates.entreprise !== undefined ? updates.entreprise : before.entreprise,
    }, 'pro');

    const saved = await updateFournisseurCompat(client, companyId, req.params.id, updates);

    if (saved.error) return res.status(400).json({ message: saved.error.message });

    await safeAudit(client, {
      userId: req.user.id || req.user._id,
      userEmail: req.user.email,
      action: 'fournisseur.update',
      targetType: 'Fournisseur',
      targetId: req.params.id,
      metadata: {
        before,
        after: mapFournisseurRow(saved.data),
      },
      ip: '',
    });

    return res.json(mapFournisseurRow(saved.data));
  } catch (err) {
    return res.status(400).json({ message: err.message });
  }
});

router.delete('/:id', requireAnyPermission(['clients.delete', 'clients.update']), async (req, res) => {
  try {
    const client = getAdminClient();
    const companyId = await getCompanyIdForUser(client, req.user.id || req.user._id);

    const existing = await client
      .from('clients')
      .select('*')
      .eq('company_id', companyId)
      .eq('id', req.params.id)
      .maybeSingle();

    if (existing.error) return res.status(500).json({ message: existing.error.message });
    if (!existing.data || !isFournisseurRow(existing.data)) {
      return res.status(404).json({ message: 'Fournisseur non trouvé' });
    }

    const removed = await client
      .from('clients')
      .delete()
      .eq('company_id', companyId)
      .eq('id', req.params.id)
      .select('id')
      .maybeSingle();

    if (removed.error) return res.status(500).json({ message: removed.error.message });
    if (!removed.data) return res.status(404).json({ message: 'Fournisseur non trouvé' });

    await safeAudit(client, {
      userId: req.user.id || req.user._id,
      userEmail: req.user.email,
      action: 'fournisseur.delete',
      targetType: 'Fournisseur',
      targetId: req.params.id,
      metadata: {
        before: mapFournisseurRow(existing.data),
        after: null,
      },
      ip: '',
    });

    return res.json({ message: 'Fournisseur supprimé' });
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

module.exports = router;
module.exports.mapFournisseurRow = mapFournisseurRow;
module.exports.encodeExtNotes = encodeExtNotes;
module.exports.decodeExtNotes = decodeExtNotes;
