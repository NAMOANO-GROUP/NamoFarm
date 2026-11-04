// Sortie des animaux vendus de l'effectif d'une bande (commande payée liée à une bande).

const ACTION_EFFECTIF = 'effectif_bande_deduit';

function toArray(v) {
  return Array.isArray(v) ? v : [];
}

/** Nombre d'animaux vendus : somme des quantités des lignes (entiers positifs). */
function quantiteAnimaux(produits) {
  return toArray(produits).reduce((s, p) => {
    const q = Math.floor(Number(p?.quantite ?? p?.qte ?? 0));
    return s + (Number.isFinite(q) && q > 0 ? q : 0);
  }, 0);
}

/** Vrai si la sortie de cette commande a déjà été retirée de la bande. */
function effectifDejaDeduit(historique) {
  return toArray(historique).some((h) => h && h.action === ACTION_EFFECTIF);
}

/** Sujets déjà retirés de la bande pour cette commande (somme des sorties et corrections tracées). */
function quantiteDeduite(historique) {
  return toArray(historique)
    .filter((h) => h && h.action === ACTION_EFFECTIF)
    .reduce((s, h) => s + (Number(h.quantite) || 0), 0);
}

function bandeIdDe(row) {
  const id = row?.bande_id || row?.bandeId || '';
  return id ? String(id) : '';
}

/** Commande à retirer de sa bande : liée à une bande, avec des animaux, pas encore retirée. */
function aDeduire(row) {
  return Boolean(bandeIdDe(row)) && quantiteAnimaux(row?.produits) > 0 && !effectifDejaDeduit(row?.historique_actions);
}

/** Entrée d'historique qui trace la sortie (sert aussi de garde contre un double retrait). */
function entreeHistorique(quantite, bandeNom, auteur) {
  return {
    action: ACTION_EFFECTIF,
    auteur: auteur || 'Système',
    details: `${quantite} sujet(s) retiré(s) de l'effectif${bandeNom ? ` de la bande ${bandeNom}` : ''}`,
    quantite,
    date: new Date().toISOString(),
  };
}

/**
 * Retire [quantite] animaux de l'effectif de la bande (une quantité négative les rend).
 * Refuse de retirer plus que l'effectif présent : c'est presque toujours une erreur de saisie
 * (prix saisi à la place de la quantité) qui viderait la bande.
 * Renvoie { ok, bandeNom, retire } ; ok = false si la bande est introuvable ou l'effectif insuffisant.
 */
async function retirerDeLaBande(api, companyId, bandeId, quantite) {
  const bande = await api
    .from('bandes')
    .select('id,nom,nombre_actuel')
    .eq('company_id', companyId)
    .eq('id', bandeId)
    .maybeSingle();
  if (bande.error) return { ok: false, error: bande.error.message };
  if (!bande.data) return { ok: false, error: 'Bande introuvable' };
  const actuel = Number(bande.data.nombre_actuel || 0);
  if (quantite > actuel) {
    return {
      ok: false,
      insuffisant: true,
      bandeNom: bande.data.nom || '',
      error: `Quantité (${quantite}) supérieure à l'effectif de la bande ${bande.data.nom || ''} (${actuel})`,
    };
  }
  const nouveau = actuel - quantite;
  const saved = await api
    .from('bandes')
    .update({ nombre_actuel: nouveau, updated_at: new Date().toISOString() })
    .eq('company_id', companyId)
    .eq('id', bandeId);
  if (saved.error) return { ok: false, error: saved.error.message };
  return { ok: true, bandeNom: bande.data.nom || '', retire: actuel - nouveau };
}

module.exports = {
  ACTION_EFFECTIF,
  quantiteAnimaux,
  effectifDejaDeduit,
  quantiteDeduite,
  aDeduire,
  bandeIdDe,
  entreeHistorique,
  retirerDeLaBande,
};
