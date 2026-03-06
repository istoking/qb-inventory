Config = Config or {}

-- Currency Storage Guardrails
--
-- These settings let you control whether players can move currency items into different
-- inventory types (stashes, vehicles, backpacks, drops, other players).
--
-- "cash" should represent all legal physical cash.
-- "markedbills" is treated as the dirty/illegal money item.

Config.CurrencyGuardrails = {
    enabled = true,

    -- Currency item names to apply these rules to.
    items = {
        cash = true,
        markedbills = true,
    },

    -- Allow moving currency into player-owned stashes (stash-*)
    allowStashes = true,

    -- Allow moving currency into vehicle storage (trunk-* / glovebox-*)
    allowVehicles = true,

    -- Allow moving currency into backpack stashes (backpack-*)
    allowBackpacks = true,

    -- Allow dropping currency on the ground (drop-*)
    allowDrops = true,

    -- Allow giving/trading currency via otherplayer-* inventories
    allowOtherPlayers = true,
}
