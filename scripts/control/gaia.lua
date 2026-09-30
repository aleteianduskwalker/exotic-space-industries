--====================================================================================================
-- GAIA
--====================================================================================================
-- Gaia specific entity behaviour:
--   * entity swaps: some entities have a stronger "Gaia" variant which is used while they stand
--     on a Gaia surface and swapped back to the regular variant elsewhere
--   * build restrictions (entities that can not be built on / outside of Gaia)
--   * void engine: needs an "out-of-map" void rift in range, draws beams into it
--   * void rift generator (3.1.0): carves its own out-of-map rift, restores the terrain on removal
--   * 3.2.0: the fulgoran ruin attractors of Gaia are replaced by the non-craftable ei-conduit-gaia
--     (new chunks, old saves and the map gen settings of existing Gaia surfaces)
--
-- Gaia surfaces are listed in storage.gaia_surfaces (the planet surface "Gaia" is always included;
-- other mods may add surfaces through the "exotic-industries" remote interface).
--====================================================================================================

local util = require("scripts/control/util")
local ei_balance = require("lib/balance")

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

--VOID RIFT GENERATOR (3.1.0, design doc §5)
------------------------------------------------------------------------------------------------------
-- On build: carves a patch_size x patch_size out-of-map patch south of the generator
-- (balance.void_rift), remembers the original tiles/resources and casts the void beams into it.
-- On removal: removes the beams and restores the original terrain and resources.
-- storage.ei.void_rift_generators[unit_number] = {entity, beams, tiles = {{name, position}},
--                                                 resources = {{name, position, amount}}}

local VOID_RIFT_GENERATOR = "ei-void-rift-generator"

---Area of the rift patch of a generator (south side, balance.void_rift.patch_gap tiles away).
---@param entity LuaEntity
---@return BoundingBox
local function rift_patch_area(entity)
    local rift = ei_balance.void_rift
    local box = entity.bounding_box
    local center_x = math.floor(entity.position.x)
    local top = math.ceil(box.right_bottom.y) + rift.patch_gap
    local half = math.floor(rift.patch_size / 2)
    return {
        left_top = {x = center_x - half, y = top},
        right_bottom = {x = center_x - half + rift.patch_size, y = top + rift.patch_size},
    }
end

---Returns the generator as item with a flying text (build not possible here).
local function refuse_generator(entity, text)
    flying_text(entity, text, {r = 1, g = 0.3, b = 0.3})
    model.create_drop(entity)
    entity.destroy()
end

---Registers a freshly built void rift generator and carves its rift.
---@param entity LuaEntity
function model.register_void_rift_generator(entity)
    if entity.name ~= VOID_RIFT_GENERATOR or not entity.unit_number then
        return
    end

    local surface = entity.surface
    if surface.platform then
        refuse_generator(entity, "Can't open a Void Rift on a platform")
        return
    end

    -- the patch must be free: no entities except resources (they are stored and restored)
    local area = rift_patch_area(entity)
    local blocking = surface.find_entities_filtered{area = area, type = "resource", invert = true}
    for _, blocker in pairs(blocking) do
        -- only colliding entities block (characters, trees, buildings...); remnants/markers do not
        if blocker.valid and next(blocker.prototype.collision_mask.layers) ~= nil then
            refuse_generator(entity, "Void Rift area is blocked")
            return
        end
    end

    local data = {entity = entity, tiles = {}, resources = {}}

    for _, resource in pairs(surface.find_entities_filtered{area = area, type = "resource"}) do
        table.insert(data.resources, {name = resource.name, position = resource.position, amount = resource.amount})
        resource.destroy()
    end

    local new_tiles = {}
    for x = area.left_top.x, area.right_bottom.x - 1 do
        for y = area.left_top.y, area.right_bottom.y - 1 do
            local tile = surface.get_tile(x, y)
            table.insert(data.tiles, {name = tile.name, position = {x = x, y = y}})
            table.insert(new_tiles, {name = VOID_RIFT_TILE, position = {x = x, y = y}})
        end
    end
    surface.set_tiles(new_tiles, true)

    local rift_tile = surface.get_tile(math.floor((area.left_top.x + area.right_bottom.x) / 2), area.left_top.y)
    data.beams = cast_void_beam(entity, rift_tile)

    storage.ei.void_rift_generators = storage.ei.void_rift_generators or {}
    storage.ei.void_rift_generators[entity.unit_number] = data
    flying_text(entity, "Void Rift opened", {r = 0, g = 0.77, b = 1})
end

---Removes the beams and restores the original terrain of a generator that gets removed.
---@param entity LuaEntity
function model.remove_void_rift_generator(entity)
    if entity.name ~= VOID_RIFT_GENERATOR or not entity.unit_number then
        return
    end

    local generators = storage.ei.void_rift_generators
    local data = generators and generators[entity.unit_number]
    if not data then
        return
    end

    for _, group in pairs(data.beams or {}) do
        for _, beam in pairs(group) do
            util.destroy_entity(beam)
        end
    end

    local surface = entity.surface
    surface.set_tiles(data.tiles, true)
    for _, resource in pairs(data.resources) do
        surface.create_entity{name = resource.name, position = resource.position, amount = resource.amount}
    end

    generators[entity.unit_number] = nil
end

--GAIA CONDUITS (3.2.0)
------------------------------------------------------------------------------------------------------

local RUIN_ATTRACTOR = "fulgoran-ruin-attractor"
local GAIA_CONDUIT = "ei-conduit-gaia"

---Replaces the vanilla ruin attractors of a Gaia surface (optionally only inside an area) with
---ei-conduit-gaia. Does nothing outside of Gaia.
---@param surface LuaSurface
---@param area BoundingBox|nil
function model.replace_ruin_attractors(surface, area)
    if not (surface and surface.valid and model.is_gaia_surface(surface)) then
        return
    end
    if not prototypes.entity[GAIA_CONDUIT] then
        return
    end

    for _, attractor in pairs(surface.find_entities_filtered{name = RUIN_ATTRACTOR, area = area}) do
        local position = attractor.position
        attractor.destroy()
        surface.create_entity{
            name = GAIA_CONDUIT,
            position = position,
            force = "neutral",
            create_build_effect_smoke = false,
            raise_built = false,
        }
    end
end

---Future chunks of an existing Gaia surface generate ei-conduit-gaia instead of ruin attractors.
---@param surface LuaSurface
local function update_map_gen_settings(surface)
    local settings = surface.map_gen_settings
    local entity_settings = settings.autoplace_settings
        and settings.autoplace_settings.entity
        and settings.autoplace_settings.entity.settings
    if not (entity_settings and entity_settings[RUIN_ATTRACTOR]) then
        return
    end

    entity_settings[GAIA_CONDUIT] = entity_settings[RUIN_ATTRACTOR]
    entity_settings[RUIN_ATTRACTOR] = nil
    -- never let a map gen detail break the migration
    pcall(function() surface.map_gen_settings = settings end)
end

---Migration (idempotent): every existing Gaia surface.
function model.migrate_conduits()
    for surface_name, _ in pairs(storage.gaia_surfaces or {}) do
        local surface = game.get_surface(surface_name)
        if surface then
            update_map_gen_settings(surface)
            model.replace_ruin_attractors(surface)
        end
    end
end

---on_chunk_generated: ruin attractors generated by old map gen settings are replaced.
function model.on_chunk_generated(event)
    model.replace_ruin_attractors(event.surface, event.area)
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
        model.register_void_rift_generator(entity)
    end
    if entity.valid then
        model.swap_entity(entity)
    end
end

function model.on_destroyed_entity(entity)
    if util.is_valid(entity) then
        model.remove_void_entity(entity)
        model.remove_void_rift_generator(entity)
    end
end

return model
