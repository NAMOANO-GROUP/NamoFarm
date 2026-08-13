-- Module Achats : demandes d'achat avec workflow de validation
-- Statuts : en_attente → valide → recu  /  en_attente → refuse
-- À exécuter dans Supabase SQL Editor

CREATE TABLE IF NOT EXISTS achats (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id            UUID NOT NULL,
  titre                 TEXT NOT NULL,
  article               TEXT NOT NULL,
  categorie             TEXT NOT NULL DEFAULT 'autre',  -- aliment, medicament, vitamine, materiel, autre
  quantite              NUMERIC(10,2) NOT NULL DEFAULT 0,
  unite                 TEXT NOT NULL DEFAULT 'unité',
  fournisseur           TEXT,
  prix_unitaire_estime  NUMERIC(12,2) DEFAULT 0,
  montant_estime        NUMERIC(12,2) DEFAULT 0,
  urgence               TEXT NOT NULL DEFAULT 'normale',  -- faible, normale, haute, urgente
  motif                 TEXT,
  statut                TEXT NOT NULL DEFAULT 'en_attente',  -- en_attente, valide, refuse, recu
  demandeur_nom         TEXT,
  demandeur_prenom      TEXT,
  validateur_nom        TEXT,
  validateur_prenom     TEXT,
  notes_validation      TEXT,
  stock_id              UUID,  -- stock Supabase lié (optionnel)
  date_demande          TIMESTAMPTZ DEFAULT NOW(),
  date_validation       TIMESTAMPTZ,
  date_reception        TIMESTAMPTZ,
  created_at            TIMESTAMPTZ DEFAULT NOW(),
  updated_at            TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS achats_company_id_idx ON achats(company_id);
CREATE INDEX IF NOT EXISTS achats_statut_idx     ON achats(statut);
CREATE INDEX IF NOT EXISTS achats_created_at_idx ON achats(created_at DESC);
