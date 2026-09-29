--====================================================================================================
-- MASTER / SLAVE REGISTRY
--====================================================================================================
-- Generic registry for compound entities (a visible "master" entity with hidden "slave" helpers).
--
-- storage layout, indexed by unit numbers:
--   storage.ei[key].master[master_unit] = {entity = LuaEntity, slaves = {slave_name = slave_unit}}
--   storage.ei[key].slave[slave_unit]   = {master = master_unit, entity = LuaEntity}
--
-- Example: copper beacon (master) with its hidden "ei-copper-beacon_slave" power consumer.
--====================================================================================================

local model = {}

---Returns the unit number for an entity or passes a unit number through unchanged.
---@param input LuaEntity|integer
---@return integer
local function get_unit(input)
    if type(input) == "number" then
        return input
    end
    return input.unit_number
end

---Returns the registry table storage.ei[key] (optionally its sub table) or nil if missing.
---@param key string registry name, e.g. "copper_beacon"
---@param sub_key string|nil "master" or "slave"
local function registry(key, sub_key)
    local ei = storage.ei
    if not ei or not ei[key] then
        return nil
    end
    if sub_key then
        return ei[key][sub_key]
    end
    return ei[key]
end

---Creates empty registries for the given keys (optionally with master/slave sub tables).
---@param keys string[]
---@param master_slave boolean
function model.init(keys, master_slave)
    storage.ei = storage.ei or {}
    for _, key in ipairs(keys) do
        storage.ei[key] = {}
        if master_slave then
            storage.ei[key].master = {}
            storage.ei[key].slave = {}
        end
    end
end

--FLUID ENTITIES (pipes/tanks checked by powered_beacon.update_fluid_storages)
------------------------------------------------------------------------------------------------------

function model.register_fluid_entity(entity)
    local fluid_entities = registry("fluid_entity")
    if fluid_entities and entity.unit_number then
        fluid_entities[entity.unit_number] = entity
    end
end

function model.deregister_fluid_entity(entity)
    local fluid_entities = registry("fluid_entity")
    if fluid_entities and entity.unit_number then
        fluid_entities[entity.unit_number] = nil
    end
end

--MASTER / SLAVE
------------------------------------------------------------------------------------------------------

---Registers a master entity; returns its unit number.
---@param key string
---@param entity LuaEntity
---@param extra table|nil additional fields copied into the master entry
---@return integer|nil
function model.register_master_entity(key, entity, extra)
    local masters = registry(key, "master")
    if not masters then
        return nil
    end

    local unit = entity.unit_number
    masters[unit] = {slaves = {}, entity = entity}

    if extra then
        for field, value in pairs(extra) do
            masters[unit][field] = value
        end
    end

    return unit
end

---Unregisters a master (entity or unit number). Returns true on success.
function model.unregister_master_entity(key, master)
    local masters = registry(key, "master")
    if not masters then
        return false
    end

    local unit = get_unit(master)
    if not masters[unit] then
        return false
    end

    masters[unit] = nil
    return true
end

---Unregisters a slave (entity or unit number) and optionally destroys the slave entity.
function model.unregister_slave_entity(key, slave, master, destroy)
    local slaves = registry(key, "slave")
    local masters = registry(key, "master")
    if not slaves or slave == nil then
        return false
    end

    local slave_unit = get_unit(slave)
    local slave_data = slaves[slave_unit]
    if not slave_data then
        return false
    end

    local slave_entity = slave
    if type(slave_entity) == "number" then
        slave_entity = slave_data.entity
    end

    -- unlink the slave from its master
    local master_data = masters and masters[slave_data.master]
    if master_data then
        for slave_name, unit in pairs(master_data.slaves) do
            if unit == slave_unit then
                master_data.slaves[slave_name] = nil
            end
        end
    end

    slaves[slave_unit] = nil

    if destroy and slave_entity and slave_entity.valid then
        slave_entity.destroy()
    end

    return true
end

---Creates a slave entity next to the master (offset {x, y}); slaves are indestructible.
---@return LuaEntity|nil
function model.make_slave(key, master, slave_name, offset)
    local masters = registry(key, "master")
    if not masters then
        return nil
    end

    local master_data = masters[get_unit(master)]
    if not master_data or not (master_data.entity and master_data.entity.valid) then
        return nil
    end

    local master_entity = master_data.entity
    local slave = master_entity.surface.create_entity{
        name = slave_name,
        position = {master_entity.position.x + offset.x, master_entity.position.y + offset.y},
        force = master_entity.force,
    }

    if slave then
        slave.destructible = false
    end

    return slave
end

---Links a slave (entity or unit number) to a master under the given slave_name.
function model.link_slave(key, master, slave, slave_name)
    local masters = registry(key, "master")
    local slaves = registry(key, "slave")
    if not masters or not slaves or slave == nil then
        return false
    end

    local master_unit = get_unit(master)
    local slave_unit = get_unit(slave)
    if not masters[master_unit] then
        return false
    end

    masters[master_unit].slaves[slave_name] = slave_unit
    slaves[slave_unit] = {master = master_unit}

    if type(slave) ~= "number" then
        slaves[slave_unit].entity = slave
    end

    return true
end

---Beacons start inactive until their slave has power (see powered_beacon.update).
function model.init_beacon(key, master)
    local masters = registry(key, "master")
    local master_data = masters and masters[get_unit(master)]
    if master_data and master_data.entity and master_data.entity.valid then
        master_data.entity.active = false
    end
end

--SPACED UPDATE COUNTERS
------------------------------------------------------------------------------------------------------

function model.add_spaced_update()
    storage.ei.spaced_updates = (storage.ei.spaced_updates or 0) + 1
end

function model.subtract_spaced_update()
    if (storage.ei.spaced_updates or 0) >= 1 then
        storage.ei.spaced_updates = storage.ei.spaced_updates - 1
    end
end

return model
