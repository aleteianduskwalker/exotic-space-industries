--====================================================================================================
-- ORBITAL COMBINATOR
--====================================================================================================
-- A constant combinator on a planet surface that mirrors the logistic requests of all space
-- platforms of its force that are currently orbiting that planet. Every platform gets its own
-- logistic section, named after the platform (section group).
-- Updated round-robin, one combinator per call; each call performs at most one structural change
-- (add/remove a section) so the work is spread over several updates.
--
-- COMPUTING POWER (3.1.0, design doc §6)
--   * every combinator has a hidden companion storage tank "ei-orbital-combinator-computing-port"
--     on the same tile (prototypes/computer_age/orbital-combinator.lua); only data cables connect
--   * consumption: balance.orbital_combinator.computing_power_per_minute, measured in REAL elapsed
--     ticks since the last update of this combinator (the round-robin scheduler does not
--     guarantee a fixed interval per entity)
--   * it is consumed ONLY while at least one orbiting platform has logistic requests
--   * not enough computing power -> "brownout": the sections are NOT updated (they keep their
--     last values), a warning icon is drawn, nothing is consumed; resumes when the port refills
--
-- storage.ei.orbital_combinators[unit_number] = {
--     entity    = LuaEntity   the combinator
--     port      = LuaEntity   hidden computing power port
--     last_tick = integer     game.tick of the last update (consumption interval)
--     icon      = LuaRenderObject|nil  brownout warning icon
-- }
-- Old saves (< 3.1.0) stored the entity directly; model.migrate() converts them.
--====================================================================================================

local util = require("scripts/control/util")
local ei_balance = require("lib/balance")

local model = {}

local COMBINATOR = "ei-orbital-combinator"
local PORT = "ei-orbital-combinator-computing-port"
local COMPUTING_POWER = "ei-computing-power"
local TICKS_PER_MINUTE = 60 * 60

function model.entity_check(entity)
  if entity == nil then return false end
  if not entity.valid then return false end
  return true
end


function model.check_init()
  storage.ei.orbital_combinators = storage.ei.orbital_combinators or {}
end

--COMPUTING POWER PORT
------------------------------------------------------------------------------------------------------

---Returns the port of a combinator: an existing one on the same tile (e.g. copied by a cloning mod)
---is reused and surplus ports are removed, otherwise a new one is created.
---@param entity LuaEntity combinator
---@return LuaEntity|nil
local function ensure_port(entity)
  local ports = entity.surface.find_entities_filtered{name = PORT, position = entity.position, radius = 0.1}
  local port = table.remove(ports, 1)
  for _, surplus in pairs(ports) do
    surplus.destroy()
  end

  if not port then
    port = entity.surface.create_entity{
      name = PORT,
      position = entity.position,
      force = entity.force,
      create_build_effect_smoke = false,
      raise_built = false,
    }
  end

  if port then
    port.destructible = false
  end
  return port
end

---Draws / removes the brownout warning icon.
---@param data table combinator record
---@param brownout boolean
local function set_brownout(data, brownout)
  if brownout and not util.is_valid(data.icon) then
    data.icon = rendering.draw_sprite{
      sprite = "utility/warning_icon",
      target = data.entity,
      surface = data.entity.surface,
      x_scale = 0.4,
      y_scale = 0.4,
      render_layer = "entity-info-icon",
    }
  elseif not brownout and data.icon then
    util.destroy_render(data.icon)
    data.icon = nil
  end
end

---Tries to pay the computing power for `elapsed` ticks. Returns true if paid.
---@param port LuaEntity
---@param elapsed integer ticks since the last update
local function pay_computing_power(port, elapsed)
  local need = ei_balance.orbital_combinator.computing_power_per_minute * elapsed / TICKS_PER_MINUTE
  if need <= 0 then
    return true
  end
  if not util.is_valid(port) then
    return false
  end

  local stored = port.get_fluid_contents()[COMPUTING_POWER] or 0
  if stored < need then
    return false
  end

  port.remove_fluid{name = COMPUTING_POWER, amount = need}
  return true
end

--REGISTRATION
------------------------------------------------------------------------------------------------------

function model.add(entity)
  if model.entity_check(entity) then
    if entity.name ~= COMBINATOR then return end
    model.check_init()
    storage.ei.orbital_combinators[entity.unit_number] = {
      entity = entity,
      port = ensure_port(entity),
      last_tick = game.tick,
    }
  end
end

function model.rem(entity)
  if model.entity_check(entity) then
    if entity.name ~= COMBINATOR then return end
    model.check_init()
    local data = storage.ei.orbital_combinators[entity.unit_number]
    if data then
      util.destroy_entity(data.port)
      util.destroy_render(data.icon)
    end
    storage.ei.orbital_combinators[entity.unit_number] = nil
  end
end

---Idempotent migration of older saves (called from on_configuration_changed):
---  * records that are plain entities (< 3.1.0) become {entity, port, last_tick}
---  * missing / invalid ports are (re)created, invalid combinators are dropped
function model.migrate()
  model.check_init()
  local combinators = storage.ei.orbital_combinators

  -- collect first: the table is modified while migrating
  local units = {}
  for unit in pairs(combinators) do
    table.insert(units, unit)
  end

  for _, unit in ipairs(units) do
    local data = combinators[unit]
    -- old format: the entity itself (LuaObjects are userdata)
    if type(data) == "userdata" or (type(data) == "table" and data.object_name == "LuaEntity") then
      data = {entity = data, last_tick = game.tick}
    end

    if type(data) ~= "table" or not util.is_valid(data.entity) then
      combinators[unit] = nil
    else
      if not util.is_valid(data.port) then
        data.port = ensure_port(data.entity)
      end
      data.last_tick = data.last_tick or game.tick
      combinators[unit] = data
    end
  end
end

--LOGISTIC SECTIONS
------------------------------------------------------------------------------------------------------

local function get_logistic_content(entity)
  if not entity then return {} end
  if not entity.valid then return {} end

  local lst = {}
  for _,logistic_point in pairs(entity.get_logistic_point()) do
    for _,logistic_section in pairs(logistic_point.sections) do
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
  local slot
  local exists = {}

  if not filter.value then return end

  for i = 1,section.filters_count do
    slot = section.get_slot(i)
    if slot and slot.value then
      exists[slot.value.name] = true
    end
  end

  -- the same item is requested twice: add the minimums up (capped by the maximum)
  if exists[filter.value] then
    for i = 1,section.filters_count do
      slot = section.get_slot(i)
      if slot and slot.value and slot.value.name == filter.value then
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

---Synchronises the combinator sections with the requests (at most one structural change per call).
---@param entity LuaEntity
---@param requests table<string, table[]> platform name -> requests
local function set_combinator(entity,requests)
  local control = entity.get_control_behavior()
  if not control then return end

  -- 1) remove one section that belongs to no orbiting platform
  for i = 1,control.sections_count do
    local section = control.get_section(i)
    if not requests[section.group] then
      control.remove_section(i)
      return
    end
  end

  -- 2) add one missing platform section
  for name in pairs(requests) do
    local found = false
    for i = 1,control.sections_count do
      if control.get_section(i).group == name then found = true end
    end

    if not found then
      control.add_section(name)
      return
    end
  end

  -- 3) refresh the slots of every section
  for name,request in pairs(requests) do
    for i = 1,control.sections_count do
      local section = control.get_section(i)
      if section.group == name then

        for slot_index = 1,section.filters_count do
          section.clear_slot(slot_index)
        end

        local index = 1
        for _,data in pairs(request) do
          set_slot(section,index,{value=data["name"],min=data["min"],max=data["max"]})
          index = index + 1
        end

      end
    end
  end

end

---Collects the requests of all platforms of the combinator's force orbiting its planet.
---@return table<string, table[]> requests, boolean has_requests
local function collect_requests(entity)
  local requests = {}
  local has_requests = false

  for _,platform in pairs(entity.force.platforms) do
    if platform and platform.valid then
      if platform.space_location and platform.space_location.name == entity.surface.name then
        local content = get_logistic_content(platform.hub)
        requests[platform.name] = content
        has_requests = has_requests or #content > 0
      end
    end
  end

  return requests, has_requests
end

---Updates one combinator: pays the computing power (if needed) and mirrors the requests.
---@param data table combinator record
function model.update_orbital_combinators(data)
  local entity = data.entity
  if not util.is_valid(entity) then return end

  local elapsed = game.tick - (data.last_tick or game.tick)
  data.last_tick = game.tick

  local requests, has_requests = collect_requests(entity)

  if has_requests and not pay_computing_power(data.port, elapsed) then
    set_brownout(data, true) -- sections stay frozen on their last values
    return
  end

  set_brownout(data, false)
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

    local data = combinators[key]
    if type(data) == "table" and util.is_valid(data.entity) then
        if not util.is_valid(data.port) then
          data.port = ensure_port(data.entity) -- port lost (e.g. removed by another mod)
        end
        model.update_orbital_combinators(data)
    else
        if type(data) == "table" then
          util.destroy_entity(data.port)
          util.destroy_render(data.icon)
        end
        combinators[key] = nil
    end

    return true
end

return model
