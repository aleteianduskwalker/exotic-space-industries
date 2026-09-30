--====================================================================================================
-- VOID RIFT GENERATOR + ALIEN TIER 5 "THRESHOLD ENGINEERING" (design doc §5)
--====================================================================================================
-- The void engine needs "out-of-map" tiles within 30 tiles. Naturally they only come from the
-- legendary "out-of-map" spawner preset. The void rift generator is the guaranteed alternative:
--   * on build it carves a square out-of-map patch next to itself (south side) and casts the same
--     beams as the void engine (scripts/control/gaia.lua -> model.register_void_rift_generator)
--   * on removal the beams disappear and the ORIGINAL terrain (and resources) is restored
--     (model.remove_void_rift_generator)
-- Graphics: the void engine graphics one to one (no own asset planned, design doc §10).
-- Entity type: simple-entity-with-owner - the carve happens once on build, so the generator
-- needs neither energy nor recipes ([ASSUMPTION]: the document does not specify a running cost).
--
-- ei-threshold-engineering: alien tier 5 node, scripted research (alien tech tree only).
--   unlocks: ei-void-rift-generator. (EM trains were REMOVED from this node - postponed, §6.)
--====================================================================================================

local ei_balance = require("lib/balance")

local void_engine = data.raw["assembling-machine"]["ei-void-engine"]

data:extend({
    {
        name = "ei-void-rift-generator",
        type = "item",
        icon = ei_void_engine_items.."void-engine.png",
        icon_size = 64,
        subgroup = "production-machine",
        order = "d-a-c-6",
        place_result = "ei-void-rift-generator",
        stack_size = 10,
    },
    {
        name = "ei-void-rift-generator",
        type = "recipe",
        category = "crafting",
        energy_required = 20,
        ingredients = {
            {type = "item", name = "ei-void-engine", amount = 1},
            {type = "item", name = "ei-alien-resonance-pack", amount = ei_balance.void_rift.resonance_packs},
            {type = "item", name = "ei-high-energy-crystal", amount = 10},
        },
        results = {{type = "item", name = "ei-void-rift-generator", amount = 1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-void-rift-generator",
    },
    {
        name = "ei-void-rift-generator",
        type = "simple-entity-with-owner",
        icon = ei_void_engine_items.."void-engine.png",
        icon_size = 64,
        flags = {"placeable-neutral", "placeable-player", "player-creation"},
        minable = {mining_time = 1, result = "ei-void-rift-generator"},
        max_health = 1000,
        resistances = table.deepcopy(void_engine.resistances),
        corpse = "big-remnants",
        dying_explosion = "medium-explosion",
        collision_box = table.deepcopy(void_engine.collision_box),
        selection_box = table.deepcopy(void_engine.selection_box),
        map_color = ei_data.colors.alien,
        render_layer = "object",
        -- the "working" void engine picture (the generator is always "on")
        picture = table.deepcopy(void_engine.graphics_set.working_visualisations[1].animation),
    },
    {
        name = "ei-threshold-engineering",
        type = "technology",
        icon = ei_void_engine_path.."void-engine.png",
        icon_size = 256,
        prerequisites = {"ei-resonance-synthesizer", "ei-void-engine"},
        effects = {
            {type = "unlock-recipe", recipe = "ei-void-rift-generator"},
        },
        research_trigger = {
            type = "scripted",
            trigger_description = {"technology-description.ei-alien-tree-trigger"},
        },
    },
})

-- an Animation (void engine working visualisation) is used as Sprite: drop animation-only keys
local picture = data.raw["simple-entity-with-owner"]["ei-void-rift-generator"].picture
picture.line_length, picture.frame_count, picture.animation_speed, picture.run_mode = nil, nil, nil, nil
