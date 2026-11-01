const test = require('node:test');
const assert = require('node:assert/strict');
const {
  normalizeChecklist,
  resetChecklist,
  writeWithOptionalColumns,
  nextEcheance,
} = require('../services/task_utils');

test('normalizeChecklist nettoie et limite les étapes', () => {
  assert.deepEqual(normalizeChecklist(null), []);
  assert.deepEqual(
    normalizeChecklist([{ titre: '  Pesée ', fait: true }, { titre: '' }, { titre: 'Vaccin', fait: 'oui' }]),
    [{ titre: 'Pesée', fait: true }, { titre: 'Vaccin', fait: false }],
  );
  assert.equal(normalizeChecklist(Array.from({ length: 50 }, (_, i) => ({ titre: `E${i}` }))).length, 30);
});

test('resetChecklist décoche toutes les étapes pour la prochaine occurrence', () => {
  assert.deepEqual(resetChecklist([{ titre: 'A', fait: true }]), [{ titre: 'A', fait: false }]);
});

test('nextEcheance gère les récurrences usuelles', () => {
  const base = '2026-11-02T08:00:00.000Z'; // lundi
  assert.equal(nextEcheance(base, 'quotidien').toISOString(), '2026-11-03T08:00:00.000Z');
  assert.equal(nextEcheance(base, 'bihebdomadaire').toISOString(), '2026-11-16T08:00:00.000Z');
  assert.equal(nextEcheance(base, 'aucune'), null);
  assert.equal(nextEcheance('pas une date', 'quotidien'), null);
  const jeudi = nextEcheance(base, 'hebdomadaire', { joursSemaine: [4] });
  assert.equal(((jeudi.getDay() + 6) % 7) + 1, 4);
});

test('writeWithOptionalColumns retire une colonne non migrée et réessaie', async () => {
  const seen = [];
  const run = async (payload) => {
    seen.push(Object.keys(payload).sort().join(','));
    if ('checklist' in payload) return { error: { message: "Could not find the 'checklist' column of 'alertes'" } };
    return { data: payload, error: null };
  };
  const result = await writeWithOptionalColumns(run, { titre: 'T', checklist: [] }, ['checklist', 'assigne_a']);
  assert.equal(result.error, null);
  assert.deepEqual(seen, ['checklist,titre', 'titre']);
});

test('writeWithOptionalColumns ne masque pas les autres erreurs', async () => {
  const run = async () => ({ error: { message: 'permission denied' } });
  const result = await writeWithOptionalColumns(run, { titre: 'T', checklist: [] }, ['checklist']);
  assert.equal(result.error.message, 'permission denied');
});
