--====================================================================================================
-- GAIA
--====================================================================================================
-- Gaia specific entity behaviour:
--   * entity swaps: some entities have a stronger "Gaia" variant which is used while they stand
--     on a Gaia surface and swapped back to the regular variant elsewhere
--   * build restrictions (entities that can not be built on / outside of Gaia)
--   * void engine: needs an "out-of-map" void rift in range, draws beams into it
--
-- Gaia surfaces are listed in storage.gaia_surfaces (the planet surface "Gaia" is always included;
-- other mods may add surfaces through the "exotic-industries" remote interface).
--====================================================================================================

local util = require("scripts/control/util")

local model = {}

-- buildings that will get destroyed (returned as item) when placed on Gaia
model.destroy_gaia = {}

-- buildings that will get destroyed (returned as item) when placed outside of Gaia
model.destroy_non_gaia = {}

-- regular entity -> Gaia variant (swapped on Gaia surfaces)
model.swap_gaia = {
    ["ei-crystal-accumulator"] = "ei-crystal-accumulator-gaia",
}

-- Gaia variant -> regular entity (swapped outside of Gaia, prevents moving the boosted variant away)
model.swap_non_gaia = {}
for regular, gaia_variant in pairs(model.swap_gaia) do
    model.swap_non_gaia[gaia_variant] = regular
end

local VOID_RIFT_TILE = "out-of-map"
local VOID_RIFT_RADIUS = 30

--UTIL
------------------------------------------------------------------------------------------------------

---Returns true if the surface counts as Gaia.
---@param surface LuaSurface
function model.is_gaia_surface(surface)
    local gaia_surfaces = storage.gaia_surfaces
    return gaia_surfaces ~= nil and gaia_surfaces[surface.name] == true
end

---Drops the entity as an item (marked for deconstruction) at its position.
---Only works for entities whose item has the same name as the entity.
function model.create_drop(entity)
    if not util.is_valid(entity) or not prototypes.item[entity.name] then
        return
    end

    entity.surface.spill_item_stack{
        position = entity.position,
        stack = {name = entity.name, count = 1},
        enable_looted = true,
        force = entity.force,
        allow_belts = false,
    }
end

local function flying_text(entity, text, color)
    rendering.draw_text{
        target = entity.position,
        text = text,
        alignment = "center",
        vertical_alignment = "middle",
        color = color,
        surface = entity.surface,
        scale = 1,
        time_to_live = 120,
    }
end

--GAIA RELATED ENTITY SWAPS
------------------------------------------------------------------------------------------------------

---Swaps an entity to its Gaia variant on Gaia, or back to the regular one elsewhere.
---@param entity LuaEntity
function model.swap_entity(entity)
    if not util.is_valid(entity) then
        return
    end

    local target_name
    if model.is_gaia_surface(entity.surface) then
        target_name = model.swap_gaia[entity.name]
    else
        target_name = model.swap_non_gaia[entity.name]
    end

    if not target_name then
        return
    end

    local surface = entity.surface
    local position = entity.position
    local force = entity.force
    local direction = entity.direction
    local quality = entity.quality
    local energy = entity.energy

    entity.destroy()

    local swapped = surface.create_entity({
        name = target_name,
        position = position,
        force = force,
        direction = direction,
        quality = quality,
        create_build_effect_smoke = false,
        raise_built = false,
    })

    if swapped and swapped.valid then
        swapped.energy = energy
    end
end

--BUILD RESTRICTIONS
------------------------------------------------------------------------------------------------------

---Destroys entities that are not allowed on this surface and returns them as items.
---@return boolean destroyed
function model.destroy_building(entity)
    local on_gaia = model.is_gaia_surface(entity.surface)

    if model.destroy_gaia[entity.name] and on_gaia then
        flying_text(entity, "Can't build on Gaia!", {r = 1, g = 0, b = 0})
    elseif model.destroy_non_gaia[entity.name] and not on_gaia then
        flying_text(entity, "Can only be built on Gaia!", {r = 1, g = 0, b = 0})
    else
        return false
    end

    model.create_drop(entity)
    entity.destroy()
    return true
end

--VOID ENGINE
------------------------------------------------------------------------------------------------------

---Creates the visual beams between a void engine and a rift tile. Returns the created beams.
local function cast_void_beam(engine, rift_tile)
    local rift_pos = {rift_tile.position.x + 0.5, rift_tile.position.y + 0.75}
    local engine_pos = {engine.position.x, engine.position.y - 5}
    local beams = {own = {}, rift = {}}

    for _ = 1, 3 do
        local beam = engine.surface.create_entity({
            name = "electric-beam",
            force = engine.force,
            position = engine_pos,
            target = engine,
            source_position = engine_pos,
            raise_built = false,
            create_build_effect_smoke = false,
        })
        if beam then table.insert(beams.own, beam) end
    end

    for _ = 1, 3 do
        local beam = engine.surface.create_entity({
            name = "electric-beam",
            force = engine.force,
            position = rift_pos,
            target_position = engine_pos,
            source_position = rift_pos,
            raise_built = false,
            create_build_effect_smoke = false,
        })
        if beam then table.insert(beams.rift, beam) end
    end

    engine.surface.create_entity({name = "blood-explosion-huge", position = rift_pos, force = engine.force})
    engine.surface.create_entity({name = "atomic-fire-smoke", position = rift_pos, force = engine.force})

    return beams
end

---Registers a freshly built void engine, or returns it as item if no void rift is in range.
function model.register_void_engine(entity)
    if entity.name ~= "ei-void-engine" or not entity.unit_number then
        return
    end

    local rift_tiles = entity.surface.find_tiles_filtered({
        position = entity.position,
        radius = VOID_RIFT_RADIUS,
        name = VOID_RIFT_TILE,
    })

    if #rift_tiles == 0 then
        flying_text(entity, "No Void Rift in Range", {r = 1, g = 0.77, b = 0})
        model.create_drop(entity)
        entity.destroy()
        return
    end

    flying_text(entity, "Void Engine Active", {r = 0, g = 0.77, b = 1})

    storage.ei.void_engines = storage.ei.void_engines or {}
    storage.ei.void_engines[entity.unit_number] = {
        entity = entity,
        beams = cast_void_beam(entity, rift_tiles[math.random(1, #rift_tiles)]),
    }
end

---Removes the beams of a void engine that gets removed.
function model.remove_void_entity(entity)
    if entity.name ~= "ei-void-engine" or not entity.unit_number then
        return
    end

    local engines = storage.ei.void_engines
    local data = engines and engines[entity.unit_number]
    if not data then
        return
    end

    if data.beams then
        for _, group in pairs(data.beams) do
            for _, beam in pairs(group) do
                util.destroy_entity(beam)
            end
        end
    end

    engines[entity.unit_number] = nil
end

--DEV COMMANDS
------------------------------------------------------------------------------------------------------

---/gaia teleports an admin to the Gaia surface (developer helper).
function model.spawn_command(event)
    if event.command ~= "gaia" then
        return
    end

    local player = util.event_player(event)
    if not player or not player.admin then
        return
    end

    local surface = game.get_surface("Gaia")
    if not surface then
        player.print("Gaia surface does not exist yet.")
        return
    end

    player.teleport({0, 0}, surface)
end

--====================================================================================================
--HANDLERS
--====================================================================================================

function model.on_built_entity(entity)
    if not util.is_valid(entity) then
        return
    end

    if model.destroy_building(entity) then
        return
    end

    model.register_void_engine(entity)
    if entity.valid then
        model.swap_entity(entity)
    end
end

function model.on_destroyed_entity(entity)
    if util.is_valid(entity) then
        model.remove_void_entity(entity)
    end
end

return model
