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

test('retirerDeLaBande refuse de retirer plus que l’effectif (erreur de saisie)', async () => {
  const { etat, api } = fausseBase(319);
  const r1 = await v.retirerDeLaBande(api, 'c', 'b1', 6);
  assert.deepEqual([r1.ok, r1.retire, etat.nombre_actuel], [true, 6, 313]);
  // Prix (3000) saisi à la place de la quantité : la bande n'est pas vidée.
  const r2 = await v.retirerDeLaBande(api, 'c', 'b1', 3000);
  assert.deepEqual([r2.ok, r2.insuffisant, etat.nombre_actuel], [false, true, 313]);
  assert.match(r2.error, /3000.*313/);
  // Quantité négative : les sujets sont rendus à la bande (correction).
  const r3 = await v.retirerDeLaBande(api, 'c', 'b1', -2);
  assert.deepEqual([r3.ok, r3.retire, etat.nombre_actuel], [true, -2, 315]);
});

test('quantiteDeduite additionne sorties et corrections', () => {
  const h = [
    { action: 'creation' },
    v.entreeHistorique(10, 'B1', 'Moi'),
    v.entreeHistorique(-4, 'B1', 'Moi'),
  ];
  assert.equal(v.quantiteDeduite(h), 6);
  assert.equal(v.quantiteDeduite([]), 0);
});
