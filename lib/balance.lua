--====================================================================================================
-- ESI BALANCE CONFIG (data-driven)
--====================================================================================================
-- Every balance-relevant number of the Alien chain / Gaia hub systems (version 3.1.0) lives here,
-- so it can be tuned in ONE place without touching the logic.
--
-- The file is a plain Lua table without side effects and is loaded in BOTH stages:
--   * data stage    (prototypes: recipes, buildings, technologies)
--   * control stage (runtime scripts: alien tree, orbital combinator, storm EMP, ...)
-- Usage:  local ei_balance = require("lib/balance")
--
-- IMPORTANT (multiplayer): control-stage values must be identical on every peer, so never change
-- this file between a save and its load in multiplayer without updating the mod version.
--
-- Values marked [ASSUMPTION] were not specified by the design document and were chosen by
-- analogy with existing content ("closest similarity"). Tune them after playtests.
--====================================================================================================

---@class EiBalance
local ei_balance = {}

--====================================================================================================
-- GAIA SURFACE CONDITION
--====================================================================================================
-- Gaia is a copy of Fulgora (magnetic field 99) with pressure 2000. No vanilla planet has both
-- values (Gleba: pressure 2000 but magnetic field 10), so this pair identifies Gaia in
-- recipe surface_conditions ("can only be crafted on Gaia").

ei_balance.gaia_surface_conditions = {
    {property = "pressure", min = 2000, max = 2000},
    {property = "magnetic-field", min = 99, max = 99},
}

--====================================================================================================
-- RESONANCE DATA / ALIEN RESONANCE PACK (design doc §3)
--====================================================================================================

-- repairing an alien artifact spills this many ei-resonance-data around the repaired structure
ei_balance.resonance_data_repair_drop = {min = 2, max = 4}

-- ei-resonance-synthesizer: automated, renewable resonance data (unlocked in alien tier 1)
ei_balance.resonance_data_recipe = {
    morphium = 100,          -- ei-morphium (fluid)
    computing_power = 50,    -- ei-computing-power (fluid, data cable)
    result = 3,              -- ei-resonance-data per craft
    time = 30,               -- seconds per craft (=> 6 per minute per synthesizer)
}

-- ei-alien-resonance-pack: second alien science tier (unlocked by alien tier 4)
ei_balance.resonance_pack_recipe = {
    morphium = 50,
    computing_power = 20,
    resonance_data = 2,
    result = 1,              -- [ASSUMPTION] packs per craft (not specified)
    time = 20,               -- [ASSUMPTION] seconds per craft (not specified)
}

--====================================================================================================
-- ALIEN TECH TREE (design doc §4)
--====================================================================================================
-- Currency: "alien knowledge" points, earned ONLY by repairing alien artifacts.
-- [ASSUMPTION] 100 points per repair keeps the author's original node costs (100 .. 2000)
-- meaningful: 1 repair = one tier 1 node, 20 repairs = the most expensive tier 3 node.
ei_balance.alien_points_per_repair = 100

-- Tier 4/5 costs (N = 10, design doc §4 + brief log §2.2).
-- `points`: alien knowledge (N repairs worth of points)
-- `items`:  additionally consumed from the player's main inventory when the node is unlocked
ei_balance.alien_tech_tier4_cost = {
    points = 10 * ei_balance.alien_points_per_repair,
    items = {{name = "ei-resonance-data", count = 10}},
}
ei_balance.alien_tech_tier5_cost = {
    points = 20 * ei_balance.alien_points_per_repair, -- [ASSUMPTION] tier 5 = double tier 4
    items = {{name = "ei-alien-resonance-pack", count = 10}},
}

--====================================================================================================
-- VOID RIFT GENERATOR (design doc §5)
--====================================================================================================

ei_balance.void_rift = {
    patch_size = 5,          -- carved out-of-map patch: patch_size x patch_size tiles
    patch_gap = 1,           -- free tiles between the generator edge and the patch
    resonance_packs = 5,     -- ei-alien-resonance-pack in the building recipe
}

--====================================================================================================
-- ORBITAL COMBINATOR (design doc §6)
--====================================================================================================

ei_balance.orbital_combinator = {
    computing_power_per_minute = 1,  -- consumed only while an orbiting platform has requests
    port_volume = 100,               -- fluid buffer of the hidden computing power port
}

--====================================================================================================
-- STORM EMP (design doc §7)
--====================================================================================================
-- A lightning strike on Gaia that does NOT hit a lightning attractor temporarily disables
-- machines/inserters/combinators around the impact.

ei_balance.storm_emp = {
    radius = 6,                  -- [ASSUMPTION] tiles around the impact ("R")
    duration_ticks = 5 * 60,     -- [ASSUMPTION] how long affected entities stay disabled ("N")
    attractor_check_radius = 2,  -- strikes this close to a lightning attractor are "attracted"
    entity_types = {
        "assembling-machine", "furnace", "lab", "mining-drill", "inserter",
        "arithmetic-combinator", "decider-combinator", "selector-combinator", "constant-combinator",
    },
}

--====================================================================================================
-- CONDUIT (lightning attractor, design doc §8)
--====================================================================================================

ei_balance.conduit = {
    efficiency = 0.8,            -- share of the strike energy converted to electricity
    buffer = "40MJ",             -- energy_source.buffer_capacity
    output_flow_limit = "5MW",   -- energy_source.output_flow_limit (drains the buffer in ~8 s)
    range_elongation = 15,       -- [ASSUMPTION] attraction range, same order as the lightning rod
}

--====================================================================================================
-- DATA CENTER (brief log §2.6, design doc §12)
--====================================================================================================

ei_balance.data_center = {
    time_multiplier = 10,                -- craft time = original science pack recipe time * 10
    computing_power_per_pack = 5,        -- [ASSUMPTION] ei-computing-power per produced pack
    fallback_time = 5,                   -- [ASSUMPTION] seconds if a pack has no recipe to copy
    include_alien_packs = true,          -- false removes the mod's own alien packs from the list
}

return ei_balance
