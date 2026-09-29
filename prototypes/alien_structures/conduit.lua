--====================================================================================================
-- CONDUIT (design doc §8 "Harness the storm")
--====================================================================================================
-- A lightning attractor that converts part of every attracted strike into electricity.
-- Pure data-stage prototype, no script: Factorio's lightning-attractor natively
--   * pulls lightning in its range (protecting nearby buildings - also from the storm EMP, §7)
--   * converts `efficiency` of the strike energy into its electric buffer (energy_source)
-- Numbers: lib/balance.lua -> conduit. Unlocked together with the Gaia technology (ei-gaia),
-- because it is part of the basic "survive on Gaia" kit, not of the alien tree.
-- Graphics: Hurricane046 "conduit" package (graphics/conduit), animation parameters from its JSON:
--   200x290 frames, 10 per line, 60 frames, scale 0.5; emission layer = glow / additive.
-- [ASSUMPTION] recipe: not specified in the document, built from computer-age materials.
--====================================================================================================

local ei_balance = require("lib/balance")

local CONDUIT_PATH = ei_path.."graphics/conduit/"

---One 60 frame layer of the conduit sprite sheets.
---@param file string file name inside graphics/conduit
---@param glow boolean|nil emission layer (drawn as glow, additive)
local function conduit_layer(file, glow)
    return {
        filename = CONDUIT_PATH..file,
        width = 200,
        height = 290,
        line_length = 10,
        frame_count = 60,
        scale = 0.5,
        shift = {0, -0.6},
        draw_as_glow = glow or nil,
        blend_mode = glow and "additive" or nil,
    }
end

local shadow = {
    filename = CONDUIT_PATH.."conduit-hr-shadow.png",
    width = 600,
    height = 400,
    scale = 0.5,
    shift = {1.2, 0.3},
    draw_as_shadow = true,
}

-- idle picture: first frame of the base sheet + shadow
local idle_base = conduit_layer("conduit-animation.png")
idle_base.line_length, idle_base.frame_count = nil, nil

local shadow_animated = table.deepcopy(shadow)
shadow_animated.repeat_count = 60

data:extend({
    {
        name = "ei-conduit",
        type = "item",
        icon = CONDUIT_PATH.."conduit-icon.png",
        icon_size = 64,
        subgroup = "energy",
        order = "e[lightning]-e[ei-conduit]",
        place_result = "ei-conduit",
        stack_size = 20,
    },
    {
        name = "ei-conduit",
        type = "recipe",
        category = "crafting",
        energy_required = 10,
        ingredients = {
            {type = "item", name = "steel-plate", amount = 20},
            {type = "item", name = "copper-cable", amount = 40},
            {type = "item", name = "ei-energy-crystal", amount = 10},
            {type = "item", name = "ei-electronic-parts", amount = 10},
        },
        results = {{type = "item", name = "ei-conduit", amount = 1}},
        enabled = false,
        main_product = "ei-conduit",
    },
    {
        name = "ei-conduit",
        type = "lightning-attractor",
        icon = CONDUIT_PATH.."conduit-icon.png",
        icon_size = 64,
        flags = {"placeable-neutral", "placeable-player", "player-creation"},
        minable = {mining_time = 0.5, result = "ei-conduit"},
        max_health = 500,
        corpse = "medium-remnants",
        dying_explosion = "medium-explosion",
        collision_box = {{-1.4, -1.4}, {1.4, 1.4}},
        selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
        drawing_box_vertical_extension = 2,
        map_color = ei_data.colors.alien,
        lightning_strike_offset = {0, -3},
        range_elongation = ei_balance.conduit.range_elongation,
        efficiency = ei_balance.conduit.efficiency,
        energy_source = {
            type = "electric",
            buffer_capacity = ei_balance.conduit.buffer,
            usage_priority = "primary-output",
            output_flow_limit = ei_balance.conduit.output_flow_limit,
            drain = "0W",
        },
        chargable_graphics = {
            picture = {layers = {idle_base, shadow}},
            charge_animation = {layers = {
                conduit_layer("conduit-animation.png"),
                conduit_layer("conduit-emission.png", true),
                shadow_animated,
            }},
            charge_animation_is_looped = true,
            charge_cooldown = 30,
            discharge_animation = {layers = {
                conduit_layer("conduit-animation.png"),
                conduit_layer("conduit-emission.png", true),
                shadow_animated,
            }},
            discharge_cooldown = 60,
        },
    },
})

-- unlocked with Gaia (basic Gaia survival kit, design doc §8)
table.insert(data.raw.technology["ei-gaia"].effects, {type = "unlock-recipe", recipe = "ei-conduit"})
