-- Coût fixe et amortissement d'une bande saisis en forfait (montant total pour la bande),
-- en plus ou à la place des montants par sujet (cout_fixe_par_sujet, amortissement_par_sujet).
-- Coût retenu = montant par sujet x sujets élevés + forfait (route /finance/analytique).
--
-- Idempotent : peut être exécuté plusieurs fois sans risque.
-- À lancer dans Supabase (Dashboard > SQL Editor > New query > coller > Run).

ALTER TABLE public.bandes ADD COLUMN IF NOT EXISTS cout_fixe_forfait numeric NOT NULL DEFAULT 0;
ALTER TABLE public.bandes ADD COLUMN IF NOT EXISTS amortissement_forfait numeric NOT NULL DEFAULT 0;
