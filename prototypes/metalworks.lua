--====================================================================================================
-- METALWORKS PROTOTYPES
--====================================================================================================

--ITEMS AND TECHS
------------------------------------------------------------------------------------------------------

data:extend({
    -- metalworks 1,2,3,4
    {
        name = "ei-metalworks-1",
        type = "item",
        icon = ei_graphics_item_path.."metalworks_1.png",
        icon_size = 64,
        subgroup = "production-machine",
        order = "a[assembling-machine-1]-a",
        place_result = "ei-metalworks-1",
        stack_size = 50
    },
    {
        name = "ei-metalworks-1",
        type = "recipe",
        categories = {"crafting"},
        energy_required = 0.5,
        ingredients =
        {
            {type="item", name="assembling-machine-1", amount=1},
            {type="item", name="electric-engine-unit", amount=4},
            {type="item", name="ei-iron-mechanical-parts", amount=2},
        },
        results = {{type="item", name="ei-metalworks-1", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-metalworks-1",
    },
    {
        name = "ei-metalworks-2",
        type = "item",
        icon = ei_graphics_item_path.."metalworks_2.png",
        icon_size = 64,
        subgroup = "production-machine",
        order = "b[assembling-machine-2]-a",
        place_result = "ei-metalworks-2",
        stack_size = 50
    },
    {
        name = "ei-metalworks-2",
        type = "recipe",
        categories = {"crafting"},
        energy_required = 0.5,
        ingredients =
        {
            {type="item", name="assembling-machine-2", amount=1},
            {type="item", name="electric-engine-unit", amount=4},
            {type="item", name="ei-iron-mechanical-parts", amount=2},
        },
        results = {{type="item", name="ei-metalworks-2", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-metalworks-2",
    },
    {
        name = "ei-metalworks-3",
        type = "item",
        icon = ei_graphics_item_path.."metalworks_3.png",
        icon_size = 64,
        subgroup = "production-machine",
        order = "c[assembling-machine-3]-a",
        place_result = "ei-metalworks-3",
        stack_size = 50
    },
    {
        name = "ei-metalworks-3",
        type = "recipe",
        categories = {"crafting"},
        energy_required = 0.5,
        ingredients =
        {
            {type="item", name="assembling-machine-3", amount=1},
            {type="item", name="ei-advanced-motor", amount=4},
            {type="item", name="ei-steel-mechanical-parts", amount=2},
        },
        results = {{type="item", name="ei-metalworks-3", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-metalworks-3",
    },
    {
        name = "ei-metalworks-4",
        type = "item",
        icon = ei_graphics_item_path.."metalworks_4.png",
        icon_size = 64,
        subgroup = "production-machine",
        order = "c[assembling-machine-3]-c",
        place_result = "ei-metalworks-4",
        stack_size = 50
    },
    {
        name = "ei-metalworks-4",
        type = "recipe",
        categories = {"crafting"},
        energy_required = 0.5,
        ingredients =
        {
            {type="item", name="ei-neo-assembler", amount=1},
            {type="item", name="ei-advanced-motor", amount=4},
            {type="item", name="ei-steel-mechanical-parts", amount=2},
        },
        results = {{type="item", name="ei-metalworks-4", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-metalworks-4",
    },
    {
        name = "ei-metalworks",
        type = "recipe-category",
    }
})

--ENTITIES
------------------------------------------------------------------------------------------------------

local entity_base = {
    name = "ei-metalworks-1",
    type = "assembling-machine",
    icon = ei_graphics_item_path.."metalworks_1.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {
        mining_time = 0.5,
        result = "ei-metalworks-1"
    },
    max_health = 300,
    corpse = "big-remnants",
    dying_explosion = "medium-explosion",
    collision_box = {{-0.9, -0.9}, {0.9, 0.9}},
    selection_box = {{-1.0, -1.0}, {1.0, 1.0}},
    map_color = ei_data.colors.assembler,
    crafting_categories = {"ei-metalworks"},
    crafting_speed = 1,
    energy_source = {
        type = "electric",
        usage_priority = "secondary-input",
    },
    energy_usage = "150kW",
    fast_replaceable_group = "ei-metalworks",
    next_upgrade = "ei-metalworks-2",
    working_sound = {
        sound = {filename = "__base__/sound/electric-mining-drill.ogg", volume = 0.8},
        apparent_volume = 0.3,
    },
}


--- Scales sprite sizes and offsets in a copied graphics tree.
--- This keeps the metalworks compact while using the split animation layers introduced in Factorio 2.1.
---@param graphics_node table Sprite, animation, visualisation, or nested graphics table to scale.
---@param scale_factor number Multiplier applied to numeric sprite scales and position offsets.
---@return nil Nothing. The supplied graphics table is modified in place.
local function scale_graphics_tree(graphics_node, scale_factor)
    -- Ignore non-table values so nested animation metadata can be traversed safely.
    if type(graphics_node) ~= "table" then
        return
    end

    -- Apply the same scale multiplier to each sprite, including high-resolution variants.
    if type(graphics_node.scale) == "number" then
        graphics_node.scale = graphics_node.scale * scale_factor
    end

    -- Scale sprite offsets along with the art to keep the shadow and status lights aligned.
    local sprite_shift = graphics_node.shift
    if type(sprite_shift) == "table" then
        if type(sprite_shift[1]) == "number" and type(sprite_shift[2]) == "number" then
            sprite_shift[1] = sprite_shift[1] * scale_factor
            sprite_shift[2] = sprite_shift[2] * scale_factor
        elseif type(sprite_shift.x) == "number" and type(sprite_shift.y) == "number" then
            sprite_shift.x = sprite_shift.x * scale_factor
            sprite_shift.y = sprite_shift.y * scale_factor
        end
    end

    -- Traverse all nested graphics tables, including HR sprite variants and working visualisations.
    for _, nested_value in pairs(graphics_node) do
        if type(nested_value) == "table" then
            scale_graphics_tree(nested_value, scale_factor)
        end
    end
end


--- Creates a compact metalworks entity using a current vanilla or ESI graphics set.
--- The graphics set is copied before scaling so the source prototype remains unchanged.
---@param level number Metalworks tier, from 1 to 4.
---@param max_level number Highest tier in the upgrade chain.
---@param source_graphics_set table Graphics set copied from an existing assembling machine.
---@param mining_result string|nil Item returned when the entity is mined; defaults to the matching metalworks item.
---@return nil Registers the generated assembling-machine prototype in data.raw.
local function make_metalworks(level, max_level, source_graphics_set, mining_result)
    local entity = util.table.deepcopy(entity_base)
    entity.name = "ei-metalworks-"..level
    entity.icon = ei_graphics_item_path.."metalworks_"..level..".png"

    -- Keep the tier-specific look and animation composition from the matching modern prototype.
    entity.graphics_set = util.table.deepcopy(source_graphics_set)
    scale_graphics_tree(entity.graphics_set, 2 / 3)

    if mining_result then
        entity.minable.result = mining_result
    else
        entity.minable.result = "ei-metalworks-"..level
    end

    entity.crafting_speed = 0.75 + (level - 1) * 0.5
    entity.energy_usage = tostring(150 * level).."kW"

    -- Link each tier to the next one, leaving the highest tier without an upgrade.
    if level < max_level then
        entity.next_upgrade = "ei-metalworks-"..(level + 1)
    else
        entity.next_upgrade = nil
    end

    data:extend({entity})
end


make_metalworks(1, 4, data.raw["assembling-machine"]["assembling-machine-1"].graphics_set)
make_metalworks(2, 4, data.raw["assembling-machine"]["assembling-machine-2"].graphics_set)
make_metalworks(3, 4, data.raw["assembling-machine"]["assembling-machine-3"].graphics_set)
make_metalworks(4, 4, data.raw["assembling-machine"]["ei-neo-assembler"].graphics_set, "ei-metalworks-4")

-- add the metalworks to their respective techs
table.insert(
    data.raw["technology"]["automation"].effects,
    {type = "unlock-recipe", recipe = "ei-metalworks-1"}
)
table.insert(
    data.raw["technology"]["automation-2"].effects,
    {type = "unlock-recipe", recipe = "ei-metalworks-2"}
)
table.insert(
    data.raw["technology"]["automation-3"].effects,
    {type = "unlock-recipe", recipe = "ei-metalworks-3"}
)
table.insert(
    data.raw["technology"]["ei-neo-assembler"].effects,
    {type = "unlock-recipe", recipe = "ei-metalworks-4"}
)

-- add the new recipe category to
local recipes_to_add = {
    ["iron-plate"] = "none",
    ["iron-gear-wheel"] = "none",
    ["iron-stick"] = "none",
    ["barrel"] = "none",
    ["copper-plate"] = "none",
    ["ei-gold-ingot"] = "ei-deep-mining",
    ["ei-lead-ingot"] = "ei-deep-mining",
    ["ei-neodym-ingot"] = "ei-neodym-refining",
    ["ei-iron-mechanical-parts"] = "none",
    ["ei-copper-mechanical-parts"] = "none",
    ["ei-steel-mechanical-parts"] = "steel-processing",
    ["copper-cable"] = "electronics",
}

for recipe_name, tech in pairs(recipes_to_add) do
  local recipe = data.raw["recipe"][recipe_name]
  if recipe then 
    -- make a copy of the recipe and change the category
    local new_recipe = util.table.deepcopy(recipe)

    if tech ~= "none" then
      ei_lib.add_unlock_recipe(tech,recipe_name)
    end

    new_recipe.name = new_recipe.name.."-metalworks"
    new_recipe.categories = {"ei-metalworks"}
    new_recipe.hide_from_player_crafting = true

    if tech ~= "none" then
      -- add the new recipe to the tech
      table.insert(
        data.raw["technology"][tech].effects,
        {type = "unlock-recipe", recipe = new_recipe.name}
      )
    end

    if tech == "none" then new_recipe.enabled = true end

    -- add the new recipe to the data
    data:extend({new_recipe})
  end
end
