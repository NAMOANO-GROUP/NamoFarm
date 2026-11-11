-- Répartition de l'argent disponible entre deux caisses.
-- La caisse 2 est une sous-caisse : aucune opération n'y est saisie, seul son montant est enregistré.
-- Caisse 1 = argent disponible (entrées - sorties) - caisse 2 (calculée, jamais stockée).
--
-- Idempotent : peut être exécuté plusieurs fois sans risque.
-- À lancer dans Supabase (Dashboard > SQL Editor > New query > coller > Run).

CREATE TABLE IF NOT EXISTS public.finance_caisses (
  company_id uuid PRIMARY KEY,
  caisse2_montant numeric NOT NULL DEFAULT 0 CHECK (caisse2_montant >= 0),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.finance_caisses ENABLE ROW LEVEL SECURITY;
