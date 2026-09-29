--====================================================================================================
-- DATA CENTER (brief log §2.6, design doc §12)
--====================================================================================================
-- An assembler that crafts ANY known science pack (vanilla, Space Age, other mods and this mod's
-- own alien packs) out of ei-computing-power only - about 10x slower than normal production.
--   * entity/item/tech/category: this file
--   * one recipe per science pack ("ei-data-center-<pack>") and the building recipe are generated
--     in data-final-fixes: scripts/data-final-updates/data_center_recipes.lua
--     (the pack list is data.raw.lab["ei-big-lab"].inputs, complete only after labs.lua)
--   * fluid box 1 (computing power) is registered in the data network (data_network.lua)
-- Graphics: Hurricane046 "cybernetics-facility" package (graphics/cybernetics-facility):
--   8x8 = 64 frames of 270x310 px, scale 0.5; the "frozen" sheet provides the frozen_patch shown
--   while the building lacks heating on Gaia.
--====================================================================================================

local FACILITY_PATH = ei_path.."graphics/cybernetics-facility/cybernetics-facility-"

---One 64 frame layer of the cybernetics facility sheets.
---@param file string suffix of the file name
---@param glow boolean|nil emission layer
local function facility_layer(file, glow)
    return {
        filename = FACILITY_PATH..file,
        width = 270,
        height = 310,
        line_length = 8,
        frame_count = 64,
        animation_speed = 0.5,
        scale = 0.5,
        shift = {0, -0.4},
        draw_as_glow = glow or nil,
        blend_mode = glow and "additive" or nil,
    }
end

local shadow = {
    filename = FACILITY_PATH.."hr-shadow.png",
    width = 500,
    height = 350,
    scale = 0.5,
    shift = {1.0, 0.2},
    repeat_count = 64,
    draw_as_shadow = true,
}

-- frozen patch: first frame of the frozen sheet (Sprite, not Animation)
local frozen = facility_layer("hr-frozen-1.png")
frozen.line_length, frozen.frame_count, frozen.animation_speed = nil, nil, nil

data:extend({
    {
        name = "ei-data-center",
        type = "recipe-category",
    },
    {
        name = "ei-data-center",
        type = "item",
        icon = FACILITY_PATH.."icon.png",
        icon_size = 64,
        subgroup = "ei-labs",
        order = "a4",
        place_result = "ei-data-center",
        stack_size = 20,
    },
    {
        name = "ei-data-center",
        type = "technology",
        icon = FACILITY_PATH.."icon-big.png",
        icon_size = 640,
        prerequisites = {"ei-big-lab"},
        effects = {
            -- the building recipe and one recipe per science pack are added in data-final-fixes
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["computer-age"],
            time = 20,
        },
        -- NOTE: no `age` on purpose (age techs become mandatory prerequisites of the next age)
    },
    {
        name = "ei-data-center",
        type = "assembling-machine",
        icon = FACILITY_PATH.."icon.png",
        icon_size = 64,
        flags = {"placeable-neutral", "placeable-player", "player-creation"},
        minable = {mining_time = 1, result = "ei-data-center"},
        max_health = 500,
        corpse = "big-remnants",
        dying_explosion = "medium-explosion",
        collision_box = {{-1.9, -1.9}, {1.9, 1.9}},
        selection_box = {{-2, -2}, {2, 2}},
        map_color = ei_data.colors.assembler,
        crafting_categories = {"ei-data-center"},
        crafting_speed = 1,
        energy_source = {
            type = "electric",
            usage_priority = "secondary-input",
        },
        energy_usage = "2MW",
        allowed_effects = {"speed", "consumption", "pollution"},
        module_slots = 2,
        fluid_boxes = {
            { -- 1: computing power (data network, see data_network.lua)
                volume = 500,
                pipe_covers = pipecoverspictures(),
                pipe_picture = ei_pipe_data,
                pipe_connections = {
                    {flow_direction = "input", direction = defines.direction.east, position = {1.5, 0.5}},
                    {flow_direction = "input", direction = defines.direction.west, position = {-1.5, 0.5}},
                },
                production_type = "input",
            },
        },
        graphics_set = {
            animation = {layers = {facility_layer("hr-animation-1.png"), shadow}},
            working_visualisations = {
                {animation = facility_layer("hr-emission-1.png", true)},
                {light = {type = "basic", intensity = 0.8, size = 12}},
            },
            frozen_patch = frozen,
        },
        working_sound = {
            sound = {filename = "__base__/sound/assembling-machine-t2-1.ogg", volume = 0.5},
            apparent_volume = 0.3,
        },
    },
})
