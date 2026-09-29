ei_data = require("lib/data")

--====================================================================================================
--VOID ENGINE
--====================================================================================================

data:extend({
    {
        name = "ei-void-engine",
        type = "recipe-category",
    },
    {
        name = "ei-void-engine",
        type = "item",
        icon = ei_void_engine_items.."void-engine.png",
        icon_size = 64,
        subgroup = "production-machine",
        order = "d-a-c-5",
        place_result = "ei-void-engine",
        stack_size = 50
    },
    {
        name = "ei-void-fuel",
        type = "item",
        icon = ei_void_engine_items.."void-fuel.png",
        icon_size = 64,
        subgroup = "intermediate-product",
        order = "d[empty-barrel]-1",
        stack_size = 50,
        fuel_category = "chemical",
        fuel_value = "1GJ",
    },
    {
        name = "ei-void-inflator",
        type = "item",
        icon = ei_void_engine_items.."void-inflator.png",
        icon_size = 64,
        subgroup = "intermediate-product",
        order = "d[empty-barrel]-1",
        stack_size = 1
    },
    {
        name = "ei-void-engine",
        type = "recipe",
        category = "crafting",
        energy_required = 4,
        ingredients =
        {
            { type = "item", name = "ei-insulated-tank", amount = 2 },
            { type = "item", name = "ei-arc-furnace", amount = 1 },
            { type = "item", name = "ei-magnet", amount = 20 },
            { type = "item", name = "ei-steel-mechanical-parts", amount = 18 },

        },
        enabled = false,
        main_product = "ei-void-engine",
        results = { { type = "item", name = "ei-void-engine", amount = 1 } },
    },
    {
        name = "ei-void-inflator",
        type = "recipe",
        category = "crafting",
        energy_required = 10,
        ingredients =
        {
            { type = "item", name = "ei-bio-matter", amount = 1 },
            { type = "item", name = "ei-high-energy-crystal", amount = 1 },
        },
        enabled = false,
        main_product = "ei-void-inflator",
        results = { { type = "item", name = "ei-void-inflator", amount = 1 } },
    },
    {
        name = "ei-void-fuel",
        type = "recipe",
        category = "ei-void-engine",
        energy_required = 100,
        ingredients =
        {
            {type="item", name="ei-void-inflator", amount=1},
            {type="item", name="ei-empty-cryo-container", amount=1},
        },
        results = {
            {type="item", name="ei-void-fuel", amount=1, probability=0.1},
            {type="item", name="ei-empty-cryo-container", amount=1, probability=0.9}
        },
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-void-fuel",
    },
    {
        name = "ei-void-engine",
        type = "technology",
        icon = ei_void_engine_path.."void-engine.png",
        icon_size = 256,
        prerequisites = {"ei-sus-plating"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-void-engine"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-void-inflator"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-void-fuel"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["alien-computer-age"],
            time = 20
        },
    },
    {
        name = "ei-void-engine",
        type = "assembling-machine",
        icon = ei_void_engine_items.."void-engine.png",
        icon_size = 64,
        flags = {"placeable-neutral", "placeable-player", "player-creation"},
        minable = {
            mining_time = 0.5,
            result = "ei-void-engine"
        },
        max_health = 300,
        resistances = {
            {
                type = "electric",
                percent = 100
            },
        },
        corpse = "big-remnants",
        dying_explosion = "medium-explosion",
        collision_box = {{-4.4, -4.4}, {4.4, 4.4}},
        selection_box = {{-4.5, -4.5}, {4.5, 4.5}},
        map_color = ei_data.colors.assembler,
        crafting_categories = {"ei-void-engine"},
        crafting_speed = 1,
        energy_source = {
            type = 'electric',
            usage_priority = 'secondary-input',
        },
        energy_usage = "20MW",
        result_inventory_size = 1,
        source_inventory_size = 1,
        allowed_effects = {"speed", "consumption", "pollution"},
        module_specification = {
            module_slots = 20
        },
        radius_visualisation_specification = {
            sprite = {
                filename = ei_graphics_other_path.."radius.png",
                width = 256,
                height = 256
            },
            distance = 30,
        },
        graphics_set = {
          animation = {
            layers = {
              {
                filename = ei_void_engine_entity.."void-engine_off.png",
                size = {512*2,512*2},
                shift = {0, -0.5},
                scale = 0.33,
                line_length = 1,
                --lines_per_file = 2,
                frame_count = 1,
                -- animation_speed = 0.2,
              }
            }
          },
          
          working_visualisations = {
            {
              animation = 
              {
                filename = ei_void_engine_entity.."void-engine.png",
                size = {512*2,512*2},
                shift = {0, -0.5},
	              scale = 0.33,
                line_length = 1,
                frame_count = 1,
                animation_speed = 0.4,
                run_mode = "backward",
              }
            },
            {
                light = {
                type = "basic",
                intensity = 1,
                size = 15
                }
            }
          }

        },

        working_sound =
        {
            sound = {filename = "__base__/sound/electric-furnace.ogg", volume = 0.6},
            apparent_volume = 0.3,
        },
    },
})