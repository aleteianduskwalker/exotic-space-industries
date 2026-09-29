--====================================================================================================
-- LIQUID TILES DESTROY DROPPED ITEMS
--====================================================================================================
-- Items dropped onto water-like tiles (everything a pump can pump from, plus a few extra liquid
-- tiles) are destroyed. Works with modded water tiles as well.

-- no visual effect when an item is destroyed
local dumped_item_trigger = nil

-- liquid tiles that do not (yet) define a fluid at this point
local EXTRA_LIQUID_TILES = {
    "water", "water-green", "deepwater", "deepwater-green",
    "oil-ocean-shallow", "oil-ocean-deep",
    "gleba-deep-lake", "wetland-blue-slime", "wetland-green-slime",
    "ammoniacal-ocean", "ammoniacal-ocean-2",
    "ei-gaia-water",
}

local function destroys_items(tile)
    tile.destroys_dropped_items = true
    tile.default_destroyed_dropped_item_trigger = dumped_item_trigger
end

for _, tile in pairs(data.raw.tile) do
    if tile.fluid then
        destroys_items(tile)
    end
end

for _, name in pairs(EXTRA_LIQUID_TILES) do
    if data.raw.tile[name] then
        destroys_items(data.raw.tile[name])
    end
end
