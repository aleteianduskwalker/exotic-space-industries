local planet_map_gen = require("gaia-map-gen")

local gaia = table.deepcopy(data.raw.planet.fulgora)

gaia.name = "Gaia"
gaia.order = "g[gaia]"
gaia.distance = 10
gaia.orientation = 0.75
gaia.icon = ei_graphics_2_path.."graphics/icons/gaia.png"
gaia.icon_size = 64
gaia.starmap_icon = ei_graphics_2_path.."graphics/icons/starmap-planet-gaia.png"
gaia.starmap_icon_size = 2048

gaia.map_gen_settings = planet_map_gen.gaia()

if ei_lib.config("gaia-freezing") then
  gaia.entities_require_heating = true
end

gaia.lightning_properties.lightnings_per_chunk_per_tick = data.raw.planet.fulgora.lightning_properties.lightnings_per_chunk_per_tick * 2
gaia.lightning_properties.lightning_multiplier_at_day = 0.5
gaia.lightning_properties.lightning_multiplier_at_night = 0.5

gaia.surface_properties["pressure"] = 2000
gaia.surface_properties["solar-power"] = 0

gaia.persistent_ambient_sounds =
{
  base_ambience = { filename = "__space-age__/sound/wind/base-wind-aquilo.ogg", volume = 0.5 },
  wind = { filename = "__space-age__/sound/wind/wind-aquilo.ogg", volume = 0.8 },
  crossfade = 
  {
    order = { "wind", "base_ambience" },
    curve_type = "cosine",
    from = { control = 0.35, volume_percentage = 0.0 },
    to = { control = 2, volume_percentage = 100.0 }
  },
  semi_persistent =
  {
    {
      sound = { variations = sound_variations("__space-age__/sound/world/semi-persistent/cold-wind-gust", 5, 0.3) },
      delay_mean_seconds = 15,
      delay_variance_seconds = 9
    }
  }
}

gaia.surface_render_parameters = 
{
  fog = 
  {
      color1 = 
      {
          0.13,
          0.32,
          0.48,
          1
      },
      color2 = 
      {
          0.5,
          0.11,
          0.18,
          1
      },
      detail_noise_texture = 
      {
          filename = "__core__/graphics/clouds-detail-noise.png",
          size = 2048
      },
      shape_noise_texture = 
      {
          filename = "__core__/graphics/clouds-noise.png",
          size = 2048
      }
  }
}

data:extend({gaia})


-- Gaia water: offshore pumps pump morphium from it
local gaia_water = table.deepcopy(data.raw.tile["water"])
gaia_water.name = "ei-gaia-water"
gaia_water.fluid = "ei-morphium"
data:extend({gaia_water})

-- landfill can be placed on Gaia water (and shallow/mud water)
local landfill = data.raw.item.landfill
if landfill and landfill.place_as_tile then
  landfill.place_as_tile.tile_condition = landfill.place_as_tile.tile_condition or {}
  for _, tile in pairs({"water-shallow", "water-mud", "ei-gaia-water"}) do
    if not ei_lib.table_contains_value(landfill.place_as_tile.tile_condition, tile) then
      table.insert(landfill.place_as_tile.tile_condition, tile)
    end
  end
end




data:extend{{
    type = "space-connection",
    name = "nauvis-gaia",
    subgroup = "planet-connections",
    from = "nauvis",
    to = "Gaia",
    order = "0",
    length = 100000,
    asteroid_spawn_definitions = {},
    icon = ei_graphics_2_path.."graphics/icons/gaia.png",
}}

data:extend{{
    name = "ei-gaia",
    type = "technology",

    icons = {
      {
        icon = ei_graphics_tech_path.."gaia.png",
        icon_size = 256
      },
      {
        icon = "__core__/graphics/icons/technology/constants/constant-planet.png",
        icon_size = 128,
        scale = 0.5,
        shift = {
          50,
          50
        }
      }
    },

    essential = true,
    icon_size = 256,
    prerequisites = {"rocket-silo"},
    effects = {
      {
        space_location = "Gaia",
        type = "unlock-space-location",
        use_icon_overlay_constant = true
      }
    },
    unit = {
        count = 100,
        ingredients = ei_data.science["computer-age-space"],
        time = 20
    },
    age = "advanced-computer-age"
}}