-- Create the roadmap_plans table so production planning is persisted server-side
-- (one row per company) instead of only in the device local storage.
--
-- Safe to run multiple times (idempotent). Run it in the Supabase SQL Editor
-- (Dashboard > SQL Editor > New query > paste > Run).

CREATE TABLE IF NOT EXISTS public.roadmap_plans (
  company_id       uuid PRIMARY KEY,
  data             jsonb NOT NULL DEFAULT '[]'::jsonb,
  selected_plan_id text,
  updated_at       timestamptz NOT NULL DEFAULT now()
);

-- (Optional) verification:
-- SELECT company_id, jsonb_array_length(data) AS nb_plans, selected_plan_id, updated_at
-- FROM public.roadmap_plans;
