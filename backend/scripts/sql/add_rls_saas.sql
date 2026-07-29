-- ============================================================================
-- Renforcement multi-entreprises (SaaS) : RLS + policies par company_id
-- ----------------------------------------------------------------------------
-- À exécuter dans Supabase SQL Editor.
--
-- Contexte :
--   Le schema_starter.sql active déjà la RLS sur les tables de base (profiles,
--   clients, commandes, stocks, tresorerie_mouvements, bandes, alertes,
--   crm_interactions, crm_taches). Ce script complète l'isolation pour les
--   tables ajoutées ensuite (reproduction, santé, cheptel, roadmap).
--
-- IMPORTANT :
--   Le backend Node utilise la clé SERVICE ROLE de Supabase, qui CONTOURNE la
--   RLS. L'isolation applicative repose donc sur le filtrage `.eq('company_id')`
--   déjà présent dans le code. Ces policies constituent une DÉFENSE EN PROFONDEUR
--   pour tout accès direct effectué avec une clé anon / un token utilisateur
--   (ex. si un jour le mobile parle directement à Supabase).
--
-- Idempotent : peut être ré-exécuté sans risque.
-- ============================================================================

-- Fonction utilitaire : company_id de l'utilisateur courant (auth.uid()).
create or replace function public.current_company_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select p.company_id from public.profiles p where p.id = auth.uid()
$$;

-- ---------------------------------------------------------------------------
-- cheptels
-- ---------------------------------------------------------------------------
alter table public.cheptels enable row level security;
drop policy if exists cheptels_all_own_company on public.cheptels;
create policy cheptels_all_own_company on public.cheptels
for all using (
  company_id = public.current_company_id()
) with check (
  company_id = public.current_company_id()
);

-- ---------------------------------------------------------------------------
-- couvees (module reproduction)
-- ---------------------------------------------------------------------------
alter table public.couvees enable row level security;
drop policy if exists couvees_all_own_company on public.couvees;
create policy couvees_all_own_company on public.couvees
for all using (
  company_id = public.current_company_id()
) with check (
  company_id = public.current_company_id()
);

-- ---------------------------------------------------------------------------
-- protocoles_vaccinaux (module santé)
-- ---------------------------------------------------------------------------
alter table public.protocoles_vaccinaux enable row level security;
drop policy if exists protocoles_all_own_company on public.protocoles_vaccinaux;
create policy protocoles_all_own_company on public.protocoles_vaccinaux
for all using (
  company_id = public.current_company_id()
) with check (
  company_id = public.current_company_id()
);

-- ---------------------------------------------------------------------------
-- traitements_sanitaires (module santé)
-- ---------------------------------------------------------------------------
alter table public.traitements_sanitaires enable row level security;
drop policy if exists traitements_all_own_company on public.traitements_sanitaires;
create policy traitements_all_own_company on public.traitements_sanitaires
for all using (
  company_id = public.current_company_id()
) with check (
  company_id = public.current_company_id()
);

-- ---------------------------------------------------------------------------
-- roadmap_plans (company_id est la clé primaire)
-- ---------------------------------------------------------------------------
alter table public.roadmap_plans enable row level security;
drop policy if exists roadmap_plans_all_own_company on public.roadmap_plans;
create policy roadmap_plans_all_own_company on public.roadmap_plans
for all using (
  company_id = public.current_company_id()
) with check (
  company_id = public.current_company_id()
);

-- ============================================================================
-- Vérification (facultatif) :
--   select tablename, rowsecurity
--   from pg_tables
--   where schemaname = 'public'
--     and tablename in (
--       'cheptels','couvees','protocoles_vaccinaux',
--       'traitements_sanitaires','roadmap_plans'
--     );
-- ============================================================================
