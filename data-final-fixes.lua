--====================================================================================================
-- DATA FINAL FIXES
--====================================================================================================

ei_mod.stage = "data-final-updates"
local ei_lib = require("lib/lib")

--====================================================================================================
--FINAL FIXES
--====================================================================================================

require("scripts/data-final-updates/final-tech-fixes")
require("scripts/data-final-updates/final-recipe-fixes")
require("scripts/data-final-updates/set_age_packs")
require("scripts/data-final-updates/set_prerequisites")
require("scripts/data-final-updates/tiles")
require("scripts/data-final-updates/items")

--====================================================================================================
--COMPATIBILITY
--====================================================================================================

require("scripts/data-final-updates/compatibility")
require("scripts/data-final-updates/labs")
-- data center: one recipe per science pack of the big lab (needs the final lab inputs of labs.lua)
require("scripts/data-final-updates/data_center_recipes")

--====================================================================================================
--FUELS
--====================================================================================================

data.raw.reactor["ei-burner-heater"].energy_source.fuel_categories = {"chemical"}
data.raw.item.wood.fuel_category = "chemical"
data.raw.item.coal.fuel_category = "chemical"

--====================================================================================================
--SPACE PLATFORMS
--====================================================================================================

-- thrusters may be placed further away from the platform edge
for _, thruster in pairs(data.raw.thruster) do
    local rules = thruster.tile_buildability_rules
    if rules and rules[2] and rules[2].area and rules[2].area[2] then
        rules[2].area[2][2] = 15.0
    end
end

data.raw["space-platform-starter-pack"]["space-platform-starter-pack"].initial_items = {
    {type = "item", name = "space-platform-foundation", amount = 2000},
}

--====================================================================================================
--ENTITY TWEAKS
--====================================================================================================

-- every ammo turret gets at least 5 ammo slots
for _, ammo_turret in pairs(data.raw["ammo-turret"]) do
    if (ammo_turret.inventory_size or 0) < 5 then
        ammo_turret.inventory_size = 5
    end
end

-- biolab runs on nutrients like the biochamber
data.raw.lab.biolab.energy_source = table.deepcopy(data.raw["assembling-machine"].biochamber.energy_source)
data.raw.lab.biolab.energy_source.light_flicker = nil

-- large foundry fluid buffers
data.raw["assembling-machine"]["foundry"].fluid_boxes[3].volume = 5000
data.raw["assembling-machine"]["foundry"].fluid_boxes[4].volume = 5000

-- the steam assembler can craft everything the assembling machine 1 can
local steam_assembler = data.raw["assembling-machine"]["ei-steam-assembler"]
steam_assembler.crafting_categories = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-1"].crafting_categories)
for _, crafting_category in pairs({"ei-steam-assembler", "crafting", "crafting-with-fluid", "electronics"}) do
    if not ei_lib.table_contains_value(steam_assembler.crafting_categories, crafting_category) then
        table.insert(steam_assembler.crafting_categories, crafting_category)
    end
end

-- oil ocean can be pumped for crude oil
data.raw.tile["oil-ocean-shallow"].fluid = "crude-oil"
data.raw.tile["oil-ocean-deep"].fluid = "crude-oil"

-- artificial soils can be placed everywhere
for _, soil in pairs({"artificial-jellynut-soil", "overgrowth-jellynut-soil", "artificial-yumako-soil", "overgrowth-yumako-soil"}) do
    local place_as_tile = data.raw.item[soil] and data.raw.item[soil].place_as_tile
    if place_as_tile then
        place_as_tile.condition_size = 1
        place_as_tile.tile_condition = nil
        place_as_tile.condition = place_as_tile.condition or {}
        place_as_tile.condition.layers = {}
    end
end

-- burner inserters can refuel themselves from what they carry
for _, inserter in pairs(data.raw.inserter) do
    if inserter.energy_source and inserter.energy_source.type == "burner" then
        inserter.allow_burner_leech = true
    end
end

-- no animation speed matching; recyclers and crushers work on every surface
for _, machine_type in pairs({"assembling-machine", "furnace", "mining-drill"}) do
    for _, prototype in pairs(data.raw[machine_type] or {}) do
        if ei_lib.contains(prototype.name, "recycler") or ei_lib.contains(prototype.name, "crusher") then
            prototype.surface_conditions = nil
        end
        prototype.match_animation_speed_to_activity = false
    end
end

-- Gaia variant of the crystal accumulator: mined as the regular accumulator, so the boosted variant
-- can not be moved away from Gaia (the runtime script swaps both variants depending on the surface)
local gaia_accumulator = data.raw["electric-energy-interface"]["ei-crystal-accumulator-gaia"]
if gaia_accumulator then
    gaia_accumulator.minable.result = "ei-crystal-accumulator"
    gaia_accumulator.placeable_by = {item = "ei-crystal-accumulator", count = 1}
    if data.raw.item["ei-crystal-accumulator-gaia"] then
        data.raw.item["ei-crystal-accumulator-gaia"].hidden = true
    end
end

--====================================================================================================
--TECHNOLOGIES
--====================================================================================================

-- remove hidden technologies from prerequisite lists (backwards, removing shifts the indices)
for _, tech in pairs(data.raw.technology) do
    local prerequisites = tech.prerequisites
    if prerequisites then
        for i = #prerequisites, 1, -1 do
            local prerequisite = data.raw.technology[prerequisites[i]]
            if prerequisite and prerequisite.hidden then
                table.remove(prerequisites, i)
            end
        end
    end
end

--====================================================================================================
--LIGHTNING (Gaia storms)
--====================================================================================================

for name, _ in pairs(data.raw["lightning-attractor"]) do
    data.raw["lightning-attractor"][name].resistances = {}
    for damage_type, _ in pairs(data.raw["damage-type"]) do
        table.insert(data.raw["lightning-attractor"][name].resistances, {type = damage_type, percent = 100})
    end
end

data.raw["lightning-attractor"]["fulgoran-ruin-attractor"].range_elongation = 25

for _, lightning in pairs(data.raw["lightning"]) do
    lightning.attracted_volume_modifier = 0.0
    lightning.damage = lightning.damage * 2.0
end

-- Storm EMP (design doc §7): every strike raises the script event "ei-storm-emp".
-- scripts/control/storm_emp.lua decides at runtime whether it counts (Gaia only, not near an
-- attractor) and temporarily disables machines around the impact.
local STORM_EMP_TRIGGER = {
    type = "direct",
    action_delivery = {
        type = "instant",
        target_effects = {{type = "script", effect_id = "ei-storm-emp"}},
    },
}

---Appends the EMP trigger to a lightning strike_effect (Trigger: a single item or an array).
---@param strike_effect table|nil
local function add_storm_emp(strike_effect)
    if strike_effect == nil then
        return {STORM_EMP_TRIGGER}
    end
    if strike_effect.type then -- single trigger item -> array of trigger items
        return {strike_effect, STORM_EMP_TRIGGER}
    end
    table.insert(strike_effect, STORM_EMP_TRIGGER)
    return strike_effect
end

for _, lightning in pairs(data.raw["lightning"]) do
    lightning.strike_effect = add_storm_emp(lightning.strike_effect)
end

--====================================================================================================
--TREES AND PLANTS
--====================================================================================================

-- trees give twice the wood
for _, tree in pairs(data.raw.tree) do
    local results = tree.minable and tree.minable.results
    for _, result in ipairs(results or {}) do
        if result.amount_min and result.amount_max then
            result.amount_min = result.amount_min * 2
            result.amount_max = result.amount_max * 2
        end
        if result.amount then
            result.amount = result.amount * 2
        end
    end
end

-- planted trees give at least 10 of each result
for name, plant in pairs(data.raw.plant) do
    local results = plant.minable and plant.minable.results
    if results and ei_lib.contains(name, "tree") then
        for _, result in ipairs(results) do
            if result.amount and result.amount < 10 then
                result.amount = 10
            end
        end
    end
end

--====================================================================================================
--SCRAP RECYCLING (Fulgora)
--====================================================================================================

data.raw["furnace"]["recycler"].result_inventory_size = 20

-- probabilities are per scrap; battery is kept at the vanilla 4 %
local SCRAP_RESULTS = {
    {"ei-iron-mechanical-parts", 0.1},
    {"ei-copper-mechanical-parts", 0.075},
    {"ei-steel-mechanical-parts", 0.05},

    {"iron-plate", 0.1},
    {"copper-plate", 0.075},
    {"steel-plate", 0.05},

    {"solid-fuel", 0.075},
    {"stone", 0.1},
    {"concrete", 0.05},
    {"ice", 0.15},

    {"electronic-circuit", 0.075},
    {"advanced-circuit", 0.05},
    {"processing-unit", 0.025},

    {"battery", 0.04},
    {"low-density-structure", 0.02},
    {"ei-alien-seed", 0.02},

    {"holmium-ore", 0.01},
    {"tungsten-ore", 0.01},

    {"calcite", 0.01},
    {"lithium", 0.01},
}

local scrap_results = {}
for _, result in ipairs(SCRAP_RESULTS) do
    -- skip items that were removed by other mods
    if data.raw.item[result[1]] then
        table.insert(scrap_results, {
            type = "item",
            name = result[1],
            amount = 1,
            probability = result[2],
            show_details_in_recipe_tooltip = false,
        })
    end
end
data.raw.recipe["scrap-recycling"].results = scrap_results

--====================================================================================================
--GUARDS (must run last)
--====================================================================================================

-- computing power only travels through data cables
require("scripts/data-final-updates/data_network")

-- Gaia terrain can not be broken by mods changing Fulgora / all planets
require("prototypes/alien_structures/gaia-map-gen").enforce_gaia_map_gen()

-- exoplanetary technologies do not need the early age packs (setting "debloat")
require("scripts/data-final-updates/tech_debloat")

-- remelting loops (plate -> molten -> plate) must not gain productivity
require("scripts/data-final-updates/productivity_loops")

-- technologies must not require science packs they unlock themselves
require("scripts/data-final-updates/tech_pack_cycles")
