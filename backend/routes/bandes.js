const express = require('express');
const crypto = require('crypto');
const { getAdminClient } = require('../services/supabase');
const { getCompanyIdForUser } = require('../services/company_scope');
const { requireRole, requirePermission } = require('../middleware/auth');

const router = express.Router();

function csvEscape(value) {
  const raw = value == null ? '' : String(value);
  return `"${raw.replace(/"/g, '""')}"`;
}

function toCsv(rows) {
  return rows.map((row) => row.map(csvEscape).join(',')).join('\n');
}

function isMissingCategorieColumnError(error) {
  const message = (error?.message || '').toString().toLowerCase();
  return message.includes("could not find the 'categorie' column")
    || (message.includes('categorie') && message.includes('schema cache'));
}

function extractMissingColumn(error) {
  const message = (error?.message || '').toString();
  const match = message.match(/Could not find the '([^']+)' column/i);
  return match?.[1] || '';
}

function toLegacyTresoreriePayload(payload) {
  const mapped = { ...payload };
  if (Object.prototype.hasOwnProperty.call(mapped, 'company_id')) {
    mapped.companyId = mapped.company_id;
    delete mapped.company_id;
  }
  if (Object.prototype.hasOwnProperty.call(mapped, 'qui_nom')) {
    mapped.quiNom = mapped.qui_nom;
    delete mapped.qui_nom;
  }
  if (Object.prototype.hasOwnProperty.call(mapped, 'qui_prenom')) {
    mapped.quiPrenom = mapped.qui_prenom;
    delete mapped.qui_prenom;
  }
  if (Object.prototype.hasOwnProperty.call(mapped, 'date_mouvement')) {
    mapped.date = mapped.date_mouvement;
    delete mapped.date_mouvement;
  }
  if (Object.prototype.hasOwnProperty.call(mapped, 'reference_type')) {
    mapped.referenceType = mapped.reference_type;
    delete mapped.reference_type;
  }
  if (Object.prototype.hasOwnProperty.call(mapped, 'reference_id')) {
    mapped.referenceId = mapped.reference_id;
    delete mapped.reference_id;
  }
  if (Object.prototype.hasOwnProperty.call(mapped, 'externe_cle')) {
    mapped.externeCle = mapped.externe_cle;
    delete mapped.externe_cle;
  }
  return mapped;
}

function withCategoryHint(payload) {
  const cloned = { ...payload };
  const categoryHint = (cloned.categorie || '').toString().trim();
  if (!categoryHint) return cloned;
  const originalComment = (cloned.commentaire || '').toString().trim();
  cloned.commentaire = `[Categorie: ${categoryHint}]${originalComment ? ` ${originalComment}` : ''}`;
  return cloned;
}

async function insertTresorerieCompat(api, payload) {
  let candidate = { ...payload };
  let legacyAttempted = false;

  for (let i = 0; i < 6; i += 1) {
    const result = await api.from('tresorerie_mouvements').insert(candidate);
    if (!result.error) return result;

    const missingColumn = extractMissingColumn(result.error);
    if (!missingColumn) return result;

    if (!legacyAttempted && missingColumn.includes('_')) {
      candidate = toLegacyTresoreriePayload(candidate);
      legacyAttempted = true;
      continue;
    }

    if (!Object.prototype.hasOwnProperty.call(candidate, missingColumn)) {
      return result;
    }

    if (missingColumn === 'categorie') {
      candidate = withCategoryHint(candidate);
    }

    delete candidate[missingColumn];
  }

  return {
    data: null,
    error: { message: 'Insertion tresorerie impossible: schema incompatible apres tentatives de fallback' },
  };
}

function toArray(value) {
  return Array.isArray(value) ? value : [];
}

async function updateStockCompat(api, companyId, stockId, updateObj) {
  let candidate = { ...updateObj };
  let lastMissingColumn = '';

  for (let i = 0; i < 12; i += 1) {
    const result = await api
      .from('stocks')
      .update(candidate)
      .eq('company_id', companyId)
      .eq('id', stockId)
      .select('*')
      .maybeSingle();
    if (!result.error) return result;

    const missingColumn = extractMissingColumn(result.error);
    if (!missingColumn) return result;
    lastMissingColumn = missingColumn;

    if (
      missingColumn === 'mouvements'
      && Object.prototype.hasOwnProperty.call(candidate, 'mouvements')
      && !Object.prototype.hasOwnProperty.call(candidate, 'mouvement')
    ) {
      candidate.mouvement = candidate.mouvements;
    }

    if (!Object.prototype.hasOwnProperty.call(candidate, missingColumn)) {
      return result;
    }

    delete candidate[missingColumn];
  }

  return {
    data: null,
    error: {
      message: `Mise a jour stock impossible: schema incompatible apres fallback (derniere colonne: ${lastMissingColumn || 'inconnue'})`,
    },
  };
}

function getUserLabel(req) {
  const prenom = (req.user?.prenom || '').toString().trim();
  const nom = (req.user?.nom || '').toString().trim();
  const full = `${prenom} ${nom}`.trim();
  if (full) return full;
  return req.user?.email || req.user?.nomComplet || req.user?.nom || 'Utilisateur';
}

function getUserName(req) {
  const prenom = (req.user?.prenom || '').toString().trim();
  const nom = (req.user?.nom || '').toString().trim();
  if (prenom || nom) {
    return {
      quiNom: nom || prenom,
      quiPrenom: prenom || nom,
    };
  }

  const full = (req.user?.nomComplet || req.user?.fullName || '').toString().trim();
  if (full) {
    const parts = full.split(/\s+/).filter(Boolean);
    if (parts.length === 1) return { quiNom: parts[0], quiPrenom: parts[0] };
    return { quiNom: parts.slice(1).join(' '), quiPrenom: parts[0] };
  }
  const email = (req.user?.email || '').toString();
  const local = email.includes('@') ? email.split('@')[0] : email;
  return { quiNom: local || 'Utilisateur', quiPrenom: local || 'Utilisateur' };
}

function isoOrNow(value) {
  const d = value ? new Date(value) : new Date();
  return Number.isNaN(d.getTime()) ? new Date().toISOString() : d.toISOString();
}

function mapBandeRow(row) {
  const dateOuverture = row.date_ouverture || new Date().toISOString();
  const dateFermeture = row.date_fermeture || null;
  const fin = dateFermeture ? new Date(dateFermeture) : new Date();
  const debut = new Date(dateOuverture);
  // Âge en jours calendaires : le changement de jour se fait à minuit (0h),
  // indépendamment de l'heure exacte d'ouverture de la bande.
  const debutMidnight = Date.UTC(debut.getUTCFullYear(), debut.getUTCMonth(), debut.getUTCDate());
  const finMidnight = Date.UTC(fin.getUTCFullYear(), fin.getUTCMonth(), fin.getUTCDate());
  const ageJours = Math.max(0, Math.floor((finMidnight - debutMidnight) / (1000 * 60 * 60 * 24)));

  const nombreInitial = Number(row.nombre_initial || 0);
  const mortaliteTotale = Number(row.mortalite_totale || 0);
  const tauxMortalite = nombreInitial > 0 ? ((mortaliteTotale / nombreInitial) * 100).toFixed(2) : '0.00';

  const suiviJournalier = toArray(row.suivi_journalier).map((s) => ({
    _id: s._id || crypto.randomUUID(),
    date: s.date || new Date().toISOString(),
    poidsMotenG: Number(s.poidsMotenG || 0),
    ...(s.poidsMinG != null ? { poidsMinG: Number(s.poidsMinG) } : {}),
    ...(s.poidsMaxG != null ? { poidsMaxG: Number(s.poidsMaxG) } : {}),
    ...(Array.isArray(s.poidsValeurs) ? { poidsValeurs: s.poidsValeurs } : {}),
    mortaliteJour: Number(s.mortaliteJour || 0),
    alimentationKg: Number(s.alimentationKg || 0),
    alimentationStockId: s.alimentationStockId || null,
    alimentationType: s.alimentationType || '',
    eauLitres: Number(s.eauLitres || 0),
    temperature: Number(s.temperature || 0),
    humidite: Number(s.humidite || 0),
    observations: s.observations || '',
  }));

  const evenementsSante = toArray(row.evenements_sante).map((e) => ({
    _id: e._id || crypto.randomUUID(),
    date: e.date || new Date().toISOString(),
    type: e.type || 'autre',
    description: e.description || '',
    medicament: e.medicament || '',
    doseParTete: e.doseParTete || '',
    dureeJours: Number(e.dureeJours || 1),
    cout: Number(e.cout || 0),
  }));

  const evenementsPrevisionnels = toArray(row.evenements_previsionnels).map((e) => ({
    _id: e._id || crypto.randomUUID(),
    type: e.type || 'intervention_diverse',
    datePrevue: e.datePrevue || new Date().toISOString(),
    description: e.description || '',
    priorite: e.priorite || 'moyenne',
    commentaires: e.commentaires || '',
    prophylaxieStockId: e.prophylaxieStockId || null,
    prophylaxieType: e.prophylaxieType || '',
    prophylaxieQuantite: Number(e.prophylaxieQuantite || 0),
    statut: e.statut || 'planifie',
    dateRealisation: e.dateRealisation || null,
    commentairesRealisation: e.commentairesRealisation || '',
  }));

  return {
    _id: row.id,
    nom: row.nom,
    dateOuverture,
    dateFermeture,
    statut: row.statut || 'ouverte',
    typeVolaille: row.type_volaille || 'poulet_chair',
    race: row.race || '',
    fournisseurPoussins: row.fournisseur_poussins || '',
    nombreInitial,
    nombreActuel: Number(row.nombre_actuel || 0),
    mortaliteTotale,
    poidsArriveeG: Number(row.poids_arrivee_g || 0),
    objectifPoidsG: Number(row.objectif_poids_g || 0),
    dureeElevageJours: Number(row.duree_elevage_jours || 45),
    batiment: row.batiment || '',
    coutFixeParSujet: Number(row.cout_fixe_par_sujet || 0),
    amortissementParSujet: Number(row.amortissement_par_sujet || 0),
    suiviJournalier,
    evenementsSante,
    evenementsPrevisionnels,
    notes: row.notes || '',
    ageJours,
    tauxMortalite,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

async function getBandeOr404(api, companyId, id, res) {
  const result = await api.from('bandes').select('*').eq('company_id', companyId).eq('id', id).maybeSingle();
  if (result.error) {
    res.status(400).json({ message: result.error.message });
    return null;
  }
  if (!result.data) {
    res.status(404).json({ message: 'Bande non trouvée' });
    return null;
  }
  return result.data;
}

router.get('/actives', requirePermission('bandes.read'), async (req, res) => {
  try {
    const api = getAdminClient();
    const companyId = await getCompanyIdForUser(api, req.user.id || req.user._id);
    const result = await api.from('bandes').select('*').eq('company_id', companyId).eq('statut', 'ouverte').order('date_ouverture', { ascending: false });
    if (result.error) return res.status(500).json({ message: result.error.message });
    return res.json((result.data || []).map(mapBandeRow));
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

router.get('/historique', requirePermission('bandes.read'), async (req, res) => {
  try {
    const api = getAdminClient();
    const companyId = await getCompanyIdForUser(api, req.user.id || req.user._id);
    const result = await api.from('bandes').select('*').eq('company_id', companyId).eq('statut', 'fermee').order('date_fermeture', { ascending: false });
    if (result.error) return res.status(500).json({ message: result.error.message });
    return res.json((result.data || []).map(mapBandeRow));
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

router.get('/historique/export.csv', requirePermission('bandes.read'), async (req, res) => {
  try {
    const api = getAdminClient();
    const companyId = await getCompanyIdForUser(api, req.user.id || req.user._id);
    const result = await api
      .from('bandes')
      .select('*')
      .eq('company_id', companyId)
      .eq('statut', 'fermee')
      .order('date_fermeture', { ascending: false });

    if (result.error) return res.status(500).json({ message: result.error.message });

    const header = [
      'id',
      'nom',
      'statut',
      'batiment',
      'nombre_initial',
      'nombre_actuel',
      'mortalite_totale',
      'taux_mortalite',
      'date_ouverture',
      'date_fermeture',
      'updated_at',
    ];

    const rows = (result.data || []).map((row) => {
      const bande = mapBandeRow(row);
      return [
        bande._id,
        bande.nom,
        bande.statut,
        bande.batiment,
        bande.nombreInitial,
        bande.nombreActuel,
        bande.mortaliteTotale,
        bande.tauxMortalite,
        bande.dateOuverture,
        bande.dateFermeture,
        bande.updatedAt,
      ];
    });

    const csv = toCsv([header, ...rows]);
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="bandes_historique_${new Date().toISOString().slice(0, 10)}.csv"`);
    return res.status(200).send('\uFEFF' + csv);
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

router.get('/performances/batiment', requirePermission('bandes.read'), async (req, res) => {
  try {
    const api = getAdminClient();
    const companyId = await getCompanyIdForUser(api, req.user.id || req.user._id);
    const result = await api.from('bandes').select('*').eq('company_id', companyId);
    if (result.error) return res.status(500).json({ message: result.error.message });

    const byBatiment = new Map();
    for (const row of result.data || []) {
      const b = mapBandeRow(row);
      const key = b.batiment || 'Non renseigné';
      if (!byBatiment.has(key)) {
        byBatiment.set(key, { batiment: key, nbBandes: 0, effectifInitial: 0, effectifRestant: 0, mortalite: 0 });
      }
      const a = byBatiment.get(key);
      a.nbBandes += 1;
      a.effectifInitial += Number(b.nombreInitial || 0);
      a.effectifRestant += Number(b.nombreActuel || 0);
      a.mortalite += Number(b.mortaliteTotale || 0);
    }

    const data = [...byBatiment.values()].map((x) => ({
      ...x,
      tauxMortalite: x.effectifInitial > 0 ? (x.mortalite / x.effectifInitial) * 100 : 0,
    })).sort((a, b) => a.tauxMortalite - b.tauxMortalite);

    return res.json(data);
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

router.get('/comparaison', requirePermission('bandes.read'), async (req, res) => {
  try {
    const api = getAdminClient();
    const companyId = await getCompanyIdForUser(api, req.user.id || req.user._id);
    const result = await api.from('bandes').select('*').eq('company_id', companyId).order('created_at', { ascending: false }).limit(20);
    if (result.error) return res.status(500).json({ message: result.error.message });

    const data = (result.data || []).map((row) => {
      const b = mapBandeRow(row);
      const alimentationTotale = b.suiviJournalier.reduce((s, j) => s + Number(j.alimentationKg || 0), 0);
      const dernierPoids = b.suiviJournalier.length ? Number(b.suiviJournalier[b.suiviJournalier.length - 1].poidsMotenG || 0) : 0;
      return {
        id: b._id,
        nom: b.nom,
        batiment: b.batiment,
        statut: b.statut,
        ageJours: b.ageJours,
        effectifInitial: b.nombreInitial,
        effectifRestant: b.nombreActuel,
        mortalite: b.mortaliteTotale,
        tauxMortalite: Number(b.tauxMortalite || 0),
        alimentationTotale,
        dernierPoids,
      };
    });

    return res.json(data);
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

router.get('/:id', requirePermission('bandes.read'), async (req, res) => {
  try {
    const api = getAdminClient();
    const companyId = await getCompanyIdForUser(api, req.user.id || req.user._id);
    const row = await getBandeOr404(api, companyId, req.params.id, res);
    if (!row) return undefined;
    return res.json(mapBandeRow(row));
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

router.get('/:id/stats', requirePermission('bandes.read'), async (req, res) => {
  try {
    const api = getAdminClient();
    const companyId = await getCompanyIdForUser(api, req.user.id || req.user._id);
    const row = await getBandeOr404(api, companyId, req.params.id, res);
    if (!row) return undefined;

    const b = mapBandeRow(row);
    const suivis = b.suiviJournalier;
    const dernierSuivi = suivis.length ? suivis[suivis.length - 1] : null;
    const alimentationTotale = suivis.reduce((sum, s) => sum + Number(s.alimentationKg || 0), 0);
    const eauTotale = suivis.reduce((sum, s) => sum + Number(s.eauLitres || 0), 0);
    const dernierPoids = dernierSuivi ? Number(dernierSuivi.poidsMotenG || 0) : 0;
    const gainPoids = dernierPoids - Number(b.poidsArriveeG || 0);
    const indiceConsommation = dernierPoids > 0 && Number(b.nombreActuel || 0) > 0
      ? ((alimentationTotale * 1000) / (Number(b.nombreActuel || 0) * dernierPoids)).toFixed(2)
      : 0;

    return res.json({
      ageJours: b.ageJours,
      nombreActuel: b.nombreActuel,
      mortaliteTotale: b.mortaliteTotale,
      tauxMortalite: b.tauxMortalite,
      dernierPoids,
      gainPoids,
      alimentationTotale,
      eauTotale,
      indiceConsommation,
      nombreSuivisJournaliers: suivis.length,
      nombreEvenementsSante: b.evenementsSante.length,
    });
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

router.post('/', requirePermission('bandes.create'), async (req, res) => {
  try {
    const api = getAdminClient();
    const companyId = await getCompanyIdForUser(api, req.user.id || req.user._id);

    const opened = await api.from('bandes').select('id', { count: 'exact', head: true }).eq('company_id', companyId).eq('statut', 'ouverte');
    if (opened.error) return res.status(400).json({ message: opened.error.message });
    if ((opened.count || 0) >= 5) {
      return res.status(400).json({ message: 'Maximum 5 bandes ouvertes en parallele' });
    }

    const dateOuverture = req.body.dateOuverture ? new Date(req.body.dateOuverture) : new Date();
    if (Number.isNaN(dateOuverture.getTime())) return res.status(400).json({ message: 'Date d\'ouverture invalide' });

    // Si un protocole vaccinal est choisi, on génère les événements prévisionnels
    // à partir de ses étapes : datePrevue = jour d'installation + jourAge de l'étape.
    let evenementsPrevisionnels = [];
    const protocoleId = (req.body.protocoleId || '').toString().trim();
    if (protocoleId) {
      const protoRes = await api
        .from('protocoles_vaccinaux')
        .select('*')
        .eq('company_id', companyId)
        .eq('id', protocoleId)
        .maybeSingle();
      if (protoRes.data) {
        const etapes = Array.isArray(protoRes.data.etapes) ? protoRes.data.etapes : [];
        const baseMidnight = Date.UTC(dateOuverture.getUTCFullYear(), dateOuverture.getUTCMonth(), dateOuverture.getUTCDate());
        evenementsPrevisionnels = etapes.map((e) => {
          const jourAge = Number(e.jourAge || 0);
          const datePrevue = new Date(baseMidnight + jourAge * 24 * 60 * 60 * 1000);
          const intervention = (e.intervention || 'Intervention').toString();
          const produit = (e.produit || '').toString();
          return {
            _id: crypto.randomUUID(),
            type: 'vaccination',
            datePrevue: datePrevue.toISOString(),
            description: `J${jourAge} - ${intervention}${produit ? ` (${produit})` : ''}`,
            priorite: 'haute',
            commentaires: [e.dose ? `Dose: ${e.dose}` : '', e.voie ? `Voie: ${e.voie}` : '', e.notes || ''].filter(Boolean).join(' • '),
            prophylaxieStockId: null,
            prophylaxieType: produit,
            prophylaxieQuantite: 0,
            statut: 'planifie',
            dateRealisation: null,
            commentairesRealisation: '',
          };
        });
      }
    }

    const payload = {
      company_id: companyId,
      nom: req.body.nom,
      date_ouverture: dateOuverture.toISOString(),
      type_volaille: req.body.typeVolaille,
      race: req.body.race,
      fournisseur_poussins: req.body.fournisseurPoussins || '',
      nombre_initial: Number(req.body.nombreInitial || 0),
      nombre_actuel: Number(req.body.nombreInitial || 0),
      poids_arrivee_g: Number(req.body.poidsArriveeG || 0),
      objectif_poids_g: Number(req.body.objectifPoidsG || 0),
      duree_elevage_jours: Number(req.body.dureeElevageJours || 45),
      batiment: req.body.batiment || '',
      notes: req.body.notes || '',
      evenements_previsionnels: evenementsPrevisionnels,
      updated_at: new Date().toISOString(),
    };

    const created = await api.from('bandes').insert(payload).select('*').single();
    if (created.error) return res.status(400).json({ message: created.error.message });
    return res.status(201).json(mapBandeRow(created.data));
  } catch (err) {
    return res.status(400).json({ message: err.message });
  }
});

router.put('/:id', requirePermission('bandes.update'), async (req, res) => {
  try {
    const api = getAdminClient();
    const companyId = await getCompanyIdForUser(api, req.user.id || req.user._id);
    const current = await getBandeOr404(api, companyId, req.params.id, res);
    if (!current) return undefined;

    const updates = {
      updated_at: new Date().toISOString(),
    };
    const map = {
      nom: 'nom',
      dateOuverture: 'date_ouverture',
      dateFermeture: 'date_fermeture',
      statut: 'statut',
      typeVolaille: 'type_volaille',
      race: 'race',
      fournisseurPoussins: 'fournisseur_poussins',
      nombreInitial: 'nombre_initial',
      nombreActuel: 'nombre_actuel',
      mortaliteTotale: 'mortalite_totale',
      poidsArriveeG: 'poids_arrivee_g',
      objectifPoidsG: 'objectif_poids_g',
      dureeElevageJours: 'duree_elevage_jours',
      batiment: 'batiment',
      coutFixeParSujet: 'cout_fixe_par_sujet',
      amortissementParSujet: 'amortissement_par_sujet',
      notes: 'notes',
    };

    for (const [k, dbk] of Object.entries(map)) {
      if (Object.prototype.hasOwnProperty.call(req.body, k)) updates[dbk] = req.body[k];
    }

    const saved = await api.from('bandes').update(updates).eq('company_id', companyId).eq('id', req.params.id).select('*').single();
    if (saved.error) return res.status(400).json({ message: saved.error.message });
    return res.json(mapBandeRow(saved.data));
  } catch (err) {
    return res.status(400).json({ message: err.message });
  }
});

router.put('/:id/fermer', requirePermission('bandes.close'), async (req, res) => {
  try {
    const api = getAdminClient();
    const companyId = await getCompanyIdForUser(api, req.user.id || req.user._id);
    const saved = await api
      .from('bandes')
      .update({ statut: 'fermee', date_fermeture: new Date().toISOString(), updated_at: new Date().toISOString() })
      .eq('company_id', companyId)
      .eq('id', req.params.id)
      .select('*')
      .maybeSingle();

    if (saved.error) return res.status(400).json({ message: saved.error.message });
    if (!saved.data) return res.status(404).json({ message: 'Bande non trouvée' });
    return res.json(mapBandeRow(saved.data));
  } catch (err) {
    return res.status(400).json({ message: err.message });
  }
});

router.post('/:id/suivi', requirePermission('bandes.suivi.create'), async (req, res) => {
  try {
    const alimentationKg = Number(req.body.alimentationKg || 0);
    const alimentationStockId = (req.body.alimentationStockId || '').toString().trim();
    const alimentationType = (req.body.alimentationType || '').toString().trim();
    const mortaliteJour = Number(req.body.mortaliteJour);
    const observations = (req.body.observations || '').toString().trim();

    if (alimentationKg <= 0 || Number.isNaN(mortaliteJour) || mortaliteJour < 0 || observations.length === 0) {
      return res.status(400).json({ message: 'Les champs obligatoires du suivi sont: alimentationKg, mortaliteJour, observations' });
    }
    if (!alimentationStockId) {
      return res.status(400).json({ message: 'Le type d\'alimentation est obligatoire pour le suivi' });
    }

    const api = getAdminClient();
    const companyId = await getCompanyIdForUser(api, req.user.id || req.user._id);
    const bandeRow = await getBandeOr404(api, companyId, req.params.id, res);
    if (!bandeRow) return undefined;
    const bande = mapBandeRow(bandeRow);

    const stockRes = await api.from('stocks').select('*').eq('company_id', companyId).eq('id', alimentationStockId).maybeSingle();
    if (stockRes.error) return res.status(400).json({ message: stockRes.error.message });
    if (!stockRes.data) return res.status(404).json({ message: 'Type d\'alimentation non trouvé en stock' });
    if (stockRes.data.categorie !== 'aliment') return res.status(400).json({ message: 'Le stock sélectionné pour l\'alimentation doit être de catégorie aliment' });
    if (Number(stockRes.data.quantite_actuelle || 0) < alimentationKg) return res.status(400).json({ message: 'Stock insuffisant pour l\'alimentation sélectionnée' });

    const suiviDateIso = isoOrNow(req.body.date);
    const suivi = {
      _id: crypto.randomUUID(),
      date: suiviDateIso,
      poidsMotenG: Number(req.body.poidsMotenG || 0),
      mortaliteJour,
      alimentationKg,
      alimentationStockId,
      alimentationType: alimentationType || stockRes.data.nom || '',
      eauLitres: Number(req.body.eauLitres || 0),
      temperature: Number(req.body.temperature || 0),
      humidite: Number(req.body.humidite || 0),
      observations,
    };

    const suivis = [...bande.suiviJournalier, suivi];
    const newMortalite = Number(bande.mortaliteTotale || 0) + mortaliteJour;
    const newNombreActuel = Math.max(0, Number(bande.nombreActuel || 0) - mortaliteJour);

    const stockMouvements = toArray(stockRes.data.mouvements);
    stockMouvements.push({
      _id: crypto.randomUUID(),
      suiviId: suivi._id,
      date: suiviDateIso,
      type: 'sortie',
      quantite: alimentationKg,
      utilisateur: getUserLabel(req),
      bandeId: bande._id,
      motif: `Consommation alimentation - suivi bande ${bande.nom}`,
      coutUnitaire: Number(stockRes.data.prix_unitaire || 0),
    });

    const stockSave = await updateStockCompat(api, companyId, stockRes.data.id, {
      quantite_actuelle: Number(stockRes.data.quantite_actuelle || 0) - alimentationKg,
      mouvements: stockMouvements,
      updated_at: new Date().toISOString(),
    });
    if (stockSave.error) return res.status(400).json({ message: stockSave.error.message });

    const saved = await api
      .from('bandes')
      .update({
        suivi_journalier: suivis,
        mortalite_totale: newMortalite,
        nombre_actuel: newNombreActuel,
        updated_at: new Date().toISOString(),
      })
      .eq('company_id', companyId)
      .eq('id', bande._id)
      .select('*')
      .single();

    if (saved.error) return res.status(400).json({ message: saved.error.message });
    return res.status(201).json(mapBandeRow(saved.data));
  } catch (err) {
    return res.status(400).json({ message: err.message });
  }
});

router.put('/:id/suivi/:suiviId/alimentation', requirePermission('bandes.suivi.create'), async (req, res) => {
  try {
    const alimentationStockId = (req.body.alimentationStockId || '').toString().trim();
    if (!alimentationStockId) return res.status(400).json({ message: "Le type d'alimentation est obligatoire" });

    const api = getAdminClient();
    const companyId = await getCompanyIdForUser(api, req.user.id || req.user._id);
    const bandeRow = await getBandeOr404(api, companyId, req.params.id, res);
    if (!bandeRow) return undefined;

    const suivis = toArray(bandeRow.suivi_journalier).map((s) => ({ ...s }));
    const suiviIndex = suivis.findIndex((s) => String(s._id || '') === req.params.suiviId);
    if (suiviIndex < 0) return res.status(404).json({ message: 'Relevé de suivi introuvable' });

    const suivi = suivis[suiviIndex];
    const oldStockId = (suivi.alimentationStockId || '').toString();
    const alimentationKg = Number(suivi.alimentationKg || 0);
    if (!oldStockId || alimentationKg <= 0) {
      return res.status(400).json({ message: "Ce relevé n'a pas de stock alimentaire modifiable" });
    }

    const oldStockRes = await api.from('stocks').select('*').eq('company_id', companyId).eq('id', oldStockId).maybeSingle();
    if (oldStockRes.error) return res.status(400).json({ message: oldStockRes.error.message });
    if (!oldStockRes.data) return res.status(404).json({ message: "L'ancien stock alimentaire est introuvable" });

    const newStockRes = await api.from('stocks').select('*').eq('company_id', companyId).eq('id', alimentationStockId).maybeSingle();
    if (newStockRes.error) return res.status(400).json({ message: newStockRes.error.message });
    if (!newStockRes.data) return res.status(404).json({ message: 'Le nouveau stock alimentaire est introuvable' });
    if (newStockRes.data.categorie !== 'aliment') {
      return res.status(400).json({ message: 'Le stock sélectionné doit être de catégorie aliment' });
    }

    const bande = mapBandeRow(bandeRow);
    const oldMovements = toArray(oldStockRes.data.mouvements);
    const suiviDate = new Date(suivi.date).getTime();
    const candidates = oldMovements
      .map((movement, index) => ({ movement, index }))
      .filter(({ movement }) => {
        if (movement.suiviId) return String(movement.suiviId) === req.params.suiviId;
        const movementDate = new Date(movement.date || '').getTime();
        return movement.type === 'sortie'
          && String(movement.bandeId || '') === String(bande._id)
          && Math.abs(Number(movement.quantite || 0) - alimentationKg) < 0.001
          && Math.abs(movementDate - suiviDate) < 1000
          && (movement.motif || '').toString().startsWith('Consommation alimentation - suivi bande ');
      });
    if (candidates.length !== 1) {
      return res.status(409).json({ message: "Mouvement de stock introuvable ou ambigu : inventaire inchangé" });
    }

    suivi.alimentationStockId = alimentationStockId;
    suivi.alimentationType = (newStockRes.data.nom || '').toString();

    if (oldStockId === alimentationStockId) {
      suivis[suiviIndex] = suivi;
      const saved = await api.from('bandes')
        .update({ suivi_journalier: suivis, updated_at: new Date().toISOString() })
        .eq('company_id', companyId)
        .eq('id', bande._id)
        .select('*')
        .single();
      if (saved.error) return res.status(400).json({ message: saved.error.message });
      return res.json(mapBandeRow(saved.data));
    }

    const targetMovements = toArray(newStockRes.data.mouvements);
    const movedStockEntry = {
      ...candidates[0].movement,
      suiviId: req.params.suiviId,
      utilisateur: getUserLabel(req),
      bandeId: bande._id,
      motif: `Consommation alimentation - suivi bande ${bande.nom}`,
      coutUnitaire: Number(newStockRes.data.prix_unitaire || 0),
    };
    oldMovements.splice(candidates[0].index, 1);
    targetMovements.push(movedStockEntry);

    if (Number(newStockRes.data.quantite_actuelle || 0) < alimentationKg) {
      return res.status(400).json({ message: 'Stock insuffisant pour corriger ce relevé' });
    }

    const oldQuantity = Number(oldStockRes.data.quantite_actuelle || 0);
    const targetQuantity = Number(newStockRes.data.quantite_actuelle || 0);
    const oldSaved = await updateStockCompat(api, companyId, oldStockId, {
      quantite_actuelle: oldQuantity + alimentationKg,
      mouvements: oldMovements,
      updated_at: new Date().toISOString(),
    });
    if (oldSaved.error) return res.status(400).json({ message: oldSaved.error.message });

    const targetSaved = await updateStockCompat(api, companyId, alimentationStockId, {
      quantite_actuelle: targetQuantity - alimentationKg,
      mouvements: targetMovements,
      updated_at: new Date().toISOString(),
    });
    if (targetSaved.error) {
      await updateStockCompat(api, companyId, oldStockId, {
        quantite_actuelle: oldQuantity,
        mouvements: toArray(oldStockRes.data.mouvements),
      });
      return res.status(400).json({ message: targetSaved.error.message });
    }

    suivis[suiviIndex] = suivi;
    const saved = await api.from('bandes')
      .update({ suivi_journalier: suivis, updated_at: new Date().toISOString() })
      .eq('company_id', companyId)
      .eq('id', bande._id)
      .select('*')
      .single();
    if (saved.error) {
      await updateStockCompat(api, companyId, oldStockId, {
        quantite_actuelle: oldQuantity,
        mouvements: toArray(oldStockRes.data.mouvements),
      });
      await updateStockCompat(api, companyId, alimentationStockId, {
        quantite_actuelle: targetQuantity,
        mouvements: toArray(newStockRes.data.mouvements),
      });
      return res.status(400).json({ message: saved.error.message });
    }
    return res.json(mapBandeRow(saved.data));
  } catch (err) {
    return res.status(400).json({ message: err.message });
  }
});

router.post('/:id/mortalite', requirePermission('bandes.mortalite.create'), async (req, res) => {
  try {
    const mortaliteJour = Number(req.body.mortaliteJour);
    const observations = (req.body.observations || '').toString().trim();

    if (Number.isNaN(mortaliteJour) || mortaliteJour <= 0) {
      return res.status(400).json({ message: 'La mortalité du jour doit être supérieure à 0' });
    }

    const api = getAdminClient();
    const companyId = await getCompanyIdForUser(api, req.user.id || req.user._id);
    const bandeRow = await getBandeOr404(api, companyId, req.params.id, res);
    if (!bandeRow) return undefined;
    const bande = mapBandeRow(bandeRow);

    const suivi = {
      _id: crypto.randomUUID(),
      date: isoOrNow(req.body.date),
      poidsMotenG: 0,
      mortaliteJour,
      alimentationKg: 0,
      alimentationStockId: null,
      alimentationType: '',
      eauLitres: 0,
      temperature: 0,
      humidite: 0,
      observations: observations || 'Déclaration de mortalité',
    };

    const suivis = [...bande.suiviJournalier, suivi];
    const newMortalite = Number(bande.mortaliteTotale || 0) + mortaliteJour;
    const newNombreActuel = Math.max(0, Number(bande.nombreActuel || 0) - mortaliteJour);

    const saved = await api
      .from('bandes')
      .update({
        suivi_journalier: suivis,
        mortalite_totale: newMortalite,
        nombre_actuel: newNombreActuel,
        updated_at: new Date().toISOString(),
      })
      .eq('company_id', companyId)
      .eq('id', bande._id)
      .select('*')
      .single();

    if (saved.error) return res.status(400).json({ message: saved.error.message });
    return res.status(201).json(mapBandeRow(saved.data));
  } catch (err) {
    return res.status(400).json({ message: err.message });
  }
});

router.post('/:id/poids', requirePermission('bandes.poids.create'), async (req, res) => {
  try {
    // Accepte une liste de valeurs (jusqu'à 6) OU un poids moyen direct (rétro-compat).
    const valeurs = Array.isArray(req.body.poidsValeurs)
      ? req.body.poidsValeurs.map((v) => Number(v)).filter((v) => Number.isFinite(v) && v > 0)
      : [];
    let moyenne;
    let minG;
    let maxG;
    if (valeurs.length > 0) {
      moyenne = valeurs.reduce((s, v) => s + v, 0) / valeurs.length;
      minG = Math.min(...valeurs);
      maxG = Math.max(...valeurs);
    } else {
      moyenne = Number(req.body.poidsMotenG || 0);
      minG = moyenne;
      maxG = moyenne;
    }
    if (!(moyenne > 0)) return res.status(400).json({ message: 'Le poids doit être supérieur à 0' });

    const api = getAdminClient();
    const companyId = await getCompanyIdForUser(api, req.user.id || req.user._id);
    const bandeRow = await getBandeOr404(api, companyId, req.params.id, res);
    if (!bandeRow) return undefined;
    const bande = mapBandeRow(bandeRow);

    const suivis = [...bande.suiviJournalier, {
      _id: crypto.randomUUID(),
      date: isoOrNow(req.body.date),
      poidsMotenG: Number(moyenne.toFixed(2)),
      poidsMinG: Number(minG.toFixed(2)),
      poidsMaxG: Number(maxG.toFixed(2)),
      poidsValeurs: valeurs,
      mortaliteJour: 0,
      alimentationKg: 0,
      eauLitres: 0,
      observations: req.body.observations || 'Relevé de poids',
    }];

    const saved = await api.from('bandes').update({ suivi_journalier: suivis, updated_at: new Date().toISOString() }).eq('company_id', companyId).eq('id', bande._id).select('*').single();
    if (saved.error) return res.status(400).json({ message: saved.error.message });
    return res.status(201).json(mapBandeRow(saved.data));
  } catch (err) {
    return res.status(400).json({ message: err.message });
  }
});

router.get('/:id/poids', requirePermission('bandes.read'), async (req, res) => {
  try {
    const api = getAdminClient();
    const companyId = await getCompanyIdForUser(api, req.user.id || req.user._id);
    const bandeRow = await getBandeOr404(api, companyId, req.params.id, res);
    if (!bandeRow) return undefined;
    const bande = mapBandeRow(bandeRow);

    const poids = bande.suiviJournalier
      .filter((s) => Number(s.poidsMotenG || 0) > 0)
      .map((s) => ({
        id: s._id,
        date: s.date,
        poidsMotenG: s.poidsMotenG,
        poidsMinG: s.poidsMinG != null ? s.poidsMinG : s.poidsMotenG,
        poidsMaxG: s.poidsMaxG != null ? s.poidsMaxG : s.poidsMotenG,
        poidsValeurs: Array.isArray(s.poidsValeurs) ? s.poidsValeurs : [],
        observations: s.observations || '',
      }))
      .sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());

    return res.json(poids);
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

router.delete('/:id/poids/:suiviId', requirePermission('bandes.poids.create'), async (req, res) => {
  try {
    const api = getAdminClient();
    const companyId = await getCompanyIdForUser(api, req.user.id || req.user._id);
    const bandeRow = await getBandeOr404(api, companyId, req.params.id, res);
    if (!bandeRow) return undefined;
    const bande = mapBandeRow(bandeRow);

    const index = bande.suiviJournalier.findIndex((s) => String(s._id) === req.params.suiviId);
    if (index < 0) return res.status(404).json({ message: 'Relevé de poids introuvable' });
    const entry = bande.suiviJournalier[index];
    if (!(Number(entry.poidsMotenG || 0) > 0)) {
      return res.status(400).json({ message: "Cette entrée ne contient pas de relevé de poids" });
    }

    // Entrée de pesée pure => supprimée ; si elle porte aussi alimentation/mortalité/climat, on n'efface que le poids.
    const purePoids = Number(entry.alimentationKg || 0) === 0
      && Number(entry.mortaliteJour || 0) === 0
      && Number(entry.eauLitres || 0) === 0
      && Number(entry.temperature || 0) === 0
      && Number(entry.humidite || 0) === 0;

    let suivis;
    if (purePoids) {
      suivis = bande.suiviJournalier.filter((_, i) => i !== index);
    } else {
      suivis = bande.suiviJournalier.map((s, i) => {
        if (i !== index) return s;
        const { poidsMinG, poidsMaxG, poidsValeurs, ...rest } = s;
        return { ...rest, poidsMotenG: 0 };
      });
    }

    const saved = await api
      .from('bandes')
      .update({ suivi_journalier: suivis, updated_at: new Date().toISOString() })
      .eq('company_id', companyId)
      .eq('id', bande._id)
      .select('*')
      .single();
    if (saved.error) return res.status(400).json({ message: saved.error.message });
    return res.json(mapBandeRow(saved.data));
  } catch (err) {
    return res.status(400).json({ message: err.message });
  }
});

router.post('/:id/climat', requirePermission('bandes.climat.create'), async (req, res) => {
  try {
    const api = getAdminClient();
    const companyId = await getCompanyIdForUser(api, req.user.id || req.user._id);
    const bandeRow = await getBandeOr404(api, companyId, req.params.id, res);
    if (!bandeRow) return undefined;
    const bande = mapBandeRow(bandeRow);

    const suivis = [...bande.suiviJournalier, {
      _id: crypto.randomUUID(),
      date: isoOrNow(req.body.date),
      poidsMotenG: 0,
      mortaliteJour: 0,
      alimentationKg: 0,
      eauLitres: 0,
      temperature: Number(req.body.temperature || 0),
      humidite: Number(req.body.humidite || 0),
      observations: req.body.observations || '',
    }];

    const saved = await api.from('bandes').update({ suivi_journalier: suivis, updated_at: new Date().toISOString() }).eq('company_id', companyId).eq('id', bande._id).select('*').single();
    if (saved.error) return res.status(400).json({ message: saved.error.message });
    return res.status(201).json(mapBandeRow(saved.data));
  } catch (err) {
    return res.status(400).json({ message: err.message });
  }
});

router.get('/:id/climat', requirePermission('bandes.read'), async (req, res) => {
  try {
    const api = getAdminClient();
    const companyId = await getCompanyIdForUser(api, req.user.id || req.user._id);
    const bandeRow = await getBandeOr404(api, companyId, req.params.id, res);
    if (!bandeRow) return undefined;
    const bande = mapBandeRow(bandeRow);

    const climat = bande.suiviJournalier
      .filter((s) => Number(s.temperature || 0) > 0 || Number(s.humidite || 0) > 0)
      .map((s) => ({ id: s._id, date: s.date, temperature: s.temperature || 0, humidite: s.humidite || 0, observations: s.observations || '' }))
      .sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());

    return res.json(climat);
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

router.get('/:id/suivis', requirePermission('bandes.read'), async (req, res) => {
  try {
    const api = getAdminClient();
    const companyId = await getCompanyIdForUser(api, req.user.id || req.user._id);
    const bandeRow = await getBandeOr404(api, companyId, req.params.id, res);
    if (!bandeRow) return undefined;
    return res.json(mapBandeRow(bandeRow).suiviJournalier);
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

router.post('/:id/sante', requirePermission('bandes.sante.create'), async (req, res) => {
  try {
    const api = getAdminClient();
    const companyId = await getCompanyIdForUser(api, req.user.id || req.user._id);
    const bandeRow = await getBandeOr404(api, companyId, req.params.id, res);
    if (!bandeRow) return undefined;
    const bande = mapBandeRow(bandeRow);

    const sante = [...bande.evenementsSante, {
      _id: crypto.randomUUID(),
      date: isoOrNow(req.body.date),
      type: req.body.type,
      description: req.body.description,
      medicament: req.body.medicament || '',
      doseParTete: req.body.doseParTete || '',
      dureeJours: Number(req.body.dureeJours || 1),
      cout: Number(req.body.cout || 0),
    }];

    const saved = await api.from('bandes').update({ evenements_sante: sante, updated_at: new Date().toISOString() }).eq('company_id', companyId).eq('id', bande._id).select('*').single();
    if (saved.error) return res.status(400).json({ message: saved.error.message });
    return res.status(201).json(mapBandeRow(saved.data));
  } catch (err) {
    return res.status(400).json({ message: err.message });
  }
});

router.get('/:id/sante', requirePermission('bandes.read'), async (req, res) => {
  try {
    const api = getAdminClient();
    const companyId = await getCompanyIdForUser(api, req.user.id || req.user._id);
    const bandeRow = await getBandeOr404(api, companyId, req.params.id, res);
    if (!bandeRow) return undefined;
    return res.json(mapBandeRow(bandeRow).evenementsSante);
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

router.get('/:id/evenements-previsionnels', requirePermission('bandes.read'), async (req, res) => {
  try {
    const api = getAdminClient();
    const companyId = await getCompanyIdForUser(api, req.user.id || req.user._id);
    const bandeRow = await getBandeOr404(api, companyId, req.params.id, res);
    if (!bandeRow) return undefined;
    const events = mapBandeRow(bandeRow).evenementsPrevisionnels.sort((a, b) => new Date(a.datePrevue).getTime() - new Date(b.datePrevue).getTime());
    return res.json(events);
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

router.post('/:id/evenements-previsionnels', requirePermission('bandes.events.manage'), async (req, res) => {
  try {
    if (!req.body.datePrevue || !req.body.description) {
      return res.status(400).json({ message: 'datePrevue et description sont obligatoires' });
    }

    const prophylaxieStockId = (req.body.prophylaxieStockId || '').toString().trim();
    const prophylaxieType = (req.body.prophylaxieType || '').toString().trim();
    const prophylaxieQuantite = Number(req.body.prophylaxieQuantite || 0);

    if (Number.isNaN(prophylaxieQuantite) || prophylaxieQuantite < 0) return res.status(400).json({ message: 'Quantité prophylaxie invalide' });
    if (prophylaxieStockId && prophylaxieQuantite <= 0) return res.status(400).json({ message: 'La quantité prophylaxie doit être supérieure à 0' });
    if (!prophylaxieStockId && prophylaxieQuantite > 0) return res.status(400).json({ message: 'Sélectionne un consommable prophylaxie avant de saisir la quantité' });

    const api = getAdminClient();
    const companyId = await getCompanyIdForUser(api, req.user.id || req.user._id);
    const bandeRow = await getBandeOr404(api, companyId, req.params.id, res);
    if (!bandeRow) return undefined;
    const bande = mapBandeRow(bandeRow);

    const events = [...bande.evenementsPrevisionnels, {
      _id: crypto.randomUUID(),
      type: req.body.type,
      datePrevue: isoOrNow(req.body.datePrevue),
      description: req.body.description,
      priorite: req.body.priorite || 'moyenne',
      commentaires: req.body.commentaires || '',
      prophylaxieStockId: prophylaxieStockId || null,
      prophylaxieType,
      prophylaxieQuantite: prophylaxieStockId ? prophylaxieQuantite : 0,
      statut: 'planifie',
    }];

    const saved = await api.from('bandes').update({ evenements_previsionnels: events, updated_at: new Date().toISOString() }).eq('company_id', companyId).eq('id', bande._id).select('*').single();
    if (saved.error) return res.status(400).json({ message: saved.error.message });
    return res.status(201).json(mapBandeRow(saved.data));
  } catch (err) {
    return res.status(400).json({ message: err.message });
  }
});

router.put('/:id/evenements-previsionnels/:eventId/terminer', requirePermission('bandes.events.manage'), async (req, res) => {
  try {
    const api = getAdminClient();
    const companyId = await getCompanyIdForUser(api, req.user.id || req.user._id);
    const bandeRow = await getBandeOr404(api, companyId, req.params.id, res);
    if (!bandeRow) return undefined;
    const bande = mapBandeRow(bandeRow);

    const events = [...bande.evenementsPrevisionnels];
    const idx = events.findIndex((e) => String(e._id) === String(req.params.eventId));
    if (idx === -1) return res.status(404).json({ message: 'Événement non trouvé dans cette bande' });
    if (events[idx].statut === 'termine') return res.status(400).json({ message: 'Cet événement est déjà marqué comme terminé' });

    const consommationStockId = (req.body.prophylaxieStockId || events[idx].prophylaxieStockId || '').toString().trim();
    const consommationType = (req.body.prophylaxieType || events[idx].prophylaxieType || '').toString().trim();
    const consommationQuantite = Number(req.body.prophylaxieQuantite ?? events[idx].prophylaxieQuantite ?? 0);

    if (Number.isNaN(consommationQuantite) || consommationQuantite < 0) return res.status(400).json({ message: 'Quantité prophylaxie invalide' });
    if (consommationStockId && consommationQuantite <= 0) return res.status(400).json({ message: 'La quantité prophylaxie doit être supérieure à 0' });
    if (!consommationStockId && consommationQuantite > 0) return res.status(400).json({ message: 'Sélectionne un consommable prophylaxie avant de saisir la quantité' });

    if (consommationStockId && consommationQuantite > 0) {
      const stockRes = await api.from('stocks').select('*').eq('company_id', companyId).eq('id', consommationStockId).maybeSingle();
      if (stockRes.error) return res.status(400).json({ message: stockRes.error.message });
      if (!stockRes.data) return res.status(404).json({ message: 'Consommable prophylaxie non trouvé en stock' });
      if (['aliment', 'materiel'].includes(stockRes.data.categorie)) {
        return res.status(400).json({ message: 'Le consommable prophylaxie doit être un produit consommable hors aliment/matériel' });
      }
      if (Number(stockRes.data.quantite_actuelle || 0) < consommationQuantite) {
        return res.status(400).json({ message: 'Stock insuffisant pour le consommable prophylaxie sélectionné' });
      }

      const dateRealisation = isoOrNow(req.body.dateRealisation);
      const mouvements = toArray(stockRes.data.mouvements);
      mouvements.push({
        _id: crypto.randomUUID(),
        date: dateRealisation,
        type: 'sortie',
        quantite: consommationQuantite,
        utilisateur: getUserLabel(req),
        bandeId: bande._id,
        motif: `Consommable prophylaxie - tâche réalisée (${events[idx].description})`,
        coutUnitaire: Number(stockRes.data.prix_unitaire || 0),
      });

      const saveStock = await api
        .from('stocks')
        .update({
          quantite_actuelle: Number(stockRes.data.quantite_actuelle || 0) - consommationQuantite,
          mouvements,
          updated_at: new Date().toISOString(),
        })
        .eq('company_id', companyId)
        .eq('id', stockRes.data.id);
      if (saveStock.error) return res.status(400).json({ message: saveStock.error.message });

      events[idx].prophylaxieStockId = consommationStockId;
      events[idx].prophylaxieType = consommationType || stockRes.data.nom;
      events[idx].prophylaxieQuantite = consommationQuantite;
    }

    events[idx].statut = 'termine';
    events[idx].dateRealisation = isoOrNow(req.body.dateRealisation);
    events[idx].commentairesRealisation = req.body.commentairesRealisation || '';

    const saved = await api.from('bandes').update({ evenements_previsionnels: events, updated_at: new Date().toISOString() }).eq('company_id', companyId).eq('id', bande._id).select('*').single();
    if (saved.error) return res.status(400).json({ message: saved.error.message });
    return res.json(mapBandeRow(saved.data));
  } catch (err) {
    return res.status(400).json({ message: err.message });
  }
});

router.delete('/:id', requireRole('admin'), requirePermission('bandes.delete'), async (req, res) => {
  try {
    const api = getAdminClient();
    const companyId = await getCompanyIdForUser(api, req.user.id || req.user._id);
    const row = await getBandeOr404(api, companyId, req.params.id, res);
    if (!row) return undefined;
    if ((row.statut || 'ouverte') !== 'fermee') {
      return res.status(400).json({ message: 'Seules les bandes fermées peuvent être supprimées' });
    }

    const deleted = await api.from('bandes').delete().eq('company_id', companyId).eq('id', req.params.id);
    if (deleted.error) return res.status(500).json({ message: deleted.error.message });
    return res.json({ message: 'Bande supprimée' });
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

module.exports = router;
