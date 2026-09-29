--====================================================================================================
-- CONTROL UTILITIES
--====================================================================================================
-- Small, dependency-free helpers shared by all runtime (control stage) modules.
--
-- MULTIPLAYER / DESYNC RULES followed by every module of this mod:
--   * Every value that influences game state lives in `storage` (it is saved and synced).
--     Plain Lua globals / upvalues are only allowed for constants and module references.
--   * `next(tbl, key)` must never be called with a key that is no longer present in `tbl`:
--     a freshly loaded client does not have "dead" keys that the server still has, which
--     results in `invalid key to 'next'` on one peer only. Use `util.next_key` instead.
--   * Never branch game logic on per-client data (GUI state, player.opened of a remote client
--     is fine - it is synced - but local settings, os time, etc. are not).
--====================================================================================================

local util = {}

---Returns true if `obj` is a non-nil LuaObject that is still valid.
---@param obj any LuaEntity, LuaRenderObject, LuaSurface, LuaPlayer, ...
---@return boolean
function util.is_valid(obj)
    return obj ~= nil and obj.valid == true
end

---Safe round-robin iterator step over a keyed table (e.g. entities indexed by unit number).
---Returns the key that follows `key`; wraps around to the first key at the end of the table.
---If `key` was removed from the table in the meantime, iteration restarts from the beginning
---instead of calling `next` with an invalid key (which would crash / desync).
---@param tbl table
---@param key any|nil current cursor (may be nil or stale)
---@return any|nil next_key nil when the table is empty
function util.next_key(tbl, key)
    if key ~= nil and tbl[key] ~= nil then
        local following = next(tbl, key)
        if following ~= nil then
            return following
        end
    end
    return (next(tbl))
end

---Round-robin step over an array (1..n). Returns the next index, wrapping around.
---@param array table
---@param index integer|nil current index (may exceed the array length after removals)
---@return integer|nil next_index nil when the array is empty
function util.next_index(array, index)
    local count = #array
    if count == 0 then
        return nil
    end
    if not index or index >= count or index < 1 then
        return 1
    end
    return index + 1
end

---Destroys a LuaRenderObject if it is still valid. Safe to call with nil.
---@param render_object LuaRenderObject|nil
function util.destroy_render(render_object)
    if render_object and render_object.valid then
        render_object.destroy()
    end
end

---Destroys an entity if it is still valid. Safe to call with nil.
---@param entity LuaEntity|nil
---@param raise_destroy boolean|nil
function util.destroy_entity(entity, raise_destroy)
    if entity and entity.valid then
        entity.destroy({raise_destroy = raise_destroy or false})
    end
end

---Clamps `value` into the [min_value, max_value] range.
function util.clamp(value, min_value, max_value)
    if value < min_value then return min_value end
    if value > max_value then return max_value end
    return value
end

---Returns the player that caused an event, or nil.
---@param event table any event with an optional player_index
---@return LuaPlayer|nil
function util.event_player(event)
    if not event or not event.player_index then
        return nil
    end
    local player = game.get_player(event.player_index)
    if player and player.valid then
        return player
    end
    return nil
end

---Returns the entity the player currently has opened (entity GUI), or nil.
---@param player LuaPlayer
---@return LuaEntity|nil
function util.opened_entity(player)
    if not (player and player.valid) then
        return nil
    end
    if player.opened_gui_type ~= defines.gui_type.entity then
        return nil
    end
    local opened = player.opened
    if opened and opened.valid and opened.object_name == "LuaEntity" then
        return opened
    end
    return nil
end

---Prints a message to the force of an entity (instead of spamming every force/player).
---@param entity LuaEntity
---@param message LocalisedString
function util.force_print(entity, message)
    if entity and entity.valid and entity.force and entity.force.valid then
        entity.force.print(message)
    else
        game.print(message)
    end
end

return util
