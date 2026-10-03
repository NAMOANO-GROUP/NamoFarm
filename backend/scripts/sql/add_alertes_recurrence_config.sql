-- Configuration détaillée de récurrence pour les tâches périodiques (todo) :
--   * hebdomadaire : { "joursSemaine": [1,3,5] }   (1=lundi ... 7=dimanche, ISO)
--   * mensuel      : { "jourMois": 15 }
--   * annuel       : { "mois": 3, "jourMois": 15 }
--
-- Idempotent. À lancer dans Supabase (SQL Editor > New query > coller > Run).

ALTER TABLE public.alertes ADD COLUMN IF NOT EXISTS recurrence_config jsonb NOT NULL DEFAULT '{}'::jsonb;
