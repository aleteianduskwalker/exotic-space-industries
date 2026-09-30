local ei_lib = require("lib/lib")

--====================================================================================================
--ITEM ICON UPDATES
--====================================================================================================

local level_table = {
    ["1"] = {
        "ei-deep-drill",
        "assembling-machine-1",
        "ei-metalworks-1",
        "ei-copper-beacon",
        "solar-panel",
        "electric-mining-drill",
        "ei-crusher",
        "ei-heat-chemical-plant",
        "oil-refinery",
        "ei-destill-tower",
        "centrifuge",
        "pumpjack"
    },
    ["2"] = {
        "ei-advanced-deep-drill",
        "assembling-machine-2",
        "ei-metalworks-2",
        "ei-iron-beacon",
        "ei-solar-panel-2",
        "ei-advanced-electric-mining-drill",
        "ei-advanced-crusher",
        "chemical-plant",
        "ei-advanced-refinery",
        "ei-advanced-destill-tower",
        "ei-advanced-centrifuge",
        "ei-deep-pumpjack"
    },
    ["3"] = {
        "assembling-machine-3",
        "ei-metalworks-3",
        "ei-solar-panel-3",
        "ei-superior-electric-mining-drill",
        "ei-advanced-chem-plant",
    },
    ["4"] = {
        "ei-neo-assembler",
        "ei-metalworks-4",
    },
    -- ["filter"] = {
    --     "ei-small-inserter",
    --     "ei-big-inserter",
    --     "fast-inserter",
    --     "bulk-inserter",
    -- }   
}

for level, items in pairs(level_table) do
    for _, item in ipairs(items) do
        ei_lib.add_item_level(item, level)
    end
end

-- NOTE: the "counts for age progression" technology overlay was removed in 3.2.0 together with
-- the age progression gate.
