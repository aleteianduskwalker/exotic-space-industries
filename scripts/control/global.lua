--====================================================================================================
-- STORAGE INITIALISATION
--====================================================================================================
-- Creates and repairs the `storage.ei` table used by all runtime modules.
-- `check_init` is idempotent: it only fills in missing fields, so it is safe to call from
-- on_init and on_configuration_changed (migration of older saves).
--====================================================================================================

local ei_global = {}

---Mapping of the "EM updater queue" startup setting to the numeric mode stored in storage.
---0 = off, 1 = beam, 2 = ring (numbers are faster to compare every update).
local EM_QUEUE_MODES = {
    ["Off"] = 0,
    ["Beam"] = 1,
    ["Ring"] = 2,
}

---Returns the value of a startup setting "ei-<name>" or `default` when it does not exist.
---@param name string setting name without the "ei-" prefix
---@param default any
local function config_or(name, default)
    local setting = settings.startup["ei-" .. name]
    if setting == nil then
        return default
    end
    return setting.value
end

---(Re)reads all startup settings that the runtime scripts cache in storage.
---Startup settings can only change together with on_configuration_changed, so caching is safe.
function ei_global.read_settings()
    local ei = storage.ei

    ei.em_train_que = EM_QUEUE_MODES[config_or("em_updater_que", "Beam")] or 1
    ei.que_width = config_or("em_updater_que_width", 6)
    ei.que_transparency = config_or("em_updater_que_transparency", 80) / 100
    ei.que_timetolive = config_or("em_updater_que_timetolive", 60)

    -- NOTE: previous versions read the non-existing settings "ei-em_train_glow_toggle" and
    -- "ei-em_charger_glow_toggle", so the glow could never be disabled.
    ei.em_train_glow_toggle = config_or("em_train_glow", true)
    ei.em_train_glow_timeToLive = config_or("em_train_glow_timetolive", 60)
    ei.em_charger_glow = config_or("em_charger_glow", true)
    ei.em_charger_glow_timeToLive = config_or("em_charger_glow_timetolive", 60)
end

---Creates a fresh storage table (new game).
function ei_global.init()
    storage.ei = {}
    ei_global.check_init()
    -- 3.2.0 one-time migrations have nothing to grandfather in a new game
    storage.ei.gate_calibration_migrated = true
    storage.ei.alien_console_migrated = true
end

---Fills in every missing storage field. Safe to call any number of times.
function ei_global.check_init()
    storage.ei = storage.ei or {}
    local ei = storage.ei

    ei.tech_scaling = ei.tech_scaling or {}
    ei.tech_scaling.maxCost = ei.tech_scaling.maxCost or 0
    ei.tech_scaling.startPrice = ei.tech_scaling.startPrice or 0
    ei.tech_scaling.techCount = ei.tech_scaling.techCount or 0

    ei.overload_icons = ei.overload_icons or {}
    ei.neutron_collector_animation = ei.neutron_collector_animation or {}
    ei.neutron_sources = ei.neutron_sources or {}
    ei.spawner_queue = ei.spawner_queue or {}
    ei.orbital_combinators = ei.orbital_combinators or {}
    ei.spaced_updates = ei.spaced_updates or 0
    ei.gaia_reforged = ei.gaia_reforged or 1

    ei.alien = ei.alien or {}

    -- 3.1.0: Gaia hub systems
    ei.storm_emp = ei.storm_emp or {}                         -- storm_emp.lua
    ei.void_rift_generators = ei.void_rift_generators or {}   -- gaia.lua

    -- 3.2.0: drone ports and their tasks (drone_port.lua)
    ei.drones = ei.drones or {}
    ei.drones.ports = ei.drones.ports or {}
    ei.drones.tasks = ei.drones.tasks or {}
    ei.drones.next_id = ei.drones.next_id or 1
    ei.drones.pending = ei.drones.pending or {}
    ei.drones.gui = ei.drones.gui or {}

    -- 3.2.0: alien terminals (alien_console.lua) and gate calibrations (gate.lua, created on demand)
    ei.alien_consoles = ei.alien_consoles or {}

    -- 3.2.0: radio stations (radio_station.lua)
    ei.radio = ei.radio or {}
    ei.radio.stations = ei.radio.stations or {}
    ei.radio.transmitters = ei.radio.transmitters or {}

    -- master/slave registries (copper/iron beacons) and fluid handling entities
    ei.copper_beacon = ei.copper_beacon or {}
    ei.copper_beacon.master = ei.copper_beacon.master or {}
    ei.copper_beacon.slave = ei.copper_beacon.slave or {}
    ei.fluid_entity = ei.fluid_entity or {}

    -- surfaces that count as "Gaia" for entity swaps; the planet surface is named "Gaia"
    storage.gaia_surfaces = storage.gaia_surfaces or {}
    storage.gaia_surfaces["Gaia"] = true

    ei_global.read_settings()
end

return ei_global
