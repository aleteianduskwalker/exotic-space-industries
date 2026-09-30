--====================================================================================================
-- DRONE PORT (3.2.0)
--====================================================================================================
-- Narrowly specialised, fully controlled drones (prototypes/alien_structures/drone-port.lua).
--
-- A drone is an item stored in a drone port. Launching a task takes one drone out of the port; while
-- the task runs the drone is only a picture (rendering) moved by this script: no collision, no path
-- finding, invulnerable and intangible. Every task position has to be within balance.range of its
-- port on the port surface. Every departure from the port (and every new cycle) costs
-- balance.trip_energy from the port buffer - a port without power keeps its drones waiting.
--
-- TASKS (one drone each)
--   salvage   mine one neutral structure (ruin, boulder, tree, ...) once, bring the result to the port;
--             broken alien artifacts on Gaia grant alien knowledge like manual salvaging
--   mine      mine a resource patch like a player (balance.mining_speed) and bring the ore to a
--             container of the port force; ends when the resource is gone
--   transfer  move exactly ONE item (any quality) from a container (or a gate) to another one
--   guard     repair damaged structures of the port force in a zone (max balance.max_zone_size) with
--             repair packs taken from the port, by priority: class order (turrets / walls / other)
--             chosen in the GUI, then the lowest health ratio, then the closest structure
--
-- storage.ei.drones = {
--     ports   = {[port_unit] = {entity, energy, render, tasks = {[task_id] = true}}},
--     tasks   = {[task_id] = task},     see model.create_task
--     next_id = integer,
--     pending = {[player_index] = {port, type, item, priority, source}}   remote selection in progress
--     gui     = {[player_index] = {type, item, priority, port}}             GUI state
-- }
--====================================================================================================

local ei_balance = require("lib/balance")

local B = ei_balance.drones
local model = {}

model.PORT = "ei-drone-port"
model.ENERGY = "ei-drone-port-energy"
model.DRONE = "ei-drone"
model.REMOTE = "ei-drone-remote"
model.GUI_NAME = "ei-drone-port-console"

model.TASK_TYPES = {"salvage", "mine", "transfer", "guard"}

-- guard priorities: class orders selectable in the GUI
model.PRIORITIES = {
    {"turret", "wall", "other"},
    {"turret", "other", "wall"},
    {"wall", "turret", "other"},
    {"wall", "other", "turret"},
    {"other", "turret", "wall"},
    {"other", "wall", "turret"},
}

local TURRET_TYPES = {
    ["ammo-turret"] = true, ["electric-turret"] = true, ["fluid-turret"] = true,
    ["artillery-turret"] = true, ["turret"] = true,
}
local WALL_TYPES = {["wall"] = true, ["gate"] = true}
-- never repaired by drones (not repairable with repair packs or not structures)
local NOT_REPAIRED = {["character"] = true, ["unit"] = true, ["spider-leg"] = true, ["entity-ghost"] = true}
local CONTAINER_TYPES = {"container", "logistic-container", "infinity-container"}

local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

--STORAGE
------------------------------------------------------------------------------------------------------

function model.check_init()
    storage.ei.drones = storage.ei.drones or {}
    local d = storage.ei.drones
    d.ports = d.ports or {}
    d.tasks = d.tasks or {}
    d.next_id = d.next_id or 1
    d.pending = d.pending or {}
    d.gui = d.gui or {}
end

local function data()
    model.check_init()
    return storage.ei.drones
end

--UTIL
------------------------------------------------------------------------------------------------------

local function distance(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

local function copy_position(position)
    return {x = position.x or position[1], y = position.y or position[2]}
end

---True if a position is inside the working range of a port (same surface required separately).
local function in_range(port_entity, position)
    return distance(port_entity.position, position) <= B.range
end

---Direction frame (0..63, north first, clockwise) of a flight from `from` to `to`.
local function direction(from, to)
    local angle = atan2(to.x - from.x, from.y - to.y) -- clockwise from north
    return math.floor(angle / (2 * math.pi) * 64 + 0.5) % 64
end

---Total number of items in the cargo of a task.
local function cargo_count(task)
    local count = 0
    for _, stack in pairs(task.cargo) do count = count + stack.count end
    return count
end

---Adds items to the cargo of a task (merged by name + quality).
local function add_cargo(task, name, quality, count)
    if count <= 0 then return end
    quality = quality or "normal"
    for _, stack in pairs(task.cargo) do
        if stack.name == name and stack.quality == quality then
            stack.count = stack.count + count
            return
        end
    end
    table.insert(task.cargo, {name = name, quality = quality, count = count})
end

---Inserts the cargo into an inventory owner (entity with inventory / LuaInventory).
---Items that do not fit stay in the cargo. Returns true when the cargo is empty.
local function unload_into(task, target)
    for i = #task.cargo, 1, -1 do
        local stack = task.cargo[i]
        local inserted = target.insert({name = stack.name, quality = stack.quality, count = stack.count})
        stack.count = stack.count - inserted
        if stack.count <= 0 then table.remove(task.cargo, i) end
    end
    return #task.cargo == 0
end

---Spills the cargo (and optionally the drone itself) on the ground.
local function spill_cargo(task, surface, position, with_drone)
    for _, stack in pairs(task.cargo) do
        surface.spill_item_stack{position = position, stack = {name = stack.name, quality = stack.quality, count = stack.count},
            enable_looted = true, allow_belts = false}
    end
    task.cargo = {}
    if with_drone then
        surface.spill_item_stack{position = position, stack = {name = model.DRONE, count = 1}, enable_looted = true, allow_belts = false}
    end
end

--RENDERING
------------------------------------------------------------------------------------------------------

local function destroy_render(task)
    for _, key in pairs({"drone", "shadow"}) do
        local object = task.render and task.render[key]
        if object and object.valid then object.destroy() end
    end
    task.render = nil
end

---Creates or moves the drone picture of a task.
local function draw(task, surface)
    local drone_position = {x = task.pos.x, y = task.pos.y - B.flight_height}
    if not (task.render and task.render.drone and task.render.drone.valid) then
        destroy_render(task)
        task.render = {
            shadow = rendering.draw_animation{animation = "ei-drone-flying-shadow", target = task.pos, surface = surface,
                animation_speed = 0, animation_offset = task.dir or 0, render_layer = "object"},
            drone = rendering.draw_animation{animation = "ei-drone-flying", target = drone_position, surface = surface,
                animation_speed = 0, animation_offset = task.dir or 0, render_layer = "air-object"},
        }
        return
    end
    task.render.drone.target = drone_position
    task.render.shadow.target = task.pos
    task.render.drone.animation_offset = task.dir or 0
    task.render.shadow.animation_offset = task.dir or 0
end

--PORTS
------------------------------------------------------------------------------------------------------

---Registers a drone port: hidden power interface + working animation.
---@param entity LuaEntity
function model.register_port(entity)
    local ports = data().ports
    if ports[entity.unit_number] then return end

    local energy = entity.surface.find_entity(model.ENERGY, entity.position)
    if not (energy and energy.valid) then
        energy = entity.surface.create_entity{name = model.ENERGY, position = entity.position, force = entity.force,
            create_build_effect_smoke = false, raise_built = false}
    end
    if energy then energy.destructible = false end

    ports[entity.unit_number] = {
        entity = entity,
        energy = energy,
        render = rendering.draw_animation{animation = "ei-drone-port-working", target = entity, surface = entity.surface,
            render_layer = "higher-object-under", visible = false},
        tasks = {},
    }
end

local function get_port(unit)
    local port = data().ports[unit]
    if port and port.entity and port.entity.valid then return port end
    return nil
end

---True if the port buffer holds enough energy for one departure (and takes it).
local function pay_trip(port)
    local energy = port.energy
    if not (energy and energy.valid) or energy.energy < B.trip_energy then return false end
    energy.energy = energy.energy - B.trip_energy
    return true
end

---Removes a port: running drones drop their cargo and themselves where they are.
---@param unit integer
function model.unregister_port(unit)
    local d = data()
    local port = d.ports[unit]
    if not port then return end

    for task_id in pairs(port.tasks) do
        local task = d.tasks[task_id]
        if task then
            local surface = game.get_surface(task.surface)
            if surface then spill_cargo(task, surface, task.pos, true) end
            destroy_render(task)
            d.tasks[task_id] = nil
        end
    end
    if port.energy and port.energy.valid then port.energy.destroy() end
    if port.render and port.render.valid then port.render.destroy() end
    d.ports[unit] = nil
end

--TASKS
------------------------------------------------------------------------------------------------------

---Starts a flight of a task to `destination`; `after` is the state on arrival.
local function fly(task, destination, after)
    task.dest = copy_position(destination)
    task.after = after
    task.state = "flying"
    task.dir = direction(task.pos, task.dest)
end

---Sends a drone back to its port (cargo is unloaded there, then the task ends).
local function go_home(task, port)
    fly(task, port.entity.position, "home")
end

local function wait(task, status, ticks)
    task.status = status
    task.wake = game.tick + (ticks or B.scan_interval)
end

---Creates a task, takes a drone out of the port. Returns the task or nil + locale key of the reason.
---@param port_unit integer
---@param params table {type, target, source, destination, item, zone, priority}
function model.create_task(port_unit, params)
    local port = get_port(port_unit)
    if not port then return nil, "drone-no-port" end
    local inventory = port.entity.get_inventory(defines.inventory.chest)
    if inventory.get_item_count(model.DRONE) < 1 then return nil, "drone-no-drone" end
    inventory.remove({name = model.DRONE, count = 1})

    local d = data()
    local task = {
        id = d.next_id,
        port = port_unit,
        type = params.type,
        surface = port.entity.surface.index,
        pos = copy_position(port.entity.position),
        dir = 0,
        state = "start",
        wake = game.tick,
        status = "drone-status-starting",
        cargo = {},
        target = params.target,
        source = params.source,
        destination = params.destination,
        item = params.item,
        zone = params.zone,
        priority = params.priority or 1,
        progress = 0,
        repair = {durability = 0, speed = 1},
    }
    d.next_id = d.next_id + 1
    d.tasks[task.id] = task
    port.tasks[task.id] = true
    return task
end

---Ends a task at its port: cargo and drone go into the port (the rest is spilled next to it).
local function finish(task, port)
    local d = data()
    if port then
        local entity = port.entity
        unload_into(task, entity)
        if entity.insert({name = model.DRONE, count = 1}) < 1 then
            spill_cargo(task, entity.surface, entity.position, true)
        else
            spill_cargo(task, entity.surface, entity.position, false)
        end
        port.tasks[task.id] = nil
    end
    destroy_render(task)
    d.tasks[task.id] = nil
end

---Recalls a drone: it flies back to the port and ends its task there.
---@param task_id integer
function model.recall(task_id)
    local task = data().tasks[task_id]
    if not task then return end
    local port = get_port(task.port)
    if not port then
        data().tasks[task_id] = nil
        destroy_render(task)
        return
    end
    task.recalled = true
    go_home(task, port)
end

--TASK LOGIC
------------------------------------------------------------------------------------------------------

local steps = {}

-- common: arrived at the port
function steps.home(task, port)
    finish(task, port)
end

-- SALVAGE ------------------------------------------------------------------------------------------

function steps.salvage(task, port)
    local target = task.target
    if task.state == "start" then
        if not (target and target.valid) then return go_home(task, port) end
        if not pay_trip(port) then return wait(task, "drone-status-no-power") end
        task.status = "drone-status-flying"
        return fly(task, target.position, "salvaging")
    end

    -- salvaging
    if not (target and target.valid) then return go_home(task, port) end
    if not task.work_until then
        local mining_time = target.prototype.mineable_properties.mining_time or 1
        task.work_until = game.tick + math.ceil(mining_time * B.salvage_time_multiplier * 60)
        return wait(task, "drone-status-working", task.work_until - game.tick)
    end
    if game.tick < task.work_until then return end

    -- alien knowledge for broken artifacts on Gaia (same as manual salvaging)
    ei_alien_system.on_artifact_salvaged(target, port.entity.force)

    local buffer = game.create_inventory(64)
    target.mine{inventory = buffer, force = port.entity.force, raise_destroyed = true, ignore_minable = false}
    for _, stack in pairs(buffer.get_contents()) do
        add_cargo(task, stack.name, stack.quality, stack.count)
    end
    buffer.destroy()
    task.status = "drone-status-returning"
    go_home(task, port)
end

-- MINE ---------------------------------------------------------------------------------------------

---Mines one unit of a resource into the cargo (like a player: products of the resource).
local function mine_unit(task, resource)
    local properties = resource.prototype.mineable_properties
    for _, product in pairs(properties.products or {}) do
        if product.type == "item" and (not product.probability or math.random() < product.probability) then
            local count = product.amount or math.random(product.amount_min or 1, product.amount_max or 1)
            add_cargo(task, product.name, "normal", count)
        end
    end

    local prototype = resource.prototype
    if prototype.infinite_resource then
        resource.amount = math.max(resource.amount - 1, prototype.minimum_resource_amount or 1)
    elseif resource.amount <= 1 then
        resource.deplete()
    else
        resource.amount = resource.amount - 1
    end
end

function steps.mine(task, port)
    local resource = task.target

    if task.state == "start" then
        if not (resource and resource.valid) then return go_home(task, port) end
        if not pay_trip(port) then return wait(task, "drone-status-no-power") end
        task.status = "drone-status-flying"
        return fly(task, resource.position, "mining")
    end

    if task.state == "mining" then
        if not (resource and resource.valid) or cargo_count(task) >= B.capacity then
            if cargo_count(task) == 0 then return go_home(task, port) end
            local container = task.destination
            if not (container and container.valid) then return go_home(task, port) end
            task.status = "drone-status-delivering"
            return fly(task, container.position, "unloading")
        end

        local mining_time = resource.prototype.mineable_properties.mining_time or 1
        task.progress = task.progress + B.mining_speed / mining_time * B.logic_interval / 60
        while task.progress >= 1 and resource.valid and cargo_count(task) < B.capacity do
            task.progress = task.progress - 1
            mine_unit(task, resource)
        end
        task.status = "drone-status-mining"
        return
    end

    -- unloading
    local container = task.destination
    if not (container and container.valid) then return go_home(task, port) end
    if not unload_into(task, container) then return wait(task, "drone-status-container-full") end
    if not (resource and resource.valid) then
        task.status = "drone-status-returning"
        return go_home(task, port)
    end
    if not pay_trip(port) then return wait(task, "drone-status-no-power") end
    task.status = "drone-status-flying"
    fly(task, resource.position, "mining")
end

-- TRANSFER -----------------------------------------------------------------------------------------

---Takes up to `limit` items of one name (any quality) out of a container inventory into the cargo.
local function take_items(task, inventory, name, limit)
    local taken = 0
    for _, content in pairs(inventory.get_contents()) do
        if content.name == name and taken < limit then
            local removed = inventory.remove({name = name, quality = content.quality, count = math.min(content.count, limit - taken)})
            add_cargo(task, name, content.quality, removed)
            taken = taken + removed
        end
    end
    return taken
end

function steps.transfer(task, port)
    local source, destination = task.source, task.destination
    if not (source and source.valid and destination and destination.valid) then
        task.status = "drone-status-returning"
        return go_home(task, port)
    end

    if task.state == "start" then
        if not pay_trip(port) then return wait(task, "drone-status-no-power") end
        task.status = "drone-status-flying"
        return fly(task, source.position, "loading")
    end

    if task.state == "loading" then
        local inventory = source.get_inventory(defines.inventory.chest)
        if not inventory or take_items(task, inventory, task.item, B.capacity - cargo_count(task)) == 0 and cargo_count(task) == 0 then
            return wait(task, "drone-status-source-empty")
        end
        task.status = "drone-status-delivering"
        return fly(task, destination.position, "unloading")
    end

    -- unloading
    if not unload_into(task, destination) then return wait(task, "drone-status-container-full") end
    if not pay_trip(port) then return wait(task, "drone-status-no-power") end
    task.status = "drone-status-flying"
    fly(task, source.position, "loading")
end

-- GUARD --------------------------------------------------------------------------------------------

---Class of a structure for the guard priorities.
local function repair_class(entity)
    if TURRET_TYPES[entity.type] then return "turret" end
    if WALL_TYPES[entity.type] then return "wall" end
    return "other"
end

---Best damaged structure of the zone: class order of the priority, lowest health ratio, closest.
---@return LuaEntity|nil
function model.pick_repair_target(task, surface, force)
    local order = {}
    for rank, class in ipairs(model.PRIORITIES[task.priority] or model.PRIORITIES[1]) do order[class] = rank end

    local best, best_key
    for _, entity in pairs(surface.find_entities_filtered{area = task.zone, force = force}) do
        local max_health = entity.max_health
        if not NOT_REPAIRED[entity.type] and entity.health and max_health and max_health > 0 and entity.health < max_health then
            local rank = order[repair_class(entity)]
            local ratio = entity.health / max_health
            local dist = distance(task.pos, entity.position)
            if not best_key or rank < best_key[1] or (rank == best_key[1] and (ratio < best_key[2]
                or (ratio == best_key[2] and dist < best_key[3]))) then
                best, best_key = entity, {rank, ratio, dist}
            end
        end
    end
    return best
end

---Loads repair durability from the repair packs of the port (exact durability, no duplication).
local function load_repair_packs(task, port)
    local inventory = port.entity.get_inventory(defines.inventory.chest)
    local wanted = 0
    local loaded = 0

    for i = 1, #inventory do
        local stack = inventory[i]
        if stack.valid_for_read and stack.type == "repair-tool" then
            local max_durability = stack.prototype.get_durability(stack.quality)
            if wanted == 0 then wanted = max_durability * B.repair_packs_per_trip end
            local available = (stack.count - 1) * max_durability + stack.durability
            local amount = math.min(available, wanted - loaded)
            if amount > 0 then
                task.repair.speed = stack.prototype.speed or 1
                stack.drain_durability(amount)
                loaded = loaded + amount
            end
            if loaded >= wanted then break end
        end
    end
    task.repair.durability = task.repair.durability + loaded
    return loaded > 0
end

local function zone_center(zone)
    return {x = (zone.left_top.x + zone.right_bottom.x) / 2, y = (zone.left_top.y + zone.right_bottom.y) / 2}
end

function steps.guard(task, port)
    local surface = port.entity.surface
    local force = port.entity.force

    if task.state == "start" or task.state == "reloading" then
        -- the drone is at the port: load repair packs, then fly to the zone
        if task.repair.durability <= 0 and not load_repair_packs(task, port) then
            return wait(task, "drone-status-no-repair-packs")
        end
        if not pay_trip(port) then return wait(task, "drone-status-no-power") end
        task.status = "drone-status-flying"
        return fly(task, zone_center(task.zone), "guarding")
    end

    if task.repair.durability <= 0 then
        task.status = "drone-status-reloading"
        return fly(task, port.entity.position, "reloading")
    end

    local target = model.pick_repair_target(task, surface, force)
    if not target then
        -- nothing to repair: hover over the zone center
        local center = zone_center(task.zone)
        if distance(task.pos, center) > 1 then return fly(task, center, "guarding") end
        task.state = "guarding"
        return wait(task, "drone-status-guarding")
    end

    if distance(task.pos, target.position) > 1.5 then
        task.status = "drone-status-flying"
        return fly(task, target.position, "repairing")
    end

    -- repairing
    local heal = B.repair_health_per_second * task.repair.speed * B.logic_interval / 60
    heal = math.min(heal, target.max_health - target.health, task.repair.durability)
    target.health = target.health + heal
    task.repair.durability = task.repair.durability - heal
    task.state = "repairing"
    task.status = "drone-status-repairing"
end

--UPDATE
------------------------------------------------------------------------------------------------------

---Moves one flying drone; returns true on arrival.
local function move(task)
    local dx, dy = task.dest.x - task.pos.x, task.dest.y - task.pos.y
    local left = math.sqrt(dx * dx + dy * dy)
    if left <= B.speed then
        task.pos = {x = task.dest.x, y = task.dest.y}
        return true
    end
    task.pos = {x = task.pos.x + dx / left * B.speed, y = task.pos.y + dy / left * B.speed}
    return false
end

---Every tick: flights; every balance.logic_interval ticks: task logic.
---@param tick integer
function model.update(tick)
    local d = storage.ei.drones
    if not d or next(d.tasks) == nil then
        if d and tick % 60 == 0 then model.update_ports() end
        return
    end

    local logic = tick % B.logic_interval == 0
    for id, task in pairs(d.tasks) do
        local port = get_port(task.port)
        local surface = game.get_surface(task.surface)
        if not (port and surface) then
            destroy_render(task)
            d.tasks[id] = nil
        elseif task.state == "flying" then
            if move(task) then
                task.state = task.after
                task.wake = tick
            end
            draw(task, surface)
        elseif logic and tick >= (task.wake or 0) then
            local step = task.state == "home" and steps.home or steps[task.type]
            step(task, port)
            if d.tasks[id] then draw(task, surface) end
        end
    end

    if tick % 60 == 0 then model.update_ports() end
end

---Port animation follows the power state; open GUIs are refreshed.
function model.update_ports()
    local d = data()
    for unit, port in pairs(d.ports) do
        if not (port.entity and port.entity.valid) then
            model.unregister_port(unit)
        elseif port.render and port.render.valid then
            port.render.visible = port.energy and port.energy.valid and port.energy.energy > 0 or false
        end
    end
    for player_index, state in pairs(d.gui) do
        local player = game.get_player(player_index)
        if player and player.gui.relative[model.GUI_NAME] and state.port then
            model.refresh_gui(player)
        end
    end
end

--TARGET SELECTION (drone remote)
------------------------------------------------------------------------------------------------------

---Clamps a selected area to the maximal guard zone size around its center.
local function clamp_zone(area)
    local half = B.max_zone_size / 2
    local center = {x = (area.left_top.x + area.right_bottom.x) / 2, y = (area.left_top.y + area.right_bottom.y) / 2}
    local function clamp(value, low, high) return math.max(low, math.min(high, value)) end
    return {
        left_top = {x = clamp(area.left_top.x, center.x - half, center.x), y = clamp(area.left_top.y, center.y - half, center.y)},
        right_bottom = {x = clamp(area.right_bottom.x, center.x, center.x + half), y = clamp(area.right_bottom.y, center.y, center.y + half)},
    }
end

---Entity of the selection closest to the area center that matches `filter`.
local function pick_entity(surface, area, search, filter)
    search.area = area
    local center = {x = (area.left_top.x + area.right_bottom.x) / 2, y = (area.left_top.y + area.right_bottom.y) / 2}
    local best, best_distance
    for _, entity in pairs(surface.find_entities_filtered(search)) do
        if filter(entity) then
            local dist = distance(center, entity.position)
            if not best or dist < best_distance then best, best_distance = entity, dist end
        end
    end
    return best
end

local function has_item_products(resource)
    for _, product in pairs(resource.prototype.mineable_properties.products or {}) do
        if product.type == "item" then return true end
    end
    return false
end

---Hands out the drone remote for the task configured in the GUI.
function model.start_selection(player)
    local state = data().gui[player.index]
    if not state or not get_port(state.port) then return end
    local task_type = model.TASK_TYPES[state.type or 1]
    if task_type == "transfer" and not state.item then
        player.print({"exotic-industries.drone-need-item"})
        return
    end

    data().pending[player.index] = {port = state.port, type = task_type, item = state.item, priority = state.priority or 1}
    player.opened = nil
    if player.clear_cursor() then
        player.cursor_stack.set_stack({name = model.REMOTE, count = 1})
    end
    player.print({"exotic-industries.drone-select-" .. task_type})
end

---on_player_selected_area / on_player_alt_selected_area with the drone remote.
function model.on_player_selected_area(event, alt)
    if event.item ~= model.REMOTE then return end
    local player = game.get_player(event.player_index)
    local d = data()
    local pending = d.pending[event.player_index]

    local function done()
        d.pending[event.player_index] = nil
        if player.cursor_stack and player.cursor_stack.valid_for_read and player.cursor_stack.name == model.REMOTE then
            player.cursor_stack.clear()
        end
    end

    if alt or not pending then return done() end
    local port = get_port(pending.port)
    if not port then return done() end

    local surface = event.surface
    local area = event.area
    local center = {x = (area.left_top.x + area.right_bottom.x) / 2, y = (area.left_top.y + area.right_bottom.y) / 2}
    if surface.index ~= port.entity.surface.index or not in_range(port.entity, center) then
        player.print({"exotic-industries.drone-out-of-range", B.range})
        return
    end

    local force = port.entity.force
    local params = {type = pending.type, item = pending.item, priority = pending.priority}

    if pending.type == "salvage" then
        params.target = pick_entity(surface, area, {force = "neutral"}, function(entity)
            return entity.type ~= "resource" and entity.prototype.mineable_properties.minable and entity.name ~= "ei-artifact-flag"
        end)
        if not params.target then return player.print({"exotic-industries.drone-no-target"}) end

    elseif pending.type == "mine" then
        if not pending.resource then
            local resource = pick_entity(surface, area, {type = "resource"}, has_item_products)
            if not resource then return player.print({"exotic-industries.drone-no-target"}) end
            pending.resource = resource
            return player.print({"exotic-industries.drone-select-mine-container"})
        end
        params.target = pending.resource
        params.destination = pick_entity(surface, area, {type = CONTAINER_TYPES, force = force}, function() return true end)
        if not params.destination then return player.print({"exotic-industries.drone-no-target"}) end

    elseif pending.type == "transfer" then
        local container = pick_entity(surface, area, {type = CONTAINER_TYPES, force = force}, function(entity)
            return entity ~= pending.source
        end)
        if not container then return player.print({"exotic-industries.drone-no-target"}) end
        if not pending.source then
            pending.source = container
            return player.print({"exotic-industries.drone-select-transfer-destination"})
        end
        params.source, params.destination = pending.source, container

    elseif pending.type == "guard" then
        params.zone = clamp_zone(area)
    end

    for _, key in pairs({"target", "source", "destination"}) do
        if params[key] and not in_range(port.entity, params[key].position) then
            player.print({"exotic-industries.drone-out-of-range", B.range})
            return done()
        end
    end

    local task, reason = model.create_task(pending.port, params)
    done()
    if not task then return player.print({"exotic-industries." .. reason}) end
    player.print({"exotic-industries.drone-task-started"})
end

--GUI
------------------------------------------------------------------------------------------------------

local function task_caption(task)
    return {"", {"exotic-industries.drone-task-" .. task.type},
        task.item and {"", " [item=", task.item, "]"} or "",
        ": ", {"exotic-industries." .. (task.status or "drone-status-starting")}}
end

function model.close_gui(player)
    local gui = player.gui.relative[model.GUI_NAME]
    if gui then gui.destroy() end
    local state = data().gui[player.index]
    if state then state.port = nil end
end

---Relative GUI next to the container GUI of a drone port.
function model.open_gui(player, entity)
    model.close_gui(player)
    if not get_port(entity.unit_number) then model.register_port(entity) end
    local d = data()
    d.gui[player.index] = d.gui[player.index] or {type = 1, priority = 1}
    local state = d.gui[player.index]
    state.port = entity.unit_number

    local root = player.gui.relative.add{
        type = "frame", name = model.GUI_NAME, direction = "vertical", caption = {"exotic-industries.drone-gui-title"},
        anchor = {gui = defines.relative_gui_type.container_gui, position = defines.relative_gui_position.right, names = {model.PORT}},
    }
    local content = root.add{type = "frame", name = "content", direction = "vertical", style = "inside_shallow_frame_with_padding"}
    content.add{type = "label", name = "status"}

    content.add{type = "line"}
    content.add{type = "label", caption = {"exotic-industries.drone-gui-new-task"}, style = "heading_2_label"}

    local types = {}
    for _, task_type in ipairs(model.TASK_TYPES) do table.insert(types, {"exotic-industries.drone-task-" .. task_type}) end
    content.add{type = "drop-down", name = "type", items = types, selected_index = state.type,
        tags = {parent_gui = model.GUI_NAME, action = "type"}}

    local task_type = model.TASK_TYPES[state.type]
    if task_type == "transfer" then
        local flow = content.add{type = "flow", direction = "horizontal"}
        flow.add{type = "label", caption = {"exotic-industries.drone-gui-item"}}
        flow.add{type = "choose-elem-button", elem_type = "item", item = state.item,
            tags = {parent_gui = model.GUI_NAME, action = "item"}}
    elseif task_type == "guard" then
        local orders = {}
        for _, order in ipairs(model.PRIORITIES) do
            table.insert(orders, {"", {"exotic-industries.drone-class-" .. order[1]}, " > ",
                {"exotic-industries.drone-class-" .. order[2]}, " > ", {"exotic-industries.drone-class-" .. order[3]}})
        end
        content.add{type = "label", caption = {"exotic-industries.drone-gui-priority"}}
        content.add{type = "drop-down", items = orders, selected_index = state.priority,
            tags = {parent_gui = model.GUI_NAME, action = "priority"}}
        content.add{type = "label", caption = {"exotic-industries.drone-gui-zone-hint", B.max_zone_size}}
    end
    content.add{type = "label", caption = {"exotic-industries.drone-gui-hint-" .. task_type, B.range}}
    content.add{type = "button", caption = {"exotic-industries.drone-gui-select"},
        tags = {parent_gui = model.GUI_NAME, action = "select"}}

    content.add{type = "line"}
    content.add{type = "label", caption = {"exotic-industries.drone-gui-tasks"}, style = "heading_2_label"}
    content.add{type = "table", name = "tasks", column_count = 2}
    model.refresh_gui(player)
end

---Refreshes the status line and the task list of an open port GUI.
function model.refresh_gui(player)
    local root = player.gui.relative[model.GUI_NAME]
    local state = data().gui[player.index]
    local port = state and get_port(state.port)
    if not (root and port) then return end
    local content = root.content

    local energy = port.energy and port.energy.valid and port.energy.energy or 0
    local drones = port.entity.get_inventory(defines.inventory.chest).get_item_count(model.DRONE)
    content.status.caption = {"exotic-industries.drone-gui-status", drones, table_size(port.tasks),
        math.floor(energy / 1000000 * 10) / 10}

    local list = content.tasks
    list.clear()
    for task_id in pairs(port.tasks) do
        local task = data().tasks[task_id]
        if task then
            list.add{type = "label", caption = task_caption(task)}
            list.add{type = "button", caption = {"exotic-industries.drone-gui-recall"}, enabled = not task.recalled,
                tags = {parent_gui = model.GUI_NAME, action = "recall", task = task_id}}
        end
    end
end

function model.on_gui_click(event)
    local tags = event.element.tags
    local player = game.get_player(event.player_index)
    if tags.action == "select" then
        model.start_selection(player)
    elseif tags.action == "recall" then
        model.recall(tags.task)
        model.refresh_gui(player)
    end
end

function model.on_gui_selection_state_changed(event)
    local element = event.element
    local state = data().gui[event.player_index]
    if not state then return end
    if element.tags.action == "type" then
        state.type = element.selected_index
    elseif element.tags.action == "priority" then
        state.priority = element.selected_index
        return
    else
        return
    end
    local port = get_port(state.port)
    if port then model.open_gui(game.get_player(event.player_index), port.entity) end
end

function model.on_gui_elem_changed(event)
    local state = data().gui[event.player_index]
    if state and event.element.tags.action == "item" then
        state.item = event.element.elem_value
    end
end

--HANDLERS
------------------------------------------------------------------------------------------------------

function model.on_built_entity(entity)
    if entity.name == model.PORT then model.register_port(entity) end
end

function model.on_destroyed_entity(entity)
    if entity.name == model.PORT and entity.unit_number then model.unregister_port(entity.unit_number) end
end

---Clones: hidden power interfaces are recreated by the cloned port (tasks are not cloned).
function model.on_entity_cloned(destination)
    if destination.name == model.ENERGY then
        destination.destroy()
    elseif destination.name == model.PORT then
        model.register_port(destination)
    end
end

return model
