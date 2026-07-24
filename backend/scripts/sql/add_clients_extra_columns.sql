-- Add the missing business columns on public.clients so adresse / type_client /
-- commentaire_activite / entreprise are stored in dedicated columns instead of the
-- notes envelope fallback.
--
-- This ALSO backfills the new columns from any data previously stored inside the
-- `notes` JSON envelope (rows where notes = {"_cx":1,...}), then restores the plain
-- user note text.
--
-- Safe to run multiple times (idempotent). Run it in the Supabase SQL Editor
-- (Dashboard > SQL Editor > New query > paste > Run).
--
-- NOTE: the `clients` table also holds fournisseurs (statut = 'fournisseur'),
-- so this single migration fixes clients AND fournisseurs at once.

BEGIN;

-- 1) Add the dedicated columns if they do not exist yet.
ALTER TABLE public.clients ADD COLUMN IF NOT EXISTS adresse text;
ALTER TABLE public.clients ADD COLUMN IF NOT EXISTS type_client text;
ALTER TABLE public.clients ADD COLUMN IF NOT EXISTS commentaire_activite text;
ALTER TABLE public.clients ADD COLUMN IF NOT EXISTS entreprise text;

ALTER TABLE public.clients ALTER COLUMN type_client SET DEFAULT 'particulier';

-- 2) Safe JSON parser (temporary, auto-dropped at end of session).
--    Returns NULL instead of raising when notes is plain text (not JSON).
CREATE OR REPLACE FUNCTION pg_temp.try_jsonb(txt text)
RETURNS jsonb
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  IF txt IS NULL OR btrim(txt) = '' OR left(btrim(txt), 1) <> '{' THEN
    RETURN NULL;
  END IF;
  RETURN txt::jsonb;
EXCEPTION WHEN others THEN
  RETURN NULL;
END;
$$;

-- 3) Backfill the new columns from the notes envelope, then restore plain notes.
WITH env AS (
  SELECT id, pg_temp.try_jsonb(notes) AS j
  FROM public.clients
  WHERE (pg_temp.try_jsonb(notes) ->> '_cx') = '1'
)
UPDATE public.clients AS c
SET
  adresse              = COALESCE(NULLIF(c.adresse, ''),              NULLIF(env.j ->> 'adresse', '')),
  type_client          = COALESCE(NULLIF(c.type_client, ''),          NULLIF(env.j ->> 'typeClient', ''), 'particulier'),
  commentaire_activite = COALESCE(NULLIF(c.commentaire_activite, ''), NULLIF(env.j ->> 'commentaireActivite', '')),
  entreprise           = COALESCE(NULLIF(c.entreprise, ''),           NULLIF(env.j ->> 'entreprise', '')),
  notes                = COALESCE(env.j ->> 'notes', '')
FROM env
WHERE c.id = env.id;

-- 4) Default type_client for any remaining empty/null values (statut-aware:
--    fournisseurs default to 'pro', clients/prospects to 'particulier').
UPDATE public.clients
SET type_client = CASE
  WHEN lower(btrim(coalesce(statut, ''))) = 'fournisseur' THEN 'pro'
  ELSE 'particulier'
END
WHERE type_client IS NULL OR btrim(type_client) = '';

COMMIT;

-- 5) (Optional) quick verification — run separately after the migration:
-- SELECT id, nom, prenom, adresse, type_client, commentaire_activite, entreprise, notes
-- FROM public.clients
-- ORDER BY updated_at DESC
-- LIMIT 20;
