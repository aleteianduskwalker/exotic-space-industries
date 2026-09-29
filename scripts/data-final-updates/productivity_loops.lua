--====================================================================================================
-- PRODUCTIVITY LOOP GUARD
--====================================================================================================
-- Remelting creates loops: plate -> molten metal -> plate (arc furnace + caster, foundry, other
-- mods' melting recipes, ...). As soon as any step of such a loop receives productivity
-- (foundry base productivity, modules, beacons, productivity research) the loop generates
-- endless metal ("foundry productivity allows infinite copper/iron/steel/gold").
--
-- This guard finds such loops in the final prototype data and disables productivity on every
-- recipe that is part of one:
--   * 1 step:  item X --melt--> fluid F --cast--> item X
--   * 2 steps: item X --craft--> item Y --melt--> fluid F --cast--> item X
-- A loop is considered dangerous when its yield could reach 100% with the maximum possible
-- productivity bonus (+300% per recipe by default).
-- Casting from ore (the normal way) is unaffected unless the same fluid can also be obtained
-- by remelting the cast product.
--====================================================================================================

local MAX_PRODUCTIVITY_FACTOR = 4 -- 1 + default maximum productivity (300%)

---Average produced amount of a result entry (amount / amount_min..max, probability).
local function result_amount(result)
    local amount = result.amount or result[2]
    if not amount and result.amount_min and result.amount_max then
        amount = (result.amount_min + result.amount_max) / 2
    end
    return (amount or 1) * (result.probability or 1)
end

---Name and type of a recipe entry (full or short format).
local function entry(entry_table)
    return entry_table.name or entry_table[1], entry_table.type or "item"
end

local function is_candidate(recipe)
    return recipe.category ~= "recycling" and recipe.results and recipe.ingredients
end

-- MELT: exactly one item ingredient (no fluid ingredients) -> fluid results
-- melt[item][fluid] = {{recipe = name, ratio = fluid_out / item_in}, ...}
local melt = {}
-- CAST: fluid ingredient -> item result
-- cast[fluid][item] = {{recipe = name, ratio = item_out / fluid_in}, ...}
local cast = {}
-- CRAFT: exactly one item ingredient -> item result (used for 2 step loops)
-- craft[item_out][item_in] = {{recipe = name, ratio = out / in}, ...}
local craft = {}

local function add(registry, key_1, key_2, value)
    registry[key_1] = registry[key_1] or {}
    registry[key_1][key_2] = registry[key_1][key_2] or {}
    table.insert(registry[key_1][key_2], value)
end

for recipe_name, recipe in pairs(data.raw.recipe) do
    if is_candidate(recipe) then
        local item_ingredients = {}
        local fluid_ingredients = {}
        for _, ingredient in pairs(recipe.ingredients) do
            local name, kind = entry(ingredient)
            local amount = ingredient.amount or ingredient[2] or 1
            if kind == "fluid" then
                table.insert(fluid_ingredients, {name = name, amount = amount})
            else
                table.insert(item_ingredients, {name = name, amount = amount})
            end
        end

        for _, result in pairs(recipe.results) do
            local name, kind = entry(result)
            local amount = result_amount(result)

            if kind == "fluid" and #fluid_ingredients == 0 and #item_ingredients == 1 then
                local input = item_ingredients[1]
                add(melt, input.name, name, {recipe = recipe_name, ratio = amount / input.amount})
            elseif kind ~= "fluid" then
                for _, input in pairs(fluid_ingredients) do
                    add(cast, input.name, name, {recipe = recipe_name, ratio = amount / input.amount})
                end
                if #fluid_ingredients == 0 and #item_ingredients == 1 and item_ingredients[1].name ~= name then
                    local input = item_ingredients[1]
                    add(craft, name, input.name, {recipe = recipe_name, ratio = amount / input.amount})
                end
            end
        end
    end
end

local loop_recipes = {}

---Marks recipes of a loop if the loop can reach >= 100% yield with maximum productivity.
local function check_loop(yield, steps, recipes)
    if yield * MAX_PRODUCTIVITY_FACTOR ^ steps >= 1 then
        for _, recipe_name in pairs(recipes) do
            loop_recipes[recipe_name] = true
        end
    end
end

for item, fluids in pairs(melt) do
    for fluid, melt_recipes in pairs(fluids) do
        local casts_by_item = cast[fluid]
        if casts_by_item then
            for _, melt_recipe in pairs(melt_recipes) do
                -- 1 step: X -> F -> X
                for _, cast_recipe in pairs(casts_by_item[item] or {}) do
                    check_loop(melt_recipe.ratio * cast_recipe.ratio, 2, {melt_recipe.recipe, cast_recipe.recipe})
                end

                -- 2 steps: X -> Y (= item) -> F -> X
                for source_item, craft_recipes in pairs(craft[item] or {}) do
                    for _, cast_recipe in pairs(casts_by_item[source_item] or {}) do
                        for _, craft_recipe in pairs(craft_recipes) do
                            check_loop(craft_recipe.ratio * melt_recipe.ratio * cast_recipe.ratio, 3,
                                {craft_recipe.recipe, melt_recipe.recipe, cast_recipe.recipe})
                        end
                    end
                end
            end
        end
    end
end

for recipe_name, _ in pairs(loop_recipes) do
    local recipe = data.raw.recipe[recipe_name]
    if recipe.allow_productivity then
        log("Exotic Space Industries: disabled productivity for " .. recipe_name .. " (part of a remelting loop)")
    end
    recipe.allow_productivity = false
end

-- productivity research must not target these recipes either
for _, technology in pairs(data.raw.technology) do
    local effects = technology.effects
    if effects then
        for i = #effects, 1, -1 do
            local effect = effects[i]
            if effect.type == "change-recipe-productivity" and loop_recipes[effect.recipe] then
                table.remove(effects, i)
            end
        end
    end
end
