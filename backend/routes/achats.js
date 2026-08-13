const express = require('express');
const crypto = require('crypto');
const { getAdminClient } = require('../services/supabase');
const { getCompanyIdForUser } = require('../services/company_scope');
const { requirePermission, requireAdmin } = require('../middleware/auth');

const router = express.Router();

function getUserName(req) {
  const prenom = (req.user?.prenom || '').trim();
  const nom = (req.user?.nom || '').trim();
  return { quiNom: nom || prenom || 'Utilisateur', quiPrenom: prenom || nom || 'Utilisateur' };
}

function mapRow(row) {
  return {
    _id: row.id,
    titre: row.titre || '',
    article: row.article || '',
    categorie: row.categorie || 'autre',
    quantite: Number(row.quantite || 0),
    unite: row.unite || 'unité',
    fournisseur: row.fournisseur || '',
    prixUnitaireEstime: Number(row.prix_unitaire_estime || 0),
    montantEstime: Number(row.montant_estime || 0),
    urgence: row.urgence || 'normale',
    motif: row.motif || '',
    statut: row.statut || 'en_attente',
    demandeurNom: row.demandeur_nom || '',
    demandeurPrenom: row.demandeur_prenom || '',
    validateurNom: row.validateur_nom || '',
    validateurPrenom: row.validateur_prenom || '',
    notesValidation: row.notes_validation || '',
    stockId: row.stock_id || null,
    dateDemande: row.date_demande || row.created_at,
    dateValidation: row.date_validation || null,
    dateReception: row.date_reception || null,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

// Liste toutes les demandes d'achat
router.get('/', requirePermission('achats.read'), async (req, res) => {
  try {
    const client = getAdminClient();
    const companyId = await getCompanyIdForUser(client, req.user.id || req.user._id);
    let query = client.from('achats').select('*').eq('company_id', companyId).order('created_at', { ascending: false });
    if (req.query.statut) query = query.eq('statut', req.query.statut);
    const { data, error } = await query;
    if (error) return res.status(500).json({ message: error.message });
    return res.json((data || []).map(mapRow));
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

// Détail d'une demande
router.get('/:id', requirePermission('achats.read'), async (req, res) => {
  try {
    const client = getAdminClient();
    const companyId = await getCompanyIdForUser(client, req.user.id || req.user._id);
    const { data, error } = await client.from('achats').select('*').eq('company_id', companyId).eq('id', req.params.id).maybeSingle();
    if (error) return res.status(500).json({ message: error.message });
    if (!data) return res.status(404).json({ message: 'Demande non trouvée' });
    return res.json(mapRow(data));
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

// Créer une demande d'achat
router.post('/', requirePermission('achats.request'), async (req, res) => {
  try {
    const titre = (req.body.titre || '').trim();
    const article = (req.body.article || '').trim();
    const quantite = Number(req.body.quantite || 0);
    if (!titre || !article || quantite <= 0) {
      return res.status(400).json({ message: 'Titre, article et quantité (> 0) sont obligatoires' });
    }

    const client = getAdminClient();
    const companyId = await getCompanyIdForUser(client, req.user.id || req.user._id);
    const { quiNom, quiPrenom } = getUserName(req);
    const prixUnitaire = Number(req.body.prixUnitaireEstime || 0);

    const { data, error } = await client.from('achats').insert({
      company_id: companyId,
      titre,
      article,
      categorie: req.body.categorie || 'autre',
      quantite,
      unite: req.body.unite || 'unité',
      fournisseur: req.body.fournisseur || '',
      prix_unitaire_estime: prixUnitaire,
      montant_estime: quantite * prixUnitaire,
      urgence: req.body.urgence || 'normale',
      motif: req.body.motif || '',
      statut: 'en_attente',
      demandeur_nom: quiNom,
      demandeur_prenom: quiPrenom,
      stock_id: req.body.stockId || null,
      date_demande: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    }).select('*').single();

    if (error) return res.status(400).json({ message: error.message });
    return res.status(201).json(mapRow(data));
  } catch (err) {
    return res.status(400).json({ message: err.message });
  }
});

// Modifier une demande (seulement si en_attente)
router.put('/:id', requirePermission('achats.request'), async (req, res) => {
  try {
    const client = getAdminClient();
    const companyId = await getCompanyIdForUser(client, req.user.id || req.user._id);

    const current = await client.from('achats').select('*').eq('company_id', companyId).eq('id', req.params.id).maybeSingle();
    if (current.error) return res.status(500).json({ message: current.error.message });
    if (!current.data) return res.status(404).json({ message: 'Demande non trouvée' });
    if (current.data.statut !== 'en_attente') {
      return res.status(400).json({ message: 'Seules les demandes en attente peuvent être modifiées' });
    }

    const quantite = Number(req.body.quantite ?? current.data.quantite);
    const prixUnitaire = Number(req.body.prixUnitaireEstime ?? current.data.prix_unitaire_estime);

    const { data, error } = await client.from('achats').update({
      titre: (req.body.titre || current.data.titre).trim(),
      article: (req.body.article || current.data.article).trim(),
      categorie: req.body.categorie || current.data.categorie,
      quantite,
      unite: req.body.unite || current.data.unite,
      fournisseur: req.body.fournisseur ?? current.data.fournisseur,
      prix_unitaire_estime: prixUnitaire,
      montant_estime: quantite * prixUnitaire,
      urgence: req.body.urgence || current.data.urgence,
      motif: req.body.motif ?? current.data.motif,
      stock_id: req.body.stockId !== undefined ? (req.body.stockId || null) : current.data.stock_id,
      updated_at: new Date().toISOString(),
    }).eq('company_id', companyId).eq('id', req.params.id).select('*').single();

    if (error) return res.status(400).json({ message: error.message });
    return res.json(mapRow(data));
  } catch (err) {
    return res.status(400).json({ message: err.message });
  }
});

// Valider une demande
router.put('/:id/valider', requirePermission('achats.validate'), async (req, res) => {
  try {
    const client = getAdminClient();
    const companyId = await getCompanyIdForUser(client, req.user.id || req.user._id);
    const { quiNom, quiPrenom } = getUserName(req);

    const current = await client.from('achats').select('statut').eq('company_id', companyId).eq('id', req.params.id).maybeSingle();
    if (current.error) return res.status(500).json({ message: current.error.message });
    if (!current.data) return res.status(404).json({ message: 'Demande non trouvée' });
    if (current.data.statut !== 'en_attente') {
      return res.status(400).json({ message: 'Seules les demandes en attente peuvent être validées' });
    }

    const { data, error } = await client.from('achats').update({
      statut: 'valide',
      validateur_nom: quiNom,
      validateur_prenom: quiPrenom,
      notes_validation: req.body.notes || '',
      date_validation: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    }).eq('company_id', companyId).eq('id', req.params.id).select('*').single();

    if (error) return res.status(400).json({ message: error.message });
    return res.json(mapRow(data));
  } catch (err) {
    return res.status(400).json({ message: err.message });
  }
});

// Refuser une demande
router.put('/:id/refuser', requirePermission('achats.validate'), async (req, res) => {
  try {
    const client = getAdminClient();
    const companyId = await getCompanyIdForUser(client, req.user.id || req.user._id);
    const { quiNom, quiPrenom } = getUserName(req);

    const current = await client.from('achats').select('statut').eq('company_id', companyId).eq('id', req.params.id).maybeSingle();
    if (current.error) return res.status(500).json({ message: current.error.message });
    if (!current.data) return res.status(404).json({ message: 'Demande non trouvée' });
    if (current.data.statut !== 'en_attente') {
      return res.status(400).json({ message: 'Seules les demandes en attente peuvent être refusées' });
    }

    const { data, error } = await client.from('achats').update({
      statut: 'refuse',
      validateur_nom: quiNom,
      validateur_prenom: quiPrenom,
      notes_validation: req.body.notes || '',
      date_validation: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    }).eq('company_id', companyId).eq('id', req.params.id).select('*').single();

    if (error) return res.status(400).json({ message: error.message });
    return res.json(mapRow(data));
  } catch (err) {
    return res.status(400).json({ message: err.message });
  }
});

// Marquer reçu → entrée stock + sortie trésorerie
router.put('/:id/recevoir', requirePermission('achats.validate'), async (req, res) => {
  try {
    const client = getAdminClient();
    const companyId = await getCompanyIdForUser(client, req.user.id || req.user._id);
    const { quiNom, quiPrenom } = getUserName(req);

    const current = await client.from('achats').select('*').eq('company_id', companyId).eq('id', req.params.id).maybeSingle();
    if (current.error) return res.status(500).json({ message: current.error.message });
    if (!current.data) return res.status(404).json({ message: 'Demande non trouvée' });
    if (!['valide', 'en_attente'].includes(current.data.statut)) {
      return res.status(400).json({ message: 'Seules les demandes validées ou en attente peuvent être marquées reçues' });
    }

    const quantiteRecue = Number(req.body.quantiteRecue || current.data.quantite || 0);
    const prixReel = Number(req.body.prixUnitaireReel || current.data.prix_unitaire_estime || 0);
    const montantReel = quantiteRecue * prixReel;

    const { data, error } = await client.from('achats').update({
      statut: 'recu',
      validateur_nom: current.data.validateur_nom || quiNom,
      validateur_prenom: current.data.validateur_prenom || quiPrenom,
      notes_validation: req.body.notes || current.data.notes_validation || '',
      date_reception: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    }).eq('company_id', companyId).eq('id', req.params.id).select('*').single();

    if (error) return res.status(400).json({ message: error.message });

    // Entrée stock + sortie trésorerie si un stock est lié
    const stockId = current.data.stock_id;
    if (stockId && quantiteRecue > 0) {
      const stockRes = await client.from('stocks').select('*').eq('company_id', companyId).eq('id', stockId).maybeSingle();
      if (stockRes.data) {
        const mouvements = Array.isArray(stockRes.data.mouvements) ? [...stockRes.data.mouvements] : [];
        mouvements.push({
          _id: crypto.randomUUID(),
          date: new Date().toISOString(),
          type: 'entree',
          quantite: quantiteRecue,
          utilisateur: `${quiPrenom} ${quiNom}`.trim(),
          motif: `Réception achat - ${current.data.titre}`,
          fournisseur: current.data.fournisseur || '',
          coutUnitaire: prixReel,
        });
        await client.from('stocks').update({
          quantite_actuelle: Number(stockRes.data.quantite_actuelle || 0) + quantiteRecue,
          mouvements,
          ...(prixReel > 0 ? { prix_unitaire: prixReel } : {}),
          updated_at: new Date().toISOString(),
        }).eq('company_id', companyId).eq('id', stockId);

        if (montantReel > 0) {
          await client.from('tresorerie_mouvements').insert({
            company_id: companyId,
            nature: 'sortie',
            source: 'stock_entree',
            qui_nom: quiNom,
            qui_prenom: quiPrenom,
            categorie: stockRes.data.categorie || current.data.categorie,
            type: current.data.article || stockRes.data.nom,
            montant: montantReel,
            date_mouvement: new Date().toISOString(),
            commentaire: `Achat reçu - ${current.data.titre}`,
            reference_type: 'Achat',
            reference_id: req.params.id,
            externe_cle: `achat:${req.params.id}:reception`,
          });
        }
      }
    }

    return res.json(mapRow(data));
  } catch (err) {
    return res.status(400).json({ message: err.message });
  }
});

// Supprimer (admin seulement)
router.delete('/:id', requireAdmin, async (req, res) => {
  try {
    const client = getAdminClient();
    const companyId = await getCompanyIdForUser(client, req.user.id || req.user._id);
    const { error } = await client.from('achats').delete().eq('company_id', companyId).eq('id', req.params.id);
    if (error) return res.status(500).json({ message: error.message });
    return res.json({ message: 'Demande supprimée' });
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

module.exports = router;
