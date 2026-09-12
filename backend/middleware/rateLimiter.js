// Limiteur anti-abus léger, en mémoire (sans dépendance externe).
// Autorise au plus `max` requêtes par IP sur une fenêtre glissante `windowMs`.
// Utilisé à la fois pour un limiteur global (toutes les routes /api) et pour
// des limiteurs plus stricts sur des endpoints sensibles (login, reset mdp...).
function createRateLimiter({ windowMs, max, message }) {
  const hits = new Map(); // ip -> { count, resetAt }

  return (req, res, next) => {
    const now = Date.now();

    // Purge occasionnelle des entrées expirées pour éviter toute fuite mémoire.
    if (hits.size > 5000) {
      for (const [key, value] of hits) {
        if (value.resetAt <= now) hits.delete(key);
      }
    }

    const forwarded = (req.headers['x-forwarded-for'] || '').split(',')[0].trim();
    const ip = forwarded || req.ip || req.socket?.remoteAddress || 'unknown';

    let entry = hits.get(ip);
    if (!entry || entry.resetAt <= now) {
      entry = { count: 0, resetAt: now + windowMs };
      hits.set(ip, entry);
    }
    entry.count += 1;

    if (entry.count > max) {
      const retryAfter = Math.ceil((entry.resetAt - now) / 1000);
      res.set('Retry-After', String(retryAfter));
      return res.status(429).json({
        message: message || `Trop de requêtes. Réessaie dans ${retryAfter} seconde(s).`,
      });
    }
    return next();
  };
}

module.exports = { createRateLimiter };
