-- Backpack logic merged into qb-inventory
-- Provides: usable backpack items that open a unique stash per backpack instance,
-- carry limits, nested-backpack prevention, and per-backpack whitelist/blacklist.
local QBCore = exports['qb-core']:GetCoreObject()

Backpacks = Backpacks or {}

local function DebugPrint(msg)
    if Config and Config.Debug and Config.Debug.Enabled and Config.Debug.Backpacks then
        print(('^3[qb-inventory:backpacks]^0 %s'):format(msg))
    elseif Config.Backpacks and Config.Backpacks.Debug then
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
                entry.whitelist = next(wl) and wl or nil
            end

            if entry.blacklist and type(entry.blacklist) == 'table' then
                local bl = {}
                for _, v in ipairs(entry.blacklist) do
                    bl[NormalizeItemName(v)] = true
                end
                entry.blacklist = next(bl) and bl or nil
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
        if item.slot and Player.PlayerData.items[item.slot] then
            Player.PlayerData.items[item.slot].info = meta
        end
        Player.Functions.SetPlayerData('items', Player.PlayerData.items)
        SaveInventory(src)
        DebugPrint(('Assigned new backpackId %s for %s'):format(backpackId, def.item))
    else
        -- Normalize fields for future-proofing
        meta.ID = meta.ID or backpackId
        meta.backpackId = meta.backpackId or backpackId
        meta.backpackType = meta.backpackType or def.item
        meta.slots = meta.slots or def.slots
        meta.maxweight = meta.maxweight or def.maxweight
        item.info = meta
        if item.slot and Player.PlayerData.items[item.slot] then
            Player.PlayerData.items[item.slot].info = meta
        end
    end

    if item.slot and Player.PlayerData.items[item.slot] then
        Player.PlayerData.items[item.slot] = item
    end

    return meta, backpackId
end

local function OpenBackpack(src, item)
    if not item or not item.name then return false end
    local itemName = NormalizeItemName(item.name)
    local def = GetBackpackDef(itemName)
    DebugPrint(('useItem src=%s item=%s slot=%s'):format(src, tostring(itemName), tostring(item.slot)))
    if not def then
        DebugPrint(('OpenBackpack missing definition for %s'):format(tostring(itemName)))
        return false
    end

    if not CheckJobLock(src, def) then
        Notify(src, 'This backpack is restricted to certain jobs.', 'error')
        return false
    end

    if Config.Backpacks and Config.Backpacks.RestrictMultipleBackpacks then
        local count = CountPlayerBackpacks(src)
        local limit = Config.Backpacks.MaxAllowedBackpacks or 2
        if count > limit then
            DebugPrint(('OpenBackpack carry warning src=%s count=%s limit=%s'):format(src, count, limit))
        end
    end

    local meta, backpackId = EnsureBackpackMetadata(src, item, def)
    if not backpackId then
        DebugPrint(('OpenBackpack failed metadata src=%s item=%s'):format(src, tostring(itemName)))
        return false
    end

    local stashId = MakeStashId(backpackId)
    local PlayerObj = QBCore.Functions.GetPlayer(src)
    if not PlayerObj then return false end

    local inventory = GetInventory(stashId)
    if inventory and inventory.isOpen and inventory.isOpen ~= src then
        Notify(src, 'This inventory is currently in use', 'error')
        DebugPrint(('OpenBackpack blocked in-use stash=%s opener=%s'):format(stashId, tostring(inventory.isOpen)))
        return false
    end

    if not inventory then
        CreateInventory(stashId, {
            label = def.label or 'Backpack',
            slots = def.slots or 20,
            maxweight = def.maxweight or 200000,
        })
        inventory = GetInventory(stashId)
    else
        inventory.label = def.label or inventory.label or 'Backpack'
        inventory.slots = def.slots or inventory.slots or 20
        inventory.maxweight = def.maxweight or inventory.maxweight or 200000
    end

    if not inventory then
        DebugPrint(('OpenBackpack failed to create inventory stash=%s'):format(stashId))
        return false
    end

    inventory.isOpen = false
    OpenBackpackStashes[stashId] = {
        src = src,
        itemName = def.item,
        backpackId = backpackId,
        ts = os.time(),
    }

    if Player(src).state.inv_busy then
        Player(src).state.inv_busy = false
    end

    DebugPrint(('Opening backpack stash=%s src=%s slots=%s maxweight=%s'):format(stashId, src, inventory.slots, inventory.maxweight))
    OpenInventory(src, stashId, {
        label = inventory.label,
        slots = inventory.slots,
        maxweight = inventory.maxweight,
    })
    return true

end


function Backpacks.Open(src, item)
    return OpenBackpack(src, item)
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
