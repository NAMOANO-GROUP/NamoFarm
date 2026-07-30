-- Codes d'inscription à USAGE UNIQUE pour l'onboarding en libre-service.
--
-- Chaque code permet de créer UNE seule nouvelle exploitation (entreprise + admin).
-- Une fois utilisé (used_at renseigné), il ne fonctionne plus jamais.
-- La table est globale (non rattachée à une entreprise) car elle sert justement
-- à créer de nouvelles entreprises.
--
-- Idempotent : peut être exécuté plusieurs fois sans risque.
-- À lancer dans Supabase (Dashboard > SQL Editor > New query > coller > Run).

CREATE TABLE IF NOT EXISTS public.onboarding_codes (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code          text NOT NULL UNIQUE,
  label         text,
  used_at       timestamptz,
  used_by_email text,
  company_id    uuid,
  expires_at    timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- Recherche rapide par code lors de l'onboarding.
CREATE INDEX IF NOT EXISTS onboarding_codes_code_idx ON public.onboarding_codes (code);

-- (Optionnel) vérification :
-- SELECT code, label,
--        CASE WHEN used_at IS NULL THEN 'disponible' ELSE 'utilisé' END AS statut,
--        used_by_email, expires_at, created_at
-- FROM public.onboarding_codes
-- ORDER BY created_at DESC;
