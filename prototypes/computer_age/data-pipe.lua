ei_data = require("lib/data")

--====================================================================================================
--DATA PIPE
--====================================================================================================

data:extend({
    {
        name = "ei-data-pipe",
        type = "item",
        icon = ei_graphics_item_path.."data-pipe.png",
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = "energy-pipe-distribution",
        order = "b[pipe]-d",
        place_result = "ei-data-pipe",
        stack_size = 100
    },
    {
        name = "ei-data-pipe",
        type = "recipe",
        category = "crafting",
        energy_required = 1,
        ingredients =
        {
            {type="item", name="ei-gold-ingot", amount=2},
            {type="item", name="plastic-bar", amount=4},
            {type="item", name="ei-insulated-wire", amount=6},
        },
        results = {{type="item", name="ei-data-pipe", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-data-pipe",
    },
})

local pipe = util.table.deepcopy(data.raw.pipe.pipe)
pipe.name = "ei-data-pipe"
pipe.minable.result = "ei-data-pipe"
pipe.fluid_box.filter = "ei-computing-power"

-- loop over pictures and swap first part of filename with ei_graphics_insulated_path
-- if filename has pipe in it, without the path part:
-- set hr version to nil and double scale, size of normal version
for k, v in pairs(pipe.pictures) do
    if v.filename then
        local filename = v.filename:match("^.+/(.+)$")
        if filename ~= "visualization.png" and filename ~= "disabled-visualization.png" then
            if filename == "steam.png" or filename == "fluid-background.png" then
                v.filename = ei_graphics_data_pipe_path.."hr-"..filename
            else
                v.filename = ei_graphics_data_pipe_path..filename
            end
        end
    end
end

data:extend({
    pipe
})

--====================================================================================================
--UNDERGROUND DATA CABLE ("data cable tier 2", alien tier 4 "Resonant Computation", design doc §4/§6)
--====================================================================================================
-- [ASSUMPTION] The document only names "data-cable tier 2" without details. By closest analogy
-- with regular pipes it is an underground data cable: a copy of the vanilla pipe-to-ground whose
-- fluid box is turned into a data fluid box by scripts/data-final-updates/data_network.lua
-- (filter ei-computing-power, connection category "ei-data" for normal AND underground links).
-- Graphics: vanilla pipe-to-ground, tinted in the data cable colour.

local DATA_TINT = {r = 0.55, g = 0.8, b = 1, a = 1}

---Recursively tints every sprite of a graphics table.
local function tint_graphics(graphics)
    if type(graphics) ~= "table" then return end
    if graphics.filename or graphics.filenames then
        graphics.tint = DATA_TINT
    end
    for _, value in pairs(graphics) do
        tint_graphics(value)
    end
end

local underground = table.deepcopy(data.raw["pipe-to-ground"]["pipe-to-ground"])
underground.name = "ei-data-pipe-to-ground"
underground.minable.result = "ei-data-pipe-to-ground"
underground.next_upgrade = nil
underground.icons = {
    {icon = data.raw.item["pipe-to-ground"].icon, icon_size = data.raw.item["pipe-to-ground"].icon_size or 64, tint = DATA_TINT},
}
underground.icon = nil
tint_graphics(underground.pictures)


data:extend({
    underground,
    {
        name = "ei-data-pipe-to-ground",
        type = "item",
        icons = underground.icons,
        subgroup = "energy-pipe-distribution",
        order = "b[pipe]-e",
        place_result = "ei-data-pipe-to-ground",
        stack_size = 50,
    },
    {
        name = "ei-data-pipe-to-ground",
        type = "recipe",
        category = "crafting",
        energy_required = 1,
        ingredients = {
            {type = "item", name = "ei-data-pipe", amount = 10},
            {type = "item", name = "ei-gold-ingot", amount = 5},
        },
        results = {{type = "item", name = "ei-data-pipe-to-ground", amount = 2}},
        enabled = false,
        main_product = "ei-data-pipe-to-ground",
    },
})
