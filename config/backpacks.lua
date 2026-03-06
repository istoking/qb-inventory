-- Backpack integration for qb-inventory (merged from cm-backpacks)
-- This file adds backpack items that open a dedicated stash (inventory) per unique backpack.

Config = Config or {}
Config.Backpacks = {
    Debug = false,

    -- Backpack carry restrictions
    RestrictMultipleBackpacks = true,
    MaxAllowedBackpacks = 2,

    -- Backpack open duration (ms) - purely cosmetic if you add client-side progress later
    Duration = {
        Open = 1000
    },

    -- Backpack definitions
    -- Note: qb-inventory uses maxweight (grams) and slots for stash sizing.
    Definitions = {
        -- Small Backpack
        {
            item = 'backpack1',
            label = 'Small Backpack',
            slots = 20,
            maxweight = 200000,
        },

        -- Medium Backpack (example)
        {
            item = 'backpack2',
            label = 'Medium Backpack',
            slots = 30,
            maxweight = 300000,
            blacklist = { -- Items NOT allowed in this backpack
                'weapon_pistol',
                'weapon_smg',
                'weapon_carbinerifle',
                'weapon_pumpshotgun',
                'weapon_assaultrifle',
            }
        },

        -- Large Backpack (example)
        {
            item = 'backpack3',
            label = 'Large Backpack',
            slots = 40,
            maxweight = 400000,
            whitelist = { -- ONLY these items allowed (if set)
                -- 'water_bottle',
                -- 'sandwich',
            }
        },
    }
}