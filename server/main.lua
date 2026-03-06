QBCore = exports['qb-core']:GetCoreObject()
Inventories = Inventories or {}
Drops = Drops or {}
RegisteredShops = RegisteredShops or {}

CreateThread(function()
    while true do
        for k, v in pairs(Drops) do
            local now = os.time()
            if v and (v.createdTime + (Config.DropExpiryMinutes * 60) < now) then
                local entity = NetworkGetEntityFromNetworkId(v.entityId)
                if DoesEntityExist(entity) then DeleteEntity(entity) end
                Drops[k] = nil
            elseif v and (v.createdTime + (Config.CleanupDropTime * 60) < now) and not Drops[k].isOpen then
                local entity = NetworkGetEntityFromNetworkId(v.entityId)
                if DoesEntityExist(entity) then DeleteEntity(entity) end
                Drops[k] = nil
            end
        end
        Wait(Config.CleanupDropInterval * 60000)
    end
end)

-- Handlers

AddEventHandler('playerDropped', function()
    for identifier, inv in pairs(Inventories) do
        if inv.isOpen == source then
            inv.isOpen = false
            if type(identifier) == 'string' and inv.dirty then
                FlushInventoryNow(identifier, true)
            end
        end
    end
    for _, drop in pairs(Drops) do
        if drop and drop.isOpen == source then
            drop.isOpen = false
        end
    end
end)

AddEventHandler('txAdmin:events:serverShuttingDown', function()
    FlushDirtyInventories(true, 5000)
    for inventory in pairs(Inventories) do
        if type(inventory) == 'string' then
            FlushInventoryNow(inventory, true)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    FlushDirtyInventories(true, 5000)
    for inventory in pairs(Inventories) do
        if type(inventory) == 'string' then
            FlushInventoryNow(inventory, true)
        end
    end
end)

RegisterNetEvent('QBCore:Server:UpdateObject', function()
    if source ~= '' then return end
    QBCore = exports['qb-core']:GetCoreObject()
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'AddItem', function(item, amount, slot, info, reason)
        return AddItem(Player.PlayerData.source, item, amount, slot, info, reason)
    end)

    QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'RemoveItem', function(item, amount, slot, reason)
        return RemoveItem(Player.PlayerData.source, item, amount, slot, reason)
    end)

    QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'GetItemBySlot', function(slot)
        return GetItemBySlot(Player.PlayerData.source, slot)
    end)

    QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'GetItemByName', function(item)
        return GetItemByName(Player.PlayerData.source, item)
    end)

    QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'GetItemsByName', function(item)
        return GetItemsByName(Player.PlayerData.source, item)
    end)

    QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'ClearInventory', function(filterItems)
        ClearInventory(Player.PlayerData.source, filterItems)
    end)

    QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'SetInventory', function(items)
        SetInventory(Player.PlayerData.source, items)
    end)

    -- Cash as item: materialize/sync on player load (after inventory is available)
    CreateThread(function()
        local src = Player.PlayerData.source
        if not src then return end

        -- Wait briefly for PlayerData.items to be present
        local waited = 0
        while (not Player.PlayerData.items) and waited < 10000 do
            Wait(100)
            waited = waited + 100
        end

        if not Player.PlayerData.items then return end
        if not QBCore.Shared.Items or not QBCore.Shared.Items['cash'] then return end

        -- NOTE: GetItemCount expects a player source, not an items table
        local cashCount = GetItemCount(src, 'cash') or 0
        local moneyCash = tonumber(Player.PlayerData.money and Player.PlayerData.money.cash) or 0

        -- Prefer existing cash items; otherwise materialize money.cash into items
        if cashCount > 0 and moneyCash ~= cashCount then
            SetPlayerCashMoney(Player, cashCount)
        elseif cashCount == 0 and moneyCash > 0 then
            EnsureCashItemMatchesMoney(Player)
            -- refresh count after adding
            cashCount = GetItemCount(src, 'cash') or 0
            if cashCount ~= moneyCash then
                SetPlayerCashMoney(Player, cashCount)
            end
        end
    end)

end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    local Players = QBCore.Functions.GetQBPlayers()
    for k in pairs(Players) do
        QBCore.Functions.AddPlayerMethod(k, 'AddItem', function(item, amount, slot, info)
            return AddItem(k, item, amount, slot, info)
        end)

        QBCore.Functions.AddPlayerMethod(k, 'RemoveItem', function(item, amount, slot)
            return RemoveItem(k, item, amount, slot)
        end)

        QBCore.Functions.AddPlayerMethod(k, 'GetItemBySlot', function(slot)
            return GetItemBySlot(k, slot)
        end)

        QBCore.Functions.AddPlayerMethod(k, 'GetItemByName', function(item)
            return GetItemByName(k, item)
        end)

        QBCore.Functions.AddPlayerMethod(k, 'GetItemsByName', function(item)
            return GetItemsByName(k, item)
        end)

        QBCore.Functions.AddPlayerMethod(k, 'ClearInventory', function(filterItems)
            ClearInventory(k, filterItems)
        end)

        QBCore.Functions.AddPlayerMethod(k, 'SetInventory', function(items)
            SetInventory(k, items)
        end)

        Player(k).state.inv_busy = false
    end
end)

-- Functions

function checkWeapon(source, item)
    local currentWeapon = type(item) == 'table' and item.name or item
    local ped = GetPlayerPed(source)
    local weapon = GetSelectedPedWeapon(ped)
    local weaponInfo = QBCore.Shared.Weapons[weapon]
    if weaponInfo and weaponInfo.name == currentWeapon then
        RemoveWeaponFromPed(ped, weapon)
        TriggerClientEvent('qb-weapons:client:UseWeapon', source, { name = currentWeapon }, false)
    end
end

-- Events

RegisterNetEvent('qb-inventory:server:openVending', function(data)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    CreateShop({
        name = 'vending',
        label = 'Vending Machine',
        coords = data.coords,
        slots = #Config.VendingItems,
        items = Config.VendingItems
    })
    OpenShop(src, 'vending')
end)

RegisterNetEvent('qb-inventory:server:closeInventory', function(inventory)
    local src = source
    local QBPlayer = QBCore.Functions.GetPlayer(src)
    if not QBPlayer then return end
    Player(source).state.inv_busy = false
    if inventory:find('shop%-') then return end
    if inventory:find('otherplayer%-') then
        local targetId = tonumber(inventory:match('otherplayer%-(.+)'))
        Player(targetId).state.inv_busy = false
        return
    end
    if Drops[inventory] then
        Drops[inventory].isOpen = false
        if #Drops[inventory].items == 0 and not Drops[inventory].isOpen then -- if no listeed items in the drop on close
            TriggerClientEvent('qb-inventory:client:removeDropTarget', -1, Drops[inventory].entityId)
            Wait(500)
            local entity = NetworkGetEntityFromNetworkId(Drops[inventory].entityId)
            if DoesEntityExist(entity) then DeleteEntity(entity) end
            Drops[inventory] = nil
        end
        return
    end
    local inv = EnsureInventoryLoaded(inventory)
    if not inv then return end
    inv.isOpen = false
    if (Config.InventoryPerformance and Config.InventoryPerformance.Save and Config.InventoryPerformance.Save.flushOnClose ~= false) then
        FlushInventoryNow(inventory, true)
    end
    if Backpacks and Backpacks.IsBackpackStash and Backpacks.IsBackpackStash(inventory) then
        Backpacks.OnClose(src, inventory)
    end
end)

RegisterNetEvent('qb-inventory:server:useItem', function(item)
    local src = source
    -- This event is primarily triggered from clients, but can be called server-side.
    -- If it is ever triggered without a valid source, bail to avoid native errors.
    if not src then return end
    local itemData = GetItemBySlot(src, item.slot)
    if not itemData then return end
    local itemInfo = QBCore.Shared.Items[itemData.name]
    if itemData.type == 'weapon' then
        TriggerClientEvent('qb-weapons:client:UseWeapon', src, itemData, itemData.info.quality and itemData.info.quality > 0)
        TriggerClientEvent('qb-inventory:client:ItemBox', src, itemInfo, 'use')
    elseif itemData.name == 'id_card' then
        UseItem(itemData.name, src, itemData)
        TriggerClientEvent('qb-inventory:client:ItemBox', src, itemInfo, 'use')
        local playerPed = GetPlayerPed(src)
        local playerCoords = GetEntityCoords(playerPed)
        local players = QBCore.Functions.GetPlayers()
        local gender = (itemData.info and itemData.info.gender == 0) and 'Male' or 'Female'
        for _, v in pairs(players) do
            local targetPed = GetPlayerPed(v)
            local dist = #(playerCoords - GetEntityCoords(targetPed))
            if dist < 3.0 then
                --[[TriggerClientEvent('chat:addMessage', v, {
                    template = '<div class="chat-message advert" style="background: linear-gradient(to right, rgba(5, 5, 5, 0.6), #74807c); display: flex;"><div style="margin-right: 10px;"><i class="far fa-id-card" style="height: 100%;"></i><strong> {0}</strong><br> <strong>Civ ID:</strong> {1} <br><strong>First Name:</strong> {2} <br><strong>Last Name:</strong> {3} <br><strong>Birthdate:</strong> {4} <br><strong>Gender:</strong> {5} <br><strong>Nationality:</strong> {6}</div></div>',
                    args = {
                        'ID Card',
                        item.info.citizenid,
                        item.info.firstname,
                        item.info.lastname,
                        item.info.birthdate,
                        gender,
                        item.info.nationality
                    }
                })--]]
            end
        end
    elseif itemData.name == 'driver_license' then
        UseItem(itemData.name, src, itemData)
        TriggerClientEvent('qb-inventory:client:ItemBox', src, itemInfo, 'use')
        local playerPed = GetPlayerPed(src)
        local playerCoords = GetEntityCoords(playerPed)
        local players = QBCore.Functions.GetPlayers()
        for _, v in pairs(players) do
            local targetPed = GetPlayerPed(v)
            local dist = #(playerCoords - GetEntityCoords(targetPed))
            if dist < 3.0 then
                --[[TriggerClientEvent('chat:addMessage', v, {
                    template = '<div class="chat-message advert" style="background: linear-gradient(to right, rgba(5, 5, 5, 0.6), #657175); display: flex;"><div style="margin-right: 10px;"><i class="far fa-id-card" style="height: 100%;"></i><strong> {0}</strong><br> <strong>First Name:</strong> {1} <br><strong>Last Name:</strong> {2} <br><strong>Birth Date:</strong> {3} <br><strong>Licenses:</strong> {4}</div></div>',
                    args = {
                        'Drivers License',
                        item.info.firstname,
                        item.info.lastname,
                        item.info.birthdate,
                        item.info.type
                    }
                })--]]
            end
        end
    else
        UseItem(itemData.name, src, itemData)
        TriggerClientEvent('qb-inventory:client:ItemBox', src, itemInfo, 'use')
    end
end)

RegisterNetEvent('qb-inventory:server:openDrop', function(dropId)
    local src = source
    if CheckInventoryRateLimit(src, 'openDrop') then return end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)
    local drop = Drops[dropId]
    if not drop then return end
    if drop.isOpen and drop.isOpen ~= src then return end
    local distance = #(playerCoords - drop.coords)
    if distance > 2.5 then return end
    local formattedInventory = {
        name = dropId,
        label = dropId,
        maxweight = drop.maxweight,
        slots = drop.slots,
        inventory = drop.items
    }
    drop.isOpen = false
    TriggerClientEvent('qb-inventory:client:openInventory', source, Player.PlayerData.items, formattedInventory)
end)

RegisterNetEvent('qb-inventory:server:updateDrop', function(dropId, coords)
    Drops[dropId].coords = coords
end)

RegisterNetEvent('qb-inventory:server:snowball', function(action)
    if action == 'add' then
        AddItem(source, 'weapon_snowball', 1, false, false, 'qb-inventory:server:snowball')
    elseif action == 'remove' then
        RemoveItem(source, 'weapon_snowball', 1, false, 'qb-inventory:server:snowball')
    end
end)

-- Callbacks

QBCore.Functions.CreateCallback('qb-inventory:server:GetCurrentDrops', function(_, cb)
    cb(Drops)
end)

QBCore.Functions.CreateCallback('qb-inventory:server:createDrop', function(source, cb, item)
    local src = source
    if CheckInventoryRateLimit(src, 'createDrop') then
        cb(false)
        return
    end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        cb(false)
        return
    end
    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)
    if item and item.name and not CanStoreRestrictedItemInInventory(item.name, 'drop-temp') then
        TriggerClientEvent('QBCore:Notify', src, 'You cannot drop that item.', 'error')
        InventoryLogBlockedAction('Blocked Drop', ('**Player:** %s (%s)\n**Item:** %s'):format(GetPlayerName(src) or 'Unknown', src, item.name))
        cb(false)
        return
    end
    if RemoveItem(src, item.name, item.amount, item.fromSlot, 'dropped item') then
        if item.type == 'weapon' then checkWeapon(src, item) end
        TaskPlayAnim(playerPed, 'pickup_object', 'pickup_low', 8.0, -8.0, 2000, 0, 0, false, false, false)
        local bag = CreateObjectNoOffset(Config.ItemDropObject, playerCoords.x + 0.5, playerCoords.y + 0.5, playerCoords.z, true, true, false)
        local dropId = NetworkGetNetworkIdFromEntity(bag)
        local newDropId = 'drop-' .. dropId
        local itemsTable = setmetatable({ item }, {
            __len = function(t)
                local length = 0
                for _ in pairs(t) do length += 1 end
                return length
            end
        })
        if not Drops[newDropId] then
            Drops[newDropId] = {
                name = newDropId,
                label = 'Drop',
                items = itemsTable,
                entityId = dropId,
                createdTime = os.time(),
                coords = playerCoords,
                maxweight = Config.DropSize.maxweight,
                slots = Config.DropSize.slots,
                isOpen = true
            }
            TriggerClientEvent('qb-inventory:client:setupDropTarget', -1, dropId)
        else
            table.insert(Drops[newDropId].items, item)
        end
        cb(dropId)
    else
        cb(false)
    end
end)

QBCore.Functions.CreateCallback('qb-inventory:server:attemptPurchase', function(source, cb, data)
    if CheckInventoryRateLimit(source, 'purchase') then cb(false) return end
    local itemInfo = data.item
    local amount = data.amount
    local shop = string.gsub(data.shop, 'shop%-', '')
    local Player = QBCore.Functions.GetPlayer(source)

    if amount < 0 then cb(false) return end

    if not Player then
        cb(false)
        return
    end

    local shopInfo = RegisteredShops[shop]
    if not shopInfo then
        cb(false)
        return
    end

    local playerPed = GetPlayerPed(source)
    local playerCoords = GetEntityCoords(playerPed)
    if shopInfo.coords then
        local shopCoords = vector3(shopInfo.coords.x, shopInfo.coords.y, shopInfo.coords.z)
        if #(playerCoords - shopCoords) > 10 then
            cb(false)
            return
        end
    end

    if shopInfo.items[itemInfo.slot].name ~= itemInfo.name then -- Check if item name passed is the same as the item in that slot
        cb(false)
        return
    end

    if amount > shopInfo.items[itemInfo.slot].amount or shopInfo.items[itemInfo.slot].amount <= 0 then
        TriggerClientEvent('QBCore:Notify', source, 'Cannot purchase larger quantity than currently in stock', 'error')
        cb(false)
        return
    end

    if not CanAddItem(source, itemInfo.name, amount) then
        TriggerClientEvent('QBCore:Notify', source, 'Cannot hold item', 'error')
        cb(false)
        return
    end

    local price = shopInfo.items[itemInfo.slot].price * amount
    if Player.PlayerData.money.cash >= price then
        Player.Functions.RemoveMoney('cash', price, 'shop-purchase')
        AddItem(source, itemInfo.name, amount, nil, itemInfo.info, 'shop-purchase')
        shopInfo.items[itemInfo.slot].amount -= amount
        TriggerEvent('qb-shops:server:UpdateShopItems', shop, itemInfo, amount)
        cb(true)
    else
        TriggerClientEvent('QBCore:Notify', source, 'You do not have enough money', 'error')
        cb(false)
    end
end)

QBCore.Functions.CreateCallback('qb-inventory:server:giveItem', function(source, cb, target, item, amount, slot, info)
    if CheckInventoryRateLimit(source, 'giveItem') then cb(false) return end
    local player = QBCore.Functions.GetPlayer(source)
    if not player or player.PlayerData.metadata['isdead'] or player.PlayerData.metadata['inlaststand'] or player.PlayerData.metadata['ishandcuffed'] then
        cb(false)
        return
    end
    local playerPed = GetPlayerPed(source)

    local Target = QBCore.Functions.GetPlayer(target)
    if not Target or Target.PlayerData.metadata['isdead'] or Target.PlayerData.metadata['inlaststand'] or Target.PlayerData.metadata['ishandcuffed'] then
        cb(false)
        return
    end
    local targetPed = GetPlayerPed(target)

    local pCoords = GetEntityCoords(playerPed)
    local tCoords = GetEntityCoords(targetPed)
    if #(pCoords - tCoords) > 5 then
        cb(false)
        return
    end

    local itemInfo = QBCore.Shared.Items[item:lower()]
    if not itemInfo then
        cb(false)
        return
    end

    local hasItem = HasItem(source, item)
    if not hasItem then
        cb(false)
        return
    end

    local itemAmount = GetItemByName(source, item).amount
    if itemAmount <= 0 then
        cb(false)
        return
    end

    local giveAmount = tonumber(amount)
    if giveAmount > itemAmount then
        cb(false)
        return
    end

    if not CanStoreRestrictedItemInInventory(item, 'otherplayer-' .. tostring(target)) then
        TriggerClientEvent('QBCore:Notify', source, 'You cannot give that item that way.', 'error')
        InventoryLogBlockedAction('Blocked Give Item', ('**Player:** %s (%s)\n**Target:** %s\n**Item:** %s'):format(GetPlayerName(source) or 'Unknown', source, target, item))
        cb(false)
        return
    end

    local removeItem = RemoveItem(source, item, giveAmount, slot, 'Item given to ID #' .. target)
    if not removeItem then
        cb(false)
        return
    end

    local giveItem = AddItem(target, item, giveAmount, false, info, 'Item given from ID #' .. source)
    if not giveItem then
        cb(false)
        return
    end

    if itemInfo.type == 'weapon' then checkWeapon(source, item) end
    TriggerClientEvent('qb-inventory:client:giveAnim', source)
    TriggerClientEvent('qb-inventory:client:ItemBox', source, itemInfo, 'remove', giveAmount)
    TriggerClientEvent('qb-inventory:client:giveAnim', target)
    TriggerClientEvent('qb-inventory:client:ItemBox', target, itemInfo, 'add', giveAmount)
    if Player(target).state.inv_busy then TriggerClientEvent('qb-inventory:client:updateInventory', target) end
    cb(true)
end)

-- Item move logic

local function getItem(inventoryId, src, slot)
    local items = {}
    if inventoryId == 'player' then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player and Player.PlayerData.items then
            items = Player.PlayerData.items
        end
    elseif inventoryId:find('otherplayer-') then
        local targetId = tonumber(inventoryId:match('otherplayer%-(.+)'))
        local targetPlayer = QBCore.Functions.GetPlayer(targetId)
        if targetPlayer and targetPlayer.PlayerData.items then
            items = targetPlayer.PlayerData.items
        end
    elseif inventoryId:find('drop-') == 1 then
        if Drops[inventoryId] and Drops[inventoryId]['items'] then
            items = Drops[inventoryId]['items']
        end
    else
        local inv = EnsureInventoryLoaded(inventoryId)
        if inv and inv.items then
            items = inv.items
        end
    end

    for _, item in pairs(items) do
        if item.slot == slot then
            return item
        end
    end
    return nil
end

local function getIdentifier(inventoryId, src)
    if inventoryId == 'player' then
        return src
    elseif inventoryId:find('otherplayer-') then
        return tonumber(inventoryId:match('otherplayer%-(.+)'))
    else
        return inventoryId
    end
end

local function getItemKeyBySlot(items, slot)
    if not items or not slot then return nil, nil end

    local direct = items[slot]
    if direct and direct.slot == slot then
        return slot, direct
    end

    for k, v in pairs(items) do
        if v and v.slot == slot then
            return k, v
        end
    end

    return nil, nil
end

local function cloneTableShallow(t)
    if type(t) ~= 'table' then return t end
    local out = {}
    for k, v in pairs(t) do
        out[k] = v
    end
    return out
end

RegisterNetEvent('qb-inventory:server:SetInventoryData', function(fromInventory, toInventory, fromSlot, toSlot, fromAmount, toAmount)
    if toInventory:find('shop%-') then return end
    local src = source
    if CheckInventoryRateLimit(src, 'moveItem') then return end
    if not fromInventory or not toInventory or not fromSlot or not toSlot or not fromAmount or not toAmount or fromAmount < 0 or toAmount < 0 then return end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    fromSlot, toSlot, fromAmount, toAmount = tonumber(fromSlot), tonumber(toSlot), tonumber(fromAmount), tonumber(toAmount)

    local fromItem = getItem(fromInventory, src, fromSlot)
    local toItem = getItem(toInventory, src, toSlot)

    if fromItem and not CanStoreRestrictedItemInInventory(fromItem.name, toInventory) then
        TriggerClientEvent('QBCore:Notify', src, 'You cannot store that item there.', 'error')
        InventoryLogBlockedAction('Blocked Inventory Move', ('**Player:** %s (%s)\n**Item:** %s\n**From:** %s\n**To:** %s'):format(GetPlayerName(src) or 'Unknown', src, fromItem.name, fromInventory, toInventory))
        return
    end

    -- Backpack stash validation (merged backpacks)
    if Backpacks and Backpacks.IsBackpackStash and Backpacks.IsBackpackStash(toInventory) and fromInventory ~= toInventory and fromItem then
        local ok, reason = Backpacks.CanMoveItemIntoBackpack(toInventory, fromItem)
        if not ok then
            TriggerClientEvent('QBCore:Notify', src, reason or 'You cannot store that item here.', 'error')
            return
        end
    end

    if fromItem then
        if not toItem and toAmount > fromItem.amount then return end
        if fromInventory == 'player' and toInventory ~= 'player' then checkWeapon(src, fromItem) end

        local fromId = getIdentifier(fromInventory, src)
        local toId = getIdentifier(toInventory, src)

        -- Reduce server->client update spam for same-inventory moves by doing a single SetPlayerData.
        -- The original logic calls RemoveItem/AddItem multiple times per swap which can cause multiple
        -- PlayerData updates (and NUI refreshes) for a single drag action.
        if fromId == toId and type(fromId) == 'number' then
            local Target = QBCore.Functions.GetPlayer(fromId)
            if Target and Target.PlayerData and Target.PlayerData.items then
                local items = Target.PlayerData.items
                local fromKey, fromInvItem = getItemKeyBySlot(items, fromSlot)
                local toKey, toInvItem = getItemKeyBySlot(items, toSlot)

                if not fromInvItem then return end
                if not toInvItem and toAmount > fromInvItem.amount then return end

                if toInvItem and fromInvItem.name == toInvItem.name then
                    -- Stack
                    fromInvItem.amount = fromInvItem.amount - toAmount
                    toInvItem.amount = toInvItem.amount + toAmount

                    if fromInvItem.amount <= 0 then
                        items[fromKey] = nil
                    else
                        items[fromKey] = fromInvItem
                    end
                    items[toKey] = toInvItem

                    Target.Functions.SetPlayerData('items', items)
                    return
                elseif (not toInvItem) and toAmount < fromAmount then
                    -- Split
                    fromInvItem.amount = fromInvItem.amount - toAmount
                    if fromInvItem.amount <= 0 then
                        items[fromKey] = nil
                    else
                        items[fromKey] = fromInvItem
                    end

                    local sharedInfo = QBCore.Shared.Items[fromInvItem.name:lower()]
                    items[toSlot] = {
                        name = fromInvItem.name,
                        amount = toAmount,
                        info = fromInvItem.info or {},
                        label = sharedInfo and sharedInfo.label or fromInvItem.label,
                        description = (sharedInfo and sharedInfo.description) or fromInvItem.description or '',
                        weight = sharedInfo and sharedInfo.weight or fromInvItem.weight or 0,
                        type = sharedInfo and sharedInfo.type or fromInvItem.type,
                        unique = sharedInfo and sharedInfo.unique or fromInvItem.unique,
                        useable = sharedInfo and sharedInfo.useable or fromInvItem.useable,
                        image = sharedInfo and sharedInfo.image or fromInvItem.image,
                        shouldClose = sharedInfo and sharedInfo.shouldClose or fromInvItem.shouldClose,
                        slot = toSlot,
                        combinable = sharedInfo and sharedInfo.combinable or fromInvItem.combinable
                    }

                    Target.Functions.SetPlayerData('items', items)
                    return
                else
                    -- Swap or Move
                    if toInvItem then
                        -- Swap the slot numbers and move entries
                        fromInvItem.slot = toSlot
                        toInvItem.slot = fromSlot

                        items[fromKey] = nil
                        items[toKey] = nil
                        items[toSlot] = fromInvItem
                        items[fromSlot] = toInvItem
                    else
                        -- Move
                        fromInvItem.slot = toSlot
                        if toAmount < fromInvItem.amount then
                            -- Partial move (should have been handled by split, but keep safe)
                            local remaining = fromInvItem.amount - toAmount
                            local moving = cloneTableShallow(fromInvItem)
                            moving.amount = toAmount
                            moving.slot = toSlot
                            fromInvItem.amount = remaining
                            items[fromKey] = fromInvItem
                            items[toSlot] = moving
                        else
                            items[fromKey] = nil
                            items[toSlot] = fromInvItem
                        end
                    end

                    Target.Functions.SetPlayerData('items', items)
                    return
                end
            end
        end

        if toItem and fromItem.name == toItem.name then
            if RemoveItem(fromId, fromItem.name, toAmount, fromSlot, 'stacked item') then
                AddItem(toId, toItem.name, toAmount, toSlot, toItem.info, 'stacked item')
            end
        elseif not toItem and toAmount < fromAmount then
            if RemoveItem(fromId, fromItem.name, toAmount, fromSlot, 'split item') then
                AddItem(toId, fromItem.name, toAmount, toSlot, fromItem.info, 'split item')
            end
        else
            if toItem then
                local fromItemAmount = fromItem.amount
                local toItemAmount = toItem.amount

                if RemoveItem(fromId, fromItem.name, fromItemAmount, fromSlot, 'swapped item') and RemoveItem(toId, toItem.name, toItemAmount, toSlot, 'swapped item') then
                    AddItem(toId, fromItem.name, fromItemAmount, toSlot, fromItem.info, 'swapped item')
                    AddItem(fromId, toItem.name, toItemAmount, fromSlot, toItem.info, 'swapped item')
                end
            else
                if RemoveItem(fromId, fromItem.name, toAmount, fromSlot, 'moved item') then
                    AddItem(toId, fromItem.name, toAmount, toSlot, fromItem.info, 'moved item')
                end
            end
        end
    end
end)
