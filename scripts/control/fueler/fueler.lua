--====================================================================================================
-- FUELER
--====================================================================================================
-- A fueler tower distributes the contents of its inventory to entities in range:
--   * ammo turrets / artillery (always): ammo is inserted into their ammo inventories
--   * the selected vehicle type (locomotive, car, spidertron, character):
--       - vehicle mode:   fuel goes into the fuel inventory, burnt results are taken back
--       - equipment mode: fuel goes into burner equipment in the vehicle's grid
--
-- storage.ei.fueler[unit_number] = {entity = LuaEntity, target_type = string, equipment = bool}
-- storage.ei.fueler_break_point   = unit number of the last updated fueler (round-robin cursor)
-- storage.ei.cooldown[unit_number] = tick until which a target is not refueled again
--
-- NOTE: previous versions keyed fuelers by "surface|x|y" strings and kept an extra array queue
-- iterated with next(), which could crash/desync after entities were removed. `migrate` converts
-- old saves.
--====================================================================================================

local util = require("scripts/control/util")

local model = {}

-- selectable target types (GUI order); "spidertron" is the entity prototype used for the icon
model.target_types = {
    "locomotive",
    "car",
    "spidertron",
    "character",
}

-- selectable target type -> entity type to search for
local TARGET_ENTITY_TYPES = {
    ["locomotive"] = "locomotive",
    ["car"] = "car",
    ["spidertron"] = "spider-vehicle",
    ["character"] = "character",
}

-- turret types that always receive ammo, with their ammo inventory
local AMMO_INVENTORIES = {
    ["ammo-turret"] = defines.inventory.turret_ammo,
    ["artillery-turret"] = defines.inventory.artillery_turret_ammo,
    ["artillery-wagon"] = defines.inventory.artillery_wagon_ammo,
}

local TARGET_COOLDOWN = 60 -- ticks between two refuels of the same target

--UTIL
------------------------------------------------------------------------------------------------------

local function check_global()
    storage.ei.fueler = storage.ei.fueler or {}
    storage.ei.cooldown = storage.ei.cooldown or {}
end

---Returns the inventory a mined fueler is transferred to (player or robot), or nil.
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

---Returns false if the miner can not take the fueler (mining will fail, keep it registered).
function model.transfer_valid(source, transfer)
    local target_inv = get_transfer_inv(transfer)
    if not target_inv then
        return true -- destroyed by damage/script
    end

    if not target_inv.can_insert({name = source.name, count = 1}) then
        return false
    end

    -- robots do not mine containers that still have contents
    local source_inv = source.get_inventory(defines.inventory.chest)
    if type(transfer) ~= "number" and source_inv and not source_inv.is_empty() then
        return false
    end

    return true
end

---Moves as many items as possible from `source_inv` into `target_inv` (quality/spoilage preserved).
---@return boolean moved true if at least one item was moved
local function transfer_items(source_inv, target_inv)
    if not source_inv or not target_inv or source_inv.is_empty() then
        return false
    end

    local moved = false
    for i = 1, #source_inv do
        local stack = source_inv[i]
        if stack.valid_for_read then
            local inserted = target_inv.insert(stack)
            if inserted > 0 then
                moved = true
                if inserted >= stack.count then
                    stack.clear()
                else
                    stack.count = stack.count - inserted
                end
            end
        end
    end
    return moved
end

---Short beam from the fueler to the target as visual feedback.
local function cast_beam(fueler, target)
    fueler.surface.create_entity({
        name = "ei-fuel-beam",
        position = fueler.position,
        source_offset = {0, -1},
        source = fueler,
        target = target,
        duration = 30,
        force = fueler.force,
    })
end

--REFUELING
------------------------------------------------------------------------------------------------------

---Ammo for turrets and artillery.
local function refuel_turret(fueler_inventory, fueler, target)
    local ammo_inventory = target.get_inventory(AMMO_INVENTORIES[target.type])
    if transfer_items(fueler_inventory, ammo_inventory) then
        cast_beam(fueler, target)
    end
end

---Fuel for vehicles, burnt results are taken back.
local function refuel_vehicle(fueler_inventory, fueler, target)
    local moved = transfer_items(fueler_inventory, target.get_fuel_inventory())

    if not fueler_inventory.is_full() then
        moved = transfer_items(target.get_burnt_result_inventory(), fueler_inventory) or moved
    end

    if moved then
        cast_beam(fueler, target)
    end
end

---Fuel for burner equipment inside the target's equipment grid.
local function refuel_equipment(fueler_inventory, fueler, target)
    local grid = target.grid
    if not grid then
        return
    end

    local moved = false
    for _, equipment in pairs(grid.equipment) do
        local burner = equipment.valid and equipment.burner
        if burner then
            moved = transfer_items(fueler_inventory, burner.inventory) or moved
            if burner.burnt_result_inventory and not fueler_inventory.is_full() then
                moved = transfer_items(burner.burnt_result_inventory, fueler_inventory) or moved
            end
        end
    end

    if moved then
        cast_beam(fueler, target)
    end
end

---Refuels everything in range of one fueler.
local function update_fueler(data)
    local fueler = data.entity
    local fueler_inventory = fueler.get_inventory(defines.inventory.chest)
    if not fueler_inventory or fueler_inventory.is_empty() then
        return
    end

    local target_type = TARGET_ENTITY_TYPES[data.target_type or "locomotive"] or "locomotive"
    local cooldown = storage.ei.cooldown
    local tick = game.tick

    local targets = fueler.surface.find_entities_filtered{
        position = fueler.position,
        radius = settings.startup["ei-fueler_range"].value,
        type = {target_type, "ammo-turret", "artillery-turret", "artillery-wagon"},
    }

    for _, target in ipairs(targets) do
        local unit = target.unit_number
        if target.valid and unit and (cooldown[unit] or 0) <= tick then
            if AMMO_INVENTORIES[target.type] then
                refuel_turret(fueler_inventory, fueler, target)
            elseif data.equipment then
                refuel_equipment(fueler_inventory, fueler, target)
            else
                refuel_vehicle(fueler_inventory, fueler, target)
            end
            cooldown[unit] = tick + TARGET_COOLDOWN
        end

        if fueler_inventory.is_empty() then
            break
        end
    end
end

---Removes expired cooldown entries.
local function update_cooldowns()
    local tick = game.tick
    local cooldown = storage.ei.cooldown
    for unit, until_tick in pairs(cooldown) do
        if type(unit) ~= "number" or until_tick < tick then
            cooldown[unit] = nil
        end
    end
end

---Round-robin: updates one fueler per call.
---@return boolean did_work
function model.updater()
    check_global()

    local fuelers = storage.ei.fueler
    local key = util.next_key(fuelers, storage.ei.fueler_break_point)
    storage.ei.fueler_break_point = key
    if key == nil then
        return false
    end

    local data = fuelers[key]
    if data.entity and data.entity.valid then
        update_fueler(data)
    else
        fuelers[key] = nil
    end

    -- the cooldown table only needs cleaning once per full round
    if key == next(fuelers) then
        update_cooldowns()
    end

    return true
end

--REGISTRATION
------------------------------------------------------------------------------------------------------

---Registers a fueler; `settings_source` (optional) is an old entry whose settings are kept.
function model.register_fueler(entity, settings_source)
    check_global()
    storage.ei.fueler[entity.unit_number] = {
        entity = entity,
        target_type = settings_source and settings_source.target_type or model.target_types[1],
        equipment = settings_source and settings_source.equipment or false,
    }
end

function model.unregister_fueler(entity, transfer)
    if not model.transfer_valid(entity, transfer) then
        return
    end
    check_global()
    storage.ei.fueler[entity.unit_number] = nil
end

---Rebuilds the registry from the map, keeping settings of already known fuelers.
---Old saves used "surface|x|y" keys, those settings are carried over as well.
function model.rebuild()
    check_global()
    local old = storage.ei.fueler
    storage.ei.fueler = {}

    for _, surface in pairs(game.surfaces) do
        for _, entity in pairs(surface.find_entities_filtered{name = "ei-fueler"}) do
            local legacy_key = surface.name .. "|" .. entity.position.x .. "|" .. entity.position.y
            model.register_fueler(entity, old[entity.unit_number] or old[legacy_key])
        end
    end

    storage.ei.fueler_queue = nil
    storage.ei.fueler_break_point = nil
    storage.ei.cooldown = {}
end

---Save migration from the old string-keyed registry.
function model.migrate()
    check_global()
    local needs_rebuild = storage.ei.fueler_queue ~= nil
    for key, _ in pairs(storage.ei.fueler) do
        if type(key) ~= "number" then
            needs_rebuild = true
            break
        end
    end
    if needs_rebuild then
        model.rebuild()
    end
end

--HANDLERS
------------------------------------------------------------------------------------------------------

function model.on_built_entity(entity)
    if util.is_valid(entity) and entity.name == "ei-fueler" then
        model.register_fueler(entity)
    end
end

---Cloned fuelers (e.g. Warp Drive Machine moving a ship) keep their settings.
function model.on_entity_cloned(source, destination)
    if destination.name ~= "ei-fueler" then
        return
    end
    check_global()
    model.register_fueler(destination, source.valid and storage.ei.fueler[source.unit_number] or nil)
end

function model.on_destroyed_entity(entity, transfer)
    if util.is_valid(entity) and entity.name == "ei-fueler" then
        model.unregister_fueler(entity, transfer)
    end
end

--GUI
------------------------------------------------------------------------------------------------------

---Returns the registry entry of the fueler the player has opened (registers it lazily).
local function opened_fueler(player)
    local entity = util.opened_entity(player)
    if not entity or entity.name ~= "ei-fueler" then
        return nil
    end
    check_global()
    if not storage.ei.fueler[entity.unit_number] then
        model.register_fueler(entity)
    end
    return storage.ei.fueler[entity.unit_number]
end

function model.open_gui(player)
    model.close_gui(player)

    local root = player.gui.relative.add{
        type = "frame",
        name = "ei-fueler-console",
        anchor = {
            gui = defines.relative_gui_type.container_gui,
            name = "ei-fueler",
            position = defines.relative_gui_position.right,
        },
        direction = "vertical",
    }

    do -- Titlebar
        local titlebar = root.add{type = "flow", direction = "horizontal"}
        titlebar.add{type = "label", caption = {"exotic-industries-fueler.fueler-gui-title"}, style = "frame_title"}
        titlebar.add{type = "empty-widget", style = "ei-titlebar-draggable-spacer", ignored_by_interaction = true}
        titlebar.add{
            type = "sprite-button",
            sprite = "virtual-signal/informatron",
            style = "frame_action_button",
            tags = {
                parent_gui = "ei-fueler-console",
                action = "goto-informatron",
                interface = "exotic-industries-fueler-informatron",
                page = "exotic-industries-fueler-informatron",
            },
        }
    end

    local main_container = root.add{type = "frame", name = "main-container", direction = "vertical", style = "inside_shallow_frame"}

    main_container.add{type = "frame", style = "ei-subheader-frame"}.add{
        type = "label",
        caption = {"exotic-industries-fueler.fueler-gui-control-title"},
        style = "subheader_caption_label",
    }

    local control_flow = main_container.add{type = "flow", name = "control-flow", direction = "vertical", style = "ei-inner-content-flow"}

    control_flow.add{
        type = "label",
        caption = {"exotic-industries-fueler.fueler-gui-control-description"},
        tooltip = {"exotic-industries-fueler.fueler-gui-control-description-tooltip"},
    }

    local button_frame = control_flow.add{type = "frame", name = "target-frame", style = "slot_button_deep_frame"}
    for _, target_name in ipairs(model.target_types) do
        button_frame.add{
            type = "sprite-button",
            sprite = "entity/" .. target_name,
            tooltip = {"entity-name." .. target_name},
            tags = {action = "set-target-type", parent_gui = "ei-fueler-console", target_type = target_name},
            style = "ei-slot-button-radio",
        }
    end
    control_flow.add{type = "empty-widget", style = "ei-vertical-pusher"}

    control_flow.add{
        type = "label",
        caption = {"exotic-industries-fueler.fueler-gui-equipment-description"},
        tooltip = {"exotic-industries-fueler.fueler-gui-equipment-description-tooltip"},
    }

    local equipment_frame = control_flow.add{type = "frame", name = "equipment-frame", style = "slot_button_deep_frame"}
    equipment_frame.add{
        type = "sprite-button",
        sprite = "ei-vehicle",
        tooltip = {"exotic-industries-fueler.vehicle"},
        tags = {action = "set-equipment-type", parent_gui = "ei-fueler-console", equipment_type = false},
        style = "ei-slot-button-radio",
    }
    equipment_frame.add{
        type = "sprite-button",
        sprite = "ei-equipment",
        tooltip = {"exotic-industries-fueler.equipment"},
        tags = {action = "set-equipment-type", parent_gui = "ei-fueler-console", equipment_type = true},
        style = "ei-slot-button-radio",
    }

    control_flow.add{type = "empty-widget", style = "ei-vertical-pusher"}

    model.update_gui(player)
end

---Syncs the radio buttons with the settings of the opened fueler.
function model.update_gui(player)
    local root = player.gui.relative["ei-fueler-console"]
    local data = opened_fueler(player)
    if not root or not data then
        return
    end

    local control = root["main-container"]["control-flow"]

    for _, elem in pairs(control["target-frame"].children) do
        elem.enabled = elem.tags.target_type ~= data.target_type
    end

    for _, elem in pairs(control["equipment-frame"].children) do
        elem.enabled = elem.tags.equipment_type ~= (data.equipment == true)
    end
end

function model.close_gui(player)
    local root = player.gui.relative["ei-fueler-console"]
    if root then
        root.destroy()
    end
end

function model.on_gui_click(event)
    local player = game.get_player(event.player_index)
    local tags = event.element.tags
    local data = opened_fueler(player)
    if not data then
        return
    end

    if tags.action == "set-target-type" then
        data.target_type = tags.target_type
        -- players only carry equipment, there is no fuel inventory
        if tags.target_type == "character" then
            data.equipment = true
        end
        model.update_gui(player)
    elseif tags.action == "set-equipment-type" then
        -- equipment mode is mandatory for characters
        if tags.equipment_type == false and data.target_type == "character" then
            return
        end
        data.equipment = tags.equipment_type == true
        model.update_gui(player)
    end
end

return model
