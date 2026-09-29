--====================================================================================================
-- DEBLOAT EXOPLANETARY TECHNOLOGIES
--====================================================================================================
-- With the "debloat" setting, technologies that need science packs from other planets / mods
-- ("exoplanetary" packs) do not additionally need the early EI age packs (dark, steam, electricity
-- age). final-tech-fixes.lua already does this, but set_age_packs.lua and the compatibility scripts
-- run afterwards and may assign age pack lists again, so the rule is re-applied at the very end.
--====================================================================================================

local ei_lib = require("lib/lib")
local ei_data = require("lib/data")

if not ei_lib.config("debloat") then
    return
end

---True for packs that are neither EI packs nor vanilla packs EI replaces.
local function is_exoplanetary_science(pack)
    local prefix = string.sub(pack, 1, 3)
    if prefix == "ei-" or prefix == "ei_" then
        return false
    end
    return not ei_data.science_dict[pack]
end

for _, technology in pairs(data.raw.technology) do
    local ingredients = technology.unit and technology.unit.ingredients
    if ingredients then
        local exoplanetary = false
        for _, ingredient in pairs(ingredients) do
            if is_exoplanetary_science(ingredient[1] or ingredient.name) then
                exoplanetary = true
                break
            end
        end

        if exoplanetary then
            -- ingredient lists can be shared between technologies, work on a copy
            local cleaned = {}
            for _, ingredient in ipairs(ingredients) do
                if not ei_data.science_dict_obsolete[ingredient[1] or ingredient.name] then
                    table.insert(cleaned, ingredient)
                end
            end
            technology.unit.ingredients = cleaned
        end
    end
end
