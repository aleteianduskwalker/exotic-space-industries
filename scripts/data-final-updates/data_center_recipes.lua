--====================================================================================================
-- DATA CENTER RECIPES (data-final-fixes, must run AFTER labs.lua)
--====================================================================================================
-- Generates for the data center (prototypes/computer_age/data-center.lua):
--   1) the building recipe "ei-data-center": a copy of the current ei-big-lab recipe ingredients
--      (table.deepcopy - never share the ingredient table)
--   2) one recipe "ei-data-center-<pack>" per science pack the big lab accepts (3.2.0):
--        ingredients: 1 ei-computing-power per UNIQUE component (item or fluid) in the recursive
--                     production tree of the pack (its recipe, the recipes of its ingredients, ...)
--        results:     always exactly 1 pack
--        time:        original time per pack * balance.time_multiplier (10x slower)
--      The walk expands every component only once (no endless recursion on loops) and gives up
--      when it gets too deep / too large; then balance.fallback_computing_power (100) is used.
-- All recipes are unlocked by the technology "ei-data-center".
--====================================================================================================

local ei_balance = require("lib/balance")
local balance = ei_balance.data_center

local technology = data.raw.technology["ei-data-center"]
local big_lab = data.raw.lab["ei-big-lab"]
if not (technology and big_lab and data.raw["assembling-machine"]["ei-data-center"]) then
    return
end

-- the mod's own alien packs (can be excluded with balance.include_alien_packs = false)
local ALIEN_PACKS = {
    ["ei-alien-computer-age-tech"] = true,
    ["ei-alien-resonance-pack"] = true,
}

--RECIPE INDEX
------------------------------------------------------------------------------------------------------

---Returns true if a recipe can be used to find out how a component is produced.
---Recycling, barrel (un)filling, hidden/parameter recipes and the data center's own recipes would
---only create fake loops or shortcuts.
---@param name string
---@param recipe table
local function is_production_recipe(name, recipe)
    return recipe.category ~= "recycling"
        and not recipe.hidden
        and not recipe.parameter
        and string.sub(name, 1, 15) ~= "ei-data-center-"
        and not string.find(name, "barrel", 1, true)
end

---Amount of `product` among the results of a recipe (nil if it is not produced).
local function produced_amount(recipe, product)
    for _, result in pairs(recipe.results or {}) do
        if result.name == product then
            return result.amount or result.amount_max or 1
        end
    end
end

-- product name -> sorted list of production recipe names (built once, deterministic order)
local producers = {}
for name, recipe in pairs(data.raw.recipe) do
    if is_production_recipe(name, recipe) then
        for _, result in pairs(recipe.results or {}) do
            if result.name then
                producers[result.name] = producers[result.name] or {}
                table.insert(producers[result.name], name)
            end
        end
    end
end
for _, list in pairs(producers) do
    table.sort(list)
end

---Finds the regular production recipe of a component: the recipe with the same name first, then
---the alphabetically first production recipe. Returns recipe, produced amount (or nil).
---@param component_name string
local function find_source_recipe(component_name)
    local same_name = data.raw.recipe[component_name]
    if same_name and is_production_recipe(component_name, same_name) and produced_amount(same_name, component_name) then
        return same_name, produced_amount(same_name, component_name)
    end

    local list = producers[component_name]
    if list and list[1] then
        local recipe = data.raw.recipe[list[1]]
        return recipe, produced_amount(recipe, component_name)
    end
end

---Counts the unique components (items and fluids) needed to produce a science pack, walking the
---production recipes recursively. Returns balance.fallback_computing_power when the walk exceeds
---the depth / size limits or the pack has no production recipe at all.
---@param pack_name string
---@return integer computing_power
local function count_unique_components(pack_name)
    local counted = {}      -- component name -> true (every unique component counts once)
    local expanded = {}     -- component name -> true (its recipe was already walked: loop guard)
    local count = 0
    local inspected_recipes = 0
    local aborted = false

    local function walk(component_name, depth)
        if aborted or expanded[component_name] then
            return
        end
        if depth > balance.max_depth then
            aborted = true
            return
        end
        expanded[component_name] = true

        local recipe = find_source_recipe(component_name)
        if not recipe then
            return -- raw resource (ore, water, ...): counted by its consumer, nothing to expand
        end

        inspected_recipes = inspected_recipes + 1
        if inspected_recipes > balance.max_visited_recipes then
            aborted = true
            return
        end

        for _, ingredient in pairs(recipe.ingredients or {}) do
            local name = ingredient.name
            if name and name ~= pack_name then
                if not counted[name] then
                    counted[name] = true
                    count = count + 1
                    if count > balance.max_components then
                        aborted = true
                        return
                    end
                end
                walk(name, depth + 1)
            end
        end
    end

    walk(pack_name, 0)

    if aborted or count == 0 then
        return balance.fallback_computing_power
    end
    return count
end

---Adds an unlock effect to the data center technology.
local function unlock(recipe_name)
    technology.effects = technology.effects or {}
    table.insert(technology.effects, {type = "unlock-recipe", recipe = recipe_name})
end

-- 1) building recipe: copy of the big lab recipe
local big_lab_recipe = data.raw.recipe["ei-big-lab"]
data:extend({{
    name = "ei-data-center",
    type = "recipe",
    category = "crafting",
    energy_required = big_lab_recipe and big_lab_recipe.energy_required or 20,
    ingredients = table.deepcopy(big_lab_recipe and big_lab_recipe.ingredients or {{type = "item", name = "lab", amount = 10}}),
    results = {{type = "item", name = "ei-data-center", amount = 1}},
    enabled = false,
    main_product = "ei-data-center",
}})
unlock("ei-data-center")

-- 2) one recipe per science pack: always 1 pack, 1 computing power per unique component
for _, pack_name in pairs(big_lab.inputs) do
    local pack = data.raw.tool[pack_name]
    local allowed = pack and not pack.hidden and (balance.include_alien_packs or not ALIEN_PACKS[pack_name])

    if allowed then
        local source, amount = find_source_recipe(pack_name)
        -- time per single pack of the original recipe, 10x slower
        local time_per_pack = source and (source.energy_required or 0.5) / math.max(amount or 1, 1) or balance.fallback_time
        local computing_power = count_unique_components(pack_name)

        local recipe_name = "ei-data-center-"..pack_name
        data:extend({{
            name = recipe_name,
            type = "recipe",
            localised_name = {"recipe-name.ei-data-center-pack", pack.localised_name or {"item-name."..pack_name}},
            localised_description = {"recipe-description.ei-data-center-pack", tostring(computing_power)},
            category = "ei-data-center",
            energy_required = time_per_pack * balance.time_multiplier,
            ingredients = {
                {type = "fluid", name = "ei-computing-power", amount = computing_power},
            },
            results = {{type = "item", name = pack_name, amount = 1}},
            main_product = pack_name,
            enabled = false,
            allow_productivity = false,
            always_show_made_in = true,
            order = (pack.order or "z").."-data-center",
        }})
        unlock(recipe_name)
    end
end
