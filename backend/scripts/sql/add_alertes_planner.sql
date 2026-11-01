-- Todo façon Microsoft Planner : personne assignée, sous-étapes (checklist) et avancement.
-- checklist : [{"titre": "Désinfecter les abreuvoirs", "fait": false}, ...]
-- progression : 'a_faire' | 'en_cours' (le statut 'active' / 'faite' reste inchangé).
--
-- Idempotent : peut être exécuté plusieurs fois (Supabase > SQL Editor > Run).
-- Tant que ce script n'est pas exécuté, le backend enregistre les tâches sans ces informations.

ALTER TABLE public.alertes ADD COLUMN IF NOT EXISTS assigne_a text NOT NULL DEFAULT '';
ALTER TABLE public.alertes ADD COLUMN IF NOT EXISTS checklist jsonb NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE public.alertes ADD COLUMN IF NOT EXISTS progression text NOT NULL DEFAULT 'a_faire';
