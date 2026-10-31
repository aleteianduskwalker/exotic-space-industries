--====================================================================================================
-- SCIENCE PACK PROTOTYPES
--====================================================================================================
-- Factorio 2.1 converted the vanilla science packs to item prototypes. Keep support for legacy
-- tool-based packs from compatibility mods, and recognise item prototypes used as research costs.

local science_packs = {}


---Builds a map of science-pack names to their item or tool prototypes.
---
---Includes legacy tool prototypes, items in conventional science-pack subgroups, and every item
---or tool referenced by a technology's research ingredients.
---
---Returns:
---  table<string, table>: Prototype map indexed by science-pack name.
---
---Side effects: None. The result is rebuilt on each call to include prototypes added by other mods.
function science_packs.get_prototypes()
    local science_pack_by_name = {}
    local item_prototypes = data.raw.item or {}
    local tool_prototypes = data.raw.tool or {}

    -- Preserve support for existing mods that still declare science packs as tool prototypes.
    for science_pack_name, science_pack_prototype in pairs(tool_prototypes) do
        science_pack_by_name[science_pack_name] = science_pack_prototype
    end

    -- Include item-based packs even when they are hidden or not referenced by a technology yet.
    for item_name, item_prototype in pairs(item_prototypes) do
        local subgroup_name = item_prototype.subgroup
        if subgroup_name == "science-pack" or subgroup_name == "ei-science-science" then
            science_pack_by_name[item_name] = item_prototype
        end
    end

    -- Factorio 2.1 allows any item prototype as a research ingredient, regardless of its subgroup.
    for _, technology in pairs(data.raw.technology or {}) do
        local research_ingredients = technology.unit and technology.unit.ingredients or {}
        for _, ingredient in pairs(research_ingredients) do
            local science_pack_name = nil

            -- Support both the legacy tuple form and named ingredient tables used by some mods.
            if type(ingredient) == "table" then
                science_pack_name = ingredient[1] or ingredient.name
            end

            -- Include only names which resolve to a real prototype.
            if science_pack_name then
                local item_prototype = item_prototypes[science_pack_name]
                local tool_prototype = tool_prototypes[science_pack_name]
                local science_pack_prototype = item_prototype or tool_prototype
                if science_pack_prototype then
                    science_pack_by_name[science_pack_name] = science_pack_prototype
                end
            end
        end
    end

    return science_pack_by_name
end


return science_packs
