--====================================================================================================
-- ALIEN SPAWNER
--====================================================================================================
-- Spawns pre-recorded "artifact" structures (lib/spawner_presets.lua) in freshly generated chunks.
-- Spawning happens in two queued steps (tiles first, entities on the next tick) so that the
-- tiles already exist when the entities are placed.
-- Also contains the developer tools (/etool, /etool2) used to record new presets.
--====================================================================================================

local util = require("scripts/control/util")
local presets = require("lib/spawner_presets")

local model = {}

-- surfaces on which artifacts may spawn (keys are surface names)
model.allowed_surfaces = {
    ["nauvis"] = true,
    ["Gaia"] = true,
}

-- entities from recorded presets that must never be spawned
model.forbidden_entities = {
    ["spidertron-leg-1"] = true,
    ["spidertron-leg-2"] = true,
    ["spidertron-leg-3"] = true,
    ["spidertron-leg-4"] = true,
    ["spidertron-leg-5"] = true,
    ["spidertron-leg-6"] = true,
    ["spidertron-leg-7"] = true,
    ["spidertron-leg-8"] = true,
    ["teleporter-flying-text"] = true,
}

-- floating warnings shown when alien flowers get destroyed
model.flower_counter_warnings = {
    [3] = {"exotic-industries.flower-count-3"},
    [5] = {"exotic-industries.flower-count-5"},
    [7] = {"exotic-industries.flower-count-7"},
    [10] = {"exotic-industries.flower-count-10"},
}

-- spawn tuning
local MIN_SPAWN_DISTANCE = 200       -- no artifacts closer than this to (0, 0)
local LEGENDARY_SPAWN_DISTANCE = 200 -- same for legendary presets
local MIN_ARTIFACT_DISTANCE = 200    -- minimal distance between two artifacts
local SPAWN_CHANCE_THRESHOLD = 90    -- roll 1..100, spawn only if roll >= threshold
local QUEUE_TIMEOUT = 10             -- ticks after which an unprocessed queue entry is dropped

--FLOWER GUARDIAN
------------------------------------------------------------------------------------------------------

---Counts destroyed alien flowers (outside of Gaia) and shows escalating warnings.
function model.count_flowers(entity)
    if entity.surface.name == "Gaia" then
        return
    end
    if not (string.find(entity.name, "alien", 1, true) and string.find(entity.name, "flower", 1, true)) then
        return
    end

    storage.ei.flower_counter = (storage.ei.flower_counter or 0) + 1
    local counter = storage.ei.flower_counter

    local warning = model.flower_counter_warnings[counter]
    if warning and math.random(1, 10) > 4 then
        rendering.draw_text{
            target = entity.position,
            text = warning,
            color = {r = 1, g = 0.5, b = 0.5},
            surface = entity.surface,
            scale = 1,
            time_to_live = 120,
        }
    end

    if counter >= 12 then
        rendering.draw_text{
            target = entity.position,
            text = {"exotic-industries.flower-count-12"},
            color = {r = 1, g = 0.2, b = 0.2},
            surface = entity.surface,
            scale = 1,
            time_to_live = 120,
        }
        storage.ei.flower_counter = 0
    end
end

--SPAWNING
------------------------------------------------------------------------------------------------------

---Places the preset tiles around `pos` and clears entities standing on them.
local function spawn_tiles(preset, surface, pos)
    if not preset.tiles then
        return
    end

    local new_tiles = {}
    for i, tile in ipairs(preset.tiles) do
        local x = tile.position.x + pos.x
        local y = tile.position.y + pos.y
        new_tiles[i] = {name = tile.name, position = {x = x, y = y}}

        for _, entity in ipairs(surface.find_entities({{x - 1, y - 1}, {x + 1, y + 1}})) do
            if entity.valid then
                entity.destroy()
            end
        end
    end

    surface.set_tiles(new_tiles)
end

---Removes trees/rocks/resources/cliffs standing where preset entities will be placed.
local function prepare_entities(preset, surface, pos)
    for _, entity_data in ipairs(preset.structure) do
        local colliding = surface.find_entities_filtered({
            position = {pos.x + entity_data.position.x, pos.y + entity_data.position.y},
            radius = 0.5,
            type = {"tree", "cliff", "resource", "simple-entity"},
        })
        for _, entity in ipairs(colliding) do
            if entity.valid then
                entity.destroy()
            end
        end
    end
end

---Places the preset entities around `pos` and marks the spot with an artifact flag.
local function spawn_entities(preset, surface, pos)
    if not preset.structure then
        return
    end

    local force = preset.force or "neutral"
    prepare_entities(preset, surface, pos)

    for _, entity_data in ipairs(preset.structure) do
        local position = {x = pos.x + entity_data.position.x, y = pos.y + entity_data.position.y}

        if model.forbidden_entities[entity_data.name] then
            goto continue
        end
        if not prototypes.entity[entity_data.name] then
            goto continue -- preset references an entity from a mod that is not active
        end
        if not surface.can_place_entity({name = entity_data.name, position = position, force = force}) then
            goto continue
        end

        do
            local tile = surface.get_tile(position)
            if not tile.valid or string.find(tile.name, "water", 1, true) then
                goto continue
            end
        end

        do
            local spawned = surface.create_entity({
                name = entity_data.name,
                position = position,
                force = force,
                raise_built = true,
            })
            if spawned and spawned.valid then
                -- all recorded presets use destructible = true; keep the flag explicit
                spawned.destructible = entity_data.destructible ~= false
                spawned.active = true
            end
        end

        ::continue::
    end

    surface.create_entity({name = "ei-artifact-flag", position = pos, force = force})
end

---Picks a random preset name of the given rarity (respecting mod requirements and
---"only once per game" legendary presets). Returns nil if none is available.
function model.select_preset(rarity)
    storage.ei.legendary_spawns = storage.ei.legendary_spawns or {}

    local candidates = {}
    for preset_name, preset in pairs(presets.entity_presets) do
        if preset.rarity == rarity
            and (not preset.mod or script.active_mods[preset.mod])
            and not (rarity == "legendary" and storage.ei.legendary_spawns[preset_name]) then
            table.insert(candidates, preset_name)
        end
    end

    if #candidates == 0 then
        return nil
    end
    return candidates[math.random(1, #candidates)]
end

---Random point inside the generated chunk area (+-32 tiles around its centre).
local function get_spawn_position(area)
    return {
        x = (area.left_top.x + area.right_bottom.x) / 2 + math.random(-32, 32),
        y = (area.left_top.y + area.right_bottom.y) / 2 + math.random(-32, 32),
    }
end

---Rolls whether an artifact spawns at `pos` and queues it (tiles first).
function model.que_preset(pos, surface, tick)
    if math.random(1, 100) < SPAWN_CHANCE_THRESHOLD then
        return
    end

    local distance = math.sqrt(pos.x ^ 2 + pos.y ^ 2)
    if distance < MIN_SPAWN_DISTANCE then
        return
    end

    -- rarity roll: <25 common, <50 rare, <75 very rare, else legendary
    local rarity = math.random(1, 100)
    local preset
    if rarity < 25 then
        preset = model.select_preset("common")
    elseif rarity < 50 then
        preset = model.select_preset("rare")
    elseif rarity < 75 then
        preset = model.select_preset("very rare")
    elseif distance >= LEGENDARY_SPAWN_DISTANCE then
        preset = model.select_preset("legendary")
    end

    if not preset then
        return
    end

    -- keep a minimal distance between artifacts
    local flags = surface.count_entities_filtered({
        position = pos,
        radius = MIN_ARTIFACT_DISTANCE,
        name = "ei-artifact-flag",
        limit = 1,
    })
    if flags > 0 then
        return
    end

    table.insert(storage.ei.spawner_queue, {
        tick = tick,
        preset = preset,
        pos = pos,
        surface = surface,
        tiles = true,
    })
end

---Processes queued spawns. Runs every tick; the queue is usually empty.
function model.update()
    local queue = storage.ei.spawner_queue
    if not queue or #queue == 0 then
        return
    end

    local tick = game.tick
    local follow_ups = {}

    -- iterate backwards so that table.remove does not skip entries
    for i = #queue, 1, -1 do
        local entry = queue[i]
        local preset = presets.entity_presets[entry.preset]

        if not preset or not util.is_valid(entry.surface) or tick - entry.tick > QUEUE_TIMEOUT then
            table.remove(queue, i)
        elseif tick >= entry.tick then
            table.remove(queue, i)

            if entry.tiles then
                spawn_tiles(preset, entry.surface, entry.pos)
                -- entities are spawned one tick later, after the tiles exist
                table.insert(follow_ups, {
                    tick = tick + 1,
                    preset = entry.preset,
                    pos = entry.pos,
                    surface = entry.surface,
                    tiles = false,
                })
            else
                spawn_entities(preset, entry.surface, entry.pos)
                if preset.rarity == "legendary" then
                    storage.ei.legendary_spawns = storage.ei.legendary_spawns or {}
                    storage.ei.legendary_spawns[entry.preset] = true
                end
            end
        end
    end

    for _, entry in ipairs(follow_ups) do
        table.insert(queue, entry)
    end
end

--DEVELOPER TOOLS (record presets)
------------------------------------------------------------------------------------------------------

---Serialises a table into Lua source (used to write recorded presets to script-output).
function model.dump(o)
    if type(o) == "table" then
        local s = "{ "
        for k, v in pairs(o) do
            if type(k) ~= "number" then
                k = '"' .. k .. '"'
            end
            s = s .. "[" .. k .. "] = " .. model.dump(v) .. ","
        end
        return s .. "} "
    elseif type(o) == "string" then
        return '"' .. o .. '"'
    end
    return tostring(o)
end

---/etool and /etool2 give the recording tools. Admin only (they write files on the host).
function model.give_tool(event)
    local player = util.event_player(event)
    if not player or not player.admin then
        return
    end

    if event.command == "etool" then
        player.insert({name = "ei-spawner-tool", count = 1})
    elseif event.command == "etool2" then
        player.insert({name = "ei-tile-tool", count = 1})
    end
end

local function entity_select(event)
    local preset = {}
    for _, entity in pairs(event.entities) do
        table.insert(preset, {
            name = entity.name,
            position = {
                x = entity.position.x - event.area.left_top.x,
                y = entity.position.y - event.area.left_top.y,
            },
            destructible = entity.destructible,
        })
    end
    helpers.write_file("spawner_preset.txt", model.dump(preset), false, event.player_index)
end

local function tile_select(event)
    local preset = {}
    for _, tile in ipairs(event.surface.find_tiles_filtered{area = event.area}) do
        if tile.name ~= "lab-dark-1" and tile.name ~= "lab-dark-2" then
            table.insert(preset, {
                name = tile.name,
                position = {
                    x = tile.position.x - event.area.left_top.x,
                    y = tile.position.y - event.area.left_top.y,
                },
            })
        end
    end
    helpers.write_file("tile_preset.txt", model.dump(preset), false, event.player_index)
end

function model.on_player_selected_area(event)
    if event.item == "ei-spawner-tool" then
        entity_select(event)
    elseif event.item == "ei-tile-tool" then
        tile_select(event)
        entity_select(event)
    end
end

--HANDLERS
------------------------------------------------------------------------------------------------------

function model.on_chunk_generated(event)
    if not model.allowed_surfaces[event.surface.name] then
        return
    end
    -- queue for the next tick, the chunk has to be fully generated first
    model.que_preset(get_spawn_position(event.area), event.surface, event.tick + 1)
end

function model.on_destroyed_entity(entity)
    model.count_flowers(entity)
end

return model
