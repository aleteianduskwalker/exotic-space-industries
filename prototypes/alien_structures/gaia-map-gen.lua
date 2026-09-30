--====================================================================================================
-- GAIA MAP GENERATION
--====================================================================================================
-- Gaia uses the terrain shape of Fulgora (elevation, islands, cliffs) with its own tiles and gas
-- patches. The settings are built from a FRESH copy of the vanilla Fulgora settings
-- (planet_map_gen.fulgora()) instead of data.raw.planet.fulgora, because other mods may already
-- have modified Fulgora (its expression names, tiles, ...), which in rare mod combinations turned
-- Gaia into an endless grass field. `enforce_gaia_map_gen` re-applies the essential parts in
-- data-final-fixes for the same reason.
--====================================================================================================

local planet_map_gen = require("__space-age__/prototypes/planet/planet-map-gen")

-- gas patches (resource entity + autoplace control)
local GAIA_RESOURCES = {
    "ei-phytogas-patch",
    "ei-cryoflux-patch",
    "ei-ammonia-patch",
    "ei-coal-gas-patch",
}

-- minable boulders scattered on Gaia (prototypes/alien_structures/gaia-boulders.lua, 3.2.0)
local GAIA_BOULDERS = {
    "ei-gaia-boulder-violet",
    "ei-gaia-boulder-red",
    "ei-gaia-boulder-slate",
    "ei-gaia-boulder-basalt",
    "ei-gaia-boulder-ice",
    "ei-gaia-boulder-sandstone",
}
planet_map_gen.GAIA_BOULDERS = GAIA_BOULDERS

-- the only tiles that are generated on Gaia
local GAIA_TILES = {
    "ei-gaia-grass-1",
    "ei-gaia-grass-2",
    "ei-gaia-grass-1-var",
    "ei-gaia-grass-2-var",
    "ei-gaia-grass-2-var-2",
    "ei-gaia-rock-1",
    "ei-gaia-rock-2",
    "ei-gaia-rock-3",
    "ei-gaia-water",
}

local PATCH_SETTINGS = {frequency = 3, size = 1, richness = 1}
local TILE_SETTINGS = {frequency = 1, size = 1, richness = 1}

---Returns the tile autoplace settings of Gaia.
local function gaia_tile_settings()
    local settings = {}
    for _, tile in pairs(GAIA_TILES) do
        settings[tile] = table.deepcopy(TILE_SETTINGS)
    end
    return settings
end

---Builds the complete Gaia map gen settings.
planet_map_gen.gaia = function()
    local map_gen_settings = planet_map_gen.fulgora()

    map_gen_settings.autoplace_controls = map_gen_settings.autoplace_controls or {}
    for _, resource in pairs(GAIA_RESOURCES) do
        map_gen_settings.autoplace_controls[resource] = table.deepcopy(PATCH_SETTINGS)
    end

    map_gen_settings.autoplace_settings = map_gen_settings.autoplace_settings or {}
    map_gen_settings.autoplace_settings.entity = {settings = {}}
    local entities = map_gen_settings.autoplace_settings.entity.settings
    for _, resource in pairs(GAIA_RESOURCES) do
        entities[resource] = table.deepcopy(PATCH_SETTINGS)
    end
    entities["scrap"] = table.deepcopy(PATCH_SETTINGS)
    -- 3.2.0: the ESI copy of the conduit replaces the vanilla ruin attractor on Gaia
    entities["ei-conduit-gaia"] = table.deepcopy(PATCH_SETTINGS)
    for _, boulder in pairs(GAIA_BOULDERS) do
        entities[boulder] = table.deepcopy(TILE_SETTINGS)
    end

    -- no cliffs on Gaia
    map_gen_settings.cliff_settings = map_gen_settings.cliff_settings or {}
    map_gen_settings.cliff_settings.cliff_elevation_0 = 0
    map_gen_settings.cliff_settings.cliff_elevation_interval = 0
    map_gen_settings.cliff_settings.richness = 0

    map_gen_settings.autoplace_settings.tile = {settings = gaia_tile_settings()}

    return map_gen_settings
end

---Re-applies the essential Gaia map generation settings (called in data-final-fixes).
---Other mods sometimes inject their tiles/expressions into every planet or change Fulgora's
---expression names before Gaia was copied from it.
planet_map_gen.enforce_gaia_map_gen = function()
    local gaia = data.raw.planet and data.raw.planet["Gaia"]
    if not gaia then
        return
    end

    local reference = planet_map_gen.gaia()
    local settings = gaia.map_gen_settings or reference
    gaia.map_gen_settings = settings

    -- terrain shape: vanilla Fulgora expressions
    settings.property_expression_names = reference.property_expression_names

    -- tiles: only Gaia tiles
    settings.autoplace_settings = settings.autoplace_settings or {}
    settings.autoplace_settings.tile = reference.autoplace_settings.tile

    -- resources: make sure the gas patches are always there
    settings.autoplace_controls = settings.autoplace_controls or {}
    settings.autoplace_settings.entity = settings.autoplace_settings.entity or {settings = {}}
    settings.autoplace_settings.entity.settings = settings.autoplace_settings.entity.settings or {}
    for _, resource in pairs(GAIA_RESOURCES) do
        if data.raw["autoplace-control"][resource] then
            settings.autoplace_controls[resource] = settings.autoplace_controls[resource] or table.deepcopy(PATCH_SETTINGS)
        end
        if data.raw.resource[resource] then
            settings.autoplace_settings.entity.settings[resource] = settings.autoplace_settings.entity.settings[resource] or table.deepcopy(PATCH_SETTINGS)
        end
    end

    -- 3.2.0: no vanilla ruin attractors on Gaia, only ei-conduit-gaia
    local entity_settings = settings.autoplace_settings.entity.settings
    entity_settings["fulgoran-ruin-attractor"] = nil
    if data.raw["lightning-attractor"]["ei-conduit-gaia"] then
        entity_settings["ei-conduit-gaia"] = entity_settings["ei-conduit-gaia"] or table.deepcopy(PATCH_SETTINGS)
    end
    for _, boulder in pairs(GAIA_BOULDERS) do
        if data.raw["simple-entity"][boulder] then
            entity_settings[boulder] = entity_settings[boulder] or table.deepcopy(TILE_SETTINGS)
        end
    end

    -- drop entries of prototypes that were removed by other mods (would fail to load)
    for name, _ in pairs(settings.autoplace_settings.tile.settings) do
        if not data.raw.tile[name] then
            settings.autoplace_settings.tile.settings[name] = nil
        end
    end
end

return planet_map_gen
