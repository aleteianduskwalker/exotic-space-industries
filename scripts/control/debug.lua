--====================================================================================================
-- DEBUG COMMANDS
--====================================================================================================

local model = {}

---"/tp <surface name or index>": teleports an admin to (0, 0) of the given surface.
function model.teleport_to(event)
    if event.command ~= "tp" or not event.parameters or not event.player_index then
        return
    end

    local player = game.get_player(event.player_index)
    if not player or not player.admin then
        return
    end

    local destination = game.get_surface(tonumber(event.parameters) or event.parameters)
    if destination == nil then
        return
    end

    player.print("Teleporting")
    player.teleport({0, 0}, destination)
end

return model
