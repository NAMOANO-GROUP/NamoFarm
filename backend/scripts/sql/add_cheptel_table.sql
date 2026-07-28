-- Cheptel (permanent herd/flock) module: continuous headcount with a movement journal.
-- For livestock NOT managed as bandes/lots (goats, local hens, guinea fowl...) where
-- births/hatchings and deaths/sales happen continuously over time.
-- Safe to run multiple times (idempotent). Run in Supabase SQL Editor.

CREATE TABLE IF NOT EXISTS public.cheptels (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id      uuid NOT NULL,
  nom             text NOT NULL,
  espece          text DEFAULT '',
  effectif_actuel integer NOT NULL DEFAULT 0,
  mouvements      jsonb NOT NULL DEFAULT '[]'::jsonb,
  notes           text DEFAULT '',
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cheptels_company ON public.cheptels (company_id);
