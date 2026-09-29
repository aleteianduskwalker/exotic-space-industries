--====================================================================================================
-- BEACON OVERLOAD
--====================================================================================================
-- A machine that is affected by more than MAX_BEACONS beacons gets "overloaded" and stops working.
-- Beacon weights: regular beacon = 1, iron beacon = 2, alien / singularity beacon = 0.
-- The check runs only when a beacon or a machine is built/removed (event driven, no polling).
--====================================================================================================

local util = require("scripts/control/util")

local model = {}

-- machines above this weighted beacon count are overloaded
local MAX_BEACONS = 4

-- machine types that can be overloaded
local OVERLOADABLE_TYPES = {
    ["assembling-machine"] = true,
    ["furnace"] = true,
    ["lab"] = true,
    ["rocket-silo"] = true,
    ["mining-drill"] = true,
}

-- beacons that count differently than 1
local BEACON_WEIGHTS = {
    ["ei-iron-beacon"] = 2,
    ["ei-alien-beacon"] = 0,
    ["kr-singularity-beacon"] = 0,
}

--UTIL
------------------------------------------------------------------------------------------------------

---Returns true if the prototype accepts at least one module effect.
local function allows_effects(entity)
    local allowed = entity.prototype.allowed_effects
    if not allowed then
        return false
    end
    for _, enabled in pairs(allowed) do
        if enabled then
            return true
        end
    end
    return false
end

---Returns true if the entity can be overloaded by beacons.
function model.counts_for_overload(entity)
    if not util.is_valid(entity) then
        return false
    end
    if entity.name == "ei-copper-beacon_slave" then
        return false
    end
    return OVERLOADABLE_TYPES[entity.type] == true and allows_effects(entity)
end

---Returns an area around `entity` enlarged by `range` tiles on each side.
local function area_around(entity, range)
    local box = entity.prototype.collision_box
    local half_size = (box.right_bottom.x - box.left_top.x) / 2
    local pos = entity.position
    return {
        {pos.x - range - half_size, pos.y - range - half_size},
        {pos.x + range + half_size, pos.y + range + half_size},
    }
end

---Counts the weighted number of beacons around a machine.
---@param entity LuaEntity machine
---@param ignored LuaEntity|nil beacon that is being removed right now and must not be counted
---@return number
function model.count_beacons(entity, ignored)
    local beacons = entity.surface.find_entities_filtered{
        area = area_around(entity, ei_data.beacon_range),
        type = "beacon",
    }

    local count = 0
    for _, beacon in pairs(beacons) do
        if beacon ~= ignored then
            count = count + (BEACON_WEIGHTS[beacon.name] or 1)
        end
    end
    return count
end

--OVERLOAD STATE
------------------------------------------------------------------------------------------------------

---Updates the overload state of a single machine.
---@param entity LuaEntity machine
---@param ignored LuaEntity|nil beacon that is being removed
function model.update_overload(entity, ignored)
    if not model.counts_for_overload(entity) then
        return
    end
    if not settings.startup["ei-beacon-overload"].value then
        return
    end

    local overloaded = model.count_beacons(entity, ignored) > MAX_BEACONS
    local was_overloaded = storage.ei.overload_icons[entity.unit_number] ~= nil

    if overloaded and not was_overloaded then
        entity.active = false
        model.add_overload_effect(entity)
        model.add_overload_icon(entity)
        ei_victory.count_value("machines_overloaded", 1)
    elseif not overloaded and was_overloaded then
        -- only re-activate machines that WE deactivated, other scripts may control `active` too
        entity.active = true
        model.remove_overload_icon(entity)
    end
end

---Updates all machines in range of a beacon (after it was built or before it gets removed).
---@param beacon LuaEntity
---@param removing boolean true if the beacon is being removed
function model.update_all_machines_in_range(beacon, removing)
    if not util.is_valid(beacon) then
        return
    end

    local machines = beacon.surface.find_entities_filtered{
        area = area_around(beacon, beacon.prototype.get_supply_area_distance()),
        type = {"assembling-machine", "furnace", "lab", "rocket-silo", "mining-drill"},
    }

    local ignored = removing and beacon or nil
    for _, machine in pairs(machines) do
        model.update_overload(machine, ignored)
    end
end

--RENDERING
------------------------------------------------------------------------------------------------------

function model.add_overload_icon(entity)
    local icons = storage.ei.overload_icons
    if icons[entity.unit_number] then
        return
    end

    icons[entity.unit_number] = rendering.draw_sprite({
        sprite = "ei-overload-icon",
        target = entity,
        x_scale = 0.75,
        y_scale = 0.75,
        surface = entity.surface,
        render_layer = 139,
    })
end

function model.remove_overload_icon(entity)
    local icons = storage.ei.overload_icons
    local unit = entity.unit_number
    if unit and icons[unit] then
        util.destroy_render(icons[unit])
        icons[unit] = nil
    end
end

---Short electric sparks at the 4 corners of the machine plus a floating text.
function model.add_overload_effect(entity)
    local box = entity.prototype.collision_box
    local half_size = (box.right_bottom.x - box.left_top.x) / 2
    local pos = entity.position

    for _, corner in pairs({{-1, -1}, {1, -1}, {-1, 1}, {1, 1}}) do
        rendering.draw_animation({
            animation = "ei-overload-animation",
            target = {pos.x + corner[1] * half_size, pos.y + corner[2] * half_size},
            surface = entity.surface,
            render_layer = 139,
            time_to_live = 30,
        })
    end

    rendering.draw_text{
        target = {pos.x - 1, pos.y - half_size},
        text = "Beacon overload",
        color = {r = 1, g = 0.77, b = 0},
        surface = entity.surface,
        scale = 1,
        time_to_live = 15,
    }
end

--HANDLERS
------------------------------------------------------------------------------------------------------

function model.on_built_entity(entity)
    if entity.type == "beacon" then
        model.update_all_machines_in_range(entity, false)
    elseif model.counts_for_overload(entity) then
        model.update_overload(entity)
    end
end

function model.on_destroyed_entity(entity)
    if entity.type == "beacon" then
        -- the beacon still exists during the destroy events, so it is explicitly ignored
        model.update_all_machines_in_range(entity, true)
    elseif entity.unit_number then
        model.remove_overload_icon(entity)
    end
end

return model
