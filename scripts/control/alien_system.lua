--====================================================================================================
-- ALIEN SYSTEM (alien tech tree + artifact repair)
--====================================================================================================
-- Currency: "alien knowledge" points per force, earned by repairing alien artifacts with the
-- repair kits (model.repair_artifact). Points are spent in the alien tech tree, shown on the
-- InformaTron page "alien" (scripts/control/informatron.lua -> model.alien).
--
-- TREE (model.tech_tree): tier -> row -> node. A node:
--   type   "tech" | "part" | "schematic"  (only "tech" is used, the others are legacy)
--   name   unique node name, also the button sprite suffix "ei_knowledge-<name>"
--   cost   alien knowledge points
--   items  optional {{name, count}} additionally taken from the player's main inventory
--   height row height (nodes with prerequisites inside the same row sit lower)
--   meta   technology that gets researched when the node is unlocked
--   prerequisites optional list of node names
-- Tiers 1-3 reactivate the author's commented nodes; tier 4/5 are new (design doc §4).
-- Every node of tier k must be unlocked before tier k+1 opens (any number of tiers).
-- A node whose technology was already researched in a lab counts as unlocked automatically.
--
-- storage.ei.alien[force_name] = {
--     alien   = number        current points
--     unlocks = {{name, unlocked, tier}}
--     tier_<k> = boolean       tier k open?
-- }
--====================================================================================================

local ei_data = require("lib/data")
local ei_balance = require("lib/balance")

local model = {}

---Shorthand for a "tech" node.
local function tech(name, cost, meta, height, prerequisites, items)
    return {type = "tech", name = name, cost = cost, meta = meta, height = height or 1,
            prerequisites = prerequisites, items = items}
end

local tier4 = ei_balance.alien_tech_tier4_cost
local tier5 = ei_balance.alien_tech_tier5_cost

model.tech_tree = {
    -- tier 1: basics + automated resonance data (design doc §3: unlocked in tier 1, not tier 4)
    {
        {tech("gate", 100, "ei-gate")},
        {tech("bio-chamber", 100, "ei-bio-chamber")},
        {tech("crystal-accumulator-repair", 100, "ei-crystal-accumulator-repair")},
        {tech("resonance-synthesizer", 100, "ei-resonance-synthesizer")},
    },
    -- tier 2: bio branch
    {
        {
            tech("bio_insulated-wire", 200, "ei-bio-insulated-wire"),
            tech("bio_electronic-parts", 300, "ei-bio-electronic-parts", 2, {"bio_insulated-wire"}),
        },
        {
            tech("bio_energy-crystal", 200, "ei-bio-energy-crystal"),
            tech("bio_high-energy-crystal", 300, "ei-bio-high-energy-crystal", 2, {"bio_energy-crystal"}),
        },
        {
            tech("bio_hydrofluoric-acid", 200, "ei-bio-hydrofluoric-acid"),
            tech("bio_nitric-acid", 300, "ei-bio-nitric-acid", 2, {"bio_hydrofluoric-acid"}),
        },
        {tech("farstation-repair", 300, "ei-farstation-repair")},
    },
    -- tier 3: old goals
    {
        {tech("alien-beacon-repair", 2000, "ei-alien-beacon-repair")},
        {tech("farstation", 1000, "ei-farstation")},
        {tech("bio_carbon-structure", 500, "ei-bio-carbon-structure")},
        {tech("bio_magnet", 500, "ei-bio-magnet")},
        {tech("bio_rocket-fuel", 500, "ei-bio-rocket-fuel")},
    },
    -- tier 4 (new): Resonant Computation - resonance pack recipe + underground data cable
    {
        {tech("resonant-computation", tier4.points, "ei-resonant-computation", 1, nil, tier4.items)},
    },
    -- tier 5 (new): Threshold Engineering - void rift generator
    {
        {tech("threshold-engineering", tier5.points, "ei-threshold-engineering", 1, nil, tier5.items)},
    },
}

model.repair_tools = ei_data.repair_tools

--UTIL
------------------------------------------------------------------------------------------------------

---Calls fn(node, tier_index) for every node of the tree.
local function for_each_node(fn)
    for tier, tier_data in ipairs(model.tech_tree) do
        for _, row_data in ipairs(tier_data) do
            for _, node in ipairs(row_data) do
                fn(node, tier)
            end
        end
    end
end

---Returns the node with the given name (or nil).
local function find_node(name)
    local found
    for_each_node(function(node) if node.name == name then found = node end end)
    return found
end

function model.check_init()
    if not storage.ei.alien then
        storage.ei.alien = {}
    end
end

function model.entity_check(entity)
    return entity ~= nil and entity.valid
end

---Returns the alien data of a force (nil while the force has not repaired any artifact).
---@param force LuaForce
function model.get_force_data(force)
    return storage.ei.alien and storage.ei.alien[force.name]
end

---Enables the alien system for a force (first repaired artifact). Idempotent.
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
---recalculates the tier flags. Fixes the old hardcoded "3 tiers" limitation.
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

---Idempotent migration of all forces (on_configuration_changed).
function model.migrate()
    model.check_init()
    for force_name in pairs(storage.ei.alien) do
        model.migrate_force(force_name)
        local force = game.forces[force_name]
        if force then model.sync_researched(force) end
    end
end

---Adds alien knowledge points to a force.
---@param force LuaForce
---@param amount number
function model.add_alien(force, amount)
    model.enable_alien(force)
    local data = model.get_force_data(force)
    data.alien = data.alien + amount
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

---Sprite of a tree button. NOTE: the sprites are named "ei_knowledge-<name>"
---(prototypes/informatron_sprites.lua); the former "ei-alien-<name>" sprites never existed.
function model.get_button_sprite(node)
    if node.type == "part" then return "ei_part" end
    if node.type == "schematic" then return "ei_schematic" end
    return "ei_knowledge-" .. node.name
end

---Tooltip: technology name, point cost and item costs.
local function get_button_tooltip(node)
    local tooltip = {"", {"technology-name." .. node.meta}, "\n", {"exotic-industries-informatron.alien-cost", node.cost}}
    for _, item in ipairs(node.items or {}) do
        table.insert(tooltip, {"", "\n", {"exotic-industries-informatron.alien-cost-item", item.count, item.name}})
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
    }
end

function model.apply_effects(tags, force)
    if tags.type == "schematic" then
        force.print({"exotic-industries.schematic-researched", tags.name})
    elseif tags.type == "part" then
        force.print({"exotic-industries.part-researched", tags.name})
    elseif tags.type == "tech" then
        local technology = force.technologies[tags.meta]
        if technology then
            technology.researched = true
            force.print({"exotic-industries.tech-researched", tags.meta}) -- [technology=__1__] rich text
        end
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

---Marks nodes as unlocked whose technology was already researched (e.g. in a lab), so no points
---are wasted on them, and recalculates the tiers.
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

---"green" unlocked, "grey" can be unlocked, "red" locked (tier or prerequisites missing).
function model.get_unlocked_state(name, force)
    force = force or game.forces["player"]
    local data = model.get_force_data(force)
    if not data then return "red" end

    if model.is_unlocked(name, force) then return "green" end

    -- tier not open yet (missing flag = closed; the old code treated nil as open)
    if data[model.get_tier(name)] ~= true then return "red" end

    for _, prerequisite in ipairs(model.get_prerequisites(name) or {}) do
        if not model.is_unlocked(prerequisite, force) then return "red" end
    end

    return "grey"
end

---Tier k+1 opens when every node of tier k is unlocked (works for any number of tiers).
---@param force_name string
function model.recalculate_tiers(force_name)
    local data = storage.ei.alien and storage.ei.alien[force_name]
    if not data then return end

    local complete = {}
    for tier = 1, #model.tech_tree do complete[tier] = true end
    for _, unlock in ipairs(data.unlocks) do
        if not unlock.unlocked then complete[unlock.tier] = false end
    end

    data.tier_1 = true
    for tier = 2, #model.tech_tree do
        data["tier_" .. tier] = data["tier_" .. (tier - 1)] and complete[tier - 1] or false
    end
end

---Kept for compatibility (old name), recalculates the tiers of the player's force.
function model.update_tier_status(player_index)
    model.recalculate_tiers(game.get_player(player_index).force.name)
end

--UNLOCKING LOGIC
------------------------------------------------------------------------------------------------------

---Returns true if the player carries all item costs of a node.
local function has_items(player, items)
    for _, item in ipairs(items or {}) do
        if player.get_item_count(item.name) < item.count then return false end
    end
    return true
end

---Checks points and items; prints the reason and returns false if the node can not be paid.
local function can_pay(player, tags)
    local data = model.get_force_data(player.force)
    if not data then return false end

    if data.alien < tags.cost then
        player.print({"exotic-industries.not-enough-alien"})
        return false
    end
    if not has_items(player, tags.items) then
        player.print({"exotic-industries.not-enough-alien-items"})
        return false
    end
    return true
end

function model.try_select_alien(player, tags)
    if model.get_unlocked_state(tags.name, player.force) ~= "grey" then return end
    if not can_pay(player, tags) then return end

    model.make_confirm_gui(player, tags, model.get_force_data(player.force).alien)
end

-- Maybe turn this into a generic confirm gui?
function model.make_confirm_gui(player, tags, balance)
    local screen_gui = player.gui.screen
    if screen_gui["ei-alien-confirm-console"] then
        screen_gui["ei-alien-confirm-console"].destroy()
    end

    local root = screen_gui.add{type = "frame", name = "ei-alien-confirm-console", direction = "vertical"}
    local main_container = root.add{type = "frame", name = "main-container", direction = "vertical", style = "inside_shallow_frame"}

    main_container.add{type = "frame", style = "ei_subheader_frame"}.add{
        type = "label",
        caption = {"exotic-industries.alien-confirm-gui-title"},
        style = "subheader_caption_label",
    }

    local content_flow = main_container.add{type = "flow", name = "control-flow", direction = "vertical", style = "ei_inner_content_flow"}
    content_flow.add{type = "label", caption = {"exotic-industries.alien-confirm-gui-label", tags.cost}}
    for _, item in ipairs(tags.items or {}) do
        content_flow.add{type = "label", caption = {"exotic-industries-informatron.alien-cost-item", item.count, item.name}}
    end
    content_flow.add{type = "label", caption = {"exotic-industries.alien-confirm-gui-label-2", balance}}

    local button_flow = content_flow.add{type = "flow", name = "button-flow", direction = "horizontal"}
    button_flow.add{
        type = "button",
        name = "confirm-button",
        caption = {"exotic-industries.alien-confirm-gui-button", "Confirm"},
        style = "ei_small_green_button",
        tags = {action = "confirm-alien", parent_gui = "ei-alien-gui", tags = tags},
    }
    button_flow.add{
        type = "button",
        name = "exit-button",
        caption = {"exotic-industries.alien-confirm-gui-button", "Cancel"},
        style = "ei_small_red_button",
        tags = {action = "exit-alien", parent_gui = "ei-alien-gui", tags = tags},
    }

    root.bring_to_front()
    root.force_auto_center()
end

function model.select_alien(player, tags)
    model.exit_confirm(player)

    local node = tags.tags
    -- re-validate: the state may have changed while the confirm dialog was open
    if model.get_unlocked_state(node.name, player.force) ~= "grey" then return end
    if not can_pay(player, node) then return end

    local data = model.get_force_data(player.force)
    data.alien = data.alien - node.cost
    for _, item in ipairs(node.items or {}) do
        player.remove_item({name = item.name, count = item.count})
    end

    model.set_unlocked(node.name, player.force, true)
    model.apply_effects(node, player.force)
    model.recalculate_tiers(player.force.name) -- was never called before: tier 2+ stayed closed
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
function model.make_tiers(player_index, element)
    local force = game.get_player(player_index).force
    local data = model.get_force_data(force)

    if not data then
        element.add{type = "label", caption = {"exotic-industries-informatron.alien-locked-hint"}}
        return
    end

    model.sync_researched(force)
    element.add{type = "label", caption = {"exotic-industries-informatron.alien-balance", data.alien}, style = "heading_2_label"}

    for tier, tier_data in ipairs(model.tech_tree) do
        local tier_flow = element.add{
            type = "flow",
            name = "tier-flow_" .. tier,
            direction = "vertical",
            style = "ei_inner_content_flow_vertical_centered",
        }

        tier_flow.add{type = "frame", style = "ei_subheader_frame_with_top_border"}.add{
            type = "label",
            caption = {"exotic-industries-informatron.tier", tier},
            style = "subheader_caption_label",
        }

        local row_flow = tier_flow.add{type = "flow", name = "row-flow", direction = "horizontal"}

        -- Tier: |row 1|row 2|row 3|, a row stacks its nodes by height
        for row, row_data in ipairs(tier_data) do
            local inner_row_flow = row_flow.add{
                type = "flow",
                name = "inner-row-flow_" .. row,
                direction = "vertical",
                style = "ei_inner_content_flow_vertical_centered",
            }

            for height = 1, model.get_total_height(row_data) do
                local holder = inner_row_flow.add{
                    type = "flow",
                    name = "inner_row_flow_" .. row .. "_" .. height,
                    direction = "horizontal",
                    style = "ei_inner_content_flow_horizontal_centered",
                }

                for _, node in ipairs(row_data) do
                    if node.height == height then
                        holder.add{
                            type = "sprite-button",
                            sprite = model.get_button_sprite(node),
                            tooltip = get_button_tooltip(node),
                            tags = model.get_button_tags(node),
                            style = "ei_alien_sprite_button_" .. model.get_unlocked_state(node.name, force),
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
        stack = {name = "ei-resonance-data", count = math.random(drop.min, drop.max)},
        enable_looted = true,
        allow_belts = false,
        max_radius = 2.5,
    }
end

function model.repair_artifact(event)
    local item = event.item
    local player = game.get_player(event.player_index)

    for _, entity in ipairs(event.entities) do
        if entity.valid and model.repair_tools[item].targets[entity.name] then

            -- spawn repaired entity and destroy old one
            local surface = entity.surface
            local position = entity.position
            local force = entity.force
            entity.destroy()

            local new_entity = surface.create_entity{
                name = model.repair_tools[item].result,
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

            -- alien knowledge goes to the repairing player's force (artifacts are neutral)
            local reward_force = player and player.force or game.forces["player"]
            model.add_alien(reward_force, ei_balance.alien_points_per_repair)
            reward_force.print({"exotic-industries.alien-knowledge-gained", ei_balance.alien_points_per_repair})

            ei_victory.count_value("artifacts_repaired", 1)
            return
        end
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

---A technology of a tree node researched in a lab marks the node as unlocked.
function model.on_research_finished(event)
    local force = event.research.force
    if model.get_force_data(force) then
        model.sync_researched(force)
    end
end

return model
