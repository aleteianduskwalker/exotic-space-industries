--====================================================================================================
-- EM TRAINS: CHARGERS
--====================================================================================================
-- EM locomotives have no fuel of their own. Chargers in range "charge" them with a hidden fuel
-- item whose acceleration / top speed bonus depends on the researched upgrade levels.
--
-- * A charger has a range (storage.ei_emt.buffs.charger_range) and an energy consumption that
--   grows with the number of rails in range (250 kW per rail + 10 MW idle).
-- * Charger efficiency research (ei_eff_1..5) lowers the consumption and the charge cost.
-- * Acceleration / speed research (ei_acc_N, ei_spd_N, N <= 20) selects the fuel item
--   "ei_emt-fuel_<acc>_<speed>".
--
-- storage.ei_emt:
--   chargers[unit]  = {entity, rail_count, surface}
--   trains[unit]    = {entity, surface}
--   charger_cursor / train_cursor = round-robin cursors (unit numbers)
--   buffs = {charger_range, eff_level, charger_efficiency (fraction 0..1), acc_level, speed_level}
--   gui   = {dirty = bool}                (mod GUI refresh flag, see gui.lua)
--   range_highlight[player_index] = {LuaRenderObject, ...}
--
-- NOTE: previous versions stored the efficiency *level* (1..5) in charger_efficiency, which made
-- the (1 - efficiency) factor negative: chargers produced energy instead of consuming it.
--====================================================================================================

local util = require("scripts/control/util")

local model = {}

model.trains = {
    ["ei_em-locomotive"] = true,
}

-- research name prefix -> buff name
model.techs = {
    ["ei_eff"] = "eff",
    ["ei_acc"] = "acc",
    ["ei_spd"] = "spd",
}

-- charger efficiency per research level (fraction of energy saved); level 0 = base value
model.effBuffMultipliers = {
    [0] = 0.1,
    [1] = 0.25,
    [2] = 0.4,
    [3] = 0.55,
    [4] = 0.7,
    [5] = 0.9,
}

local MAX_BUFF_LEVEL = 20          -- fuel items exist for acc/speed levels 0..20
local RAIL_POWER = 250 * 1000      -- W per rail in range
local IDLE_POWER = 10 * 1000 * 1000 -- W
local CHARGE_ENERGY = 100 * 1000 * 1000 -- J for a full charge at level 0

-- all rail entity types (2.0 + legacy)
local RAIL_TYPES = {
    "straight-rail", "half-diagonal-rail", "curved-rail-a", "curved-rail-b",
    "elevated-straight-rail", "elevated-half-diagonal-rail", "elevated-curved-rail-a", "elevated-curved-rail-b",
    "legacy-straight-rail", "legacy-curved-rail", "rail-ramp",
}
local RAIL_TYPE_SET = {}
for _, rail_type in pairs(RAIL_TYPES) do
    RAIL_TYPE_SET[rail_type] = true
end

-- duration of the charging beam (one updater cycle)
local BEAM_DURATION = math.max(1, math.floor(settings.startup["ei_ticks_per_full_update"].value / 9))

--STORAGE
------------------------------------------------------------------------------------------------------

function model.check_global()
    storage.ei_emt = storage.ei_emt or {}
    local emt = storage.ei_emt

    emt.chargers = emt.chargers or {}
    emt.trains = emt.trains or {}
    emt.gui = emt.gui or {}
    emt.range_highlight = emt.range_highlight or {}

    emt.buffs = emt.buffs or {}
    local buffs = emt.buffs
    buffs.charger_range = buffs.charger_range or 96
    buffs.eff_level = buffs.eff_level or 0
    buffs.acc_level = buffs.acc_level or 0
    buffs.speed_level = buffs.speed_level or 0
    buffs.charger_efficiency = model.effBuffMultipliers[buffs.eff_level] or model.effBuffMultipliers[0]
end

---Save migration: drops the old register/queue arrays and the broken efficiency value.
function model.migrate()
    model.check_global()
    local emt = storage.ei_emt

    emt.chargers_register = nil
    emt.chargers_que = nil
    emt.trains_register = nil
    emt.trains_que = nil

    -- old versions kept (never filled) highlight tables under numeric keys of the gui table
    for key, _ in pairs(emt.gui) do
        if type(key) == "number" then
            emt.gui[key] = nil
        end
    end

    model.check_buffs()
end

--BUFFS
------------------------------------------------------------------------------------------------------

---Reads the researched upgrade levels of the player force.
function model.check_buffs()
    model.check_global()

    local force = game.forces["player"]
    if not force then
        return
    end

    local technologies = force.technologies
    local levels = {acc = 0, spd = 0, eff = 0}

    for buff, _ in pairs(levels) do
        for tier = MAX_BUFF_LEVEL, 1, -1 do
            local tech = technologies["ei_" .. buff .. "_" .. tier]
            if tech and tech.researched then
                levels[buff] = tier
                break
            end
        end
    end

    local buffs = storage.ei_emt.buffs
    buffs.acc_level = levels.acc
    buffs.speed_level = levels.spd
    buffs.eff_level = math.min(levels.eff, 5)
    buffs.charger_efficiency = model.effBuffMultipliers[buffs.eff_level]
end

---Power a charger needs per tick (J/tick) for the given rail count.
local function charger_power_usage(rail_count)
    local efficiency = storage.ei_emt.buffs.charger_efficiency
    return (rail_count * RAIL_POWER + IDLE_POWER) * (1 - efficiency) / 60
end

--RENDERING
------------------------------------------------------------------------------------------------------

local STATUS_COLORS = {
    idle = {r = 0.3, g = 0.3, b = 0.3},
    working = {r = 0.0, g = 0.8, b = 0.4},
    error = {r = 1.0, g = 0.1, b = 0.1},
    warning = {r = 1.0, g = 0.5, b = 0.0},
    offline = {r = 0.9, g = 0.2, b = 0.2},
    default = {r = 0.3, g = 0.5, b = 0.9},
    buff = {r = 0.6, g = 0.1, b = 0.9},
}

---Status ring around a charger/train ("Ring" updater visualisation, or forced by `override`).
function model.render_status_rings(entity, status, width, time_until_fade, override)
    if not util.is_valid(entity) then
        return
    end
    if not override and storage.ei.em_train_que ~= 2 then
        return
    end

    local base = STATUS_COLORS[status] or STATUS_COLORS.default
    local color = {r = base.r, g = base.g, b = base.b, a = storage.ei.que_transparency}

    rendering.draw_circle{
        color = color,
        radius = math.min(storage.ei.que_width, width or 1),
        width = 1.5,
        filled = false,
        target = entity,
        surface = entity.surface,
        time_to_live = math.ceil((storage.ei.que_timetolive or time_until_fade or 10) * 2),
        draw_on_ground = false,
    }
end

---Charging beam ("Beam" updater visualisation).
function model.cast_beam(charger, target)
    if storage.ei.em_train_que ~= 1 or not util.is_valid(charger) then
        return
    end
    charger.surface.create_entity({
        name = "ei_charger-beam",
        position = charger.position,
        source_offset = {0, -1},
        source = charger,
        target = target,
        duration = BEAM_DURATION,
        force = charger.force,
    })
end

local GLOW_COLORS = {
    {r = 0, g = 0.4, b = 1.0},
    {r = 0.4, g = 0.2, b = 1.0},
    {r = 0.2, g = 0.2, b = 1.0},
    {r = 0.4, g = 0.1, b = 0.8},
}

---Glow on a charged train and all of its carriages.
function model.draw_train_glow(train)
    if not util.is_valid(train) or not storage.ei.em_train_glow_toggle then
        return
    end

    local color = GLOW_COLORS[math.random(1, #GLOW_COLORS)]
    local scale = math.random(1, 4)
    local intensity = 0.4 + math.random() * 0.37

    local targets = {train}
    if train.train then
        targets = train.train.carriages
    end

    for _, car in pairs(targets) do
        if car.valid then
            rendering.draw_light{
                sprite = "emt_train_glow",
                scale = scale,
                intensity = intensity,
                color = color,
                target = car,
                surface = car.surface,
                time_to_live = storage.ei.em_train_glow_timeToLive,
                blend_mode = "multiplicative",
                apply_runtime_tint = true,
                draw_as_glow = true,
            }
        end
    end
end

---Glow on a charger that just delivered a charge.
function model.draw_charger_glow(charger)
    if not util.is_valid(charger) or not storage.ei.em_charger_glow then
        return
    end

    local ttl = storage.ei.em_charger_glow_timeToLive
    local lights = {
        {scale = 2, intensity = 0.65, color = GLOW_COLORS[1]},
        {scale = 2, intensity = 0.25, color = GLOW_COLORS[math.random(1, #GLOW_COLORS)]},
        {scale = 14, intensity = 0.2, color = GLOW_COLORS[math.random(1, #GLOW_COLORS)]},
    }

    for _, light in pairs(lights) do
        rendering.draw_light{
            sprite = "emt_charger_glow",
            scale = light.scale,
            intensity = light.intensity,
            color = light.color,
            target = charger,
            surface = charger.surface,
            time_to_live = ttl,
            blend_mode = "multiplicative",
            apply_runtime_tint = true,
            draw_as_glow = true,
        }
    end
end

---Range circle of a charger. Temporary for everybody, or permanent for the given players.
---@return LuaRenderObject
function model.animate_range(charger, players)
    local radius = storage.ei_emt.buffs.charger_range
    model.render_status_rings(charger, "default", radius, 10)
    return rendering.draw_sprite{
        sprite = "ei_emt-radius_big",
        x_scale = radius / 16,
        y_scale = radius / 16,
        target = charger,
        surface = charger.surface,
        draw_on_ground = true,
        players = players,
        time_to_live = (not players) and 60 or nil,
    }
end

--CHARGING
------------------------------------------------------------------------------------------------------

---Takes the energy for (part of) a charge from the charger.
---@return number fraction 0..1 of a full charge that was paid for
local function draw_charge(charger, train)
    local energy = charger.energy
    if not energy or energy <= 0 then
        return 0
    end

    local buffs = storage.ei_emt.buffs
    local needed = (1 - buffs.charger_efficiency)
        * (1 + 0.1 * buffs.acc_level)
        * (1 + 0.1 * buffs.speed_level)
        * CHARGE_ENERGY

    -- only pay for the part of the charge that is actually missing
    local burner = train.burner
    local burning = burner and burner.currently_burning
    if burning and burner.remaining_burning_fuel then
        local left = burner.remaining_burning_fuel / burning.name.fuel_value
        needed = needed * (1 - util.clamp(left, 0, 1))
    end

    if needed <= 0 then
        return 1
    end

    if energy >= needed then
        charger.energy = energy - needed
        model.draw_charger_glow(charger)
        return 1
    end

    -- not enough energy: use half of the stored energy for a partial charge
    charger.energy = energy / 2
    return (energy / 2) / needed
end

---Collects charge from chargers in range of the train.
---@return number fraction 0..1
local function find_charge(train)
    local surface = train.surface
    local position = train.position
    local range = storage.ei_emt.buffs.charger_range
    local max_range_sqr = range * range
    local parts = 0

    for _, charger_data in pairs(storage.ei_emt.chargers) do
        local charger = charger_data.entity
        if charger and charger.valid and charger.surface == surface then
            local dx = position.x - charger.position.x
            local dy = position.y - charger.position.y
            if dx * dx + dy * dy <= max_range_sqr then
                parts = parts + draw_charge(charger, train)
                if parts >= 1 then
                    model.cast_beam(charger, train)
                    model.render_status_rings(charger, "working", 8, 10)
                    return 1
                end
            end
        end
    end

    return parts
end

---Refills the train's hidden fuel according to the paid charge.
---@return string status for the status ring
local function set_burner(train, charge)
    local burner = train.burner
    if not burner then
        return "error"
    end

    if charge <= 0 then
        burner.remaining_burning_fuel = 0
        return "offline"
    end

    local buffs = storage.ei_emt.buffs
    local acc = util.clamp(buffs.acc_level, 0, MAX_BUFF_LEVEL)
    local speed = util.clamp(buffs.speed_level, 0, MAX_BUFF_LEVEL)
    local fuel = prototypes.item["ei_emt-fuel_" .. acc .. "_" .. speed]
    if not fuel then
        return "error"
    end

    burner.currently_burning = fuel
    burner.remaining_burning_fuel = fuel.fuel_value * charge
    model.draw_train_glow(train)
    return "working"
end

---Charges one train.
local function update_train(train)
    local status = set_burner(train, find_charge(train))
    model.render_status_rings(train, status, 8, 10)
end

---Rail count, power usage and status ring of one charger.
function model.update_charger(charger)
    if not util.is_valid(charger) then
        return false
    end

    local data = storage.ei_emt.chargers[charger.unit_number]
    if not data then
        return false
    end

    data.rail_count = model.get_rail_count(charger)
    charger.power_usage = charger_power_usage(data.rail_count)

    local has_rails = data.rail_count > 1
    local has_energy = charger.energy > 100000

    local status, radius = "default", 6
    if has_rails and has_energy then
        status, radius = "working", 8
    elseif has_rails then
        status, radius = "offline", 12
    end

    model.render_status_rings(charger, status, radius, 12)
    return true
end

--RAILS
------------------------------------------------------------------------------------------------------

function model.get_rail_count(charger)
    return charger.surface.count_entities_filtered({
        position = charger.position,
        radius = storage.ei_emt.buffs.charger_range,
        type = RAIL_TYPES,
    })
end

---Adjusts rail counts of chargers in range when a rail is built (+1) or removed (-1).
function model.update_charger_from_rail(rail, sign)
    local chargers = rail.surface.find_entities_filtered({
        position = rail.position,
        radius = storage.ei_emt.buffs.charger_range,
        name = "ei_charger",
    })

    for _, charger in ipairs(chargers) do
        local data = storage.ei_emt.chargers[charger.unit_number]
        if data then
            data.rail_count = math.max(0, (data.rail_count or 0) + sign)
            charger.power_usage = charger_power_usage(data.rail_count)
        end
    end
end

function model.update_rail_counts()
    for _, data in pairs(storage.ei_emt.chargers) do
        if util.is_valid(data.entity) then
            data.rail_count = model.get_rail_count(data.entity)
            data.entity.power_usage = charger_power_usage(data.rail_count)
        end
    end
end

--REGISTRATION
------------------------------------------------------------------------------------------------------

function model.register_charger(entity)
    model.check_global()
    local rail_count = model.get_rail_count(entity)
    storage.ei_emt.chargers[entity.unit_number] = {
        entity = entity,
        rail_count = rail_count,
        surface = entity.surface,
    }
    entity.power_usage = charger_power_usage(rail_count)
end

function model.unregister_charger(entity)
    model.check_global()
    if entity.unit_number then
        storage.ei_emt.chargers[entity.unit_number] = nil
    end
end

function model.register_train(entity)
    model.check_global()
    storage.ei_emt.trains[entity.unit_number] = {
        entity = entity,
        surface = entity.surface,
    }
end

function model.unregister_train(entity)
    model.check_global()
    if entity.unit_number then
        storage.ei_emt.trains[entity.unit_number] = nil
    end
end

---Rebuilds the charger registry from the map (configuration change).
function model.reinitialize_chargers()
    model.check_global()
    storage.ei_emt.chargers = {}
    for _, surface in pairs(game.surfaces) do
        for _, entity in pairs(surface.find_entities_filtered{name = "ei_charger"}) do
            model.register_charger(entity)
        end
    end
end

---Rebuilds the train registry from the map (configuration change).
function model.reinitialize_trains()
    model.check_global()
    storage.ei_emt.trains = {}
    for name, _ in pairs(model.trains) do
        for _, surface in pairs(game.surfaces) do
            for _, entity in pairs(surface.find_entities_filtered{name = name}) do
                model.register_train(entity)
            end
        end
    end
end

--UPDATERS (round-robin, one entity per call)
------------------------------------------------------------------------------------------------------

---@return boolean did_work
function model.train_updater()
    model.check_global()
    local trains = storage.ei_emt.trains
    local key = util.next_key(trains, storage.ei_emt.train_cursor)
    storage.ei_emt.train_cursor = key
    if key == nil then
        return false
    end

    local train = trains[key].entity
    if util.is_valid(train) then
        update_train(train)
    else
        trains[key] = nil
    end
    return true
end

---@return boolean did_work
function model.charger_updater()
    model.check_global()
    local chargers = storage.ei_emt.chargers
    local key = util.next_key(chargers, storage.ei_emt.charger_cursor)
    storage.ei_emt.charger_cursor = key
    if key == nil then
        return false
    end

    if not model.update_charger(chargers[key].entity) then
        chargers[key] = nil
    end
    return true
end

--RANGE HIGHLIGHT (mod GUI toggle)
------------------------------------------------------------------------------------------------------

---Toggles permanent range circles of all chargers for one player.
function model.toggle_range_highlight(player)
    model.check_global()
    local highlights = storage.ei_emt.range_highlight

    if highlights[player.index] then
        for _, render in pairs(highlights[player.index]) do
            util.destroy_render(render)
        end
        highlights[player.index] = nil
        return
    end

    local renders = {}
    for _, data in pairs(storage.ei_emt.chargers) do
        if util.is_valid(data.entity) then
            table.insert(renders, model.animate_range(data.entity, {player}))
        end
    end
    highlights[player.index] = renders
end

---Redraws the range highlights of all players that have them enabled (a charger was added).
function model.fix_toggle_range()
    -- collect first: toggling modifies the table that is iterated
    local player_indices = {}
    for player_index, _ in pairs(storage.ei_emt.range_highlight) do
        table.insert(player_indices, player_index)
    end

    for _, player_index in ipairs(player_indices) do
        local player = game.get_player(player_index)
        if player then
            model.toggle_range_highlight(player) -- remove
            model.toggle_range_highlight(player) -- draw again
        else
            storage.ei_emt.range_highlight[player_index] = nil
        end
    end
end

--HANDLERS
------------------------------------------------------------------------------------------------------

function model.on_research_finished(event)
    local name = event.research.name
    local buff = model.techs[string.sub(name, 1, 6)]
    if not buff or not string.match(name, "_%d+$") then
        return
    end

    model.check_buffs()
    model.update_rail_counts() -- applies the new efficiency to the power usage

    -- purple "upgrade" rings on everything affected
    local registry = buff == "eff" and storage.ei_emt.chargers or storage.ei_emt.trains
    for _, data in pairs(registry) do
        model.render_status_rings(data.entity, "buff", 8, 10, true)
    end
end

function model.on_built_entity(entity)
    if not util.is_valid(entity) then
        return
    end

    if entity.name == "ei_charger" then
        model.register_charger(entity)
        model.animate_range(entity, nil)
        model.fix_toggle_range()
        em_trains_gui.mark_dirty()
    elseif RAIL_TYPE_SET[entity.type] then
        model.update_charger_from_rail(entity, 1)
        em_trains_gui.mark_dirty()
    elseif model.trains[entity.name] then
        model.register_train(entity)
        em_trains_gui.mark_dirty()
    end
end

function model.on_destroyed_entity(entity)
    if not util.is_valid(entity) then
        return
    end

    if entity.name == "ei_charger" then
        model.unregister_charger(entity)
        em_trains_gui.mark_dirty()
    elseif RAIL_TYPE_SET[entity.type] then
        model.update_charger_from_rail(entity, -1)
        em_trains_gui.mark_dirty()
    elseif model.trains[entity.name] then
        model.unregister_train(entity)
        em_trains_gui.mark_dirty()
    end
end

return model
