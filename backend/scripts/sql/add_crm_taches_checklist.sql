-- CRM premium : sous-étapes (checklist) des tâches / relances, façon Microsoft Planner.
-- Format : [{"titre": "Envoyer le devis", "fait": false}, ...]
--
-- Idempotent : peut être exécuté plusieurs fois (Supabase > SQL Editor > Run).
-- Tant que ce script n'est pas exécuté, le backend enregistre les tâches sans checklist.

ALTER TABLE public.crm_taches
  ADD COLUMN IF NOT EXISTS checklist jsonb NOT NULL DEFAULT '[]'::jsonb;
