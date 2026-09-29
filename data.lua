--====================================================================================================
--PRE INIT
--====================================================================================================

-- info

ei_mod = {}
ei_mod.stage = "data"

ei_mod.dev_mode = false
ei_mod.show_temp = false
ei_mod.show_dummy = false
ei_mod.show_exotic_gates = true

-- lib and paths

require("lib/paths")

ei_lib = require("lib/lib")
ei_data = require("lib/data")

--====================================================================================================
--MAIN CONTENT CODE
--====================================================================================================

-- add new categories, entities, items, techs, recipes fluids, resources

require("prototypes/pipe-covers")
require("prototypes/other")
require("prototypes/fluids")
require("prototypes/styles")
require("prototypes/informatron_sprites")
require("prototypes/age_techs")
require("prototypes/dark_age/dark_age")
require("prototypes/steam_age/steam_age")
require("prototypes/electricity_age/electricity_age")
require("prototypes/computer_age/computer_age")
require("prototypes/quantum_age/quantum_age")
require("prototypes/alien_structures/alien_structures")
require("prototypes/exotic_age/exotic_age")
require("prototypes/dark_age/loaders")
require("prototypes/electricity_age/robots")

--====================================================================================================
--COMPATIBILITY CODE
--====================================================================================================

-- dummy lab so that Factorio doesn't complain about there being no lab that can handle techs
data:extend({
  {
    name = "ei-dummy-lab",
    type = "lab",
    energy_source = {type = "void"},
    energy_usage = "1J",
    inputs = {},
  }
})

-- Alien Biomes: keep the Gaia and induction matrix tiles on top of its tile layers
alien_biomes_priority_tiles = alien_biomes_priority_tiles or {}
for _, tile in pairs(data.raw.tile) do
  if ei_lib.contains(tile.name, "gaia") or ei_lib.contains(tile.name, "induction-matrix") then
    table.insert(alien_biomes_priority_tiles, tile.name)
  end
end
