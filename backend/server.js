const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
require('dotenv').config();

// Fail fast if JWT_SECRET is missing or left as an obvious placeholder — a weak
// or absent secret would let anyone forge valid auth tokens.
const jwtSecret = (process.env.JWT_SECRET || '').trim();
const weakSecrets = new Set(['dev_secret_change_me', 'change_this_secret', 'secret', '']);
if (weakSecrets.has(jwtSecret) || jwtSecret.length < 16) {
  console.error('\n❌ JWT_SECRET manquant ou trop faible. Définissez une variable d\'environnement JWT_SECRET forte (>= 16 caractères aléatoires) avant de démarrer le serveur.\n');
  process.exit(1);
}

const { authenticate } = require('./middleware/auth');
const { createRateLimiter } = require('./middleware/rateLimiter');

const app = express();

// CORS: restrict to known origins via CORS_ORIGIN (comma-separated). Requests
// without an Origin header (native mobile apps, curl, server-to-server) are
// always allowed since browsers are the only clients that send/enforce CORS.
const configuredOrigins = (process.env.CORS_ORIGIN || '')
  .split(',')
  .map((o) => o.trim())
  .filter(Boolean);

if (configuredOrigins.length === 0) {
  console.warn('⚠️  CORS_ORIGIN non défini: toutes les origines web sont acceptées. Définissez CORS_ORIGIN (ex: https://monapp.vercel.app) pour restreindre l\'accès.');
}

app.use(cors({
  origin(origin, callback) {
    if (!origin || configuredOrigins.length === 0 || configuredOrigins.includes(origin)) {
      return callback(null, true);
    }
    return callback(new Error('Origine non autorisée par CORS'));
  },
}));
app.use(bodyParser.json({ limit: '2mb' }));

// Filet de sécurité global anti-abus: au-delà des limiteurs spécifiques sur
// /auth, toutes les routes /api partagent cette limite généreuse par IP.
const globalApiLimiter = createRateLimiter({
  windowMs: 5 * 60 * 1000,
  max: 600,
  message: 'Trop de requêtes depuis cette adresse. Réessaie dans quelques minutes.',
});
app.use('/api', globalApiLimiter);

// Routes
const bandesRoutes = require('./routes/bandes');
const clientsRoutes = require('./routes/clients');
const fournisseursRoutes = require('./routes/fournisseurs');
const commandesRoutes = require('./routes/commandes');
const stocksRoutes = require('./routes/stocks');
const alertesRoutes = require('./routes/alertes');
const authRoutes = require('./routes/auth');
const crmRoutes = require('./routes/crm');
const dashboardRoutes = require('./routes/dashboard');
const reportsRoutes = require('./routes/reports');
const usersRoutes = require('./routes/users');
const configRoutes = require('./routes/config');
const onboardingCodesRoutes = require('./routes/onboarding_codes');
const financeRoutes = require('./routes/finance');
const roadmapRoutes = require('./routes/roadmap');
const couveesRoutes = require('./routes/couvees');
const santeRoutes = require('./routes/sante');
const cheptelRoutes = require('./routes/cheptel');
const previsionsRoutes = require('./routes/previsions');
const achatsRoutes = require('./routes/achats');

app.use('/api/auth', authRoutes);
app.use('/api/bandes', authenticate, bandesRoutes);
app.use('/api/clients', authenticate, clientsRoutes);
app.use('/api/fournisseurs', authenticate, fournisseursRoutes);
app.use('/api/commandes', authenticate, commandesRoutes);
app.use('/api/stocks', authenticate, stocksRoutes);
app.use('/api/alertes', authenticate, alertesRoutes);
app.use('/api/crm', authenticate, crmRoutes);
app.use('/api/dashboard', authenticate, dashboardRoutes);
app.use('/api/reports', authenticate, reportsRoutes);
app.use('/api/finance', authenticate, financeRoutes);
app.use('/api/roadmap', authenticate, roadmapRoutes);
app.use('/api/reproduction', authenticate, couveesRoutes);
app.use('/api/sante', authenticate, santeRoutes);
app.use('/api/cheptel', authenticate, cheptelRoutes);
app.use('/api/previsions', authenticate, previsionsRoutes);
app.use('/api/achats', authenticate, achatsRoutes);
app.use('/api/users', usersRoutes);
app.use('/api/config', configRoutes);
app.use('/api/onboarding-codes', onboardingCodesRoutes);

// Route de test
app.get('/', (req, res) => {
  res.json({ message: 'NamoFarm API est en ligne' });
});

// Démarrage du serveur
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`Serveur NamoFarm démarré sur le port ${PORT}`);
});
