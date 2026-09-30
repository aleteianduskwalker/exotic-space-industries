--====================================================================================================
-- ALIEN TERMINAL (3.2.0)
--====================================================================================================
-- The alien terminal (ei-alien-console, prototypes/alien_structures/alien-console.lua) is the
-- access point of the alien tech tree:
--   * nodes can only be bought while the player's character stands within balance.range of a
--     terminal of the own force (on Gaia when balance.gaia_only); nodes with `anywhere = true`
--     (the terminal node itself) are exempt, see model.check_access
--   * every balance.conversion_interval ticks the resonance packs and resonance data in the
--     terminal inventory are converted into alien knowledge at the payment rates
--     (1 pack = alien_points_per_resonance_pack, resonance_data_per_alien_point data = 1 point);
--     nothing is converted once the tree is complete
--   * the terminal GUI (relative to the container GUI) shows the balance and opens the tree
--     (alien_system.swap_gui)
--   * a repaired broken terminal (Gaia ruin) grants a one-time bonus (balance.repair_bonus)
--
-- storage.ei.alien_consoles[unit_number] = {entity = LuaEntity, render = LuaRenderObject}
--====================================================================================================

local util = require("scripts/control/util")
local ei_balance = require("lib/balance")
local B = ei_balance.alien_console

local model = {}

model.NAME = "ei-alien-console"
model.GUI_NAME = "ei-alien-console-gui"

local PACK = "ei-alien-resonance-pack"
local DATA = "ei-resonance-data"

--STORAGE
------------------------------------------------------------------------------------------------------

function model.check_init()
    storage.ei.alien_consoles = storage.ei.alien_consoles or {}
end

local function consoles()
    model.check_init()
    return storage.ei.alien_consoles
end

---True if a terminal works at its place (Gaia only when balance.gaia_only).
---@param entity LuaEntity
function model.is_working(entity)
    return util.is_valid(entity) and (not B.gaia_only or ei_gaia.is_gaia_surface(entity.surface))
end

---Registers a terminal and draws its working animation (hidden while it does not work).
---@param entity LuaEntity
function model.register(entity)
    local list = consoles()
    if list[entity.unit_number] then return end
    list[entity.unit_number] = {
        entity = entity,
        render = rendering.draw_animation{
            animation = "ei-alien-console-working",
            target = entity,
            surface = entity.surface,
            render_layer = "higher-object-under",
            visible = model.is_working(entity),
        },
    }
end

---Removes a terminal and its animation.
---@param unit integer
function model.unregister(unit)
    local list = consoles()
    local entry = list[unit]
    if not entry then return end
    if entry.render and entry.render.valid then entry.render.destroy() end
    list[unit] = nil
end

--ACCESS
------------------------------------------------------------------------------------------------------

---Nearest working terminal of the player's force around the player's character, or nil.
---The physical position is used, so the remote view can not be used to reach a far terminal.
---@param player LuaPlayer
---@return LuaEntity|nil
function model.find_near(player)
    local surface = player.physical_surface
    if not surface then return nil end
    if B.gaia_only and not ei_gaia.is_gaia_surface(surface) then return nil end

    local found = surface.find_entities_filtered{
        name = model.NAME,
        force = player.force,
        position = player.physical_position,
        radius = B.range,
        limit = 1,
    }
    return found[1]
end

---True if the player may buy the node here; prints why not otherwise.
---@param player LuaPlayer
---@param node table node or button tags (field `anywhere`)
function model.check_access(player, node)
    if node.anywhere or model.find_near(player) then return true end
    player.print({"exotic-industries.alien-console-required", B.range})
    return false
end

--CONVERSION
------------------------------------------------------------------------------------------------------

---Converts the packs and the data of one terminal into knowledge. Returns the added points.
---Data is only taken in whole points (the rest stays in the terminal).
---@param entity LuaEntity
function model.convert(entity)
    local force = entity.force
    if ei_alien_system.is_tree_complete(force) then return 0 end

    local inventory = entity.get_inventory(defines.inventory.chest)
    if not inventory then return 0 end

    local points = 0
    local packs = inventory.get_item_count(PACK)
    if packs > 0 then
        packs = inventory.remove({name = PACK, count = packs})
        points = points + packs * ei_balance.alien_points_per_resonance_pack
    end

    local per_point = ei_balance.resonance_data_per_alien_point
    local data_points = math.floor(inventory.get_item_count(DATA) / per_point)
    if data_points > 0 then
        local removed = inventory.remove({name = DATA, count = data_points * per_point})
        points = points + math.floor(removed / per_point)
    end

    if points > 0 and ei_alien_system.add_alien(force, points) then
        ei_alien_system.show_points(entity.surface, entity.position, force, points)
    end
    return points
end

---Runs every tick: converts the inventories every balance.conversion_interval ticks and drops
---stale registry entries (e.g. terminals destroyed by the Gaia build restriction).
---@param tick integer
function model.update(tick)
    if tick % B.conversion_interval ~= 0 then return end
    local list = storage.ei.alien_consoles
    if not list or next(list) == nil then return end

    for unit, entry in pairs(list) do
        if not util.is_valid(entry.entity) then
            model.unregister(unit)
        elseif model.is_working(entry.entity) then
            model.convert(entry.entity)
        end
    end
end

---A broken terminal was repaired: register it and grant the one-time bonus.
---@param entity LuaEntity the new terminal
---@param force LuaForce repairing force
function model.on_repaired(entity, force)
    model.register(entity)
    if ei_alien_system.add_alien(force, B.repair_bonus) then
        force.print({"exotic-industries.alien-console-repaired", B.repair_bonus})
    end
end

--GUI
------------------------------------------------------------------------------------------------------

function model.close_gui(player)
    local root = player.gui.relative[model.GUI_NAME]
    if root then root.destroy() end
end

---Relative GUI next to the terminal inventory: balance, conversion rates, "open the tree" button.
---@param player LuaPlayer
---@param entity LuaEntity
function model.open_gui(player, entity)
    model.close_gui(player)
    model.register(entity)

    local root = player.gui.relative.add{
        type = "frame", name = model.GUI_NAME, direction = "vertical", caption = {"exotic-industries.alien-console-gui-title"},
        anchor = {gui = defines.relative_gui_type.container_gui, position = defines.relative_gui_position.right, names = {model.NAME}},
    }
    local content = root.add{type = "frame", direction = "vertical", style = "inside_shallow_frame_with_padding"}

    local data = ei_alien_system.get_force_data(player.force)
    content.add{type = "label", caption = {"exotic-industries-informatron.alien-balance", data and data.alien or 0},
        style = "heading_2_label"}
    if not model.is_working(entity) then
        content.add{type = "label", caption = {"exotic-industries.alien-console-gui-not-working"}}
    elseif ei_alien_system.is_tree_complete(player.force) then
        content.add{type = "label", caption = {"exotic-industries.alien-console-gui-complete"}}
    else
        content.add{type = "label", caption = {"exotic-industries.alien-console-gui-conversion",
            ei_balance.alien_points_per_resonance_pack, ei_balance.resonance_data_per_alien_point}}
    end
    content.add{type = "button", caption = {"exotic-industries.alien-console-gui-open-tree"},
        tags = {parent_gui = model.GUI_NAME, action = "open-tree"}}
end

function model.on_gui_click(event)
    if event.element.tags.action == "open-tree" then
        ei_alien_system.swap_gui(game.get_player(event.player_index))
    end
end

--HANDLERS
------------------------------------------------------------------------------------------------------

function model.on_built_entity(entity)
    if entity.name == model.NAME then model.register(entity) end
end

function model.on_destroyed_entity(entity)
    if entity.name == model.NAME and entity.unit_number then model.unregister(entity.unit_number) end
end

---Idempotent migration: registers terminals that exist without a registry entry.
function model.migrate()
    for _, surface in pairs(game.surfaces) do
        for _, entity in pairs(surface.find_entities_filtered{name = model.NAME}) do
            model.register(entity)
        end
    end
end

return model
