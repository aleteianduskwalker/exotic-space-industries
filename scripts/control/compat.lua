--====================================================================================================
-- MOD COMPATIBILITY (control stage)
--====================================================================================================

local model = {}

---Called from on_init and on_configuration_changed.
function model.check_init()
    -- Krastorio 2 (Spaced Out): the intergalactic transceiver must not end the game,
    -- the black hole generator is the EI end goal.
    local interface = remote.interfaces["kr-intergalactic-transceiver"]
    if interface and interface["set_no_victory"] then
        remote.call("kr-intergalactic-transceiver", "set_no_victory", true)
    end
end

--====================================================================================================
-- REMOTE INTERFACE
--====================================================================================================

-- other mods can register additional surfaces on which Gaia entity variants are used
remote.add_interface("exotic-industries", {
    add_gaia_surface = function(surface_name)
        storage.gaia_surfaces = storage.gaia_surfaces or {}
        storage.gaia_surfaces[surface_name] = true
    end,
    clear_gaia_surfaces = function()
        -- the Gaia planet surface itself always stays registered
        storage.gaia_surfaces = {["Gaia"] = true}
    end,
})

return model
