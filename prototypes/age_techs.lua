-- Age technologies ("ei-<age>-age"). They are pure metadata/milestones of the tech tree:
-- the old "research N % of the previous age" gate (hidden "-dummy" techs) was removed in 3.2.0.

local ei_lib = require("lib/lib")
local ei_data = require("lib/data")

--====================================================================================================
--AGE TECHS
--====================================================================================================

local science = ei_data.science

data:extend({
    {
        name = "ei-temp",
        type = "technology",
        icon = ei_graphics_path.."graphics/128_placeholder.png",
        icon_size = 128,
        prerequisites = {

        },
        effects = {

        },
        unit = {
            count = 100,
            ingredients = science["dark-age"],
            time = 100
        },
        enabled = false,
        visible_when_disabled = true,
    },
    {
        name = "ei-dark-age",
        type = "technology",
        icon = ei_graphics_tech_path.."dark-age.png",
        icon_size = 128,
        prerequisites = {

        },
        effects = {

        },
        unit = {
            count = 100,
            ingredients = science["dark-age"],
            time = 10
        },
        enabled = true,
        visible_when_disabled = true,
    },
    {
        name = "ei-steam-age",
        type = "technology",
        icon = ei_graphics_tech_path.."steam-age.png",
        icon_size = 128,
        prerequisites = {
            -- "ei-dark-age",
        },
        effects = {

        },
        unit = {
            count = 100,
            ingredients = science["dark-age"],
            time = 20
        },
        enabled = true,
        visible_when_disabled = true,
    },
    {
        name = "ei-electricity-age",
        type = "technology",
        icon = ei_graphics_tech_path.."electricity-age.png",
        icon_size = 128,
        prerequisites = {
            -- "ei-steam-age",
        },
        effects = {

        },
        unit = {
            count = 100,
            ingredients = science["steam-age"],
            time = 30
        },
        enabled = true,
        visible_when_disabled = true,
    },
    {
        name = "ei-computer-age",
        type = "technology",
        icon = ei_graphics_tech_path.."computer-age.png",
        icon_size = 128,
        prerequisites = {
            -- "ei-electricity-age",
        },
        effects = {

        },
        unit = {
            count = 100,
            ingredients = science["electricity-age"],
            time = 40
        },
        enabled = true,
        visible_when_disabled = true,
    },
    {
        name = "ei-quantum-age",
        type = "technology",
        icon = ei_graphics_tech_path.."quantum-age.png",
        icon_size = 128,
        prerequisites = {},
        effects = {

        },
        unit = {
            count = 100,
            ingredients = science["both-computer-age"],
            time = 50
        },
        enabled = true,
        visible_when_disabled = true,
    },
    {
        name = "ei-exotic-age",
        type = "technology",
        icon = ei_graphics_tech_path.."exotic-age.png",
        icon_size = 128,
        prerequisites = {},
        effects = {
            
        },
        unit = {
            count = 100,
            ingredients = science["both-quantum-age"],
            time = 60
        },
        enabled = true,
        visible_when_disabled = true,
    },

})

-- dev mode: make sure every age technology is available
if ei_mod.dev_mode == true then
    for _, age in pairs({"dark", "steam", "electricity", "computer", "quantum", "exotic"}) do
        local tech = data.raw.technology["ei-" .. age .. "-age"]
        if tech then
            tech.enabled = true
        end
    end
end
