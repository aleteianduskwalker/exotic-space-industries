--====================================================================================================
-- STORM EMP (3.1.0, design doc §7)
--====================================================================================================
-- "The storm jams the automation": a lightning strike on Gaia that does NOT hit a lightning
-- attractor temporarily disables machines, inserters and combinators around the impact.
-- The circuit network values are NOT changed (the API can not write into a wire network) - the
-- affected devices simply stop reacting for a while (entity.active = false).
--
-- Flow:
--   data-final-fixes.lua adds {type = "script", effect_id = "ei-storm-emp"} to every lightning
--   -> on_script_trigger_effect -> model.on_strike(event)
--   -> on_nth_tick(60)          -> model.update() re-activates expired entities
-- Protection: lightning attractors (vanilla rods and the ESI conduit) pull the strikes onto
-- themselves; strikes within balance.storm_emp.attractor_check_radius of an attractor are ignored.
-- Toggle: runtime-global map setting "ei-gaia-storm-emp". Numbers: lib/balance.lua -> storm_emp.
--
-- storage.ei.storm_emp[unit_number] = {entity, until_tick, icon}
-- Coordination with beacon_overload.lua: entities disabled by an overload are never touched here,
-- and an overload that ends during an EMP leaves the re-activation to this module.
--====================================================================================================

local util = require("scripts/control/util")
local ei_balance = require("lib/balance")

local model = {}

local EFFECT_ID = "ei-storm-emp"

---Returns true if the beacon overload currently disables this entity.
local function is_overloaded(unit_number)
    local icons = storage.ei.overload_icons
    return icons ~= nil and icons[unit_number] ~= nil
end

---Short blue flash at the impact (visual feedback why machines stopped).
local function draw_flash(surface, position, radius)
    rendering.draw_light{
        sprite = "utility/light_medium",
        target = position,
        surface = surface,
        scale = radius / 2,
        intensity = 1,
        color = {r = 0.5, g = 0.75, b = 1},
        time_to_live = 30,
    }
end

---Disables one entity for the EMP duration (or extends a running EMP).
local function disable(entity, until_tick)
    local emp = storage.ei.storm_emp
    local record = emp[entity.unit_number]

    if record then
        record.until_tick = math.max(record.until_tick, until_tick)
        return
    end

    -- entities that are already inactive (overload, other scripts) are left alone
    if not entity.active or is_overloaded(entity.unit_number) then
        return
    end

    entity.active = false
    emp[entity.unit_number] = {
        entity = entity,
        until_tick = until_tick,
        icon = rendering.draw_sprite{
            sprite = "utility/electricity_icon_unplugged",
            target = entity,
            surface = entity.surface,
            x_scale = 0.5,
            y_scale = 0.5,
            render_layer = "entity-info-icon",
        },
    }
end

---Handles one lightning strike (on_script_trigger_effect with effect_id "ei-storm-emp").
---@param event EventData.on_script_trigger_effect
function model.on_strike(event)
    if event.effect_id ~= EFFECT_ID then return end
    if not settings.global["ei-gaia-storm-emp"].value then return end

    local surface = game.get_surface(event.surface_index)
    if not surface or not ei_gaia.is_gaia_surface(surface) then return end

    local position = event.target_position or event.source_position
    if not position then return end

    local config = ei_balance.storm_emp

    -- strikes caught by an attractor do no harm ("the more you invest, the less the storm hurts")
    local attracted = surface.count_entities_filtered{
        position = position,
        radius = config.attractor_check_radius,
        type = "lightning-attractor",
        limit = 1,
    }
    if attracted > 0 then return end

    storage.ei.storm_emp = storage.ei.storm_emp or {}
    local until_tick = game.tick + config.duration_ticks

    for _, entity in pairs(surface.find_entities_filtered{position = position, radius = config.radius, type = config.entity_types}) do
        if entity.valid and entity.unit_number and entity.force.name ~= "neutral" then
            disable(entity, until_tick)
        end
    end

    draw_flash(surface, position, config.radius)
end

---Re-activates entities whose EMP expired. Called once per second.
function model.update()
    local emp = storage.ei.storm_emp
    if not emp or next(emp) == nil then return end

    local tick = game.tick
    for unit, record in pairs(emp) do
        -- assigning nil to an existing field during pairs() is allowed in Lua
        if not util.is_valid(record.entity) then
            util.destroy_render(record.icon)
            emp[unit] = nil
        elseif tick >= record.until_tick then
            if not is_overloaded(unit) then
                record.entity.active = true
            end
            util.destroy_render(record.icon)
            emp[unit] = nil
        end
    end
end

---An entity that gets removed while disabled: drop its record and icon.
---@param entity LuaEntity
function model.on_destroyed_entity(entity)
    local emp = storage.ei.storm_emp
    local record = emp and entity.unit_number and emp[entity.unit_number]
    if record then
        util.destroy_render(record.icon)
        emp[entity.unit_number] = nil
    end
end

return model
