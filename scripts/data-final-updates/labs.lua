local science_pack_prototypes = require("lib/science_packs").get_prototypes()
local science_pack_names = {}

-- Use a stable order so lab inputs are built deterministically across runs.
for science_pack_name in pairs(science_pack_prototypes) do
    table.insert(science_pack_names, science_pack_name)
end

table.sort(science_pack_names)


-- Hidden packs and packs already accepted by the large lab are also accepted by the dummy lab.
for _, science_pack_name in ipairs(science_pack_names) do
    local science_pack_prototype = science_pack_prototypes[science_pack_name]

    -- Hidden packs are routed to the dummy lab to prevent missing-lab warnings.
    if science_pack_prototype.hidden then
        if not ei_lib.table_contains_value(data.raw.lab["ei-dummy-lab"].inputs, science_pack_name) then
            table.insert(data.raw.lab["ei-dummy-lab"].inputs, science_pack_name)
        end
    -- Existing large-lab packs are also accepted by the dummy lab.
    elseif ei_lib.table_contains_value(data.raw.lab["ei-big-lab"].inputs, science_pack_name) then
        if not ei_lib.table_contains_value(data.raw.lab["ei-dummy-lab"].inputs, science_pack_name) then
            table.insert(data.raw.lab["ei-dummy-lab"].inputs, science_pack_name)
        end
    -- Other active packs are accepted by the large lab.
    else
        table.insert(data.raw.lab["ei-big-lab"].inputs, science_pack_name)
    end
end

-- Age-specific labs intentionally accept only the packs configured for their stage.
data.raw.lab["ei-dark-age-lab"].inputs = table.deepcopy(ei_data.lab_inputs["dark-age-lab"])
data.raw.lab.lab.inputs = table.deepcopy(ei_data.lab_inputs["lab"])

-- Keep optional third-party research computers compatible with the early science packs.
if data.raw.lab["kr-spaceship-research-computer"] then
    data.raw.lab["kr-spaceship-research-computer"].inputs = table.deepcopy(ei_data.lab_inputs["dark-age-lab"])
end

if data.raw.lab["wood-lab"] then
    data.raw.lab["wood-lab"].inputs = table.deepcopy(ei_data.lab_inputs["dark-age-lab"])
end


-- Assign active EI packs, hidden packs and packs already accepted by the standard lab to the dummy lab.
for _, science_pack_name in ipairs(science_pack_names) do
    local science_pack_prototype = science_pack_prototypes[science_pack_name]
    local dummy_lab_inputs = data.raw.lab["ei-dummy-lab"].inputs

    -- Hidden packs should never become normal research inputs.
    if science_pack_prototype.hidden then
        if not ei_lib.table_contains_value(dummy_lab_inputs, science_pack_name) then
            table.insert(dummy_lab_inputs, science_pack_name)
        end
    -- EI-specific packs need a lab mapping even when they are not used by the vanilla lab.
    elseif string.sub(science_pack_name, 1, 3) == "ei-" then
        if not ei_lib.table_contains_value(dummy_lab_inputs, science_pack_name) then
            table.insert(dummy_lab_inputs, science_pack_name)
        end
    -- Preserve packs configured for the vanilla lab in the dummy lab as well.
    elseif ei_lib.table_contains_value(data.raw.lab.lab.inputs, science_pack_name) then
        if not ei_lib.table_contains_value(dummy_lab_inputs, science_pack_name) then
            table.insert(dummy_lab_inputs, science_pack_name)
        end
    -- Other modded packs are made available to the vanilla lab.
    else
        table.insert(data.raw.lab.lab.inputs, science_pack_name)
    end
end
