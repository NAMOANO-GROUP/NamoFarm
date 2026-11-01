// Utilitaires partagés par les tâches (Todo /alertes et relances CRM).

/** Nettoie une checklist reçue de l'application : [{ titre, fait }], 30 éléments max. */
function normalizeChecklist(value) {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => ({
      titre: (item?.titre || '').toString().trim(),
      fait: item?.fait === true,
    }))
    .filter((item) => item.titre)
    .slice(0, 30);
}

function isMissingColumnError(error, column) {
  const message = (error?.message || '').toString();
  return message.includes(`'${column}'`) && /column/i.test(message);
}

/**
 * Exécute une écriture Supabase ; si une colonne optionnelle (pas encore migrée) est absente,
 * la retire du payload et réessaie, pour que l'application fonctionne avant la migration.
 */
async function writeWithOptionalColumns(run, payload, optionalColumns = []) {
  let current = { ...payload };
  let result = await run(current);
  for (let attempt = 0; attempt < optionalColumns.length && result.error; attempt += 1) {
    const missing = optionalColumns.find((c) => c in current && isMissingColumnError(result.error, c));
    if (!missing) break;
    const { [missing]: _ignored, ...rest } = current;
    current = rest;
    result = await run(current);
  }
  return result;
}

function clampDay(year, monthIndex, day) {
  const last = new Date(year, monthIndex + 1, 0).getDate();
  return Math.min(day, last);
}

/**
 * Prochaine échéance d'une tâche périodique.
 * config: { joursSemaine:[1..7] } (hebdo), { jourMois:1..31 } (mensuel), { mois:1..12, jourMois:1..31 } (annuel).
 */
function nextEcheance(dateIso, recurrence, config = {}) {
  const d = new Date(dateIso);
  if (Number.isNaN(d.getTime())) return null;
  const cfg = config && typeof config === 'object' ? config : {};
  switch ((recurrence || '').toString().toLowerCase()) {
    case 'quotidien':
      d.setDate(d.getDate() + 1);
      return d;
    case 'hebdomadaire': {
      const jours = Array.isArray(cfg.joursSemaine)
        ? cfg.joursSemaine.map(Number).filter((n) => n >= 1 && n <= 7)
        : [];
      if (jours.length === 0) {
        d.setDate(d.getDate() + 7);
        return d;
      }
      // Cherche le prochain jour de la semaine coché (ISO: 1=lundi..7=dimanche).
      for (let i = 1; i <= 7; i += 1) {
        const cand = new Date(d);
        cand.setDate(d.getDate() + i);
        const iso = ((cand.getDay() + 6) % 7) + 1;
        if (jours.includes(iso)) return cand;
      }
      d.setDate(d.getDate() + 7);
      return d;
    }
    case 'bihebdomadaire':
      d.setDate(d.getDate() + 14);
      return d;
    case 'mensuel': {
      const year = d.getFullYear();
      const month = d.getMonth() + 1;
      const jour = Number(cfg.jourMois) >= 1 && Number(cfg.jourMois) <= 31 ? Number(cfg.jourMois) : d.getDate();
      return new Date(year, month, clampDay(year, month, jour), d.getHours(), d.getMinutes());
    }
    case 'annuel': {
      const year = d.getFullYear() + 1;
      const monthIndex = Number(cfg.mois) >= 1 && Number(cfg.mois) <= 12 ? Number(cfg.mois) - 1 : d.getMonth();
      const jour = Number(cfg.jourMois) >= 1 && Number(cfg.jourMois) <= 31 ? Number(cfg.jourMois) : d.getDate();
      return new Date(year, monthIndex, clampDay(year, monthIndex, jour), d.getHours(), d.getMinutes());
    }
    default:
      return null;
  }
}

/** Checklist de la prochaine occurrence d'une tâche périodique : mêmes étapes, toutes à refaire. */
function resetChecklist(value) {
  return normalizeChecklist(value).map((item) => ({ ...item, fait: false }));
}

module.exports = {
  normalizeChecklist,
  resetChecklist,
  isMissingColumnError,
  writeWithOptionalColumns,
  nextEcheance,
};
