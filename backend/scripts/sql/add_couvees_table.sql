-- Reproduction / hatchery module: incubation batches (couvées).
-- Tracks fertility and hatch rates for breeding/hatchery operations.
-- Safe to run multiple times (idempotent). Run in Supabase SQL Editor.

CREATE TABLE IF NOT EXISTS public.couvees (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id            uuid NOT NULL,
  code                  text NOT NULL,
  race                  text DEFAULT '',
  bande_id              uuid,
  date_mise_incubation  timestamptz NOT NULL DEFAULT now(),
  nb_oeufs_incubes      integer NOT NULL DEFAULT 0,
  date_mirage           timestamptz,
  nb_oeufs_fertiles     integer,
  date_eclosion         timestamptz,
  nb_eclos              integer,
  nb_poussins_viables   integer,
  statut                text NOT NULL DEFAULT 'en_incubation',
  notes                 text DEFAULT '',
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_couvees_company ON public.couvees (company_id);
CREATE INDEX IF NOT EXISTS idx_couvees_statut ON public.couvees (statut);

-- (Optional) verification:
-- SELECT id, code, statut, nb_oeufs_incubes, nb_oeufs_fertiles, nb_eclos
-- FROM public.couvees ORDER BY created_at DESC LIMIT 20;
