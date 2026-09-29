--====================================================================================================
-- BLACK HOLE GENERATOR
--====================================================================================================
-- HOW IT WORKS (all timings are per game tick, the generator is updated every tick)
--
-- stage 0 (dormant):
--     press "initiate startup" -> the generator starts absorbing mass (items in its inventory).
--     1000 mass is needed to advance -> stage 1. No injector pylons needed.
-- stage 1 (collapse):
--     press the button again -> 8 active energy injector pylons are required for 3600 ticks
--     (1 minute) while the black hole grows -> stage 2.
-- stage 2 (running):
--     8 injector pylons must stay active, energy is produced from mass and mass decay and is
--     handed out through energy extractor pylons in range.
-- Losing containment (less than 8 active injectors while running / collapsing) resets to stage 0.
--
-- Injector pylons count as active while their buffer holds more than 10 MJ.
--
-- STATE (storage.ei.black_hole[unit_number]):
--   entity, mass, battery (active injectors), energy (GJ this tick), energy_last, last_tick,
--   energy_out (smoothed GJ per tick), stage (0..2), started (bool), stage_progress,
--   animation / overlay (LuaRenderObject)
--
-- NOTE: previous versions stored the "startup was pressed" state inside stage_progress, which
-- dropped back to 0 as soon as the mass reached 0. Together with the update running only every
-- 10th tick (and the GUI only when tick % 15 == 0) this made the generator and its GUI freeze
-- after saving/loading. The explicit `started` flag and a per-tick update fix both issues.
--====================================================================================================

local util = require("scripts/control/util")

local model = {}

local PYLON_RANGE = 20
local REQUIRED_INJECTORS = 8
local INJECTOR_ACTIVE_ENERGY = 10 * 1000 * 1000 -- J (10 MJ)
local STAGE_1_MASS = 1000
local STAGE_2_TICKS = 3600
local EXTRACTOR_MAX_GJ_PER_TICK = 100 / 60 -- 100 GJ/s per extractor pylon
local GIGA = 1000 * 1000 * 1000
local GUI_UPDATE_INTERVAL = 15

--UTIL
------------------------------------------------------------------------------------------------------

---Returns the inventory a mined black hole would be transferred to (player or robot), or nil.
local function get_transfer_inv(transfer)
    if not transfer then
        return nil
    end
    if type(transfer) == "number" then
        local player = game.get_player(transfer)
        return player and player.get_main_inventory()
    end
    if transfer.valid then
        return transfer.get_inventory(defines.inventory.robot_cargo)
    end
    return nil
end

---Returns false if the miner can not take the black hole and its contents (mining will fail).
function model.transfer_valid(source, transfer)
    local target_inv = get_transfer_inv(transfer)
    if not target_inv then
        return true -- destroyed by damage/script: always unregister
    end

    local source_inv = source.get_inventory(defines.inventory.chest)
    for _, item in pairs(source_inv.get_contents()) do
        if target_inv.get_insertable_count({name = item.name, quality = item.quality}) < item.count then
            return false
        end
    end

    if not target_inv.can_insert({name = source.name, count = 1}) then
        return false
    end

    -- robots do not mine containers that still have contents
    if type(transfer) ~= "number" and not source_inv.is_empty() then
        return false
    end

    return true
end

---Returns the state table of a registered black hole or nil.
---@param unit integer
function model.get(unit)
    local black_holes = storage.ei.black_hole
    return black_holes and black_holes[unit]
end

local function find_pylons(entity, name)
    return entity.surface.find_entities_filtered{
        name = name,
        position = entity.position,
        radius = PYLON_RANGE,
    }
end

---Migrates old state tables (before `started` existed) and fills in missing fields.
local function repair_state(data)
    data.mass = data.mass or 0
    data.battery = data.battery or 0
    data.energy = data.energy or 0
    data.energy_last = data.energy_last or 0
    data.energy_out = data.energy_out or 0
    data.last_tick = data.last_tick or game.tick
    data.stage = data.stage or 0
    data.stage_progress = data.stage_progress or 0
    if data.started == nil then
        data.started = data.stage_progress > 0
    end
end

--UPDATE
------------------------------------------------------------------------------------------------------

---Absorbs the inventory contents into mass (stage 0 only after startup, always afterwards).
local function update_mass(data, entity)
    if data.stage == 0 and not data.started then
        return
    end

    local inv = entity.get_inventory(defines.inventory.chest)
    if not inv or inv.is_empty() then
        return
    end

    for _, item in pairs(inv.get_contents()) do
        data.mass = data.mass + item.count
    end
    inv.clear()
end

---Counts the active energy injector pylons in range.
local function update_battery(data, entity)
    local active = 0
    for _, injector in pairs(find_pylons(entity, "ei-energy-injector-pylon")) do
        if injector.energy > INJECTOR_ACTIVE_ENERGY then
            active = active + 1
        end
    end
    data.battery = active
end

---Mass decays constantly, radiating energy (GJ per tick).
local function make_energy(data)
    local mass = math.max(data.mass, 0)

    local mass_loss = math.max(math.floor(mass * 0.005), 1)
    if mass - mass_loss < 0 then
        mass_loss = 0
    end
    data.mass = mass - mass_loss

    -- remember the previous value twice a second for a smoothed output
    local tick = game.tick
    if tick - data.last_tick > 30 then
        data.energy_last = data.energy
        data.last_tick = tick
    end

    data.energy = (mass * 0.1 + mass_loss * 25) / 100
    data.energy_out = (data.energy + data.energy_last) / 2
end

---Resets the generator after a containment failure.
local function containment_failure(data, entity)
    data.stage = 0
    data.stage_progress = 0
    data.started = false

    rendering.draw_text{
        target = entity,
        text = "WARNING: Black hole containment failure!",
        color = {r = 1, g = 0, b = 0},
        surface = entity.surface,
        scale = 1,
        time_to_live = 120,
    }
    util.force_print(entity, "WARNING: Black hole containment failure at [gps="
        .. entity.position.x .. "," .. entity.position.y .. "," .. entity.surface.name .. "]!")
end

---Checks containment: collapsing (stage 1 started) and running (stage 2) need 8 injectors.
local function check_battery(data, entity)
    local needs_containment = (data.stage == 1 and data.started) or data.stage == 2
    if needs_containment and data.battery < REQUIRED_INJECTORS then
        containment_failure(data, entity)
    end
end

---Advances the stage machine.
local function update_stage(data)
    if data.stage == 0 then
        if not data.started then
            return
        end
        if data.mass >= STAGE_1_MASS then
            data.stage = 1
            data.started = false
            data.stage_progress = 0
        else
            -- percent of the required mass, shown in the GUI
            data.stage_progress = data.mass / STAGE_1_MASS * 100
        end
    elseif data.stage == 1 then
        if not data.started then
            return
        end
        data.stage_progress = data.stage_progress + 1
        if data.stage_progress >= STAGE_2_TICKS then
            data.stage = 2
            data.started = false
            data.stage_progress = 0
        end
    end
end

---Draws the growing (stage 1) or glowing (stage 2) overlay.
local function make_stage_picture(data, entity)
    if data.overlay and not data.overlay.valid then
        data.overlay = nil
    end

    if data.stage == 0 then
        util.destroy_render(data.overlay)
        data.overlay = nil
        return
    end

    if data.stage == 1 then
        -- 36 frames over 3600 ticks -> a new frame every 100 ticks
        local frame = math.min(math.floor(data.stage_progress / 100), 35)
        if not data.overlay then
            data.overlay = rendering.draw_animation{
                animation = "ei-black-hole_growing",
                target = entity,
                surface = entity.surface,
                render_layer = "object",
                animation_speed = 0,
                animation_offset = frame,
            }
        else
            data.overlay.animation = "ei-black-hole_growing"
            data.overlay.animation_speed = 0
            data.overlay.animation_offset = frame
        end
        return
    end

    -- stage 2
    if not data.overlay then
        data.overlay = rendering.draw_animation{
            animation = "ei-black-hole_glowing",
            target = entity,
            surface = entity.surface,
            render_layer = "object",
            animation_speed = 0.3,
        }
    elseif data.overlay.animation ~= "ei-black-hole_glowing" then
        data.overlay.animation = "ei-black-hole_glowing"
        data.overlay.animation_speed = 0.3
    end
end

---Hands out the produced energy through the extractor pylons in range.
local function apply_output(data, entity)
    local power_out = data.energy_out -- GJ this tick

    for _, extractor in pairs(find_pylons(entity, "ei-energy-extractor-pylon")) do
        if data.stage ~= 2 then
            extractor.energy = 0
        elseif power_out > EXTRACTOR_MAX_GJ_PER_TICK then
            extractor.energy = extractor.energy + EXTRACTOR_MAX_GJ_PER_TICK * GIGA
            power_out = power_out - EXTRACTOR_MAX_GJ_PER_TICK
        else
            extractor.energy = extractor.energy + power_out * GIGA
            power_out = 0
        end
    end
end

---Full per-tick update of a single black hole.
local function update_black_hole(unit, data)
    local entity = data.entity
    if not (entity and entity.valid) then
        util.destroy_render(data.overlay)
        util.destroy_render(data.animation)
        storage.ei.black_hole[unit] = nil
        return
    end

    update_mass(data, entity)
    update_battery(data, entity)
    make_energy(data)
    check_battery(data, entity)
    update_stage(data)
    make_stage_picture(data, entity)
    apply_output(data, entity)
end

--REGISTRATION
------------------------------------------------------------------------------------------------------

---Registers a newly built black hole. `state` (optional) is copied, used for cloned entities.
function model.register_black_hole(entity, state)
    if entity.name ~= "ei-black-hole" then
        return
    end

    storage.ei.black_hole = storage.ei.black_hole or {}

    local data = {
        entity = entity,
        mass = 0,
        battery = 0,        -- active injector pylons in range
        energy = 0,         -- GJ produced this tick
        energy_last = 0,
        last_tick = game.tick,
        energy_out = 0,     -- smoothed GJ per tick
        stage = 0,
        started = false,
        stage_progress = 0, -- stage 0: percent of required mass, stage 1: ticks
    }

    if state then
        for _, field in pairs({"mass", "stage", "started", "stage_progress"}) do
            if state[field] ~= nil then
                data[field] = state[field]
            end
        end
    end

    data.animation = rendering.draw_animation{
        animation = "ei-black-hole_animation",
        target = entity,
        surface = entity.surface,
        render_layer = "object",
    }

    storage.ei.black_hole[entity.unit_number] = data
end

function model.unregister_black_hole(entity, transfer)
    if entity.name ~= "ei-black-hole" then
        return
    end
    if not model.transfer_valid(entity, transfer) then
        return
    end

    local data = model.get(entity.unit_number)
    if data then
        util.destroy_render(data.overlay)
        util.destroy_render(data.animation)
        storage.ei.black_hole[entity.unit_number] = nil
    end
end

---Save migration: fills in fields introduced by newer versions (called on configuration change).
function model.migrate()
    for _, data in pairs(storage.ei.black_hole or {}) do
        repair_state(data)
    end
end

--HANDLERS
------------------------------------------------------------------------------------------------------

function model.on_built_entity(entity)
    if util.is_valid(entity) then
        model.register_black_hole(entity)
    end
end

function model.on_destroyed_entity(entity, transfer)
    model.unregister_black_hole(entity, transfer)
end

---Runs every tick.
function model.update()
    local black_holes = storage.ei.black_hole
    if not black_holes or next(black_holes) == nil then
        return
    end

    for unit, data in pairs(black_holes) do
        update_black_hole(unit, data)
    end

    if game.tick % GUI_UPDATE_INTERVAL == 0 then
        model.update_player_guis()
    end
end

--GUI
------------------------------------------------------------------------------------------------------

-- Shows: current mass, energy produced, injector/extractor pylons in range, stage + progress.
-- Button: start the next stage.

---Collects everything the GUI displays for one black hole.
function model.get_data(unit)
    local data = model.get(unit)
    if not data or not (data.entity and data.entity.valid) then
        return nil
    end
    repair_state(data)

    local entity = data.entity
    local stage = data.stage
    local injectors = #find_pylons(entity, "ei-energy-injector-pylon")
    local extractors = #find_pylons(entity, "ei-energy-extractor-pylon")

    local gui = {
        mass = data.mass,
        power = stage == 2 and data.energy * 60 or 0, -- GW
        stage = {caption = stage, value = stage / 2},
        injectors = {caption = injectors, value = math.min(injectors / REQUIRED_INJECTORS, 1), max = REQUIRED_INJECTORS},
        extractors = {caption = 0, value = 1, max = 0},
    }

    -- progress relative to the current stage, 0..100
    local progress = 0
    if stage == 0 then
        progress = data.started and math.min(data.stage_progress, 100) or 0
    elseif stage == 1 then
        progress = data.stage_progress / STAGE_2_TICKS * 100
    end
    gui.stage_progress = {caption = progress, value = progress / 100}

    if data.started then
        gui.stage.value = math.min(gui.stage.value + 0.25, 1)
    end

    -- no injectors needed while dormant
    if stage == 0 then
        gui.injectors.value = 1
        gui.injectors.max = 0
    end

    -- each extractor can hand out 100 GW
    if gui.power > 0 then
        gui.extractors.caption = extractors
        gui.extractors.max = math.floor(gui.power / 100 + 0.5)
        gui.extractors.value = math.min(extractors * 100 / gui.power, 1)
    end

    -- control button caption: 1 start stage 0, 2 absorbing, 3 start collapse, 4 collapsing, 5 running
    if stage == 0 then
        gui.control_button = data.started and 2 or 1
    elseif stage == 1 then
        gui.control_button = data.started and 4 or 3
    else
        gui.control_button = 5
    end

    return gui
end

---Returns the black hole the player has opened, or nil.
local function opened_black_hole(player)
    local entity = util.opened_entity(player)
    if entity and entity.name == "ei-black-hole" then
        return entity
    end
    return nil
end

function model.open_gui(player)
    model.close_gui(player)

    local entity = opened_black_hole(player)
    if not entity then
        return
    end

    -- entities placed without a build event (e.g. by other mods) are registered lazily
    if not model.get(entity.unit_number) then
        model.register_black_hole(entity)
    end

    local root = player.gui.relative.add{
        type = "frame",
        name = "ei-black-hole-console",
        anchor = {
            gui = defines.relative_gui_type.container_gui,
            name = "ei-black-hole",
            position = defines.relative_gui_position.right,
        },
        direction = "vertical",
    }

    do -- Titlebar
        local titlebar = root.add{type = "flow", direction = "horizontal"}
        titlebar.add{type = "label", caption = {"exotic-industries.black-hole-gui-title"}, style = "frame_title"}
        titlebar.add{type = "empty-widget", style = "ei_titlebar_nondraggable_spacer", ignored_by_interaction = true}
        titlebar.add{
            type = "sprite-button",
            sprite = "virtual-signal/informatron",
            tooltip = {"exotic-industries.gui-open-informatron"},
            style = "frame_action_button",
            tags = {parent_gui = "ei-black-hole-console", action = "goto-informatron", page = "black_hole"},
        }
    end

    local main_container = root.add{type = "frame", name = "main-container", direction = "vertical", style = "inside_shallow_frame"}

    do -- Status
        main_container.add{type = "frame", style = "ei_subheader_frame"}.add{
            type = "label",
            caption = {"exotic-industries.black-hole-gui-status-title"},
            style = "subheader_caption_label",
        }
        local status_flow = main_container.add{type = "flow", name = "status-flow", direction = "vertical", style = "ei_inner_content_flow"}
        status_flow.add{type = "label", name = "mass", caption = {"exotic-industries.black-hole-gui-status-mass", 0}, tooltip = {"exotic-industries.black-hole-gui-status-mass-tooltip"}}
        status_flow.add{type = "label", name = "power", caption = {"exotic-industries.black-hole-gui-status-power", 0}, tooltip = {"exotic-industries.black-hole-gui-status-power-tooltip"}}
        status_flow.add{type = "progressbar", name = "injectors", caption = {"exotic-industries.black-hole-gui-status-injectors", 0}, style = "ei_status_progressbar_red"}
        status_flow.add{type = "progressbar", name = "extractors", caption = {"exotic-industries.black-hole-gui-status-extractors", 0}, style = "ei_status_progressbar_grey"}
    end

    do -- Control
        main_container.add{type = "frame", style = "ei_subheader_frame_with_top_border"}.add{
            type = "label",
            caption = {"exotic-industries.black-hole-gui-control-title"},
            style = "subheader_caption_label",
        }
        local control_flow = main_container.add{type = "flow", name = "control-flow", direction = "vertical", style = "ei_inner_content_flow"}
        control_flow.add{type = "progressbar", name = "stage", caption = {"exotic-industries.black-hole-gui-control-stage", 0}, style = "ei_status_progressbar"}
        control_flow.add{type = "progressbar", name = "stage-progress", caption = {"exotic-industries.black-hole-gui-control-stage-progress", 0}, style = "ei_status_progressbar_grey"}
        control_flow.add{
            type = "button",
            name = "control-button",
            caption = {"exotic-industries.black-hole-gui-control-button"},
            style = "ei_green_button",
            tags = {action = "control-start", parent_gui = "ei-black-hole-console"},
        }
    end

    -- fill the GUI immediately instead of waiting for the next periodic update
    model.update_gui(player, model.get_data(entity.unit_number))
end

---Periodic GUI refresh for every player that has a black hole console open.
function model.update_player_guis()
    for _, player in pairs(game.connected_players) do
        if player.gui.relative["ei-black-hole-console"] then
            local entity = opened_black_hole(player)
            if entity then
                model.update_gui(player, model.get_data(entity.unit_number))
            else
                model.close_gui(player)
            end
        end
    end
end

local CONTROL_BUTTON_STYLES = {
    [1] = "ei_green_button",
    [2] = "ei_button",
    [3] = "ei_green_button",
    [4] = "ei_button",
    [5] = "ei_button",
}

function model.update_gui(player, data)
    local root = player.gui.relative["ei-black-hole-console"]
    if not root or not data then
        return
    end

    local status = root["main-container"]["status-flow"]
    local control = root["main-container"]["control-flow"]

    status["mass"].caption = {"exotic-industries.black-hole-gui-status-mass", string.format("%.1f", data.mass / 100)}
    status["power"].caption = {"exotic-industries.black-hole-gui-status-power", string.format("%.1f", data.power)}

    local injectors = status["injectors"]
    injectors.caption = {"exotic-industries.black-hole-gui-status-injectors", data.injectors.caption, data.injectors.max}
    injectors.value = data.injectors.value
    injectors.style = data.injectors.value >= 1 and "ei_status_progressbar" or "ei_status_progressbar_red"

    local extractors = status["extractors"]
    extractors.caption = {"exotic-industries.black-hole-gui-status-extractors", data.extractors.caption, data.extractors.max}
    extractors.value = data.extractors.value

    control["stage"].caption = {"exotic-industries.black-hole-gui-control-stage", data.stage.caption}
    control["stage"].value = data.stage.value

    control["stage-progress"].caption = {"exotic-industries.black-hole-gui-control-stage-progress", string.format("%.1f", data.stage_progress.caption)}
    control["stage-progress"].value = data.stage_progress.value

    local button = control["control-button"]
    button.caption = {"exotic-industries.black-hole-gui-control-control-button-" .. data.control_button}
    button.style = CONTROL_BUTTON_STYLES[data.control_button]
end

---"Initiate" button: starts the current stage (no effect while a stage is running).
function model.change_stage(player)
    local entity = opened_black_hole(player)
    if not entity then
        return
    end

    local data = model.get(entity.unit_number)
    if not data then
        return
    end
    repair_state(data)

    if data.stage < 2 and not data.started then
        data.started = true
        if data.stage == 1 then
            data.stage_progress = 0
        end
    end

    model.update_gui(player, model.get_data(entity.unit_number))
end

function model.on_gui_click(event)
    if event.element.tags.action == "control-start" then
        model.change_stage(game.get_player(event.player_index))
    end
end

function model.close_gui(player)
    local root = player.gui.relative["ei-black-hole-console"]
    if root then
        root.destroy()
    end
end

return model
