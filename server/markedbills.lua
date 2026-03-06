local QBCore = exports['qb-core']:GetCoreObject()

local function GetFirstMarkedBillsSlot(items)
    for slot, item in pairs(items or {}) do
        if item and item.name == 'markedbills' then
            return slot, item
        end
    end
    return nil, nil
end

local function SumAllMarkedBills(items)
    local total = 0
    local slots = {}
    for slot, item in pairs(items or {}) do
        if item and item.name == 'markedbills' then
            local w = tonumber(item.info and item.info.worth) or 0
            total = total + w
            slots[#slots + 1] = slot
        end
    end
    return total, slots
end

-- Collapse multiple markedbills stacks into a single stack (total worth)
local function MergeMarkedBillsStacks(Player)
    if not Player then return end

    local items = Player.PlayerData.items or {}
    local total, slots = SumAllMarkedBills(items)
    if total <= 0 or #slots <= 1 then return end

    local keepSlot = slots[1]
    local keepItem = items[keepSlot]
    if not keepItem then return end

    keepItem.info = keepItem.info or {}
    keepItem.info.worth = total
    keepItem.amount = 1

    for i = 2, #slots do
        items[slots[i]] = nil
    end

    Player.Functions.SetPlayerData('items', items)
    TriggerClientEvent('inventory:client:UpdatePlayerInventory', Player.PlayerData.source, false)
end

-- Adds VALUE to markedbills in a single stack:
-- - If player already has markedbills: increases info.worth (total) and keeps amount = 1
-- - If not: creates 1 markedbills with info.worth = value
exports('AddMarkedBillsValue', function(source, value, reason)
    local src = tonumber(source)
    local addValue = tonumber(value)
    if not src or not addValue or addValue <= 0 then return false end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end

    -- Ensure any existing multiple stacks are merged first
    MergeMarkedBillsStacks(Player)

    local items = Player.PlayerData.items or {}
    local slot, item = GetFirstMarkedBillsSlot(items)

    if slot and item then
        item.info = item.info or {}
        local current = tonumber(item.info.worth) or 0
        item.info.worth = current + addValue
        item.amount = 1

        Player.Functions.SetPlayerData('items', items)
        TriggerClientEvent('inventory:client:UpdatePlayerInventory', src, false)
        return true
    end

    return exports['qb-inventory']:AddItem(src, 'markedbills', 1, false, { worth = addValue }, reason or 'illegal_payout')
end)

exports('GetMarkedBillsValue', function(source)
    local src = tonumber(source)
    if not src then return 0 end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return 0 end

    local total = 0
    for _, item in pairs(Player.PlayerData.items or {}) do
        if item and item.name == 'markedbills' then
            local w = tonumber(item.info and item.info.worth) or 0
            total = total + w
        end
    end
    return total
end)

exports('RemoveMarkedBillsValue', function(source, value)
    local src = tonumber(source)
    local removeValue = tonumber(value)
    if not src or not removeValue or removeValue <= 0 then return false end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end

    -- Always merge first so we only operate on one stack
    MergeMarkedBillsStacks(Player)

    local items = Player.PlayerData.items or {}
    local slot, item = GetFirstMarkedBillsSlot(items)
    if not slot or not item then return false end

    local current = tonumber(item.info and item.info.worth) or 0
    if current <= 0 then
        exports['qb-inventory']:RemoveItem(src, 'markedbills', 1, slot)
        return false
    end

    if removeValue >= current then
        exports['qb-inventory']:RemoveItem(src, 'markedbills', 1, slot)
        return true
    end

    item.info = item.info or {}
    item.info.worth = current - removeValue
    item.amount = 1

    Player.Functions.SetPlayerData('items', items)
    TriggerClientEvent('inventory:client:UpdatePlayerInventory', src, false)
    return true
end)

-- Merge stacks when the player loads, so old payouts consolidate automatically
AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    MergeMarkedBillsStacks(Player)
end)
