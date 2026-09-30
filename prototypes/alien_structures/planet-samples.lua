--====================================================================================================
-- PLANET SAMPLES - GATE CALIBRATION KEYS (3.2.0)
--====================================================================================================
-- The first gate exit a force sets to a planet has to be "calibrated" with a sample of the planet
-- rock (scripts/control/gate.lua). A sample is crushed from local raw materials and can only be
-- made on its planet (recipe surface conditions copied from the planet surface properties).
--
-- KEY CONVENTION: the key of a planet is the item "ei-planet-sample-<lower case planet name>".
-- Planets without such an item can not be gate exits at all (modded planets need a patch).
-- Nauvis needs no key (home planet); platforms need none, but only while orbiting Gaia.
--
-- COMPATIBILITY PATCH for a modded planet: call the global ei_make_planet_sample in the
-- data-updates stage (or later) of a mod that depends on Exotic Space Industries, see the
-- example at the end of this file.
--
-- Sprites (graphics-1): items/<rock>-rock.png = sample icons, other/<rock>-rock.png = recipe icons
-- and InformaTron illustrations. Colours: mars (orange) Vulcanus, uran (green) Gleba,
-- sulf (ochre) Fulgora, exotic (cyan) Aquilo, moon (grey) Gaia.
--====================================================================================================

local ei_balance = require("lib/balance")

-- surface properties copied into the sample recipe surface conditions
local CONDITION_PROPERTIES = {"pressure", "magnetic-field", "gravity"}

---Surface conditions that only match the given planet.
---@param planet_name string
local function planet_conditions(planet_name)
    local planet = data.raw.planet[planet_name]
    if not planet then return nil end
    local conditions = {}
    for _, property in pairs(CONDITION_PROPERTIES) do
        local value = planet.surface_properties and planet.surface_properties[property]
        if value == nil and data.raw["surface-property"][property] then
            value = data.raw["surface-property"][property].default_value
        end
        if value ~= nil then
            table.insert(conditions, {property = property, min = value, max = value})
        end
    end
    return conditions
end

---Creates the calibration key of a planet: item "ei-planet-sample-<planet>" + crusher recipe.
---GLOBAL on purpose: compatibility patches of other mods call it.
---@param planet_name string planet prototype name
---@param options table {icon, recipe_icon, icon_size, ingredients, energy_required, surface_conditions,
---                      order, technology}
function ei_make_planet_sample(planet_name, options)
    local name = "ei-planet-sample-" .. string.lower(planet_name)
    local conditions = options.surface_conditions or planet_conditions(planet_name)

    data:extend({
        {
            name = name,
            type = "item",
            icon = options.icon,
            icon_size = options.icon_size or 64,
            subgroup = "ei-alien-items",
            order = "z-sample-" .. (options.order or planet_name),
            stack_size = 50,
            localised_name = {"item-name.ei-planet-sample", {"space-location-name." .. planet_name}},
            localised_description = {"item-description.ei-planet-sample", {"space-location-name." .. planet_name}},
        },
        {
            name = name,
            type = "recipe",
            category = "ei-crushing",
            icon = options.recipe_icon or options.icon,
            icon_size = options.icon_size or 64,
            energy_required = options.energy_required or 10,
            ingredients = options.ingredients,
            results = {{type = "item", name = name, amount = 1}},
            surface_conditions = conditions,
            enabled = false,
            always_show_made_in = true,
            allow_productivity = false,
            main_product = name,
            localised_name = {"item-name.ei-planet-sample", {"space-location-name." .. planet_name}},
        },
    })

    -- unlocked together with the gate (or a technology chosen by the patch)
    local technology = data.raw.technology[options.technology or "ei-gate"]
    if technology then
        technology.effects = technology.effects or {}
        table.insert(technology.effects, {type = "unlock-recipe", recipe = name})
    end
end

--VANILLA PLANETS + GAIA
------------------------------------------------------------------------------------------------------

local ITEM = ei_graphics_item_path
local OTHER = ei_graphics_other_path

if data.raw.planet["vulcanus"] then
    ei_make_planet_sample("vulcanus", {
        icon = ITEM .. "mars-rock.png", recipe_icon = OTHER .. "mars-rock.png", order = "a",
        ingredients = {{type = "item", name = "calcite", amount = 10}, {type = "item", name = "tungsten-ore", amount = 10}},
    })
end
if data.raw.planet["gleba"] then
    ei_make_planet_sample("gleba", {
        icon = ITEM .. "uran-rock.png", recipe_icon = OTHER .. "uran-rock.png", order = "b",
        ingredients = {{type = "item", name = "stone", amount = 10}, {type = "item", name = "spoilage", amount = 10}},
    })
end
if data.raw.planet["fulgora"] then
    ei_make_planet_sample("fulgora", {
        icon = ITEM .. "sulf-rock.png", recipe_icon = OTHER .. "sulf-rock.png", order = "c",
        ingredients = {{type = "item", name = "scrap", amount = 20}},
    })
end
if data.raw.planet["aquilo"] then
    ei_make_planet_sample("aquilo", {
        icon = ITEM .. "exotic-rock.png", recipe_icon = OTHER .. "exotic-rock.png", order = "d",
        ingredients = {{type = "item", name = "ice", amount = 20}, {type = "item", name = "lithium", amount = 2}},
    })
end
ei_make_planet_sample("Gaia", {
    icon = ITEM .. "moon-rock.png", recipe_icon = OTHER .. "moon-rock.png", order = "e",
    ingredients = {{type = "item", name = "stone", amount = 10}, {type = "item", name = "ei-cryodust", amount = 5}},
    surface_conditions = table.deepcopy(ei_balance.gaia_surface_conditions),
})

-- InformaTron illustrations of the gate page (other/<rock>-rock.png)
for _, rock in pairs({"mars", "uran", "sulf", "exotic", "moon"}) do
    data:extend({{type = "sprite", name = "ei-planet-sample-" .. rock, filename = OTHER .. rock .. "-rock.png", size = 64}})
end

--EXAMPLE COMPATIBILITY PATCH (modded planet)
------------------------------------------------------------------------------------------------------
-- A modded planet is no gate exit until a key exists. A patch in the data-updates.lua of a mod that
-- depends on "exotic-space-industries" (or in this mod, guarded by `mods[...]`) looks like this.
-- The recipe is limited to the planet automatically (its surface properties):
--
--   if mods["planet-muluna"] and data.raw.planet["muluna"] and ei_make_planet_sample then
--       ei_make_planet_sample("muluna", {
--           icon = "__exotic-space-industries-graphics-1__/graphics/items/moon-rock.png",
--           ingredients = {{type = "item", name = "stone", amount = 10}},  -- local raw material(s)
--           technology = "ei-gate",                                          -- unlocking technology
--       })
--   end
--
-- plus the locale of the planet name ([space-location-name] muluna=...) that the planet mod provides.
