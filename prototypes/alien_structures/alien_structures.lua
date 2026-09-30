--====================================================================================================
--MAIN CONTENT CODE
--====================================================================================================

-- prototype definitions for buildable entities get seperate files
-- those include prototype definitions for recipes, items, techs and categories

-- add alien beacon
require("alien-beacon")
-- add alien stabilizer
require("alien-stabilizer")
-- add new tiles
require("gaia-tiles")
-- add new trees
require("gaia-trees")
-- add gate
require("gate")
-- add crystal accumulator
require("crystal-accumulator")
-- add farsation
require("farstation")
-- add other
require("alien-structures")
-- add other
require("gaia-planet")
-- 3.1.0: Alien chain / Gaia hub (design doc "ESI: Alien chain and Gaia hub")
-- resonance data item (repair drop + synthesizer product)
require("resonance-data")
-- resonance synthesizer (clone of the small simulator) + tier 1 technology
require("resonance-synthesizer")
-- alien resonance pack + alien tier 4 technology "resonant computation"
require("resonance-pack")
-- void rift generator + alien tier 5 technology "threshold engineering"
require("void-rift-generator")
-- conduit: lightning attractor that harvests the Gaia storms (alien tree tier 1) + ei-conduit-gaia
require("conduit")
