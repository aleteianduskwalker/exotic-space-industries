--====================================================================================================
-- ECHO CODEX: GAIA REFORGER
--====================================================================================================
-- "/esi-gaia-reborn" checks the Gaia surface and, if it does not contain any of the Gaia gas
-- patches (broken map generation, e.g. an old save or a mod conflict), deletes and regenerates it.
--
-- The process is a small state machine driven by `echo_codex.reforge_gaia_surface`, which is
-- called periodically (see control.lua) while storage.ei.gaia_reforged == 0:
--   1. surface has patches        -> done (gaia_reforged = 1)
--   2. surface exists, no patches -> evacuate players and delete it (deletion happens at the end
--                                    of the tick, so the next step runs on a later call)
--   3. surface missing            -> create it again from the planet map gen settings
-- After MAX_ATTEMPTS failed regenerations the process stops to avoid an endless loop.
--====================================================================================================

local echo_codex = {}

local GAIA = "Gaia"
local MAX_ATTEMPTS = 5

local PATCH_RESOURCES = {
    "ei-phytogas-patch",
    "ei-cryoflux-patch",
    "ei-ammonia-patch",
    "ei-coal-gas-patch",
}

local GAIA_TILES = {
    "ei-gaia-grass-1",
    "ei-gaia-grass-1-var",
    "ei-gaia-grass-2",
    "ei-gaia-grass-2-var",
    "ei-gaia-grass-2-var-2",
    "ei-gaia-rock-1",
    "ei-gaia-rock-2",
    "ei-gaia-rock-3",
    "ei-gaia-water",
}

echo_codex.surface_messages = {
    forging_needed = {
        "☄ [Forging Initiated] — Rebuilding Gaia surface with correct resonance...",
        "🔧 [Terraform Protocol Active] — Overwriting corrupted structure...",
        "⚙️ [Sigil of Reform] — Gaia does not match its crystalline record. Invocation begins.",
        "🌋 [Architectural Drift] — Planetary manifold unstable. Reforging rituals deployed.",
    },
    evacuation = {
        "🚷 [Relocation Warning] — Biostructural sync collapsing. Returning to Nauvis...",
        "🚨 [Evacuation Directive] — Players removed from destabilizing plane: Gaia.",
        "🧬 [Phase Collapse Detected] — Displacing all organic signatures to safe cradle.",
    },
    surface_destroying = {
        "⌬ [Astral Scaffold Deconstructed] — Gaia has been unshaped. Preparing for spectral convergence...",
        "💥 [Gaia Disassembled] — Surface entropy complete. Awaiting renewal.",
        "💣 [Cradle Collapse] — Deleted corrupted surface. Beginning rebirth cycle.",
        "🌌 [Dimensional Rift Sealed] — Gaia’s shell has been destroyed. Void rests for now.",
    },
    surface_created = {
        "✧ [Bloom Reinitiated] — The harmonic skeleton has reemerged. Awaiting resource resonance...",
        "🌱 [Gaia Born Anew] — Reformed substrate breathing. Awaiting soulstone.",
        "🔄 [Gaia Cycle Reset] — Planet surface reconstruction succeeded.",
        "🌟 [Terraform Success] — New astral surface online. Next: resonance scan.",
    },
    no_resources = {
        "✖ [Gaian Echo Lost] — No soulstone signature recovered. The garden lies fallow. Restarting terraformation incantation...",
        "🌑 [Dead Soil Detected] — No resources found. Reattempting spiritual formatting...",
        "🕯 [Void Crust] — Failed to locate any geologic resonance. Restarting surface...",
        "⛓ [Anchor Missing] — Resonance test returned null. Restart sequence required.",
    },
    surface_finalized = {
        "⛧ [Core Integrity Verified] — Autogenic substrate lattice normalized. Biome reformation phase stabilized.",
        "🌐 [Reality Anchor Stable] — Gaia’s soul aligned with simulation grid. Finalized.",
        "✅ [Harmonic Sync] — Surface stabilization completed. Integration confirmed.",
    },
}

---Prints a random message of the given category.
function echo_codex.random_surface_echo(category)
    local pool = echo_codex.surface_messages[category]
    if not pool then
        ei_lib.crystal_echo("❓ [Echo Unknown] — No prophecy prepared for category: " .. tostring(category))
        return
    end
    ei_lib.crystal_echo(pool[math.random(1, #pool)])
end

---Returns true if the surface contains at least one of the given entity names.
local function surface_contains_any(surface, names)
    for _, name in pairs(names) do
        if prototypes.entity[name] and surface.count_entities_filtered{name = name, limit = 1} > 0 then
            return true
        end
    end
    return false
end

---Map gen settings used to recreate Gaia (planet settings with the Gaia patches/tiles enforced).
local function gaia_map_gen_settings()
    local settings = table.deepcopy(prototypes.space_location[GAIA].map_gen_settings)

    settings.autoplace_controls = settings.autoplace_controls or {}
    settings.autoplace_settings = settings.autoplace_settings or {}
    settings.autoplace_settings.entity = settings.autoplace_settings.entity or {settings = {}}
    settings.autoplace_settings.entity.settings = settings.autoplace_settings.entity.settings or {}
    settings.autoplace_settings.tile = settings.autoplace_settings.tile or {settings = {}}
    settings.autoplace_settings.tile.settings = settings.autoplace_settings.tile.settings or {}

    for _, resource in ipairs(PATCH_RESOURCES) do
        if prototypes.autoplace_control[resource] then
            settings.autoplace_controls[resource] = {frequency = 3, size = 1, richness = 1}
        end
        settings.autoplace_settings.entity.settings[resource] = {frequency = 3, size = 1, richness = 1}
    end

    for _, tile in ipairs(GAIA_TILES) do
        settings.autoplace_settings.tile.settings[tile] = {frequency = 1, size = 1, richness = 1}
    end

    return settings
end

local function finish(message_category)
    storage.ei.gaia_reforged = 1
    storage.ei.gaia_reforge_deleting = nil
    storage.ei.gaia_reforge_attempts = nil
    echo_codex.random_surface_echo(message_category)
end

---One step of the reforge state machine (see header).
function echo_codex.reforge_gaia_surface()
    if storage.ei.gaia_reforged ~= 0 then
        return
    end

    local surface = game.get_surface(GAIA)

    -- 1. healthy surface
    if surface and surface_contains_any(surface, PATCH_RESOURCES) then
        finish("surface_finalized")
        return
    end

    -- 2. broken surface: delete it (deletion is deferred to the end of the tick)
    if surface then
        if storage.ei.gaia_reforge_deleting then
            return
        end

        local attempts = (storage.ei.gaia_reforge_attempts or 0) + 1
        storage.ei.gaia_reforge_attempts = attempts
        if attempts > MAX_ATTEMPTS then
            storage.ei.gaia_reforged = 1
            storage.ei.gaia_reforge_attempts = nil
            ei_lib.crystal_echo("✖ Gaia could not be regenerated with resources after " .. MAX_ATTEMPTS .. " attempts. Check for mods changing the Gaia map generation.")
            return
        end

        echo_codex.random_surface_echo(attempts == 1 and "forging_needed" or "no_resources")

        for _, player in pairs(game.players) do
            if player.surface == surface then
                echo_codex.random_surface_echo("evacuation")
                player.teleport({0, 0}, "nauvis")
            end
        end

        game.delete_surface(surface)
        storage.ei.gaia_reforge_deleting = true
        echo_codex.random_surface_echo("surface_destroying")
        return
    end

    -- 3. no surface: create it again
    storage.ei.gaia_reforge_deleting = nil

    -- the planet creates (and owns) its surface again; this also works when Gaia entities require
    -- heating (associate_surface refuses such planets)
    local planet = game.planets[GAIA]
    if planet then
        surface = planet.create_surface()
    else
        surface = game.create_surface(GAIA, gaia_map_gen_settings())
    end

    surface.request_to_generate_chunks({0, 0}, 20)
    surface.force_generate_chunk_requests()

    for _, force in pairs(game.forces) do
        if #force.players > 0 then
            force.chart_all(surface)
        end
    end

    echo_codex.random_surface_echo("surface_created")
end

---/esi-gaia-reborn: start the consistency check (the actual work is done over the next seconds).
function echo_codex.gaia_reborn(command)
    local player = command and command.player_index and game.get_player(command.player_index)
    if player and not player.admin then
        player.print("Only admins can use this command.")
        return
    end

    ei_lib.crystal_echo("Performing Gaia consistency check")
    storage.ei.gaia_reforged = 0
    storage.ei.gaia_reforge_deleting = nil
    storage.ei.gaia_reforge_attempts = nil
    echo_codex.reforge_gaia_surface()
end

return echo_codex
