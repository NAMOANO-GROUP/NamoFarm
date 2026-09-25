-- Add per-bande end-of-flock cost inputs (per subject):
--   * cout_fixe_par_sujet        : "Coût Fixe" (ex: salaire) appliqué par sujet
--   * amortissement_par_sujet    : "Amortissement" des investissements, par sujet
--
-- Ces montants sont saisis par bande (modifiables à tout moment) et multipliés
-- par l'effectif vivant dans le calcul du coût total (route /finance/analytique).
--
-- Idempotent : peut être exécuté plusieurs fois sans risque.
-- À lancer dans Supabase (Dashboard > SQL Editor > New query > coller > Run).

ALTER TABLE public.bandes ADD COLUMN IF NOT EXISTS cout_fixe_par_sujet numeric NOT NULL DEFAULT 0;
ALTER TABLE public.bandes ADD COLUMN IF NOT EXISTS amortissement_par_sujet numeric NOT NULL DEFAULT 0;
