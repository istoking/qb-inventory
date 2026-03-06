Config = Config or {}

-- Inventory Cleanup
-- This prevents the inventories table from filling up with glovebox/trunk entries from unowned/local vehicles.
-- Owned vehicles (player_vehicles) are persistent; unowned vehicles are handled as temporary in-memory inventories.
Config.InventoryCleanup = Config.InventoryCleanup or {
    enabled = true,

    -- Run once per day at this server-local time.
    hour = 4,
    minute = 0,

    -- Add a small random delay (in ms) so multiple delete operations don't hit the DB at exactly the same moment.
    jitterMs = { 0, 300000 }, -- 0 to 5 minutes
}
