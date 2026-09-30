--====================================================================================================
-- ALIEN TECH TREE DEFINITION (shared by the data and the control stage)
--====================================================================================================
-- The alien tech tree is shown on the InformaTron page "Alien tech tree" and bought with "alien
-- knowledge" points (scripts/control/alien_system.lua). Every node unlocks one technology ("meta").
--
-- DATA STAGE (scripts/data-final-updates/alien_tree_techs.lua)
--   Every meta technology becomes a visible, script-only technology (research_trigger "scripted",
--   no lab research) that depends on the lab technology `alien_tree.anchor_technology` (resonance
--   synthesizer), so the vanilla technology screen shows what a node gives.
--
-- CONTROL STAGE (scripts/control/alien_system.lua)
--   Tier k+1 opens once every node of tier k is unlocked; inside a tier a node may require other
--   nodes of its row (`prerequisites`). A node can only be bought when every prerequisite
--   technology of its meta technology is researched.
--
-- STRUCTURE: tiers -> rows -> nodes. A node:
--   name                unique node name (button sprite "ei-knowledge-<name>" if it exists)
--   meta                technology researched when the node is unlocked
--   cost                alien knowledge points (may be paid with packs / data, see lib/balance.lua)
--   items               optional {{name, count}} additionally consumed from the main inventory
--   height              row position (nodes with prerequisites sit lower)
--   prerequisites       optional list of node names of the same row
--   keep_prerequisites  true: the meta technology keeps its own prerequisites instead of the
--                       anchor technology (needed when the anchor itself depends on it)
--   technologies        optional extra prerequisite (lab) technologies of the meta technology
--   anywhere            true: can be bought without an alien terminal nearby (3.2.0: every other
--                       node needs one, see scripts/control/alien_console.lua)
--====================================================================================================

local ei_balance = require("lib/balance")

local alien_tree = {}

-- lab technology every script-only alien technology depends on
alien_tree.anchor_technology = "ei-resonance-synthesizer"

---Creates a node definition.
---@param name string node name
---@param meta string technology name
---@param cost number|table alien knowledge points or a tier cost table {points, items}
---@param options table|nil {height, prerequisites, keep_prerequisites, technologies, anywhere}
local function node(name, meta, cost, options)
    options = options or {}
    local points, items = cost, nil
    if type(cost) == "table" then
        points, items = cost.points, cost.items
    end
    return {
        type = "tech",
        name = name,
        meta = meta,
        cost = points,
        items = items,
        height = options.height or 1,
        prerequisites = options.prerequisites,
        keep_prerequisites = options.keep_prerequisites,
        technologies = options.technologies,
        anywhere = options.anywhere,
    }
end

local tier4 = ei_balance.alien_tech_tier4_cost
local tier5 = ei_balance.alien_tech_tier5_cost

alien_tree.tiers = {
    -- tier 1: first steps on Gaia
    {
        {node("gate", "ei-gate", 100)},
        -- the alien science pack (and therefore the anchor technology) needs the bio chamber
        {node("bio-chamber", "ei-bio-chamber", 100, {keep_prerequisites = true})},
        {node("crystal-accumulator-repair", "ei-crystal-accumulator-repair", 100)},
        -- 3.2.0: the conduit replaces the resonance synthesizer node (that one is a lab technology)
        {node("conduit", "ei-conduit", 100)},
        -- 3.2.0: the alien terminal is the access point of the tree, so its own node is the only one
        -- that can be bought anywhere (no deadlock without a repaired terminal ruin)
        {node("alien-console", "ei-alien-console", 100, {anywhere = true})},
    },
    -- tier 2: bio branch
    {
        {
            node("bio_insulated-wire", "ei-bio-insulated-wire", 200),
            node("bio_electronic-parts", "ei-bio-electronic-parts", 300, {height = 2, prerequisites = {"bio_insulated-wire"}}),
        },
        {
            node("bio_energy-crystal", "ei-bio-energy-crystal", 200),
            node("bio_high-energy-crystal", "ei-bio-high-energy-crystal", 300, {height = 2, prerequisites = {"bio_energy-crystal"}}),
        },
        {
            node("bio_hydrofluoric-acid", "ei-bio-hydrofluoric-acid", 200),
            node("bio_nitric-acid", "ei-bio-nitric-acid", 300, {height = 2, prerequisites = {"bio_hydrofluoric-acid"}}),
        },
        {node("farstation-repair", "ei-farstation-repair", 300)},
        -- 3.2.0: drone port, drones and the drone remote
        {node("drone-port", "ei-drone-port", 300)},
    },
    -- tier 3: old goals
    {
        {node("alien-beacon-repair", "ei-alien-beacon-repair", 2000)},
        {node("farstation", "ei-farstation", 1000)},
        {node("bio_carbon-structure", "ei-bio-carbon-structure", 500)},
        {node("bio_magnet", "ei-bio-magnet", 500)},
        {node("bio_rocket-fuel", "ei-bio-rocket-fuel", 500)},
    },
    -- tier 4: resonant computation (every node costs the same)
    {
        {node("resonant-computation", "ei-resonant-computation", tier4)},
        {node("data-center", "ei-data-center", tier4)},
        -- the crystal radio station is built from a regular radio station
        {node("crystal-radio-station", "ei-crystal-radio-station", tier4, {technologies = {"ei-radio-station"}})},
    },
    -- tier 5: threshold engineering (the void rift generator is built from a void engine)
    {
        {
            node("void-engine", "ei-void-engine", tier5),
            node("threshold-engineering", "ei-threshold-engineering", tier5, {height = 2, prerequisites = {"void-engine"}}),
        },
    },
}

---Calls fn(node, tier_index) for every node of the tree.
---@param fn fun(node: table, tier: integer)
function alien_tree.for_each_node(fn)
    for tier, tier_data in ipairs(alien_tree.tiers) do
        for _, row_data in ipairs(tier_data) do
            for _, tree_node in ipairs(row_data) do
                fn(tree_node, tier)
            end
        end
    end
end

---Returns the node with the given name (or nil).
---@param name string
function alien_tree.find_node(name)
    local found
    alien_tree.for_each_node(function(tree_node)
        if tree_node.name == name then found = tree_node end
    end)
    return found
end

---Set of all technologies that are unlocked through the tree: {[technology_name] = node}.
function alien_tree.meta_technologies()
    local metas = {}
    alien_tree.for_each_node(function(tree_node) metas[tree_node.meta] = tree_node end)
    return metas
end

return alien_tree
