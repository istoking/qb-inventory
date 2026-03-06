-- Backpack logic merged into qb-inventory
-- Provides: usable backpack items that open a unique stash per backpack instance,
-- carry limits, nested-backpack prevention, and per-backpack whitelist/blacklist.
local QBCore = exports['qb-core']:GetCoreObject()

Backpacks = Backpacks or {}

local function DebugPrint(msg)
    if Config.Backpacks and Config.Backpacks.Debug then
        print(('^3[qb-inventory:backpacks]^0 %s'):format(msg))
    end
end

local function Notify(src, msg, msgType)
    TriggerClientEvent('QBCore:Notify', src, msg, msgType or 'primary')
end

local BackpackDefs = {}
local BackpackItems = {}

local OpenBackpackStashes = {}  -- stashId -> { src, itemName, backpackId, ts }

local function NormalizeItemName(name)
    return (type(name) == 'string' and name:lower()) or name
end

local function BuildCaches()
    BackpackDefs = {}
    BackpackItems = {}

    if not Config.Backpacks or not Config.Backpacks.Definitions then return end

    for _, def in ipairs(Config.Backpacks.Definitions) do
        if def and def.item then
            local itemName = NormalizeItemName(def.item)
            local entry = {
                item = itemName,
                label = def.label or 'Backpack',
                slots = tonumber(def.slots) or 20,
                maxweight = tonumber(def.maxweight) or 200000,
                jobLock = def.jobLock,
                whitelist = def.whitelist,
                blacklist = def.blacklist,
            }

            if entry.whitelist and type(entry.whitelist) == 'table' then
                local wl = {}
                for _, v in ipairs(entry.whitelist) do
                    wl[NormalizeItemName(v)] = true
                end
                entry.whitelist = wl
            end

            if entry.blacklist and type(entry.blacklist) == 'table' then
                local bl = {}
                for _, v in ipairs(entry.blacklist) do
                    bl[NormalizeItemName(v)] = true
                end
                entry.blacklist = bl
            end

            BackpackDefs[itemName] = entry
            BackpackItems[itemName] = true
        end
    end
end

local function IsBackpack(itemName)
    itemName = NormalizeItemName(itemName)
    return itemName and BackpackItems[itemName] == true
end

local function GetBackpackDef(itemName)
    itemName = NormalizeItemName(itemName)
    return itemName and BackpackDefs[itemName] or nil
end

local function GenerateId()
    local chars = 'abcdefghijklmnopqrstuvwxyz0123456789'
    local id = ''
    for _ = 1, 10 do
        local rand = math.random(1, #chars)
        id = id .. chars:sub(rand, rand)
    end
    return id
end

local function GetItemMeta(item)
    if not item then return {} end
    if type(item.info) == 'table' then return item.info end
    return {}
end

local function CountPlayerBackpacks(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Player.PlayerData or not Player.PlayerData.items then return 0 end
    local count = 0
    for _, item in pairs(Player.PlayerData.items) do
        if item and item.name and IsBackpack(item.name) then
            count += 1
        end
    end
    return count
end

local function CheckJobLock(src, def)
    if not def or not def.jobLock then return true end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end

    local job = Player.PlayerData.job and Player.PlayerData.job.name
    local grade = Player.PlayerData.job and Player.PlayerData.job.grade and Player.PlayerData.job.grade.level

    local jobs = def.jobLock.jobs or {}
    local grades = def.jobLock.grades or {}

    local jobAllowed = false
    for _, j in ipairs(jobs) do
        if job == j then
            jobAllowed = true
            break
        end
    end
    if not jobAllowed then return false end

    if not grades or #grades == 0 then return true end
    for _, g in ipairs(grades) do
        if grade == g then
            return true
        end
    end
    return false
end

local function IsItemAllowedInBackpack(def, itemName)
    if not def or not itemName then return true end
    itemName = NormalizeItemName(itemName)

    if def.whitelist then
        return def.whitelist[itemName] == true
    end
    if def.blacklist then
        return def.blacklist[itemName] ~= true
    end
    return true
end

local function MakeStashId(backpackId)
    return ('backpack-%s'):format(backpackId)
end

local function EnsureBackpackMetadata(src, item, def)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return nil, nil end

    local meta = GetItemMeta(item)
    local backpackId = meta.ID or meta.id or meta.backpackId

    if not backpackId then
        backpackId = GenerateId()
        meta.ID = backpackId
        meta.backpackId = backpackId
        meta.backpackType = def.item
        meta.slots = def.slots
        meta.maxweight = def.maxweight
        meta.quality = meta.quality or 100

        item.info = meta
        Player.Functions.SetInventory(Player.PlayerData.items)
        DebugPrint(('Assigned new backpackId %s for %s'):format(backpackId, def.item))
    else
        -- Normalize fields for future-proofing
        meta.ID = meta.ID or backpackId
        meta.backpackId = meta.backpackId or backpackId
        meta.backpackType = meta.backpackType or def.item
        item.info = meta
    end

    return meta, backpackId
end

local function OpenBackpack(src, item)
    if not item or not item.name then return end
    local itemName = NormalizeItemName(item.name)
    local def = GetBackpackDef(itemName)
    if not def then return end

    if not CheckJobLock(src, def) then
        Notify(src, 'This backpack is restricted to certain jobs.', 'error')
        return
    end

    if Config.Backpacks and Config.Backpacks.RestrictMultipleBackpacks then
        local count = CountPlayerBackpacks(src)
        if count > (Config.Backpacks.MaxAllowedBackpacks or 2) then
            Notify(src, ('You can only carry %d backpacks.'):format(Config.Backpacks.MaxAllowedBackpacks or 2), 'error')
            return
        end
    end

    local meta, backpackId = EnsureBackpackMetadata(src, item, def)
    if not backpackId then return end

    local stashId = MakeStashId(backpackId)
    OpenBackpackStashes[stashId] = {
        src = src,
        itemName = def.item,
        backpackId = backpackId,
        ts = os.time(),
    }

    -- Ensure inv_busy is cleared before opening a stash (prevents rare stuck states)
    if Player(src).state.inv_busy then
        Player(src).state.inv_busy = false
        Wait(0)
    end

    OpenInventory(src, stashId, {
        label = def.label or 'Backpack',
        slots = def.slots or 20,
        maxweight = def.maxweight or 200000,
    })
end

function Backpacks.IsBackpackStash(inventoryId)
    return type(inventoryId) == 'string' and inventoryId:find('^backpack%-') ~= nil
end

function Backpacks.GetOpenStashMeta(stashId)
    return stashId and OpenBackpackStashes[stashId] or nil
end

function Backpacks.CanMoveItemIntoBackpack(stashId, item)
    local openMeta = Backpacks.GetOpenStashMeta(stashId)
    if not openMeta then
        -- If the stash wasn't opened via the backpack flow, be conservative: disallow nesting.
        if item and item.name and IsBackpack(item.name) then
            return false, 'You cannot put backpacks inside backpacks.'
        end
        return true
    end

    if not item or not item.name then return true end
    local def = GetBackpackDef(openMeta.itemName)
    if not def then return true end

    if IsBackpack(item.name) then
        return false, 'You cannot put backpacks inside backpacks.'
    end

    if not IsItemAllowedInBackpack(def, item.name) then
        return false, 'This item cannot be stored in this backpack.'
    end

    return true
end

function Backpacks.OnClose(src, inventoryId)
    local openMeta = OpenBackpackStashes[inventoryId]
    if not openMeta then return end

    -- Extra safety: remove any nested backpacks if they ended up inside the stash.
    local inv = Inventories[inventoryId]
    if inv and inv.items and next(inv.items) then
        local changed = false
        for slot, stashItem in pairs(inv.items) do
            if stashItem and stashItem.name and IsBackpack(stashItem.name) then
                -- Attempt to return to player inventory
                local ok = AddItem(src, stashItem.name, stashItem.amount or 1, nil, stashItem.info)
                if ok then
                    inv.items[slot] = nil
                    changed = true
                end
            end
        end

        if changed then
            Notify(src, 'Backpacks cannot be stored inside backpacks.', 'error')
        end
    end

    OpenBackpackStashes[inventoryId] = nil
end

CreateThread(function()
    Wait(500)
    BuildCaches()

    -- Register backpack items as usable
    for itemName, def in pairs(BackpackDefs) do
        QBCore.Functions.CreateUseableItem(itemName, function(source, item)
            OpenBackpack(source, item)
        end)
        DebugPrint(('Registered backpack item: %s'):format(itemName))
    end

    DebugPrint(('Backpack integration loaded (%d definitions)'):format(#(Config.Backpacks and Config.Backpacks.Definitions or {})))
end)
