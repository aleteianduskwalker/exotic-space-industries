# Неиспользуемые PNG-спрайты — Exotic Space Industries 3.2.0

Метод: data-стадия мода (все зависимости base / space-age, настройки по умолчанию) прогнана в эмуляторе; из `data.raw` (включая `gui-style`) собраны все пути `__exotic-space-industries*__/...`. Control-стадия файлов напрямую не использует (только имена спрайтов-прототипов, которые уже в `data.raw`). Файл из списка считается неиспользуемым, если его путь не встречается в загруженных прототипах.

Итого: в списке 2026 файлов, используется 1392, **не используется 629** (+5 используются только вместе с Krastorio2).

Исправлено в 3.2.0 по итогам первой версии отчёта: тепловые трубы снова используют все варианты спрайтов, у продвинутого и превосходного бура свои остатки (tier_1 больше не перезаписывается), удалена неиспользуемая таблица `ei_pipe_basic`, исправлен путь с двойным слэшем `entities//64x64_empty.png`, удалён мёртвый `stone_well_pump.lua`; валуны `gaia-boulder-1…15` задействованы как валуны Гайи; графика дрона и порта дронов задействована новой системой дронов.


## 1. Версии низкого разрешения (в Factorio 2.0 используются только hr-версии) (295)

Для каждого файла рядом есть используемый `hr-`вариант.


**exotic-space-industries-graphics-1/graphics/belts/**

- neo-splitter-east-top_patch.png
- neo-splitter-east.png
- neo-splitter-north.png
- neo-splitter-south.png
- neo-splitter-west-top_patch.png
- neo-splitter-west.png
- neo-transport-belt.png
- neo-underground-belt-structure-back-patch.png
- neo-underground-belt-structure-front-patch.png
- neo-underground-belt-structure.png

**exotic-space-industries-graphics-1/graphics/data-pipes/**

- fluid-background.png
- steam.png

**exotic-space-industries-graphics-1/graphics/entities/**

- coke-furnace.png
- heat-chemical-plant.png
- reactor-lights-color.png
- reactor.png

**exotic-space-industries-graphics-1/graphics/heat-pipes/cold_connections/**

- heat-pipe-corner-down-left-1.png
- heat-pipe-corner-down-left-2.png
- heat-pipe-corner-down-left-3.png
- heat-pipe-corner-down-left-4.png
- heat-pipe-corner-down-left-5.png
- heat-pipe-corner-down-left-6.png
- heat-pipe-corner-down-right-1.png
- heat-pipe-corner-down-right-2.png
- heat-pipe-corner-down-right-3.png
- heat-pipe-corner-down-right-4.png
- heat-pipe-corner-down-right-5.png
- heat-pipe-corner-down-right-6.png
- heat-pipe-corner-up-left-1.png
- heat-pipe-corner-up-left-2.png
- heat-pipe-corner-up-left-3.png
- heat-pipe-corner-up-left-4.png
- heat-pipe-corner-up-left-5.png
- heat-pipe-corner-up-left-6.png
- heat-pipe-corner-up-right-1.png
- heat-pipe-corner-up-right-2.png
- heat-pipe-corner-up-right-3.png
- heat-pipe-corner-up-right-4.png
- heat-pipe-corner-up-right-5.png
- heat-pipe-corner-up-right-6.png
- heat-pipe-ending-down-1.png
- heat-pipe-ending-left-1.png
- heat-pipe-ending-right-1.png
- heat-pipe-ending-up-1.png
- heat-pipe-straight-horizontal-1.png
- heat-pipe-straight-horizontal-2.png
- heat-pipe-straight-horizontal-3.png
- heat-pipe-straight-horizontal-4.png
- heat-pipe-straight-horizontal-5.png
- heat-pipe-straight-horizontal-6.png
- heat-pipe-straight-vertical-1.png
- heat-pipe-straight-vertical-2.png
- heat-pipe-straight-vertical-3.png
- heat-pipe-straight-vertical-4.png
- heat-pipe-straight-vertical-5.png
- heat-pipe-straight-vertical-6.png
- heat-pipe-straight-vertical-single.png
- heat-pipe-t-1.png
- heat-pipe-t-down-1.png
- heat-pipe-t-left-1.png
- heat-pipe-t-right-1.png
- heat-pipe-t-up-1.png

**exotic-space-industries-graphics-1/graphics/heat-pipes/heated_connections/**

- heated-corner-down-left-1.png
- heated-corner-down-left-2.png
- heated-corner-down-left-3.png
- heated-corner-down-left-4.png
- heated-corner-down-left-5.png
- heated-corner-down-left-6.png
- heated-corner-down-right-1.png
- heated-corner-down-right-2.png
- heated-corner-down-right-3.png
- heated-corner-down-right-4.png
- heated-corner-down-right-5.png
- heated-corner-down-right-6.png
- heated-corner-up-left-1.png
- heated-corner-up-left-2.png
- heated-corner-up-left-3.png
- heated-corner-up-left-4.png
- heated-corner-up-left-5.png
- heated-corner-up-left-6.png
- heated-corner-up-right-1.png
- heated-corner-up-right-2.png
- heated-corner-up-right-3.png
- heated-corner-up-right-4.png
- heated-corner-up-right-5.png
- heated-corner-up-right-6.png
- heated-ending-down-1.png
- heated-ending-left-1.png
- heated-ending-right-1.png
- heated-ending-up-1.png
- heated-straight-horizontal-1.png
- heated-straight-horizontal-2.png
- heated-straight-horizontal-3.png
- heated-straight-horizontal-4.png
- heated-straight-horizontal-5.png
- heated-straight-horizontal-6.png
- heated-straight-vertical-1.png
- heated-straight-vertical-2.png
- heated-straight-vertical-3.png
- heated-straight-vertical-4.png
- heated-straight-vertical-5.png
- heated-straight-vertical-6.png
- heated-t-1.png
- heated-t-down-1.png
- heated-t-left-1.png
- heated-t-right-1.png
- heated-t-up-1.png

**exotic-space-industries-graphics-1/graphics/insulated-pipes/**

- fluid-background.png
- pipe-corner-down-left.png
- pipe-corner-down-right.png
- pipe-corner-up-left.png
- pipe-corner-up-right.png
- pipe-cross.png
- pipe-ending-down.png
- pipe-ending-left.png
- pipe-ending-right.png
- pipe-ending-up.png
- pipe-horizontal-window-background.png
- pipe-straight-horizontal-window.png
- pipe-straight-horizontal.png
- pipe-straight-vertical-single.png
- pipe-straight-vertical-window.png
- pipe-straight-vertical.png
- pipe-t-down.png
- pipe-t-left.png
- pipe-t-right.png
- pipe-t-up.png
- pipe-to-ground-down.png
- pipe-to-ground-left.png
- pipe-to-ground-right.png
- pipe-to-ground-up.png
- pipe-vertical-window-background.png
- steam.png

**exotic-space-industries-graphics-1/graphics/other/V453000-entities/**

- assembling-machine-3-mask.png
- beaconed-assembling-machine-3-overlay.png

**exotic-space-industries-graphics-1/graphics/other/kirazy-semi-classic-mining-drill/tier_1/**

- electric-mining-drill-E-front.png
- electric-mining-drill-E-integration.png
- electric-mining-drill-E-light.png
- electric-mining-drill-E-output.png
- electric-mining-drill-E-shadow.png
- electric-mining-drill-E-smoke.png
- electric-mining-drill-E-wet-fluid-background-front.png
- electric-mining-drill-E-wet-fluid-flow-front.png
- electric-mining-drill-E-wet-front.png
- electric-mining-drill-E-wet-shadow.png
- electric-mining-drill-E-wet-window-background-front.png
- electric-mining-drill-E-wet.png
- electric-mining-drill-E.png
- electric-mining-drill-N-integration.png
- electric-mining-drill-N-light.png
- electric-mining-drill-N-output.png
- electric-mining-drill-N-shadow.png
- electric-mining-drill-N-smoke.png
- electric-mining-drill-N-wet-fluid-background-front.png
- electric-mining-drill-N-wet-fluid-background.png
- electric-mining-drill-N-wet-fluid-flow-front.png
- electric-mining-drill-N-wet-fluid-flow.png
- electric-mining-drill-N-wet-front.png
- electric-mining-drill-N-wet-shadow.png
- electric-mining-drill-N-wet-window-background-front.png
- electric-mining-drill-N-wet-window-background.png
- electric-mining-drill-N-wet.png
- electric-mining-drill-N.png
- electric-mining-drill-S-front.png
- electric-mining-drill-S-integration.png
- electric-mining-drill-S-light.png
- electric-mining-drill-S-output.png
- electric-mining-drill-S-shadow.png
- electric-mining-drill-S-smoke.png
- electric-mining-drill-S-wet-fluid-background.png
- electric-mining-drill-S-wet-fluid-flow.png
- electric-mining-drill-S-wet-front.png
- electric-mining-drill-S-wet-shadow.png
- electric-mining-drill-S-wet-window-background.png
- electric-mining-drill-S-wet.png
- electric-mining-drill-S.png
- electric-mining-drill-W-front.png
- electric-mining-drill-W-integration.png
- electric-mining-drill-W-light.png
- electric-mining-drill-W-output.png
- electric-mining-drill-W-shadow.png
- electric-mining-drill-W-smoke.png
- electric-mining-drill-W-wet-fluid-background-front.png
- electric-mining-drill-W-wet-fluid-flow-front.png
- electric-mining-drill-W-wet-front.png
- electric-mining-drill-W-wet-shadow.png
- electric-mining-drill-W-wet-window-background-front.png
- electric-mining-drill-W-wet.png
- electric-mining-drill-W.png
- electric-mining-drill-horizontal-front.png
- electric-mining-drill-horizontal-shadow.png
- electric-mining-drill-horizontal.png
- electric-mining-drill-shadow.png
- electric-mining-drill-smoke-front.png
- electric-mining-drill-smoke.png
- electric-mining-drill.png

**exotic-space-industries-graphics-1/graphics/other/kirazy-semi-classic-mining-drill/tier_1/remnants/**

- electric-mining-drill-remnants.png

**exotic-space-industries-graphics-1/graphics/other/kirazy-semi-classic-mining-drill/tier_2/**

- electric-mining-drill-E-front.png
- electric-mining-drill-E-integration.png
- electric-mining-drill-E-light.png
- electric-mining-drill-E-output.png
- electric-mining-drill-E-shadow.png
- electric-mining-drill-E-smoke.png
- electric-mining-drill-E-wet-fluid-background-front.png
- electric-mining-drill-E-wet-fluid-flow-front.png
- electric-mining-drill-E-wet-front.png
- electric-mining-drill-E-wet-shadow.png
- electric-mining-drill-E-wet-window-background-front.png
- electric-mining-drill-E-wet.png
- electric-mining-drill-E.png
- electric-mining-drill-N-integration.png
- electric-mining-drill-N-light.png
- electric-mining-drill-N-output.png
- electric-mining-drill-N-shadow.png
- electric-mining-drill-N-smoke.png
- electric-mining-drill-N-wet-fluid-background-front.png
- electric-mining-drill-N-wet-fluid-background.png
- electric-mining-drill-N-wet-fluid-flow-front.png
- electric-mining-drill-N-wet-fluid-flow.png
- electric-mining-drill-N-wet-front.png
- electric-mining-drill-N-wet-shadow.png
- electric-mining-drill-N-wet-window-background-front.png
- electric-mining-drill-N-wet-window-background.png
- electric-mining-drill-N-wet.png
- electric-mining-drill-N.png
- electric-mining-drill-S-front.png
- electric-mining-drill-S-integration.png
- electric-mining-drill-S-light.png
- electric-mining-drill-S-output.png
- electric-mining-drill-S-shadow.png
- electric-mining-drill-S-smoke.png
- electric-mining-drill-S-wet-fluid-background.png
- electric-mining-drill-S-wet-fluid-flow.png
- electric-mining-drill-S-wet-front.png
- electric-mining-drill-S-wet-shadow.png
- electric-mining-drill-S-wet-window-background.png
- electric-mining-drill-S-wet.png
- electric-mining-drill-S.png
- electric-mining-drill-W-front.png
- electric-mining-drill-W-integration.png
- electric-mining-drill-W-light.png
- electric-mining-drill-W-output.png
- electric-mining-drill-W-shadow.png
- electric-mining-drill-W-smoke.png
- electric-mining-drill-W-wet-fluid-background-front.png
- electric-mining-drill-W-wet-fluid-flow-front.png
- electric-mining-drill-W-wet-front.png
- electric-mining-drill-W-wet-shadow.png
- electric-mining-drill-W-wet-window-background-front.png
- electric-mining-drill-W-wet.png
- electric-mining-drill-W.png
- electric-mining-drill-horizontal-front.png
- electric-mining-drill-horizontal-shadow.png
- electric-mining-drill-horizontal.png
- electric-mining-drill-shadow.png
- electric-mining-drill-smoke-front.png
- electric-mining-drill-smoke.png
- electric-mining-drill.png

**exotic-space-industries-graphics-1/graphics/other/kirazy-semi-classic-mining-drill/tier_2/remnants/**

- electric-mining-drill-remnants.png

**exotic-space-industries-graphics-2/graphics/trees/01/**

- tree-01-a-leaves.png
- tree-01-b-leaves.png
- tree-01-c-leaves.png
- tree-01-d-leaves.png
- tree-01-e-leaves.png
- tree-01-f-leaves.png
- tree-01-g-leaves.png
- tree-01-h-leaves.png
- tree-01-i-leaves.png
- tree-01-j-leaves.png
- tree-01-k-leaves.png
- tree-01-l-leaves.png

**exotic-space-industries-graphics-2/graphics/trees/02/**

- tree-02-a-leaves.png
- tree-02-b-leaves.png
- tree-02-c-leaves.png
- tree-02-d-leaves.png
- tree-02-e-leaves.png
- tree-02-f-leaves.png
- tree-02-g-leaves.png
- tree-02-h-leaves.png
- tree-02-i-leaves.png
- tree-02-j-leaves.png
- tree-02-k-leaves.png
- tree-02-l-leaves.png

**exotic-space-industries-graphics-2/graphics/trees/05/**

- tree-05-a-leaves.png
- tree-05-b-leaves.png
- tree-05-c-leaves.png
- tree-05-d-leaves.png
- tree-05-e-leaves.png
- tree-05-f-leaves.png
- tree-05-g-leaves.png
- tree-05-h-leaves.png
- tree-05-i-leaves.png
- tree-05-j-leaves.png
- tree-05-k-leaves.png
- tree-05-l-leaves.png

## 2. Космические направления и спутники (система удалена после перехода на Space Age; фоны, газ и породы переиспользованы в 3.2.0) (27)


**exotic-space-industries-graphics-1/graphics/items/**

- advanced-mining-satellite.png
- black-hole-data.png
- exploration-satellite.png
- gas-giant-data.png
- mining-satellite.png
- moon-fish.png
- sun-data.png
- watch-satellite.png

**exotic-space-industries-graphics-1/graphics/other/**

- rocket-silo.png

**exotic-space-industries-graphics-1/graphics/techs/**

- asteroid-exploration.png
- asteroid-mining.png
- exploration-satellite.png
- galaxy-exploration.png
- gas-giant-exploration.png
- gas-giant-watching.png
- mars-exploration.png
- mars-mining.png
- moon-exploration.png
- moon-mining.png
- planet-exploration.png
- sulf-exploration.png
- sulf-mining.png
- sun-exploration.png
- sun-watching.png
- uran-exploration.png
- uran-mining.png
- watch-satellite.png

## 3. Старая система знаний (удалена; инопланетная консоль снова используется как терминал) (13)


**exotic-space-industries-graphics-1/graphics/other/**

- blue_alien.png
- blueprint.png
- green_alien.png
- greenprint.png
- pinkprint.png
- red_alien.png
- redprint.png
- schematic.png
- yellow_alien.png

**exotic-space-industries-graphics-2/graphics/items/**

- knowledge-science.png
- knowledge-science_2.png
- knowledge-science_3.png
- scanner.png

## 4. Прогресс эпох (система удалена) (3)


**exotic-space-industries-graphics-1/graphics/other/**

- age_progression.png
- lab.png
- tech_overlay.png

## 5. Каменный колодец (мёртвый файл stone_well_pump.lua эпохи 1.1 удалён в 3.2.0) (2)


**exotic-space-industries-graphics-2/graphics/entities/**

- stone-waterwell.png

**exotic-space-industries-graphics-2/graphics/icons/**

- stone-waterwell.png

## 6. Дубликаты графики ЭМ-поездов и заправщика в graphics-2 / временные спрайты (используются версии из graphics-3) (88)


**exotic-space-industries-graphics-2/graphics/**

- 64_empty.png
- 64_red.png
- equipment.png
- fueler_icon.png
- fueler_picture.png
- fueler_tech.png
- radius.png
- vehicle.png

**exotic-space-industries-graphics-2/graphics/entities/**

- charger.png
- charger_animation.png
- em-cargo-wagon_1.png
- em-cargo-wagon_2.png
- em-locomotive-temp_1.png
- em-locomotive-temp_2.png
- em-locomotive_1.png
- em-locomotive_1_shadow.png
- em-locomotive_2.png
- em-locomotive_2_shadow.png
- em-wagon-temp_1.png
- em-wagon-temp_2.png
- em-wagon_1.png
- em-wagon_1_shadow.png
- em-wagon_2.png
- em-wagon_2_shadow.png
- radius.png
- radius_big.png

**exotic-space-industries-graphics-2/graphics/items/**

- charger.png
- charging.png
- dummy.png
- em-cargo-wagon.png
- em-fluid-wagon.png
- em-locomotive.png
- fielder.png

**exotic-space-industries-graphics-2/graphics/techs/**

- acc_1.png
- acc_10.png
- acc_11.png
- acc_12.png
- acc_13.png
- acc_14.png
- acc_15.png
- acc_16.png
- acc_17.png
- acc_18.png
- acc_19.png
- acc_2.png
- acc_20.png
- acc_3.png
- acc_4.png
- acc_5.png
- acc_6.png
- acc_7.png
- acc_8.png
- acc_9.png
- charger.png
- eff_1.png
- eff_2.png
- eff_3.png
- eff_4.png
- eff_5.png
- em-locomotive.png
- spd_1.png
- spd_10.png
- spd_11.png
- spd_12.png
- spd_13.png
- spd_14.png
- spd_15.png
- spd_16.png
- spd_17.png
- spd_18.png
- spd_19.png
- spd_2.png
- spd_20.png
- spd_3.png
- spd_4.png
- spd_5.png
- spd_6.png
- spd_7.png
- spd_8.png
- spd_9.png

**exotic-space-industries-graphics-3/graphics/em-trains/entities/**

- 64x64_empty.png
- em-locomotive-temp_1.png
- em-locomotive-temp_2.png
- em-wagon-temp_1.png
- em-wagon-temp_2.png

**exotic-space-industries-graphics-3/graphics/em-trains/techs/**

- charger.png

**exotic-space-industries-graphics-3/graphics/fueler/**

- 64_empty.png
- 64_red.png

## 7. Kirazy: старый бур (папка unused и неиспользуемый вариант kirazy-mining-drill) (66)


**exotic-space-industries-graphics-1/graphics/other/kirazy-mining-drill/entity/**

- electric-mining-drill-E-drill-shadow.png
- electric-mining-drill-E.png
- electric-mining-drill-N-drill-shadow.png
- electric-mining-drill-N.png
- electric-mining-drill-S-drill-shadow.png
- electric-mining-drill-S.png
- electric-mining-drill-W-drill-shadow.png
- electric-mining-drill-W.png
- hr-electric-mining-drill-E-drill-shadow.png
- hr-electric-mining-drill-E.png
- hr-electric-mining-drill-N-drill-shadow.png
- hr-electric-mining-drill-N.png
- hr-electric-mining-drill-S-drill-shadow.png
- hr-electric-mining-drill-S.png
- hr-electric-mining-drill-W-drill-shadow.png
- hr-electric-mining-drill-W.png

**exotic-space-industries-graphics-1/graphics/other/kirazy-mining-drill/entity/unused/**

- electric-mining-drill-E-drill-received-shadow.png
- electric-mining-drill-E-fluid-background.png
- electric-mining-drill-E-fluid-flow.png
- electric-mining-drill-E-patch-shadow.png
- electric-mining-drill-E-patch.png
- electric-mining-drill-E-window-background.png
- electric-mining-drill-N-drill-received-shadow.png
- electric-mining-drill-N-fluid-background.png
- electric-mining-drill-N-fluid-flow.png
- electric-mining-drill-N-patch-shadow.png
- electric-mining-drill-N-patch.png
- electric-mining-drill-N-window-background.png
- electric-mining-drill-S-drill-received-shadow.png
- electric-mining-drill-S-fluid-background.png
- electric-mining-drill-S-fluid-flow.png
- electric-mining-drill-S-patch-shadow.png
- electric-mining-drill-S-patch.png
- electric-mining-drill-S-window-background.png
- electric-mining-drill-W-drill-received-shadow.png
- electric-mining-drill-W-fluid-background.png
- electric-mining-drill-W-fluid-flow.png
- electric-mining-drill-W-patch-shadow.png
- electric-mining-drill-W-patch.png
- electric-mining-drill-W-window-background.png
- electric-mining-drill-radius-visualization.png
- hr-electric-mining-drill-E-drill-received-shadow.png
- hr-electric-mining-drill-E-fluid-background.png
- hr-electric-mining-drill-E-fluid-flow.png
- hr-electric-mining-drill-E-patch-shadow.png
- hr-electric-mining-drill-E-patch.png
- hr-electric-mining-drill-E-window-background.png
- hr-electric-mining-drill-N-drill-received-shadow.png
- hr-electric-mining-drill-N-fluid-background.png
- hr-electric-mining-drill-N-fluid-flow.png
- hr-electric-mining-drill-N-patch-shadow.png
- hr-electric-mining-drill-N-patch.png
- hr-electric-mining-drill-N-window-background.png
- hr-electric-mining-drill-S-drill-received-shadow.png
- hr-electric-mining-drill-S-fluid-background.png
- hr-electric-mining-drill-S-fluid-flow.png
- hr-electric-mining-drill-S-patch-shadow.png
- hr-electric-mining-drill-S-patch.png
- hr-electric-mining-drill-S-window-background.png
- hr-electric-mining-drill-W-drill-received-shadow.png
- hr-electric-mining-drill-W-fluid-background.png
- hr-electric-mining-drill-W-fluid-flow.png
- hr-electric-mining-drill-W-patch-shadow.png
- hr-electric-mining-drill-W-patch.png
- hr-electric-mining-drill-W-window-background.png

**exotic-space-industries-graphics-1/graphics/other/kirazy-mining-drill/technology/**

- mining-productivity.png

## 8. Тепловые трубы (1)


**exotic-space-industries-graphics-1/graphics/heat-pipes/heated_connections/**

- heated-glow.png

## 9. Маски цвета / превью (не поддерживаются прототипом или не нужны в игре) (6)


**exotic-space-industries/graphics/conduit/**

- conduit-color1.png
- conduit-color2.png

**exotic-space-industries/graphics/cybernetics-facility/**

- cybernetics-facility-hr-color1-1.png
- cybernetics-facility-hr-color2-1.png
- cybernetics-facility-hr-color3-1.png

**exotic-space-industries/graphics/radio-station/**

- radio-station-preview-static.png

## 10. Glow-спрайты неиспользуемых размеров/вариантов (19)


**exotic-space-industries/graphics/glow/big_pngs/**

- glow.png
- glow_3_1%.png
- glow_3_5%.png

**exotic-space-industries/graphics/glow/small_pngs/frame_count_1/**

- glow_1.png
- glow_1_1%.png
- glow_1_25%.png
- glow_1_5%.png

**exotic-space-industries/graphics/glow/small_pngs/frame_count_3/**

- glow_3_1%.png
- glow_3_5.png

**exotic-space-industries/graphics/glow/small_pngs/**

- glow.png

**exotic-space-industries/graphics/glow/tiny_pngs/frame_count_1/**

- glow_1.png
- glow_1_1%.png
- glow_1_25%.png
- glow_1_5%.png

**exotic-space-industries/graphics/glow/tiny_pngs/frame_count_3/**

- glow_3.png
- glow_3_1%.png
- glow_3_25%.png
- glow_3_5%.png

**exotic-space-industries/graphics/glow/tiny_pngs/**

- glow.png

## 11. Тайлы Гайи низкого разрешения (7)


**exotic-space-industries-graphics-2/graphics/terrain/**

- gaia-grass-1.png
- gaia-grass-1_var.png
- gaia-grass-2.png
- gaia-grass-2_var.png
- gaia-rock-1.png
- gaia-rock-2.png
- gaia-rock-3.png

## 12. Прочие ассеты без ссылок в коде (старые предметы, иконки, технологии, трубы) (90)


**exotic-space-industries-graphics-1/graphics/data-pipes/remnants/**

- hr-pipe-remnants.png
- pipe-remnants.png

**exotic-space-industries-graphics-1/graphics/entities/**

- hr-solar-panel-2.png
- hr-solar-panel-3.png
- induction-matrix-core.png
- turret-base.png

**exotic-space-industries-graphics-1/graphics/fluids/**

- elemental-copper.png
- elemental-iron.png
- elemental-sulfur.png
- elemental-uranium.png
- heated-elemental-copper.png
- heated-elemental-iron.png
- heated-elemental-sulfur.png
- heated-elemental-uranium.png
- heated-helium-4.png
- heated-lithium-7.png
- heated-oxygen-16.png
- helium-4.png
- oxygen-16.png

**exotic-space-industries-graphics-1/graphics/heat-covers/**

- hr-heatex-endings-heated.png
- hr-heatex-endings-heated_double.png
- hr-heatex-endings.png
- hr-heatex-endings_double.png

**exotic-space-industries-graphics-1/graphics/inserters/**

- big-inserter_inserter-platform.png
- small-inserter_inserter-platform.png

**exotic-space-industries-graphics-1/graphics/insulated-pipes/remnants/**

- hr-pipe-remnants.png
- pipe-remnants.png

**exotic-space-industries-graphics-1/graphics/items/**

- advanced-base-waver.png
- big-inserter.png
- carbon-fiber.png
- copper-beam.png
- electron-tube.png
- factorio-icon.png
- gold-plate.png
- iron-beam.png
- lead-plate.png
- neodym-plate.png
- poor-copper-chunk.png
- poor-iron-chunk.png
- rocket-parts.png
- sand-1.png
- slag.png
- small-inserter.png
- steel-plate.png
- supercharged-grenade.png

**exotic-space-industries-graphics-1/graphics/other/**

- copper-extraction.png
- gold-extraction.png
- iron-extraction.png
- lead-extraction.png
- metalworks_overlay.png
- neodym-purification.png
- overlay_5.png
- overlay_filter.png
- uran-extraction.png
- uranium-extraction.png
- uranium-purification.png

**exotic-space-industries-graphics-1/graphics/pipe-covers/**

- north_basic_covers.png
- north_long_basic_covers.png

**exotic-space-industries-graphics-1/graphics/techs/**

- dirty-water-production.png
- exotic-assembler.png
- green-circuit-waver.png
- kr-imersite.png
- kr-matter.png
- supercharged-grenade.png

**exotic-space-industries-graphics-2/graphics/entities/**

- accelerator.png
- morphium-patch.png

**exotic-space-industries-graphics-2/graphics/items/**

- condensed-cryodust-1_light.png
- condensed-cryodust-2_light.png
- condensed-cryodust-3_light.png
- condensed-cryodust-4_light.png
- condensed-cryodust-5_light.png
- condensed-cryodust-6_light.png
- enriched-cryodust-2_light.png
- enriched-cryodust-3_light.png
- enriched-cryodust-4_light.png
- enriched-cryodust_light.png
- morphium-patch.png

**exotic-space-industries-graphics-2/graphics/pipe-covers/**

- big_south_covers.png
- east_covers.png
- east_covers_insulated.png
- electricity_south_covers.png
- north_basic_covers.png
- north_long_basic_covers.png
- south_basic_covers_data.png
- south_basic_covers_insulated.png
- south_pumpjack_covers.png
- steam_south_covers.png
- west_covers.png
- west_covers_insulated.png

**exotic-space-industries-graphics-2/graphics/technology/**

- gaia.png

## 13. Упоминаются в коде, но в игру не загружаются (12)

- `exotic-space-industries-graphics-1/graphics/128_empty.png` — ei_lib.empty_sprite(128) — никем не вызывается
- `exotic-space-industries-graphics-1/graphics/256_empty.png` — ei_lib.empty_sprite(256) — вызывали только удалённые dummy-технологии эпох
- `exotic-space-industries-graphics-1/graphics/entities/energy-extractor-pylon.png` — закомментированный блок в black-hole.lua
- `exotic-space-industries-graphics-1/graphics/entities/ground-source.png` — закомментированный ресурс ei-core-patch (drill-deposits.lua)
- `exotic-space-industries-graphics-1/graphics/items/advanced-faulty-waver.png` — закомментированный предмет в computer_prototypes.lua
- `exotic-space-industries-graphics-1/graphics/items/core-patch.png` — закомментированный ресурс ei-core-patch (drill-deposits.lua)
- `exotic-space-industries-graphics-1/graphics/items/exotic-quantum-age-tech.png` — закомментированный код в quantum_prototypes.lua
- `exotic-space-industries-graphics-1/graphics/other/kirazy-mining-drill/icon/electric-mining-drill.png` — закомментированный код в electricity_prototypes.lua
- `exotic-space-industries-graphics-1/graphics/other/power_overlay.png` — закомментированный код в electricity_prototypes.lua
- `exotic-space-industries-graphics-1/graphics/other/processing-unit.png` — закомментированный код в quantum_prototypes.lua
- `exotic-space-industries-graphics-1/graphics/techs/induction-matrix-advanced-solenoid.png` — закомментированная технология в induction-matrix.lua
- `exotic-space-industries-graphics-3/graphics/em-trains/entities/charger.png` — закомментированная анимация в em-trains/charger.lua

## Используются только с Krastorio2-spaced-out (5) — не удалять

- `exotic-space-industries-graphics-1/graphics/items/antimatter-cube.png`
- `exotic-space-industries-graphics-1/graphics/items/imersite-quantum-age-tech.png`
- `exotic-space-industries-graphics-1/graphics/items/matter-quantum-age-tech.png`
- `exotic-space-industries-graphics-1/graphics/other/science.png`
- `exotic-space-industries-graphics-1/graphics/techs/antimatter.png`
