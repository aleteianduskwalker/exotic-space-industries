-- add basic heat pipes
-- with max temp of 275 dec
-- but way better heat transfer

ei_data = require("lib/data")

--====================================================================================================
--BASIC HEAT PIPE
--====================================================================================================

data:extend({
    {
        name = "ei-basic-heat-pipe",
        type = "item",
        icon = ei_graphics_item_path.."basic-heat-pipe.png",
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = "energy",
        order = "f[nuclear-energy]-b[basic-heat-pipe]",
        place_result = "ei-basic-heat-pipe",
        stack_size = 50
    },
    {
        name = "ei-basic-heat-pipe",
        type = "recipe",
        category = "crafting",
        energy_required = 1,
        ingredients =
        {
            {type="item", name="steel-plate", amount=1},
            {type="item", name="iron-plate", amount=2},
            {type="item", name="copper-plate", amount=2},
        },
        results = {{type="item", name="ei-basic-heat-pipe", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-basic-heat-pipe",
    },
})

local pipe = table.deepcopy(data.raw["heat-pipe"]["heat-pipe"])

pipe.name = "ei-basic-heat-pipe"
pipe.icon = ei_graphics_item_path.."basic-heat-pipe.png"
pipe.icon_size = 64
pipe.minable.result = "ei-basic-heat-pipe"
pipe.mining_speed = 0.5

pipe.heat_buffer.max_temperature = 275
pipe.heat_buffer.specific_heat = ei_data.specific_heat
pipe.heat_buffer.minimum_glow_temperature = pipe.heat_buffer.max_temperature * 0.5

-- loop over connection sprites and change the filename of EVERY variant
-- (3.2.0 fix: the old loop wrote filename/size onto the variant list itself, so the whole list was
-- read as one sprite and only the last variant of each direction was ever shown)

for _, variants in pairs(pipe.connection_sprites) do
    for _, sprite in ipairs(variants) do
        -- keep only the file name of the vanilla sprite, e.g. "heat-pipe-straight-vertical-3.png"
        local file = sprite.filename:gsub("^(.*/)", "")

        sprite.filename = ei_graphics_heat_path.."cold_connections/".."hr-"..file
        sprite.scale = 0.5
        sprite.height = 64
        sprite.width = 64
    end
end

for i,v in pairs(pipe.heat_glow_sprites) do

    for j,k in ipairs(pipe.heat_glow_sprites[i]) do
        -- if layers
        if pipe.heat_glow_sprites[i][j].layers then
            -- remove the path from filename
            local file = pipe.heat_glow_sprites[i][j].layers[1].filename:gsub("^(.*/)", "")
            -- change the filename and hr version
            pipe.heat_glow_sprites[i][j].layers[1].filename = ei_graphics_heat_path.."heated_connections/".."hr-"..file
            pipe.heat_glow_sprites[i][j].layers[1].scale = 0.5
            pipe.heat_glow_sprites[i][j].layers[1].height = 64
            pipe.heat_glow_sprites[i][j].layers[1].width = 64
        

            pipe.heat_glow_sprites[i][j].layers[2].filename = ei_graphics_heat_path.."heated_connections/".."hr-"..file
            pipe.heat_glow_sprites[i][j].layers[2].scale = 0.5
            pipe.heat_glow_sprites[i][j].layers[2].height = 64
            pipe.heat_glow_sprites[i][j].layers[2].width = 64
            pipe.heat_glow_sprites[i][j].layers[2].draw_as_light = true
        end
    end
end

data:extend({pipe})