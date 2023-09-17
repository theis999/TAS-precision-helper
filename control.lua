require("util")
local painter = require "entity-painter"

local player
local steps = {}
local step_list = {}
local speed = 1
local gui_width = settings.startup["q-gui-width"].value

local settings_prefix = "t-tas-helper_"

local reachable_range_limit = {
    min = -5,
    max = 100,
}
local skip_tick_limit = {
    min = 1,
    max = 1000,
}

local scope = {
    index = 0,
    start = 0,
    stop = 0,
    steps = {},
}

local function update_game_speed()
    if game then speed = game.speed end
end

local function update_speed_boost()
    if not global.settings.speed_boost then return end
    ---@type LuaPlayer
    local p = player or game and game.players and game.players[1]
    if not (p or p.character) then return end
    local _speed = p.character.character_running_speed
    local _position = p.character.position
    local _position_int = {x = math.floor(_position.x), y = math.floor(_position.y)}
    local _walking = p.character.walking_state
    local data = global.speed_boost_data or {position = {x=5, y=7}, speed = 0.15}

    if data.position_int ~= _position_int or data.speed ~= _speed then
        if data.speed_id then
            rendering.destroy(data.speed_id)
            data.speed_id = nil
        end
        data.speed = _speed
        data.position_int = _position_int
        if _speed > 0.15 then
            data.speed_id = rendering.draw_rectangle{
                color = {0.5,1,0.5,0.2},
                filled = true,
                left_top = _position_int,
                right_bottom = {x =  _position_int.x + 1, y = _position_int.y +1},
                surface = p.surface,
                draw_on_ground = true,
                only_in_alt_mode = true,
            }
        end
    end

    ---@type LuaEntity?
    local _entity = global.speed_boost_data and global.speed_boost_data.entity or nil
    local box = _entity and _entity.valid and _entity.bounding_box and {
        left_top = {x = math.floor(_entity.bounding_box.left_top.x), y = math.floor(_entity.bounding_box.left_top.y)},
        right_bottom = {x = math.ceil(_entity.bounding_box.right_bottom.x), y = math.ceil(_entity.bounding_box.right_bottom.y)},
    }
    if _entity and box and
        box.left_top.x <= _position.x and box.left_top.y <= _position.y and
        box.right_bottom.x >= _position.x and box.right_bottom.y >= _position.y
    then --color change
        local _orientation = math.floor(_entity.orientation * 8)
        local a = not _walking.walking or _orientation  == _walking.direction
        if not data.color and a then
            rendering.set_color(data._entity_id, {1,1,1})
            data.color = true
        elseif data.color and not a then
            rendering.set_color(data._entity_id, {1,0,0})
            data.color = false
        end
    elseif data._entity_id then
        rendering.destroy(data._entity_id)
        local entities = p.surface.find_entities_filtered{
            area = {_position_int, {_position_int.x + 1, _position_int.y + 1}},
            type = {"transport-belt", "splitter"},
            limit = 1
        }
        data.entity = entities and entities[1] or nil
        if data.entity then
            local _orientation = math.floor(data.entity.orientation * 8)
            local a = not _walking.walking or _orientation  == _walking.direction
            data._entity_id = rendering.draw_rectangle{
                color = a and {1,1,1} or {1,0,0},
                left_top = data.entity.bounding_box.left_top,
                right_bottom = data.entity.bounding_box.right_bottom,
                surface = data.entity.surface,
                draw_on_ground = false,
                only_in_alt_mode = true,
            }
            data.color = a
        end
    else
        
        local entities = p.surface.find_entities_filtered{
            area = {_position_int, {_position_int.x + 1, _position_int.y + 1}},
            type = {"transport-belt", "splitter"},
            limit = 1
        }
        data.entity = entities and entities[1] or nil
        if data.entity then
            local _orientation = math.floor(data.entity.orientation * 8)
            local a = not _walking.walking or _orientation  == _walking.direction
            data._entity_id = rendering.draw_rectangle{
                color = a and {1,1,1} or {1,0,0},
                left_top = data.entity.bounding_box.left_top,
                right_bottom = data.entity.bounding_box.right_bottom,
                surface = data.entity.surface,
                draw_on_ground = false,
                only_in_alt_mode = true,
            }
            data.color = a
        end
    end

    global.speed_boost_data = data
end

---Draws two circles indication your range
local function draw_reachable_range()
    if not global.player_info[1].refs.settings.circles.state then return end
    global.circles = global.circles or {id = 0, id2 = 0}
    if global.circles.id == 0 then
        global.circles.id = rendering.draw_circle{
            color = {r=0.5,a=0.5},
            width = 2,
            radius = player.reach_distance,
            filled = false,
            target = player.character,
            surface = player.surface,
            draw_on_ground = true
        }
    end

    if global.circles.id2 == 0 then
        global.circles.id2 = rendering.draw_circle{
            color = {r=0.2, g=0.5,a=0.5},
            width = 2,
            radius = player.resource_reach_distance,
            filled = false,
            target = player.character,
            surface = player.surface,
            draw_on_ground = true
        }
    end
end

---draws bounding boxes on entities in range
local function draw_reachable_entities()
    if not global.player_info[1].refs.settings.reachable.state then return end
    local entities = player.surface.find_entities_filtered{
        position = player.position,
        radius = player.reach_distance + global.settings.range,
        force = player.force
    }
    for i in pairs(entities) do
        if entities[i] ~= player.character and player.can_reach_entity(entities[i]) then
            rendering.draw_rectangle{
                color = {r=155, g=155, b=125, a=155},
                width = 1,
                filled = false,
                left_top = entities[i].bounding_box.left_top,
                right_bottom = entities[i].bounding_box.right_bottom,
                surface = player.surface,
                time_to_live = global.settings.skip + 1
            }
        end
    end

    entities = player.surface.find_entities_filtered{
        position = player.position,
        radius = player.resource_reach_distance + global.settings.range,
        force = player.force,
        name = "highlight-box",
        invert = true,
    }
    for i in pairs(entities) do
        if entities[i] ~= player.character and player.can_reach_entity(entities[i]) then
            rendering.draw_rectangle{
                color = {g=1, a=0.5},
                width = 1,
                filled = false,
                left_top = entities[i].bounding_box.left_top,
                right_bottom = entities[i].bounding_box.right_bottom,
                surface = player.surface,
                time_to_live = global.settings.skip + 1,
                draw_on_ground = true
            }
        end
    end
end

---Creates the GUI for a player
---@param player_index uint
local function build_gui(player_index)
    local player = game.players[player_index]
    local screen = player.gui.screen

    global.player_info[player_index] = {
        -- references to gui objects belonging to this player
        refs = {},
    }
    local refs = global.player_info[player_index].refs

    local main_frame = screen.add{ type = "frame", direction = "vertical", }
    main_frame.location = {x = settings.global[settings_prefix.."x"].value, y = settings.global[settings_prefix.."y"].value}
    main_frame.style.width = gui_width
    refs.main_frame = main_frame

    -- add title bar (from raiguard's style guide)
    do
        local title_bar = main_frame.add{ type = "flow", direction = "horizontal", name = "title_bar", }
        title_bar.drag_target = main_frame
        title_bar.add{ type = "sprite", sprite = "t-tas-helper_icon"}
        title_bar.add{ type = "label", style = "frame_title", caption = " TAS precision", ignored_by_interaction = true, }
        title_bar.add{ type = "empty-widget", style = "t_tas_helper_title_bar_draggable_space", ignored_by_interaction = true, }
        refs.toggle_options_button = title_bar.add{ type = "sprite-button", style = "frame_action_button", sprite = "t_tas_helper_settings_icon_white", hovered_sprite = "t_tas_helper_settings_icon_black", clicked_sprite = "t_tas_helper_settings_icon_black", }
        refs.t_main_frame_close_button = title_bar.add{ type = "sprite-button", style = "frame_action_button", sprite = "utility/close_white", hovered_sprite = "utility/close_black", clicked_sprite = "utility/close_black", }
    end

    local main_table = main_frame.add{ type = "table", style = "bordered_table", column_count = 1, }

    local function make_textfield_spec(style, default_text)
        return {
            type = "textfield",
            style = style,
            text = default_text,
            numeric = true,
            allow_decimal = true,
            allow_negative = true,
            lose_focus_on_confirm = true,
        }
    end

    do
        local prefix = settings_prefix
        local function setting(name)
            return settings.global[prefix..name].value
        end

        local function create_setting_flow(settings, name)
            local flow = settings.add{ type = "flow", direction = "horizontal", name = name.."_flow"}
            local checkbox = flow.add{ type = "checkbox", caption = {"gui-caption."..name}, state = setting(name), name = "show_"..name, tooltip = {"gui-tooltip."..name} }
            flow.add{ type = "empty-widget", }.style.horizontally_stretchable = true
            local yellow = flow.add{ type = "textfield", style = "very_short_number_textfield", tooltip = {"gui-tooltip."..name.."-yellow-swap"}, text = setting(name.."-yellow-swap"), numeric = true, allow_negative = false, name = name.."_yellow_swap", }
            local red = flow.add{ type = "textfield", style = "very_short_number_textfield", tooltip = {"gui-tooltip."..name.."-red-swap"}, text = setting(name.."-red-swap"), numeric = true, allow_negative = false, name = name.."_red_swap", }
            return checkbox, yellow, red
        end

        local frame = screen.add{ type = "frame", direction = "vertical", visible = false, }
        global.settings_frame = frame
        --frame.force_auto_center()

        local title_bar = frame.add{ type = "flow", direction = "horizontal", name = "title_bar", }
        title_bar.drag_target = frame
        title_bar.add{ type = "sprite", sprite = "t-tas-helper_icon"}
        title_bar.add{ type = "label", style = "frame_title", caption = "Settings", ignored_by_interaction = true, }
        title_bar.add{ type = "empty-widget", style = "t_tas_helper_title_bar_draggable_space", ignored_by_interaction = true, }
        local close_options_button = title_bar.add{ type = "sprite-button", style = "frame_action_button", sprite = "utility/close_white", hovered_sprite = "utility/close_black", clicked_sprite = "utility/close_black", }
        refs.close_options_button = close_options_button

        local inside_shallow_frame = frame.add{ type = "frame", style = "inside_shallow_frame", direction = "vertical", }
        inside_shallow_frame.style.top_padding = 6
        inside_shallow_frame.style.bottom_padding = 6
        local settings = inside_shallow_frame.add{ type = "frame", style = "bordered_frame_with_extra_side_margins", direction = "vertical", }
        settings.style.horizontally_stretchable = true
        settings.style.minimal_width = 180
        global.elements = {settings = settings}
        settings.add{ type = "label", style = "caption_label", caption = "Show", }
        settings.add{ type = "checkbox", caption = "Reach circles", state = setting("circles"), name = "show_circles" }
        settings.add{ type = "checkbox", caption = "Highlight speed boost", state = setting("speed_boost"), name = "speed_boost", tooltip={"gui-tooltip.highlight-speedboost"}, }

        settings.add{ type = "flow", direction = "horizontal", name = "reachable_range", }
        settings.reachable_range.add{ type = "checkbox", caption = "Highlight reachable", state = setting("reachable"), name = "show_reachable", tooltip = {"gui-tooltip.highlight-reachable"}, }
        settings.reachable_range.add{ type = "empty-widget", }.style.horizontally_stretchable = true
        settings.reachable_range.add{ type = "textfield", style = "very_short_number_textfield", text = setting("reachable-range"), numeric = true, allow_negative = true, name = "textfield", tooltip = {"gui-tooltip.reachable-range"}}
        settings.reachable_range.textfield.style.horizontal_align = "right"

        settings.add{ type = "checkbox", caption = "Output count", state = setting("output"), name = "show_output", tooltip={"gui-tooltip.output"}, }

        local crafting_checkbox, crafting_yellow, crafting_red  = create_setting_flow(settings, "crafting")
        local burn_checkbox, burn_yellow, burn_red = create_setting_flow(settings, "burn")
        local lab_checkbox, lab_yellow, lab_red = create_setting_flow(settings, "lab")

        settings.add{type = "flow", direction = "horizontal", name = "cycle_flow"}
        settings.cycle_flow.add{ type = "checkbox", caption = "Show cycle", state = setting("cycle"), name = "show_cycle", tooltip={"gui-tooltip.cycle"}, }
        settings.cycle_flow.add{ type = "empty-widget", }.style.horizontally_stretchable = true
        settings.cycle_flow.add{ type = "checkbox", caption = "furnaces", state = setting("cycle_furnace"), name = "show_cycle_furnace", tooltip={"gui-tooltip.cycle-furnace"}, }
        settings.cycle_flow.add{ type = "checkbox", caption = "miners", state = setting("cycle_miner"), name = "show_cycle_miner", tooltip={"gui-tooltip.cycle-miner"}, }

        settings.add{ type = "line" }

        settings.add{ type = "flow", direction = "horizontal", name = "skip_tick", }
        settings.skip_tick.add{ type = "label", caption = "Skip tick [img=info]: ", tooltip = "The number of ticks between processing\nLower numbers gives better accuracy\nHigher numbers gives better performance", name = "label" }
        settings.skip_tick.add{ type = "empty-widget", }.style.horizontally_stretchable = true
        settings.skip_tick.add{ type = "textfield", style = "very_short_number_textfield", text = setting("skip-tick"), numeric = true, name = "textfield", }
        settings.skip_tick.textfield.style.horizontal_align = "right"

        --settings.reachable_range.add{ type = "label", caption = "Reachable range [img=info]: ", tooltip = "How far extra to scan for entities, beyound your reach range", name = "label" }

        refs.settings = {
            circles = global.elements.settings.show_circles,
            craft = crafting_checkbox,
            craft_yellow_swap = crafting_yellow,
            craft_red_swap = crafting_red,
            burn = burn_checkbox,
            burn_yellow_swap = burn_yellow,
            burn_red_swap = burn_red,
            lab = lab_checkbox,
            lab_yellow_swap = lab_yellow,
            lab_red_swap = lab_red,
            output = global.elements.settings.show_output,
            cycle = global.elements.settings.cycle_flow.show_cycle,
            cycle_furnace = global.elements.settings.cycle_flow.show_cycle_furnace,
            cycle_miner = global.elements.settings.cycle_flow.show_cycle_miner,
            speed_boost = global.elements.settings.speed_boost,
            skip = global.elements.settings.skip_tick.textfield,

            reachable = global.elements.settings.reachable_range.show_reachable,
            range = global.elements.settings.reachable_range.textfield,
        }
    end

    do --controls
        local flow = main_table.add{ type = "flow", direction = "vertical" }
        refs.btn_controls = flow
        local display_flow = flow.add{ type = "flow", direction = "horizontal" }
        --display_flow.add{ type = "label", style = "caption_label", caption = {"t-tas-helper.tas-controls"}, }
        display_flow.add{ type = "empty-widget", style = "t_tas_helper_horizontal_space", }
        local controls_flow = flow.add{ type = "flow", style = "t_tas_helper_control_flow", direction = "horizontal", }
        refs.btn_controls_controls_flow = controls_flow
        controls_flow.add{ type = "empty-widget", style = "t_tas_helper_horizontal_space", }
        refs.editor_button = controls_flow.add{ type = "sprite-button", style = "slot_sized_button", tooltip = "editor", sprite = "t_tas_controls_editor_icon",}
        refs.release_button = controls_flow.add{ type = "sprite-button", style = "slot_sized_button", tooltip = "release", sprite = "t_tas_controls_release_icon", enabled = false}
        refs.skip_button = controls_flow.add{ type = "sprite-button", style = "slot_sized_button", tooltip = "skip", sprite = "t_tas_controls_skip_icon",}
    end

    do --crafting timer, position & teleport
        local crafting_flow = main_table.add{ type = "flow", direction = "vertical", name = "crafting_flow" }
        crafting_flow.add{ type = "label", style = "caption_label", caption = "Handcrafting time", }
        local crafting_display_flow = crafting_flow.add{ type = "flow", direction = "horizontal", name = "crafting_display_flow" }
        crafting_display_flow.add{ type = "empty-widget", style = "t_tas_helper_horizontal_space", }
        refs.crafting_timer = crafting_display_flow.add{ type = "label", caption = "[0 , 0]", name = "crafting_timer", tooltip = {"gui-tooltip.crafting-timer"} }

        local flow = main_table.add{ type = "flow", direction = "vertical" }
        flow.add{ type = "label", style = "caption_label", caption = "Position", }
        local display_flow_pos = flow.add{ type = "flow", direction = "horizontal" }
        display_flow_pos.add{ type = "empty-widget", style = "t_tas_helper_horizontal_space", }
        refs.current_position = display_flow_pos.add{ type = "label", caption = "[0 , 0]" }
        refs.teleport_flow = flow
        local display_flow = flow.add{ type = "flow", direction = "horizontal" }
        display_flow.add{ type = "label", style = "caption_label", caption = {"t-tas-helper.teleport"}, }
        display_flow.add{ type = "empty-widget", style = "t_tas_helper_horizontal_space", }
        local controls_flow = flow.add{ type = "flow", style = "t_tas_helper_control_flow", direction = "horizontal", }
        refs.teleport_controls_flow = controls_flow
        refs.x_textfield = controls_flow.add(make_textfield_spec("t_tas_helper_number_textfield", player.position.x))
        refs.y_textfield = controls_flow.add(make_textfield_spec("t_tas_helper_number_textfield", player.position.y))

        refs.teleport_button = controls_flow.add{ type = "sprite-button", style = "tool_button", tooltip = {"t-tas-helper.teleport"}, sprite = "t_tas_controls_teleport_icon",}
    end

    do --tasklist
        local flow = main_table.add{ type = "flow", direction = "vertical" }
        local display_flow = flow.add{ type = "flow", direction = "horizontal" }
        display_flow.add{ type = "label", style = "caption_label", caption = {"t-tas-helper.step-list"}, }
        display_flow.add{ type = "empty-widget", style = "t_tas_helper_horizontal_space", }
        refs.tasks = flow.add{type = "list-box", style = "t-tas-helper-tasks", items = scope.steps}
    end
end

---@param player_index uint
local function do_update(player_index)
    local refs = global.player_info[player_index].refs
    local player = game.players[player_index]
    local position = player.position
    refs.current_position.caption = string.format("[ %.2f, %.2f ]", position.x, position.y)

    if player.controller_type == defines.controllers.character then
        if not player.crafting_queue then
            refs.crafting_timer.caption = "0.00 s  /  0 t,  [0]"
            return
        end

        local count = -1
        local time = 0
        for key, value in pairs(player.crafting_queue) do
            local recipe = game.recipe_prototypes[value.recipe]
            time = time + (recipe.energy * value.count)
            count = count + value.count
        end
        local energy = game.recipe_prototypes[player.crafting_queue[1].recipe].energy
        time = time - player.crafting_queue_progress * energy + count / 60
        refs.crafting_timer.caption = string.format("%.2f s  /  %d t,  [%d]", time , math.floor(time * 60), (1-player.crafting_queue_progress) * 60 * energy)
    end
    --player
end

---@param player_index uint?
local function update_gui_internal(player_index)
    if global.player_info == nil then global.player_info = {} end
    if player_index then
        do_update(player_index)
    else
        for player_index_, __ in pairs(global.player_info) do
            do_update(player_index_)
        end
    end
end

local function update_gui_for_all_players()
    if speed < 1.4 then
        update_gui_internal()
    end
end

---@param event EventData.on_lua_shortcut
local function toggle_gui(event)
    local player_index = event.player_index
    local refs = global.player_info[player_index].refs
    local frame = refs.main_frame

    frame.visible = not frame.visible
    frame.bring_to_front()

    if not frame.visible and global.settings_frame.visible then global.settings_frame.visible = false end

    -- toggle shortcut
    local player_ = game.players[player_index]
    player_.set_shortcut_toggled("t-tas-helper-toggle-gui", frame.visible)
end

local function toggle_editor(event)
    local player_index = event.player_index
    local refs = global.player_info[player_index].refs

    -- toggle shortcut
    local player_ = game.players[player_index]
    player_.toggle_map_editor()
    --game.tick_paused = player_.controller_type == defines.controllers.character
    player_.set_shortcut_toggled("t-tas-helper-toggle-editor", player_.controller_type == defines.controllers.editor)
end

---@param event EventData.on_gui_click
local function teleport(event)
    local p = game.players[event.player_index]
    local refs = global.player_info[event.player_index].refs
    local x = refs.x_textfield.text
    local y = refs.y_textfield.text
    p.teleport({x = x, y = y})
end

---@param player_index number
local function destroy_gui(player_index)
    if global
    and global.player_info
    and #global.player_info > 0
    and global.player_info[player_index].refs
    and global.player_info[player_index].refs.main_frame
    then
        global.player_info[player_index].refs.main_frame.destroy()
    end
    if global
    and global.player_info
    and global.player_info[player_index]
    then
        global.player_info[player_index] = nil
    end
end

---@param n number
---@return string
local function amount(n)
    if n == -1 then return "all"
    else return tostring(n) .. "x" end
end

local function duration(n)
    if n == -1 then return "all"
    else return "for "..tostring(n) .. "ticks" end
end

local function position_to_string(position)
    -- round to 2 decimal places
    local x = tonumber(string.format("%.2f", position.x))
    local y = tonumber(string.format("%.2f", position.y))
    return "[font=default-bold][" .. x .. ", " .. y .. "][/font]"
end

---@param str string
---@return string, integer
local function format_name(str)
    return str:gsub("^%l", string.upper):gsub("-", " ")
end

local function format_walk_direction(step)
    local same_x = step[5] or false
    local same_y = step[6] or false

    if same_x ~= same_y then
        return same_x == "same_x" and "↕ " or "↔ "
    elseif same_x and same_y then
        return "↗ "
    else
        return ""
    end
end

---Converts one entry in steps_ into a string for tasklist -> [task-number]: Taskname taskdetail
---@param step table
---@return string|table step_line
local function step_to_string(step)
    if not step then return "" end
    local n = step[2]
    if not n then return "" end
    local description
    if n == "walk" then
        description = {"tas-step.description_walk", position_to_string({x=step[3][1], y=step[3][2]}), format_walk_direction(step)}
    elseif n == "put" or n == "take" then
        description = {"tas-step.description_"..n, amount(step[5]), step[4], position_to_string({x=step[3][1], y=step[3][2]})}
    elseif n == "craft" then
        description = {"tas-step.description_craft", amount(step[3]), step[4]}
    elseif n == "build" then
        return {"tas-step.description_step", step[1][1], {"tas-step.description_build", step[4], position_to_string({x=step[3][1], y=step[3][2]})}}
    elseif n == "mine" then
        description = {"tas-step.description_mine", position_to_string({x=step[3][1], y=step[3][2]}), duration(step[4])}
    elseif n == "recipe" then
        description = {"tas-step.description_recipe", step[4], position_to_string({x=step[3][1], y=step[3][2]})}
    elseif n == "drop" then
        description = {"tas-step.description_drop", step[4], position_to_string({x=step[3][1], y=step[3][2]})}
    elseif n == "filter" then
        description = {"tas-step.description_filter", step[4], position_to_string({x=step[3][1], y=step[3][2]})}
    elseif n == "limit" then
        description = {"tas-step.description_limit", step[4], position_to_string({x=step[3][1], y=step[3][2]})}
    elseif n == "tech" then
        description = {"tas-step.description_research", step[3]}
    elseif n == "priority" then
        description = {"tas-step.description_priority", step[4], step[5], position_to_string({x=step[3][1], y=step[3][2]})}
    elseif n == "pick" then
        description = {"tas-step.description_pickup", tostring(step[3])}
    elseif n == "launch" then
        description = {"tas-step.description_launch", position_to_string({x=step[3][1], y=step[3][2]})}
    elseif n == "cancel crafting" then
        description = {"tas-step.description_cancel_crafting", amount(step[3]), step[4]}
    elseif n == "rotate" then
        description = {"tas-step.description_rotate", step[4] and "tas_helper_rotate_anticlockwise" or "tas_helper_rotate_clockwise", position_to_string({x=step[3][1], y=step[3][2]})}
    elseif n == "speed" then
        description = {"tas-step.description_speed", step[3]*100 }
    elseif n == "save" then
        description = {"tas-step.description_misc", format_name(n), step[3] or ""}
    elseif n == "start" or n == "stop" or n == "pause" or n == "idle" then
        description = {"tas-step.description_misc", n == "speed" and "Game speed" or format_name(n), step[3] and amount(step[3]) or ""}
    elseif n == "shoot" then
        description = {"tas-step.description_shoot", position_to_string({x=step[3][1], y=step[3][2]}), tostring(step[4])}
    elseif n == "throw" then
        local l = string.lower(step[4]):gsub(" ", "-")
        description = {"tas-step.description_throw", position_to_string({x=step[3][1], y=step[3][2]}), l}
    else
        description = {"tas-step.description_misc", format_name(n), ""}
    end
    return {"tas-step.description_step", step[1][1], description}
end

---comment
---@param player_index uint
---@param to_step uint
local function handle_scroll(player_index, to_step)
    local tasks = global.player_info[player_index].refs.tasks
    local scope_changed = false

    while math.abs(to_step - scope.index) > 100 do
        scope_changed = true
        if to_step - scope.index < 0 then scope.index = scope.index - 100
        else scope.index = scope.index + 100 end
    end
    if scope_changed then
        scope = {
            index = scope.index,
            start = math.max(1, scope.index - 100),
            stop = math.min(#steps, scope.index + 200),
            steps = {},
        }
        for i = scope.start, scope.stop do
            scope.steps[i] = steps[i]
        end
        global.player_info[player_index].refs.tasks.items = scope.steps
        tasks = global.player_info[player_index].refs.tasks
    end
    local step = step_list[to_step]
    if step and step[3] and type(step[3]) == "table" and step[3][1] and step[3][2] then
        local x, y = step[3][1], step[3][2]
        if global.current_highlight_box then global.current_highlight_box.destroy{} end
        local highlight_box = game.surfaces[1].create_entity{
            name = "highlight-box",
            position = {0, 0}, -- ignored
            bounding_box = {{x-0.5,y-0.5},{x+0.5,y+0.5}},
        }
        global.current_highlight_box = highlight_box
    end
    tasks.scroll_to_item(to_step - (scope.start - 1), "top-third")
    tasks.selected_index = to_step - (scope.start - 1)
end

local function handle_task_change(data)
    if data and data.step then
        local to_step = math.max(1, math.min(#steps, data.step))
        for player_index, _ in pairs(game.players) do
            ---@cast player_index uint
            handle_scroll(player_index, to_step)
        end
    end
end

local function handle_state_change(data)
    if data then
        for index, player_info in pairs(global.player_info) do
            if player_info.refs and player_info.refs.release_button then
                player_info.refs.release_button.style = data.is_running and "t_tas_helper_selected_slot_sized_button" or "slot_sized_button"
                player_info.refs.release_button.tooltip = data.is_running and "release" or "resume"
            end
        end
    end
end

local function setup_tasklist()
    local interface = remote.interfaces["DunRaider-TAS"]
    if interface then
        --setup task list
        step_list = remote.call("DunRaider-TAS", "get_task_list")
        if not step_list then return end
        for i = 1, #step_list do
            steps[i] = step_to_string(step_list[i])
        end
        scope = {
            index = 0,
            start = 1,
            stop = math.min(#steps, 200),
            steps = {},
        }
        for i = scope.start, scope.stop do
            scope.steps[i] = steps[i]
        end
        for player_info, _ in pairs(global.player_info) do
            local refs = global.player_info[player_info].refs
            refs.tasks.items = scope.steps
            if refs.release_button and refs.skip_button then
                refs.release_button.enabled = interface.release
                refs.skip_button.enabled = interface.skip
            end
            --handle_task_change({step = 1})
        end
        --setup event to fire on step change
        script.on_event(
            remote.call("DunRaider-TAS", "get_tas_step_change_id"),
            handle_task_change
        )
        if interface.get_tas_state_change_id then
            script.on_event(
            remote.call("DunRaider-TAS", "get_tas_state_change_id"),
                handle_state_change
            )
        end
    end
end

script.on_event(defines.events.on_player_toggled_map_editor, function (event)
    if global.player_info and
        global.player_info[event.player_index] and
        global.player_info[event.player_index].refs and
        global.player_info[event.player_index].refs.editor_button
    then
        global.player_info[event.player_index].refs.editor_button.style =
            game.players[event.player_index].controller_type == defines.controllers.editor and "t_tas_helper_selected_slot_sized_button" or "slot_sized_button"
    end
end)

script.on_init(function ()
    -- initialise player_info table
    global.player_info = {}
    global.settings = {
        reach = settings.global[settings_prefix.."circles"].value,
        reachable = settings.global[settings_prefix.."reachable"].value,
        burn = settings.global[settings_prefix.."burn"].value,
        burn_red_swap = settings.global[settings_prefix.."burn-red-swap"].value,
        burn_yellow_swap = settings.global[settings_prefix.."burn-yellow-swap"].value,
        crafting = settings.global[settings_prefix.."crafting"].value,
        crafting_red_swap = settings.global[settings_prefix.."crafting-red-swap"].value,
        crafting_yellow_swap = settings.global[settings_prefix.."crafting-yellow-swap"].value,
        lab = settings.global[settings_prefix.."lab"].value,
        lab_red_swap = settings.global[settings_prefix.."lab-red-swap"].value,
        lab_yellow_swap = settings.global[settings_prefix.."lab-yellow-swap"].value,
        cycle = settings.global[settings_prefix.."cycle"].value,
        cycle_furnace = settings.global[settings_prefix.."cycle_furnace"].value,
        cycle_miner = settings.global[settings_prefix.."cycle_miner"].value,
        output = settings.global[settings_prefix.."output"].value,
        speed_boost = settings.global[settings_prefix.."speed_boost"].value,
        range = settings.global[settings_prefix.."reachable-range"].value,
        skip = settings.global[settings_prefix.."skip-tick"].value,
    }

    -- build gui for all existing players
    for player_index, _ in pairs(game.players) do
        ---@cast player_index uint
        build_gui(player_index)
    end

    --The tas generated mod changes name so we just have to test if it is there
    setup_tasklist()
    painter.init()
end)

script.on_load(function ()
    setup_tasklist()
    local interface = remote.interfaces["DunRaider-TAS"]
    for player_info, _ in pairs(global.player_info) do
        local refs = global.player_info[player_info].refs
        if interface then
            local state = interface.get_tas_state and remote.call("DunRaider-TAS", "get_tas_state") or {is_running = false}
            refs.release_button.enabled = interface.release
            refs.skip_button.enabled = interface.skip
            refs.release_button.style = state.is_running and "t_tas_helper_selected_slot_sized_button" or "slot_sized_button"
        else
            refs.release_button.enabled = false
            refs.skip_button.enabled = false
        end
    end
end)

script.on_event(defines.events.on_player_created, function(event)
    build_gui(event.player_index)

    local interface = remote.interfaces["DunRaider-TAS"]
    if interface then
        for player_info, _ in pairs(global.player_info) do
            local refs = global.player_info[player_info].refs
            refs.tasks.items = scope.steps
            if refs.release_button and refs.skip_button then
                refs.release_button.enabled = interface.release
                refs.skip_button.enabled = interface.skip

                local state = interface.get_tas_state and remote.call("DunRaider-TAS", "get_tas_state") or {is_running = false}
                if state.is_running then
                    refs.release_button.style = "t_tas_helper_selected_slot_sized_button"
                end
            end
        end
    end
end)

script.on_event(defines.events.on_pre_player_removed, function(event)
    pcall(destroy_gui,event.player_index)
end)

local function position_equals(p1, p2)
    local d = 0.0001
    local a1 = p1.x < p2.x + d
    local a2 = p1.x > p2.x - d
    local b1 = p1.y < p2.y + d
    local b2 = p1.y > p2.y - d
    return p1.x < p2.x + d and p1.x > p2.x - d and p1.y < p2.y + d and p1.y > p2.y - d
end

script.on_event(defines.events.on_tick, function(event)
    if not game or game.players == nil or
        event.tick % global.settings.skip ~= 0 or
        speed > 1.4
    then
        return
    end

    update_gui_for_all_players()
    painter.refresh()

    player = game.players[1]
    if player == nil or player.character == nil then return end

    if player.mining_state.mining then
        global.tas_mining = global.tas_mining or {pos = player.mining_state.position}
        local e = player.selected and (player.selected.prototype or game.entity_prototypes[player.selected.prototype_name]).mineable_properties.mining_time or 0
        local t = string.format("%d", math.floor((1 - player.character_mining_progress) * e / player.character.prototype.mining_speed * 60))
        if global.tas_mining.id and not position_equals(global.tas_mining.pos, player.mining_state.position) then
            rendering.destroy(global.tas_mining.id)
            global.tas_mining = nil
        elseif global.tas_mining.id then
            rendering.set_text(global.tas_mining.id, t)
        else
            global.tas_mining.id = rendering.draw_text{
                text = t,
                surface = player.surface,
                target = player.mining_state.position,
                color = {0,1,0},
            }
        end
    end

    update_speed_boost()
    draw_reachable_range()
    draw_reachable_entities() -- <- has it's own entity list 
    local refs = global.player_info[player.index].refs.settings
end)

script.on_event(defines.events.on_player_mined_entity, function(event)
    if global.tas_mining and global.tas_mining.id then
        rendering.destroy(global.tas_mining.id)
        global.tas_mining = nil
    end
end)

script.on_nth_tick(23, update_game_speed)

script.on_event("t-tas-helper-toggle-gui", toggle_gui)
script.on_event("t-tas-helper-toggle-editor", toggle_editor)

script.on_configuration_changed(function (param1)
    --[[local pi = true
    if global and not global.player_info then
        global.player_info = {}
        pi = false
    end

    -- build gui for all existing players
    for player_index, _ in pairs(game.players) do
        ---@cast player_index uint
        if player_index and pi then
            pcall(destroy_gui,player_index) --protected calling
            build_gui(player_index)
        elseif player_index then
            build_gui(player_index)
        end
    end
    setup_tasklist()]]
end)

local function defines_to_string(i, entity_name)
    local defines_inventory = {
        "fuel",
        "input",
        "output",
        "modules",
        "armor",
        "burnt result",
        "vehicle",
        "trash",
        chest = {
            "chest",
        },
        lab = { },
        mining_drill = { },
        beacon = {
            "modules"
        }
    }
    defines_inventory.lab[3] = "modules"
    defines_inventory.mining_drill[2] = "modules"

    if entity_name and defines_inventory[entity_name] and defines_inventory[entity_name][i] then
        return defines_inventory[entity_name][i]
    elseif defines_inventory[i] then
        return defines_inventory[i]
    else
        tostring(i)
    end
end

local direction_strings = {
    "north",
    "northeast",
    "east",
    "southeast",
    "south",
    "southwest",
    "west",
    "northwest"
}
local function direction_to_string(i)
    return direction_strings[i+1] or "north"
end

local step_types = {
    walk = {pos = 3,},
    pick = {dur = 3,},
    put = {pos = 3, item = 4, amount = 5, inv = 6,},
    take = {pos = 3, item = 4, amount = 5, inv = 6,},
    craft = {item = 4, amount = 3,},
    build = {pos = 3, item = 4, dir = 5,},
    mine = {pos = 3, amount = 4,},
    recipe = {pos = 3, item = 4,},
    drop  = {pos = 3, item = 4,},
    filter = {pos = 3, item = 4,},
    limit = {pos = 3, amount = 4,},
    tech = {item = 3,},
    priority = {pos = 3,},
    launch = {pos = 3,},
    rotate = {pos = 3,},
    save = {item = 3},
    start = {},
    stop = {},
    pause = {},
    speed = {amount = 3},
    idle = {dur = 3},
    shoot = {pos = 3, dur = 4,},
    throw = {pos = 3, item = 4,},
    ["cancel crafting"] = {item = 4, amount = 3}
    --break = {},
}

---converts a step into a printable sting
local function step_to_print(step)
    if step[2] then
        local t = step_types[step[2]]
        local var = {
            pos = t.pos and {x = step[t.pos][1], y = step[t.pos][2]},
            item = t.item and step[t.item],
            amount = t.amount and amount(step[t.amount]) or t.dur and step[t.dur],
            dir = t.dir and direction_to_string(step[t.dir]),
            inv = t.inv and defines_to_string(step[t.inv]),
        }
        if var.pos and step[2] ~= "mine" then
            local entities = game.surfaces[1].find_entities_filtered{
                position = var.pos,
                --radius = player.reach_distance + global.settings.range,
                force = player.force,
                limit = 1,
            }
            var.entity = entities and entities[1]
        elseif var.pos then
            local entities = game.surfaces[1].find_entities_filtered{
                position = var.pos,
                --radius = player.reach_distance + global.settings.range,
                --force = {"player", "neutral" },
                name = {"highlight-box", "flare"},
                limit = 1,
                invert = true,
            }
            var.entity = entities and entities[1]
        end
        if t == step_types.save and not game.is_multiplayer() then
            var.item = "_autosave-"..var.item
        elseif t == step_types.priority then
            return {"tas-print-step.priority", var.pos.x, var.pos.y,
                step[4], step[5],
                var.entity and "[entity="..var.entity.name.."]" or "at area"}
        elseif t == step_types.rotate then
            return {"tas-print-step.rotate", var.pos.x, var.pos.y,
                step[4] and "tas_helper_rotate_anticlockwise" or "tas_helper_rotate_clockwise",
                var.entity and "[entity="..var.entity.name.."]" or "at area"}
        end
        return {"tas-print-step."..step[2],
            var.pos and var.pos.x or 0, var.pos and var.pos.y or 0, --1,2
            var.item   or "", --3
            var.amount or "", --4
            var.dir    or "", --5
            var.inv    or "", --6
            var.entity and "[entity="..var.entity.name.."]" or "at area", --7
        }
    else
        return ""
    end

end

---@param event EventData.on_gui_selection_state_changed
local function select_task(event)
    local player_ = game.players[event.player_index]
    local element_ = event.element
    local step = step_list[element_.selected_index + (scope.start - 1)]

    local p = step_to_print(step)
    player_.print({"tas-print-step.description_step", element_.selected_index + (scope.start - 1), p})

    local type = step[2]
    if type == "take" or type == "put" or
        type == "walk" or
        type == "build" or
        type == "drop" or
        type == "limit" or type == "filter" or type == "priority" or type == "launch" or type == "recipe" or
        type == "rotate" or type == "counter-rotate"
    then
        --TODO convert to highlight box
        if player_.character and player_.character.surface then
            player_.character.surface.create_entity{
                name = "flare",
                position = step[3],
                movement = {0,0},
                height = 0,
                vertical_speed = 0,
                frame_speed = 120,
            }
        end
    end
end

script.on_event(defines.events.on_lua_shortcut, function(event)
    if event.prototype_name == "t-tas-helper-toggle-gui" then
        toggle_gui(event)
    elseif event.prototype_name == "t-tas-helper-toggle-editor" then
        toggle_editor(event)
    end
end)

---@param event EventData.on_gui_click
local function toggle_settings(event)
    global.settings_frame.visible = not global.settings_frame.visible

    local player_index = event.player_index
    local refs = global.player_info[player_index].refs
    local settings_window_width = 220

    local location = refs.main_frame.location
    if location.x + math.floor((gui_width + settings_window_width) * player.display_scale) < player.display_resolution.width then
        -- position settings to the right of the helper window
        location.x = location.x + math.floor(gui_width * player.display_scale)
    else
        -- position settings to the left
        location.x = location.x - math.floor(settings_window_width * player.display_scale)
    end
    global.settings_frame.location = location
end

local function editor()
    if player then player.toggle_map_editor() end
    --if player and game then game.tick_paused = player.controller_type == defines.controllers.character end
end
local function toggle_release_resume()
    local interface = remote.interfaces["DunRaider-TAS"]
    local refs = global.player_info and global.player_info[1] and global.player_info[1].refs or nil
    local btn = refs and refs.release_button or nil
    if btn and interface then
        if interface.release and btn.style.name == "t_tas_helper_selected_slot_sized_button" then
            remote.call("DunRaider-TAS", "release")
            if global.current_highlight_box then global.current_highlight_box.destroy{} end
        elseif interface.resume and btn.style.name == "slot_sized_button" then
            remote.call("DunRaider-TAS", "resume")
        end
    end
end
local function skip_c()
    if remote.interfaces["DunRaider-TAS"] and remote.interfaces["DunRaider-TAS"].skip then
        remote.call("DunRaider-TAS", "skip", 1)
    end
end

local has_main_frame_moved = nil
script.on_event(defines.events.on_gui_location_changed, function (event)
    for index, player_index in pairs(global.player_info) do
        if event.element == player_index.refs.main_frame then
            has_main_frame_moved = {x = event.element.location.x, y = event.element.location.y}
        end
    end
end)

script.on_nth_tick(59, function (param1)
    if has_main_frame_moved then
        settings.global[settings_prefix.."x"], settings.global[settings_prefix.."y"] =
            {value = has_main_frame_moved.x}, {value = has_main_frame_moved.y}
        has_main_frame_moved = nil
    end
end)

script.on_event(defines.events.on_gui_selection_state_changed, function(event)
    local player_index = event.player_index
    local refs = global.player_info[player_index].refs
    local handlers = {
        [refs.tasks] = select_task,
    }
    for element, handler in pairs(handlers) do
        if event.element == element then
            handler(event)
        end
    end
end)

---@param event any
---@param skip boolean
local function handle_setting_toggled(event, skip)
    local checkboxes = {
        reachable = global.elements.settings.reachable_range.show_reachable,
        crafting = global.elements.settings.crafting_flow.show_crafting,
        burn = global.elements.settings.burn_flow.show_burn,
        lab = global.elements.settings.lab_flow.show_lab,
        output = global.elements.settings.show_output,
        cycle = global.elements.settings.cycle_flow.show_cycle,
        cycle_furnace = global.elements.settings.cycle_flow.show_cycle_furnace,
        cycle_miner = global.elements.settings.cycle_flow.show_cycle_miner,
        speed_boost = global.elements.settings.speed_boost,
        circles = global.elements.settings.show_circles,
    }
    if checkboxes.circles == event.element then
        local element = checkboxes.circles
        if not skip then settings.global[settings_prefix.."circles"] = {value = element.state} end
        global.settings["circles"] = element.state
        global.circles = global.circles or {id = 0, id2 = 0}
        if global.circles.id ~= 0 then
            rendering.destroy(global.circles.id)
            global.circles.id = 0
        end
        if global.circles.id2 ~= 0 then
            rendering.destroy(global.circles.id2)
            global.circles.id2 = 0
        end
    end
    for name, element in pairs(checkboxes) do
        if element == event.element then
            if not skip then settings.global[settings_prefix..name] = {value = element.state} end
            global.settings[name] = element.state
            break
        end
    end
    painter.ClearPaint()
end

---@param event EventData.on_gui_text_changed
---@param skip boolean
local function handle_setting_changed(event, skip)
    local integerboxes = {
        ["skip-tick"] = global.elements.settings.skip_tick.textfield,
        ["reachable-range"] = global.elements.settings.reachable_range.textfield,
    }
    for name, element in pairs(integerboxes) do
        local value = tonumber(element.text)
        if element == event.element and (
            (name=="skip-tick" and value >= skip_tick_limit.min and value <= skip_tick_limit.max) or
            (name=="reachable-range" and value >= reachable_range_limit.min and value <= reachable_range_limit.max))
        then
            if not skip then settings.global[settings_prefix..name] = {value = element.text} end
            global.settings[name=="skip-tick" and "skip" or name=="reachable-range" and "range"] = value
            break
        end
    end
end

---@param event EventData.on_gui_text_changed
---@param skip boolean
local function handle_painter_setting_changed(event, skip)
    local integerboxes = {
        ["crafting-yellow-swap"] = global.elements.settings.crafting_flow.crafting_yellow_swap,
        ["crafting-red-swap"] = global.elements.settings.crafting_flow.crafting_red_swap,
        ["burn-yellow-swap"] = global.elements.settings.burn_flow.burn_yellow_swap,
        ["burn-red-swap"] = global.elements.settings.burn_flow.burn_red_swap,
        ["lab-yellow-swap"] = global.elements.settings.lab_flow.lab_yellow_swap,
        ["lab-red-swap"] = global.elements.settings.lab_flow.lab_red_swap,
    }
    for name, element in pairs(integerboxes) do
        local value = tonumber(element.text)
        if element == event.element then
            if not skip then settings.global[settings_prefix..name] = {value = element.text} end
            global.settings[element.name] = value
            break
        end

    end
end

script.on_event(defines.events.on_gui_click, function(event)
    local player_index = event.player_index
    local refs = global.player_info[player_index].refs
    local handlers = {
        [refs.tasks] = select_task,
        [refs.t_main_frame_close_button] = toggle_gui,
        [refs.teleport_button] = teleport,
        [refs.editor_button] = editor,
        [refs.release_button] = toggle_release_resume,
        [refs.skip_button] = skip_c,
        [refs.toggle_options_button] = toggle_settings,
        [refs.close_options_button] = toggle_settings,
    }
    for element, handler in pairs(handlers) do
        if event.element == element then
            handler(event)
        end
    end
end)

script.on_event(defines.events.on_gui_checked_state_changed, function (event)
    local player_index = event.player_index
    local refs = global.player_info[player_index].refs
    local handlers = {
        [refs.settings.circles] = handle_setting_toggled,
        [refs.settings.reachable] = handle_setting_toggled,
        [refs.settings.craft] = handle_setting_toggled,
        [refs.settings.burn] = handle_setting_toggled,
        [refs.settings.lab] = handle_setting_toggled,
        [refs.settings.cycle] = handle_setting_toggled,
        [refs.settings.cycle_furnace] = handle_setting_toggled,
        [refs.settings.cycle_miner] = handle_setting_toggled,
        [refs.settings.output] = handle_setting_toggled,
        [refs.settings.speed_boost] = handle_setting_toggled,
    }
    for element, handler in pairs(handlers) do
        if event.element == element then
            handler(event)
        end
    end
end)

script.on_event(defines.events.on_gui_text_changed, function (event)
    if tonumber (event.text ) then
        local player_index = event.player_index
        local refs = global.player_info[player_index].refs
        local handlers = {
            [refs.settings.skip] = handle_setting_changed,
            [refs.settings.range] = handle_setting_changed,
            [refs.settings.craft_yellow_swap] = handle_painter_setting_changed,
            [refs.settings.craft_red_swap] = handle_painter_setting_changed,
            [refs.settings.burn_yellow_swap] = handle_painter_setting_changed,
            [refs.settings.burn_red_swap] = handle_painter_setting_changed,
            [refs.settings.lab_yellow_swap] = handle_painter_setting_changed,
            [refs.settings.lab_red_swap] = handle_painter_setting_changed,
        }
        for element, handler in pairs(handlers) do
            if event.element == element then
                handler(event)
            end
        end
    end
end)

local reload_set = settings.startup["q-reload-settings-on-load"].value
---@param event EventData.on_runtime_mod_setting_changed
local function change_setting(event)
    if not reload_set then return end

    if settings_prefix.."circles" == event.setting then
        global.circles = global.circles or {id = 0, id2 = 0}
        if global.circles.id ~= 0 then
            rendering.destroy(global.circles.id)
            global.circles.id = 0
        end
        if global.circles.id2 ~= 0 then
            rendering.destroy(global.circles.id2)
            global.circles.id2 = 0
        end
    end

    local list = {
        ["circles"] = global.elements.settings.show_circles,
        ["output"] = global.elements.settings.show_output,
        ["burn"] = global.elements.settings.burn_flow.show_burn,
        ["burn-yellow-swap"] = global.elements.settings.burn_flow.burn_yellow_swap,
        ["burn-red-swap"] = global.elements.settings.burn_flow.burn_red_swap,
        ["crafting"] = global.elements.settings.crafting_flow.show_crafting,
        ["crafting-yellow-swap"] = global.elements.settings.crafting_flow.crafting_yellow_swap,
        ["crafting-red-swap"] = global.elements.settings.crafting_flow.crafting_red_swap,
        ["lab"] = global.elements.settings.lab_flow.show_lab,
        ["lab-yellow-swap"] = global.elements.settings.lab_flow.lab_yellow_swap,
        ["lab-red-swap"] = global.elements.settings.lab_flow.lab_red_swap,
        ["cycle"] = global.elements.settings.cycle_flow.show_cycle,
        ["cycle_furnace"] = global.elements.settings.cycle_flow.show_cycle_furnace,
        ["cycle_miner"] = global.elements.settings.cycle_flow.show_cycle_miner,
        ["speed_boost"] = global.elements.settings.speed_boost,
        ["skip-tick"] = global.elements.settings.skip_tick.textfield,
        ["reachable"] = global.elements.settings.reachable_range.show_reachable,
        ["reachable-range"] = global.elements.settings.reachable_range.textfield,
    }

    for name, node in pairs(list) do
        if settings_prefix..name == event.setting then
            if node.type == "textfield" then
                node.text = "" .. settings.global[event.setting].value
                handle_painter_setting_changed({element = node}, true)
                handle_setting_changed({element = node}, true)
            else
                node.state = settings.global[event.setting].value
                handle_setting_toggled({element = node}, true)
            end
        end
    end
end

script.on_event(defines.events.on_runtime_mod_setting_changed , change_setting)
