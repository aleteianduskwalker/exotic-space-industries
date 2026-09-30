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

-- ei-resonance-synthesizer: renewable resonance data (lab technology ei-resonance-synthesizer).
-- 3.2.0: the recipe multiplies existing data (1 -> 2) instead of creating it from nothing, so the
-- first pieces always come from repaired / salvaged artifacts.
ei_balance.resonance_data_recipe = {
    morphium = 100,          -- ei-morphium (fluid)
    computing_power = 50,    -- ei-computing-power (fluid, data cable)
    resonance_data = 1,      -- consumed ei-resonance-data per craft
    result = 2,              -- produced ei-resonance-data per craft (net +1)
    time = 30,               -- seconds per craft
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
-- Currency: "alien knowledge" points, earned by repairing alien artifacts and (3.2.0) by salvaging
-- broken ones on Gaia. The tree itself is defined in lib/alien_tree.lua.
-- [ASSUMPTION] 100 points per repair keeps the author's original node costs (100 .. 2000)
-- meaningful: 1 repair = one tier 1 node, 20 repairs = the most expensive tier 3 node.
ei_balance.alien_points_per_repair = 100

-- 3.2.0: mining / deconstructing / destroying a broken (unrepaired) artifact on Gaia grants 10 % of
-- the repair reward. No points are granted anymore once every node of the tree is unlocked.
ei_balance.alien_points_per_salvage = ei_balance.alien_points_per_repair / 10

-- 3.2.0: alien knowledge can be substituted from the player's main inventory when a node is paid.
-- Payment priority: alien knowledge points -> alien resonance packs -> resonance data.
ei_balance.alien_points_per_resonance_pack = 10   -- 1 ei-alien-resonance-pack = 10 points
ei_balance.resonance_data_per_alien_point = 10    -- 10 ei-resonance-data = 1 point

-- 3.2.0: loot of broken (unrepaired) artifacts. Salvaging them no longer returns the ruin itself but
-- a small random amount of high tier resources ({name, min, max, probability}); used for both mining
-- (minable.results) and destruction (loot). Keys are the broken entity name prefixes.
ei_balance.artifact_salvage = {
    ["ei-crystal-accumulator_off"] = {
        {"ei-high-energy-crystal", 1, 1, 1},
        {"ei-energy-crystal", 2, 4, 1},
    },
    ["ei-farstation_off"] = {
        {"ei-magnet", 1, 3, 1},
        {"ei-electronic-parts", 2, 5, 1},
        {"ei-high-energy-crystal", 1, 1, 0.5},
    },
    ["ei-alien-beacon_off"] = {
        {"ei-high-energy-crystal", 1, 2, 1},
        {"ei-alien-resin", 2, 5, 1},
        {"ei-resonance-data", 1, 1, 0.5},
    },
    ["ei-alien-console_off"] = {
        {"ei-resonance-data", 2, 4, 1},
        {"ei-electronic-parts", 2, 4, 1},
        {"ei-high-energy-crystal", 1, 1, 0.5},
    },
}

-- 3.2.0: ALIEN TERMINAL (ei-alien-console, prototypes/alien_structures/alien-console.lua)
-- Access point of the alien tech tree: nodes can only be bought near a terminal of the own force.
ei_balance.alien_console = {
    range = 16,                -- max distance (tiles) between the player's character and a terminal
    gaia_only = true,          -- terminals work (and can be built) only on Gaia
    slots = 10,                -- inventory slots (resonance packs / data for the auto conversion)
    conversion_interval = 60,  -- ticks between two conversions of the inventory into knowledge
    repair_bonus = 200,        -- one-time knowledge bonus of a repaired terminal (plus the repair reward)
}

-- Tier 4/5 costs (N = 10, design doc §4 + brief log §2.2). Every node of a tier shares its cost.
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

-- ei-conduit-gaia (3.2.0): non-craftable copy that replaces the fulgoran ruin attractors on Gaia.
-- It only attracts lightning (no energy source) and can not be mined or destroyed.
ei_balance.conduit = {
    efficiency = 0.8,            -- share of the strike energy converted to electricity
    buffer = "40MJ",             -- energy_source.buffer_capacity
    output_flow_limit = "5MW",   -- energy_source.output_flow_limit (drains the buffer in ~8 s)
    range_elongation = 15,       -- [ASSUMPTION] attraction range, same order as the lightning rod
}

--====================================================================================================
-- DATA CENTER (brief log §2.6, design doc §12)
--====================================================================================================

-- 3.2.0: every data center recipe produces exactly 1 pack and costs 1 computing power per UNIQUE
-- component in the recursive production tree of the pack (see data_center_recipes.lua).
ei_balance.data_center = {
    time_multiplier = 10,                -- craft time = original science pack recipe time * 10
    fallback_time = 5,                   -- [ASSUMPTION] seconds if a pack has no recipe to copy
    fallback_computing_power = 100,      -- used when the component walk is too deep / too large
    max_depth = 25,                      -- recursion depth limit of the component walk
    max_components = 400,                -- abort the walk after this many unique components
    max_visited_recipes = 2000,          -- abort the walk after this many inspected recipes
    include_alien_packs = true,          -- false removes the mod's own alien packs from the list
}

--====================================================================================================
-- GAIA BOULDERS (3.2.0)
--====================================================================================================
-- Six families of Gaia boulders (prototypes/alien_structures/gaia-boulders.lua). Each family uses
-- some of the 15 sprites of graphics-2/graphics/terrain/gaia-boulder-<n>.png as random variations.
--   sprites      sprite numbers used as variations
--   results      mining results {name, min, max, probability}
--   probability  autoplace probability per tile on Gaia ("sometimes alone")
-- Rocks of the ruin presets (POI) spawned on Gaia are replaced by these boulders at runtime.
ei_balance.gaia_boulders = {
    violet    = {sprites = {1, 2},          results = {{"stone", 12, 20, 1}, {"ei-energy-crystal", 1, 2, 0.3}}, probability = 0.00025},
    red       = {sprites = {3, 4},          results = {{"stone", 12, 20, 1}, {"iron-ore", 5, 10, 1}},           probability = 0.00025},
    slate     = {sprites = {5, 6},          results = {{"stone", 12, 20, 1}, {"copper-ore", 5, 10, 1}},         probability = 0.00025},
    basalt    = {sprites = {7, 8, 9},       results = {{"stone", 12, 20, 1}, {"coal", 8, 15, 1}},               probability = 0.0003},
    ice       = {sprites = {10, 11},        results = {{"ice", 10, 20, 1}, {"ei-cryodust", 1, 3, 0.5}},         probability = 0.0002},
    sandstone = {sprites = {12, 13, 14, 15}, results = {{"stone", 8, 15, 1}, {"ei-sand", 10, 20, 1}},           probability = 0.0004},
}

--====================================================================================================
-- DRONES (3.2.0)
--====================================================================================================
-- Script drones of the drone port (prototypes/alien_structures/drone-port.lua,
-- scripts/control/drone_port.lua). A flying drone is only a picture: no collision, invulnerable.
ei_balance.drones = {
    capacity = 50,                  -- items a drone carries per trip
    speed = 0.3,                    -- tiles per tick
    range = 64,                     -- max distance of every task position from the port (tiles)
    flight_height = 1.5,            -- drawn height above its shadow (tiles)
    port_slots = 10,                -- port inventory slots (filters: drones, repair packs, loot)
    port_buffer = "20MJ",           -- energy buffer of the port
    port_input = "2MW",             -- max charge rate of the buffer
    port_idle_usage = "100kW",      -- constant consumption of a built port
    trip_energy = 1000000,          -- J taken from the port buffer for every departure of a drone
    mining_speed = 0.5,             -- resource mining speed (same as a player)
    salvage_time_multiplier = 1,    -- salvage duration = mining_time * multiplier (seconds)
    repair_health_per_second = 30,  -- repaired health per second per point of repair tool "speed"
    repair_packs_per_trip = 10,     -- repair packs loaded per trip (durability is taken exactly)
    max_zone_size = 21,             -- guard zone: max width / height (tiles)
    scan_interval = 60,             -- ticks between two scans of an idle guard / waiting drone
    logic_interval = 10,            -- ticks between two logic steps of a working drone
}

--====================================================================================================
-- RADIO STATIONS (3.2.0)
--====================================================================================================
-- Wireless circuit network channels: one transmitter per channel, any number of receivers.
ei_balance.radio_station = {
    energy_usage = "100kW",              -- ei-radio-station (same surface only)
    crystal_energy_usage = "10MW",       -- ei-crystal-radio-station (every surface)
    update_interval = 6,                 -- ticks between two signal transfers
}

return ei_balance
