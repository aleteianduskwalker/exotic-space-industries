--====================================================================================================
-- INFORMATRON MESSAGER
--====================================================================================================
-- Prints "Informatron wiki updated!" when a technology is researched that makes a wiki page
-- relevant. 3.1.0: the research handler was an empty stub and model.notify was never called.
-- TECH_PAGES: technology name -> localised page title (keys of [exotic-industries-informatron]).
--====================================================================================================

local model = {}

local TECH_PAGES = {
    ["ei-black-hole"] = "title_black_hole",
    ["ei-gate"] = "title_gate",
    ["ei-induction-matrix"] = "title_induction_matrix",
    ["ei-resonance-synthesizer"] = "title_alien",
    ["ei-data-center"] = "title_gaia_hub",
    ["ei-radio-station"] = "title_radio_stations",
}

---Prints the wiki update message for a page title key to a force.
---@param force LuaForce
---@param title_key string key in [exotic-industries-informatron]
function model.notify(force, title_key)
    force.print({"exotic-industries.message-informatron", {"exotic-industries-informatron." .. title_key}})
end

--HANDLERS
------------------------------------------------------------------------------------------------------

function model.on_research_finished(event)
    local research = event.research
    local title_key = TECH_PAGES[research.name]
    -- by_script: researched through commands/other scripts (e.g. the alien tree) - still relevant
    if title_key then
        model.notify(research.force, title_key)
    end
end

return model
