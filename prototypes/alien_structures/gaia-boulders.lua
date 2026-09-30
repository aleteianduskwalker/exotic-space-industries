--====================================================================================================
-- GAIA BOULDERS (3.2.0)
--====================================================================================================
-- Minable boulders of Gaia, one simple-entity per colour family ("ei-gaia-boulder-<family>"),
-- every family picks a random sprite of its variations. Numbers: lib/balance.lua -> gaia_boulders.
--   * autoplace: only on Gaia (default_enabled = false, listed in gaia-map-gen.lua), scattered alone
--   * ruins (POI): rocks of the presets spawned on Gaia become boulders (alien_spawner.lua)
-- Template: the vanilla huge rock (sounds, particles, resistances), the boulder sprites have a
-- similar size and a baked shadow on the right side like the vanilla rock sprites.
-- [CHECK IN GAME] sprite shift and collision box.
--====================================================================================================

local ei_balance = require("lib/balance")

-- pixel sizes of graphics-2/graphics/terrain/gaia-boulder-<n>.png (the sprites are not trimmed)
local SPRITE_SIZES = {
    [1] = {188, 127}, [2] = {195, 135}, [3] = {205, 132}, [4] = {144, 142}, [5] = {130, 107},
    [6] = {165, 109}, [7] = {150, 133}, [8] = {156, 111}, [9] = {187, 120}, [10] = {225, 128},
    [11] = {183, 144}, [12] = {186, 160}, [13] = {181, 174}, [14] = {212, 150}, [15] = {155, 117},
}

-- family order in the list of all boulders (used by the map gen and the runtime)
local FAMILIES = {"violet", "red", "slate", "basalt", "ice", "sandstone"}

---Sprite variation of one boulder picture.
---@param number integer sprite number
local function boulder_picture(number)
    local size = SPRITE_SIZES[number]
    return {
        filename = ei_graphics_terrain_path.."gaia-boulder-"..number..".png",
        width = size[1],
        height = size[2],
        scale = 0.5,
        -- the right part of every sprite is the baked shadow (same as the vanilla huge rock)
        shift = {0.25, -0.1},
    }
end

local template = data.raw["simple-entity"]["huge-rock"]
local boulders = {}

for index, family in ipairs(FAMILIES) do
    local config = ei_balance.gaia_boulders[family]
    local boulder = table.deepcopy(template)

    boulder.name = "ei-gaia-boulder-"..family
    -- icon: the vanilla huge rock icon of the template (the boulder sprites are not square)
    boulder.localised_name = nil
    boulder.order = "a[decorative]-l[rock]-z[gaia]-"..index.."["..family.."]"
    boulder.collision_box = {{-1.2, -0.8}, {1.2, 0.8}}
    boulder.selection_box = {{-1.4, -1.0}, {1.4, 1.0}}
    boulder.map_color = {r = 0.45, g = 0.45, b = 0.55}

    boulder.pictures = {}
    for _, number in ipairs(config.sprites) do
        table.insert(boulder.pictures, boulder_picture(number))
    end

    boulder.minable = {mining_time = 2, mining_particle = "stone-particle", results = {}}
    for _, result in ipairs(config.results) do
        local name, min, max, probability = result[1], result[2], result[3], result[4]
        if data.raw.item[name] then
            table.insert(boulder.minable.results, {
                type = "item", name = name, amount_min = min, amount_max = max, probability = probability,
            })
        end
    end

    -- scattered alone on Gaia only (the planet lists the boulders in its map gen settings)
    boulder.autoplace = {
        order = "a[doodad]-a[rock]-z[ei-gaia-boulder]-"..index,
        probability_expression = tostring(config.probability),
        default_enabled = false,
    }

    table.insert(boulders, boulder)
end

data:extend(boulders)
