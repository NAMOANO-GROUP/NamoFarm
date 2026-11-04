const test = require('node:test');
const assert = require('node:assert/strict');
const v = require('../services/ventes_bandes');

test('quantiteAnimaux additionne les lignes valides', () => {
  assert.equal(v.quantiteAnimaux([{ quantite: 20 }, { qte: '5' }, { quantite: -3 }, { quantite: 'x' }, null]), 25);
  assert.equal(v.quantiteAnimaux(null), 0);
});

test('aDeduire : bande liée, animaux, pas encore retirée', () => {
  const base = { bande_id: 'b1', produits: [{ quantite: 10 }], historique_actions: [] };
  assert.equal(v.aDeduire(base), true);
  assert.equal(v.aDeduire({ ...base, bande_id: null }), false);
  assert.equal(v.aDeduire({ ...base, produits: [] }), false);
  const deja = { ...base, historique_actions: [v.entreeHistorique(10, 'B1', 'Moi')] };
  assert.equal(v.aDeduire(deja), false);
  assert.match(deja.historique_actions[0].details, /10 sujet\(s\) retiré\(s\).*B1/);
});

function fausseBase(nombre) {
  const etat = { nombre_actuel: nombre, maj: [] };
  const chaine = {
    select() { return chaine; },
    eq() { return chaine; },
    update(obj) { etat.maj.push(obj); etat.nombre_actuel = obj.nombre_actuel; return { eq: () => ({ eq: async () => ({ error: null }) }) }; },
    maybeSingle: async () => ({ data: { id: 'b1', nom: 'B1', nombre_actuel: etat.nombre_actuel }, error: null }),
  };
  return { etat, api: { from: () => chaine } };
}

test('retirerDeLaBande ne descend jamais sous zéro', async () => {
  const { etat, api } = fausseBase(30);
  const r1 = await v.retirerDeLaBande(api, 'c', 'b1', 12);
  assert.deepEqual([r1.ok, r1.retire, etat.nombre_actuel], [true, 12, 18]);
  const r2 = await v.retirerDeLaBande(api, 'c', 'b1', 50);
  assert.deepEqual([r2.retire, etat.nombre_actuel], [18, 0]);
});
