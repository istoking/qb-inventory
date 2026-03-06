QBCore = QBCore or exports['qb-core']:GetCoreObject()
Inventories = Inventories or {}
Drops = Drops or {}
RegisteredShops = RegisteredShops or {}

Config = Config or {}
Config.InventoryPerformance = Config.InventoryPerformance or {
    LazyLoad = {
        enabled = true,
    },
    Save = {
        enabled = true,
        intervalSeconds = 30,
        batchSize = 75,
        debounceSeconds = 5,
        flushOnClose = true,
    },
    Cache = {
        enabled = true,
        evictIntervalSeconds = 300,
        idleTtlSeconds = 900,
        maxCachedInventories = 1000,
    },
    RateLimit = {
        enabled = true,
        buckets = {
            openDrop = { windowMs = 1000, max = 4 },
            createDrop = { windowMs = 2500, max = 8 },
            moveItem = { windowMs = 1200, max = 25 },
            giveItem = { windowMs = 3000, max = 6 },
            purchase = { windowMs = 3000, max = 8 },
        }
    },
    Logging = {
        enabled = true,
        logPlayerItemChanges = false,
        logExternalInventoryChanges = false,
        logSetInventoryPayload = false,
        logBlockedActions = true,
    },
}

local Perf = {
    meta = {},
    rateLimits = {},
}

local function PerfCfg()
    return Config.InventoryPerformance or {}
end

local function SafeDecodeItems(raw)
    if not raw or raw == '' then return {} end
    local ok, decoded = pcall(json.decode, raw)
    if not ok or type(decoded) ~= 'table' then
        return {}
    end
    return decoded
end

local function UpsertInventoryDefaults(identifier, data, items)
    local inv = Inventories[identifier]
    if not inv then
        inv = {
            items = items or {},
            isOpen = false,
            label = data and data.label or identifier,
            maxweight = data and data.maxweight or Config.StashSize.maxweight,
            slots = data and data.slots or Config.StashSize.slots,
            dirty = false,
        }
        Inventories[identifier] = inv
    else
        if items then inv.items = items end
        inv.label = (data and data.label) or inv.label or identifier
        inv.maxweight = (data and data.maxweight) or inv.maxweight or Config.StashSize.maxweight
        inv.slots = (data and data.slots) or inv.slots or Config.StashSize.slots
        if inv.isOpen == nil then inv.isOpen = false end
        if inv.dirty == nil then inv.dirty = false end
    end
    return inv
end

function TouchInventory(identifier)
    if not identifier or type(identifier) ~= 'string' then return end
    local now = os.time()
    Perf.meta[identifier] = Perf.meta[identifier] or {}
    Perf.meta[identifier].lastAccess = now
end

function EnsureInventoryLoaded(identifier, data)
    if not identifier or type(identifier) ~= 'string' then return nil end

    local existing = Inventories[identifier]
    if existing then
        UpsertInventoryDefaults(identifier, data)
        TouchInventory(identifier)
        return existing
    end

    local items = {}
    local lazyEnabled = not PerfCfg().LazyLoad or PerfCfg().LazyLoad.enabled ~= false
    if lazyEnabled and MySQL and MySQL.single and MySQL.single.await then
        local row = MySQL.single.await('SELECT items FROM inventories WHERE identifier = ?', { identifier })
        if row and row.items then
            items = SafeDecodeItems(row.items)
        end
    end

    local inv = UpsertInventoryDefaults(identifier, data, items)
    local now = os.time()
    Perf.meta[identifier] = Perf.meta[identifier] or {}
    Perf.meta[identifier].loadedAt = now
    Perf.meta[identifier].lastAccess = now
    Perf.meta[identifier].lastDirtyAt = 0
    Perf.meta[identifier].lastSavedAt = 0
    return inv
end

function MarkInventoryDirty(identifier)
    if not identifier or type(identifier) ~= 'string' then return end
    local inv = Inventories[identifier]
    if not inv then return end
    inv.dirty = true
    local now = os.time()
    Perf.meta[identifier] = Perf.meta[identifier] or {}
    Perf.meta[identifier].lastDirtyAt = now
    Perf.meta[identifier].lastAccess = now
end

function FlushInventoryNow(identifier, force)
    if not identifier or type(identifier) ~= 'string' then return false end
    local inv = Inventories[identifier]
    if not inv then return false end
    if not force and not inv.dirty then return false end

    local encoded = json.encode(inv.items or {})
    MySQL.prepare.await(
        'INSERT INTO inventories (identifier, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = VALUES(items)',
        { identifier, encoded }
    )

    inv.dirty = false
    local now = os.time()
    Perf.meta[identifier] = Perf.meta[identifier] or {}
    Perf.meta[identifier].lastSavedAt = now
    Perf.meta[identifier].lastAccess = now
    return true
end

function FlushDirtyInventories(force, maxBatch)
    local flushed = 0
    local cfg = PerfCfg().Save or {}
    local debounceSeconds = math.max(0, tonumber(cfg.debounceSeconds) or 5)
    local batchSize = math.max(1, tonumber(maxBatch or cfg.batchSize) or 75)
    local now = os.time()

    for identifier, inv in pairs(Inventories) do
        if type(identifier) == 'string' and inv and inv.dirty then
            local meta = Perf.meta[identifier] or {}
            local dirtyAge = now - (meta.lastDirtyAt or 0)
            if force or dirtyAge >= debounceSeconds then
                if FlushInventoryNow(identifier, true) then
                    flushed = flushed + 1
                    if flushed >= batchSize then
                        break
                    end
                end
            end
        end
    end

    return flushed
end

function EvictIdleInventories(maxBatch)
    local cfg = PerfCfg().Cache or {}
    if cfg.enabled == false then return 0 end

    local ttl = math.max(60, tonumber(cfg.idleTtlSeconds) or 900)
    local maxCached = math.max(50, tonumber(cfg.maxCachedInventories) or 1000)
    local now = os.time()
    local count = 0
    local ids = {}

    for identifier, inv in pairs(Inventories) do
        if type(identifier) == 'string' and inv then
            count = count + 1
            local meta = Perf.meta[identifier] or {}
            local idleFor = now - (meta.lastAccess or meta.loadedAt or now)
            if not inv.isOpen and not inv.dirty and idleFor >= ttl then
                ids[#ids + 1] = identifier
            end
        end
    end

    if count <= maxCached and #ids == 0 then
        return 0
    end

    local target = math.max(1, tonumber(maxBatch) or 100)
    local evicted = 0

    for i = 1, #ids do
        if evicted >= target and count <= maxCached then break end
        Inventories[ids[i]] = nil
        Perf.meta[ids[i]] = nil
        count = count - 1
        evicted = evicted + 1
    end

    if count > maxCached then
        for identifier, inv in pairs(Inventories) do
            if evicted >= target then break end
            if type(identifier) == 'string' and inv and not inv.isOpen and not inv.dirty then
                Inventories[identifier] = nil
                Perf.meta[identifier] = nil
                evicted = evicted + 1
                count = count - 1
                if count <= maxCached then break end
            end
        end
    end

    return evicted
end

function InventoryShouldLog(kind, identifier)
    local cfg = PerfCfg().Logging or {}
    if cfg.enabled == false then return false end
    local isPlayer = type(identifier) == 'number'
    if kind == 'set' then
        return cfg.logSetInventoryPayload == true
    end
    if isPlayer then
        return cfg.logPlayerItemChanges == true
    end
    return cfg.logExternalInventoryChanges == true
end

function InventoryLogBlockedAction(title, message)
    local cfg = PerfCfg().Logging or {}
    if cfg.enabled == false or cfg.logBlockedActions == false then return end
    TriggerEvent('qb-log:server:CreateLog', 'playerinventory', title, 'yellow', message)
end

function CheckInventoryRateLimit(src, bucket)
    local rlCfg = PerfCfg().RateLimit or {}
    if rlCfg.enabled == false then return false end
    local bucketCfg = rlCfg.buckets and rlCfg.buckets[bucket]
    if not bucketCfg then return false end

    local now = GetGameTimer()
    local windowMs = math.max(250, tonumber(bucketCfg.windowMs) or 1000)
    local maxHits = math.max(1, tonumber(bucketCfg.max) or 5)

    Perf.rateLimits[src] = Perf.rateLimits[src] or {}
    local entry = Perf.rateLimits[src][bucket]
    if not entry or (now - entry.startedAt) > windowMs then
        Perf.rateLimits[src][bucket] = { startedAt = now, count = 1 }
        return false
    end

    entry.count = entry.count + 1
    if entry.count > maxHits then
        return true
    end

    return false
end

AddEventHandler('playerDropped', function()
    Perf.rateLimits[source] = nil
end)

function IsCurrencyRestrictedItem(itemName)
    local guard = Config.CurrencyGuardrails
    if not guard or guard.enabled == false then return false end
    if not itemName then return false end
    return guard.items and guard.items[tostring(itemName):lower()] == true
end

function CanStoreRestrictedItemInInventory(itemName, inventoryId)
    if not IsCurrencyRestrictedItem(itemName) then
        return true
    end

    local guard = Config.CurrencyGuardrails or {}
    if not inventoryId or inventoryId == 'player' then
        return true
    end

    if inventoryId:find('otherplayer%-') == 1 then
        return guard.allowOtherPlayers ~= false
    elseif inventoryId:find('drop%-') == 1 then
        return guard.allowDrops ~= false
    elseif inventoryId:find('trunk%-') == 1 or inventoryId:find('glovebox%-') == 1 then
        return guard.allowVehicles ~= false
    elseif inventoryId:find('backpack%-') == 1 then
        return guard.allowBackpacks ~= false
    elseif inventoryId:find('shop%-') == 1 then
        return false
    end

    return guard.allowStashes ~= false
end

CreateThread(function()
    local cfg = PerfCfg().Save or {}
    if cfg.enabled == false then return end
    local interval = math.max(5, tonumber(cfg.intervalSeconds) or 30)
    local batchSize = math.max(1, tonumber(cfg.batchSize) or 75)
    while true do
        Wait(interval * 1000)
        FlushDirtyInventories(false, batchSize)
    end
end)

CreateThread(function()
    local cfg = PerfCfg().Cache or {}
    if cfg.enabled == false then return end
    local interval = math.max(60, tonumber(cfg.evictIntervalSeconds) or 300)
    while true do
        Wait(interval * 1000)
        EvictIdleInventories(150)
    end
end)
