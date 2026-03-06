-- Deletes orphaned vehicle inventories from qb-inventory `inventories` table.
-- Orphaned = trunk-/glovebox- identifier whose plate is NOT present in player_vehicles.
-- Uses REPLACE to handle plates with spaces.

DELETE i
FROM inventories i
LEFT JOIN player_vehicles pv
  ON REPLACE(pv.plate, ' ', '') = REPLACE(SUBSTRING(i.identifier, LOCATE('-', i.identifier) + 1), ' ', '')
WHERE (i.identifier LIKE 'glovebox-%' OR i.identifier LIKE 'trunk-%')
  AND pv.plate IS NULL;
