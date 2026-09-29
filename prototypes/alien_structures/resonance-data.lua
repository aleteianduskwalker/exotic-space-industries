--====================================================================================================
-- RESONANCE DATA (design doc §3, §9)
--====================================================================================================
-- Intermediate of the second alien science tier.
-- Sources:
--   1) repairing an alien artifact spills 2-4 pieces (scripts/control/alien_system.lua,
--      model.repair_artifact) - finite, one-time source
--   2) ei-resonance-synthesizer recipe (prototypes/alien_structures/resonance-synthesizer.lua)
--      - renewable source, unlocked in alien tech tier 1
-- Consumers: ei-alien-resonance-pack recipe, alien tech tier 4 node (lib/balance.lua).
--====================================================================================================

data:extend({
    {
        name = "ei-resonance-data",
        type = "item",
        -- final icon by request: the same as ei-simulation-data
        icon = ei_graphics_item_path.."simulation-data.png",
        icon_size = 128,
        subgroup = "ei-alien-items",
        order = "b-a",
        stack_size = 200,
    },
})
