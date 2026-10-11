-- Ajoute les colonnes manquantes à tresorerie_mouvements.
-- Nécessaire pour la ventilation en comptabilité par bande
-- (Coût poussins = type "Achat de sujet", Prophylaxie = type "Prophylaxie").
-- Sans ces colonnes, le type/catégorie des dépenses n'est pas stocké.

ALTER TABLE public.tresorerie_mouvements
  ADD COLUMN IF NOT EXISTS type text NOT NULL DEFAULT '';

ALTER TABLE public.tresorerie_mouvements
  ADD COLUMN IF NOT EXISTS categorie text NOT NULL DEFAULT '';
