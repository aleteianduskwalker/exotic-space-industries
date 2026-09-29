local util = require("scripts/control/util")

local model = {}

--====================================================================================================
--MATTER STABILIZER
--====================================================================================================

model.stabilizers = {
    ["ei-alien-stabilizer"] = ei_data.matter_stabilizer.alien_range,
    ["ei-matter-stabilizer"] = ei_data.matter_stabilizer.matter_range
}

model.matter_machines = {
    ["ei-exotic-assembler"] = true
}


--UTIL AND OTHER
------------------------------------------------------------------------------------------------------

function model.check_entity(entity)

    if entity == nil then
        return false
    end

    if not entity.valid then
        return false
    end

    return true

end


function model.find_in_range(machine_type, surface, pos, range)

    local entities = surface.find_entities_filtered{
        position = pos,
        radius = range,
    }

    local matter_machines = {}

    for _, e in pairs(entities) do

        if machine_type == "stabilizer" then
            if model.stabilizers[e.name] then
                table.insert(matter_machines, e)
            end
        end

        if machine_type == "matter_machine" then
            if model.matter_machines[e.name] then
                table.insert(matter_machines, e)
            end
        end

    end

    return matter_machines

end


function model.update_matter_machine(entity)

    if not model.check_entity(entity) then
        return
    end

    -- get stabilizers in range
    local stabilizers = model.find_in_range("stabilizer", entity.surface, entity.position, ei_data.matter_stabilizer.matter_range)

    if #stabilizers > 0 then
        return
    end

    -- blow machine up if crafting progress is over 50 %
    if entity.crafting_progress > 0.5 then
        entity.die()
    end

end


--REGISTRY
------------------------------------------------------------------------------------------------------

function model.register_stabilizer(entity)

    if storage.ei.matter_stabilizers == nil then
        storage.ei.matter_stabilizers = {}
    end

    storage.ei.matter_stabilizers[entity.unit_number] = entity

end


function model.unregister_stabilizer(entity)

    if storage.ei.matter_stabilizers == nil then
        return
    end

    storage.ei.matter_stabilizers[entity.unit_number] = nil

end


function model.register_matter_machine(entity)

    if storage.ei.matter_machines == nil then
        storage.ei.matter_machines = {}
    end

    storage.ei.matter_machines[entity.unit_number] = entity

end


function model.unregister_matter_machine(entity)

    if storage.ei.matter_machines == nil then
        return
    end

    storage.ei.matter_machines[entity.unit_number] = nil

end


--RENDERING RELATED
------------------------------------------------------------------------------------------------------
-- Range circles and connection lines are drawn only for the player that selected a stabilizer or
-- holds one in the cursor. Render objects are stored per player:
--   storage.ei.stabilizer_renders[player_index] = { {render = LuaRenderObject, source = entity,
--                                                    target = entity|nil, type = "range"|"connection"} }

---Returns (and creates) the render list of a player.
local function player_renders(player)
    storage.ei.stabilizer_renders = storage.ei.stabilizer_renders or {}
    local renders = storage.ei.stabilizer_renders
    renders[player.index] = renders[player.index] or {}
    return renders[player.index]
end

---Save migration: previous versions kept one shared render list for all players.
function model.migrate()
    local old = storage.ei.selected_render
    if old then
        for _, data in pairs(old) do
            if type(data) == "table" then
                util.destroy_render(data.render)
            end
        end
        storage.ei.selected_render = nil
    end
end


function model.draw_connection(source, target, player)

    if not model.check_entity(source) or not model.check_entity(target) then
        return
    end

    local render = rendering.draw_line{
        color = {r = 0, g = 1, b = 0},
        width = 0.2,
        from = source.position,
        to = target.position,
        surface = source.surface,
        players = {player},
        draw_on_ground = true,
    }

    table.insert(player_renders(player), {
        render = render,
        source = source,
        target = target,
        type = "connection",
    })

end


function model.draw_stabilizer_range(entity, player)

    if not model.check_entity(entity) then
        return
    end

    local renders = player_renders(player)

    -- only one range circle per stabilizer
    for _, data in pairs(renders) do
        if data.type == "range" and data.source == entity then
            return
        end
    end

    local range = model.stabilizers[entity.name]
    local scale = range / 4 -- 1 <-> 2.5 + 1.5 tiles = 4 tiles

    local render = rendering.draw_sprite{
        sprite = "ei-stabilizer-radius",
        target = entity,
        surface = entity.surface,
        players = {player},
        render_layer = "radius-visualization",
        x_scale = scale,
        y_scale = scale,
    }

    table.insert(renders, {
        render = render,
        source = entity,
        type = "range",
    })

end


---Removes every rendering (of every player) that belongs to a removed stabilizer/matter machine.
function model.remove_rendering(entity)

    local all_renders = storage.ei.stabilizer_renders
    if not all_renders then
        return
    end

    for _, renders in pairs(all_renders) do
        -- iterate backwards so table.remove does not skip entries
        for i = #renders, 1, -1 do
            local data = renders[i]
            if data.source == entity or data.target == entity then
                util.destroy_render(data.render)
                table.remove(renders, i)
            end
        end
    end

end


function model.clear_rendering(player)

    if not player.valid then
        return
    end

    -- dont clear rendering if player has stabilizer or matter machine in cursor
    local cursor = player.cursor_stack
    if cursor and cursor.valid_for_read then
        if model.stabilizers[cursor.name] or model.matter_machines[cursor.name] then
            return
        end
    end

    local renders = player_renders(player)
    for _, data in pairs(renders) do
        util.destroy_render(data.render)
    end

    storage.ei.stabilizer_renders[player.index] = nil

end


---Drops all renderings of a player (player removed from the game).
function model.clear_player(player_index)
    local renders = storage.ei.stabilizer_renders and storage.ei.stabilizer_renders[player_index]
    if renders then
        for _, data in pairs(renders) do
            util.destroy_render(data.render)
        end
        storage.ei.stabilizer_renders[player_index] = nil
    end
end


function model.stabilizer_selected(player, entity)

    if not model.check_entity(entity) then
        return
    end

    local range = model.stabilizers[entity.name]
    local matter_machines = model.find_in_range("matter_machine", entity.surface, entity.position, range)

    -- draw lines to all matter machines
    for _, machine in pairs(matter_machines) do
        model.draw_connection(entity, machine, player)
    end

end


function model.stabilizer_on_cursor(player)

    -- find all stabilizers in screen range around the player
    local stabilizers = model.find_in_range("stabilizer", player.surface, player.position, 100)

    for _, stabilizer in pairs(stabilizers) do
        model.draw_stabilizer_range(stabilizer, player)
        model.stabilizer_selected(player, stabilizer)
    end

end


--HANDLERS
------------------------------------------------------------------------------------------------------

function model.on_built_entity(entity)

    if model.stabilizers[entity.name] then
        model.register_stabilizer(entity)
    end

    if model.matter_machines[entity.name] then
        model.register_matter_machine(entity)
    end
    
end


function model.on_destroyed_entity(entity)

    if model.stabilizers[entity.name] then
        model.remove_rendering(entity)

        -- remove stabilizer from storage
        model.unregister_stabilizer(entity)
    end

    if model.matter_machines[entity.name] then
        model.remove_rendering(entity)

        -- remove matter machine from storage
        model.unregister_matter_machine(entity)
    end
    
end


function model.on_selected_entity_changed(event)

    local player = game.get_player(event.player_index)
    if not player then
        return
    end

    model.clear_rendering(player)

    local selected = player.selected
    if selected and model.stabilizers[selected.name] then
        model.stabilizer_selected(player, selected)
    end

end


function model.on_player_cursor_stack_changed(event)

    local player = game.get_player(event.player_index)
    if not player then
        return
    end

    model.clear_rendering(player)

    local cursor = player.cursor_stack
    if cursor and cursor.valid_for_read then
        if model.stabilizers[cursor.name] or model.matter_machines[cursor.name] then
            model.stabilizer_on_cursor(player)
        end
    end

end


---Round-robin: checks one matter machine per call.
---@return boolean did_work
function model.update()

    local machines = storage.ei.matter_machines
    if not machines then
        return false
    end

    local key = util.next_key(machines, storage.ei.stabilizer_break_point)
    storage.ei.stabilizer_break_point = key
    if key == nil then
        return false
    end

    local machine = machines[key]
    if machine and machine.valid then
        model.update_matter_machine(machine)
    else
        machines[key] = nil
    end

    return true

end


return model
