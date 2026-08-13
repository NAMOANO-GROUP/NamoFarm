/**
 * Supprime les mouvements trésorerie erronés générés par les sorties de stock
 * (consommation alimentation bandes + prophylaxie).
 *
 * Ces lignes ont source = 'stock_sortie' et ne doivent pas exister :
 * seules les ENTRÉES de stock (achats) génèrent une sortie d'argent.
 *
 * Usage :
 *   node scripts/cleanup_stock_sortie_finance.js --dry-run
 *   node scripts/cleanup_stock_sortie_finance.js --confirm DELETE_NOW
 */

const path = require('path');
const dotenv = require('dotenv');

dotenv.config({ path: path.join(__dirname, '..', '.env') });

const { getAdminClient } = require('../services/supabase');

const CONFIRM_TOKEN = 'DELETE_NOW';

function parseArgs() {
  const args = process.argv.slice(2);
  const result = { dryRun: false, confirm: '' };
  for (let i = 0; i < args.length; i += 1) {
    if (args[i] === '--dry-run') result.dryRun = true;
    if (args[i] === '--confirm') result.confirm = args[i + 1] || '';
  }
  return result;
}

async function main() {
  const { dryRun, confirm } = parseArgs();

  if (!dryRun && confirm !== CONFIRM_TOKEN) {
    console.error(`\nErreur: passez --dry-run pour prévisualiser, ou --confirm ${CONFIRM_TOKEN} pour supprimer.\n`);
    process.exit(1);
  }

  const client = getAdminClient();

  // Récupérer les lignes erronées
  const { data, error } = await client
    .from('tresorerie_mouvements')
    .select('id, company_id, montant, date_mouvement, commentaire, reference_id')
    .eq('source', 'stock_sortie');

  if (error) {
    console.error('Erreur lors de la lecture:', error.message);
    process.exit(1);
  }

  if (!data || data.length === 0) {
    console.log('✅ Aucun enregistrement erroné trouvé. La base est propre.');
    return;
  }

  console.log(`\n📋 ${data.length} mouvement(s) trésorerie erroné(s) trouvé(s) (source = 'stock_sortie') :\n`);
  for (const row of data) {
    console.log(`  - id: ${row.id} | montant: ${row.montant} | date: ${row.date_mouvement} | commentaire: ${row.commentaire}`);
  }

  if (dryRun) {
    console.log(`\n🔍 Mode --dry-run : aucune suppression effectuée.`);
    console.log(`   Pour supprimer, relancez avec : --confirm ${CONFIRM_TOKEN}\n`);
    return;
  }

  const ids = data.map((r) => r.id);
  const { error: delError } = await client
    .from('tresorerie_mouvements')
    .delete()
    .in('id', ids);

  if (delError) {
    console.error('Erreur lors de la suppression:', delError.message);
    process.exit(1);
  }

  console.log(`\n✅ ${ids.length} enregistrement(s) supprimé(s) avec succès.\n`);
}

main().catch((err) => {
  console.error('Erreur inattendue:', err.message);
  process.exit(1);
});
