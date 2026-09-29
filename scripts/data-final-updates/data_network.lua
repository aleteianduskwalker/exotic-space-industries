--====================================================================================================
-- DATA NETWORK (computing power)
--====================================================================================================
-- Computing power is a fluid that must only travel through data cables:
--   * data cables only carry "ei-computing-power" (fluid box filter)
--   * data cables use their own pipe connection category, so they never connect to regular
--     pipes, pumps, tanks or regular machine fluid boxes (and vice versa)
--   * the computing power fluid boxes of computers use the same category, so regular pipes can
--     not be attached to them and therefore can never carry computing power
--
-- This runs in data-final-fixes so that changes of other mods to these prototypes are overridden.
--====================================================================================================

local DATA_FLUID = "ei-computing-power"
local DATA_CONNECTION_CATEGORY = "ei-data"

-- entity type -> entity name -> indices of the fluid boxes that carry computing power
local DATA_FLUID_BOXES = {
    ["assembling-machine"] = {
        ["ei-computer-core"] = {1},
        ["ei-small-simulator"] = {1},
        ["ei-quantum-computer"] = {1, 2},
        ["ei-resonance-synthesizer"] = {1}, -- 3.1.0: fluid box 2 (morphium) stays a regular pipe
        ["ei-data-center"] = {1},           -- 3.1.0
    },
}

-- data cables and other single fluid box entities that carry computing power (`fluid_box`)
local DATA_CABLES = {
    ["pipe"] = {"ei-data-pipe"},
    ["pipe-to-ground"] = {"ei-data-pipe-to-ground"},               -- 3.1.0: underground data cable
    ["storage-tank"] = {"ei-orbital-combinator-computing-port"},   -- 3.1.0: hidden combinator port
}

---Turns a fluid box into a data fluid box.
---@param fluid_box table FluidBox prototype
local function make_data_fluid_box(fluid_box)
    fluid_box.filter = DATA_FLUID
    for _, connection in pairs(fluid_box.pipe_connections or {}) do
        connection.connection_category = DATA_CONNECTION_CATEGORY
    end
end

for entity_type, names in pairs(DATA_CABLES) do
    for _, name in pairs(names) do
        local prototype = data.raw[entity_type] and data.raw[entity_type][name]
        if prototype and prototype.fluid_box then
            make_data_fluid_box(prototype.fluid_box)
        end
    end
end

for entity_type, entities in pairs(DATA_FLUID_BOXES) do
    for name, indices in pairs(entities) do
        local prototype = data.raw[entity_type] and data.raw[entity_type][name]
        if prototype and prototype.fluid_boxes then
            for _, index in pairs(indices) do
                if prototype.fluid_boxes[index] then
                    make_data_fluid_box(prototype.fluid_boxes[index])
                end
            end
        end
    end
end
