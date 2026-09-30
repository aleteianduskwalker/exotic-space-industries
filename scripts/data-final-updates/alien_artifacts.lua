--====================================================================================================
-- BROKEN ALIEN ARTIFACTS (3.2.0)
--====================================================================================================
-- Broken (unrepaired) artifacts of the Gaia ruins (the repair tool targets of lib/data.lua):
--   * salvage: mining / deconstructing them yields a small random amount of high tier resources
--     (minable.results) and destroying them spills the same resources (loot) instead of the ruin
--     item; alien knowledge for salvaging on Gaia is granted at runtime (alien_system.lua)
--   * lightning: 100 % electric resistance, Gaia storms can not destroy the ruins
--   * their items are hidden: the ruins can not be picked up anymore
-- Loot tables: lib/balance.lua -> artifact_salvage (keyed by the entity name prefix).
--====================================================================================================

local ei_data = require("lib/data")
local ei_balance = require("lib/balance")

---Returns the salvage table of a broken artifact (matched by its name prefix).
---@param entity_name string
local function salvage_table(entity_name)
    for prefix, results in pairs(ei_balance.artifact_salvage) do
        if string.sub(entity_name, 1, #prefix) == prefix then
            return results
        end
    end
end

---Finds the prototype of a broken artifact (any entity type).
---@param name string
local function find_entity(name)
    for _, prototype_type in pairs({"simple-entity-with-owner", "simple-entity", "assembling-machine", "container", "electric-energy-interface", "beacon", "accumulator"}) do
        local prototype = data.raw[prototype_type] and data.raw[prototype_type][name]
        if prototype then
            return prototype
        end
    end
end

for _, tool in pairs(ei_data.repair_tools) do
    for entity_name, _ in pairs(tool.targets) do
        local entity = find_entity(entity_name)
        local results = salvage_table(entity_name)

        if entity and results then
            -- mining: random high tier resources instead of the ruin itself
            local minable_results, loot = {}, {}
            for _, result in ipairs(results) do
                local item_name, min, max, probability = result[1], result[2], result[3], result[4]
                if data.raw.item[item_name] then
                    table.insert(minable_results, {
                        type = "item", name = item_name,
                        amount_min = min, amount_max = max, probability = probability,
                    })
                    table.insert(loot, {item = item_name, count_min = min, count_max = max, probability = probability})
                end
            end
            entity.minable = entity.minable or {mining_time = 1}
            entity.minable.result = nil
            entity.minable.count = nil
            entity.minable.results = minable_results
            -- destruction: the same resources are spilled on the ground
            entity.loot = loot

            -- immune to lightning (electric damage)
            entity.resistances = entity.resistances or {}
            local has_electric = false
            for _, resistance in pairs(entity.resistances) do
                if resistance.type == "electric" then
                    resistance.percent, resistance.decrease = 100, 0
                    has_electric = true
                end
            end
            if not has_electric then
                table.insert(entity.resistances, {type = "electric", percent = 100})
            end

            -- the ruin item can not be obtained anymore
            if data.raw.item[entity_name] then
                data.raw.item[entity_name].hidden = true
            end
        end
    end
end
