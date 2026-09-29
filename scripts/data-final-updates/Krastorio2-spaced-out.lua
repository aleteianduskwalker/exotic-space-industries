--====================================================================================================
-- -- CHECK FOR MOD
--====================================================================================================

if not mods["Krastorio2-spaced-out"] then
  return
end

local ei_lib = require("lib.lib")
local ei_data = require("lib.data")
local _td = table.deepcopy

--CONSTANTS
------------------------------------------------------------------------------------------------------

local function convertTypePrototype(name, old_type, new_type)
    if data.raw[old_type][name] then
        local new_prototype = table.deepcopy(data.raw[old_type][name])
        new_prototype.type = new_type
        data.raw[old_type][name] = nil
        data:extend({ new_prototype })
    end
end

--====================================================================================================
-- -- NEW PROTOTYPES
--====================================================================================================

--CATEGORIES, GROUPS, SUBGROUPS
------------------------------------------------------------------------------------------------------

if data.raw['item-group']['science'] then 

  data:extend({
      {
          name = "ei-science-data",
          type = "item-subgroup",
          group = "intermediate-products",
      },
      {
          name = "ei-science-tech-card",
          type = "item-subgroup",
          group = "intermediate-products",
      },
      {
          name = "t4-tech-cards",
          type = "recipe-category",
      },
      {
          name = "ei-atmosphere-condensation",
          type = "recipe-category",
      },
      {
          name = "ei-science-other",
          type = "item-subgroup",
          group = "science",
          order = "a",
      },
      {
          name = "ei-science-kr-cards",
          type = "item-subgroup",
          group = "science",
          order = "b",
      },
      {
          name = "ei-science-ei-cards",
          type = "item-subgroup",
          group = "science",
          order = "c",
      },
      {
          name = "ei-science-science",
          type = "item-subgroup",
          group = "science",
          order = "d",
      },
      {
          name = "underground-belt",
          type = "item-subgroup",
          group = "logistics",
          order = "b-a",
      },
      {
          name = "splitter-belt",
          type = "item-subgroup",
          group = "logistics",
          order = "b-b",
      },
      {
          name = "loader-belt",
          type = "item-subgroup",
          group = "logistics",
          order = "b-c",
      },
  })

else

data:extend({

      {
        name = "ei-science",
        type = "item-group",
        icon = ei_graphics_other_path.."science.png",
        icon_size = 128,
        inventory_order = "d-a",
        order = "d-a",
    },
  
    {
        name = "ei-science-data",
        type = "item-subgroup",
        group = "intermediate-products",
    },
    {
        name = "ei-science-tech-card",
        type = "item-subgroup",
        group = "intermediate-products",
    },
    {
        name = "t4-tech-cards",
        type = "recipe-category",
    },
    {
        name = "ei-atmosphere-condensation",
        type = "recipe-category",
    },
    {
        name = "ei-science-other",
        type = "item-subgroup",
        group = "ei-science",
        order = "a",
    },
    {
        name = "ei-science-kr-cards",
        type = "item-subgroup",
        group = "ei-science",
        order = "b",
    },
    {
        name = "ei-science-ei-cards",
        type = "item-subgroup",
        group = "ei-science",
        order = "c",
    },
    {
        name = "ei-science-science",
        type = "item-subgroup",
        group = "ei-science",
        order = "d",
    },
    {
        name = "underground-belt",
        type = "item-subgroup",
        group = "logistics",
        order = "b-a",
    },
    {
        name = "splitter-belt",
        type = "item-subgroup",
        group = "logistics",
        order = "b-b",
    },
    {
        name = "loader-belt",
        type = "item-subgroup",
        group = "logistics",
        order = "b-c",
    },
})

end

--====================================================================================================
--PROPERTIES CHANGES
--====================================================================================================

convertTypePrototype("ei-arc-furnace", "furnace", "assembling-machine")
convertTypePrototype("kr-crusher", "furnace", "assembling-machine")

--====================================================================================================
--SAND AND CRUSHERS
--====================================================================================================
-- K2 has its own sand item ("bag of sand", kr-sand) that could only be made in the K2 crusher,
-- while EI sand ("pile of sand", ei-sand) could only be made in EI crushers. Both are merged into
-- EI sand and every crusher can handle both crushing categories.

if data.raw.item["kr-sand"] and data.raw.item["ei-sand"] then
    ei_lib.merge_item("ei-sand", "kr-sand")

    -- leftover K2 sand from older saves can be converted by hand
    data:extend({
        {
            type = "recipe",
            name = "ei-sand-from-kr-sand",
            category = "crafting",
            energy_required = 0.5,
            ingredients = {{type = "item", name = "kr-sand", amount = 1}},
            results = {{type = "item", name = "ei-sand", amount = 1}},
            enabled = true,
            hidden_in_factoriopedia = true,
            allow_productivity = false,
            allow_quality = true,
            auto_recycle = false,
        },
    })
end

local CRUSHING_CATEGORIES = {"ei-crushing", "kr-crushing"}

for _, machine in pairs(data.raw["assembling-machine"]) do
    local categories = machine.crafting_categories or {}
    local is_crusher = false
    for _, category in pairs(CRUSHING_CATEGORIES) do
        if ei_lib.table_contains_value(categories, category) then
            is_crusher = true
        end
    end

    if is_crusher then
        for _, category in pairs(CRUSHING_CATEGORIES) do
            if data.raw["recipe-category"][category] and not ei_lib.table_contains_value(categories, category) then
                table.insert(categories, category)
            end
        end
    end
end


ei_lib.add_item_level("kr-superior-filter-inserter", "filter")
ei_lib.add_item_level("kr-superior-long-filter-inserter", "filter")
ei_lib.add_item_level("kr-crusher", "3")
ei_lib.add_item_level("kr-advanced-solar-panel", "4")
ei_lib.add_item_level("accumulator", "1")
ei_lib.add_item_level("kr-energy-storage", "2")
ei_lib.add_item_level("stone-furnace", "1")
ei_lib.add_item_level("steel-furnace", "2")
ei_lib.add_item_level("electric-furnace", "3")
ei_lib.add_item_level("kr-advanced-furnace", "4")
ei_lib.add_item_level("kr-advanced-chemical-plant", "4")
ei_lib.add_item_level("ei-dark-age-lab", "1")
ei_lib.add_item_level("lab", "2")
ei_lib.add_item_level("biusart-lab", "3")
ei_lib.add_item_level("kr-singularity-lab", "4")
ei_lib.add_item_level("ei-big-lab", "5")
ei_lib.add_item_level("kr-advanced-assembling-machine", "5")
ei_lib.add_item_level("ei-purifier", "1")
ei_lib.add_item_level("kr-filtration-plant", "2")
ei_lib.add_item_level("kr-research-server", "1")
ei_lib.add_item_level("kr-quantum-computer", "2")
ei_lib.add_item_level("ei-quantum-computer", "3")
ei_lib.add_item_level("ei-lufter", "1")
ei_lib.add_item_level("kr-atmospheric-condenser", "2")

--====================================================================================================
--TECH FIXES
--====================================================================================================

data:extend({
    {
        name = "ei-matter-quantum-age-tech",
        type = "tool",
        icon = ei_graphics_item_path.."matter-quantum-age-tech.png",
        icon_size = 64,
        stack_size = 200,
        durability = 1,
        subgroup = "ei-science-science",
        order = "a5-4",
        pictures = {
            layers =
            {
              {
                size = 64,
                filename = ei_graphics_item_path.."matter-quantum-age-tech.png",
                scale = 0.25
              },
              {
                draw_as_light = true,
                flags = {"light"},
                size = 64,
                filename = ei_graphics_item_path.."quantum-age-tech_light.png",
                scale = 0.25
              }
            }
        },
    },
    {
        name = "ei-imersite-quantum-age-tech",
        type = "tool",
        icon = ei_graphics_item_path.."imersite-quantum-age-tech.png",
        icon_size = 64,
        stack_size = 200,
        durability = 1,
        subgroup = "ei-science-science",
        order = "a5-3",
        pictures = {
            layers =
            {
              {
                size = 64,
                filename = ei_graphics_item_path.."imersite-quantum-age-tech.png",
                scale = 0.25
              },
              {
                draw_as_light = true,
                flags = {"light"},
                size = 64,
                filename = ei_graphics_item_path.."quantum-age-tech_light.png",
                scale = 0.25
              }
            }
        },
    },
})


-- machinery and other
-------------------------------------------------------------------------------
ei_lib.recipe_add("ei-quantum-computer", "kr-quantum-computer", 1)
ei_lib.add_unlock_recipe("ei-electricity-power", "kr-wind-turbine")

data.raw["solar-panel"]["kr-advanced-solar-panel"].production = "1280kW"


-- ressouces
-------------------------------------------------------------------------------

ei_lib.add_unlock_recipe("kr-fluids-chemistry", "kr-rare-metals")


data:extend({
    {
        name = "ei-enriched-iron",
        type = "recipe",
        category = "ei-purifier",
        energy_required = 1,
        ingredients = {
            {type = "item", name = "ei-pure-iron", amount = 9},
            {type = "fluid", name = "sulfuric-acid", amount = 3},
        },
        results = {
            {type = "item", name = "kr-enriched-iron", amount = 9},
            {type = "fluid", name = "ei-dirty-water", amount = 3},
        },
        main_product = "kr-enriched-iron",
        subgroup = "ei-refining-purified",
        order = "b",
        enabled = false,
        always_show_made_in = true,
    },
    {
        name = "ei-enriched-copper",
        type = "recipe",
        category = "ei-purifier",
        energy_required = 1,
        ingredients = {
            {type = "item", name = "ei-pure-copper", amount = 9},
            {type = "fluid", name = "sulfuric-acid", amount = 3},
        },
        results = {
            {type = "item", name = "kr-enriched-copper", amount = 9},
            {type = "fluid", name = "ei-dirty-water", amount = 3},
        },
        main_product = "kr-enriched-copper",
        subgroup = "ei-refining-purified",
        order = "b",
        enabled = false,
        always_show_made_in = true,
    },
    {
        name = "ei-enriched-rare-metals",
        type = "recipe",
        category = "ei-purifier",
        energy_required = 1,
        ingredients = {
            {type = "item", name = "kr-rare-metal-ore", amount = 9},
            {type = "fluid", name = "kr-hydrogen-chloride", amount = 10},
        },
        results = {
            {type = "item", name = "kr-enriched-rare-metals", amount = 9},
            {type = "fluid", name = "kr-chlorine", amount = 5},
        },
        main_product = "kr-enriched-rare-metals",
        subgroup = "ei-refining-purified",
        order = "b",
        enabled = false,
        always_show_made_in = true,
    },
    {
        name = "ei-enriched-iron-plate",
        type = "recipe",
        category = "smelting",
        energy_required = 16,
        ingredients = {
            {type = "item", name = "kr-enriched-iron", amount = 10},
        },
        results = {
            {type = "item", name = "iron-plate", amount = 20},
        },
        main_product = "iron-plate",
        enabled = false,
        always_show_made_in = true,
    },
    {
        name = "ei-enriched-copper-plate",
        type = "recipe",
        category = "smelting",
        energy_required = 16,
        ingredients = {
            {type = "item", name = "kr-enriched-copper", amount = 10},
        },
        results = {
            {type = "item", name = "copper-plate", amount = 20},
        },
        main_product = "copper-plate",
        enabled = false,
        always_show_made_in = true,
    },
    {
        name = "ei-quartz",
        type = "recipe",
        category = "ei-purifier",
        energy_required = 3,
        ingredients = {
            {type = "item", name = "ei-sand", amount = 10},
            {type = "fluid", name = "water", amount = 10},
        },
        results = {
            {type = "item", name = "kr-quartz", amount = 6},
        },
        main_product = "kr-quartz",
        subgroup = "ei-refining-purified",
        order = "b-a",
        enabled = false,
        always_show_made_in = true,
    },
    {
        name = "ei-bio-matter-biomass",
        type = "recipe",
        category = "kr-bioprocessing",
        energy_required = 10,
        ingredients = {
            {type = "item", name = "ei-bio-matter", amount = 1},
            {type = "item", name = "kr-fertilizer", amount = 1},
            {type = "item", name = "kr-biomass", amount = 10},
            {type = "item", name = "ei-cryodust", amount = 4},
            {type = "fluid", name = "kr-chlorine", amount = 10},
        },
        results = {
            {type = "item", name = "ei-bio-matter", amount = 2},
            {type = "item", name = "ei-cryodust", amount = 1, probability = 0.5},
        },
        main_product = "ei-bio-matter",
        enabled = false,
        always_show_made_in = true,
    },
    {
        name = "ei-imersium-beam-metalworks",
        type = "recipe",
        category = "ei-metalworks",
        energy_required = 3,
        ingredients = {
            {type = "item", name = "kr-imersium-plate", amount = 2},
            {type = "item", name = "steel-plate", amount = 1},
        },
        results = {
            {type = "item", name = "kr-imersium-beam", amount = 1},
        },
        main_product = "kr-imersium-beam",
        hide_from_player_crafting = true,
        enabled = false,
        always_show_made_in = true,
    },
    {
        name = "ei-imersium-gear-wheel-metalworks",
        type = "recipe",
        category = "ei-metalworks",
        energy_required = 2,
        ingredients = {
            {type = "item", name = "kr-imersium-plate", amount = 4},
            {type = "item", name = "ei-steel-mechanical-parts", amount = 4},
        },
        results = {
            {type = "item", name = "kr-imersium-gear-wheel", amount = 4},
        },
        main_product = "kr-imersium-gear-wheel",
        hide_from_player_crafting = true,
        enabled = false,
        always_show_made_in = true,
    },
    {
        name = "ei-water-from-atmosphere",
        type = "recipe",
        category = "ei-atmosphere-condensation",
        energy_required = 120,
        ingredients = {},
        results = {
            {type = "fluid", name = "water", amount = 25},
        },
        main_product = "water",
        subgroup = "fluid-recipes",
        order = "a",
        enabled = false,
        always_show_made_in = true,
    },
    {
        name = "ei-antimatter-cube",
        type = "item",
        icon = ei_graphics_item_path.."antimatter-cube.png",
        icon_size = 64,
        subgroup = "intermediate-product",
        order = "r",
        stack_size = 1
    },
    {
        name = "ei-antimatter-cube",
        type = "recipe",
        category = "ei-accelerator",
        energy_required = 100, -- 100s at 100MW = 10GJ
        ingredients = {
            {type = "item", name = "kr-matter-cube", amount = 1},
            {type = "item", name = "kr-ai-core", amount = 1},
            {type = "item", name = "steel-plate", amount = 10},
            {type = "item", name = "ei-eu-magnet", amount = 1},
        },
        results = {
            {type = "item", name = "ei-antimatter-cube", amount = 1, probability = 0.5},
            {type = "item", name = "kr-matter-cube", amount = 1, probability = 0.5},
            {type = "item", name = "kr-ai-core", amount = 1, probability = 0.5},
            {type = "item", name = "ei-eu-magnet", amount = 1, probability = 0.5},
        },
        main_product = "ei-antimatter-cube",
        enabled = false,
        always_show_made_in = true,
    },
    {
        name = "ei-antimatter-cube",
        type = "technology",
        icon = ei_graphics_tech_path.."antimatter.png",
        icon_size = 128,
        prerequisites = {"ei-accelerator"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-antimatter-cube"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["four-quantum-age"],
            time = 20
        },
        age = "four-quantum-age",
    },
})

-- inserters and belts
-------------------------------------------------------------------------------
ei_lib.recipe_add("ei-steam-inserter", "kr-inserter-parts", 1)
ei_lib.recipe_add("ei-steam-long-inserter", "kr-inserter-parts", 1)
ei_lib.recipe_add("ei-small-inserter-normal", "kr-inserter-parts", 4)
ei_lib.recipe_add("ei-big-inserter-normal", "kr-inserter-parts", 4)
ei_lib.remove_unlock_recipe("logistics", "inserter")
ei_lib.remove_unlock_recipe("logistics", "long-handed-inserter")
ei_lib.remove_unlock_recipe("logistics", "kr-loader")
ei_lib.add_unlock_recipe("fast-inserter", "kr-loader")

data.raw["item"]["ei-neo-underground-belt"].subgroup = "underground-belt"
data.raw["item"]["ei-neo-splitter"].subgroup = "splitter-belt"

-- science
-------------------------------------------------------------------------------

data:extend({
    {
        name = "ei-blank-tech-card",
        type = "recipe",
        category = "crafting",
        energy_required = 4,
        ingredients = {
          {type = "item", name = "ei-ceramic", amount = 3},
          {type = "item", name = "iron-plate", amount = 4},
          {type = "item", name = "ei-glass", amount = 2},
        },
        results = {{type = "item", name = "kr-blank-tech-card", amount = 16}},
        enabled = false,
        always_show_made_in = true,
    },
    {
        name = "ei-blank-tech-card-electronic-parts",
        type = "recipe",
        category = "crafting",
        energy_required = 8,
        ingredients = {
            {type = "item", name = "ei-ceramic", amount = 6},
            {type = "item", name = "iron-plate", amount = 6},
            {type = "item", name = "ei-electronic-parts", amount = 2},
        },
        results = {{type = "item", name = "kr-blank-tech-card", amount = 32}},
        enabled = false,
        always_show_made_in = true,
    },
    {
        name = "ei-matter-quantum-age-tech",
        type = "recipe",
        category = "ei-nano-factory",
        energy_required = 60,
        ingredients = {
            {type = "item", name = "ei-clean-plating", amount = 2},
            {type = "item", name = "kr-energy-control-unit", amount = 1},
            {type = "item", name = "kr-matter-tech-card", amount = 1},
        },
        results = {{type = "item", name = "ei-matter-quantum-age-tech", amount = 10}},
        enabled = false,
        always_show_made_in = true,
    },
    {
        name = "ei-imersite-quantum-age-tech",
        type = "recipe",
        category = "ei-nano-factory",
        energy_required = 60,
        ingredients = {
            {type = "item", name = "kr-imersium-plate", amount = 10},
            {type = "item", name = "ei-carbon-structure", amount = 1},
            -- {type = "item", name = "", amount = },
        },
        results = {{type = "item", name = "ei-imersite-quantum-age-tech", amount = 10}},
        enabled = false,
        always_show_made_in = true,
    },
    {
        type = "recipe",
        name = "kr-wind-turbine",
        category = "crafting",
        energy_required = 4,
        ingredients = {
            {type = "item", name = "electric-engine-unit", amount = 1},
            {type = "item", name = "ei-iron-mechanical-parts", amount = 3},
            {type = "item", name = "ei-copper-mechanical-parts", amount = 3},
        },
        results = {{type = "item", name = "kr-wind-turbine", amount = 1}},
        enabled = false,
    },
    {
        type = "recipe",
        name = "ei-imersite-powder",
        category = "ei-crushing",
        energy_required = 1,
        ingredients = {
            {type = "item", name = "kr-imersite", amount = 6},
        },
        results = {
            {type = "item", name = "ei-sand", amount = 2},
            {type = "item", name = "kr-imersite-powder", amount = 4},
        },
        main_product = "kr-imersite-powder",
        enabled = false,
    },
    
})

ei_lib.add_unlock_recipe("electronics", "ei-blank-tech-card")
ei_lib.add_unlock_recipe("ei-electronic-parts", "ei-blank-tech-card-electronic-parts")
ei_lib.add_unlock_recipe("ei-steam-age", "logistic-science-pack")
ei_lib.add_unlock_recipe("ei-electricity-age", "chemical-science-pack")
ei_lib.add_unlock_recipe("kr-research-server", "utility-science-pack")
ei_lib.add_unlock_recipe("kr-quantum-computer", "production-science-pack")
ei_lib.add_unlock_recipe("ei-moon-exploration", "space-science-pack")
ei_lib.add_unlock_recipe("kr-imersium-processing", "ei-imersite-quantum-age-tech")
ei_lib.add_unlock_recipe("kr-energy-control-unit", "ei-matter-quantum-age-tech")
ei_lib.add_unlock_recipe("kr-energy-control-unit", "kr-matter-tech-card")
ei_lib.add_unlock_recipe("ei-exotic-age", "kr-advanced-tech-card")

ei_lib.add_prerequisite("ei-moon-exploration", "ei-quantum-computer")
ei_lib.add_prerequisite("kr-intergalactic-transceiver", "ei-exotic-age")
ei_lib.add_prerequisite("kr-intergalactic-transceiver", "ei-fusion-reactor")
ei_lib.add_prerequisite("kr-intergalactic-transceiver", "kr-antimatter-reactor")
ei_lib.add_prerequisite("kr-intergalactic-transceiver", "ei-high-temperature-reactor")
ei_lib.add_prerequisite("kr-intergalactic-transceiver", "nuclear-power")
ei_lib.add_prerequisite("kr-intergalactic-transceiver", "ei-superior-induction-matrix")

-- intermediates
-------------------------------------------------------------------------------

ei_lib.recipe_add("ei-crystal-solution", "kr-chlorine", 20, true)
ei_lib.recipe_add("ei-advanced-semiconductor", "kr-chlorine", 5, true)
ei_lib.recipe_add("ei-advanced-semiconductor:monosilicon", "kr-chlorine", 10, true)
ei_lib.recipe_add("ei-monosilicon", "kr-chlorine", 2, true)
ei_lib.recipe_add("ei-nitric-acid-uranium-235", "kr-chlorine", 10, true)
ei_lib.recipe_add("ei-nitric-acid-uranium-233", "kr-chlorine", 10, true)
ei_lib.recipe_add("ei-nitric-acid-plutonium-239", "kr-chlorine", 10, true)
ei_lib.recipe_add("ei-nitric-acid-thorium-232", "kr-chlorine", 10, true)
ei_lib.recipe_add("ei-bio-matter", "kr-chlorine", 2, true)

ei_lib.recipe_add("empty-antimatter-fuel-cell", "ei-empty-cryo-container", 1, false)
ei_lib.recipe_add("empty-antimatter-fuel-cell", "ei-clean-plating", 10, false)

ei_lib.recipe_add("solar-panel", "kr-quartz", 8, false)
ei_lib.recipe_add("electronic-circuit", "wood", 1, false)
ei_lib.recipe_add("ei-green-circuit-waver", "wood", 4, false)
ei_lib.recipe_add("ei-advanced-motor", "kr-rare-metals", 2, false)
ei_lib.recipe_add("ei-module-part", "kr-rare-metals", 4, false)

ei_lib.recipe_add("advanced-circuit", "kr-silicon", 1)

data.raw["recipe"]["kr-quartz"].ingredients = {
    {type = "item", name = "ei-sand", amount = 2},
    {type = "fluid", name = "water", amount = 20},
}

ei_lib.recipe_add("ei-semiconductor", "kr-silicon", 2)
ei_lib.recipe_add("ei-advanced-base-semiconductor", "kr-silicon", 4)
ei_lib.recipe_add("ei-silicon", "kr-silicon", 1)
ei_lib.recipe_add("ei-neutron-collector", "lithium", 15)
ei_lib.recipe_add("ei-fusion-reactor", "lithium", 100)
ei_lib.recipe_add("lithium-sulfur-battery", "battery", 1)
ei_lib.recipe_add("ei-fusion-data", "lithium", 2)

data.raw["recipe"]["kr-ai-core"].ingredients = {
  {type = "item", name = "processing-unit", amount = 1},
  {type = "item", name = "kr-imersite-crystal", amount = 4},
  {type = "item", name = "ei-computing-unit", amount = 1},
}

ei_lib.recipe_add("ei-superior-data", "kr-ai-core", 1)
ei_lib.recipe_add("ei-plasma-data-tritium", "kr-ai-core", 1)
ei_lib.recipe_add("ei-plasma-data-deuterium", "kr-ai-core", 1)
ei_lib.recipe_add("ei-plasma-data-protium", "kr-ai-core", 1)
ei_lib.recipe_add("ei-magnet-data", "kr-ai-core", 1)
ei_lib.recipe_add("ei-fusion-data", "kr-ai-core", 1)

ei_lib.recipe_add("ei-odd-plating", "kr-imersite-crystal", 1)

ei_lib.recipe_add("ei-energy-crystal-growing", "kr-quartz", 1)

ei_lib.add_unlock_recipe("kr-bio-processing", "ei-bio-matter-biomass")
ei_lib.add_unlock_recipe("kr-imersium-processing", "ei-imersium-beam-metalworks")
ei_lib.add_unlock_recipe("kr-imersium-processing", "ei-imersium-gear-wheel-metalworks")

ei_lib.recipe_add("kr-imersium-beam", "steel-plate", 1)
ei_lib.recipe_add("kr-imersium-gear-wheel", "ei-steel-mechanical-parts", 4)

data.raw.technology["kr-automation"].effects = {
    { type = "unlock-recipe", recipe = "kr-advanced-assembling-machine" },
}

ei_lib.recipe_add("ei-sus-plating", "kr-rare-metals", 1)



-- chemistry changes
-------------------------------------------------------------------------------
ei_lib.add_unlock_recipe("kr-fluids-chemistry", "kr-water-separation")
ei_lib.remove_unlock_recipe("kr-advanced-chemistry", "kr-water-separation")
ei_lib.remove_unlock_recipe("kr-advanced-chemistry", "kr-ammonia")
ei_lib.add_prerequisite("kr-advanced-chemistry", "ei-nitric-acid")

data.raw.technology["kr-atmosphere-condensation"].effects = {
    { type = "unlock-recipe", recipe = "kr-atmospheric-condenser" },
    { type = "unlock-recipe", recipe = "ei-water-from-atmosphere" },
}

ei_lib.add_unlock_recipe("oil-processing", "chemical-plant")
ei_lib.remove_unlock_recipe("kr-fluids-chemistry", "kr-filtration-plant")
ei_lib.remove_unlock_recipe("kr-fluids-chemistry", "chemical-plant")

ei_lib.add_prerequisite("speed-module", "kr-mineral-water-gathering")
ei_lib.add_prerequisite("productivity-module", "kr-mineral-water-gathering")
ei_lib.add_prerequisite("effectivity-module", "kr-mineral-water-gathering")





-- fuel and vehicles
-------------------------------------------------------------------------------
data.raw["locomotive"]["ei-steam-advanced-locomotive"].energy_source.fuel_categories = {
    "chemical",
    "kr-vehicle-fuel"
}

data.raw["locomotive"]["locomotive"].energy_source.fuel_categories = {
    "ei-diesel-fuel",
    "ei-rocket-fuel"
}

data.raw["locomotive"]["kr-nuclear-locomotive"].energy_source.fuel_categories = {
    "ei-nuclear-fuel",
    "ei-fusion-fuel"
}

for _, spider in pairs(data.raw["spider-vehicle"]) do
    spider.energy_source = {
        type = "burner",
        fuel_categories = {"chemical", "ei-nuclear-fuel", "ei-fusion-fuel"},
        effectivity = 1,
        fuel_inventory_size = 3,
        burnt_inventory_size = 3,
    }
    spider.movement_energy_consumption = "1.0MW"
end

ei_lib.recipe_add("ei-diesel-fuel-unit", "kr-fuel", 1)



-- nuclear and steam reset
-------------------------------------------------------------------------------
data.raw["boiler"]["ei-fluid-boiler"].energy_consumption = "1.5MW"

-- also increase energy usage of injector pylons to 10GW each
data.raw["assembling-machine"]["ei-energy-injector-pylon"].energy_usage = "10GW"

-- make pump not use energy
data.raw["pump"]["pump"].energy_source = {
    type = 'void'
}

if data.raw["assembling-machine"]["kr-electric-offshore-pump"] then 
  data.raw["assembling-machine"]["kr-electric-offshore-pump"].energy_source = {type = 'void'}
end

-- tech cost fixup
-------------------------------------------------------------------------------

-- loop over all techs and set their cost to 10 if they dont ignore tech multiplier
for tech_name, tech in pairs(data.raw.technology) do

    if ei_lib.config("no-tech-scaling") then goto continue end

    if tech.ignore_tech_cost_multiplier == true then
        goto continue
    end

    if not tech.unit then
        goto continue
    end

    if not tech.unit.count then
        goto continue
    end

    tech.unit.count = ei_lib.config("tech-scaling-startPrice")

    ::continue::
end

-- fix ammos
-------------------------------------------------------------------------------

if settings.startup["kr-realistic-weapons"].value then
    data.raw["ammo"]["firearm-magazine"].ammo_type.category = "pistol-ammo"
    data.raw["ammo"]["piercing-rounds-magazine"].ammo_type.category = "pistol-ammo"
end
