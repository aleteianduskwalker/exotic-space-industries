local model = {}

--====================================================================================================
--INFORMATRON
--====================================================================================================

remote.add_interface("exotic-industries-informatron", {
    informatron_menu = function(data)
      return model.menu(data.player_index)
    end,
    informatron_page_content = function(data)
      return model.page_content(data.page_name, data.player_index, data.element)
    end
})

--MENU
------------------------------------------------------------------------------------------------------

function model.menu(player_index)

    local player = game.get_player(player_index)
    local force = nil

    if player then
        force = player.force
    end

    local model = {
        game_related = {
            overall = 1,
            ages_and_tech = 1,
        },
        world_gen_related = {
            resources = 1,
            artifacts = 1,
            -- 3.1.0: the old "knowledge" gate (storage.ei.knowledge, never set anywhere) made
            -- gate/repair unreachable; they are permanent menu entries now
            repair = 1,
            alien = 1,
            gate = 1,
        },
        new_logistics = {
            train_progression = 1,
            cranes_and_belts = 1,
            radio_stations = 1,
            drones = 1,
        },
        new_mechanics = {
            beacon_overhaul = 1,
            specialised_pipes = 1,
            gaia_hub = 1,
            induction_matrix = 1,
            exotic_stabilizer = 1,
        },
        nuclear_fission_and_fusion = {
            fission = 1,
            fusion_power = 1,
        },
    }

    -- optional pages
    if force then
        model.new_mechanics.black_hole = 1
    end

    return model

    -- NOTE: here the force is hardcoded to player, support for multiple forces is not implemented therefore

end

-- strucure of stuff

-- GAME RELATED:
--  - remind to check settings
--  - ages and tech (tiered labs)
--  - how research cost scaling works

-- WORLD GEN REALTED:
--  - resources: stone, surface patches and veins
--  - artifacts
--  - artifact repair, alien tech tree (alien knowledge), gate

-- NEW LOGISTCS:
--  - EI has tons of new logistic options
--  - train progression + fuel for trains / spidertrons
--  - inserter cranes
--  - bots

-- NEW MECHANICS:
--  - Beacon overhaul
--  - spezialised pipes and cables
--  - Induction matrix
--  - Exotic explosives

-- NUCLEAR FISSION AND FUSION:
--  - changes to fission + nuclear waste
--  - HTR reactor
--  - Fusion power
--  - Neutrons and you

-- DISCOVERIES:
-- - TODO new things


--CONTENT
------------------------------------------------------------------------------------------------------

function model.exotic_industries_informatron(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.welcome"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.welcome-text"}}

    local image_container = element.add{type = "flow"}
    image_container.style.horizontal_align = "center"
    image_container.style.horizontally_stretchable = true
    image_container.add{type = "sprite", sprite = "ei-plasma-cube-logo"}

    element.add{type = "label", caption = {"exotic-industries-informatron.welcome-text-2"}}
end


function model.game_related(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.game-related"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.game-related-text"}}
end

function model.overall(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.overall"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.overall-text"}}

    element.add{type = "label", caption = {"exotic-industries-informatron.biters"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.biters-text"}}
end

function model.ages_and_tech(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.ages-and-tech"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.ages-and-tech-text"}}

    local image_container = element.add{type = "flow"}
    image_container.style.horizontal_align = "center"
    image_container.style.horizontally_stretchable = true

    element.add{type = "label", caption = {"exotic-industries-informatron.ages-and-tech-2"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.ages-and-tech-text-2"}}

    -- technology cost scaling (the old "N % of the previous age" gate was removed in 3.2.0)
    element.add{type = "label", caption = {"exotic-industries-informatron.tech"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.tech-text"}}

end


function model.world_gen_related(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.world-gen-related"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.world-gen-related-text"}}
end

function model.resources(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.resources"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.resources-text"}}

    -- 3.1.0: the "surface patches" block was removed - its heading and text were empty strings
    element.add{type = "label", caption = {"exotic-industries-informatron.veins"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.veins-text"}}

    local image_container = element.add{type = "flow"}
    image_container.style.horizontal_align = "center"
    image_container.style.horizontally_stretchable = true
    image_container.add{type = "sprite", sprite = "ei-uranium_patch"}
end

function model.artifacts(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.artifacts"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.artifacts-text"}}

    local image_container = element.add{type = "flow"}
    image_container.style.horizontal_align = "center"
    image_container.style.horizontally_stretchable = true
    image_container.add{type = "sprite", sprite = "ei-artifact"}
end

function model.gate(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.gate"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.gate-text"}}

    local image_container = element.add{type = "flow"}
    image_container.style.horizontal_align = "center"
    image_container.style.horizontally_stretchable = true
    image_container.add{type = "sprite", sprite = "ei-gate"}

    -- 3.2.0: calibration with planet samples (other/<rock>-rock.png illustrations)
    element.add{type = "label", caption = {"exotic-industries-informatron.gate-calibration"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.gate-calibration-text"}}

    local samples = element.add{type = "flow", direction = "horizontal"}
    samples.style.horizontal_align = "center"
    samples.style.horizontally_stretchable = true
    samples.style.horizontal_spacing = 16
    for _, sample in pairs({
        {"mars", "vulcanus"}, {"uran", "gleba"}, {"sulf", "fulgora"}, {"exotic", "aquilo"}, {"moon", "gaia"},
    }) do
        local item = "ei-planet-sample-" .. sample[2]
        if prototypes.item[item] then
            samples.add{type = "sprite", sprite = "ei-planet-sample-" .. sample[1], tooltip = prototypes.item[item].localised_name}
        end
    end
end

-- 3.1.0: own page (no longer repeats the artifacts introduction), mentions resonance data
function model.repair(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.repair"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.repair-text"}}

    element.add{type = "label", caption = {"exotic-industries-informatron.resonance"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.resonance-text"}}
end

-- 3.1.0: alien tech tree page (was referenced by alien_system.lua but never registered)
function model.alien(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.alien"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.alien-text"}}
    ei_alien_system.make_tiers(player_index, element)
end


function model.new_logistics(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.new-logistics"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.new-logistics-text"}}
end

function model.train_progression(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.train-progression"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.train-progression-text"}}

    local image_container = element.add{type = "flow"}
    image_container.style.horizontal_align = "center"
    image_container.style.horizontally_stretchable = true
    image_container.add{type = "sprite", sprite = "ei-train_progression"}

    element.add{type = "label", caption = {"exotic-industries-informatron.spidertron"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.spidertron-text"}}
end

function model.cranes_and_belts(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.cranes-and-belts"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.cranes-and-belts-text"}}

    local image_container = element.add{type = "flow"}
    image_container.style.horizontal_align = "center"
    image_container.style.horizontally_stretchable = true
    image_container.add{type = "sprite", sprite = "ei-robots"}

    element.add{type = "label", caption = {"exotic-industries-informatron.bots"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.bots-text"}}
end


-- 3.2.0: wireless circuit network channels
function model.radio_stations(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.radio-stations"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.radio-stations-text"}}
end


-- 3.2.0: drone port and script drones
function model.drones(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.drones"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.drones-text"}}
end


function model.new_mechanics(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.new-mechanics"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.new-mechanics-text"}}
end

function model.beacon_overhaul(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.beacon-overhaul"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.beacon-overhaul-text"}}

    local image_container = element.add{type = "flow"}
    image_container.style.horizontal_align = "center"
    image_container.style.horizontally_stretchable = true
    image_container.add{type = "sprite", sprite = "ei-beacons"}
end

function model.specialised_pipes(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.specialised-pipes"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.specialised-pipes-text"}}

    local image_container = element.add{type = "flow"}
    image_container.style.horizontal_align = "center"
    image_container.style.horizontally_stretchable = true
    image_container.add{type = "sprite", sprite = "ei-pipes"}
end

-- 3.1.0: Gaia as the hub of the system (design doc "Alien chain and Gaia hub")
function model.gaia_hub(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.gaia-hub"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.gaia-hub-text"}}

    element.add{type = "label", caption = {"exotic-industries-informatron.storm"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.storm-text"}}

    local image_container = element.add{type = "flow"}
    image_container.style.horizontal_align = "center"
    image_container.style.horizontally_stretchable = true
    image_container.add{type = "sprite", sprite = "ei-conduit"}

    element.add{type = "label", caption = {"exotic-industries-informatron.data-center"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.data-center-text"}}

    image_container = element.add{type = "flow"}
    image_container.style.horizontal_align = "center"
    image_container.style.horizontally_stretchable = true
    image_container.add{type = "sprite", sprite = "ei-data_center"}

    element.add{type = "label", caption = {"exotic-industries-informatron.orbital-combinator"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.orbital-combinator-text"}}

    element.add{type = "label", caption = {"exotic-industries-informatron.void-rift"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.void-rift-text"}}
end

function model.induction_matrix(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.induction-matrix"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.induction-matrix-text"}}

    local image_container = element.add{type = "flow"}
    image_container.style.horizontal_align = "center"
    image_container.style.horizontally_stretchable = true
    image_container.add{type = "sprite", sprite = "ei-induction_matrix"}

    element.add{type = "label", caption = {"exotic-industries-informatron.induction-matrix-2"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.induction-matrix-2-text"}}
end

function model.exotic_stabilizer(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.exotic-stabilizers"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.exotic-stabilizers-text"}}

    local image_container = element.add{type = "flow"}
    image_container.style.horizontal_align = "center"
    image_container.style.horizontally_stretchable = true
    image_container.add{type = "sprite", sprite = "ei-exotic_stabilizers"}
end

function model.black_hole(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.black-hole"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.black-hole-text"}}

    local image_container = element.add{type = "flow"}
    image_container.style.horizontal_align = "center"
    image_container.style.horizontally_stretchable = true
    image_container.add{type = "sprite", sprite = "ei-black_hole"}

    element.add{type = "label", caption = {"exotic-industries-informatron.black-hole-2"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.black-hole-2-text"}}

    element.add{type = "label", caption = {"exotic-industries-informatron.black-hole-3"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.black-hole-3-text"}}
end


function model.nuclear_fission_and_fusion(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.nuclear-fission-and-fusion"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.nuclear-fission-and-fusion-text"}}
end

function model.fission(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.fission-reactors"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.fission-reactors-text"}}

    local image_container = element.add{type = "flow"}
    image_container.style.horizontal_align = "center"
    image_container.style.horizontally_stretchable = true
    image_container.add{type = "sprite", sprite = "ei-fission_reactors"}

    element.add{type = "label", caption = {"exotic-industries-informatron.fission-reactors-2"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.fission-reactors-2-text"}}
end

function model.fusion_power(player_index, element)
    element.add{type = "label", caption = {"exotic-industries-informatron.fusion-power"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.fusion-power-text"}}

    local image_container = element.add{type = "flow"}
    image_container.style.horizontal_align = "center"
    image_container.style.horizontally_stretchable = true
    image_container.add{type = "sprite", sprite = "ei-fusion_power"}

    element.add{type = "label", caption = {"exotic-industries-informatron.fusion-power-2"}, style = "heading_1_label"}
    element.add{type = "label", caption = {"exotic-industries-informatron.fusion-power-2-text"}}
end

-- page name -> content function (page names come from model.menu + the root page)
local PAGES = {
    ["exotic-industries-informatron"] = model.exotic_industries_informatron,
    game_related = model.game_related,
    overall = model.overall,
    ages_and_tech = model.ages_and_tech,
    world_gen_related = model.world_gen_related,
    resources = model.resources,
    artifacts = model.artifacts,
    repair = model.repair,
    alien = model.alien,
    gate = model.gate,
    new_logistics = model.new_logistics,
    train_progression = model.train_progression,
    cranes_and_belts = model.cranes_and_belts,
    radio_stations = model.radio_stations,
    drones = model.drones,
    new_mechanics = model.new_mechanics,
    beacon_overhaul = model.beacon_overhaul,
    specialised_pipes = model.specialised_pipes,
    gaia_hub = model.gaia_hub,
    induction_matrix = model.induction_matrix,
    exotic_stabilizer = model.exotic_stabilizer,
    black_hole = model.black_hole,
    nuclear_fission_and_fusion = model.nuclear_fission_and_fusion,
    fission = model.fission,
    fusion_power = model.fusion_power,
}

---Builds the content of one InformaTron page.
function model.page_content(page_name, player_index, element)
    local page = PAGES[page_name]
    if page then
        page(player_index, element)
    end
end

return model
