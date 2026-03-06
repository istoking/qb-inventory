local QBCore = exports['qb-core']:GetCoreObject()

-- This file handles background maintenance tasks to avoid heavy DB spikes on restart:
-- 1) Purge persisted drop-* inventories (drops should not persist).
-- 2) Purge orphaned trunk-/glovebox- inventories that no longer have a matching vehicle plate.

local function DebugPrint(enabled, msg)
    if enabled then
        print(('[qb-inventory][maintenance] %s'):format(msg))
    end
end

local function Clamp(n, min, max)
    if n < min then return min end
    if n > max then return max end
    return n
end

local function Sleep(ms)
    Wait(ms)
end

CreateThread(function()
    -- Start delay (use the larger of the configured delays, so we don't spike on boot)
    local startDelay = 120
    if Config.DropDBPurge and Config.DropDBPurge.startDelaySeconds then
        startDelay = math.max(startDelay, tonumber(Config.DropDBPurge.startDelaySeconds) or 120)
    end
    if Config.OrphanCleanup and Config.OrphanCleanup.startDelaySeconds then
        startDelay = math.max(startDelay, tonumber(Config.OrphanCleanup.startDelaySeconds) or 120)
    end

    Sleep(startDelay * 1000)

    while true do
        -- 1) Drop DB purge
        if Config.DropDBPurge and Config.DropDBPurge.enabled then
            local interval = Clamp(tonumber(Config.DropDBPurge.intervalMinutes) or 10, 1, 1440)
            local batch = Clamp(tonumber(Config.DropDBPurge.batchSize) or 50, 1, 500)
            local debug = Config.DropDBPurge.debug == true

            -- Drops should not persist. Purge any persisted drop-* identifiers in small batches.
            local affected = MySQL.update('DELETE FROM inventories WHERE identifier LIKE ? LIMIT ?', { 'drop-%', batch })
            if affected and affected > 0 then
                DebugPrint(debug, ('Purged %d persisted drop inventories'):format(affected))
            end

            -- 2) Orphan cleanup (run on same cadence as drop purge; cheap when nothing to delete)
            if Config.OrphanCleanup and Config.OrphanCleanup.enabled then
                local oBatch = Clamp(tonumber(Config.OrphanCleanup.batchSize) or batch, 1, 500)
                local oDebug = Config.OrphanCleanup.debug == true
                local vehicleTable = (Config.OrphanCleanup.vehicleTable and tostring(Config.OrphanCleanup.vehicleTable)) or 'player_vehicles'
                local plateColumn = (Config.OrphanCleanup.plateColumn and tostring(Config.OrphanCleanup.plateColumn)) or 'plate'

                -- trunk-<plate> : prefix length = 6, plate starts at position 7 (1-indexed)
                local trunkSql = ('DELETE i FROM inventories i LEFT JOIN %s v ON v.%s = SUBSTRING(i.identifier, 7) WHERE i.identifier LIKE ? AND v.%s IS NULL LIMIT ?')
                    :format(vehicleTable, plateColumn, plateColumn)
                local trunkDeleted = MySQL.update(trunkSql, { 'trunk-%', oBatch })
                if trunkDeleted and trunkDeleted > 0 then
                    DebugPrint(oDebug, ('Purged %d orphaned trunk inventories'):format(trunkDeleted))
                end

                -- glovebox-<plate> : prefix length = 9, plate starts at position 10 (1-indexed)
                local gloveSql = ('DELETE i FROM inventories i LEFT JOIN %s v ON v.%s = SUBSTRING(i.identifier, 10) WHERE i.identifier LIKE ? AND v.%s IS NULL LIMIT ?')
                    :format(vehicleTable, plateColumn, plateColumn)
                local gloveDeleted = MySQL.update(gloveSql, { 'glovebox-%', oBatch })
                if gloveDeleted and gloveDeleted > 0 then
                    DebugPrint(oDebug, ('Purged %d orphaned glovebox inventories'):format(gloveDeleted))
                end
            end

            Sleep(interval * 60000)
        else
            -- If drop purge is disabled, fall back to orphan interval (or 10 min) so we don't spin.
            local interval = 10
            if Config.OrphanCleanup and Config.OrphanCleanup.intervalMinutes then
                interval = Clamp(tonumber(Config.OrphanCleanup.intervalMinutes) or 10, 1, 1440)
            end
            Sleep(interval * 60000)
        end
    end
end)
