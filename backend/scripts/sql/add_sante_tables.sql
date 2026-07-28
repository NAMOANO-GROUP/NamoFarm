-- Health traceability module (#3): reusable vaccination protocols + treatment registry
-- with withdrawal periods (délai d'attente avant abattage/consommation).
-- Safe to run multiple times (idempotent). Run in Supabase SQL Editor.

CREATE TABLE IF NOT EXISTS public.protocoles_vaccinaux (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id    uuid NOT NULL,
  nom           text NOT NULL,
  type_volaille text DEFAULT '',
  etapes        jsonb NOT NULL DEFAULT '[]'::jsonb,
  notes         text DEFAULT '',
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.traitements_sanitaires (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id          uuid NOT NULL,
  bande_id            uuid,
  date_traitement     timestamptz NOT NULL DEFAULT now(),
  type                text NOT NULL DEFAULT 'traitement',
  produit             text DEFAULT '',
  dose                text DEFAULT '',
  voie                text DEFAULT '',
  motif               text DEFAULT '',
  delai_attente_jours integer NOT NULL DEFAULT 0,
  utilisateur         text DEFAULT '',
  notes               text DEFAULT '',
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_protocoles_company ON public.protocoles_vaccinaux (company_id);
CREATE INDEX IF NOT EXISTS idx_traitements_company ON public.traitements_sanitaires (company_id);
CREATE INDEX IF NOT EXISTS idx_traitements_bande ON public.traitements_sanitaires (bande_id);
