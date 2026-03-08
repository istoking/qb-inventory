Config = Config or {}

Config.UseTarget = GetConvar('UseTarget', 'false') == 'true'

Config.MaxWeight = 250000
Config.MaxSlots = 50

Config.StashSize = {
    maxweight = 2000000,
    slots = 100
}

Config.DropSize = {
    maxweight = 1000000,
    slots = 50
}

Config.Keybinds = {
    Open = 'TAB',
    Hotbar = 'Z',
}

Config.CleanupDropTime = 15
Config.CleanupDropInterval = 1

Config.ItemDropObject = `bkr_prop_duffel_bag_01a`
Config.ItemDropObjectBone = 28422
Config.ItemDropObjectOffset = {
    vector3(0.260000, 0.040000, 0.000000),
    vector3(90.000000, 0.000000, -78.989998),
}

Config.VendingObjects = {
    'prop_vend_soda_01',
    'prop_vend_soda_02',
    'prop_vend_water_01',
    'prop_vend_coffe_01',
}

Config.VendingItems = {
    { name = 'kurkakola',    price = 4, amount = 50 },
    { name = 'water_bottle', price = 4, amount = 50 },
}

Config.DropExpiryMinutes = 60

Config.DropDBPurge = {
    enabled = true,
    intervalMinutes = 10,
    batchSize = 50,
    startDelaySeconds = 120,
    debug = false,
}

Config.OrphanCleanup = {
    enabled = true,
    intervalMinutes = 10,
    batchSize = 50,
    startDelaySeconds = 120,
    vehicleTable = 'player_vehicles',
    plateColumn = 'plate',
    debug = false,
}

Config.Debug = Config.Debug or {
    Enabled = true,
    Backpacks = true,
    Drops = true,
    Moves = true,
}
