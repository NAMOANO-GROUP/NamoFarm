// Budgets mensuels par poste de dépense (table finance_budgets).

// Plafond de la colonne numeric(14,2).
const MONTANT_MAX = 999999999999.99;

/**
 * Nettoie les budgets envoyés par l'application : { "Alimentation": 500000, ... } ou
 * [{ poste, montantMensuel }]. Ignore les postes vides, les montants négatifs ou invalides.
 */
function normalizeBudgets(input) {
  const entries = Array.isArray(input)
    ? input.map((b) => [b?.poste, b?.montantMensuel])
    : Object.entries(input && typeof input === 'object' ? input : {});
  const out = new Map();
  for (const [poste, montant] of entries) {
    const key = (poste || '').toString().trim().slice(0, 80);
    const value = Number(montant);
    if (!key || !Number.isFinite(value) || value < 0) continue;
    out.set(key, Math.min(Math.round(value * 100) / 100, MONTANT_MAX));
  }
  return [...out.entries()].map(([poste, montantMensuel]) => ({ poste, montantMensuel }));
}

/** Vrai si l'erreur Supabase indique que la table n'existe pas encore (migration non faite). */
function isMissingTableError(error) {
  const message = (error?.message || '').toString().toLowerCase();
  return error?.code === '42P01' || error?.code === 'PGRST205'
    || (message.includes('finance_budgets') && (message.includes('does not exist') || message.includes('could not find')));
}

module.exports = { normalizeBudgets, isMissingTableError, MONTANT_MAX };
