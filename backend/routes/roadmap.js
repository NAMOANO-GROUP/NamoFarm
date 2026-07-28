const express = require('express');
const { getAdminClient } = require('../services/supabase');
const { getCompanyIdForUser } = require('../services/company_scope');

const router = express.Router();

// Detect the case where the roadmap_plans table has not been created yet, so the
// mobile app can gracefully fall back to its local cache instead of erroring.
function isMissingTableError(error) {
  const msg = (error?.message || '').toString().toLowerCase();
  return msg.includes('roadmap_plans')
    && (msg.includes('does not exist') || msg.includes('could not find') || msg.includes('schema cache') || msg.includes('relation'));
}

function normalizePlans(value) {
  return Array.isArray(value) ? value : [];
}

router.get('/', async (req, res) => {
  try {
    const client = getAdminClient();
    const companyId = await getCompanyIdForUser(client, req.user.id || req.user._id);

    const result = await client
      .from('roadmap_plans')
      .select('*')
      .eq('company_id', companyId)
      .maybeSingle();

    if (result.error) {
      if (isMissingTableError(result.error)) {
        return res.json({ plans: [], selectedPlanId: null, storage: 'unavailable' });
      }
      return res.status(500).json({ message: result.error.message });
    }

    const row = result.data;
    return res.json({
      plans: normalizePlans(row?.data),
      selectedPlanId: row?.selected_plan_id || null,
      updatedAt: row?.updated_at || null,
    });
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

router.put('/', async (req, res) => {
  try {
    const client = getAdminClient();
    const companyId = await getCompanyIdForUser(client, req.user.id || req.user._id);

    const plans = normalizePlans(req.body.plans);
    const selectedPlanId = req.body.selectedPlanId != null && req.body.selectedPlanId !== ''
      ? String(req.body.selectedPlanId)
      : null;

    const payload = {
      company_id: companyId,
      data: plans,
      selected_plan_id: selectedPlanId,
      updated_at: new Date().toISOString(),
    };

    const saved = await client
      .from('roadmap_plans')
      .upsert(payload, { onConflict: 'company_id' })
      .select('*')
      .single();

    if (saved.error) {
      if (isMissingTableError(saved.error)) {
        return res.status(503).json({
          message: "Table 'roadmap_plans' absente. Executez la migration SQL add_roadmap_plans_table.sql dans Supabase.",
        });
      }
      return res.status(400).json({ message: saved.error.message });
    }

    return res.json({
      plans: normalizePlans(saved.data?.data),
      selectedPlanId: saved.data?.selected_plan_id || null,
      updatedAt: saved.data?.updated_at || null,
    });
  } catch (err) {
    return res.status(400).json({ message: err.message });
  }
});

module.exports = router;
