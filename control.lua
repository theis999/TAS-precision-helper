require("util")

local id = 0
local id2 = 0
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
    if id == 0 then
        id = rendering.draw_circle{
            color = {r=0.5,a=0.5},
            width = 2,
            radius = player.reach_distance,
            filled = false,
            target = player.character,
            surface = player.surface,
            draw_on_ground = true
        }
    end

    if id2 == 0 then
        id2 = rendering.draw_circle{
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

---Draws crafting time left in ticks, of the current craft, for a furnace or assembler
---@param entity LuaEntity
local function draw_craft(entity)
    if not global.settings.craft then return end
    if entity.prototype.type == "furnace" or entity.type == "assembling-machine" then
        local rec = entity.get_recipe()
        if rec ~= nil then
            local ticks_left = math.ceil(60*(1-entity.crafting_progress)*(rec.energy/entity.crafting_speed))
            if not entity.is_crafting() then ticks_left = 0 end
            rendering.draw_text{
                text = ticks_left,
                surface = entity.surface,
                target = entity.bounding_box.left_top,
                color = {1,1,1,1},
                time_to_live = global.settings.skip + 1
            }
        end
    end
end

---Draws fuel remaining in seconds on a burner entity (furnace, boiler, burner inserter etc.)
---@param entity LuaEntity
local function draw_burn(entity)
    if not global.settings.burn then return end
    local fuel
    local fuel_remain = 0
    if  entity.burner == nil then return end
    fuel = entity.get_fuel_inventory()
    if  fuel == nil then return end

    local inv = fuel.get_contents()
    for stack, count in pairs(inv) do
        local stack_ent = game.item_prototypes[stack]
        fuel_remain = fuel_remain + stack_ent.fuel_value * count
    end

    local burner_time
    if entity.prototype.energy_usage == nil then
        burner_time = math.floor((entity.burner.remaining_burning_fuel + fuel_remain) / entity.prototype.max_energy_usage / 60)
    else
        burner_time = math.floor((entity.burner.remaining_burning_fuel + fuel_remain) / entity.prototype.energy_usage / 60)
    end

    rendering.draw_text{
        text = burner_time .. "s",
        surface = entity.surface,
        target = {entity.bounding_box.left_top.x, entity.bounding_box.right_bottom.y - 0.5},
        color = {1,1,1,1},
        time_to_live = global.settings.skip + 1
    }
end

---Draws the time an assembler will craft with the current input and the number of craftable items an assembler will produce before it runs out of resources
---@param entity LuaEntity
local function draw_craftable(entity)
    if not global.settings.craftable then return end
    local inv = entity.get_inventory(defines.inventory.assembling_machine_input)
    if inv == nil or entity.type ~= "assembling-machine" then return end
    local rec = entity.get_recipe()
    if rec == nil then return end
    local count = 999
    local content = inv.get_contents()
    for i = 1, #rec.ingredients do
        if content[rec.ingredients[i].name] then
            count = math.min(count, math.floor(content[rec.ingredients[i].name] / rec.ingredients[i].amount))
        else
            count = 0
        end
    end

    local time
    if entity.crafting_progress == 0 then
        time = count * rec.energy / entity.crafting_speed
    else
        time = (1-entity.crafting_progress + count) * rec.energy / entity.crafting_speed
    end
    local text
    if time < 1 then text = math.floor(time*60) .. "t" else text = math.floor(time) .. "s" end --if less than 1 second

    rendering.draw_text{
        text = text,
        surface = entity.surface,
        target = {entity.bounding_box.left_top.x, entity.bounding_box.right_bottom.y -0.5}, --left bottom
        color = {1,1,1,1},
        time_to_live = global.settings.skip + 1
    }

    local color = {1,0,0,1} --red
    if entity.is_crafting() then
        count = count + 1
        color = {1,1,1,1} --shift color to white if crafting
    end

    rendering.draw_text{
        text = count,
        surface = entity.surface,
        target = {entity.bounding_box.right_bottom.x - 0.5, entity.bounding_box.left_top.y}, --right top
        color = color,
        time_to_live = global.settings.skip + 1
    }
end

---Draws the time left an lab can work and the number of cycles it has left
---@param entity LuaEntity
local function draw_lab(entity)
    if not global.settings.craftable then return end
    local inv = entity.get_inventory(defines.inventory.lab_input)
    local research = player.force.current_research
    if inv == nil or research == nil or entity.type ~= "lab" then return end
    local ing = research.research_unit_ingredients
    local content = inv.get_contents()
    local count = 999.9
    for i = 1, #ing do
        if content[ing[i].name] then
            local stack = inv.find_item_stack(ing[i].name)
            if stack then count = math.min(count, (content[ing[i].name] -1 + stack.durability) / ing[i].amount)
            else count = 0 end
        else
            count = 0
        end
    end

    local time = count * research.research_unit_energy / entity.prototype.researching_speed
    local text
    if time < 61 then text = math.floor(time) .. "t" else text = math.floor(time/60) .. "s" end

    rendering.draw_text{
        text = text,
        surface = entity.surface,
        target = {entity.bounding_box.left_top.x, entity.bounding_box.right_bottom.y -0.5}, --left bottom
        color = {1,1,0,1},
        time_to_live = global.settings.skip + 1
    }

    rendering.draw_text{
        text = string.format("%.2f",count),
        surface = entity.surface,
        target = {entity.bounding_box.right_bottom.x - 0.85, entity.bounding_box.left_top.y}, --right top
        color = {1,1,1,1},
        time_to_live = global.settings.skip + 1
    }
end

---Draws the number of items ready for pick up
---@param entity LuaEntity
local function draw_output(entity)
    if not global.settings.output then return end
    local count = -1
    local t = entity.type
    if t == "assembling-machine" then
        local inv = entity.get_inventory(defines.inventory.assembling_machine_output)
        if inv and #inv > 0 then
            count = inv[1].count--just take the first stack, whatever
        end
    elseif t == "furnace" then
        local inv = entity.get_inventory(defines.inventory.furnace_result)
        if inv and #inv > 0 then count = inv[1].count else count = 0 end --just take the first stack, whatever
    elseif t == "container" then
        local contents = entity.get_inventory(defines.inventory.chest).get_contents()
        count = 0
        for k,v in pairs(contents) do
            count = count + v
        end
    end --unhandled defines.inventory.rocket_silo_output

    if count > 0 then
        rendering.draw_text{
            text = count,
            surface = entity.surface,
            target = {entity.bounding_box.right_bottom.x - 0.5, entity.bounding_box.right_bottom.y - 0.5}, --right bottom
            color = {1,1,1,1},
            time_to_live = global.settings.skip + 1
        }
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
        title_bar.add{ type = "sprite", sprite = "tas_helper_icon"}
        title_bar.add{ type = "label", style = "frame_title", caption = " Helper", ignored_by_interaction = true, }
        title_bar.add{ type = "empty-widget", style = "game_speed_title_bar_draggable_space", ignored_by_interaction = true, }
        refs.toggle_options_button = title_bar.add{ type = "sprite-button", style = "frame_action_button", sprite = "game_speed_settings_icon_white", hovered_sprite = "game_speed_settings_icon_black", clicked_sprite = "game_speed_settings_icon_black", }
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

        local frame = screen.add{ type = "frame", direction = "vertical", visible = false, }
        global.settings_frame = frame
        --frame.force_auto_center()

        local title_bar = frame.add{ type = "flow", direction = "horizontal", name = "title_bar", }
        title_bar.drag_target = frame
        title_bar.add{ type = "sprite", sprite = "tas_helper_icon"}
        title_bar.add{ type = "label", style = "frame_title", caption = "Settings", ignored_by_interaction = true, }
        title_bar.add{ type = "empty-widget", style = "tas_helper_title_bar_draggable_space", ignored_by_interaction = true, }
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
        settings.add{ type = "checkbox", caption = "Highlight reachable", state = setting("reachable"), name = "show_reachable" }
        settings.add{ type = "checkbox", caption = "Crafting timer", state = setting("craft"), name = "show_craft" }
        settings.add{ type = "checkbox", caption = "Burn timer", state = setting("burn"), name = "show_burn" }
        settings.add{ type = "checkbox", caption = "Craftable count", state = setting("craftable"), name = "show_craftable" }
        settings.add{ type = "checkbox", caption = "Output count", state = setting("output"), name = "show_output" }
        settings.add{ type = "checkbox", caption = "Highlight speed boost", state = setting("speed_boost"), name = "speed_boost" }

        settings.add{ type = "line" }

        settings.add{ type = "flow", direction = "horizontal", name = "skip_tick", }
        settings.skip_tick.add{ type = "label", caption = "Skip tick [img=info]: ", tooltip = "something about ticks", name = "label" }
        settings.skip_tick.add{ type = "empty-widget", }.style.horizontally_stretchable = true
        settings.skip_tick.add{ type = "textfield", style = "very_short_number_textfield", text = setting("skip-tick"), numeric = true, name = "textfield", }
        settings.skip_tick.textfield.style.horizontal_align = "right"

        settings.add{ type = "flow", direction = "horizontal", name = "reachable_range", }
        settings.reachable_range.add{ type = "label", caption = "Reachable range [img=info]: ", tooltip = "something about reach", name = "label" }
        settings.reachable_range.add{ type = "empty-widget", }.style.horizontally_stretchable = true
        settings.reachable_range.add{ type = "textfield", style = "very_short_number_textfield", text = setting("reachable-range"), numeric = true, allow_negative = true, name = "textfield", }
        settings.reachable_range.textfield.style.horizontal_align = "right"

        refs.settings = {
            circles = global.elements.settings.show_circles,
            reachable = global.elements.settings.show_reachable,
            craft = global.elements.settings.show_craft,
            burn = global.elements.settings.show_burn,
            craftable = global.elements.settings.show_craftable,
            output = global.elements.settings.show_output,
            speed_boost = global.elements.settings.speed_boost,
            skip = global.elements.settings.skip_tick.textfield,
            range = global.elements.settings.reachable_range.textfield,
        }
    end

    do --controls
        local flow = main_table.add{ type = "flow", direction = "vertical" }
        refs.btn_controls = flow
        local display_flow = flow.add{ type = "flow", direction = "horizontal" }
        --display_flow.add{ type = "label", style = "caption_label", caption = {"t-tas-helper.tas-controls"}, }
        display_flow.add{ type = "empty-widget", style = "game_speed_horizontal_space", }
        local controls_flow = flow.add{ type = "flow", style = "game_speed_control_flow", direction = "horizontal", }
        refs.btn_controls_controls_flow = controls_flow
        controls_flow.add{ type = "empty-widget", style = "game_speed_horizontal_space", }
        refs.editor_button = controls_flow.add{ type = "sprite-button", style = "slot_sized_button", tooltip = "editor", sprite = "t_tas_controls_editor_icon",}
        refs.release_button = controls_flow.add{ type = "sprite-button", style = "slot_sized_button", tooltip = "release", sprite = "t_tas_controls_release_icon", enabled = false}
        refs.skip_button = controls_flow.add{ type = "sprite-button", style = "slot_sized_button", tooltip = "skip", sprite = "t_tas_controls_skip_icon",}
    end

    do --position & teleport 
        local flow = main_table.add{ type = "flow", direction = "vertical" }
        flow.add{ type = "label", style = "caption_label", caption = "Position", }
        local display_flow_pos = flow.add{ type = "flow", direction = "horizontal" }
        display_flow_pos.add{ type = "empty-widget", style = "game_speed_horizontal_space", }
        refs.current_position = display_flow_pos.add{ type = "label", caption = "[0 , 0]" }
        refs.teleport_flow = flow
        local display_flow = flow.add{ type = "flow", direction = "horizontal" }
        display_flow.add{ type = "label", style = "caption_label", caption = {"t-tas-helper.teleport"}, }
        display_flow.add{ type = "empty-widget", style = "game_speed_horizontal_space", }
        local controls_flow = flow.add{ type = "flow", style = "game_speed_control_flow", direction = "horizontal", }
        refs.teleport_controls_flow = controls_flow
        refs.x_textfield = controls_flow.add(make_textfield_spec("t_tas_helper_number_textfield", player.position.x))
        refs.y_textfield = controls_flow.add(make_textfield_spec("t_tas_helper_number_textfield", player.position.y))

        refs.teleport_button = controls_flow.add{ type = "sprite-button", style = "tool_button", tooltip = {"t-tas-helper.teleport"}, sprite = "t_tas_controls_teleport_icon",}
    end

    do --tasklist
        local flow = main_table.add{ type = "flow", direction = "vertical" }
        local display_flow = flow.add{ type = "flow", direction = "horizontal" }
        display_flow.add{ type = "label", style = "caption_label", caption = {"t-tas-helper.step-list"}, }
        display_flow.add{ type = "empty-widget", style = "game_speed_horizontal_space", }
        refs.tasks = flow.add{type = "list-box", style = "t-tas-helper-tasks", items = scope.steps}
    end
end

---@param player_index uint
local function do_update(player_index)
    local refs = global.player_info[player_index].refs
    local p = game.players[player_index].position
    refs.current_position.caption = string.format("[ %.2f, %.2f ]", p.x, p.y)
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
    player_.set_shortcut_toggled("t-tas-helper-toggle-editor", player_.controller_type == defines.controllers.editor)
end

---@param event EventData.on_gui_click
local function teleport(event)
    local p = game.players[event.player_index]
    local refs = global.player_info[event.player_index].refs
    local x = refs.x_textfield.text
    local y = refs.y_textfield.text
    p.teleport({x, y})
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
    else return tostring(n) end
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

---Converts one entry in steps_ into a string for tasklist -> [task-number]: Taskname taskdetail
---@param step table
---@return string|table step_line
local function step_to_string(step)
    if not step then return "" end
    local n = step[2]
    if not n then return "" end
    local description
    if n == "walk" then
        description = {"tas-step.description_walk", position_to_string({x=step[3][1], y=step[3][2]})}
    elseif n == "put" or n == "take" then
        description = {"tas-step.description_"..n, amount(step[5]), step[4], position_to_string({x=step[3][1], y=step[3][2]})}
    elseif n == "craft" then
        description = {"tas-step.description_craft", amount(step[3]), step[4]}
    elseif n == "build" then
        return {"tas-step.description_step", step[1][1], {"tas-step.description_build", step[4], position_to_string({x=step[3][1], y=step[3][2]})}}
    elseif n == "mine" then
        description = {"tas-step.description_mine", position_to_string({x=step[3][1], y=step[3][2]})}
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
        description = {"tas-step.description_pickup", amount(step[3])}
    elseif n == "launch" then
        description = {"tas-step.description_launch", position_to_string({x=step[3][1], y=step[3][2]})}
    elseif n == "cancel crafting" then
        description = {"tas-step.description_cancel_crafting", amount(step[3]), step[4]}
    elseif n == "rotate" then
        description = {"tas-step.description_rotate", step[4] and "tas_helper_rotate_anticlockwise" or "tas_helper_rotate_clockwise", position_to_string({x=step[3][1], y=step[3][2]})}
    elseif n == "speed" then
        description = {"tas-step.description_speed", step[3]*100 }
    elseif n == "save" or n == "start" or n == "stop" or n == "pause" or n == "idle" then
        description = {"tas-step.description_misc", n == "speed" and "Game speed" or format_name(n), step[3] and amount(step[3]) or ""}
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
                player_info.refs.release_button.style = data.is_running and "game_speed_selected_slot_sized_button" or "slot_sized_button"
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
        script.on_event(
            remote.call("DunRaider-TAS", "get_tas_state_change_id"),
            handle_state_change
        )
    end
end

local function change_setting(setting)
    if true then return end
    if (setting == "tas-reach") then
        reach = settings.global["tas-reach"].value
        if id ~= 0 then
            rendering.destroy(id)
            id = 0
        end
        if id2 ~= 0 then
            rendering.destroy(id2)
            id2 = 0
        end
    end
    if (setting == "tas-reachable") then
        reachable = settings.global["tas-reachable"].value
    end
    if (setting == "tas-burn") then
        burn = settings.global["tas-burn"].value
    end
    if (setting == "tas-craft") then
        craft = settings.global["tas-craft"].value
    end
    if (setting == "tas-craftable") then
        craftable = settings.global["tas-craftable"].value
    end
    if (setting == "tas-output") then
        output = settings.global["tas-output"].value
    end
    if (setting == "tas-speed_boost") then
        speed_boost = settings.global["tas-speed_boost"].value
    end
    if (setting == "tas-reachable-range") then
        reachable_range = settings.global["tas-reachable-range"].value
    end
end

script.on_event(defines.events.on_player_toggled_map_editor, function (event)
    if global.player_info and
        global.player_info[event.player_index] and
        global.player_info[event.player_index].refs and
        global.player_info[event.player_index].refs.editor_button
    then
        global.player_info[event.player_index].refs.editor_button.style =
            game.players[event.player_index].controller_type == defines.controllers.editor and "game_speed_selected_slot_sized_button" or "slot_sized_button"
    end
end)

script.on_init(function ()
    -- initialise player_info table
    global.player_info = {}
    global.settings = {
        reach = settings.global[settings_prefix.."circles"].value,
        reachable = settings.global[settings_prefix.."reachable"].value,
        burn = settings.global[settings_prefix.."burn"].value,
        craft = settings.global[settings_prefix.."craft"].value,
        craftable = settings.global[settings_prefix.."craftable"].value,
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
            refs.release_button.style = state.is_running and "game_speed_selected_slot_sized_button" or "slot_sized_button"
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

                local state = remote.call("DunRaider-TAS", "get_tas_state")
                if state.is_running then
                    refs.release_button.style = "game_speed_selected_slot_sized_button"
                end
            end
        end
    end
end)

script.on_event(defines.events.on_pre_player_removed, function(event)
    pcall(destroy_gui,event.player_index)
end)

script.on_event(defines.events.on_tick, function(event)
    if not game or game.players == nil or
        event.tick % global.settings.skip ~= 0 or
        speed > 1.4
    then
        return
    end

    player = game.players[1]
    if player == nil or player.character == nil then return end

    update_speed_boost()
    draw_reachable_range()
    draw_reachable_entities() -- <- has it's own entity list 
    local refs = global.player_info[player.index].refs.settings
    if not (global.settings.burn or global.settings.craft or global.settings.craftable or global.settings.output) then return end
    local entities = player.surface.find_entities_filtered{
        position = player.position,
        radius = player.reach_distance + global.settings.range,
        force = player.force
    }

    for i in pairs(entities) do
        local entity = entities[i]
        if entity ~= nil then
            draw_burn(entity)
            draw_craft(entity)
            draw_craftable(entity)
            draw_output(entity)
            draw_lab(entity)
        end
    end
end)

script.on_nth_tick(11, update_gui_for_all_players)
script.on_nth_tick(23, update_game_speed)

script.on_event(defines.events.on_runtime_mod_setting_changed , function(event)
    local setting = event.setting
    change_setting(setting)
end)

script.on_event("t-tas-helper-toggle-gui", toggle_gui)
script.on_event("t-tas-helper-toggle-editor", toggle_editor)

script.on_configuration_changed(function (param1)
    local pi = true
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
    setup_tasklist()
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
end
local function toggle_release_resume()
    local interface = remote.interfaces["DunRaider-TAS"]
    local refs = global.player_info and global.player_info[1] and global.player_info[1].refs or nil
    local btn = refs and refs.release_button or nil
    if btn and interface then
        if interface.release and btn.style.name == "game_speed_selected_slot_sized_button" then
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

local function handle_setting_toggled(event)
    local checkboxes = {
        reachable = global.elements.settings.show_reachable,
        craft = global.elements.settings.show_craft,
        burn = global.elements.settings.show_burn,
        craftable = global.elements.settings.show_craftable,
        output = global.elements.settings.show_output,
        speed_boost = global.elements.settings.speed_boost,
        circles = global.elements.settings.show_circles,
    }
    if checkboxes.circles == event.element then
        local element = checkboxes.circles
        settings.global[settings_prefix.."circles"] = {value = element.state}
        global.settings["circles"] = element.state
        if id ~= 0 then
            rendering.destroy(id)
            id = 0
        end
        if id2 ~= 0 then
            rendering.destroy(id2)
            id2 = 0
        end
    end
    for name, element in pairs(checkboxes) do
        if element == event.element then
            settings.global[settings_prefix..name] = {value = element.state}
            global.settings[name] = element.state
            break
        end
    end
end

local function handle_setting_changed(event)
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
            settings.global[settings_prefix..name] = {value = element.text}
            global.settings[name=="skip-tick" and "skip" or name=="reachable-range" and "range"] = value
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
        [refs.settings.craftable] = handle_setting_toggled,
        [refs.settings.burn] = handle_setting_toggled,
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
        }
        for element, handler in pairs(handlers) do
            if event.element == element then
                handler(event)
            end
        end
    end
end)
