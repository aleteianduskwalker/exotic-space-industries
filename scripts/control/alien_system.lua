--====================================================================================================
-- ALIEN SYSTEM (alien tech tree + artifact repair / salvage)
--====================================================================================================
-- Currency: "alien knowledge" points per force.
--   * repairing an alien artifact with a repair kit: balance.alien_points_per_repair
--   * 3.2.0: mining / deconstructing / destroying a broken artifact on Gaia:
--     balance.alien_points_per_salvage (10 % of a repair)
--   No points are granted anymore once every node of the tree is unlocked.
-- Points are spent in the alien tech tree (lib/alien_tree.lua), shown on the InformaTron page
-- "alien" (scripts/control/informatron.lua -> model.alien).
--
-- PAYMENT (3.2.0): the point cost of a node is paid in this priority:
--   1) alien knowledge points
--   2) ei-alien-resonance-pack from the main inventory (1 pack = 10 points, surplus is refunded as points)
--   3) ei-resonance-data from the main inventory (10 data = 1 point)
-- Explicit item costs of a node (tier 4/5) are reserved first and never used as currency.
--
-- RULES
--   * 3.2.0: nodes are bought near an alien terminal of the own force (scripts/control/alien_console.lua);
--     only nodes with `anywhere` (the terminal node) can be bought everywhere
--   * tier k+1 opens when every node of tier k is unlocked (any number of tiers)
--   * a node may require other nodes of its row (node.prerequisites)
--   * 3.2.0: every prerequisite technology of the node's technology must be researched
--     (the anchor technology "resonance synthesizer" for almost every node)
--   * a node whose technology is already researched counts as unlocked automatically
--
-- storage.ei.alien[force_name] = {
--     alien   = number        current points
--     unlocks = {{name, unlocked, tier}}
--     tier_<k> = boolean       tier k open?
-- }
--====================================================================================================

local ei_data = require("lib/data")
local ei_balance = require("lib/balance")
local alien_tree = require("lib/alien_tree")

local model = {}

local PACK = "ei-alien-resonance-pack"
local DATA = "ei-resonance-data"

-- kept as a field: other modules and old code read model.tech_tree
model.tech_tree = alien_tree.tiers
model.repair_tools = ei_data.repair_tools

-- broken artifact entity name -> true (the repair tool targets)
local BROKEN_ARTIFACTS = {}
for _, tool in pairs(ei_data.repair_tools) do
    for entity_name, _ in pairs(tool.targets) do
        BROKEN_ARTIFACTS[entity_name] = true
    end
end

--UTIL
------------------------------------------------------------------------------------------------------

local for_each_node = alien_tree.for_each_node
local find_node = alien_tree.find_node

function model.check_init()
    if not storage.ei.alien then
        storage.ei.alien = {}
    end
end

function model.entity_check(entity)
    return entity ~= nil and entity.valid
end

---Returns the alien data of a force (nil while the force has not gained any alien knowledge).
---@param force LuaForce
function model.get_force_data(force)
    return storage.ei.alien and storage.ei.alien[force.name]
end

---Enables the alien system for a force (first repaired / salvaged artifact). Idempotent.
---Accepts an entity (old signature) or a force.
---@param source LuaEntity|LuaForce
function model.enable_alien(source)
    local force = source.object_name == "LuaForce" and source or source.force
    model.check_init()

    if storage.ei.alien[force.name] then return end

    storage.ei.alien[force.name] = {alien = 0, unlocks = {}, tier_1 = true}
    model.migrate_force(force.name)
    model.sync_researched(force)
end

---Brings the stored unlock list of a force in line with the current tree:
---adds missing nodes (new tiers of a mod update), refreshes their tier, drops removed nodes and
---recalculates the tier flags.
---@param force_name string
function model.migrate_force(force_name)
    local data = storage.ei.alien[force_name]
    if not data then return end

    local old = {}
    for _, unlock in ipairs(data.unlocks or {}) do
        old[unlock.name] = unlock.unlocked
    end

    data.unlocks = {}
    for_each_node(function(node, tier)
        table.insert(data.unlocks, {name = node.name, unlocked = old[node.name] == true, tier = tier})
    end)

    data.alien = data.alien or 0
    model.recalculate_tiers(force_name)
end

---3.2.0: technologies became script-only. A force that already owns every recipe of a node's
---technology (e.g. the conduit that was unlocked with Gaia before) gets the technology researched,
---so an update never takes anything away.
---@param force LuaForce
local function grandfather_technologies(force)
    for_each_node(function(node)
        local technology = force.technologies[node.meta]
        if not technology or technology.researched then return end

        local has_recipes = false
        for _, effect in pairs(technology.prototype.effects) do
            if effect.type == "unlock-recipe" then
                local recipe = force.recipes[effect.recipe]
                if not (recipe and recipe.enabled) then return end
                has_recipes = true
            end
        end
        if has_recipes then
            technology.researched = true
        end
    end)
end

---Idempotent migration of all forces (on_configuration_changed).
function model.migrate()
    model.check_init()
    for _, force in pairs(game.forces) do
        if force.name ~= "enemy" and force.name ~= "neutral" then
            grandfather_technologies(force)
        end
    end
    for force_name in pairs(storage.ei.alien) do
        model.migrate_force(force_name)
        local force = game.forces[force_name]
        if force then model.sync_researched(force) end
    end

    -- 3.2.0: forces that already used the tree (bought anywhere before) get the alien terminal
    if not storage.ei.alien_console_migrated then
        storage.ei.alien_console_migrated = true
        for force_name in pairs(storage.ei.alien) do
            local force = game.forces[force_name]
            local technology = force and force.technologies["ei-alien-console"]
            if technology and not technology.researched then
                technology.researched = true
            end
        end
    end
end

---Returns true if every node of the tree is unlocked for the force.
---@param force LuaForce
function model.is_tree_complete(force)
    local data = model.get_force_data(force)
    if not data then return false end
    for _, unlock in ipairs(data.unlocks) do
        if not unlock.unlocked then return false end
    end
    return true
end

---Adds alien knowledge points to a force. Returns false (nothing added) once the tree is complete.
---@param force LuaForce
---@param amount number
---@return boolean added
function model.add_alien(force, amount)
    model.enable_alien(force)
    if model.is_tree_complete(force) then
        return false
    end
    local data = model.get_force_data(force)
    data.alien = data.alien + amount
    return true
end

--STATE
------------------------------------------------------------------------------------------------------

function model.get_total_height(row_data)
    local height = 0
    for _, node in ipairs(row_data) do
        if node.height and node.height > height then
            height = node.height
        end
    end
    return height
end

---Sprite of a tree button: the hand made "ei-knowledge-<name>" sprite if it exists, otherwise the
---icon of the node technology.
function model.get_button_sprite(node)
    local sprite = "ei-knowledge-" .. node.name
    if helpers.is_valid_sprite_path(sprite) then
        return sprite
    end
    return "technology/" .. node.meta
end

---Prerequisite technologies of the node technology that are not researched yet.
---@param node table
---@param force LuaForce
---@return string[]
local function missing_technologies(node, force)
    local missing = {}
    local technology = force.technologies[node.meta]
    if not technology then return missing end

    for name, prerequisite in pairs(technology.prerequisites) do
        if not prerequisite.researched then
            table.insert(missing, name)
        end
    end
    table.sort(missing)
    return missing
end

---Tooltip: technology name, costs, payment hint and missing technologies.
local function get_button_tooltip(node, force)
    local tooltip = {"", {"technology-name." .. node.meta}, "\n", {"exotic-industries-informatron.alien-cost", node.cost}}
    for _, item in ipairs(node.items or {}) do
        table.insert(tooltip, {"", "\n", {"exotic-industries-informatron.alien-cost-item", item.count, item.name}})
    end
    for _, technology in ipairs(missing_technologies(node, force)) do
        table.insert(tooltip, {"", "\n", {"exotic-industries-informatron.alien-requires-technology", technology}})
    end
    return tooltip
end

function model.get_button_tags(node)
    return {
        cost = node.cost,
        action = "select-alien",
        name = node.name,
        type = node.type,
        parent_gui = "ei-alien-gui",
        meta = node.meta,
        prerequisites = node.prerequisites,
        items = node.items,
        anywhere = node.anywhere,
    }
end

function model.apply_effects(tags, force)
    local technology = force.technologies[tags.meta]
    if technology then
        technology.researched = true
        force.print({"exotic-industries.tech-researched", tags.meta}) -- [technology=__1__] rich text
    end
end

function model.is_unlocked(name, force)
    force = force or game.forces["player"]
    local data = model.get_force_data(force)
    if not data then return false end

    for _, unlock in ipairs(data.unlocks) do
        if unlock.name == name then return unlock.unlocked end
    end
    return false
end

function model.set_unlocked(name, force, state)
    force = force or game.forces["player"]
    if state == nil then state = true end
    local data = model.get_force_data(force)
    if not data then return false end

    for _, unlock in ipairs(data.unlocks) do
        if unlock.name == name then
            unlock.unlocked = state
            return true
        end
    end
    return false
end

---Marks nodes as unlocked whose technology was already researched (e.g. by a command or an older
---version of the mod), so no points are wasted on them, and recalculates the tiers.
---@param force LuaForce
function model.sync_researched(force)
    local data = model.get_force_data(force)
    if not data then return end

    for_each_node(function(node)
        local technology = node.meta and force.technologies[node.meta]
        if technology and technology.researched then
            model.set_unlocked(node.name, force, true)
        end
    end)
    model.recalculate_tiers(force.name)
end

function model.get_prerequisites(name)
    local node = find_node(name)
    return node and node.prerequisites or nil
end

function model.get_tier(name)
    local tier_of = 1
    for_each_node(function(node, tier) if node.name == name then tier_of = tier end end)
    return "tier_" .. tier_of
end

---"green" unlocked, "grey" can be unlocked, "red" locked (tier, prerequisites or technologies missing).
function model.get_unlocked_state(name, force)
    force = force or game.forces["player"]
    local data = model.get_force_data(force)
    if not data then return "red" end

    if model.is_unlocked(name, force) then return "green" end

    -- tier not open yet (missing flag = closed)
    if data[model.get_tier(name)] ~= true then return "red" end

    for _, prerequisite in ipairs(model.get_prerequisites(name) or {}) do
        if not model.is_unlocked(prerequisite, force) then return "red" end
    end

    local node = find_node(name)
    if node and #missing_technologies(node, force) > 0 then return "red" end

    return "grey"
end

---Tier k+1 opens when every node of tier k is unlocked (works for any number of tiers).
---@param force_name string
function model.recalculate_tiers(force_name)
    local data = storage.ei.alien and storage.ei.alien[force_name]
    if not data then return end

    local complete = {}
    for tier = 1, #alien_tree.tiers do complete[tier] = true end
    for _, unlock in ipairs(data.unlocks) do
        if not unlock.unlocked then complete[unlock.tier] = false end
    end

    data.tier_1 = true
    for tier = 2, #alien_tree.tiers do
        data["tier_" .. tier] = data["tier_" .. (tier - 1)] and complete[tier - 1] or false
    end
end

---Kept for compatibility (old name), recalculates the tiers of the player's force.
function model.update_tier_status(player_index)
    model.recalculate_tiers(game.get_player(player_index).force.name)
end

--PAYMENT
------------------------------------------------------------------------------------------------------

---Computes how the cost of a node would be paid by a player (priority: points -> packs -> data).
---@param player LuaPlayer
---@param node table node or button tags ({cost, items})
---@return table|nil plan {points, packs, data, change}, or nil
---@return string|nil reason locale key of [exotic-industries] when the node can not be paid
function model.payment_plan(player, node)
    local data = model.get_force_data(player.force)
    if not data then return nil, "not-enough-alien" end

    -- explicit item costs are reserved first
    local reserved = {}
    for _, item in ipairs(node.items or {}) do
        reserved[item.name] = (reserved[item.name] or 0) + item.count
    end
    for name, count in pairs(reserved) do
        if player.get_item_count(name) < count then
            return nil, "not-enough-alien-items"
        end
    end

    local need = node.cost
    local plan = {points = math.min(data.alien, need), packs = 0, data = 0, change = 0}
    need = need - plan.points

    -- 2) alien resonance packs (the surplus of the last pack is refunded as points)
    if need > 0 then
        local pack_value = ei_balance.alien_points_per_resonance_pack
        local available = math.max(0, player.get_item_count(PACK) - (reserved[PACK] or 0))
        plan.packs = math.min(available, math.ceil(need / pack_value))
        local paid = plan.packs * pack_value
        plan.change = math.max(0, paid - need)
        need = math.max(0, need - paid)
    end

    -- 3) resonance data
    if need > 0 then
        local available = math.max(0, player.get_item_count(DATA) - (reserved[DATA] or 0))
        local required = math.ceil(need * ei_balance.resonance_data_per_alien_point)
        if available < required then
            return nil, "not-enough-alien"
        end
        plan.data = required
    end

    return plan
end

---Checks the payment; prints the reason and returns nil if the node can not be paid.
local function can_pay(player, tags)
    local plan, reason = model.payment_plan(player, tags)
    if not plan then
        player.print({"exotic-industries." .. reason})
    end
    return plan
end

---Consumes points and items of a payment plan (plus the explicit item costs of the node).
local function pay(player, tags, plan)
    local data = model.get_force_data(player.force)
    data.alien = data.alien - plan.points + plan.change
    if plan.packs > 0 then player.remove_item({name = PACK, count = plan.packs}) end
    if plan.data > 0 then player.remove_item({name = DATA, count = plan.data}) end
    for _, item in ipairs(tags.items or {}) do
        player.remove_item({name = item.name, count = item.count})
    end
end

--UNLOCKING LOGIC
------------------------------------------------------------------------------------------------------

function model.try_select_alien(player, tags)
    if model.get_unlocked_state(tags.name, player.force) ~= "grey" then return end
    if not ei_alien_console.check_access(player, tags) then return end
    local plan = can_pay(player, tags)
    if not plan then return end

    model.make_confirm_gui(player, tags, plan, model.get_force_data(player.force).alien)
end

---Confirm dialog: shows the node cost and exactly what will be consumed.
function model.make_confirm_gui(player, tags, plan, balance)
    local screen_gui = player.gui.screen
    if screen_gui["ei-alien-confirm-console"] then
        screen_gui["ei-alien-confirm-console"].destroy()
    end

    local root = screen_gui.add{type = "frame", name = "ei-alien-confirm-console", direction = "vertical"}
    local main_container = root.add{type = "frame", name = "main-container", direction = "vertical", style = "inside_shallow_frame"}

    main_container.add{type = "frame", style = "ei-subheader-frame"}.add{
        type = "label",
        caption = {"exotic-industries.alien-confirm-gui-title"},
        style = "subheader_caption_label",
    }

    local content_flow = main_container.add{type = "flow", name = "control-flow", direction = "vertical", style = "ei-inner-content-flow"}
    content_flow.add{type = "label", caption = {"exotic-industries.alien-confirm-gui-label", tags.cost}}
    for _, item in ipairs(tags.items or {}) do
        content_flow.add{type = "label", caption = {"exotic-industries-informatron.alien-cost-item", item.count, item.name}}
    end

    -- payment breakdown (points -> packs -> data)
    content_flow.add{type = "label", caption = {"exotic-industries.alien-confirm-gui-pay-points", plan.points}}
    if plan.packs > 0 then
        content_flow.add{type = "label", caption = {"exotic-industries.alien-confirm-gui-pay-packs", plan.packs}}
    end
    if plan.data > 0 then
        content_flow.add{type = "label", caption = {"exotic-industries.alien-confirm-gui-pay-data", plan.data}}
    end
    if plan.change > 0 then
        content_flow.add{type = "label", caption = {"exotic-industries.alien-confirm-gui-change", plan.change}}
    end
    content_flow.add{type = "label", caption = {"exotic-industries.alien-confirm-gui-label-2", balance}}

    local button_flow = content_flow.add{type = "flow", name = "button-flow", direction = "horizontal"}
    button_flow.add{
        type = "button",
        name = "confirm-button",
        caption = {"exotic-industries.alien-confirm-gui-button", {"gui.confirm"}},
        style = "ei-small-green-button",
        tags = {action = "confirm-alien", parent_gui = "ei-alien-gui", tags = tags},
    }
    button_flow.add{
        type = "button",
        name = "exit-button",
        caption = {"exotic-industries.alien-confirm-gui-button", {"gui.cancel"}},
        style = "ei-small-red-button",
        tags = {action = "exit-alien", parent_gui = "ei-alien-gui", tags = tags},
    }

    root.bring_to_front()
    root.force_auto_center()
end

function model.select_alien(player, tags)
    model.exit_confirm(player)

    local node = tags.tags
    -- re-validate: the state and the inventory may have changed while the dialog was open
    if model.get_unlocked_state(node.name, player.force) ~= "grey" then return end
    if not ei_alien_console.check_access(player, node) then return end
    local plan = can_pay(player, node)
    if not plan then return end

    pay(player, node, plan)
    model.set_unlocked(node.name, player.force, true)
    model.apply_effects(node, player.force)
    model.recalculate_tiers(player.force.name)
    model.update_informatron(player)
end

function model.exit_confirm(player)
    local screen_gui = player.gui.screen
    if screen_gui["ei-alien-confirm-console"] then
        screen_gui["ei-alien-confirm-console"].destroy()
    end
end

---"Dirty" reload of the InformaTron alien page.
function model.update_informatron(player)
    if not remote.interfaces["informatron"] then return end

    if player.gui.screen["informatron"] then
        player.gui.screen["informatron"].destroy()
    end

    remote.call("informatron", "informatron_open_to_page", {
        player_index = player.index,
        interface = "exotic-industries-informatron",
        page_name = "alien",
    })
end

--INFORMATRON PAGE
------------------------------------------------------------------------------------------------------

---Builds the alien page: balance header + all tiers with their buttons.
---@param player_index integer
---@param element LuaGuiElement
-- first tier drawn on the deep space background
local DEEP_SPACE_TIER = 4

function model.make_tiers(player_index, element)
    local player = game.get_player(player_index)
    local force = player.force
    local data = model.get_force_data(force)

    if not data then
        element.add{type = "label", caption = {"exotic-industries-informatron.alien-locked-hint"}}
        return
    end

    model.sync_researched(force)
    element.add{type = "label", caption = {"exotic-industries-informatron.alien-balance", data.alien}, style = "heading_2_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.alien-balance-items",
        player.get_item_count(PACK), player.get_item_count(DATA)}}
    -- 3.2.0: nodes are bought at an alien terminal
    local near = ei_alien_console.find_near(player) ~= nil
    element.add{type = "label", caption = {"exotic-industries-informatron.alien-console-" .. (near and "near" or "far"),
        ei_balance.alien_console.range}}

    for tier, tier_data in ipairs(alien_tree.tiers) do
        local tier_flow = element.add{
            type = "flow",
            name = "tier-flow_" .. tier,
            direction = "vertical",
            style = "ei-inner-content-flow-vertical-centered",
        }

        tier_flow.add{type = "frame", style = "ei-subheader-frame-with-top-border"}.add{
            type = "label",
            caption = {"exotic-industries-informatron.tier", tier},
            style = "subheader_caption_label",
        }

        -- 3.2.0: every tier sits in a space frame (deep space for tiers 4 and 5)
        local space_frame = tier_flow.add{
            type = "frame",
            name = "space-frame",
            direction = "vertical",
            style = tier >= DEEP_SPACE_TIER and "ei-deep-space-frame" or "ei-space-frame",
        }
        local row_flow = space_frame.add{type = "flow", name = "row-flow", direction = "horizontal"}

        -- Tier: |row 1|row 2|row 3|, a row stacks its nodes by height
        for row, row_data in ipairs(tier_data) do
            local inner_row_flow = row_flow.add{
                type = "flow",
                name = "inner-row-flow_" .. row,
                direction = "vertical",
                style = "ei-inner-content-flow-vertical-centered",
            }

            for height = 1, model.get_total_height(row_data) do
                local holder = inner_row_flow.add{
                    type = "flow",
                    name = "inner_row_flow_" .. row .. "_" .. height,
                    direction = "horizontal",
                    style = "ei-inner-content-flow-horizontal-centered",
                }

                for _, node in ipairs(row_data) do
                    if node.height == height then
                        holder.add{
                            type = "sprite-button",
                            sprite = model.get_button_sprite(node),
                            tooltip = get_button_tooltip(node, force),
                            tags = model.get_button_tags(node),
                            style = "ei-alien-sprite-button-" .. model.get_unlocked_state(node.name, force),
                        }
                    end
                end
            end
        end
    end
end

--ARTIFACT INTERACTION
------------------------------------------------------------------------------------------------------

---Spills the resonance data reward of a repaired artifact around it (design doc §9).
local function spill_resonance_data(entity)
    local drop = ei_balance.resonance_data_repair_drop
    entity.surface.spill_item_stack{
        position = entity.position,
        stack = {name = DATA, count = math.random(drop.min, drop.max)},
        enable_looted = true,
        allow_belts = false,
        max_radius = 2.5,
    }
end

---Shows "+N alien knowledge" above a position for one force.
function model.show_points(surface, position, force, amount)
    rendering.draw_text{
        text = {"exotic-industries.alien-knowledge-flying-text", amount},
        surface = surface,
        target = position,
        color = {r = 0.6, g = 0.4, b = 1},
        scale = 1.2,
        alignment = "center",
        forces = {force},
        time_to_live = 120,
    }
end

function model.repair_artifact(event)
    local item = event.item
    local player = game.get_player(event.player_index)

    for _, entity in ipairs(event.entities) do
        if entity.valid and model.repair_tools[item].targets[entity.name] then

            -- spawn repaired entity and destroy old one
            local tool = model.repair_tools[item]
            local surface = entity.surface
            local position = entity.position
            -- alien knowledge goes to the repairing player's force (artifacts are neutral)
            local reward_force = player and player.force or game.forces["player"]
            -- 3.2.0: some repaired artifacts (alien terminal) belong to the repairing force
            local force = tool.own_force and reward_force or entity.force
            entity.destroy()

            local new_entity = surface.create_entity{
                name = tool.result,
                position = position,
                force = force,
                raise_built = false,
            }

            -- consume the repair tool (it should be in the cursor stack)
            local cursor_stack = player and player.cursor_stack
            if cursor_stack and cursor_stack.valid_for_read and cursor_stack.name == item then
                cursor_stack.clear()
            end

            if new_entity and new_entity.valid then
                spill_resonance_data(new_entity)
                -- repaired structures on Gaia turn into their Gaia variant
                ei_gaia.swap_entity(new_entity)
            end
            -- repaired terminal: registration + one-time knowledge bonus
            if new_entity and new_entity.valid and new_entity.name == ei_alien_console.NAME then
                ei_alien_console.on_repaired(new_entity, reward_force)
            end

            if model.add_alien(reward_force, ei_balance.alien_points_per_repair) then
                reward_force.print({"exotic-industries.alien-knowledge-gained", ei_balance.alien_points_per_repair})
            end

            ei_victory.count_value("artifacts_repaired", 1)
            return
        end
    end
end

---3.2.0: a broken artifact on Gaia was mined, deconstructed or destroyed by a force: grants
---10 % of the repair reward (the resources themselves come from minable results / loot).
---@param entity LuaEntity the broken artifact (still valid)
---@param force LuaForce|nil the salvaging force
function model.on_artifact_salvaged(entity, force)
    if not (entity and entity.valid and BROKEN_ARTIFACTS[entity.name]) then return end
    if not (force and force.valid) or force.name == "enemy" or force.name == "neutral" then return end
    if not ei_gaia.is_gaia_surface(entity.surface) then return end

    local amount = ei_balance.alien_points_per_salvage
    if model.add_alien(force, amount) then
        model.show_points(entity.surface, entity.position, force, amount)
    end
end

--HANDLERS
------------------------------------------------------------------------------------------------------

---Opens the InformaTron on the alien page (e.g. from an entity GUI).
function model.swap_gui(player)
    if player.opened_gui_type == defines.gui_type.entity and player.opened then
        player.opened = nil
    end
    model.update_informatron(player)
end

function model.on_gui_click(event)
    local tags = event.element.tags
    local player = game.get_player(event.player_index)

    if tags.action == "select-alien" then
        model.try_select_alien(player, tags)
    elseif tags.action == "confirm-alien" then
        model.select_alien(player, tags)
    elseif tags.action == "exit-alien" then
        model.exit_confirm(player)
    end
end

function model.on_player_selected_area(event)
    if model.repair_tools[event.item] then
        model.repair_artifact(event)
    end
end

---A technology of a tree node researched (by the tree or a command) marks the node as unlocked.
function model.on_research_finished(event)
    local force = event.research.force
    if model.get_force_data(force) then
        model.sync_researched(force)
    end
end

---on_player_mined_entity / on_robot_mined_entity (after a successful mining action).
function model.on_mined_entity(event)
    local force
    if event.player_index then
        local player = game.get_player(event.player_index)
        force = player and player.force
    elseif event.robot and event.robot.valid then
        force = event.robot.force
    end
    model.on_artifact_salvaged(event.entity, force)
end

---on_entity_died: `force` is the force that killed the entity (nil for e.g. lightning).
function model.on_entity_died(event)
    model.on_artifact_salvaged(event.entity, event.force)
end

return model
