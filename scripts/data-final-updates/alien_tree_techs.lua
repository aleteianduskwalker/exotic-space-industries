--====================================================================================================
-- ALIEN TREE TECHNOLOGIES (3.2.0)
--====================================================================================================
-- Every technology unlocked through the alien tech tree (lib/alien_tree.lua) becomes:
--   * script-only: research_trigger "scripted", no lab research (unit removed)
--   * visible in the vanilla technology screen, so players can see what a node gives
--   * dependent on the anchor lab technology (resonance synthesizer), on optional extra lab
--     technologies (node.technologies) and on the meta technologies of its in-row prerequisite nodes
-- Runs at the very end of data-final-fixes, after every script that touches technology costs or
-- prerequisites (tech flattening, age packs, pack cycles, debloat, ...).
--====================================================================================================

local alien_tree = require("lib/alien_tree")

local technologies = data.raw.technology
local anchor = alien_tree.anchor_technology

alien_tree.for_each_node(function(node)
    local technology = technologies[node.meta]
    if not technology then
        log("ESI alien tree: technology " .. node.meta .. " of node " .. node.name .. " does not exist")
        return
    end

    -- script-only research
    technology.unit = nil
    technology.research_trigger = {
        type = "scripted",
        trigger_description = {"technology-description.ei-alien-tree-trigger"},
    }

    -- visible and researchable by script
    technology.hidden = nil
    technology.enabled = true
    technology.visible_when_disabled = true
    -- the age attribute would give the technology age science packs again (no-triggers setting)
    technology.age = nil

    if node.keep_prerequisites then
        return
    end

    local prerequisites = {}
    if technologies[anchor] and anchor ~= node.meta then
        table.insert(prerequisites, anchor)
    end
    for _, technology_name in ipairs(node.technologies or {}) do
        if technologies[technology_name] then
            table.insert(prerequisites, technology_name)
        end
    end
    for _, prerequisite_name in ipairs(node.prerequisites or {}) do
        local prerequisite = alien_tree.find_node(prerequisite_name)
        if prerequisite and technologies[prerequisite.meta] then
            table.insert(prerequisites, prerequisite.meta)
        end
    end
    technology.prerequisites = prerequisites
end)
