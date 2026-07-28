const express = require('express');
const { getAdminClient } = require('../services/supabase');
const { getCompanyIdForUser } = require('../services/company_scope');

const router = express.Router();

function toArray(v) {
  return Array.isArray(v) ? v : [];
}

function round(v, d = 1) {
  if (v == null || Number.isNaN(v)) return null;
  const f = Math.pow(10, d);
  return Math.round(v * f) / f;
}

function daysBetween(a, b) {
  return Math.floor((b.getTime() - a.getTime()) / (1000 * 60 * 60 * 24));
}

// Simple least-squares linear regression on [{x, y}] points.
function linreg(points) {
  const n = points.length;
  if (n < 2) return null;
  let sx = 0, sy = 0, sxy = 0, sxx = 0;
  for (const p of points) {
    sx += p.x; sy += p.y; sxy += p.x * p.y; sxx += p.x * p.x;
  }
  const denom = n * sxx - sx * sx;
  if (denom === 0) return null;
  const slope = (n * sxy - sx * sy) / denom;
  const intercept = (sy - slope * sx) / n;
  return { slope, intercept };
}

async function safeSelect(api, table, columns, companyId) {
  const res = await api.from(table).select(columns).eq('company_id', companyId);
  if (res.error) {
    const msg = (res.error.message || '').toString().toLowerCase();
    if (msg.includes(table) && (msg.includes('does not exist') || msg.includes('could not find') || msg.includes('schema cache') || msg.includes('relation'))) {
      return [];
    }
    throw new Error(res.error.message);
  }
  return res.data || [];
}

router.get('/', async (req, res) => {
  try {
    const api = getAdminClient();
    const companyId = await getCompanyIdForUser(api, req.user.id || req.user._id);

    const bandesRaw = await safeSelect(
      api,
      'bandes',
      'id,nom,statut,type_volaille,date_ouverture,created_at,objectif_poids_g,nombre_initial,mortalite_totale,suivi_journalier',
      companyId,
    );
    const cheptelsRaw = await safeSelect(api, 'cheptels', 'id,nom,espece,effectif_actuel,mouvements', companyId);

    const now = new Date();

    const bandes = bandesRaw
      .filter((b) => (b.statut || 'ouverte') === 'ouverte')
      .map((b) => {
        const ouverture = new Date(b.date_ouverture || b.created_at || now);
        const suivi = toArray(b.suivi_journalier);
        const points = [];
        for (const s of suivi) {
          const w = Number(s.poidsMotenG || s.poidsMoyenG || 0);
          if (w <= 0) continue;
          const d = new Date(s.date);
          if (Number.isNaN(d.getTime())) continue;
          const age = daysBetween(ouverture, d);
          if (age < 0) continue;
          points.push({ x: age, y: w });
        }
        const reg = linreg(points);
        const ageActuel = Math.max(0, daysBetween(ouverture, now));
        const objectif = Number(b.objectif_poids_g || 0);
        const lastW = points.length ? points[points.length - 1].y : 0;

        let gainJour = null;
        let poidsEstimeActuel = lastW || null;
        let poidsProjete7j = null;
        let joursAvantObjectif = null;
        let dateAbattageEstimee = null;

        if (reg && reg.slope > 0) {
          gainJour = reg.slope;
          poidsEstimeActuel = reg.intercept + reg.slope * ageActuel;
          poidsProjete7j = poidsEstimeActuel + reg.slope * 7;
          const base = Math.max(poidsEstimeActuel, lastW);
          if (objectif > base) {
            joursAvantObjectif = Math.ceil((objectif - base) / reg.slope);
            const dd = new Date(now);
            dd.setDate(dd.getDate() + joursAvantObjectif);
            dateAbattageEstimee = dd.toISOString();
          } else if (objectif > 0) {
            joursAvantObjectif = 0;
            dateAbattageEstimee = now.toISOString();
          }
        }

        const nombreInitial = Number(b.nombre_initial || 0);
        const mort = Number(b.mortalite_totale || 0);
        const tauxMortActuel = nombreInitial > 0 ? (mort / nombreInitial) * 100 : 0;
        let tauxMortProjete = tauxMortActuel;
        if (ageActuel > 0 && joursAvantObjectif != null && nombreInitial > 0) {
          const dailyMort = mort / ageActuel;
          const finalAge = ageActuel + joursAvantObjectif;
          tauxMortProjete = ((dailyMort * finalAge) / nombreInitial) * 100;
        }

        return {
          bandeId: b.id,
          nom: b.nom || '',
          typeVolaille: b.type_volaille || '',
          ageActuel,
          nbPointsPoids: points.length,
          poidsMesure: lastW,
          objectifPoidsG: objectif,
          gainMoyenParJour: round(gainJour),
          poidsEstimeActuel: round(poidsEstimeActuel),
          poidsProjete7j: round(poidsProjete7j),
          joursAvantObjectif,
          dateAbattageEstimee,
          tauxMortaliteActuel: round(tauxMortActuel, 2),
          tauxMortaliteProjete: round(tauxMortProjete, 2),
        };
      });

    const cheptels = cheptelsRaw.map((c) => {
      const mvts = toArray(c.mouvements)
        .slice()
        .sort((a, b) => new Date(a.date || 0).getTime() - new Date(b.date || 0).getTime());
      const effectifActuel = Number(c.effectif_actuel || 0);
      if (mvts.length < 2) {
        return { cheptelId: c.id, nom: c.nom || '', espece: c.espece || '', effectifActuel, tendanceParJour: null, effectifProjete30j: null };
      }
      const first = new Date(mvts[0].date);
      let eff = 0;
      const points = [];
      for (const m of mvts) {
        const q = Number(m.quantite || 0);
        if (m.type === 'ajustement') eff = q;
        else if (m.type === 'naissance' || m.type === 'entree') eff += q;
        else eff -= q;
        const d = new Date(m.date);
        if (Number.isNaN(d.getTime())) continue;
        points.push({ x: daysBetween(first, d), y: eff });
      }
      const reg = linreg(points);
      let tendance = null;
      let proj = null;
      if (reg) {
        tendance = reg.slope;
        proj = Math.max(0, Math.round(effectifActuel + reg.slope * 30));
      }
      return {
        cheptelId: c.id,
        nom: c.nom || '',
        espece: c.espece || '',
        effectifActuel,
        tendanceParJour: round(tendance, 2),
        effectifProjete30j: proj,
      };
    });

    return res.json({ bandes, cheptels });
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

module.exports = router;
