const test = require('node:test');
const assert = require('node:assert/strict');
const { normalizeBudgets, isMissingTableError, MONTANT_MAX } = require('../services/finance_budgets');
const { parseBorneDate } = require('../services/finance_dates');

test('normalizeBudgets accepte un objet ou une liste et ignore les valeurs invalides', () => {
  assert.deepEqual(normalizeBudgets({ Alimentation: '500000', Transport: 25000.555, '': 10, Divers: -5, Salaire: 'abc' }), [
    { poste: 'Alimentation', montantMensuel: 500000 },
    { poste: 'Transport', montantMensuel: 25000.56 },
  ]);
  assert.deepEqual(normalizeBudgets([{ poste: ' Alimentation ', montantMensuel: 1 }, { poste: 'Alimentation', montantMensuel: 2 }]), [
    { poste: 'Alimentation', montantMensuel: 2 },
  ]);
  assert.deepEqual(normalizeBudgets(null), []);
  assert.deepEqual(normalizeBudgets({ Divers: 5e15 }), [{ poste: 'Divers', montantMensuel: MONTANT_MAX }]);
});

test('isMissingTableError reconnaît une table non migrée', () => {
  assert.equal(isMissingTableError({ code: '42P01', message: 'relation does not exist' }), true);
  assert.equal(isMissingTableError({ message: "Could not find the table 'public.finance_budgets' in the schema cache" }), true);
  assert.equal(isMissingTableError({ message: 'permission denied' }), false);
});

test('parseBorneDate garde l\'instant envoyé avec fuseau, sinon prend le début ou la fin du jour', () => {
  assert.equal(parseBorneDate('2026-02-28T23:00:00.000Z').toISOString(), '2026-02-28T23:00:00.000Z');
  assert.equal(parseBorneDate('2026-03-31T22:59:59.999+00:00', true).toISOString(), '2026-03-31T22:59:59.999Z');
  const debut = parseBorneDate('2026-03-05T15:20:00');
  assert.deepEqual([debut.getHours(), debut.getMinutes(), debut.getDate()], [0, 0, 5]);
  const fin = parseBorneDate('2026-03-05T08:00:00', true);
  assert.deepEqual([fin.getHours(), fin.getMinutes(), fin.getDate()], [23, 59, 5]);
  assert.equal(parseBorneDate(''), null);
  assert.equal(parseBorneDate('pas une date'), null);
});
