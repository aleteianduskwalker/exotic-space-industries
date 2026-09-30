--====================================================================================================
-- RESONANCE SYNTHESIZER (design doc §3, brief log §2.1)
--====================================================================================================
-- Clone of ei-small-simulator with its own crafting category and TWO fluid boxes:
--   fluid box 1 (east):  ei-computing-power - registered in the data network
--                        (scripts/data-final-updates/data_network.lua), connects ONLY to data cables
--   fluid box 2 (west):  ei-morphium - regular pipe connection
-- Not a fixed_recipe machine: it crafts
--   * ei-resonance-data        (unlocked by the lab technology ei-resonance-synthesizer;
--                               3.2.0: multiplies data 1 -> 2, it can not create data from nothing)
--   * ei-alien-resonance-pack  (unlocked by technology ei-resonant-computation / alien tier 4)
-- WHY an own category: computing power can only reach machines whose fluid box is registered in
-- the data network; regular "advanced-crafting" machines have no such connection.
--====================================================================================================

local ei_balance = require("lib/balance")
local recipe_data = ei_balance.resonance_data_recipe

-- entity: deep copy of the small simulator, so graphics and base stats stay in sync with it
local synthesizer = table.deepcopy(data.raw["assembling-machine"]["ei-small-simulator"])
synthesizer.name = "ei-resonance-synthesizer"
synthesizer.minable.result = "ei-resonance-synthesizer"
synthesizer.crafting_categories = {"ei-resonance-synthesizer"}
synthesizer.fixed_recipe = nil
synthesizer.energy_usage = "1MW"
synthesizer.fluid_boxes = {
    { -- 1: computing power (data network, see data_network.lua)
        volume = 200,
        pipe_covers = pipecoverspictures(),
        pipe_picture = ei_pipe_data,
        pipe_connections = {
            {flow_direction = "input", direction = defines.direction.east, position = {1, 0}},
        },
        production_type = "input",
    },
    { -- 2: morphium (regular pipes)
        volume = 500,
        pipe_covers = pipecoverspictures(),
        pipe_connections = {
            {flow_direction = "input", direction = defines.direction.west, position = {-1, 0}},
        },
        production_type = "input",
    },
}

data:extend({
    synthesizer,
    {
        name = "ei-resonance-synthesizer",
        type = "recipe-category",
    },
    {
        name = "ei-resonance-synthesizer",
        type = "item",
        icon = ei_graphics_item_path.."small-simulator.png",
        icon_size = 64,
        subgroup = "ei-labs",
        order = "b2b", -- "b3" is taken by ei-quantum-computer
        place_result = "ei-resonance-synthesizer",
        stack_size = 50,
    },
    {
        name = "ei-resonance-synthesizer",
        type = "recipe",
        category = "crafting",
        energy_required = 2,
        ingredients = {
            {type = "item", name = "ei-small-simulator", amount = 1},
            {type = "item", name = "ei-energy-crystal", amount = 10},
            {type = "item", name = "ei-alien-resin", amount = 20},
            {type = "item", name = "ei-electronic-parts", amount = 10},
        },
        results = {{type = "item", name = "ei-resonance-synthesizer", amount = 1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-resonance-synthesizer",
    },
    {
        name = "ei-resonance-data",
        type = "recipe",
        category = "ei-resonance-synthesizer",
        energy_required = recipe_data.time,
        ingredients = {
            {type = "fluid", name = "ei-morphium", amount = recipe_data.morphium},
            {type = "fluid", name = "ei-computing-power", amount = recipe_data.computing_power},
            {type = "item", name = "ei-resonance-data", amount = recipe_data.resonance_data},
        },
        results = {
            {type = "item", name = "ei-resonance-data", amount = recipe_data.result},
        },
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-resonance-data",
        -- a multiplying loop must never gain productivity
        allow_productivity = false,
    },
    {
        -- regular lab technology; 3.2.0: anchor of every script-only alien tree technology
        -- (lib/alien_tree.lua -> anchor_technology), it is no longer a node of the tree itself
        name = "ei-resonance-synthesizer",
        type = "technology",
        icon = ei_graphics_tech_path.."computer-core.png",
        icon_size = 256,
        prerequisites = {"ei-alien-computer-age-tech", "ei-computer-core"},
        effects = {
            {type = "unlock-recipe", recipe = "ei-resonance-synthesizer"},
            {type = "unlock-recipe", recipe = "ei-resonance-data"},
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["alien-computer-age"],
            time = 20,
        },
    },
})
