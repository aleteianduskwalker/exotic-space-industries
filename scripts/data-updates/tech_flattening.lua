-- Set cost of every technology to startPrice from settings
-- used with scaling tech costs in control stage

-- also set prerequisite of all techs to "ei-temp" tech

local ei_lib = require("lib/lib")
local ei_data = require("lib/data")

--====================================================================================================
--TECH FLATTENING
--====================================================================================================

local startPrice = ei_lib.config("tech-scaling-startPrice")

-- set every technology cost to the start price (the control stage scales it during the game)
if not ei_lib.config("no-tech-scaling") then
    for _, technology in pairs(data.raw.technology) do
        local unit = technology.unit
        if unit then
            if unit.count then
                unit.count = startPrice
            end
            -- infinite technologies
            if unit.count_formula then
                unit.count_formula = "2^((L-1)*0.5)*" .. tostring(startPrice)
            end
        end
    end
end

-- every tech in ei_data.tech_structure[] and ei_data.tech_exclude_list gets "ei-temp" as its only
-- prerequisite (the real prerequisites are set by tech_structure.lua / hidden in final fixes)
for _, techs in pairs(ei_data.tech_structure) do
    for _, tech_name in ipairs(techs) do
        if data.raw.technology[tech_name] then
            data.raw.technology[tech_name].prerequisites = {"ei-temp"}
        end
    end
end

for _, tech_name in ipairs(ei_data.tech_exclude_list) do
    if data.raw.technology[tech_name] then
        data.raw.technology[tech_name].prerequisites = {"ei-temp"}
    end
end
