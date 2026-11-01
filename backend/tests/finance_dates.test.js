const test = require('node:test');
const assert = require('node:assert/strict');
const { parseBorneDate } = require('../services/finance_dates');

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
