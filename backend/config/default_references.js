// Références théoriques par type de volaille (valeurs par défaut, modifiables dans la Configuration).
const DEFAULT_REFERENCES = {
  poulet_ameliore_45j: { dureeJours: 45, poidsFinalG: 2000, consoTotaleKgParTete: 4.5, courbeTheorique: [] },
  poulet_local_ameliore: { dureeJours: 90, poidsFinalG: 1500, consoTotaleKgParTete: 5.5, courbeTheorique: [] },
  poulet_ameliore: { dureeJours: 60, poidsFinalG: 2200, consoTotaleKgParTete: 5.5, courbeTheorique: [] },
  poulet_local: { dureeJours: 120, poidsFinalG: 1400, consoTotaleKgParTete: 6.0, courbeTheorique: [] },
  poule_pondeuse: { dureeJours: 140, poidsFinalG: 1800, consoTotaleKgParTete: 14.0, courbeTheorique: [] },
  canard: { dureeJours: 50, poidsFinalG: 3200, consoTotaleKgParTete: 6.0, courbeTheorique: [] },
  dinde: { dureeJours: 90, poidsFinalG: 7000, consoTotaleKgParTete: 18.0, courbeTheorique: [] },
  autre: { dureeJours: 45, poidsFinalG: 2500, consoTotaleKgParTete: 5.0, courbeTheorique: [] },
};

// Complète les références enregistrées avec les types absents (ex. nouveaux types ajoutés depuis).
function withDefaultReferences(stored) {
  const base = stored && typeof stored === 'object' ? stored : {};
  return { ...DEFAULT_REFERENCES, ...base };
}

module.exports = { DEFAULT_REFERENCES, withDefaultReferences };
