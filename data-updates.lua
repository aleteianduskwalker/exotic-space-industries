--====================================================================================================
--PRE UPDATES
--====================================================================================================

-- info

ei_mod.stage = "data-updates"
ei_lib = require("lib/lib")

--====================================================================================================
--CONTENT UPDATES
--====================================================================================================



-- reorganize vanilla data

-- remove vanilla resources from autoplace-controls
require("scripts/data-updates/vanilla_resources")
-- set science costs to startPrice and set prerequisite to "ei-temp" tech for vanilla techs
require("scripts/data-updates/tech_flattening")
-- set prerequisites of vanilla techs for IE
require("scripts/data-updates/tech_structure")
-- apply vanilla patches
require("scripts/data-updates/vanilla_patches")

-- add metalworks
require("prototypes/metalworks")
-- apply icon patches
require("scripts/data-updates/icon_updates")
-- apply locale patches
require("scripts/data-updates/locale_updates")

-- Проверяем сложность прототипов погрузчиков в настройках
if ei_lib.config("loader-prototype-complexity") then
  require("scripts/data-updates/loader_patches")
end

-- apply mod patches
require("scripts/data-updates/nanobot_patches")
require("scripts/data-updates/fmf_patches")
require("scripts/data-updates/sp_patches")
require("scripts/data-updates/flow_control_patches")
require("scripts/data-updates/teleporters_patches")
require("scripts/data-updates/solar_patches")
require("scripts/data-updates/text_plates_patches")
require("scripts/data-updates/extra_storage_tanks_patches")



--====================================================================================================
--ROCKET LIFT CAPACITY BUFF
--====================================================================================================



-- Если бафф грузоподъемности ракет отключен в настройках запуска, завершаем обработку
if settings.startup["ei-rocket-lift-capacity-buff"].value == 0 then
  return
end

-- Применяем множитель к грузоподъемности ракет и вместимости посадочной площадки.
local size_multiplier = settings.startup["ei-rocket-lift-capacity-buff"].value
local utility_constants = data.raw["utility-constants"]["default"]
local default_rocket_lift_weight = utility_constants.default_rocket_lift_weight
local increased_rocket_lift_weight = default_rocket_lift_weight * size_multiplier

-- Обновляем общее значение, используемое подсказками и интерфейсом игры.
utility_constants.default_rocket_lift_weight = increased_rocket_lift_weight

-- Вес стартового пакета должен соответствовать увеличенной грузоподъемности ракеты.
local space_platform_starter_pack = data.raw["space-platform-starter-pack"]["space-platform-starter-pack"]
space_platform_starter_pack.weight = increased_rocket_lift_weight

-- В Factorio 2.1 грузоподъемность задается через lift_weight, а не через weight.
local rocket_silo = data.raw["rocket-silo"]["rocket-silo"]
rocket_silo.lift_weight = increased_rocket_lift_weight
rocket_silo.cargo_station_parameters.prefer_packed_cargo_units = false

-- Вместимость посадочной площадки определяется размером ее инвентаря.
local cargo_landing_pad = data.raw["cargo-landing-pad"]["cargo-landing-pad"]
cargo_landing_pad.inventory_size = cargo_landing_pad.inventory_size * size_multiplier

-- В режиме запуска на космические платформы это поле игнорируется игрой.
rocket_silo.to_be_inserted_to_rocket_inventory_size = 90