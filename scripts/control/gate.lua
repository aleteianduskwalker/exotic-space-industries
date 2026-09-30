local util = require("scripts/control/util")

local model = {}
--====================================================================================================
--GATE
--====================================================================================================

-- transport costs in MJ (the gate only transports items; the old drone/player teleport was removed)
-- 50MW spare per portal -> 100 Items/s
model.energy_costs = {
    ["item"] = 1
}

-- default exit surface for a new gate
model.inverse_surface = {
    ["Gaia"] = "nauvis",
    ["nauvis"] = "Gaia"
}

--HUB RULE (3.1.0, design doc §2)
------------------------------------------------------------------------------------------------------
-- Gaia is the mandatory hub of the gate network: every jump goes through Gaia.
--   gate NOT on Gaia -> the exit may only be on a Gaia surface
--   gate on Gaia     -> the exit may be on any OTHER surface (planets, platforms)
-- Allowed: Nauvis <-> Gaia <-> Fulgora, Gaia <-> platform. Not allowed: Nauvis <-> Fulgora.
-- Enforced in the exit dropdown (model.get_data), when an exit is set (update_surface,
-- used_remote), before every transfer (model.gate_state) and for old saves (model.migrate).

---Returns true if a gate on `gate_surface` may use `exit_surface` as exit.
---@param gate_surface LuaSurface
---@param exit_surface LuaSurface|nil
function model.is_allowed_exit(gate_surface, exit_surface)
    if not (exit_surface and exit_surface.valid) then
        return false
    end
    if ei_gaia.is_gaia_surface(gate_surface) then
        return exit_surface.index ~= gate_surface.index
    end
    return ei_gaia.is_gaia_surface(exit_surface)
end

---Names of all surfaces a gate may use as exit (dropdown content).
---@param gate LuaEntity
---@return string[]
function model.allowed_exit_surfaces(gate)
    local names = {}
    for _, surface in pairs(game.surfaces) do
        if model.is_allowed_exit(gate.surface, surface) then
            table.insert(names, surface.name)
        end
    end
    return names
end

---Default exit surface of a new gate: the inverse surface if allowed, else the first allowed one.
---@param gate LuaEntity
---@return string|nil
local function default_exit_surface(gate)
    local inverse = model.inverse_surface[gate.surface.name]
    if inverse and model.is_allowed_exit(gate.surface, game.get_surface(inverse)) then
        return inverse
    end
    return model.allowed_exit_surfaces(gate)[1]
end

---Idempotent migration: exits that break the hub rule are reset to the default exit
---(the gate is switched off, its exit container link is dropped).
function model.migrate()
    local gates = storage.ei.gate and storage.ei.gate.gate
    for _, data in pairs(gates or {}) do
        local gate = data.gate
        if gate and gate.valid and data.exit
            and not model.is_allowed_exit(gate.surface, game.get_surface(data.exit.surface or "")) then
            data.exit = {surface = default_exit_surface(gate), x = 0, y = 0}
            data.exit_container = nil
            data.state = false
            gate.force.print({"exotic-industries.gate-hub-rule-reset", gate.position.x, gate.position.y, gate.surface.name})
        end
    end
end

--DOC
------------------------------------------------------------------------------------------------------

-- placing the gate will place hidden container ontop
-- gui allows selection of exit location
-- item transport is only possible, if exit location is coupled to exit point
-- item transport consumes energy
-- gui allows to set condition for item transport trigger

--UTIL
-----------------------------------------------------------------------------------------------------

function model.entity_check(entity)

    if entity == nil then
        return false
    end

    if not entity.valid then
        return false
    end

    return true
end


function model.check_global_init()

    if not storage.ei.gate then
        storage.ei.gate = {}
    end

    if not storage.ei.gate.gate then
        storage.ei.gate.gate = {}
    end

--    if not storage.ei.gate.gate_break_point then
--        storage.ei.gate.gate_break_point = nil

    if not storage.ei.gate.exit_platform then
        storage.ei.gate.exit_platform = {}
    end

end


function model.get_transfer_inv(transfer)
    -- transfer is either a player index, a robot, or nil
    -- needed to prevent unregistration when the transferer cant mine due to full inv

    if not transfer then
        return nil
    end

    if type(transfer) == "number" then
        -- player index
        local player = game.get_player(transfer)
        return player.get_main_inventory()
    end

    if transfer.valid then
        -- robot
        local robot = transfer
        return robot.get_inventory(defines.inventory.robot_cargo)
    end

    return nil

end


function model.transfer_valid(transfer)

    local target_inv = model.get_transfer_inv(transfer)
    
    if not target_inv then
        -- case for when destroyed by gun f.e. -> need to unregister
        return true
    end

    -- check if target has space for gate item
    if target_inv.can_insert({name = "ei-gate", count = 1}) then
        target_inv.insert({name = "ei-gate", count = 1})
        return true
    end

    return false

end


function model.transfer(transfer)

    local target_inv = model.get_transfer_inv(transfer)
    
    if not target_inv then
        return
    end

    target_inv.insert({name = "ei-gate", count = 1})
end


function model.register_gate(gate, container)

    model.check_global_init()
    
    local gate_unit = gate.unit_number

    if storage.ei.gate.gate[gate_unit] then
        return
    end

    storage.ei.gate.gate[gate_unit] = {}
    storage.ei.gate.gate[gate_unit].gate = gate
    storage.ei.gate.gate[gate_unit].container = container

    -- set endpoint to (0, 0)
    storage.ei.gate.gate[gate_unit].exit = {surface = default_exit_surface(gate), x = 0, y = 0}
    storage.ei.gate.gate[gate_unit].state = false


end


function model.find_gate(container)

    if not container then
        return nil
    end

    if container.name ~= "ei-gate-container" then
        return nil
    end

    local gate = container.surface.find_entity("ei-gate", container.position)

    if not gate then
        return nil
    end

    return gate

end

--GATE LOGIC
-----------------------------------------------------------------------------------------------------

function model.make_gate(gate)

    -- create and register cate-container
    local container = gate.surface.create_entity({
        name = "ei-gate-container",
        position = gate.position,
        force = gate.force
    })

    model.register_gate(gate, container)

end


function model.destroy_gate(gate, container)

    if not gate and container then
        -- look for gate at container position
        gate = container.surface.find_entity("ei-gate", container.position)
    end

    if not container and gate then
        -- look for container at gate position
        container = gate.surface.find_entity("ei-gate-container", gate.position)
    end

    local gate_unit = gate and gate.valid and gate.unit_number
    local gate_data = gate_unit and storage.ei.gate.gate[gate_unit]

    if gate_data then
        util.destroy_render(gate_data.animation)
        storage.ei.gate.gate[gate_unit] = nil
    end

    if model.entity_check(gate) then
        gate.destroy()
    end

    if model.entity_check(container) then
        -- do not delete the items that were waiting for transport
        local inventory = container.get_inventory(defines.inventory.chest)
        if inventory and not inventory.is_empty() then
            for i = 1, #inventory do
                local stack = inventory[i]
                if stack.valid_for_read then
                    container.surface.spill_item_stack{
                        position = container.position,
                        stack = stack,
                        enable_looted = true,
                        force = container.force,
                        allow_belts = false,
                    }
                end
            end
        end
        container.destroy()
    end

end


---Moves items from the gate container into the exit container (if powered, switched on and the
---exit is valid). Every transported item costs model.energy_costs.item MJ.
---@param unit integer gate unit number
---@param gate LuaEntity
function model.transfer_items(unit, gate)

    if not model.gate_state(gate) then
        return
    end

    local exit_container = storage.ei.gate.gate[unit].exit_container

    if exit_container then

        -- is container still valid? if not try to find new one
        if not exit_container.valid then
            
            local position = {x = storage.ei.gate.gate[unit].exit.x, y = storage.ei.gate.gate[unit].exit.y}
            local surface = game.get_surface(storage.ei.gate.gate[unit].exit.surface)

            if not model.find_container(gate, surface, position) then
                return
            end   
            
            exit_container = storage.ei.gate.gate[unit].exit_container

        end

        local source_container = storage.ei.gate.gate[unit].container
        if not util.is_valid(source_container) then return end
        local source_inv = source_container.get_inventory(defines.inventory.chest)
        if source_inv.is_empty() then return end

        local target_inv = exit_container.get_inventory(defines.inventory.chest)
        if target_inv.is_full() then return end

        local success = false

        -- loop over source inv and try to transfer to target inv
        for i = 1, #source_inv do
            if source_inv[i].valid_for_read then
                
                local transfer_count = target_inv.insert(source_inv[i])
                if transfer_count > 0 then

                    if model.pay_energy(gate, {{count = transfer_count}}) then

                        source_inv[i].count = source_inv[i].count - transfer_count
                        success = true

                        ei_victory.count_value("gate_items_transported", transfer_count)

                    end

                end 

            end
        end

        if success then
            model.render_exit(gate, exit_container.bounding_box)
        end

    end

    return

end


function model.find_container(gate, surface, position, print_out)
    if not gate then return false end 
    if not gate.valid then return false end 
    if not surface then return false end 
    if not surface.valid then return false end     

    print_out = print_out or false
    local unit = gate.unit_number

    -- try to snap position to a container entity
    local containers = surface.find_entities_filtered(
        {
            area = {
                {position.x - 0.3, position.y - 0.3},
                {position.x + 0.3, position.y + 0.3}
            },
            type = {
                "container",
                "logistic-container",
            }
        }
    )

    if #containers > 0 and containers[1].name ~= "ei-gate-container" then
        position = containers[1].position
        storage.ei.gate.gate[unit].exit_container = containers[1]

        if print_out then
            gate.force.print({"exotic-industries.gate-exit-container-set", surface.name, position.x, position.y, containers[1].name})
        end

    else
        storage.ei.gate.gate[unit].exit_container = nil

        if print_out then
            gate.force.print({"exotic-industries.gate-exit-set", surface.name, position.x, position.y})
        end
        return false
    end

    -- set new exit
    storage.ei.gate.gate[unit].exit = {
        surface = surface.name,
        x = position.x,
        y = position.y
    }
    
    return true

end


function model.gate_state(gate)
    if not gate then return false end 
    if not gate.valid then return false end 

    -- will be false if no exit is set

    local exit = storage.ei.gate.gate[gate.unit_number] and storage.ei.gate.gate[gate.unit_number].exit
    if not exit then
        return false
    end

    -- hub rule: an exit that breaks it never transfers anything
    if not model.is_allowed_exit(gate.surface, game.get_surface(exit.surface or "")) then
        return false
    end

    -- also check if has power
    if gate.energy < 1000000000 then
        return false
    end

    if not storage.ei.gate.gate[gate.unit_number].state then
        return false
    end

    return true
end


function model.pay_energy(gate, tablein)

    -- check if gate has enough energy to transport all contents of tablein
    -- if so, pay and return true

    local energy = 0
    for _, v in ipairs(tablein) do
        energy = energy + model.energy_costs.item * v.count
    end

    -- change to Mj
    energy = energy * 1000000

    if gate.energy < energy then
        return false
    end

    gate.energy = gate.energy - energy
    return true

end

function model.update_energy(unit, gate)

    -- if energy below 100MJ/2 turn off
    if gate.energy < 50000000 then

        if storage.ei.gate.gate[unit].state == true then
            gate.force.print({"exotic-industries.gate-not-enough-energy", gate.position.x, gate.position.y, gate.surface.name})
        end

        storage.ei.gate.gate[unit].state = false
    end

    -- update gui if open
    for _, player in pairs(game.connected_players) do
        if player.gui.relative["ei-gate-console"] then
            -- only update the gui if the gui open belongs to this gate
            local open_gate = model.find_gate(util.opened_entity(player))
            if open_gate and open_gate.unit_number == unit then
                model.update_gui(player, model.get_data(gate), true)
            end
        end
    end

end


function model.create_gate_user_permission_group()

    local group = game.permissions.create_group("gate-user")

    -- disable all
    for action,_ in pairs(defines.input_action) do
        group.set_allows_action(defines.input_action[action], false)
    end

    -- allow movement + items
    group.set_allows_action(defines.input_action.start_walking, true)
    group.set_allows_action(defines.input_action.use_item, true)

end


--RENDERING
-----------------------------------------------------------------------------------------------------

function model.render_exit(gate, box)

    local gate_unit = gate.unit_number
    local exit = storage.ei.gate.gate[gate_unit].exit
    local animation

    -- check if exit already exists, if at same pos and surface extend time to live
    if storage.ei.gate.gate[gate_unit].exit_animation then

        animation = storage.ei.gate.gate[gate_unit].exit_animation  --[[@as LuaRenderObject]]

        -- check if still valid, might be very old
        if animation.valid then

            -- also test pos and surface  
            local target = animation.target
            local surface = animation.surface
            
            if target.position.x == exit.x and target.position.y == exit.y and surface.name == exit.surface then
                
                -- extend time to live
                animation.time_to_live = 180
                return
            end
        end
    end

    local x_scale = 1
    local y_scale = 1

    if box then
        -- bounding box of container
        -- both x,y = 1 <=> width: 6tiles, height: 5tiles

        local width = math.abs(box.right_bottom.x - box.left_top.x)
        local height = math.abs(box.right_bottom.y - box.left_top.y)

        x_scale = (width / 6) * 1.2
        y_scale = (height / 5) * 1.2
    end

    -- create new exit
    animation = rendering.draw_animation{
        animation = "ei-exit-simple",
        target = {exit.x, exit.y},
        surface = exit.surface,
        render_layer = "object",
        animation_speed = 0.6,
        x_scale = x_scale,
        y_scale = y_scale,
        time_to_live = 180,
    }

    storage.ei.gate.gate[gate_unit].exit_animation = animation
    
end


-- colours of the flickering gate glow
local GATE_GLOW_COLORS = {
    {r = 0, g = 0.4, b = 1.0},
    {r = 0.4, g = 0.2, b = 1.0},
    {r = 0.2, g = 0.2, b = 1.0},
    {r = 0.4, g = 0.1, b = 0.8},
}

function model.render_animation(gate)

    local gate_unit = gate.unit_number

    -- short glow with a random colour, renewed every update
    rendering.draw_light {
        sprite = "gate_glow",
        scale = 3,
        intensity = 0.2,
        color = GATE_GLOW_COLORS[math.random(1, #GATE_GLOW_COLORS)],
        target = gate,
        surface = gate.surface,
        time_to_live = ei_ticksPerFullUpdate * 2,
        blend_mode = "multiplicative",
        apply_runtime_tint = true,
        draw_as_glow = true,
    }

    local current = storage.ei.gate.gate[gate_unit].animation
    if current and current.valid then return end

    local animation = rendering.draw_animation{
        animation = "ei-gate-running",
        target = gate,
        surface = gate.surface,
        render_layer = "object",
        x_scale = 1,
        y_scale = 1
    }

    storage.ei.gate.gate[gate_unit].animation = animation

end


function model.update_renders(unit, gate)

    local state = model.gate_state(gate)
    -- if state true -> check if need to render animation
    -- if state false -> check if need to destroy animation + cleanup

    if not state then
        if storage.ei.gate.gate[unit].animation then
            util.destroy_render(storage.ei.gate.gate[unit].animation)
            storage.ei.gate.gate[unit].animation = nil
        end
    else
        model.render_animation(gate)
    end

end


--GUI
-----------------------------------------------------------------------------------------------------

function model.open_gui(player)

    if player.gui.relative["ei-gate-console"] then
        model.close_gui(player)
    end

    local root = player.gui.relative.add{
        type = "frame",
        name = "ei-gate-console",
        anchor = {
            gui = defines.relative_gui_type.container_gui,
            name = "ei-gate-container",
            position = defines.relative_gui_position.right,
        },
        direction = "vertical",
    }

    do -- Titlebar
        local titlebar = root.add{type = "flow", direction = "horizontal"}
        titlebar.add{
            type = "label",
            caption = {"exotic-industries.gate-gui-title"},
            style = "frame_title",
        }

        titlebar.add{
            type = "empty-widget",
            style = "ei-titlebar-nondraggable-spacer",
            ignored_by_interaction = true
        }

        titlebar.add{
            type = "sprite-button",
            sprite = "virtual-signal/informatron",
            tooltip = {"exotic-industries.gui-open-informatron"},
            style = "frame_action_button",
            tags = {
                parent_gui = "ei-gate-console",
                action = "goto-informatron",
                page = "gate"
            }
        }
    end

    local main_container = root.add{
        type = "frame",
        name = "main-container",
        direction = "vertical",
        style = "inside_shallow_frame",
    }

    do -- Status subheader
        main_container.add{
            type = "frame",
            style = "ei-subheader-frame",
        }.add{
            type = "label",
            caption = {"exotic-industries.gate-gui-status-title"},
            style = "subheader_caption_label",
        }
    
        local status_flow = main_container.add{
            type = "flow",
            name = "status-flow",
            direction = "vertical",
            style = "ei-inner-content-flow",
        }

        status_flow.add{
            type = "progressbar",
            name = "energy",
            caption = {"exotic-industries.gate-gui-status-energy", 0},
            tooltip = {"exotic-industries.gate-gui-status-energy-tooltip"},
            style = "ei-status-progressbar"
        }

    end


    do -- Control subheader
        main_container.add{
            type = "frame",
            style = "ei-subheader-frame",
        }.add{
            type = "label",
            caption = {"exotic-industries.gate-gui-control-title"},
            style = "subheader_caption_label",
        }
    
        local control_flow = main_container.add{
            type = "flow",
            name = "control-flow",
            direction = "horizontal",
            style = "ei-inner-content-flow-horizontal",
        }

        local target_flow = control_flow.add{
            type = "flow",
            name = "target-flow",
            direction = "vertical"
        }

        -- Surface
        local dropdown_flow = target_flow.add{
            type = "flow",
            name = "dropdown-flow",
            direction = "vertical"
        }
    
        dropdown_flow.add{
            type = "label",
            caption = {"exotic-industries.gate-gui-control-dropdown-label"},
            tooltip = {"exotic-industries.gate-gui-control-dropdown-label-tooltip"}
        }
        dropdown_flow.add{
            type = "drop-down",
            name = "surface",
            tags = {
                parent_gui = "ei-gate-console",
                action = "set-surface"
            }
        }

        -- Position
        local position_flow = target_flow.add{
            type = "flow",
            name = "position-flow",
            direction = "vertical"
        }

        position_flow.add{
            type = "label",
            caption = {"exotic-industries.gate-gui-control-position-label"},
            tooltip = {"exotic-industries.gate-gui-control-position-label-tooltip"}
        }
        position_flow.add{
            type = "button",
            name = "position-button",
            caption = {"exotic-industries.gate-gui-control-position-button", 0, 0},
            style = "ei-small-button",
            tags = {
                action = "set-position",
                parent_gui = "ei-gate-console",
            }
        }

        position_flow.add{
            type = "label",
            caption = {"exotic-industries.gate-gui-control-state-label"},
        }
        position_flow.add{
            type = "button",
            name = "state-button",
            caption = {"exotic-industries.gate-gui-control-state-button", "OFF"},
            tooltip = {"exotic-industries.gate-gui-control-state-button-tooltip"},
            style = "ei-small-red-button",
            tags = {
                action = "set-state",
                parent_gui = "ei-gate-console",
            }
        }

        -- Target cam
        local camera_frame = control_flow.add{
            type = "frame",
            name = "camera-frame",
            style = "ei-small-camera-frame"
        }
        camera_frame.add{
            type = "camera",
            name = "target-camera",
            position = {0, 0},
            surface_index = 1,
            zoom = 0.25,
            style = "ei-small-camera"
        }

    end

    local data = model.get_data(model.find_gate(util.opened_entity(player)))
    model.update_gui(player, data)

end


function model.update_gui(player, data, ontick)

    if not data then return end

    local root = player.gui.relative["ei-gate-console"]
    local status = root["main-container"]["status-flow"]
    local control = root["main-container"]["control-flow"]


    local energy = status["energy"]
    local dropdown = control["target-flow"]["dropdown-flow"]["surface"]
    local position = control["target-flow"]["position-flow"]["position-button"]
    local camera = control["camera-frame"]["target-camera"]
    local state = control["target-flow"]["position-flow"]["state-button"]

    -- Update status
    energy.caption = {"exotic-industries.gate-gui-status-energy", string.format("%.0f", data.energy/1000000)}
    energy.value = data.energy / data.max_energy

    -- if ontick update dont redo user input stuff
    if ontick then return end

    -- Surface dropdown
    local selected_index
    local surface_strings = {}
    for i, possible_surface in pairs(data.surfaces) do
      if game.get_surface(possible_surface) then
        surface_strings[i] = possible_surface
        if data.target_surface == possible_surface then
          selected_index = i
        end
      end
    end
    dropdown.items = surface_strings
    if selected_index then
        dropdown.selected_index = selected_index
    end
    dropdown.tags = {
        parent_gui = "ei-gate-console",
        action = "set-surface",
        surface_list = data.surfaces -- to get surface later on with index
    }

    -- Position button
    position.caption = {"exotic-industries.gate-gui-control-position-button", string.format("%.1f", data.target_pos.x), string.format("%.1f", data.target_pos.y)}

    -- Camera
    camera.position = {data.target_pos.x, data.target_pos.y}

    if not data.target_surface then return end
    if not game.get_surface(data.target_surface) then return end
    
    camera.surface_index = game.get_surface(data.target_surface).index or 1

    -- State button
    if data.state then
        state.style = "ei-small-green-button"
        state.caption = {"exotic-industries.gate-gui-control-state-button", "ON"}
    else
        state.style = "ei-small-red-button"
        state.caption = {"exotic-industries.gate-gui-control-state-button", "OFF"}
    end

end


function model.update_player_guis()

    for _, player in pairs(game.connected_players) do
        if player.gui.relative["ei-gate-console"] then
            local gate = model.find_gate(util.opened_entity(player))
            if gate then
                model.update_gui(player, model.get_data(gate), true)
            else
                model.close_gui(player)
            end
        end
    end

end


function model.update_surface(player)

    local entity = util.opened_entity(player)
    local root = player.gui.relative["ei-gate-console"]
    if not root or not entity then return end

    if entity.name ~= "ei-gate-container" then return end

    local dropdown = root["main-container"]["control-flow"]["target-flow"]["dropdown-flow"]["surface"]
    local surface_list = dropdown.tags.surface_list
    local selected_surface = surface_list and surface_list[dropdown.selected_index]

    local gate = model.find_gate(entity)

    if not gate or not selected_surface or not storage.ei.gate.gate[gate.unit_number] then return end

    -- hub rule (the dropdown only offers allowed surfaces, but tags could be stale)
    if not model.is_allowed_exit(gate.surface, game.get_surface(selected_surface)) then
        player.print({"exotic-industries.gate-hub-rule"})
        return
    end

    storage.ei.gate.gate[gate.unit_number].exit.surface = selected_surface
    storage.ei.gate.gate[gate.unit_number].exit_container = nil -- the old container is on another surface

    local data = model.get_data(gate)
    model.update_gui(player, data)

end


function model.toggle_state(player)

    local entity = util.opened_entity(player)
    local root = player.gui.relative["ei-gate-console"]
    if not root or not entity then return end

    if entity.name ~= "ei-gate-container" then return end

    local gate = model.find_gate(entity)
    if not gate or not storage.ei.gate.gate[gate.unit_number] then return end

    -- try to toggle state, if not enough energy return
    local energy = gate.energy
    if energy < 1000000000 then
        player.print({"exotic-industries.gate-not-enough-energy", gate.position.x, gate.position.y, gate.surface.name})
    else
        -- toggle state
        storage.ei.gate.gate[gate.unit_number].state = not storage.ei.gate.gate[gate.unit_number].state
    end

    local data = model.get_data(gate)
    model.update_gui(player, data)

end


---Remote exit selection: the player's character stays at the gate (invulnerable and inoperable),
---the player is moved as a character-less "ghost" to the current exit and gets a gate remote.
---Using the remote (see model.used_remote) sets the new exit and returns the player.
---Pending selections are stored per player in storage.ei.gate.remote[player_index].
function model.choose_position(player)

    local entity = util.opened_entity(player)
    local root = player.gui.relative["ei-gate-console"]
    if not root or not entity then return end

    if entity.name ~= "ei-gate-container" then return end

    local gate = model.find_gate(entity)
    if not gate or not storage.ei.gate.gate[gate.unit_number] then return end

    storage.ei.gate.remote = storage.ei.gate.remote or {}
    -- migrate the old single-slot format ({player = ..., ...})
    if storage.ei.gate.remote.player then
        storage.ei.gate.remote = {}
    end

    -- this player is already selecting a position
    if storage.ei.gate.remote[player.index] then return end

    local exit = storage.ei.gate.gate[gate.unit_number].exit
    if not exit or not exit.surface then return end

    local target_surface = game.get_surface(exit.surface)
    if not target_surface then return end

    local character = player.character
    if not character then return end

    -- make the original character "op" while the player is away
    character.destructible = false
    character.operable = false

    -- clone character to current position, swap the player to it and teleport it to the target
    local clone = character.clone({
        position = player.position,
        surface = player.surface,
        force = player.force,
        create_build_effect_smoke = false
    })
    if not clone then
        character.destructible = true
        character.operable = true
        return
    end

    player.character = clone
    player.teleport({exit.x, exit.y}, target_surface)

    -- detach clone from player (player is character-less now)
    player.character = nil
    clone.destroy({raise_destroy = false})

    storage.ei.gate.remote[player.index] = {
        player = player,
        original_character = character,
        gate_unit = gate.unit_number,
        permission_group = player.permission_group and player.permission_group.name or "Default",
    }

    if not game.permissions.get_group("gate-user") then
        model.create_gate_user_permission_group()
    end
    model.change_permission(player, "gate-user")

    -- give the gate remote
    player.cursor_stack.set_stack({name = "ei-gate-remote", count = 1})

end


function model.get_data(gate)

    if not gate then return end

    local data = {}

    data.max_energy = gate.electric_buffer_size
    data.energy = gate.energy

    -- surfaces allowed by the hub rule (gate on Gaia: all others, elsewhere: only Gaia)
    data.surfaces = model.allowed_exit_surfaces(gate)

    local exit = storage.ei.gate.gate[gate.unit_number].exit
    data.target_surface = exit.surface
    data.target_pos = {x = exit.x, y = exit.y}
    data.state = storage.ei.gate.gate[gate.unit_number].state

    return data

end


function model.change_permission(player, new_group)

    local group = game.permissions.get_group(new_group or "Default")

    if not group then
        log("Exotic Space Industries: permission group '" .. tostring(new_group) .. "' does not exist")
        return
    end

    player.permission_group = group

end


--HANDLERS
-----------------------------------------------------------------------------------------------------

function model.on_built_entity(entity)

    if model.entity_check(entity) == false then
        return
    end

    if entity.name == "ei-gate" then
        model.make_gate(entity)
    end

end


function model.on_destroyed_entity(entity, transfer)

    if model.entity_check(entity) == false then
        return
    end

    if entity.name ~= "ei-gate" and entity.name ~= "ei-gate-container" then
        return
    end

    model.check_global_init()

    if not model.transfer_valid(transfer) then
        return
    end

    if entity.name == "ei-gate" then

        model.destroy_gate(entity, nil)
        return

    end

    -- normaly gate gets mined/destroyed first
    if entity.name == "ei-gate-container" then

        model.destroy_gate(nil, entity)
        return

    end

end


---Round-robin: updates one gate per call (item transfer, renders, energy, open GUIs).
---@return boolean did_work
function model.update()

    local gates = storage.ei.gate and storage.ei.gate.gate
    if not gates then
      return false
    end

    local key = util.next_key(gates, storage.ei.gate.gate_break_point)
    storage.ei.gate.gate_break_point = key
    if key == nil then
      return false
    end

    local gate = gates[key].gate
    if gate and gate.valid then
        model.transfer_items(key, gate)
        model.update_renders(key, gate)
        model.update_energy(key, gate)
    else
        -- gate vanished without a destroy event: remove the leftovers
        util.destroy_entity(gates[key].container)
        util.destroy_render(gates[key].animation)
        gates[key] = nil
    end

    return true

end

---Finds the pending remote selection that belongs to a used gate remote.
---The remote is used while the player has no character, so the event carries no player; the
---pending selection of the player on that surface holding the remote in the cursor is used.
local function find_remote_user(event)
    local remotes = storage.ei.gate.remote
    if not remotes then return nil end

    for player_index, data in pairs(remotes) do
        local player = data.player
        if player and player.valid and player.surface.index == event.surface_index then
            local cursor = player.cursor_stack
            if cursor and cursor.valid_for_read and cursor.name == "ei-gate-remote" then
                return player_index, data
            end
        end
    end

    return nil
end

---Returns the player of a pending remote selection to the original character.
---@param player_index integer
---@param restore_only boolean|nil only restore the character flags (player is being removed)
function model.finish_remote(player_index, restore_only)

    local remotes = storage.ei.gate and storage.ei.gate.remote
    if not remotes or remotes.player then return end -- nothing pending / old single-slot format
    local data = remotes[player_index]
    if not data then return end
    remotes[player_index] = nil

    local player = data.player
    local original_character = data.original_character

    if player and player.valid then
        model.change_permission(player, data.permission_group or "Default")

        local cursor = player.cursor_stack
        if cursor and cursor.valid_for_read and cursor.name == "ei-gate-remote" then
            cursor.clear()
        end
    end

    if not (original_character and original_character.valid) then
        return
    end

    -- de "op" original character
    original_character.destructible = true
    original_character.operable = true

    if restore_only or not (player and player.valid and player.connected) then
        return
    end

    -- temporary character to carry the player back, then swap to the original one
    local transport = player.surface.create_entity({
        name = "character",
        position = player.position,
        force = player.force,
    })

    if transport then
        player.character = transport
        player.teleport(original_character.position, original_character.surface)
        player.character = original_character
        transport.destroy({raise_destroy = false})
    else
        player.teleport(original_character.position, original_character.surface)
        player.character = original_character
    end

end

---Gate remote used: set the new exit (snapping to a container) and return the player.
function model.used_remote(event)

    local surface = game.get_surface(event.surface_index)
    local position = event.target_position
    if not surface or not position then return end

    local player_index, data = find_remote_user(event)
    if not player_index then return end

    local gate_data = storage.ei.gate.gate[data.gate_unit]
    if gate_data and util.is_valid(gate_data.gate) and not model.is_allowed_exit(gate_data.gate.surface, surface) then
        util.force_print(gate_data.gate, {"exotic-industries.gate-hub-rule"}) -- hub rule
    elseif gate_data and util.is_valid(gate_data.gate) then
        if not model.find_container(gate_data.gate, surface, position, true) then
            gate_data.exit = {
                surface = surface.name,
                x = position.x,
                y = position.y
            }
        end
    end

    model.finish_remote(player_index)

end

--GUI HANDLER
-----------------------------------------------------------------------------------------------------

function model.on_gui_selection_state_changed(event)
    local action = event.element.tags.action

    if action == "set-surface" then
        model.update_surface(game.get_player(event.player_index))
    end
end


function model.close_gui(player)
    if player.gui.relative["ei-gate-console"] then
        player.gui.relative["ei-gate-console"].destroy()
    end
end


function model.on_gui_opened(event)
    model.open_gui(game.get_player(event.player_index))
end


function model.on_gui_click(event)
    if event.element.tags.action == "set-state" then
        model.toggle_state(game.get_player(event.player_index))
        return
    end

    if event.element.tags.action == "set-position" then
        model.choose_position(game.get_player(event.player_index))
        return
    end

end

return model
-- TODO:
-- have gates that turned off due to power restart when power is back?
-- allow logistic chests as endpoints?