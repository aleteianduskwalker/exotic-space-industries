--====================================================================================================
-- POWERED BEACONS AND SPECIAL FLUID HANDLING
--====================================================================================================
-- 1) Copper/iron beacons are only active while their hidden slave consumer has energy.
-- 2) Regular pipes/tanks react to "special" fluids:
--      * computing power in a regular or insulated pipe -> the pipe explodes
--        (data is only meant to travel through data cables, see prototypes/computer_age/data-pipe.lua)
--      * liquid nitrogen/oxygen in a non-insulated pipe -> evaporates into its gas form
--      * heated plasma ("ei-heated-*") in a non-insulated pipe -> the pipe explodes
-- Both updaters are round-robin: every call processes exactly one registered entity.
--====================================================================================================

local util = require("scripts/control/util")

local model = {}

local COMPUTING_POWER = "ei-computing-power"

-- liquid -> gas conversions for non-insulated pipes
local EVAPORATION = {
    ["ei-liquid-nitrogen"] = "ei-nitrogen-gas",
    ["ei-liquid-oxygen"] = "ei-oxygen-gas",
}

--FLUID HANDLING
------------------------------------------------------------------------------------------------------

---Returns true if the given pipe/tank is an insulated one (may carry cryogenic/hot fluids).
local function is_insulated(entity)
    return string.sub(entity.name, 1, 12) == "ei-insulated"
end

---Destroys the entity after removing the offending fluid (plays the death explosion).
local function explode(entity, fluid_name, amount)
    entity.remove_fluid({name = fluid_name, amount = amount})
    entity.die(entity.force)
end

---Applies the special fluid rules to one pipe/tank.
---@param entity LuaEntity
local function check_fluid_entity(entity)
    local contents = entity.get_fluid_contents()

    -- computing power may never be carried by regular or insulated pipes
    local data_amount = contents[COMPUTING_POWER]
    if data_amount and data_amount > 0 then
        explode(entity, COMPUTING_POWER, data_amount)
        return
    end

    -- insulated pipes can carry everything else safely
    if is_insulated(entity) then
        return
    end

    for fluid_name, amount in pairs(contents) do
        if amount > 0 then
            local gas = EVAPORATION[fluid_name]
            if gas then
                entity.remove_fluid({name = fluid_name, amount = amount})
                entity.insert_fluid({name = gas, amount = amount})
            elseif string.find(fluid_name, "ei-heated-", 1, true) then
                explode(entity, fluid_name, amount)
                return
            end
        end
    end
end

---Round-robin update of one registered fluid entity.
---@return boolean did_work false when there is nothing registered
function model.update_fluid_storages()
    local fluid_entities = storage.ei.fluid_entity
    if not fluid_entities then
        return false
    end

    local key = util.next_key(fluid_entities, storage.ei.fluid_break_point)
    storage.ei.fluid_break_point = key
    if key == nil then
        return false
    end

    local entity = fluid_entities[key]
    if entity and entity.valid then
        check_fluid_entity(entity)
    else
        -- entity vanished without a destroy event (e.g. removed by another mod)
        fluid_entities[key] = nil
    end

    return true
end

---Returns true if the entity should be registered for special fluid handling.
---Data cables are excluded: they have their own filter and connection category.
---@param entity LuaEntity
function model.counts_for_fluid_handling(entity)
    local entity_type = entity.type
    if entity_type ~= "pipe" and entity_type ~= "storage-tank" and entity_type ~= "pipe-to-ground" then
        return false
    end
    return string.sub(entity.name, 1, 7) ~= "ei-data"
end

--POWERED BEACONS
------------------------------------------------------------------------------------------------------

---Beacon is active only while its slave consumer has energy.
local function update_beacon(slave_entity, master_entity)
    if not (slave_entity and slave_entity.valid and master_entity and master_entity.valid) then
        return
    end
    master_entity.active = slave_entity.energy > 0
end

---Round-robin update of one registered copper/iron beacon.
---@return boolean did_work
function model.update()
    local registry = storage.ei.copper_beacon
    if not registry or not registry.master then
        return false
    end

    local key = util.next_key(registry.master, registry.script_break_point)
    registry.script_break_point = key
    if key == nil then
        return false
    end

    local master_data = registry.master[key]
    local slave_unit = master_data.slaves and master_data.slaves.slave_assembler
    local slave_data = slave_unit and registry.slave[slave_unit]

    if master_data.entity and master_data.entity.valid then
        update_beacon(slave_data and slave_data.entity, master_data.entity)
    else
        -- stale entry: clean it up (and the slave with it)
        if slave_data and slave_data.entity and slave_data.entity.valid then
            slave_data.entity.destroy()
        end
        if slave_unit then
            registry.slave[slave_unit] = nil
        end
        registry.master[key] = nil
    end

    return true
end

return model
