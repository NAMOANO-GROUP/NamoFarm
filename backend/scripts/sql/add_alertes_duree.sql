-- Durée des tâches todo : heure de début = date_echeance (existant, avec heure),
-- + heure de fin et indicateur "toute la journée".
--
-- Idempotent. À lancer dans Supabase (SQL Editor > New query > coller > Run).

ALTER TABLE public.alertes ADD COLUMN IF NOT EXISTS date_fin timestamptz;
ALTER TABLE public.alertes ADD COLUMN IF NOT EXISTS toute_journee boolean NOT NULL DEFAULT false;
