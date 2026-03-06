Config = {
    UseTarget = GetConvar('UseTarget', 'false') == 'true',

    MaxWeight = 250000,
    MaxSlots = 50,

    StashSize = {
        maxweight = 2000000,
        slots = 100
    },

    DropSize = {
        maxweight = 1000000,
        slots = 50
    },

    Keybinds = {
        Open = 'TAB',
        Hotbar = 'Z',
    },

    CleanupDropTime = 15,    -- in minutes
    CleanupDropInterval = 1, -- in minutes

    ItemDropObject = `bkr_prop_duffel_bag_01a`,
    ItemDropObjectBone = 28422,
    ItemDropObjectOffset = {
        vector3(0.260000, 0.040000, 0.000000),
        vector3(90.000000, 0.000000, -78.989998),
    },

    VendingObjects = {
        'prop_vend_soda_01',
        'prop_vend_soda_02',
        'prop_vend_water_01',
        'prop_vend_coffe_01',
    },

    VendingItems = {
        { name = 'kurkakola',    price = 4, amount = 50 },
        { name = 'water_bottle', price = 4, amount = 50 },
    },


    -- Drop inventories should NOT persist forever. This is a hard-expiry (even if left open).
    DropExpiryMinutes = 60,

    -- Gradually purge persisted drop-* inventories from the DB to avoid startup spikes.
    DropDBPurge = {
        enabled = true,
        intervalMinutes = 10,
        batchSize = 50,
        startDelaySeconds = 120,
        debug = false,
    },

    -- Gradually purge orphaned trunk-/glovebox- inventories that no longer have a matching vehicle plate.
    OrphanCleanup = {
        enabled = true,
        intervalMinutes = 10,
        batchSize = 50,
        startDelaySeconds = 120,
        vehicleTable = 'player_vehicles',
        plateColumn = 'plate',
        debug = false,
    },
}
