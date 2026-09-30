--====================================================================================================
-- RADIO STATIONS (3.2.0)
--====================================================================================================
-- Wireless circuit network channels (prototypes: prototypes/electricity_age/radio-station.lua).
--
--   * a CHANNEL is identified by a signal chosen in the station GUI
--   * mode "transmitter": reads the red + green circuit network wired to the station and sends it
--     to every receiver of the channel. Only ONE transmitter per channel.
--   * mode "receiver" (default): outputs the signals of the channel's transmitter into its own
--     circuit network (through an invisible constant combinator wired to the station)
--   * scope: ei-radio-station links stations of the same force on the SAME surface,
--     ei-crystal-radio-station links stations of the same force on EVERY surface; both kinds use
--     separate channel namespaces
--   * a station without power neither sends nor receives (receivers output nothing)
--
-- NOTE: wiring a receiver and a transmitter of the same channel into one network creates a
-- feedback loop (like two combinators feeding each other) - that is the player's wiring.
--
-- storage.ei.radio = {
--     stations     = {[unit_number] = {entity, output, channel = SignalID|nil,
--                                      transmitter = boolean, crystal = boolean, hash = string}},
--     transmitters = {[channel_key] = unit_number},
-- }
--====================================================================================================

local ei_balance = require("lib/balance")

local model = {}

model.STATIONS = {
    ["ei-radio-station"] = {crystal = false},
    ["ei-crystal-radio-station"] = {crystal = true},
}
model.OUTPUT = "ei-radio-station-output"
model.UPDATE_INTERVAL = ei_balance.radio_station.update_interval

local GUI_NAME = "ei-radio-station-console"
local MAX_FILTERS_PER_SECTION = 1000

--STORAGE
------------------------------------------------------------------------------------------------------

function model.check_init()
    storage.ei.radio = storage.ei.radio or {}
    storage.ei.radio.stations = storage.ei.radio.stations or {}
    storage.ei.radio.transmitters = storage.ei.radio.transmitters or {}
end

local function get_stations()
    return storage.ei.radio and storage.ei.radio.stations or {}
end

local function get_transmitters()
    return storage.ei.radio and storage.ei.radio.transmitters or {}
end

--UTIL
------------------------------------------------------------------------------------------------------

---Unique key of the channel a station is tuned to (nil without channel).
---Normal stations: force + surface + signal. Crystal stations: force + "*" + signal.
---@param station table station record
---@return string|nil
local function channel_key(station)
    local entity, channel = station.entity, station.channel
    if not (channel and entity and entity.valid) then
        return nil
    end
    local scope = station.crystal and "*" or tostring(entity.surface.index)
    return table.concat({entity.force.index, scope, channel.type or "item", channel.name}, ":")
end

---A station works only while it has power.
---@param station table
local function is_powered(station)
    return station.entity and station.entity.valid and station.entity.energy > 0
end

---Merged red + green signals of the network wired to a station ({key -> Signal}).
---@param entity LuaEntity
local function read_signals(entity)
    local merged = {}
    for _, wire in pairs({defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green}) do
        local network = entity.get_circuit_network(wire)
        for _, signal in pairs(network and network.signals or {}) do
            local id = signal.signal
            local key = (id.type or "item") .. "/" .. id.name .. "/" .. (id.quality or "")
            local existing = merged[key]
            if existing then
                existing.count = existing.count + signal.count
            else
                merged[key] = {signal = id, count = signal.count}
            end
        end
    end
    return merged
end

---Converts merged signals into constant combinator filters + a hash to detect changes.
---@param merged table
---@return LogisticFilter[] filters
---@return string hash
local function to_filters(merged)
    local keys = {}
    for key, signal in pairs(merged) do
        if signal.count ~= 0 then table.insert(keys, key) end
    end
    table.sort(keys) -- deterministic order (hash + multiplayer)

    local filters, parts = {}, {}
    for _, key in ipairs(keys) do
        local signal = merged[key]
        local id = signal.signal
        table.insert(filters, {
            value = {type = id.type or "item", name = id.name, quality = id.quality or "normal", comparator = "="},
            min = signal.count,
        })
        table.insert(parts, key .. "=" .. signal.count)
    end
    return filters, table.concat(parts, ";")
end

---Writes the received signals into the hidden output combinator of a receiver.
---@param station table
---@param filters LogisticFilter[]|nil nil/empty clears the output
---@param hash string
local function set_output(station, filters, hash)
    if station.hash == hash then return end
    local output = station.output
    if not (output and output.valid) then return end

    local behavior = output.get_or_create_control_behavior()
    filters = filters or {}

    -- one section per 1000 signals
    local needed = math.max(1, math.ceil(#filters / MAX_FILTERS_PER_SECTION))
    while behavior.sections_count < needed do behavior.add_section() end
    while behavior.sections_count > needed do behavior.remove_section(behavior.sections_count) end

    for index = 1, needed do
        local chunk = {}
        for i = (index - 1) * MAX_FILTERS_PER_SECTION + 1, math.min(#filters, index * MAX_FILTERS_PER_SECTION) do
            table.insert(chunk, filters[i])
        end
        behavior.get_section(index).filters = chunk
    end
    behavior.enabled = true
    station.hash = hash
end

--REGISTRATION
------------------------------------------------------------------------------------------------------

---Creates (or reuses) the hidden output combinator of a station and wires it to the station.
---@param entity LuaEntity
local function create_output(entity)
    local output = entity.surface.find_entity(model.OUTPUT, entity.position)
    if not (output and output.valid) then
        output = entity.surface.create_entity{
            name = model.OUTPUT,
            position = entity.position,
            force = entity.force,
            create_build_effect_smoke = false,
            raise_built = false,
        }
    end
    if not output then return nil end
    output.destructible = false

    for _, wire in pairs({defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green}) do
        local from = entity.get_wire_connector(wire, true)
        local to = output.get_wire_connector(wire, true)
        from.connect_to(to, false, defines.wire_origin.script)
    end
    return output
end

---Registers a newly built station (default: receiver without channel).
---@param entity LuaEntity
---@param settings table|nil {channel, transmitter} to copy (clones)
function model.register(entity, settings)
    local kind = model.STATIONS[entity.name]
    if not kind then return end
    model.check_init()

    local station = {
        entity = entity,
        output = create_output(entity),
        channel = settings and settings.channel or nil,
        transmitter = false,
        crystal = kind.crystal,
        hash = nil,
    }
    get_stations()[entity.unit_number] = station

    if settings and settings.transmitter then
        model.set_mode(entity.unit_number, true)
    end
end

---Removes a station (entity about to be removed / invalid) and frees its transmitter slot.
---@param unit_number integer
function model.unregister(unit_number)
    local station = get_stations()[unit_number]
    if not station then return end

    local transmitters = get_transmitters()
    for key, transmitter_unit in pairs(transmitters) do
        if transmitter_unit == unit_number then transmitters[key] = nil end
    end
    if station.output and station.output.valid then
        station.output.destroy()
    end
    get_stations()[unit_number] = nil
end

--SETTINGS
------------------------------------------------------------------------------------------------------

---Switches a station between receiver (false) and transmitter (true).
---@param unit_number integer
---@param transmitter boolean
---@return boolean success false if the channel already has another transmitter
function model.set_mode(unit_number, transmitter)
    local station = get_stations()[unit_number]
    if not station then return false end
    local transmitters = get_transmitters()

    -- free the old transmitter slot
    for key, transmitter_unit in pairs(transmitters) do
        if transmitter_unit == unit_number then transmitters[key] = nil end
    end
    station.transmitter = false

    if transmitter then
        local key = channel_key(station)
        if key then
            local owner = transmitters[key]
            local owner_station = owner and get_stations()[owner]
            if owner_station and owner_station.entity and owner_station.entity.valid then
                return false
            end
            transmitters[key] = unit_number
        end
        station.transmitter = true
        -- a transmitter outputs nothing itself
        set_output(station, nil, "")
    end
    return true
end

---Tunes a station to a channel (SignalID or nil). A transmitter keeps its role only if the new
---channel is free, otherwise it becomes a receiver.
---@param unit_number integer
---@param channel SignalID|nil
---@return boolean kept_transmitter
function model.set_channel(unit_number, channel)
    local station = get_stations()[unit_number]
    if not station then return false end

    local was_transmitter = station.transmitter
    model.set_mode(unit_number, false)
    station.channel = channel and {type = channel.type, name = channel.name} or nil
    if was_transmitter then
        return model.set_mode(unit_number, true)
    end
    return true
end

--UPDATE
------------------------------------------------------------------------------------------------------

---Transfers the signals of every transmitter to its receivers (every UPDATE_INTERVAL ticks).
function model.update()
    local stations = get_stations()
    if next(stations) == nil then return end
    local transmitters = get_transmitters()

    -- drop invalid stations (removed without an event, e.g. by other mods)
    for unit_number, station in pairs(stations) do
        if not (station.entity and station.entity.valid) then
            model.unregister(unit_number)
        end
    end

    -- read every powered transmitter once
    local channels = {}
    for key, unit_number in pairs(transmitters) do
        local station = stations[unit_number]
        if station and station.transmitter and channel_key(station) == key then
            if is_powered(station) then
                local filters, hash = to_filters(read_signals(station.entity))
                channels[key] = {filters = filters, hash = hash}
            end
        else
            transmitters[key] = nil -- stale slot (channel changed, force changed, ...)
        end
    end

    -- write the receivers
    for _, station in pairs(stations) do
        if not station.transmitter then
            local key = channel_key(station)
            local channel = key and channels[key]
            if channel and is_powered(station) then
                set_output(station, channel.filters, channel.hash)
            else
                set_output(station, nil, "")
            end
        end
    end
end

--GUI
------------------------------------------------------------------------------------------------------

---Status line of a station (localised string).
local function status_caption(station)
    if not is_powered(station) then
        return {"exotic-industries.radio-status-no-power"}
    end
    if not station.channel then
        return {"exotic-industries.radio-status-no-channel"}
    end
    if station.transmitter then
        return {"exotic-industries.radio-status-transmitting"}
    end
    local key = channel_key(station)
    local owner = key and get_transmitters()[key]
    if owner and get_stations()[owner] then
        return {"exotic-industries.radio-status-receiving"}
    end
    return {"exotic-industries.radio-status-no-transmitter"}
end

function model.close_gui(player)
    local gui = player.gui.relative[GUI_NAME]
    if gui then gui.destroy() end
end

---Relative GUI next to the (assembling machine) GUI of a station.
---@param player LuaPlayer
---@param entity LuaEntity
function model.open_gui(player, entity)
    model.close_gui(player)
    local station = get_stations()[entity.unit_number]
    if not station then
        model.register(entity)
        station = get_stations()[entity.unit_number]
        if not station then return end
    end

    local root = player.gui.relative.add{
        type = "frame",
        name = GUI_NAME,
        direction = "vertical",
        caption = {"exotic-industries.radio-gui-title"},
        anchor = {
            gui = defines.relative_gui_type.assembling_machine_gui,
            position = defines.relative_gui_position.right,
            names = {"ei-radio-station", "ei-crystal-radio-station"},
        },
    }
    local content = root.add{type = "frame", name = "content", direction = "vertical", style = "inside_shallow_frame_with_padding"}

    content.add{type = "label", caption = {"exotic-industries.radio-gui-channel"}, style = "heading_2_label"}
    content.add{
        type = "choose-elem-button",
        name = "channel",
        elem_type = "signal",
        signal = station.channel,
        tooltip = {"exotic-industries.radio-gui-channel-tooltip"},
        tags = {parent_gui = GUI_NAME, action = "channel", unit = entity.unit_number},
    }

    content.add{type = "label", caption = {"exotic-industries.radio-gui-mode"}, style = "heading_2_label"}
    content.add{
        type = "switch",
        name = "mode",
        switch_state = station.transmitter and "right" or "left",
        left_label_caption = {"exotic-industries.radio-gui-receiver"},
        right_label_caption = {"exotic-industries.radio-gui-transmitter"},
        right_label_tooltip = {"exotic-industries.radio-gui-transmitter-tooltip"},
        tags = {parent_gui = GUI_NAME, action = "mode", unit = entity.unit_number},
    }

    content.add{type = "label", name = "status", caption = status_caption(station)}
    content.add{type = "label", caption = {station.crystal and "exotic-industries.radio-gui-scope-crystal" or "exotic-industries.radio-gui-scope-surface"}}
end

---Rebuilds the GUI after a change (keeps it in sync with the stored settings).
local function refresh_gui(player, unit_number)
    local station = get_stations()[unit_number]
    if station and station.entity and station.entity.valid then
        model.open_gui(player, station.entity)
    end
end

function model.on_gui_elem_changed(event)
    local element = event.element
    local tags = element.tags
    if tags.action ~= "channel" then return end
    local player = game.get_player(event.player_index)

    if not model.set_channel(tags.unit, element.elem_value) then
        player.print({"exotic-industries.radio-transmitter-taken"})
    end
    refresh_gui(player, tags.unit)
end

function model.on_gui_switch_state_changed(event)
    local element = event.element
    local tags = element.tags
    if tags.action ~= "mode" then return end
    local player = game.get_player(event.player_index)

    if not model.set_mode(tags.unit, element.switch_state == "right") then
        player.print({"exotic-industries.radio-transmitter-taken"})
    end
    refresh_gui(player, tags.unit)
end

--HANDLERS
------------------------------------------------------------------------------------------------------

function model.on_built_entity(entity)
    if model.STATIONS[entity.name] then
        model.register(entity)
    end
end

function model.on_destroyed_entity(entity)
    if model.STATIONS[entity.name] and entity.unit_number then
        model.unregister(entity.unit_number)
    end
end

---Clones (e.g. ships of other mods): the clone gets the settings, hidden outputs are recreated.
function model.on_entity_cloned(source, destination)
    if destination.name == model.OUTPUT then
        destination.destroy()
        return
    end
    if not model.STATIONS[destination.name] then return end

    local original = source.valid and get_stations()[source.unit_number]
    model.register(destination, original and {channel = original.channel} or nil)
end

---Copy & paste of the station settings (the transmitter role is only pasted to a free channel).
function model.on_entity_settings_pasted(event)
    local source, destination = event.source, event.destination
    if not (model.STATIONS[source.name] and model.STATIONS[destination.name]) then return end

    local original = get_stations()[source.unit_number]
    if not original then return end
    if not get_stations()[destination.unit_number] then model.register(destination) end

    model.set_channel(destination.unit_number, original.channel)
end

return model
