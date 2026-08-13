const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
require('dotenv').config();
const { authenticate } = require('./middleware/auth');

const app = express();

// Middleware
app.use(cors());
app.use(bodyParser.json());

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
