local styles = data.raw["gui-style"].default

styles["game_speed_title_bar_draggable_space"] = {
    type = "empty_widget_style",
    parent = "draggable_space_header",
    horizontally_stretchable = "on",
    vertically_stretchable = "on",
    height = 24,
    right_margin = 4,
}

styles["game_speed_horizontal_space"] = {
    type = "empty_widget_style",
    horizontally_stretchable = "on",
}

styles["game_speed_control_flow"] = {
    type = "horizontal_flow_style",
    parent = "horizontal_flow",
    vertical_align = "center",
}

styles["game_speed_number_textfield"] = {
    type = "textbox_style",
    parent = "textbox",
    minimal_width = 50,
    horizontal_align = "right",
    horizontally_stretchable = "on",
}

styles["t-tas-helper-tasks"] = {
    type = "list_box_style",
    parent = "list_box",
    maximal_height = 300,
}

data.raw.shortcut["t-tas-helper-toggle-gui"] = {
    type = "shortcut",
    name = "t-tas-helper-toggle-gui",
    toggleable = true,
    action = "lua",
    localised_name = {"t-tas-helper.toggle-gui"},
    associated_control_input = "t-tas-helper-toggle-gui",
    icon = {
        filename = "__core__/graphics/time-editor-icon.png",
        size = 32,
    },
}

data:extend({
    {
        type = "sprite",
        name = "game_speed_settings_icon_black",
        filename = "__game-speed__/graphics/settings-icons.png",
        position = { 0, 0 },
        size = 32,
        flags = { "icon" },
    },
    {
        type = "sprite",
        name = "game_speed_settings_icon_white",
        filename = "__game-speed__/graphics/settings-icons.png",
        position = { 32, 0 },
        size = 32,
        flags = { "icon" },
    },
    {
        type = "sprite",
        name = "game_speed_play_until",
        filename = "__game-speed__/graphics/play-until.png",
        priority = "medium",
        width = 32,
        height = 32,
        mipmap_count = 2,
        flags = {"gui-icon"},
        scale = 0.5,
    },
    {
        type = "sprite",
        name = "game_speed_play_until_disabled",
        filename = "__game-speed__/graphics/play-until-disabled.png",
        priority = "medium",
        width = 32,
        height = 32,
        mipmap_count = 2,
        flags = {"gui-icon"},
        scale = 0.5,
    },
    {
        type = "artillery-flare",
        name = "flare",
        icon = "__base__/graphics/icons/artillery-targeting-remote.png",
        icon_size = 64, icon_mipmaps = 4,
        flags = {"placeable-off-grid", "not-on-map"},
        map_color = {r=1, g=0.5, b=0},
        life_time = 3 * 60,
        initial_height = 0,
        initial_vertical_speed = 0,
        initial_frame_speed = 1,
        shots_per_flare = 0,
        early_death_ticks = 3 * 60,
        pictures =
        {
          {
            filename = "__core__/graphics/shoot-cursor-red.png",
            priority = "low",
            width = 258,
            height = 183,
            frame_count = 1,
            scale = 0.7,
            flags = {"icon"}
          }
        }
      },
})

styles["game_speed_selected_slot_sized_button"] = {
    type = "button_style",
    parent = "button",
    default_graphical_set =
    {
        base = {position = {363, 744}, corner_size = 8},
        shadow = offset_by_2_default_glow(default_dirt_color, 0.5)
    },
    disabled_graphical_set =
    {
        base = {position = {329, 744}, corner_size = 8},
        shadow = offset_by_2_default_glow(default_dirt_color, 0.5)
    },
    hovered_graphical_set =
    {
        base = {position = {346, 744}, corner_size = 8},
        shadow = offset_by_2_default_glow(default_dirt_color, 0.5),
        glow = offset_by_2_default_glow(default_glow_color, 0.5)
    },
    left_click_sound = {{ filename = "__core__/sound/gui-square-button.ogg", volume = 1 }},
    clicked_graphical_set =
    {
        base = {position = {363, 744}, tint = {255, 255, 255, 0}, corner_size = 8},
        shadow = offset_by_2_default_glow(default_dirt_color, 0.5),
    },
    size = 40,
    padding = 0
}

local function add_hotkey(name, key_sequence, alternative_key_sequence, order)
    data:extend({
        {
            type = "custom-input",
            name = name,
            key_sequence = key_sequence,
            alternative_key_sequence = alternative_key_sequence,
            consuming = "game-only",
            order = order,
        }
    })
end

add_hotkey("t-tas-helper-toggle-gui", "CONTROL + P", "", "a")
