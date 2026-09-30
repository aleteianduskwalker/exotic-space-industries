--====================================================================================================
-- RADIO STATIONS (3.2.0)
--====================================================================================================
-- Wireless circuit network channels (runtime logic: scripts/control/radio_station.lua).
--   * ei-radio-station          100 kW, links stations of the SAME surface (electricity age)
--   * ei-crystal-radio-station  10 MW, links stations on EVERY surface (alien tech tree tier 4)
-- A station is either the transmitter of a channel (a signal chosen in its GUI; one transmitter
-- per channel) or one of any number of receivers. The transmitter sends the signals of the circuit
-- network wired to it, receivers put them into their own circuit network.
--
-- Entities:
--   * main building: assembling machine with a fixed, never finishing "running" recipe, so it
--     draws its power continuously; it provides the circuit connectors and the graphics
--   * ei-radio-station-output: invisible constant combinator created by the script on the same
--     position and wired to the main building (script wires), it outputs the received signals
-- Graphics: Hurricane046 "radio station" package (graphics/radio-station): 20 frames of 160x290 px,
--   8 per line, scale 0.5. [CHECK IN GAME] shift of the sprite and of the shadow.
--====================================================================================================

local ei_balance = require("lib/balance")

local RADIO_PATH = ei_path.."graphics/radio-station/radio-station-"
local balance = ei_balance.radio_station

---One 20 frame layer of the radio station sheets.
---@param file string suffix of the file name
---@param glow boolean|nil emission layer (drawn as glow, additive)
local function radio_layer(file, glow)
    return {
        filename = RADIO_PATH..file,
        width = 160,
        height = 290,
        line_length = 8,
        frame_count = 20,
        animation_speed = 0.4,
        scale = 0.5,
        shift = {0, -1.25},
        draw_as_glow = glow or nil,
        blend_mode = glow and "additive" or nil,
    }
end

local shadow = {
    filename = RADIO_PATH.."hr-shadow.png",
    width = 400,
    height = 350,
    scale = 0.5,
    shift = {1.9, -0.3},
    repeat_count = 20,
    draw_as_shadow = true,
}

-- the same circuit connector for all 4 directions (the station can not be rotated)
local connector = {variation = 18, main_offset = util.by_pixel(22, 8), shadow_offset = util.by_pixel(30, 16), show_shadow = true}
local circuit_connector = circuit_connector_definitions.create_vector(universal_connector_template,
    {connector, connector, connector, connector})

---Main building prototype.
---@param name string
---@param energy_usage string
local function make_station(name, energy_usage)
    return {
        name = name,
        type = "assembling-machine",
        icon = RADIO_PATH.."icon.png",
        icon_size = 64,
        flags = {"placeable-neutral", "placeable-player", "player-creation", "not-rotatable"},
        minable = {mining_time = 0.5, result = name},
        max_health = 250,
        corpse = "medium-remnants",
        dying_explosion = "medium-explosion",
        collision_box = {{-0.9, -0.9}, {0.9, 0.9}},
        selection_box = {{-1, -1}, {1, 1}},
        drawing_box_vertical_extension = 2.5,
        map_color = ei_data.colors.assembler,
        crafting_categories = {"ei-radio-station"},
        fixed_recipe = "ei-radio-station-running",
        crafting_speed = 1,
        show_recipe_icon = false,
        show_recipe_icon_on_map = false,
        module_slots = 0,
        allowed_effects = {},
        energy_source = {
            type = "electric",
            usage_priority = "secondary-input",
            drain = "0W",
        },
        energy_usage = energy_usage,
        circuit_connector = circuit_connector,
        circuit_wire_max_distance = default_circuit_wire_max_distance or 9,
        graphics_set = {
            animation = {layers = {radio_layer("hr-animation-1.png"), shadow}},
            working_visualisations = {
                {
                    fadeout = true,
                    animation = radio_layer("hr-emission-1.png", true),
                },
            },
        },
        open_sound = {filename = "__base__/sound/machine-open.ogg", volume = 0.6},
        close_sound = {filename = "__base__/sound/machine-close.ogg", volume = 0.6},
    }
end

local station = make_station("ei-radio-station", balance.energy_usage)
local crystal_station = make_station("ei-crystal-radio-station", balance.crystal_energy_usage)

-- crystal variant: same graphics, the icon gets a small energy crystal overlay
local crystal_icon = data.raw.item["ei-energy-crystal"] and data.raw.item["ei-energy-crystal"].icon
local crystal_icons = {{icon = RADIO_PATH.."icon.png", icon_size = 64}}
if crystal_icon then
    table.insert(crystal_icons, {
        icon = crystal_icon,
        icon_size = data.raw.item["ei-energy-crystal"].icon_size or 64,
        scale = 0.25,
        shift = {8, 8},
    })
end
crystal_station.icon = nil
crystal_station.icons = crystal_icons

--HIDDEN OUTPUT COMBINATOR
------------------------------------------------------------------------------------------------------

local empty_sprite = {filename = "__core__/graphics/empty.png", size = 1, priority = "extra-high"}
local empty_4way = {north = empty_sprite, east = empty_sprite, south = empty_sprite, west = empty_sprite}

local output = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
output.name = "ei-radio-station-output"
output.icon = RADIO_PATH.."icon.png"
output.icon_size = 64
output.icons = nil
output.flags = {"placeable-neutral", "placeable-off-grid", "not-on-map", "not-blueprintable",
    "not-deconstructable", "not-upgradable", "not-flammable", "hide-alt-info", "not-rotatable", "no-copy-paste"}
output.hidden = true
output.minable = nil
output.selectable_in_game = false
output.collision_box = {{-0.1, -0.1}, {0.1, 0.1}}
output.selection_box = {{-0.1, -0.1}, {0.1, 0.1}}
output.collision_mask = {layers = {}}
output.corpse = nil
output.dying_explosion = nil
output.fast_replaceable_group = nil
output.next_upgrade = nil
output.sprites = empty_4way
output.activity_led_sprites = empty_4way
output.activity_led_light = nil
output.circuit_wire_max_distance = 0
output.water_reflection = nil

data:extend({
    station,
    crystal_station,
    output,
    {
        name = "ei-radio-station",
        type = "recipe-category",
    },
    {
        -- never finishes: keeps the station "working" (and consuming power) all the time
        name = "ei-radio-station-running",
        type = "recipe",
        category = "ei-radio-station",
        energy_required = 1000,
        ingredients = {},
        results = {},
        enabled = false,
        hidden = true,
        icon = RADIO_PATH.."icon.png",
        icon_size = 64,
        subgroup = "circuit-network",
    },
    {
        name = "ei-radio-station",
        type = "item",
        icon = RADIO_PATH.."icon.png",
        icon_size = 64,
        subgroup = "circuit-network",
        order = "d[other]-e[ei-radio-station]",
        place_result = "ei-radio-station",
        stack_size = 20,
    },
    {
        name = "ei-crystal-radio-station",
        type = "item",
        icons = table.deepcopy(crystal_icons),
        subgroup = "circuit-network",
        order = "d[other]-f[ei-crystal-radio-station]",
        place_result = "ei-crystal-radio-station",
        stack_size = 20,
    },
    {
        name = "ei-radio-station",
        type = "recipe",
        category = "crafting",
        energy_required = 5,
        ingredients = {
            {type = "item", name = "steel-plate", amount = 10},
            {type = "item", name = "ei-insulated-wire", amount = 10},
            {type = "item", name = "electronic-circuit", amount = 5},
            {type = "item", name = "ei-steel-mechanical-parts", amount = 4},
        },
        results = {{type = "item", name = "ei-radio-station", amount = 1}},
        enabled = false,
        main_product = "ei-radio-station",
    },
    {
        name = "ei-crystal-radio-station",
        type = "recipe",
        category = "crafting",
        energy_required = 10,
        ingredients = {
            {type = "item", name = "ei-radio-station", amount = 1},
            {type = "item", name = "ei-high-energy-crystal", amount = 10},
            {type = "item", name = "ei-resonance-data", amount = 5},
            {type = "item", name = "ei-electronic-parts", amount = 10},
        },
        results = {{type = "item", name = "ei-crystal-radio-station", amount = 1}},
        enabled = false,
        main_product = "ei-crystal-radio-station",
    },
    {
        name = "ei-radio-station",
        type = "technology",
        icon = RADIO_PATH.."icon-big.png",
        icon_size = 640,
        prerequisites = {"circuit-network"},
        effects = {
            {type = "unlock-recipe", recipe = "ei-radio-station"},
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["electricity-age"],
            time = 20,
        },
        age = "electricity-age",
    },
    {
        -- alien tree tier 4, script-only (scripts/data-final-updates/alien_tree_techs.lua)
        name = "ei-crystal-radio-station",
        type = "technology",
        icons = {
            {icon = RADIO_PATH.."icon-big.png", icon_size = 640},
        },
        prerequisites = {"ei-resonance-synthesizer", "ei-radio-station"},
        effects = {
            {type = "unlock-recipe", recipe = "ei-crystal-radio-station"},
        },
        research_trigger = {
            type = "scripted",
            trigger_description = {"technology-description.ei-alien-tree-trigger"},
        },
    },
})
