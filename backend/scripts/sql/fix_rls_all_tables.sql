-- ============================================================================
-- Correctif SÉCURITÉ : activer Row-Level Security (RLS) sur TOUTES les tables
-- publiques restantes signalées par Supabase (rls_disabled_in_public).
-- ----------------------------------------------------------------------------
-- À exécuter dans Supabase : Dashboard > SQL Editor > New query > coller > Run.
--
-- CONTEXTE IMPORTANT :
--   Le backend Node utilise la clé SERVICE ROLE, qui CONTOURNE la RLS.
--   Activer la RLS ci-dessous NE CASSE donc PAS l'application : toutes les
--   requêtes serveur continuent de fonctionner normalement.
--   Ces règles bloquent uniquement les accès directs faits avec une clé anon
--   ou un token utilisateur (ce qui est précisément la faille signalée).
--
--   - Tables rattachées à une entreprise  -> policy par company_id (défense en profondeur)
--   - Tables globales / sensibles          -> RLS activée SANS policy permissive
--     (donc AUCUN accès via anon/authenticated ; seul le service role passe).
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
-- TABLES RATTACHÉES À UNE ENTREPRISE (isolation par company_id)
-- ---------------------------------------------------------------------------

-- achats (module demandes d'achat)
alter table public.achats enable row level security;
drop policy if exists achats_all_own_company on public.achats;
create policy achats_all_own_company on public.achats
for all using (
  company_id = public.current_company_id()
) with check (
  company_id = public.current_company_id()
);

-- cheptels (module cheptel) — repris ici au cas où add_rls_saas.sql n'aurait pas été exécuté
alter table public.cheptels enable row level security;
drop policy if exists cheptels_all_own_company on public.cheptels;
create policy cheptels_all_own_company on public.cheptels
for all using (
  company_id = public.current_company_id()
) with check (
  company_id = public.current_company_id()
);

-- couvees (module reproduction)
alter table public.couvees enable row level security;
drop policy if exists couvees_all_own_company on public.couvees;
create policy couvees_all_own_company on public.couvees
for all using (
  company_id = public.current_company_id()
) with check (
  company_id = public.current_company_id()
);

-- protocoles_vaccinaux (module santé)
alter table public.protocoles_vaccinaux enable row level security;
drop policy if exists protocoles_all_own_company on public.protocoles_vaccinaux;
create policy protocoles_all_own_company on public.protocoles_vaccinaux
for all using (
  company_id = public.current_company_id()
) with check (
  company_id = public.current_company_id()
);

-- traitements_sanitaires (module santé)
alter table public.traitements_sanitaires enable row level security;
drop policy if exists traitements_all_own_company on public.traitements_sanitaires;
create policy traitements_all_own_company on public.traitements_sanitaires
for all using (
  company_id = public.current_company_id()
) with check (
  company_id = public.current_company_id()
);

-- roadmap_plans (company_id est la clé primaire)
alter table public.roadmap_plans enable row level security;
drop policy if exists roadmap_plans_all_own_company on public.roadmap_plans;
create policy roadmap_plans_all_own_company on public.roadmap_plans
for all using (
  company_id = public.current_company_id()
) with check (
  company_id = public.current_company_id()
);

-- ---------------------------------------------------------------------------
-- entreprises : chaque utilisateur ne voit QUE sa propre entreprise
-- ---------------------------------------------------------------------------
alter table public.entreprises enable row level security;
drop policy if exists entreprises_select_own on public.entreprises;
create policy entreprises_select_own on public.entreprises
for select using (
  id = public.current_company_id()
);

-- ---------------------------------------------------------------------------
-- TABLES GLOBALES / SENSIBLES : RLS activée, AUCUNE policy permissive.
-- => inaccessibles via anon/authenticated ; seul le backend (service role) passe.
-- ---------------------------------------------------------------------------

-- app_config : configuration applicative (gérée uniquement par le backend).
alter table public.app_config enable row level security;

-- audit_logs : journal d'audit (jamais exposé aux clients).
alter table public.audit_logs enable row level security;

-- password_reset_tokens : jetons de réinitialisation (TRÈS sensible).
alter table public.password_reset_tokens enable row level security;

-- onboarding_codes : codes de création d'exploitation (sensible).
alter table public.onboarding_codes enable row level security;

-- ---------------------------------------------------------------------------
-- FILET DE SÉCURITÉ GÉNÉRIQUE : force RLS = true sur TOUTE table publique
-- restante (y compris toute table future non listée ci-dessus).
-- Garantit qu'aucune table du schéma public ne reste sans RLS.
-- ---------------------------------------------------------------------------
do $$
declare
  r record;
begin
  for r in
    select tablename
    from pg_tables
    where schemaname = 'public'
      and rowsecurity = false
  loop
    execute format('alter table public.%I enable row level security;', r.tablename);
    raise notice 'RLS activée sur la table: %', r.tablename;
  end loop;
end $$;

-- ============================================================================
-- Vérification : toutes les lignes doivent afficher rowsecurity = true.
-- ============================================================================
select tablename, rowsecurity
from pg_tables
where schemaname = 'public'
order by rowsecurity asc, tablename;
