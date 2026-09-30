--====================================================================================================
-- DRONE PORT AND DRONES (3.2.0)
--====================================================================================================
-- Narrowly specialised, fully controlled script drones (runtime: scripts/control/drone_port.lua).
--   * ei-drone-port: 5x5 container with filtered slots (drones, repair packs, loot) and the hub of
--     the drone control GUI. A hidden electric energy interface on the same position powers it.
--   * ei-drone: item; drones are stored in the port and launched for one task each
--   * ei-drone-remote: selection tool handed out by the port GUI to pick task targets
--   * animations: the flying drone (64 directions + shadow) and the working port
-- Unlocked by the script-only technology ei-drone-port (alien tech tree tier 2).
-- Numbers: lib/balance.lua -> drones. Graphics: Exotic Industries (graphics-2), frame layout of the
-- original EI drone port: port 512x512 (scale 0.35), port animation 4x4 frames (12 used),
-- drone and shadow 8x8 = 64 directions of 512x512 (scale 0.15), north first, clockwise.
--====================================================================================================

local ei_balance = require("lib/balance")
local balance = ei_balance.drones

local PORT_PICTURE = {
    filename = ei_graphics_entity_2_path.."drone-port.png",
    size = 512,
    shift = {-0.1, 0.2},
    scale = 0.35,
}

--ANIMATIONS (drawn by the script with rendering.draw_animation)
------------------------------------------------------------------------------------------------------

---One 64-direction drone sheet (animation_offset selects the direction, animation_speed = 0).
---@param name string animation prototype name
---@param file string file in graphics-2/graphics/entities
---@param shadow boolean|nil
local function drone_sheet(name, file, shadow)
    return {
        type = "animation",
        name = name,
        filename = ei_graphics_entity_2_path..file,
        width = 512,
        height = 512,
        line_length = 8,
        frame_count = 64,
        scale = 0.15,
        draw_as_shadow = shadow or nil,
    }
end

data:extend({
    drone_sheet("ei-drone-flying", "drone_animation.png"),
    drone_sheet("ei-drone-flying-shadow", "drone_shadow.png", true),
    {
        type = "animation",
        name = "ei-drone-port-working",
        filename = ei_graphics_entity_2_path.."drone-port_animation.png",
        width = 512,
        height = 512,
        line_length = 4,
        frame_count = 12,
        animation_speed = 0.4,
        shift = {-0.1, 0.2},
        scale = 0.35,
    },
})

--PORT
------------------------------------------------------------------------------------------------------

local port = {
    name = "ei-drone-port",
    type = "container",
    icon = ei_graphics_item_2_path.."drone-port.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = "ei-drone-port"},
    max_health = 3000,
    corpse = "big-remnants",
    dying_explosion = "medium-explosion",
    collision_box = {{-2.4, -2.4}, {2.4, 2.4}},
    selection_box = {{-2.5, -2.5}, {2.5, 2.5}},
    map_color = ei_data.colors.assembler,
    inventory_size = balance.port_slots,
    -- slots can be filtered (drones / repair packs) and limited like a chest
    inventory_type = "with_filters_and_bar",
    picture = PORT_PICTURE,
    open_sound = {filename = "__base__/sound/machine-open.ogg", volume = 0.6},
    close_sound = {filename = "__base__/sound/machine-close.ogg", volume = 0.6},
}

-- hidden power consumer of the port (created by the script on the port position)
local energy = {
    name = "ei-drone-port-energy",
    type = "electric-energy-interface",
    icon = ei_graphics_item_2_path.."drone-port.png",
    icon_size = 64,
    flags = {"placeable-neutral", "not-on-map", "not-blueprintable", "not-deconstructable",
        "not-upgradable", "not-flammable", "hide-alt-info", "no-copy-paste"},
    hidden = true,
    selectable_in_game = false,
    collision_box = {{-2.4, -2.4}, {2.4, 2.4}},
    collision_mask = {layers = {}},
    selection_box = {{-2.5, -2.5}, {2.5, 2.5}},
    max_health = 3000,
    energy_source = {
        type = "electric",
        usage_priority = "secondary-input",
        buffer_capacity = balance.port_buffer,
        input_flow_limit = balance.port_input,
        output_flow_limit = "0W",
    },
    energy_usage = balance.port_idle_usage,
    energy_production = "0W",
}

data:extend({
    port,
    energy,
    {
        name = "ei-drone-port",
        type = "item",
        icon = ei_graphics_item_2_path.."drone-port.png",
        icon_size = 64,
        subgroup = "ei-alien-structures-2",
        order = "c-a",
        place_result = "ei-drone-port",
        stack_size = 10,
    },
    {
        name = "ei-drone",
        type = "item",
        icon = ei_graphics_item_2_path.."drone.png",
        icon_size = 64,
        subgroup = "ei-alien-structures-2",
        order = "c-b",
        stack_size = 10,
    },
    {
        name = "ei-drone-port",
        type = "recipe",
        category = "crafting",
        energy_required = 10,
        ingredients = {
            {type = "item", name = "steel-plate", amount = 20},
            {type = "item", name = "ei-steel-mechanical-parts", amount = 32},
            {type = "item", name = "ei-electronic-parts", amount = 20},
            {type = "item", name = "ei-computer-core", amount = 1},
        },
        results = {{type = "item", name = "ei-drone-port", amount = 1}},
        enabled = false,
        main_product = "ei-drone-port",
    },
    {
        name = "ei-drone",
        type = "recipe",
        category = "crafting",
        energy_required = 5,
        ingredients = {
            {type = "item", name = "ei-electronic-parts", amount = 4},
            {type = "item", name = "ei-steel-mechanical-parts", amount = 6},
            {type = "item", name = "ei-insulated-wire", amount = 4},
            {type = "item", name = "ei-energy-crystal", amount = 2},
        },
        results = {{type = "item", name = "ei-drone", amount = 1}},
        enabled = false,
        main_product = "ei-drone",
    },
    {
        -- target picker, handed out by the port GUI (not craftable)
        name = "ei-drone-remote",
        type = "selection-tool",
        icon = ei_graphics_item_2_path.."drone.png",
        icon_size = 64,
        stack_size = 1,
        flags = {"only-in-cursor", "not-stackable", "spawnable"},
        hidden = true,
        select = {
            border_color = {r = 0.3, g = 0.8, b = 1, a = 0.6},
            cursor_box_type = "entity",
            mode = {"any-entity"},
        },
        alt_select = {
            border_color = {r = 1, g = 0.3, b = 0.3, a = 0.6},
            cursor_box_type = "not-allowed",
            mode = {"nothing"},
        },
    },
    {
        -- alien tech tree tier 2, script-only (scripts/data-final-updates/alien_tree_techs.lua)
        name = "ei-drone-port",
        type = "technology",
        icon = ei_graphics_tech_2_path.."drone-port.png",
        icon_size = 256,
        prerequisites = {"ei-resonance-synthesizer"},
        effects = {
            {type = "unlock-recipe", recipe = "ei-drone-port"},
            {type = "unlock-recipe", recipe = "ei-drone"},
        },
        research_trigger = {
            type = "scripted",
            trigger_description = {"technology-description.ei-alien-tree-trigger"},
        },
    },
})
