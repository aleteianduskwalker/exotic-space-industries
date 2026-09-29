--====================================================================================================
-- SCIENCE PACK CYCLE GUARD
--====================================================================================================
-- A technology must never cost a science pack that only becomes craftable by researching that
-- technology itself (or one of the technologies that come after it). The automatic age/pack
-- assignment of EI can produce such cycles with other mods, e.g. "kr-imersium-processing"
-- (Krastorio 2 Spaced Out) unlocks the imersite tech pack and was assigned the imersite age.
--
-- For every science pack P that is unlocked by exactly one technology T, P is removed from the
-- research cost of T and of all prerequisites of T (recursively).
-- Runs at the very end of data-final-fixes.
--====================================================================================================

---Returns the science packs (tools) produced by a recipe.
local function produced_packs(recipe)
    local packs = {}
    for _, result in pairs(recipe.results or {}) do
        local name = result.name or result[1]
        if name and data.raw.tool[name] then
            table.insert(packs, name)
        end
    end
    return packs
end

-- pack name -> list of technologies unlocking a recipe for it
local unlocking_techs = {}
-- packs that can be crafted from the start (no technology needed)
local available_from_start = {}

for _, recipe in pairs(data.raw.recipe) do
    if recipe.enabled ~= false and not recipe.hidden then
        for _, pack in pairs(produced_packs(recipe)) do
            available_from_start[pack] = true
        end
    end
end

for tech_name, technology in pairs(data.raw.technology) do
    for _, effect in pairs(technology.effects or {}) do
        local recipe = effect.type == "unlock-recipe" and data.raw.recipe[effect.recipe]
        if recipe then
            for _, pack in pairs(produced_packs(recipe)) do
                unlocking_techs[pack] = unlocking_techs[pack] or {}
                unlocking_techs[pack][tech_name] = true
            end
        end
    end
end

---Removes `pack` from the research cost of a technology.
local function remove_pack(technology, pack)
    if not (technology.unit and technology.unit.ingredients) then
        return
    end
    -- ingredient lists can be shared between technologies (age pack tables), copy first
    technology.unit.ingredients = table.deepcopy(technology.unit.ingredients)
    local ingredients = technology.unit.ingredients
    for i = #ingredients, 1, -1 do
        local name = ingredients[i][1] or ingredients[i].name
        if name == pack then
            log("Exotic Space Industries: removed " .. pack .. " from " .. technology.name .. " (the pack is unlocked by this technology or a later one)")
            table.remove(ingredients, i)
        end
    end
end

-- Only packs with exactly ONE unlocking technology are handled (conservative: packs that can be
-- obtained in several ways are left alone).
for pack, techs in pairs(unlocking_techs) do
    local only_tech = next(techs)
    if not available_from_start[pack] and next(techs, only_tech) == nil then
        local visited = {}
        local stack = {only_tech}
        while #stack > 0 do
            local name = table.remove(stack)
            local current = data.raw.technology[name]
            if current and not visited[name] then
                visited[name] = true
                remove_pack(current, pack)
                for _, prerequisite in pairs(current.prerequisites or {}) do
                    table.insert(stack, prerequisite)
                end
            end
        end
    end
end
