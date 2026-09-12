/**
 * Liste (et supprime sur confirmation) les mouvements trésorerie erronés
 * générés par une vente de cheptel où le montant n'a pas été multiplié
 * par la quantité (ex: montant = 5000 au lieu de quantite * prix_unitaire).
 *
 * Usage :
 *   node scripts/cleanup_cheptel_vente_montant.js --dry-run
 *   node scripts/cleanup_cheptel_vente_montant.js --dry-run --montant 5000
 *   node scripts/cleanup_cheptel_vente_montant.js --confirm DELETE_NOW --id <uuid>
 */

const path = require('path');
const dotenv = require('dotenv');

dotenv.config({ path: path.join(__dirname, '..', '.env') });

const { getAdminClient } = require('../services/supabase');

const CONFIRM_TOKEN = 'DELETE_NOW';

function parseArgs() {
  const args = process.argv.slice(2);
  const result = { dryRun: false, confirm: '', montant: null, id: '' };
  for (let i = 0; i < args.length; i += 1) {
    if (args[i] === '--dry-run') result.dryRun = true;
    if (args[i] === '--confirm') result.confirm = args[i + 1] || '';
    if (args[i] === '--montant') result.montant = Number(args[i + 1]);
    if (args[i] === '--id') result.id = args[i + 1] || '';
  }
  return result;
}

async function main() {
  const { dryRun, confirm, montant, id } = parseArgs();

  if (!dryRun && confirm !== CONFIRM_TOKEN) {
    console.error(`\nErreur: passez --dry-run pour previsualiser, ou --confirm ${CONFIRM_TOKEN} --id <uuid> pour supprimer une ligne precise.\n`);
    process.exit(1);
  }

  const client = getAdminClient();

  if (!dryRun && id) {
    const { error } = await client.from('tresorerie_mouvements').delete().eq('id', id);
    if (error) {
      console.error('Erreur lors de la suppression:', error.message);
      process.exit(1);
    }
    console.log(`\n✅ Transaction ${id} supprimee avec succes.\n`);
    return;
  }

  let query = client
    .from('tresorerie_mouvements')
    .select('id, company_id, montant, date_mouvement, commentaire, reference_id, source')
    .eq('source', 'vente_cheptel');

  if (montant != null && !Number.isNaN(montant)) {
    query = query.eq('montant', montant);
  }

  const { data, error } = await query.order('date_mouvement', { ascending: false }).limit(50);

  if (error) {
    console.error('Erreur lors de la lecture:', error.message);
    process.exit(1);
  }

  if (!data || data.length === 0) {
    console.log('✅ Aucun mouvement "vente_cheptel" correspondant trouve.');
    return;
  }

  console.log(`\n📋 ${data.length} mouvement(s) "vente_cheptel" trouve(s) :\n`);
  for (const row of data) {
    console.log(`  - id: ${row.id} | montant: ${row.montant} | date: ${row.date_mouvement} | commentaire: ${row.commentaire}`);
  }
  console.log(`\n🔍 Mode --dry-run : aucune suppression effectuee.`);
  console.log(`   Pour supprimer une ligne precise: --confirm ${CONFIRM_TOKEN} --id <uuid>\n`);
}

main().catch((err) => {
  console.error('Erreur inattendue:', err.message);
  process.exit(1);
});
