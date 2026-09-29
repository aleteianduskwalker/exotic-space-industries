--====================================================================================================
-- EI LIB
--====================================================================================================
-- Commonly used helper functions.
--   * STRING / TABLE helpers  : usable in every stage
--   * SETTINGS                : startup settings access
--   * RECIPE / TECH helpers   : data stage only (they modify `data.raw`)
--   * GRAPHICS helpers        : data stage only
--   * CHAT helpers            : control stage only (crystal_echo)
--
-- NOTE: ingredients/results in Factorio 2.0 always use the full format
-- {type = "item", name = "...", amount = n}; the helpers still understand the old short
-- format {"name", amount} for compatibility with third party prototypes.
--====================================================================================================

local ei_lib = {}

--====================================================================================================
--STRING / TABLE HELPERS
--====================================================================================================

function ei_lib.endswith(str, suffix) return str:sub(-string.len(suffix)) == suffix end
function ei_lib.startswith(text, prefix) return text:find(prefix, 1, true) == 1 end
function ei_lib.starts_with(text, prefix) return text:sub(1, #prefix) == prefix end
function ei_lib.contains(s, word) return tostring(s):find(word, 1, true) ~= nil end

-- debug helpers
function ei_lib.sb(s) error(serpent.block(s)) end
function ei_lib.sbp(s) game.print(serpent.block(s)) end

function ei_lib.is_valid_number(x)
    return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

---Returns a new array with all values of `t` (drops the keys).
function ei_lib.clean_nils(t)
    local result = {}
    for _, v in pairs(t) do
        result[#result + 1] = v
    end
    return result
end

function ei_lib.table_contains_value(table_in, value)
    for _, v in pairs(table_in) do
        if v == value then
            return true
        end
    end
    return false
end

---Looks up `key` in `switch_table` (emulates switch-case). Returns nil if not found.
function ei_lib.switch_string(switch_table, key)
    if not switch_table or not key then
        return nil
    end
    return switch_table[key]
end

---Counts all keys of a table (0 for nil).
function ei_lib.getn(table_in)
    if not table_in then return 0 end
    local count = 0
    for _ in pairs(table_in) do
        count = count + 1
    end
    return count
end

--====================================================================================================
--SETTINGS
--====================================================================================================

---Quick access to startup settings "ei-<name>". Returns false for missing settings.
function ei_lib.config(name)
    local setting = settings.startup["ei-" .. name]
    if not setting then return false end

    local val = setting.value
    if type(val) == "boolean" or type(val) == "number" or type(val) == "string" then
        return val
    end
    return false
end

--====================================================================================================
--RECIPE RELATED (data stage)
--====================================================================================================

---Name of an ingredient/result in either short or full format.
local function entry_name(entry)
    return entry.name or entry[1]
end

---Amount of an ingredient/result in either short or full format.
local function entry_amount(entry)
    return entry.amount or entry[2]
end

---Sets the name (and optionally amount) of an ingredient/result in its own format.
local function set_entry(entry, name, amount)
    if entry.name or entry[1] == nil then
        entry.name = name
        if amount then entry.amount = amount end
    else
        entry[1] = name
        if amount then entry[2] = amount end
    end
end

---Replaces `old_ingredient` in a recipe by `new_ingredient` (keeping the amount unless given).
function ei_lib.recipe_swap(recipe, old_ingredient, new_ingredient, amount)
    if not recipe or not old_ingredient or not new_ingredient then
        return
    end

    local prototype = data.raw.recipe[recipe]
    if not prototype then
        log("recipe " .. recipe .. " does not exist in data.raw.recipe")
        return
    end

    local changed = false
    for _, ingredient in pairs(prototype.ingredients or {}) do
        if entry_name(ingredient) == old_ingredient then
            set_entry(ingredient, new_ingredient, amount or entry_amount(ingredient) or 1)
            changed = true
        end
    end

    if changed then
        ei_lib.fix_recipe(recipe)
    end
end

---Merges duplicate ingredients of a recipe (sums up their amounts).
function ei_lib.fix_recipe(recipe)
    local prototype = data.raw.recipe[recipe]
    if not prototype or not prototype.ingredients or not prototype.ingredients[1] then
        return
    end

    local merged = {}
    local by_name = {}
    for _, ingredient in ipairs(prototype.ingredients) do
        local name = entry_name(ingredient)
        local existing = name and by_name[name]
        if existing then
            local total = (entry_amount(existing) or 1) + (entry_amount(ingredient) or 1)
            set_entry(existing, name, total)
        else
            table.insert(merged, ingredient)
            if name then by_name[name] = ingredient end
        end
    end

    prototype.ingredients = merged
end

---Adds a result with optional probability/range to a recipe (made for ash, slag, ...).
---args = {recipe, ingredient, amountmin, amountmax, probability, fluid, allowproductivity}
function ei_lib.recipe_output_add(args)
    if not args then log("no args") return end

    local prototype = data.raw.recipe[args.recipe]
    if not prototype then
        log("recipe " .. tostring(args.recipe) .. " does not exist in data.raw.recipe")
        return
    end
    if not args.ingredient then
        log("recipe " .. args.recipe .. " lacks ingredient")
        return
    end

    local probability = args.probability or 1
    if probability <= 0 then
        log("recipe " .. args.recipe .. " ingredient " .. args.ingredient .. " probability cannot be 0")
        return
    end

    local result = {type = args.fluid and "fluid" or (args.type or "item"), name = args.ingredient}
    if args.amountmax then
        result.amount_min = args.amountmin or 1
        result.amount_max = args.amountmax
    else
        result.amount = args.amountmin or 1
    end
    if probability < 1 then
        result.probability = probability
    end
    if args.allowproductivity == false then
        result.ignored_by_productivity = 1e9
    end

    prototype.results = prototype.results or {}
    table.insert(prototype.results, result)
end

---Adds an ingredient to a recipe, or sets its amount if it is already present.
function ei_lib.recipe_add(recipe, ingredient, amount, fluid)
    amount = amount or 1

    local prototype = data.raw.recipe[recipe]
    if not prototype then
        log("recipe " .. recipe .. " does not exist in data.raw.recipe")
        return
    end

    prototype.ingredients = prototype.ingredients or {}
    local typus = fluid and "fluid" or "item"

    for i, entry in pairs(prototype.ingredients) do
        if entry_name(entry) == ingredient then
            prototype.ingredients[i] = {type = typus, name = ingredient, amount = amount}
            return
        end
    end

    table.insert(prototype.ingredients, {type = typus, name = ingredient, amount = amount})
end

---Removes an ingredient from a recipe.
function ei_lib.recipe_remove(recipe, ingredient)
    local prototype = data.raw.recipe[recipe]
    if not prototype then
        log("recipe " .. recipe .. " does not exist in data.raw.recipe")
        return
    end

    local ingredients = prototype.ingredients or {}
    for i = #ingredients, 1, -1 do
        if entry_name(ingredients[i]) == ingredient then
            table.remove(ingredients, i)
        end
    end
end

---Sets a completely new ingredient list.
function ei_lib.recipe_new(recipe, table_in)
    if not data.raw.recipe[recipe] then
        log("recipe " .. recipe .. " does not exist in data.raw.recipe")
        return
    end
    data.raw.recipe[recipe].ingredients = table_in
end

---Replaces a recipe by an "_alt" copy with new ingredients (keeps technology unlocks).
function ei_lib.recipe_hard_overwrite(recipe, ingredients)
    local new_recipe = table.deepcopy(data.raw.recipe[recipe])
    new_recipe.name = new_recipe.name .. "_alt"
    new_recipe.hidden = false
    new_recipe.ingredients = ingredients
    data:extend({new_recipe})

    local swapped = false
    for tech, _ in pairs(data.raw.technology) do
        if ei_lib.remove_unlock_recipe(tech, recipe) then
            ei_lib.add_unlock_recipe(tech, new_recipe.name)
            swapped = true
        end
    end

    if not swapped then new_recipe.enabled = true end
    data.raw.recipe[recipe].hidden = true
end

--TECH RELATED (data stage)
------------------------------------------------------------------------------------------------------

function ei_lib.set_prerequisites(tech, prerequisites)
    if not data.raw.technology[tech] then
        log("tech " .. tech .. " does not exist in data.raw.technology")
        return
    end

    for _, prerequisite in ipairs(prerequisites) do
        if not data.raw.technology[prerequisite] then
            log("tech " .. prerequisite .. " does not exist in data.raw.technology")
            return
        end
    end

    data.raw.technology[tech].prerequisites = prerequisites
end

---Adds a prerequisite to a technology (no duplicates).
function ei_lib.add_prerequisite(tech, prerequisite)
    if not data.raw.technology[tech] then
        log("tech " .. tech .. " does not exist in data.raw.technology")
        return
    end
    if not data.raw.technology[prerequisite] then
        log("tech " .. prerequisite .. " does not exist in data.raw.technology")
        return
    end

    local technology = data.raw.technology[tech]
    technology.prerequisites = technology.prerequisites or {}

    for _, existing in ipairs(technology.prerequisites) do
        if existing == prerequisite then
            return
        end
    end

    table.insert(technology.prerequisites, prerequisite)
end

---Removes a prerequisite from a technology (dummy techs are left untouched).
function ei_lib.remove_prerequisite(tech, prerequisite)
    local technology = data.raw.technology[tech]
    if not technology then
        log("tech " .. tech .. " does not exist in data.raw.technology")
        return
    end
    if not technology.prerequisites or string.find(tech, "-dummy", 1, true) then
        return
    end

    for i = #technology.prerequisites, 1, -1 do
        if technology.prerequisites[i] == prerequisite then
            table.remove(technology.prerequisites, i)
        end
    end
end

---Removes a science pack from a technology's cost.
function ei_lib.remove_tech_ingredient(tech, ingredient)
    local technology = data.raw.technology[tech]
    if not technology or not technology.unit or not technology.unit.ingredients then
        log("ei_lib.remove_tech_ingredient: " .. tech .. " has no ingredients to remove " .. ingredient .. " from")
        return
    end

    local ingredients = technology.unit.ingredients
    for i = #ingredients, 1, -1 do
        if entry_name(ingredients[i]) == ingredient then
            table.remove(ingredients, i)
        end
    end
end

---Removes an "unlock-recipe" effect from a technology. Returns true if one was removed.
function ei_lib.remove_unlock_recipe(tech, recipe)
    local technology = data.raw.technology[tech]
    if not technology then
        log("tech " .. tech .. " does not exist in data.raw.technology")
        return false
    end
    if not technology.effects then
        return false
    end

    for i, effect in ipairs(technology.effects) do
        if effect.type == "unlock-recipe" and effect.recipe == recipe then
            table.remove(technology.effects, i)
            return true
        end
    end

    return false
end

---Adds an "unlock-recipe" effect to a technology and disables the recipe at game start.
function ei_lib.add_unlock_recipe(tech, recipe)
    local technology = data.raw.technology[tech]
    if not technology then
        log("ei_lib.add_unlock_recipe: tech '" .. tech .. "' does not exist in data.raw.technology")
        return
    end
    if not data.raw.recipe[recipe] then
        log("ei_lib.add_unlock_recipe: " .. recipe .. " does not exist in data.raw.recipe")
        return
    end

    if type(technology.effects) ~= "table" then
        technology.effects = {}
    end

    data.raw.recipe[recipe].enabled = false

    for _, effect in pairs(technology.effects) do
        if effect.type == "unlock-recipe" and effect.recipe == recipe then
            return
        end
    end

    table.insert(technology.effects, {type = "unlock-recipe", recipe = recipe})
end

function ei_lib.convert_short_ingredients_to_full(ingredients)
    for k, v in pairs(ingredients) do
        if v.type == nil then
            ingredients[k] = {type = "item", name = v[1], amount = v[2]}
        end
    end
end

-- default research unit for technologies that were trigger techs
local science_unit_template = {
    count = 10,
    ingredients = {},
    time = 10,
}

---Replaces a technology's cost by a science pack list (removes research triggers).
function ei_lib.set_science_packs(tech, ingredients)
    if not ingredients then error("Tech " .. tech .. " set with no ingredients.") end
    local technology = data.raw.technology[tech]
    if not technology then return end

    technology.research_trigger = nil
    technology.unit = technology.unit or table.deepcopy(science_unit_template)
    technology.unit.ingredients = table.deepcopy(ingredients)
end

function ei_lib.set_age_packs(tech, age)
    if not ei_data.science[age] then error("ei_data.science does not have age " .. age) end
    ei_lib.set_science_packs(tech, ei_data.science[age])
end

---Copies the research unit of one technology to another.
function ei_lib.copy_science_packs(tech_to, tech_from)
    local target = data.raw.technology[tech_to]
    local source = data.raw.technology[tech_from]
    if not target or not source or not source.unit then return end

    target.research_trigger = nil
    target.unit = table.deepcopy(source.unit)
    target.hidden = false
    source.hidden = false
end

---Hides a technology and removes it from all prerequisite lists.
function ei_lib.remove_tech(tech)
    if not data.raw.technology[tech] then
        log("tech " .. tech .. " does not exist in data.raw.technology")
        return
    end

    for name, _ in pairs(data.raw.technology) do
        ei_lib.remove_prerequisite(name, tech)
    end

    data.raw.technology[tech].enabled = false
    data.raw.technology[tech].hidden = true
end

---Removes a technology and hides every prototype with the same name (item, recipe, entity...).
function ei_lib.disable(id)
    if data.raw.technology[id] then
        ei_lib.remove_tech(id)
    end

    for tech_name, _ in pairs(data.raw.technology) do
        ei_lib.remove_unlock_recipe(tech_name, id)
    end

    for _, prototypes_of_type in pairs(data.raw) do
        if prototypes_of_type[id] then
            prototypes_of_type[id].hidden = true
        end
    end
end

function ei_lib.enable(id)
    for _, prototypes_of_type in pairs(data.raw) do
        if prototypes_of_type[id] then
            prototypes_of_type[id].hidden = false
        end
    end
end

function ei_lib.enable_from_start(id)
    for _, prototypes_of_type in pairs(data.raw) do
        if prototypes_of_type[id] then
            prototypes_of_type[id].hidden = false
            prototypes_of_type[id].enabled = true
        end
    end
end

--GENERAL PROTOTYPES RELATED (data stage)
------------------------------------------------------------------------------------------------------

---Recursively copies `source` into `target`; keys starting with "_" are ignored.
local function recursive_copy(target, source)
    for key, value in pairs(source) do
        if tostring(key):find("^_") ~= 1 then
            if type(value) == "table" then
                target[key] = target[key] or {}
                recursive_copy(target[key], value)
            else
                target[key] = value
            end
        end
    end
end

---Updates (overwrites) attributes of an existing prototype. `obj` needs `name` and `type`;
---properties starting with an underscore are ignored.
function ei_lib.set_properties(obj)
    if not (obj and obj.name and obj.type) then
        log(serpent.log({["Invalid object:"] = obj}))
        return
    end
    local prototype = data.raw[obj.type][obj.name]
    if not prototype then
        log("Could not find prototype" .. obj.type .. "/" .. obj.name)
        return
    end
    recursive_copy(prototype, obj)
end

---Replaces `old` by `new` in the ingredients/results of one recipe.
local function replace_in_recipe(recipe, old, new)
    for _, list in pairs({recipe.ingredients, recipe.results}) do
        for _, entry in pairs(list or {}) do
            if entry_name(entry) == old then
                set_entry(entry, new)
            end
        end
    end
    if recipe.main_product == old then
        recipe.main_product = new
    end
    if recipe.result == old then
        recipe.result = new
    end
end

---Swaps fluid `fluid` by `target` in all recipes and hides `fluid`.
function ei_lib.merge_fluid(target, fluid, icon_transfer)
    if not data.raw.fluid[target] or not data.raw.fluid[fluid] then return end

    for _, recipe in pairs(data.raw.recipe) do
        replace_in_recipe(recipe, fluid, target)
    end

    if icon_transfer then
        data.raw.fluid[target].icon = data.raw.fluid[fluid].icon
        data.raw.fluid[target].icon_size = data.raw.fluid[fluid].icon_size
    end

    data.raw.fluid[fluid].hidden = true
end

---Swaps item `item` by `target` in all recipes, entity mining results and technology triggers,
---then hides `item`.
function ei_lib.merge_item(target, item, icon_transfer)
    if not data.raw.item[target] or not data.raw.item[item] then return end

    for _, recipe in pairs(data.raw.recipe) do
        replace_in_recipe(recipe, item, target)
        ei_lib.fix_recipe(recipe.name)
    end

    -- mining results (rocks, trees, resources, ...)
    for _, prototypes_of_type in pairs(data.raw) do
        for _, prototype in pairs(prototypes_of_type) do
            local minable = type(prototype) == "table" and prototype.minable
            if type(minable) == "table" then
                if minable.result == item then
                    minable.result = target
                end
                for _, result in pairs(minable.results or {}) do
                    if entry_name(result) == item then
                        set_entry(result, target)
                    end
                end
            end
        end
    end

    -- research triggers ("craft-item")
    for _, technology in pairs(data.raw.technology) do
        local trigger = technology.research_trigger
        if trigger and trigger.item == item then
            trigger.item = target
        end
    end

    if icon_transfer then
        data.raw.item[target].icon = data.raw.item[item].icon
        data.raw.item[target].icon_size = data.raw.item[item].icon_size
    end

    data.raw.item[item].hidden = true
end

-- kept for compatibility with older code
function ei_lib.do_fluid_merge(recipe, target, fluid) replace_in_recipe(recipe, fluid, target) end
function ei_lib.do_item_merge(recipe, target, item) replace_in_recipe(recipe, item, target) end

--====================================================================================================
--GRAPHICS FUNCTIONS (data stage)
--====================================================================================================

---Path of an empty sprite of the given size (64, 128 or 256) from the graphics mod.
function ei_lib.empty_sprite(size)
    if size == 128 then
        return ei_graphics_path .. "graphics/128_empty.png"
    elseif size == 256 then
        return ei_graphics_path .. "graphics/256_empty.png"
    end
    return ei_graphics_path .. "graphics/64_empty.png"
end

-- from base factorio
function ei_lib.make_4way_animation_from_spritesheet(animation)
    local function make_animation_layer(idx, anim)
        local start_frame = (anim.frame_count or 1) * idx
        local x = 0
        local y = 0
        if anim.line_length then
            y = anim.height * math.floor(start_frame / (anim.line_length or 1))
        else
            x = idx * anim.width
        end
        return {
            filename = anim.filename,
            priority = anim.priority or "high",
            flags = anim.flags,
            x = x,
            y = y,
            width = anim.width,
            height = anim.height,
            frame_count = anim.frame_count or 1,
            line_length = anim.line_length,
            repeat_count = anim.repeat_count,
            shift = anim.shift,
            draw_as_shadow = anim.draw_as_shadow,
            force_hr_shadow = anim.force_hr_shadow,
            apply_runtime_tint = anim.apply_runtime_tint,
            animation_speed = anim.animation_speed,
            scale = anim.scale or 1,
            tint = anim.tint,
            blend_mode = anim.blend_mode,
        }
    end

    local function make_animation(idx)
        if animation.layers then
            local tab = {layers = {}}
            for _, layer in ipairs(animation.layers) do
                table.insert(tab.layers, make_animation_layer(idx, layer))
            end
            return tab
        end
        return make_animation_layer(idx, animation)
    end

    return {
        north = make_animation(0),
        east = make_animation(1),
        south = make_animation(2),
        west = make_animation(3),
    }
end

---Universal circuit connector definition shifted by (Dx, Dy).
function ei_lib.make_circuit_connector(Dx, Dy)
    local function sprite(filename, width, height, x, y, shift_x, shift_y, extra)
        local result = {
            filename = "__base__/graphics/entity/circuit-connector/" .. filename,
            width = width,
            height = height,
            x = x,
            y = y,
            priority = "low",
            scale = 0.5,
            shift = {shift_x + Dx, shift_y + Dy},
        }
        for k, v in pairs(extra or {}) do
            result[k] = v
        end
        return result
    end

    local circuit_wire_connection_point = {
        shadow = {
            green = {0.671875 + Dx, 0.609375 + Dy},
            red = {0.890625 + Dx, 0.5625 + Dy},
        },
        wire = {
            green = {0.453125 + Dx, 0.453125 + Dy},
            red = {0.390625 + Dx, 0.21875 + Dy},
        },
    }

    local circuit_connector_sprites = {
        blue_led_light_offset = {0.125 + Dx, 0.46875 + Dy},
        connector_main = sprite("ccm-universal-04a-base-sequence.png", 52, 50, 104, 150, 0.09375, 0.203125),
        connector_shadow = sprite("ccm-universal-04b-base-shadow-sequence.png", 62, 46, 124, 138, 0.3125, 0.3125, {draw_as_shadow = true}),
        led_blue = sprite("ccm-universal-04e-blue-LED-on-sequence.png", 60, 60, 120, 180, 0.09375, 0.171875, {draw_as_glow = true}),
        led_blue_off = sprite("ccm-universal-04f-blue-LED-off-sequence.png", 46, 44, 92, 132, 0.09375, 0.171875),
        led_green = sprite("ccm-universal-04h-green-LED-sequence.png", 48, 46, 96, 138, 0.09375, 0.171875, {draw_as_glow = true}),
        led_light = {intensity = 0, size = 0.9},
        led_red = sprite("ccm-universal-04i-red-LED-sequence.png", 48, 46, 96, 138, 0.09375, 0.171875, {draw_as_glow = true}),
        red_green_led_light_offset = {0.109375 + Dx, 0.359375 + Dy},
        wire_pins = sprite("ccm-universal-04c-wire-sequence.png", 62, 58, 124, 174, 0.09375, 0.171875),
        wire_pins_shadow = sprite("ccm-universal-04d-wire-shadow-sequence.png", 70, 54, 140, 162, 0.25, 0.296875, {draw_as_shadow = true}),
    }

    return {
        circuit_wire_connection_point,
        circuit_connector_sprites,
    }
end

---Adds a tier overlay ("1".."5", "filter", ...) to an item icon.
function ei_lib.add_item_level(item, level)
    local prototype = data.raw.item[item]
    if not prototype or not prototype.icon then
        return
    end

    prototype.icons = {
        {icon = prototype.icon, icon_size = prototype.icon_size or 64},
        {icon = ei_graphics_other_path .. "overlay_" .. level .. ".png", icon_size = 64},
    }
    prototype.icon = nil
    prototype.icon_size = nil
end

--====================================================================================================
--OTHER (data stage)
--====================================================================================================

---Logs every crafting category with its recipes and machines (debug helper).
function ei_lib.debug_crafting_categories()
    local output = {}
    local blacklist_category = {
        ["void-crushing"] = true,
        ["fuel-burning"] = true,
    }

    for name, _ in pairs(data.raw["recipe-category"]) do
        if not blacklist_category[name] then
            local info = {category = name, recipes = {}, machines = {}}

            for _, recipe in pairs(data.raw.recipe) do
                if recipe.category == name
                    and not (ei_lib.starts_with(recipe.name, "fill-") or ei_lib.starts_with(recipe.name, "empty-")) then
                    table.insert(info.recipes, recipe.name)
                end
            end

            for _, source in pairs({"assembling-machine", "furnace", "rocket-silo"}) do
                for _, entity in pairs(data.raw[source]) do
                    if ei_lib.table_contains_value(entity.crafting_categories or {}, name) then
                        table.insert(info.machines, entity.type .. "/" .. entity.name)
                    end
                end
            end

            output[name] = info
        end
    end
    log(serpent.block(output))
end

--====================================================================================================
--CRYSTAL MESSAGES (control stage)
--====================================================================================================

function ei_lib.lerp_color(c1, c2, t)
    return {
        math.floor(c1[1] + (c2[1] - c1[1]) * t + 0.5),
        math.floor(c1[2] + (c2[2] - c1[2]) * t + 0.5),
        math.floor(c1[3] + (c2[3] - c1[3]) * t + 0.5),
    }
end

function ei_lib.rgb_to_hex(rgb)
    return string.format("%02x%02x%02x", rgb[1], rgb[2], rgb[3])
end

local GRADIENT_COLORS = {
    {112, 48, 160},  -- Royal purple
    {0, 123, 167},   -- Cerulean
    {186, 85, 211},  -- Orchid flare
    {72, 209, 204},  -- Crystal teal
    {255, 105, 180}, -- Etheric pink
    {240, 230, 140}, -- Dream gold
    {50, 205, 50},   -- Verdant flux
    {255, 69, 0},    -- Solar flare
}

---Picks 2..4 random colours for a gradient (uses the synchronised game RNG).
function ei_lib.pick_gradient_stops()
    local stops = {}
    for _ = 1, math.random(2, 4) do
        table.insert(stops, GRADIENT_COLORS[math.random(1, #GRADIENT_COLORS)])
    end
    return stops
end

---Splits a string into UTF-8 characters (emoji and other multibyte characters stay intact).
local function utf8_chars(text)
    local chars = {}
    for char in string.gmatch(text, "[%z\1-\127\194-\244][\128-\191]*") do
        chars[#chars + 1] = char
    end
    return chars
end

---Prints a message with a random colour gradient to everyone (or only to `target`, a LuaPlayer
---or LuaForce). Must be called from synchronised game events only (it uses math.random).
function ei_lib.crystal_echo(msg, font, target)
    local gradient = ei_lib.pick_gradient_stops()
    local segments = #gradient - 1
    local chars = utf8_chars(msg)
    local total_chars = #chars
    local result = {}

    for i, letter in ipairs(chars) do
        local t = (i - 1) / math.max(1, total_chars - 1)
        local segment = math.min(math.floor(t * segments) + 1, #gradient)
        local local_t = (t * segments) % 1
        local c1 = gradient[segment]
        local c2 = gradient[segment + 1] or c1
        local hex = ei_lib.rgb_to_hex(ei_lib.lerp_color(c1, c2, local_t))

        if font then
            result[#result + 1] = "[font=" .. font .. "][color=#" .. hex .. "]" .. letter .. "[/color][/font]"
        else
            result[#result + 1] = "[color=#" .. hex .. "]" .. letter .. "[/color]"
        end
    end

    local text = table.concat(result)
    if target and target.valid then
        target.print(text)
    else
        game.print(text)
    end
end

return ei_lib
