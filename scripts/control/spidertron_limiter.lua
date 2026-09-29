local model = {}

--====================================================================================================
--SPIDERTRON LIMITER
--====================================================================================================
-- The spiderling (SpidertronPatrols) may only request fuel items through its logistic sections.

---Clears a logistic request slot that does not request a fuel item.
function model.remove_nonfuel_requests(event)
    if not (event.entity and event.section and event.slot_index) then
        return
    end

    local slot = event.section.get_slot(event.slot_index)
    local name = slot and slot.value and slot.value.name
    if name and not ei_lib.endswith(name, "fuel") then
        event.section.clear_slot(event.slot_index)

        local player = event.player_index and game.get_player(event.player_index)
        local message = "Only fuel items can be requested for this spidertron."
        if player then
            player.print(message)
        else
            event.entity.force.print(message)
        end
    end
end

function model.on_entity_logistic_slot_changed(event)

    -- spider vehicle as spiderling should only allow request of fuel
    if not event then return end
    if not event.entity then return end
    local entity = event.entity
    if not entity.type then return end
--    local inbound_slots = entity.logistic_sections["inbound"]
--    if not inbound_slots then return end

    if entity.type ~= "spider-vehicle" then
        return
    end

    if entity.name == "sp-spiderling" then
        model.remove_nonfuel_requests(event)
    end

end


return model