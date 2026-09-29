--====================================================================================================
-- DATA CENTER RECIPES (data-final-fixes, must run AFTER labs.lua)
--====================================================================================================
-- Generates for the data center (prototypes/computer_age/data-center.lua):
--   1) the building recipe "ei-data-center": a copy of the current ei-big-lab recipe ingredients
--      (table.deepcopy - never share the ingredient table)
--   2) one recipe "ei-data-center-<pack>" per science pack the big lab accepts:
--        ingredients: ei-computing-power only (balance: computing_power_per_pack * amount)
--        results:     the same amount as the original recipe of that pack
--        time:        original energy_required * balance.time_multiplier (10x slower)
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

---Finds the regular production recipe of an item: the recipe with the same name first, then any
---non-recycling recipe that produces it. Returns recipe, produced amount (or nil).
---@param item_name string
local function find_source_recipe(item_name)
    ---@return number|nil amount of item_name among the results
    local function produced_amount(recipe)
        for _, result in pairs(recipe.results or {}) do
            if result.name == item_name then
                return result.amount or result.amount_max or 1
            end
        end
    end

    local same_name = data.raw.recipe[item_name]
    if same_name and produced_amount(same_name) then
        return same_name, produced_amount(same_name)
    end

    for name, recipe in pairs(data.raw.recipe) do
        if recipe.category ~= "recycling" and string.sub(name, 1, 15) ~= "ei-data-center-" then
            local amount = produced_amount(recipe)
            if amount then
                return recipe, amount
            end
        end
    end
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

-- 2) one recipe per science pack
for _, pack_name in pairs(big_lab.inputs) do
    local pack = data.raw.tool[pack_name]
    local allowed = pack and not pack.hidden and (balance.include_alien_packs or not ALIEN_PACKS[pack_name])

    if allowed then
        local source, amount = find_source_recipe(pack_name)
        amount = amount or 1
        local time = (source and source.energy_required or balance.fallback_time) * balance.time_multiplier

        local recipe_name = "ei-data-center-"..pack_name
        data:extend({{
            name = recipe_name,
            type = "recipe",
            localised_name = {"recipe-name.ei-data-center-pack", pack.localised_name or {"item-name."..pack_name}},
            category = "ei-data-center",
            energy_required = time,
            ingredients = {
                {type = "fluid", name = "ei-computing-power", amount = balance.computing_power_per_pack * amount},
            },
            results = {{type = "item", name = pack_name, amount = amount}},
            enabled = false,
            allow_productivity = false,
            always_show_made_in = true,
            order = (pack.order or "z").."-data-center",
        }})
        unlock(recipe_name)
    end
end
