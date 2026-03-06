local function RandomBetween(min, max)
    min = tonumber(min) or 0
    max = tonumber(max) or 0
    if max < min then max = min end
    if max == min then return min end
    return math.random(min, max)
end

local function DoVehicleInventoryCleanup()
    local result = MySQL.update.await([[
        DELETE i FROM inventories i
        LEFT JOIN player_vehicles pv
            ON REPLACE(pv.plate, ' ', '') = REPLACE(SUBSTRING(i.identifier, LOCATE('-', i.identifier) + 1), ' ', '')
        WHERE (i.identifier LIKE 'glovebox-%' OR i.identifier LIKE 'trunk-%')
          AND pv.plate IS NULL
    ]])

    print(('[qb-inventory] Daily cleanup: removed %s orphan vehicle inventories from inventories table.'):format(result or 0))
end

local function SecondsUntilNextRun(hour, minute)
    local now = os.date('*t')
    local target = os.date('*t')
    target.hour = hour
    target.min = minute
    target.sec = 0

    local nowTs = os.time(now)
    local targetTs = os.time(target)

    if targetTs <= nowTs then
        -- schedule for tomorrow
        targetTs = targetTs + 86400
    end

    return math.max(1, targetTs - nowTs)
end

CreateThread(function()
    local cfg = (Config and Config.InventoryCleanup) or {}
    if not cfg.enabled then
        return
    end

    -- Seed RNG for jitter
    math.randomseed(GetGameTimer())

    while true do
        local hour = tonumber(cfg.hour) or 4
        local minute = tonumber(cfg.minute) or 0
        local waitSeconds = SecondsUntilNextRun(hour, minute)

        Wait(waitSeconds * 1000)

        local jitter = cfg.jitterMs or { 0, 0 }
        local jitterMs = RandomBetween(jitter[1], jitter[2])
        if jitterMs > 0 then
            Wait(jitterMs)
        end

        DoVehicleInventoryCleanup()
        -- loop schedules next run
    end
end)
