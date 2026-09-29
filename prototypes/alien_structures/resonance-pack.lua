--====================================================================================================
-- ALIEN RESONANCE PACK + ALIEN TIER 4 "RESONANT COMPUTATION" (design doc §3, §4)
--====================================================================================================
-- ei-alien-resonance-pack: second tier of the alien science.
--   recipe:  50 ei-morphium + 20 ei-computing-power + 2 ei-resonance-data -> 1 pack
--            (numbers in lib/balance.lua -> resonance_pack_recipe)
--   made in: ei-resonance-synthesizer (own category, computing power needs a data connection)
--   only on Gaia: recipe surface_conditions (lib/balance.lua -> gaia_surface_conditions)
--   consumed by: alien tree tier 5 node, ei-void-rift-generator recipe
--
-- ei-resonant-computation: alien tier 4 node. It can ONLY be unlocked through the alien tech
-- tree (research_trigger "scripted"), never in a lab.
--   unlocks: ei-alien-resonance-pack recipe, ei-data-pipe-to-ground ("data cable tier 2")
--====================================================================================================

local ei_balance = require("lib/balance")
local pack = ei_balance.resonance_pack_recipe

data:extend({
    {
        name = "ei-alien-resonance-pack",
        type = "tool",
        -- icon by request: ei-simulation-data; the small alien pack overlay tells both items apart
        icons = {
            {icon = ei_graphics_item_path.."simulation-data.png", icon_size = 128},
            {icon = ei_graphics_item_path.."alien-computer-age-tech.png", icon_size = 64, scale = 0.25, shift = {8, 8}},
        },
        stack_size = 200,
        durability = 1,
        subgroup = "science-pack",
        order = "a4-3",
    },
    {
        name = "ei-alien-resonance-pack",
        type = "recipe",
        category = "ei-resonance-synthesizer",
        energy_required = pack.time,
        ingredients = {
            {type = "fluid", name = "ei-morphium", amount = pack.morphium},
            {type = "fluid", name = "ei-computing-power", amount = pack.computing_power},
            {type = "item", name = "ei-resonance-data", amount = pack.resonance_data},
        },
        results = {
            {type = "item", name = "ei-alien-resonance-pack", amount = pack.result},
        },
        surface_conditions = table.deepcopy(ei_balance.gaia_surface_conditions),
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-alien-resonance-pack",
    },
    {
        name = "ei-resonant-computation",
        type = "technology",
        icon = ei_graphics_tech_path.."alien-computer-age-tech.png",
        icon_size = 256,
        prerequisites = {"ei-resonance-synthesizer"},
        effects = {
            {type = "unlock-recipe", recipe = "ei-alien-resonance-pack"},
            {type = "unlock-recipe", recipe = "ei-data-pipe-to-ground"},
        },
        -- only the alien tech tree (scripts/control/alien_system.lua) researches this technology
        research_trigger = {
            type = "scripted",
            trigger_description = {"technology-description.ei-alien-tree-trigger"},
        },
    },
})
