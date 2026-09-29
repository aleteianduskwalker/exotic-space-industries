--====================================================================================================
-- ORBITAL COMBINATOR
--====================================================================================================
-- A constant combinator on a planet surface that mirrors the logistic requests of all space
-- platforms of its force that are currently orbiting that planet. Every platform gets its own
-- logistic section, named after the platform (section group).
-- Updated round-robin, one combinator per call; each call performs at most one structural change
-- (add/remove a section) so the work is spread over several updates.
--====================================================================================================

local util = require("scripts/control/util")

local model = {}


function model.entity_check(entity)
  if entity == nil then return false end
  if not entity.valid then return false end
  return true
end


function model.check_init()
  storage.ei.orbital_combinators = storage.ei.orbital_combinators or {}
end


function model.add(entity)
  if model.entity_check(entity) then 
    if entity.name ~= "ei-orbital-combinator" then return end
    model.check_init()
    storage.ei.orbital_combinators[entity.unit_number] = entity
  end
end

function model.rem(entity)
  if model.entity_check(entity) then 
    if entity.name ~= "ei-orbital-combinator" then return end
    model.check_init()
    storage.ei.orbital_combinators[entity.unit_number] = nil
  end
end


local function get_logistic_content(entity)
  if not entity then return {} end 
  if not entity.valid then return {} end  

  local lst = {}
  for _,logistic_point in pairs(entity.get_logistic_point()) do
    -- sb(logistic_point)
    for _,logistic_section in pairs(logistic_point.sections) do
      -- sb(logistic_section)
      for i = 1,logistic_section.filters_count do
        local slot = logistic_section.get_slot(i)
        if slot['value'] and slot['min'] and slot['min'] > 0 then
          table.insert(lst,{min=slot['min'],max=slot['max'],name=slot['value']['name']})
        end
      end
    end
  end

  return lst
end

local function set_slot(section,index,filter)
  -- sl({section,index,filter})
  local slot
  local exists = {}

  if not filter.value then return end
  
  for i = 1,section.filters_count do
    slot = section.get_slot(i)
    if slot and slot.value then 
      -- sl({slot.value.name,filter.value})
      exists[slot.value.name] = true
    end
  end

  if exists[filter.value] then 
    for i = 1,section.filters_count do
      slot = section.get_slot(i)
      if slot and slot.value and slot.value.name == filter.value then 
        -- sl({slot,filter})
        -- sl({slot.value.name,slot.min,filter.min})
        section.clear_slot(i)
        if slot.min ~= nil and filter.min ~= nil then
          filter.min = filter.min + slot.min
          if filter.min ~= nil and filter.max ~= nil and filter.min > filter.max then filter.min = filter.max end
          section.set_slot(i,filter)     
        end
        return   
      end
    end

    return 
  end

  section.clear_slot(index)
  section.set_slot(index,filter)
end

local function set_combinator(entity,requests)
  -- sl("set_logistic_sections - 1")
  local control = entity.get_control_behavior()
  if not control then return end
  -- sl("set_logistic_sections - 2")

  for i = 1,control.sections_count do
    local remove = true
    for name,request in pairs(requests) do 
      local section = control.get_section(i)
      if section.group == name then remove = false end
    end
    if remove then control.remove_section(i) return end
  end

  for name,request in pairs(requests) do 
    local found = false
    for i = 1,control.sections_count do
      local section = control.get_section(i)
      if section.group == name then found = true end
    end

    if not found then 
      control.add_section(name)
      return
    end

  end

  -- sl("set_logistic_sections - 3")
  
  

  for name,request in pairs(requests) do 
    for i = 1,control.sections_count do
      local section = control.get_section(i)
      if section.group == name then 

        for i = 1,section.filters_count do
          section.clear_slot(i)
        end

        local index = 1
        for name,data in pairs(request) do
          set_slot(section,index,{value=data["name"],min=data["min"],max=data["max"]})
          index = index + 1
        end

      end
    end
  end

end



function model.update_orbital_combinators(entity)
  if not entity then return end
  if not entity.valid then return end

  local requests = {}

  for index,platform in pairs(entity.force.platforms) do
    if platform and platform.valid then 
      if platform.space_location and platform.space_location.name == entity.surface.name then
        requests[platform.name] = get_logistic_content(platform.hub)
      end
    end
  end

  set_combinator(entity,requests)
end

---Round-robin: updates one orbital combinator per call.
---@return boolean did_work
function model.update()
    local combinators = storage.ei and storage.ei.orbital_combinators
    if not combinators then
        return false
    end

    local key = util.next_key(combinators, storage.ei.orbital_combinators_break_point)
    storage.ei.orbital_combinators_break_point = key
    if key == nil then
        return false
    end

    local entity = combinators[key]
    if entity and entity.valid then
        model.update_orbital_combinators(entity)
    else
        combinators[key] = nil
    end

    return true
end

return model
