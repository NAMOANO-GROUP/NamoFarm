const test = require('node:test');
const assert = require('node:assert/strict');
const {
  computeScore,
  normalizeDeal,
  summarizePipeline,
  reorderSuggestions,
  bandeExitSuggestions,
  dormantSuggestions,
  buildSuggestions,
  inferPipelineStage,
} = require('../services/crm_insights');

const NOW = new Date('2026-11-01T10:00:00.000Z');
const daysAgo = (n) => new Date(NOW.getTime() - n * 86400000).toISOString();

test('inferPipelineStage déduit l’étape des commandes', () => {
  assert.equal(inferPipelineStage({ statut: 'prospect' }, []), 'lead');
  assert.equal(inferPipelineStage({ statut: 'actif' }, []), 'qualifie');
  assert.equal(inferPipelineStage({}, [{ statut: 'en_attente' }]), 'negociation');
  assert.equal(inferPipelineStage({}, [{ statut: 'payee' }]), 'gagne');
});

test('computeScore récompense la récence et reste borné à 100', () => {
  const recent = computeScore({ client: {}, lastActivity: daysAgo(2), now: NOW });
  const ancien = computeScore({ client: {}, lastActivity: daysAgo(200), now: NOW });
  assert.equal(recent, 25);
  assert.equal(ancien, 0);

  const max = computeScore({
    client: { chiffre_affaires_cumul: 10_000_000 },
    interactionsCount: 50,
    commandes: Array.from({ length: 20 }, () => ({ statut: 'payee' })),
    lastActivity: daysAgo(1),
    now: NOW,
  });
  assert.equal(max, 100);
});

test('computeScore ignore les commandes annulées', () => {
  const score = computeScore({ client: {}, commandes: [{ statut: 'annulee' }, { statut: 'payee' }], now: NOW });
  assert.equal(score, 6);
});

test('normalizeDeal applique la probabilité par défaut de l’étape', () => {
  assert.deepEqual(normalizeDeal({}, 'proposition'), { montant: 0, probabilite: 50, dateCloturePrevue: null });
  const deal = normalizeDeal({ montant: '150000', probabilite: 140, dateCloturePrevue: '2026-12-01' }, 'lead');
  assert.equal(deal.montant, 150000);
  assert.equal(deal.probabilite, 100);
  assert.equal(deal.dateCloturePrevue, '2026-12-01T00:00:00.000Z');
});

test('summarizePipeline calcule totaux et prévision pondérée hors gagné/perdu', () => {
  const summary = summarizePipeline([
    { stage: 'proposition', montant: 100000, probabilite: 50 },
    { stage: 'negociation', montant: 200000, probabilite: 75 },
    { stage: 'gagne', montant: 500000, probabilite: 100 },
    { stage: 'perdu', montant: 80000, probabilite: 0 },
  ]);
  assert.equal(summary.montantOuvert, 300000);
  assert.equal(summary.previsionPonderee, 200000);
  assert.equal(summary.stages.find((s) => s.stage === 'gagne').montant, 500000);
});

test('reorderSuggestions détecte un réachat attendu', () => {
  const clients = [{ id: 'c1', prenom: 'Awa', nom: 'Diop', statut: 'actif' }];
  const commandes = [
    { client_id: 'c1', statut: 'payee', created_at: daysAgo(90) },
    { client_id: 'c1', statut: 'payee', created_at: daysAgo(60) },
    { client_id: 'c1', statut: 'payee', created_at: daysAgo(32) },
  ];
  const [s] = reorderSuggestions({ clients, commandes, now: NOW });
  assert.equal(s.kind, 'reachat');
  assert.equal(s.priorite, 'haute');
  assert.match(s.raison, /depuis/);

  assert.equal(reorderSuggestions({ clients, commandes, excludedClientIds: new Set(['c1']), now: NOW }).length, 0);
});

test('reorderSuggestions ignore les clients avec une seule commande', () => {
  const out = reorderSuggestions({
    clients: [{ id: 'c1' }],
    commandes: [{ client_id: 'c1', created_at: daysAgo(10) }],
    now: NOW,
  });
  assert.equal(out.length, 0);
});

test('bandeExitSuggestions cible les acheteurs du même type de volaille', () => {
  const bandes = [
    { id: 'b-old', nom: 'Ancienne', statut: 'fermee', type_volaille: 'poulet_chair', date_ouverture: daysAgo(200) },
    { id: 'b-new', nom: 'B12', statut: 'ouverte', type_volaille: 'poulet_chair', date_ouverture: daysAgo(40), duree_elevage_jours: 45 },
  ];
  const clients = [{ id: 'c1', prenom: 'Awa' }, { id: 'c2', prenom: 'Moussa' }];
  const commandes = [
    { client_id: 'c1', bande_id: 'b-old', statut: 'payee', montant_total: 50000 },
    { client_id: 'c2', bande_snapshot: { typeVolaille: 'pondeuse' }, statut: 'payee', montant_total: 90000 },
  ];
  const out = bandeExitSuggestions({ bandes, clients, commandes, now: NOW });
  assert.equal(out.length, 1);
  assert.equal(out[0].clientId, 'c1');
  assert.equal(out[0].kind, 'sortie_bande');
  assert.match(out[0].raison, /5 j/);
});

test('dormantSuggestions ne retient que les clients actifs sans contact récent', () => {
  const clients = [
    { id: 'c1', statut: 'actif', dernier_contact_le: daysAgo(45) },
    { id: 'c2', statut: 'actif', dernier_contact_le: daysAgo(3) },
    { id: 'c3', statut: 'prospect' },
  ];
  const out = dormantSuggestions({ clients, now: NOW });
  assert.deepEqual(out.map((s) => s.clientId), ['c1']);
});

test('buildSuggestions exclut les clients ayant déjà une relance ouverte', () => {
  const clients = [{ id: 'c1', statut: 'actif' }, { id: 'c2', statut: 'actif' }];
  const out = buildSuggestions({
    clients,
    taches: [{ client_id: 'c1', statut: 'a_faire' }, { client_id: 'c2', statut: 'terminee' }],
    now: NOW,
  });
  assert.deepEqual(out.map((s) => s.clientId), ['c2']);
});
