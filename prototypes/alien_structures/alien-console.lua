--====================================================================================================
-- ALIEN TERMINAL (3.2.0)
--====================================================================================================
-- Access point of the alien tech tree (runtime: scripts/control/alien_console.lua).
--   * ei-alien-console: 2x2 container of the player force. Nodes of the alien tree can only be
--     bought near a terminal (balance.alien_console.range); resonance packs and resonance data in
--     its inventory are converted into alien knowledge at the payment rates. Built only on Gaia.
--   * ei-alien-console_off: broken terminal, a Gaia ruin (POI "gaia-terminal_ruin"), repaired with
--     ei-alien-console-repair (unlocked with Gaia, so the first terminal needs no tree node).
--   * ei-alien-console (technology): alien tree tier 1, unlocks the terminal recipe.
-- Graphics: Exotic Industries knowledge console (graphics-1 item / tech icon, graphics-2 entity):
-- static picture 256x256 and a working animation 8x8 frames of 256x256, both scale 0.32.
--====================================================================================================

local ei_balance = require("lib/balance")
local balance = ei_balance.alien_console

local ICON = ei_graphics_item_path.."alien-console.png"

---Picture of the terminal; the broken one is the same picture, darkened.
---@param tint table|nil
local function picture(tint)
    return {
        filename = ei_graphics_entity_2_path.."alien-console.png",
        size = 256,
        scale = 0.32,
        shift = {0, -0.3},
        tint = tint,
    }
end

-- repair kit icon: terminal icon with a small repair pack in the corner
local REPAIR_ICONS = {
    {icon = ICON, icon_size = 64},
    {icon = "__base__/graphics/icons/repair-pack.png", icon_size = 64, scale = 0.25, shift = {8, 8}},
}

data:extend({
    --ANIMATION (drawn by the script over working terminals)
    {
        type = "animation",
        name = "ei-alien-console-working",
        filename = ei_graphics_entity_2_path.."alien-console_animation.png",
        width = 256,
        height = 256,
        line_length = 8,
        frame_count = 64,
        animation_speed = 0.5,
        scale = 0.32,
        shift = {0, -0.3},
    },

    --TERMINAL
    {
        name = "ei-alien-console",
        type = "container",
        icon = ICON,
        icon_size = 64,
        flags = {"placeable-neutral", "placeable-player", "player-creation"},
        minable = {mining_time = 1, result = "ei-alien-console"},
        max_health = 500,
        corpse = "medium-remnants",
        dying_explosion = "medium-explosion",
        collision_box = {{-0.8, -0.8}, {0.8, 0.8}},
        selection_box = {{-1, -1}, {1, 1}},
        map_color = ei_data.colors.alien,
        inventory_size = balance.slots,
        picture = picture(),
        open_sound = {filename = "__base__/sound/machine-open.ogg", volume = 0.6},
        close_sound = {filename = "__base__/sound/machine-close.ogg", volume = 0.6},
    },
    {
        name = "ei-alien-console",
        type = "item",
        icon = ICON,
        icon_size = 64,
        subgroup = "ei-alien-structures-2",
        order = "d-a",
        place_result = "ei-alien-console",
        stack_size = 10,
    },
    {
        name = "ei-alien-console",
        type = "recipe",
        category = "crafting",
        energy_required = 10,
        ingredients = {
            {type = "item", name = "ei-electronic-parts", amount = 10},
            {type = "item", name = "ei-energy-crystal", amount = 10},
            {type = "item", name = "ei-resonance-data", amount = 10},
        },
        results = {{type = "item", name = "ei-alien-console", amount = 1}},
        enabled = false,
        main_product = "ei-alien-console",
    },

    --BROKEN TERMINAL (ruin)
    {
        name = "ei-alien-console_off",
        type = "container",
        icon = ICON,
        icon_size = 64,
        flags = {"placeable-neutral", "player-creation", "not-deconstructable", "not-blueprintable"},
        max_health = 300,
        corpse = "medium-remnants",
        collision_box = {{-0.8, -0.8}, {0.8, 0.8}},
        selection_box = {{-1, -1}, {1, 1}},
        map_color = ei_data.colors.alien,
        inventory_size = 0,
        picture = picture({r = 0.45, g = 0.4, b = 0.5, a = 1}),
        -- results / loot are replaced by the salvage table (scripts/data-final-updates/alien_artifacts.lua)
        minable = {mining_time = 2, result = "ei-alien-console_off"},
    },
    {
        -- hidden item of the ruin (map editor / placement only)
        name = "ei-alien-console_off",
        type = "item",
        icon = ICON,
        icon_size = 64,
        subgroup = "ei-alien-structures",
        order = "d1",
        place_result = "ei-alien-console_off",
        stack_size = 1,
    },

    --REPAIR KIT
    {
        name = "ei-alien-console-repair",
        type = "selection-tool",
        stack_size = 1,
        icons = REPAIR_ICONS,
        select = {
            border_color = {r = 0.79, g = 0.4, b = 0, a = 0.5},
            mode = {"any-entity"},
            cursor_box_type = "entity",
        },
        alt_select = {
            border_color = {r = 0, g = 1, b = 0, a = 0.5},
            cursor_box_type = "entity",
            mode = {"any-entity"},
        },
        entity_filter_mode = "whitelist",
        entity_filters = ei_data.repair_tool_entity_filter("ei-alien-console-repair"),
        subgroup = "ei-repairs",
        order = "a-d",
    },
    {
        name = "ei-alien-console-repair",
        type = "recipe",
        category = "crafting",
        energy_required = 20,
        ingredients = {
            {type = "item", name = "ei-electronic-parts", amount = 6},
            {type = "item", name = "ei-energy-crystal", amount = 6},
            {type = "item", name = "ei-insulated-wire", amount = 10},
        },
        results = {{type = "item", name = "ei-alien-console-repair", amount = 1}},
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-alien-console-repair",
    },

    --TECHNOLOGY (alien tree tier 1, script-only: scripts/data-final-updates/alien_tree_techs.lua)
    {
        name = "ei-alien-console",
        type = "technology",
        icon = ei_graphics_tech_path.."alien-console.png",
        icon_size = 256,
        prerequisites = {"ei-resonance-synthesizer"},
        effects = {
            {type = "unlock-recipe", recipe = "ei-alien-console"},
        },
        research_trigger = {
            type = "scripted",
            trigger_description = {"technology-description.ei-alien-tree-trigger"},
        },
    },
})

-- the first terminal comes from a ruin: its repair kit is unlocked together with Gaia
local gaia_technology = data.raw.technology["ei-gaia"]
if gaia_technology then
    gaia_technology.effects = gaia_technology.effects or {}
    table.insert(gaia_technology.effects, {type = "unlock-recipe", recipe = "ei-alien-console-repair"})
end
