const express = require('express');
const crypto = require('crypto');
const { authenticate, requireSuperadmin } = require('../middleware/auth');
const { getAdminClient, logAudit } = require('../services/supabase');

const router = express.Router();

// Toutes les routes de gestion des codes sont réservées au super-administrateur.
router.use(authenticate, requireSuperadmin);

// Génère un code lisible du type "NAMO-4F7K-9QXZ" (sans caractères ambigus).
function generateReadableCode() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // sans I, O, 0, 1
  const pick = (n) => {
    let out = '';
    const bytes = crypto.randomBytes(n);
    for (let i = 0; i < n; i += 1) {
      out += alphabet[bytes[i] % alphabet.length];
    }
    return out;
  };
  return `NAMO-${pick(4)}-${pick(4)}`;
}

// Liste tous les codes (les plus récents d'abord).
router.get('/', async (req, res) => {
  try {
    const client = getAdminClient();
    const { data, error } = await client
      .from('onboarding_codes')
      .select('*')
      .order('created_at', { ascending: false });
    if (error) return res.status(400).json({ message: error.message });
    return res.json(data || []);
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

// Génère un nouveau code à usage unique.
// Body optionnel : { label?: string, expiresInDays?: number }
router.post('/', async (req, res) => {
  try {
    const client = getAdminClient();

    const label = (req.body.label || '').trim() || null;
    const expiresInDays = Number(req.body.expiresInDays);
    const expiresAt = Number.isFinite(expiresInDays) && expiresInDays > 0
      ? new Date(Date.now() + expiresInDays * 24 * 60 * 60 * 1000).toISOString()
      : null;

    // Génère un code unique (réessaie en cas de collision improbable).
    let inserted = null;
    for (let attempt = 0; attempt < 5; attempt += 1) {
      const code = generateReadableCode();
      const result = await client
        .from('onboarding_codes')
        .insert({ code, label, expires_at: expiresAt })
        .select('*')
        .single();
      if (!result.error) {
        inserted = result.data;
        break;
      }
      // 23505 = violation de contrainte d'unicité → on retente avec un autre code.
      const isDuplicate = (result.error.message || '').toLowerCase().includes('duplicate');
      if (!isDuplicate) {
        return res.status(400).json({ message: result.error.message });
      }
    }

    if (!inserted) {
      return res.status(500).json({ message: 'Impossible de générer un code unique. Réessaie.' });
    }

    await logAudit(client, {
      userId: req.user.id || req.user._id,
      userEmail: req.user.email,
      action: 'onboarding_code.create',
      targetType: 'OnboardingCode',
      targetId: inserted.id,
      metadata: { code: inserted.code, label },
      ip: '',
    });

    return res.status(201).json(inserted);
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

// Supprime (révoque) un code. Utile pour retirer un code non encore utilisé.
router.delete('/:id', async (req, res) => {
  try {
    const client = getAdminClient();
    const { id } = req.params;

    const { data: existing } = await client
      .from('onboarding_codes')
      .select('*')
      .eq('id', id)
      .maybeSingle();
    if (!existing) return res.status(404).json({ message: 'Code introuvable' });

    const { error } = await client.from('onboarding_codes').delete().eq('id', id);
    if (error) return res.status(400).json({ message: error.message });

    await logAudit(client, {
      userId: req.user.id || req.user._id,
      userEmail: req.user.email,
      action: 'onboarding_code.delete',
      targetType: 'OnboardingCode',
      targetId: id,
      metadata: { code: existing.code },
      ip: '',
    });

    return res.json({ message: 'Code supprimé' });
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

module.exports = router;
