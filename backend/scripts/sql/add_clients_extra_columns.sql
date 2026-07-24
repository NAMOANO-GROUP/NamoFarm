-- Add the missing business columns on public.clients so adresse / type_client /
-- commentaire_activite / entreprise are stored in dedicated columns instead of the
-- notes envelope fallback.
--
-- Robust version: the ADD COLUMN statements run first and the (optional) data
-- backfill is isolated inside a DO ... EXCEPTION block, so a backfill problem can
-- NEVER roll back the column creation.
--
-- Safe to run multiple times (idempotent). Run it in the Supabase SQL Editor
-- (Dashboard > SQL Editor > New query > paste > Run).
--
-- NOTE: the `clients` table also holds fournisseurs (statut = 'fournisseur'),
-- so this single migration fixes clients AND fournisseurs at once.

-- 1) Add the dedicated columns (idempotent, cannot fail on re-run).
ALTER TABLE public.clients ADD COLUMN IF NOT EXISTS adresse text;
ALTER TABLE public.clients ADD COLUMN IF NOT EXISTS type_client text;
ALTER TABLE public.clients ADD COLUMN IF NOT EXISTS commentaire_activite text;
ALTER TABLE public.clients ADD COLUMN IF NOT EXISTS entreprise text;

-- 2) Optional backfill from the old notes envelope ({"_cx":1,...}), non-blocking:
--    if anything goes wrong here it is caught and simply skipped, the columns above
--    remain created.
DO $$
BEGIN
  UPDATE public.clients c
  SET
    adresse              = COALESCE(NULLIF(c.adresse, ''),              NULLIF(c.notes::jsonb ->> 'adresse', '')),
    type_client          = COALESCE(NULLIF(c.type_client, ''),          NULLIF(c.notes::jsonb ->> 'typeClient', '')),
    commentaire_activite = COALESCE(NULLIF(c.commentaire_activite, ''), NULLIF(c.notes::jsonb ->> 'commentaireActivite', '')),
    entreprise           = COALESCE(NULLIF(c.entreprise, ''),           NULLIF(c.notes::jsonb ->> 'entreprise', '')),
    notes                = COALESCE(c.notes::jsonb ->> 'notes', c.notes)
  WHERE left(btrim(c.notes), 1) = '{'
    AND c.notes LIKE '%"_cx"%';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'Backfill ignore (non bloquant): %', SQLERRM;
END $$;

-- 3) Default type_client only for rows where it is still empty/unknown.
--    IMPORTANT: type (pro/particulier) is INDEPENDENT of statut (client/fournisseur):
--    a fournisseur can be pro OR particulier, and a client can be pro OR particulier.
--    So we do NOT force any type based on statut; we only fill a neutral default
--    ('particulier') for legacy rows whose type was never captured. Any explicit
--    choice already restored from the notes envelope in step 2 is preserved.
UPDATE public.clients
SET type_client = 'particulier'
WHERE type_client IS NULL OR btrim(type_client) = '';

-- 4) (Optional) quick verification — run separately after the migration:
-- SELECT id, nom, prenom, adresse, type_client, commentaire_activite, entreprise, notes
-- FROM public.clients
-- ORDER BY updated_at DESC
-- LIMIT 20;
