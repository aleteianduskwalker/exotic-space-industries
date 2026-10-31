-- Factorio 2.1 represents science packs as item prototypes rather than tool prototypes.
local space_science_pack = data.raw.item["space-science-pack"]
local ei_space_data = data.raw.item["ei-space-data"]

-- Keep the vanilla science pack's icon consistent with Exotic Industries space data.
if space_science_pack and ei_space_data then
    space_science_pack.icon = ei_space_data.icon
    space_science_pack.pictures = ei_space_data.pictures
    space_science_pack.icon_size = ei_space_data.icon_size
end

data.raw['item']["iron-plate"].icon = ei_graphics_item_path.."iron-ingot.png"
data.raw['item']["copper-plate"].icon = ei_graphics_item_path.."copper-ingot.png"
data.raw['item']["steel-plate"].icon = ei_graphics_item_path.."steel-ingot.png"

data.raw['item']["iron-plate"].subgroup = "ei-refining-ingot"
data.raw['item']["copper-plate"].subgroup = "ei-refining-ingot"
data.raw['item']["steel-plate"].subgroup = "ei-refining-ingot"
data.raw['item']["ei-gold-ingot"].subgroup = "ei-refining-ingot"
data.raw['item']["ei-lead-ingot"].subgroup = "ei-refining-ingot"
data.raw['item']["ei-neodym-ingot"].subgroup = "ei-refining-ingot"

ei_lib.disable("automation-science-pack")
ei_lib.disable("logistic-science-pack")
ei_lib.disable("chemical-science-pack")
ei_lib.disable("military-science-pack")
ei_lib.disable("production-science-pack")
ei_lib.disable("utility-science-pack")

local science_pack_prototypes = require("lib/science_packs").get_prototypes()

for _, item in pairs(data.raw.item) do
  local is_science_pack = science_pack_prototypes[item.name] ~= nil

  -- Preserve science-pack stack sizes; in Factorio 2.1 they now live in data.raw.item.
  if not is_science_pack and item.stack_size and item.stack_size > 100 then
    item.stack_size = 500
  end

  -- Keep the existing barrel stack-size rule for ordinary items.
  if ei_lib.endswith(item.name, "-barrel") then
    item.stack_size = 100
  end
end

-- Gun prototypes live in data.raw.gun, not data.raw.item.
for _, gun in pairs(data.raw.gun or {}) do
  if gun.stack_size then
    gun.stack_size = 1
  end
end

table.insert(data.raw['simple-entity']['fulgurite'].minable.results, {
  amount_max = 1,
  amount_min = 0,
  name = "ei-alien-seed",
  type = "item"
})