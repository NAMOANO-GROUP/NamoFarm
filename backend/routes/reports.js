const express = require('express');
const PDFDocument = require('pdfkit');
const ExcelJS = require('exceljs');
const { getAdminClient } = require('../services/supabase');
const { getCompanyIdForUser } = require('../services/company_scope');
const { requireAnyPermission } = require('../middleware/auth');

const router = express.Router();

const REPORT_PERMS = ['reports.sales', 'reports.tech', 'reports.full'];

// Select that tolerates a not-yet-created table (returns []), so the report never
// breaks if the optional module migrations (couvees, sante...) haven't been run.
async function safeSelect(api, table, columns, companyId) {
  const res = await api.from(table).select(columns).eq('company_id', companyId);
  if (res.error) {
    const msg = (res.error.message || '').toString().toLowerCase();
    const missing = msg.includes(table)
      && (msg.includes('does not exist') || msg.includes('could not find') || msg.includes('schema cache') || msg.includes('relation'));
    if (missing) return [];
    throw new Error(res.error.message);
  }
  return res.data || [];
}

function isPaid(row) {
  return (row.statut || row.status || '').toString().toLowerCase() === 'payee';
}

async function computeReportData(api, companyId) {
  const [commandes, treso, bandes, couvees, traitements] = await Promise.all([
    safeSelect(api, 'commandes', 'id,bande_id,statut,status,montant_total', companyId),
    safeSelect(api, 'tresorerie_mouvements', 'nature,montant,reference_type,reference_id', companyId),
    safeSelect(api, 'bandes', 'id,nom,statut,type_volaille,nombre_initial,nombre_actuel,mortalite_totale,cout_poussin', companyId),
    safeSelect(api, 'couvees', 'nb_oeufs_incubes,nb_oeufs_fertiles,nb_eclos', companyId),
    safeSelect(api, 'traitements_sanitaires', 'date_traitement,delai_attente_jours', companyId),
  ]);

  // Finances
  const ca = commandes.reduce((s, c) => s + Number(c.montant_total || 0), 0);
  const dep = (treso || []).filter((m) => m.nature === 'sortie').reduce((s, d) => s + Number(d.montant || 0), 0);
  const entrees = (treso || []).filter((m) => m.nature === 'entree').reduce((s, d) => s + Number(d.montant || 0), 0);
  const benef = ca - dep;
  const marge = ca > 0 ? (benef / ca) * 100 : 0;

  // Élevage
  const effectifInitial = bandes.reduce((s, b) => s + Number(b.nombre_initial || 0), 0);
  const effectifActuel = bandes.reduce((s, b) => s + Number(b.nombre_actuel || 0), 0);
  const mortalite = bandes.reduce((s, b) => s + Number(b.mortalite_totale || 0), 0);
  const tauxMortalite = effectifInitial > 0 ? (mortalite / effectifInitial) * 100 : 0;

  // Reproduction
  const totalIncubes = couvees.reduce((s, c) => s + Number(c.nb_oeufs_incubes || 0), 0);
  const totalFertiles = couvees.reduce((s, c) => s + Number(c.nb_oeufs_fertiles || 0), 0);
  const totalEclos = couvees.reduce((s, c) => s + Number(c.nb_eclos || 0), 0);
  const tauxFertilite = totalIncubes > 0 ? (totalFertiles / totalIncubes) * 100 : 0;
  const tauxEclosion = (totalFertiles > 0 ? totalEclos / totalFertiles : (totalIncubes > 0 ? totalEclos / totalIncubes : 0)) * 100;

  // Santé
  const now = Date.now();
  let delaiEnCours = 0;
  for (const t of traitements) {
    const d = t.date_traitement ? new Date(t.date_traitement) : null;
    const delai = Number(t.delai_attente_jours || 0);
    if (d && delai > 0) {
      const fin = new Date(d.getTime());
      fin.setDate(fin.getDate() + delai);
      if (now < fin.getTime()) delaiEnCours += 1;
    }
  }

  // Performance par bande
  const revenusByBande = new Map();
  for (const c of commandes) {
    if (!isPaid(c)) continue;
    const id = c.bande_id ? String(c.bande_id) : null;
    if (!id) continue;
    revenusByBande.set(id, (revenusByBande.get(id) || 0) + Number(c.montant_total || 0));
  }
  const depByBande = new Map();
  for (const m of treso) {
    if (m.nature !== 'sortie') continue;
    if ((m.reference_type || '').toString().toLowerCase() !== 'bande') continue;
    const id = m.reference_id ? String(m.reference_id) : null;
    if (!id) continue;
    depByBande.set(id, (depByBande.get(id) || 0) + Number(m.montant || 0));
  }
  const perBande = bandes.map((b) => {
    const id = String(b.id);
    const coutPoussins = Number(b.cout_poussin || 0) * Number(b.nombre_initial || 0);
    const depenses = Number(depByBande.get(id) || 0);
    const coutTotal = coutPoussins + depenses;
    const revenus = Number(revenusByBande.get(id) || 0);
    return {
      nom: b.nom || '',
      statut: b.statut || '',
      revenus,
      coutTotal,
      marge: revenus - coutTotal,
    };
  });

  return {
    generatedAt: new Date().toISOString(),
    finances: { ca, dep, entrees, benef, marge, nbCommandes: commandes.length },
    elevage: { nbBandes: bandes.length, effectifInitial, effectifActuel, mortalite, tauxMortalite },
    reproduction: { nbCouvees: couvees.length, totalIncubes, totalFertiles, totalEclos, tauxFertilite, tauxEclosion },
    sante: { nbTraitements: traitements.length, delaiEnCours },
    perBande,
  };
}

function fcfa(n) {
  return `${Number(n || 0).toFixed(0)} FCFA`;
}

router.get('/global.pdf', requireAnyPermission(REPORT_PERMS), async (req, res) => {
  try {
    const api = getAdminClient();
    const companyId = await getCompanyIdForUser(api, req.user.id || req.user._id);
    const data = await computeReportData(api, companyId);

    const doc = new PDFDocument({ margin: 36 });
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', 'attachment; filename=rapport-global.pdf');
    doc.pipe(res);

    doc.fontSize(20).text('Rapport Global AgriBusiness', { align: 'center' });
    doc.moveDown(0.3);
    doc.fontSize(9).fillColor('#666').text(`Généré le ${new Date(data.generatedAt).toLocaleString('fr-FR')}`, { align: 'center' });
    doc.moveDown();
    doc.fillColor('#000');

    const section = (title) => {
      doc.moveDown(0.5);
      doc.fontSize(13).fillColor('#1B5E20').text(title);
      doc.fillColor('#000').fontSize(11);
    };

    section('Finances');
    doc.text(`Chiffre d'affaires: ${fcfa(data.finances.ca)}`);
    doc.text(`Entrées trésorerie: ${fcfa(data.finances.entrees)}`);
    doc.text(`Dépenses: ${fcfa(data.finances.dep)}`);
    doc.text(`Bénéfice net: ${fcfa(data.finances.benef)}  (marge ${data.finances.marge.toFixed(1)}%)`);
    doc.text(`Nombre de commandes: ${data.finances.nbCommandes}`);

    section('Élevage');
    doc.text(`Bandes: ${data.elevage.nbBandes}`);
    doc.text(`Effectif initial / actuel: ${data.elevage.effectifInitial} / ${data.elevage.effectifActuel}`);
    doc.text(`Mortalité cumulée: ${data.elevage.mortalite} (${data.elevage.tauxMortalite.toFixed(2)}%)`);

    section('Reproduction / Couvoir');
    doc.text(`Couvées: ${data.reproduction.nbCouvees}`);
    doc.text(`Œufs incubés / fertiles / éclos: ${data.reproduction.totalIncubes} / ${data.reproduction.totalFertiles} / ${data.reproduction.totalEclos}`);
    doc.text(`Taux fertilité: ${data.reproduction.tauxFertilite.toFixed(1)}%  |  Taux éclosion: ${data.reproduction.tauxEclosion.toFixed(1)}%`);

    section('Santé / Prophylaxie');
    doc.text(`Traitements enregistrés: ${data.sante.nbTraitements}`);
    doc.text(`Délais d'attente en cours: ${data.sante.delaiEnCours}`);

    if (data.perBande.length) {
      section('Performance par bande');
      doc.fontSize(10);
      for (const b of data.perBande) {
        doc.text(`• ${b.nom} (${b.statut}) — Revenus ${fcfa(b.revenus)} | Coût ${fcfa(b.coutTotal)} | Marge ${fcfa(b.marge)}`);
      }
    }

    doc.end();
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

router.get('/global.xlsx', requireAnyPermission(REPORT_PERMS), async (req, res) => {
  try {
    const api = getAdminClient();
    const companyId = await getCompanyIdForUser(api, req.user.id || req.user._id);
    const data = await computeReportData(api, companyId);

    const workbook = new ExcelJS.Workbook();
    const kpi = workbook.addWorksheet('Synthèse');
    kpi.addRow(['Indicateur', 'Valeur']);
    kpi.addRow(["Chiffre d'affaires", data.finances.ca]);
    kpi.addRow(['Entrées trésorerie', data.finances.entrees]);
    kpi.addRow(['Dépenses', data.finances.dep]);
    kpi.addRow(['Bénéfice net', data.finances.benef]);
    kpi.addRow(['Marge (%)', Number(data.finances.marge.toFixed(2))]);
    kpi.addRow(['Nombre de commandes', data.finances.nbCommandes]);
    kpi.addRow(['Bandes', data.elevage.nbBandes]);
    kpi.addRow(['Effectif initial', data.elevage.effectifInitial]);
    kpi.addRow(['Effectif actuel', data.elevage.effectifActuel]);
    kpi.addRow(['Mortalité cumulée', data.elevage.mortalite]);
    kpi.addRow(['Taux mortalité (%)', Number(data.elevage.tauxMortalite.toFixed(2))]);
    kpi.addRow(['Couvées', data.reproduction.nbCouvees]);
    kpi.addRow(['Œufs incubés', data.reproduction.totalIncubes]);
    kpi.addRow(['Œufs fertiles', data.reproduction.totalFertiles]);
    kpi.addRow(['Poussins éclos', data.reproduction.totalEclos]);
    kpi.addRow(['Taux fertilité (%)', Number(data.reproduction.tauxFertilite.toFixed(2))]);
    kpi.addRow(['Taux éclosion (%)', Number(data.reproduction.tauxEclosion.toFixed(2))]);
    kpi.addRow(['Traitements', data.sante.nbTraitements]);
    kpi.addRow(["Délais d'attente en cours", data.sante.delaiEnCours]);
    kpi.getRow(1).font = { bold: true };
    kpi.columns.forEach((c) => { c.width = 28; });

    const bandeSheet = workbook.addWorksheet('Performance bandes');
    bandeSheet.addRow(['Bande', 'Statut', 'Revenus', 'Coût total', 'Marge']);
    bandeSheet.getRow(1).font = { bold: true };
    for (const b of data.perBande) {
      bandeSheet.addRow([b.nom, b.statut, b.revenus, b.coutTotal, b.marge]);
    }
    bandeSheet.columns.forEach((c) => { c.width = 22; });

    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', 'attachment; filename=rapport-global.xlsx');
    await workbook.xlsx.write(res);
    return res.end();
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
});

module.exports = router;
