local ei_lib = require("lib/lib")

local style = data.raw["gui-style"]["default"]

style["ei-relative-titlebar-flow"] = {
    type = "horizontal_flow_style",
    horizontal_spacing = 8
}

style["ei-titlebar-draggable-spacer"] = {
    type = "empty_widget_style",
    parent = "draggable_space",
    height = 24,
    horizontally_stretchable = "on",
    left_margin = 4,
    right_margin = 4
  }

style["ei-titlebar-nondraggable-spacer"] = {
    type = "empty_widget_style",
    height = 24,
    horizontally_stretchable="on"
}

style["ei-subheader-frame"] = {
    type = "frame_style",
    parent = "subheader_frame",
    horizontally_stretchable = "on"
}

style["ei-subheader-frame-with-top-border"] = {
    type = "frame_style",
    parent = "subheader_frame",
    graphical_set =
    {
    base =
    { -- add top transition into subheader center
        top = {position = {42, 0}, size = {1, 8}},
        center = {position = {256, 25}, size = {1, 1}},
        bottom = {position = {256, 26}, size = {1, 8}}
    },
    glow =
    { -- transition from content frame
        top = {position = {93, 0}, size = {1, 8}},
        draw_type = "outer"
    },
    shadow = bottom_shadow
    },
    -- to maintain alignment with standard subheader frames
    top_margin = 1,
    -- optical correction - the added shadow increases the perceived height
    -- of the frame
    top_padding = -1,
    height = 35,
    horizontally_stretchable = "on"
}

style["ei-inner-content-flow"] = {
    type = "vertical_flow_style",
    padding = 12
}

style["ei-inner-content-flow-horizontal"] = {
    type = "horizontal_flow_style",
    padding = 12
}

style["ei-status-progressbar"] = {
    type = "progressbar_style",
    bar_width = 28,
    horizontally_stretchable = "on",
    vertical_align = "center",
    font = "default-bold",
    embed_text_in_bar = true,
    font_color = {227, 227, 227},
    filled_font_color = {0, 0, 0}
}
style["ei-status-progressbar-cyan"] = {
    type = "progressbar_style",
    parent = "ei-status-progressbar",
    color = {0, 255, 255}
}
style["ei-status-progressbar-grey"] = {
    type = "progressbar_style",
    parent = "ei-status-progressbar",
    color = {227, 227, 227}
}
style["ei-status-progressbar-purple"] = {
    type = "progressbar_style",
    parent = "ei-status-progressbar",
    color = {184, 33, 184}
}
style["ei-status-progressbar-red"] = {
    type = "progressbar_style",
    parent = "ei-status-progressbar",
    color = {255, 0, 0}
}

style["ei-slot-button-radio"] = {
    type = "button_style",
    parent = "slot_button",
    disabled_graphical_set = style.slot_button.clicked_graphical_set
}

style["ei-vertical-pusher"] = {
    type = "empty_widget_style",
    height = 4
}

style["ei-horizontal-pusher"] = {
    type = "empty_widget_style",
    horizontally_stretchable = "on"
}

style["ei-relative-gui-slider"] = {
    type = "slider_style",
    parent = "notched_slider",
    horizontally_stretchable = "on",
    draw_notches = true
}

style["ei-camera-frame"] = {
    type = "frame_style",
    parent = "deep_frame_in_shallow_frame",
    width = 282
}

style["ei-camera"] = {
    type = "camera_style",
    size = 282
}

style["ei-small-camera-frame"] = {
    type = "frame_style",
    parent = "deep_frame_in_shallow_frame",
    width = 222
}

style["ei-small-camera"] = {
    type = "camera_style",
    size = 222
}

style["ei-green-button"] = {
    type = "button_style",
    parent = "menu_button_continue",
    width = 260,
    height = 36,
    font = "default-bold",
}

style["ei-button"] = {
    type = "button_style",
    parent = "menu_button",
    width = 260,
    height = 36,
    font = "default-bold",
}

style["ei-small-button"] = {
    type = "button_style",
    parent = "button",
    width = 110,
    height = 30,
    font = "default-bold"
}

style["ei-small-red-button"] = {
    type = "button_style",
    parent = "red_button",
    width = 110,
    height = 30,
    font = "default-bold",
}

style["ei-small-green-button"] = {
    type = "button_style",
    parent = "green_button",
    width = 110,
    height = 30,
    font = "default-bold",
}

style["ei-alien-sprite-button-grey"] = {
    type = "button_style",
    -- parent = "slot_button",
    parent = "filter_inventory_slot",
    width = 80,
    height = 80
}

style["ei-alien-sprite-button-red"] = {
    type = "button_style",
    -- parent = "slot_button",
    parent = "closed_inventory_slot",
    width = 80,
    height = 80,
    color = {0, 0.7, 0}
}

style["ei-alien-sprite-button-green"] = {
    type = "button_style",
    --parent = "slot_button",
    parent = "green_slot",
    width = 80,
    height = 80,
    color = {0.05, 0.86, 0}
}

style["ei-inner-content-flow-horizontal-centered"] = {
    type = "horizontal_flow_style",
    padding = 12,
    horizontal_align = "center"
}

style["ei-inner-content-flow-vertical-centered"] = {
    type = "vertical_flow_style",
    padding = 12,
    horizontal_align = "center"
}

if ei_lib.config("expanded-gui") then
  data.raw["utility-constants"]["default"].inventory_width = 10
  data.raw["utility-constants"]["default"].select_slot_row_count = 28
  data.raw["utility-constants"]["default"].select_group_row_count = 17
end
