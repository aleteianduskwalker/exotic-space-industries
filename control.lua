--====================================================================================================
-- EXOTIC SPACE INDUSTRIES - CONTROL STAGE ENTRY POINT
--====================================================================================================
-- Event registration and the central update scheduler.
--
-- MULTIPLAYER / DESYNC SAFETY
--   * All mutable state lives in `storage` (saved + synchronised). The global module references
--     below (ei_lib, ei_black_hole, ...) are constants and identical on every peer.
--   * The round-robin scheduler derives its step from `game.tick` instead of a Lua variable,
--     so a client that just joined executes exactly the same updates as the server.
--====================================================================================================

if script.active_mods["gvv"] then require("__gvv__.gvv")() end
require("util")

--====================================================================================================
--MODULES
--====================================================================================================
-- Shared modules are exposed as globals because they reference each other (e.g. fusion reactor ->
-- neutron collector). They only contain functions and constant tables.

ei_lib = require("lib/lib")
ei_data = require("lib/data")
ei_echo_codex = require("lib/echo_codex")
ei_loaders_lib = require("lib/ei_loaders_lib")

local ei_util = require("scripts/control/util")
local ei_tech_scaling = require("scripts/control/tech_scaling")
local ei_global = require("scripts/control/global")
local ei_register = require("scripts/control/register_util")
local ei_powered_beacon = require("scripts/control/powered_beacon")
local ei_beacon_overload = require("scripts/control/beacon_overload")
local ei_spidertron_limiter = require("scripts/control/spidertron_limiter")

ei_victory = require("scripts/control/victory_disabler")
ei_alien_spawner = require("scripts/control/alien_spawner")
ei_informatron = require("scripts/control/informatron")
ei_milestone_preset = require("scripts/control/milestone_preset")
ei_matter_stabilizer = require("scripts/control/matter_stabilizer")
ei_neutron_collector = require("scripts/control/neutron_collector")
ei_fusion_reactor = require("scripts/control/fusion_reactor")
ei_induction_matrix = require("scripts/control/induction_matrix")
ei_black_hole = require("scripts/control/black_hole")
ei_informatron_messager = require("scripts/control/informatron_messager")
ei_gaia = require("scripts/control/gaia")
ei_gate = require("scripts/control/gate")
ei_alien_system = require("scripts/control/alien_system")
ei_debug = require("scripts/control/debug")
ei_compat = require("scripts/control/compat")

ei_fueler = require("scripts/control/fueler/fueler")
ei_fueler_informatron = require("scripts/control/fueler/informatron")

em_trains = require("scripts/control/em-trains/charger")
em_trains_gui = require("scripts/control/em-trains/gui")

orbital_combinator = require("scripts/control/orbital_combinator")

-- startup settings (constant for the whole session and identical on every peer)
ei_ticksPerFullUpdate = settings.startup["ei_ticks_per_full_update"].value
ei_maxEntityUpdates = settings.startup["ei-max_updates_per_tick"].value

-- remote interfaces and commands have to be registered in the main chunk (every load)
ei_victory.add_interface()

commands.add_command("esi-gaia-reborn", "Checks the Gaia surface and regenerates it if its resources are missing (admin only).", function(command)
    ei_echo_codex.gaia_reborn(command)
end)

--====================================================================================================
--UPDATE SCHEDULER
--====================================================================================================
-- Entity updaters are spread over `ei_ticksPerFullUpdate` ticks: every tick exactly one updater
-- runs (chosen by game.tick), and it processes enough entities so that every registered entity is
-- visited once per full cycle (capped by the "max updates per tick" setting).
-- Each updater processes ONE entity per call and returns false when it has nothing to do.

local function count(tbl)
    return tbl and table_size(tbl) or 0
end

local UPDATERS = {
    {
        update = function() return ei_powered_beacon.update() end,
        count = function() return count(storage.ei.copper_beacon and storage.ei.copper_beacon.master) end,
    },
    {
        update = function() return ei_powered_beacon.update_fluid_storages() end,
        count = function() return count(storage.ei.fluid_entity) end,
    },
    {
        update = function() return ei_neutron_collector.update() end,
        count = function() return count(storage.ei.neutron_sources) end,
    },
    {
        update = function() return ei_matter_stabilizer.update() end,
        count = function() return count(storage.ei.matter_machines) end,
    },
    {
        update = function() return orbital_combinator.update() end,
        count = function() return count(storage.ei.orbital_combinators) end,
    },
    {
        update = function() return ei_fueler.updater() end,
        count = function() return count(storage.ei.fueler) end,
    },
    {
        update = function() return ei_gate.update() end,
        count = function() return count(storage.ei.gate and storage.ei.gate.gate) end,
    },
    {
        update = function() return em_trains.train_updater() end,
        count = function() return count(storage.ei_emt and storage.ei_emt.trains) end,
    },
    {
        update = function() return em_trains.charger_updater() end,
        count = function() return count(storage.ei_emt and storage.ei_emt.chargers) end,
    },
}

-- how many times each updater runs per full update cycle
local UPDATER_CALLS_PER_CYCLE = math.max(1, ei_ticksPerFullUpdate / #UPDATERS)

---Runs the round-robin updater that belongs to this tick.
---@param tick integer
local function run_entity_updater(tick)
    local updater = UPDATERS[tick % #UPDATERS + 1]

    local entities = updater.count()
    if entities == 0 then
        return
    end

    local updates = math.ceil(entities / UPDATER_CALLS_PER_CYCLE)
    updates = ei_util.clamp(updates, 1, ei_maxEntityUpdates)

    for _ = 1, updates do
        if not updater.update() then
            break
        end
    end
end

script.on_event(defines.events.on_tick, function(event)
    if not storage.ei then
        return
    end

    run_entity_updater(event.tick)

    -- updates that run every tick (cheap when there is nothing to do)
    em_trains_gui.updater()
    ei_alien_spawner.update()
    ei_induction_matrix.update()
    ei_black_hole.update()
end)

-- once per second (NOTE: only one handler per nth-tick value can be registered)
script.on_nth_tick(60, function()
    if not storage.ei then
        return
    end

    -- EM train buffs are re-read regularly (research can also be granted by scripts/commands)
    em_trains.check_buffs()

    -- Gaia reforge state machine (only active after /esi-gaia-reborn)
    if storage.ei.gaia_reforged == 0 then
        ei_echo_codex.reforge_gaia_surface()
    end
end)

--====================================================================================================
--INIT AND MIGRATION
--====================================================================================================

---Refreshes everything that depends on prototypes or startup settings.
local function refresh_runtime_data()
    ei_global.check_init()
    ei_tech_scaling.init()
    ei_victory.init()
    ei_compat.check_init()
    orbital_combinator.check_init()
    em_trains.check_global()
    em_trains.check_buffs()
    em_trains_gui.mark_dirty()
end

script.on_init(function()
    if remote.interfaces["freeplay"] then
        remote.call("freeplay", "set_disable_crashsite", true)
    end

    ei_global.init()
    refresh_runtime_data()

    if game.planets["Gaia"] and not game.get_surface("Gaia") then
        game.planets["Gaia"].create_surface()
    end
end)

script.on_configuration_changed(function(event)
    refresh_runtime_data()
    ei_tech_scaling.on_research_finished()

    -- stop any Gaia reforge that was running while the game was saved
    storage.ei.gaia_reforged = 1

    local own_changes = event.mod_changes and event.mod_changes["exotic-space-industries"]
    if own_changes then
        -- migrations of older saves (all of them are idempotent)
        ei_black_hole.migrate()
        ei_matter_stabilizer.migrate()
        ei_fueler.migrate()
        em_trains.migrate()

        -- rebuild registries that older versions could leave with duplicates/stale entries
        em_trains.reinitialize_chargers()
        em_trains.reinitialize_trains()
        em_trains.update_rail_counts()

        ei_lib.crystal_echo("ESI: CONFIGURATION CHANGED", "default-bold")
    end
end)

--====================================================================================================
--ENTITY HANDLERS
--====================================================================================================

---Every module registration for a newly built entity.
---@param entity LuaEntity
---@param event table the original build event
local function on_built_entity(entity, event)
    if not ei_util.is_valid(entity) then
        return
    end

    if ei_powered_beacon.counts_for_fluid_handling(entity) then
        ei_register.register_fluid_entity(entity)
    end

    -- copper and iron beacons: master + hidden powered slave
    if entity.name == "ei-copper-beacon" or entity.name == "ei-iron-beacon" then
        local master_unit = ei_register.register_master_entity("copper_beacon", entity)
        local slave = ei_register.make_slave("copper_beacon", master_unit, entity.name .. "_slave", {x = 0, y = 0})
        ei_register.link_slave("copper_beacon", master_unit, slave, "slave_assembler")
        ei_register.init_beacon("copper_beacon", master_unit)
        ei_register.add_spaced_update()
    end

    ei_beacon_overload.on_built_entity(entity)
    ei_neutron_collector.on_built_entity(entity)
    ei_fusion_reactor.on_built_entity(entity)
    ei_matter_stabilizer.on_built_entity(entity)
    ei_induction_matrix.on_built_entity(entity)
    ei_black_hole.on_built_entity(entity)
    ei_gate.on_built_entity(entity)
    ei_fueler.on_built_entity(entity)
    em_trains.on_built_entity(entity)
    orbital_combinator.add(entity)

    -- loaders only snap to belts/containers when built by hand (not from blueprints)
    if event.name == defines.events.on_built_entity then
        ei_loaders_lib.on_built_entity(entity)
    end

    -- last: may destroy the entity (build restrictions) or swap it for its Gaia variant
    if entity.valid then
        ei_gaia.on_built_entity(entity)
    end
end

script.on_event({
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity,
    defines.events.on_space_platform_built_entity,
    defines.events.script_raised_built,
    defines.events.script_raised_revive,
}, function(event)
    on_built_entity(event.entity, event)
end)

---Entities cloned by other mods (e.g. Warp Drive Machine moving a ship).
---Only simple registries are copied; compound entities are not supported.
script.on_event(defines.events.on_entity_cloned, function(event)
    local source = event.source
    local destination = event.destination
    if not ei_util.is_valid(destination) then
        return
    end

    local name = destination.name
    if name == "ei_fueler" then
        ei_fueler.on_entity_cloned(source, destination)
    elseif name == "ei-black-hole" then
        ei_black_hole.register_black_hole(destination, source.valid and ei_black_hole.get(source.unit_number) or nil)
    else
        if ei_powered_beacon.counts_for_fluid_handling(destination) then
            ei_register.register_fluid_entity(destination)
        end
        ei_neutron_collector.on_built_entity(destination)
        ei_matter_stabilizer.on_built_entity(destination)
        em_trains.on_built_entity(destination)
        orbital_combinator.add(destination)
    end
end)

---Every module cleanup for an entity that is about to be removed.
---All these events fire BEFORE the entity is actually removed.
local function on_destroyed_entity(event)
    local entity = event.entity
    if not ei_util.is_valid(entity) then
        return
    end

    -- robot / player index: needed to check whether mining can succeed (full inventory)
    local transfer = event.robot or event.player_index

    if ei_powered_beacon.counts_for_fluid_handling(entity) then
        ei_register.deregister_fluid_entity(entity)
    end

    if entity.name == "ei-copper-beacon" or entity.name == "ei-iron-beacon" then
        local master = storage.ei.copper_beacon.master[entity.unit_number]
        if master then
            ei_register.unregister_slave_entity("copper_beacon", master.slaves.slave_assembler, entity, true)
            ei_register.unregister_master_entity("copper_beacon", entity.unit_number)
            ei_register.subtract_spaced_update()
        end
    end

    ei_beacon_overload.on_destroyed_entity(entity)
    ei_neutron_collector.on_destroyed_entity(entity)
    ei_alien_spawner.on_destroyed_entity(entity)
    ei_matter_stabilizer.on_destroyed_entity(entity)
    ei_induction_matrix.on_destroyed_entity(entity)
    ei_black_hole.on_destroyed_entity(entity, transfer)
    ei_gate.on_destroyed_entity(entity, transfer)
    ei_fueler.on_destroyed_entity(entity, transfer)
    em_trains.on_destroyed_entity(entity)
    orbital_combinator.rem(entity)
    ei_gaia.on_destroyed_entity(entity)
end

script.on_event({
    defines.events.on_entity_died,
    defines.events.on_pre_player_mined_item,
    defines.events.on_robot_pre_mined,
    defines.events.on_space_platform_pre_mined,
    defines.events.script_raised_destroy,
}, on_destroyed_entity)

script.on_event({
    defines.events.on_player_built_tile,
    defines.events.on_robot_built_tile,
}, function(event)
    ei_induction_matrix.on_built_tile(event)
end)

script.on_event({
    defines.events.on_player_mined_tile,
    defines.events.on_robot_mined_tile,
}, function(event)
    ei_induction_matrix.on_destroyed_tile(event)
end)

--====================================================================================================
--OTHER GAME EVENTS
--====================================================================================================

script.on_event(defines.events.on_console_command, function(event)
    ei_alien_spawner.give_tool(event)
    ei_gaia.spawn_command(event)
    ei_debug.teleport_to(event)
end)

script.on_event(defines.events.on_player_selected_area, function(event)
    ei_alien_spawner.on_player_selected_area(event)
    ei_alien_system.on_player_selected_area(event)
end)

script.on_event(defines.events.on_selected_entity_changed, function(event)
    ei_matter_stabilizer.on_selected_entity_changed(event)
end)

script.on_event(defines.events.on_player_cursor_stack_changed, function(event)
    ei_matter_stabilizer.on_player_cursor_stack_changed(event)
end)

script.on_event(defines.events.on_entity_logistic_slot_changed, function(event)
    ei_spidertron_limiter.on_entity_logistic_slot_changed(event)
end)

script.on_event(defines.events.on_research_finished, function(event)
    ei_tech_scaling.on_research_finished()
    ei_informatron_messager.on_research_finished(event)
    em_trains.on_research_finished(event)
end)

script.on_event(defines.events.on_chunk_generated, function(event)
    ei_alien_spawner.on_chunk_generated(event)
end)

script.on_event(defines.events.on_script_trigger_effect, function(event)
    if event.effect_id == "ei-gate-remote" then
        ei_gate.used_remote(event)
    end
end)

-- respawned characters start empty (no free pistol + ammo from freeplay)
script.on_event(defines.events.on_player_respawned, function(event)
    local player = game.get_player(event.player_index)
    if player and player.character then
        player.character.clear_items_inside()
    end
end)

script.on_event(defines.events.on_player_created, function()
    em_trains_gui.mark_dirty() -- adds the EM trains mod GUI button for the new player
end)

-- a removed player can not return from a gate exit selection: give the character back its flags
script.on_event(defines.events.on_pre_player_removed, function(event)
    ei_gate.finish_remote(event.player_index, true)
    ei_matter_stabilizer.clear_player(event.player_index)
end)

script.on_event({
    defines.events.on_player_joined_game,
    defines.events.on_cutscene_cancelled,
    defines.events.on_cutscene_finished,
}, function(event)
    -- a player that left while selecting a gate exit returns to his character now
    if event.name == defines.events.on_player_joined_game then
        ei_gate.finish_remote(event.player_index)
    end

    local player = game.get_player(event.player_index)
    if player and player.valid and player.character then
        -- greeting only for the arriving player
        ei_lib.crystal_echo("INITIALIZING SYSTEM CORE: EXOTIC SPACE INDUSTRIES", "default-bold", player)
        ei_lib.crystal_echo("Fragments of GAIA lament ripple across space-time...", "default-bold", player)
    end
end)

--====================================================================================================
--GUI EVENTS
--====================================================================================================

script.on_event(defines.events.on_gui_opened, function(event)
    local name = event.entity and event.entity.name
    if not name then
        return
    end

    local player = game.get_player(event.player_index)

    if name == "ei-fusion-reactor" then
        ei_fusion_reactor.open_gui(player)
    elseif ei_induction_matrix.core[name] then
        ei_induction_matrix.open_gui(player)
    elseif name == "ei-black-hole" then
        ei_black_hole.open_gui(player)
    elseif name == "ei-gate-container" then
        ei_gate.open_gui(player)
    elseif name == "ei_fueler" then
        ei_fueler.open_gui(player)
    end
end)

script.on_event(defines.events.on_gui_closed, function(event)
    local name = event.entity and event.entity.name
    local element_name = event.element and event.element.valid and event.element.name
    local player = game.get_player(event.player_index)

    if name == "ei-fusion-reactor" then
        ei_fusion_reactor.close_gui(player)
    elseif element_name == "ei-induction-matrix-console" then
        ei_induction_matrix.close_gui(player)
    elseif name == "ei-black-hole" then
        ei_black_hole.close_gui(player)
    elseif name == "ei-gate-container" then
        ei_gate.close_gui(player)
    elseif name == "ei_fueler" then
        ei_fueler.close_gui(player)
    end
end)

-- parent_gui tag -> click handler
local CLICK_HANDLERS = {
    ["ei-fusion-reactor-console"] = function(event) ei_fusion_reactor.on_gui_click(event) end,
    ["ei-induction-matrix-console"] = function(event) ei_induction_matrix.on_gui_click(event) end,
    ["ei-black-hole-console"] = function(event) ei_black_hole.on_gui_click(event) end,
    ["ei-gate-console"] = function(event) ei_gate.on_gui_click(event) end,
    ["ei-alien-gui"] = function(event) ei_alien_system.on_gui_click(event) end,
    ["ei_fueler-console"] = function(event) ei_fueler.on_gui_click(event) end,
    ["mod_gui"] = function(event) em_trains_gui.on_gui_click(event) end,
    ["em_trains_mod-gui"] = function(event) em_trains_gui.on_gui_click(event) end,
    ["ei_mod-gui"] = function(event) em_trains_gui.on_gui_click(event) end,
}

script.on_event(defines.events.on_gui_click, function(event)
    local element = event.element
    if not (element and element.valid) then
        return
    end

    local tags = element.tags
    if not tags.parent_gui then
        return
    end

    -- "open informatron page" buttons exist in several consoles
    if tags.action == "goto-informatron" then
        if remote.interfaces["informatron"] then
            remote.call("informatron", "informatron_open_to_page", {
                player_index = event.player_index,
                interface = tags.interface or "exotic-industries-informatron",
                page_name = tags.page,
            })
        end
        return
    end

    local handler = CLICK_HANDLERS[tags.parent_gui]
    if handler then
        handler(event)
    end
end)

script.on_event(defines.events.on_gui_value_changed, function(event)
    if event.element.tags.parent_gui == "ei-fusion-reactor-console" then
        ei_fusion_reactor.on_gui_value_changed(event)
    end
end)

script.on_event(defines.events.on_gui_selection_state_changed, function(event)
    if event.element.tags.parent_gui == "ei-gate-console" then
        ei_gate.on_gui_selection_state_changed(event)
    end
end)
