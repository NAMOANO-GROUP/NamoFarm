-- Finance : budget mensuel par poste de dépense (Aliment, Salaires, Transport...).
-- `poste` reprend le « type » des dépenses (ex. 'Alimentation', 'Salaire Prime etc').
--
-- Idempotent : peut être exécuté plusieurs fois (Supabase > SQL Editor > Run).
-- Tant que ce script n'est pas exécuté, l'onglet Budget de l'application indique simplement
-- que les budgets ne sont pas encore activés ; le reste de la Finance fonctionne normalement.

CREATE TABLE IF NOT EXISTS public.finance_budgets (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id      uuid NOT NULL REFERENCES public.entreprises(id) ON DELETE CASCADE,
  poste           text NOT NULL,
  montant_mensuel numeric(14,2) NOT NULL DEFAULT 0 CHECK (montant_mensuel >= 0),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (company_id, poste)
);

CREATE INDEX IF NOT EXISTS idx_finance_budgets_company_id ON public.finance_budgets(company_id);

-- Fonction utilitaire (déjà créée par fix_rls_all_tables.sql ; recréée ici pour rendre le script autonome).
CREATE OR REPLACE FUNCTION public.current_company_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p.company_id FROM public.profiles p WHERE p.id = auth.uid()
$$;

-- Même isolation par entreprise que les autres tables (le backend, en service role, n'est pas concerné).
ALTER TABLE public.finance_budgets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS finance_budgets_all_own_company ON public.finance_budgets;
CREATE POLICY finance_budgets_all_own_company ON public.finance_budgets
FOR ALL USING (company_id = public.current_company_id())
WITH CHECK (company_id = public.current_company_id());

NOTIFY pgrst, 'reload schema';
