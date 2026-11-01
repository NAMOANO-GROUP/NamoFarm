// Bornes de période envoyées par l'application pour filtrer les mouvements.

const AVEC_FUSEAU = /(Z|[+-]\d{2}:?\d{2})$/i;

/**
 * Convertit une borne de filtre en Date.
 * - Avec fuseau (ex. « 2026-02-28T23:00:00.000Z ») : instant exact calculé par l'appareil
 *   (début ou fin de journée dans le fuseau de l'utilisateur).
 * - Sans fuseau (anciennes versions) : début ou fin de la journée côté serveur.
 * Renvoie null si la valeur est vide ou invalide.
 */
function parseBorneDate(raw, finDeJournee = false) {
  const value = (raw || '').toString().trim();
  if (!value) return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  if (AVEC_FUSEAU.test(value)) return date;
  if (finDeJournee) date.setHours(23, 59, 59, 999);
  else date.setHours(0, 0, 0, 0);
  return date;
}

module.exports = { parseBorneDate };
