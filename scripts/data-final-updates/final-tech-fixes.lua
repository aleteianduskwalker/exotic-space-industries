-- treat tech mainly added by other mods
-- swap vanilla science packs with ei_science packs
-- TODO: add recursive age inclusion

local ei_data = require("lib/data")
local ei_lib = require("lib/lib")

--====================================================================================================
--UTIL
--====================================================================================================

---Returns a copy of `list` without duplicate values (keeps the first occurrence).
local function unique_list(list)
    local seen = {}
    local result = {}
    for _, value in ipairs(list) do
        if not seen[value] then
            seen[value] = true
            table.insert(result, value)
        end
    end
    return result
end

---Returns a copy of a science pack list without duplicate packs (keeps the first occurrence).
local function unique_ingredients(ingredients)
    local seen = {}
    local result = {}
    for _, ingredient in ipairs(ingredients) do
        local name = ingredient[1] or ingredient.name
        if name and not seen[name] then
            seen[name] = true
            table.insert(result, ingredient)
        end
    end
    return result
end

local function is_exoplanetary_science(pack)
  if string.sub(pack, 1, 3) == "ei-" then return false end
  if string.sub(pack, 1, 3) == "ei_" then return false end
  if not ei_data.science_dict[pack] then return true end
  return false
end

local function is_exoplanetary_tech(tech)
  if data.raw.technology[tech].unit then
    for x,y in ipairs(data.raw.technology[tech].unit.ingredients) do
      -- error(serpent.block(y[1]))
      if is_exoplanetary_science(y[1]) then return true end 
    end
  end
  return false
end

local function hide_temp_techs()
    -- disable and hide "ei-temp-tech" and all techs that require it
    for i,v in pairs(data.raw.technology) do
        if data.raw.technology[i].prerequisites then
            for x,y in ipairs(data.raw.technology[i].prerequisites) do
                if y == "ei-temp" then
                    data.raw.technology[i].enabled = false
                    data.raw.technology[i].hidden = true
                end
            end
        end
    end

    -- hide "ei-temp-tech"
    data.raw.technology["ei-temp"].hidden = true
end


local function set_packs(tech, ingredients, exclude)
    -- test if tech is in data.raw
    if not data.raw["technology"][tech] then
        log("Error: "..tech.." not found in data.raw")
        return
    end

    if exclude[tech] then
        return
    end

    -- set pack for tech
    if data.raw["technology"][tech].unit then
      data.raw["technology"][tech].unit.ingredients = ingredients
    end

end


local function fix_age_packs(packs, exclude)
    for i,v in pairs(data.raw.technology) do
        if not is_exoplanetary_tech(i) then
          if data.raw.technology[i].age then
              set_packs(i, packs[data.raw.technology[i].age], exclude)
          end
        end
    end
end



---Returns all ages a technology belongs to (its own age or the ages of its prerequisites).
---@param tech table technology prototype
---@param is_root boolean|nil true for the technology whose age is being determined
local function get_ages(tech, is_root)
    if not tech then return {} end

    -- A tech that unlocks an age tech pack gives that age to the techs depending on it.
    -- The unlocking tech itself must NOT get that age: it would need the pack it unlocks
    -- (e.g. "kr-imersium-processing" requiring the imersite tech pack it unlocks).
    if not is_root and ei_data.tech_ages_with_sub[tech.name] then
        return {ei_data.tech_ages_with_sub[tech.name]}
    end

    if tech.age then
        return {tech.age}
    end

    if not tech.prerequisites then
        return {}
    end

    local return_ages = {}
    
    for i,v in ipairs(tech.prerequisites) do
        local ages = get_ages(data.raw.technology[v])
        if ages then
            for x,y in ipairs(ages) do
                table.insert(return_ages, y)
            end
        end
    end

    return return_ages

end


local function get_highest_age(ages)

    local highest_age = "dark-age"

    if ages == nil then
        return highest_age
    end

    for i,v in ipairs(ages) do

        if not ei_data.ages_with_sub[v] then
            goto continue
        end

        if not ei_data.ages_with_sub[highest_age] then
            goto continue
        end

        if ei_data.ages_with_sub[v] > ei_data.ages_with_sub[highest_age] then
            highest_age = v
        end

        ::continue::

    end

    return highest_age

end


--====================================================================================================
--PREREQ TECH FIXES
--====================================================================================================

local science_packs = ei_data.science
local tech_swap_dict = ei_data.tech_swap_dict
local exclude = {
    ["electric-engine"] = true,
    ["ei-electricity-power"] = true
}

-- also get all techs wich have space science pack as prereuisite
-- swap this with ei_quantum-age

local exclude_list = ei_data.tech_exclude_list

for _, technology in pairs(data.raw.technology) do
    if technology.prerequisites then
        for x, prerequisite in ipairs(technology.prerequisites) do
            if tech_swap_dict[prerequisite] then
                technology.prerequisites[x] = tech_swap_dict[prerequisite]
            end
        end
    end
end

-- loop over all techs and get the one that dont start with "ei-"
-- these are from base game and other mods
-- if they have the age property their fine, if not recursively get their prerequisits
-- set their age to the highest age findable

for i,tech in pairs(data.raw.technology) do
    if string.sub(i, 1, 3) == "ei-" then goto continue end
    if string.sub(i, 1, 3) == "ei_" then goto continue end

    -- if tech has age skip
    if tech.age then
        goto continue
    end

    -- if tech has no prerequisits skip
    if not tech.prerequisites then
        goto continue
    end

    -- get possible ages
    local ages = get_ages(tech, true)

    -- get highest age
    local highest_age = get_highest_age(ages)

    -- set tech age to highest age
    tech.age = highest_age

    ::continue::

end


-- remove all excluded techs from prerequisits
for i,tech in pairs(data.raw.technology) do

    if not tech.prerequisites then
        goto continue
    end

    -- remove excluded techs (backwards, so removing does not shift the remaining indices)
    for id = #tech.prerequisites, 1, -1 do
        if ei_lib.table_contains_value(exclude_list, tech.prerequisites[id]) then
            table.remove(tech.prerequisites, id)
        end
    end

    ::continue::

end


--====================================================================================================
--FINAL TECH FIXES
--====================================================================================================

-- loop over all techs and check if they still contain a vanilla science pack
-- as cost, if so replace with ei_science pack from ei_data.science_dict

for i,v in pairs(data.raw.technology) do
    if string.sub(i, 1, 3) == "se-" then goto continue end
    -- if string.sub(i, 1, 3) == "kr-" then goto continue end
    if data.raw.technology[i].unit and data.raw.technology[i].unit.ingredients then
        
        -- check if tech contains vanilla science pack
        for x,y in ipairs(data.raw.technology[i].unit.ingredients) do
            if ei_data.science_dict[y[1]] then
                -- check if ei_science pack is already in tech
                local found = false
                for z,w in ipairs(data.raw.technology[i].unit.ingredients) do
                    if w[1] == ei_data.science_dict[y[1]] then
                        found = true
                    end
                end

                -- if ei_science pack is not in tech, swap vanilla science pack with ei_science pack
                if not found then
                    data.raw.technology[i].unit.ingredients[x][1] = ei_data.science_dict[y[1]]
                else
                  -- if not is_exoplanetary_science(x) then 
                    -- if ei_science pack is in tech, remove vanilla science pack
                    -- table.remove(data.raw.technology[i].unit.ingredients, x)
                  -- end
                end 
            end
        end
    end
    ::continue::
end

-- loop over all techs and check if they still contain a vanilla science pack
-- if so remove it

for i,v in pairs(data.raw.technology) do
    if string.sub(i, 1, 3) == "se-" then goto continue end
    if v.unit and v.unit.ingredients then
        local ingredients = v.unit.ingredients
        for x = #ingredients, 1, -1 do
            if ei_data.science_dict[ingredients[x][1]] then
                table.remove(ingredients, x)
            end
        end
    end
    ::continue::
end

-- check all techs and fix if a prerequisit is registered more than once
-- also fixup order and number of tech icons
for i,v in pairs(data.raw.technology) do
    -- prereqs
    if v.prerequisites then
        v.prerequisites = unique_list(v.prerequisites)
    end

    if v.unit and v.unit.ingredients then
        v.unit.ingredients = unique_ingredients(v.unit.ingredients)
    end

    -- icons
    if data.raw.technology[i].age then

        local effects = util.table.deepcopy(data.raw.technology[i].effects)
        local icon_found = false

        if not effects then goto continue end

        local id = 1
        while true do
            if not effects[id] then
                break
            end

            local y = effects[id]
            if y.type == "nothing" then
                if y.icon == ei_graphics_other_path.."tech_overlay.png" then
                    table.remove(effects, id)
                    icon_found = true
                    id = 1
                end
            end

            id = id + 1

        end

        data.raw.technology[i].effects = effects

        ::continue::
        
    end
end


-- if not in dev mode hide or if in devmode and show_temp is false
if not ei_mod.dev_mode then
    hide_temp_techs()
elseif not ei_mod.show_temp then
    hide_temp_techs()
end

fix_age_packs(science_packs, exclude)


-- loop over all techs and check if any of their prerequisits contain
-- a pack they dont, if so add it to the tech

local to_add = {}

for tech_id,_ in pairs(data.raw.technology) do

    local tech = data.raw.technology[tech_id]

    -- skip techs that end with :dummy
    if string.sub(tech_id, -6) == "-dummy" then
        goto continue
    end
    if tech_id == "ei-temp" then
        goto continue
    end

    if not tech.prerequisites then
        goto continue
    end
    if #tech.prerequisites == 0 then
        goto continue
    end

    -- first collect list of all science packs from all prerequisits
    local prereq_packs = {}

    for _,prereq in ipairs(tech.prerequisites) do

        local prereq_tech = data.raw.technology[prereq]

        if not prereq_tech then
            goto skip
        end

        if not prereq_tech.unit then
            goto skip
        end
        if not prereq_tech.unit.ingredients then
            goto skip
        end

        for _,pack in ipairs(prereq_tech.unit.ingredients) do
            prereq_packs[pack[1]] = true
        end

        ::skip::

    end


    -- now check if tech contains all prerequisit packs, if not add them
    if not tech.unit then
        goto continue
    end
    if not tech.unit.ingredients then
        goto continue
    end
    if #tech.unit.ingredients == 0 then
        goto continue
    end

    for i,_ in pairs(prereq_packs) do

        local missing = true

        for _,pack in ipairs(tech.unit.ingredients) do
            if pack[1] == i then
                missing = false
            end
        end

        if missing then
            table.insert(to_add, {tech_id, i})
        end

    end
    
    ::continue::

end

for i,v in ipairs(to_add) do

    local tech = v[1]
    local pack = v[2]
    log("Added "..pack.." to "..tech)
    data.raw.technology[tech].unit.ingredients = table.deepcopy(data.raw.technology[tech].unit.ingredients)
    table.insert(data.raw.technology[tech].unit.ingredients, {pack, 1})
    
end




for i,v in pairs(data.raw.technology) do
  
  if ei_lib.config("no-tech-scaling") then

    if data.raw.technology[i].unit then
      if data.raw.technology[i].unit.count and data.raw.technology[i].unit.ingredients then
        data.raw.technology[i].unit.count = 100 * #data.raw.technology[i].unit.ingredients
      end
    end

    if not data.raw.technology[i].count_formula and not data.raw.technology[i].unit then 
      data.raw.technology[i].unit = {count = 1, ingredients = {}, time = 1}
    end

  end

  if is_exoplanetary_tech(i) and ei_lib.config('debloat') then
    local ingredients = data.raw.technology[i].unit.ingredients
    for x = #ingredients, 1, -1 do
      if ei_data.science_dict_obsolete[ingredients[x][1]] then
        table.remove(ingredients, x)
      end
    end
  end
end

-- ===========================================================================================================================================


for tech_id,_ in pairs(data.raw.technology) do
  local tech = data.raw.technology[tech_id]
  if string.sub(tech_id, -6) == "-dummy" then goto continue end
  if string.sub(tech_id, 1, 3) == "ei-" then goto continue end
  if string.sub(tech_id, 1, 3) == "ei_" then goto continue end
  if tech_id == "ei-temp" then goto continue end
  -- if not tech.prerequisites then goto continue end
  -- if #tech.prerequisites == 0 then goto continue end
  if not tech.unit then goto continue end
  if not tech.unit.ingredients then goto continue end
  
  for index = #tech.unit.ingredients, 1, -1 do
    local pack = tech.unit.ingredients[index][1]
    if data.raw.tool[pack] and (data.raw.tool[pack].hidden or ei_data.science_dict[pack]) then
      table.remove(tech.unit.ingredients, index)
    end
  end

  ::continue::

end

-- error(serpent.block(data.raw.technology["CW-spirit-shadow"]))


-- ======================================================================================

if data.raw.technology["worker-robots-storage-4"] and data.raw.technology["worker-robots-storage-10"] then
  data.raw.technology["worker-robots-storage-4"].icon_size = 256
  data.raw.technology["worker-robots-storage-5"].icon_size = 256
  data.raw.technology["worker-robots-storage-6"].icon_size = 256
  data.raw.technology["worker-robots-storage-7"].icon_size = 256
  data.raw.technology["worker-robots-storage-8"].icon_size = 256
  data.raw.technology["worker-robots-storage-9"].icon_size = 256
  data.raw.technology["worker-robots-storage-10"].icon_size = 256
end


for i,v in pairs(data.raw.technology) do
  data.raw.technology[i].hidden = false

  if data.raw.technology[i].unit then
    if data.raw.technology[i].unit.count and data.raw.technology[i].unit.ingredients then
      if data.raw.technology[i].unit.count >= 9999 then data.raw.technology[i].unit.count = 9999 end
      if data.raw.technology[i].unit.time >= 9999 then data.raw.technology[i].unit.time = 9999 end
    end
  end

  if data.raw.technology[i].unit and data.raw.technology[i].unit.ingredients then
    data.raw.technology[i].unit.ingredients = unique_ingredients(data.raw.technology[i].unit.ingredients)
  end
end


table.insert(data.raw["technology"]["ei-dark-age"].effects, {
  type = "unlock-quality",
  quality = "normal"
})

table.insert(data.raw["technology"]["ei-dark-age"].effects, {
  type = "unlock-quality",
  quality = "uncommon"
})

table.insert(data.raw["technology"]["ei-steam-age"].effects, {
  type = "unlock-quality",
  quality = "rare"
})

table.insert(data.raw["technology"]["ei-electricity-age"].effects, {
  type = "unlock-quality",
  quality = "epic"
})

table.insert(data.raw["technology"]["ei-computer-age"].effects, {
  type = "unlock-quality",
  quality = "legendary"
})

-- =================================================================================================

ei_lib.remove_tech("steam-power")
ei_lib.remove_tech("wdm_ship_fix_lock")

ei_lib.remove_tech("ei-temp")
ei_lib.remove_tech("ei-steam-age-dummy")
ei_lib.remove_tech("ei-electricity-age-dummy")
ei_lib.remove_tech("ei-computer-age-dummy")
ei_lib.remove_tech("ei-quantum-age-dummy")
ei_lib.remove_tech("ei-exotic-age-dummy")

