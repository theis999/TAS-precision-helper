local painter = {}

local RED = {1,0,0}
--local GREEN = {0,1,0}
local YELLOW = {1,1,0}
local WHITE = {1,1,1}

local function set_color(node_corner, new_color)
    if node_corner.color ~= new_color then
        node_corner.color = new_color
        rendering.set_color(node_corner.id, new_color)
    end
end

local function set_text(node_corner, new_text)
    if node_corner.text ~= new_text then
        node_corner.text = new_text
        rendering.set_text(node_corner.id, new_text)
    end
end

function painter.destroy_node(node)
    local function destroy_corner(node_corner)
        if node_corner then
            rendering.destroy(node_corner.id)
        end
    end
    
    destroy_corner(node.top_right)
    destroy_corner(node.top_left)
    destroy_corner(node.bottom_left)
    destroy_corner(node.bottom_right)

    node.top_right = nil
    node.top_left = nil
    node.bottom_left = nil
    node.bottom_right = nil
end

function painter.PaintOutput(node)
    if not (node.is_crafter or node.is_furnace or node.is_chest) then return end

    if not global.settings.output then
        if node.bottom_right then
            rendering.destroy(node.bottom_right.id)
        end
        node.bottom_right = nil
        return
    end

    local entity = node.entity
    local count = 0

    local inventory = entity.get_inventory(
        node.is_crafter and defines.inventory.assembling_machine_output or
        node.is_furnace and defines.inventory.furnace_result or
        defines.inventory.chest
    )
    if inventory and #inventory > 0 then
        for _, stack in pairs(inventory.get_contents()) do
            count = count + stack
        end
    end

    if node.bottom_right then
        set_text(node.bottom_right, count)
    else
        node.bottom_right = {
            text = count,
            color = WHITE,
            id = rendering.draw_text{
                text = count,
                surface = entity.surface,
                target = {x = entity.bounding_box.right_bottom.x - 0.5, y = entity.bounding_box.right_bottom.y - 0.5}, --right bottom
                color = WHITE,
            },
        }
    end
end

function painter.PaintLab(node)
    if not node.is_lab then return end

    if not global.settings.lab then
        if node.bottom_left then rendering.destroy(node.bottom_left.id) end
        if node.top_right then rendering.destroy(node.top_right.id) end
        node.bottom_left = nil
        node.top_right = nil
        return
    end

    local entity = node.entity
    local inventory = entity.get_inventory(defines.inventory.lab_input)
    local research = game.forces["player"].current_research
    if inventory == nil or research == nil then return end
    local ingredients = research.research_unit_ingredients
    local content = inventory.get_contents()
    local count = 999.9
    for i = 1, #ingredients do
        if content[ingredients[i].name] then
            local stack = inventory.find_item_stack(ingredients[i].name)
            if stack then count = math.min(count, (content[ingredients[i].name] -1 + stack.durability) / ingredients[i].amount)
            else
                count = 0
                break
            end
        else
            count = 0
            break
        end
    end

    local time = count * research.research_unit_energy / entity.prototype.researching_speed
    local text = time <= global.settings.lab_yellow_swap and math.floor(time) or math.floor(time/60)
    local color = time > global.settings.lab_yellow_swap and WHITE or time <= global.settings.lab_red_swap and RED or YELLOW

    if not node.bottom_left then
        node.bottom_left = {
            text = text,
            color = color,
            id = rendering.draw_text{
                text = text,
                surface = entity.surface,
                target = {x = entity.bounding_box.left_top.x, y = entity.bounding_box.right_bottom.y -0.5}, --left bottom
                color = color,
            },
        }
    else
        set_text(node.bottom_left, text)
        set_color(node.bottom_left, color)
    end

    local text = string.format("%.2f", count)
    if not node.top_right then
        node.top_right = {
            text = text,
            color = WHITE,
            id = rendering.draw_text{
                text = text,
                surface = entity.surface,
                target = {x = entity.bounding_box.right_bottom.x - 0.85, y = entity.bounding_box.left_top.y}, --right top
                color = WHITE,
            },
        }
    else
        set_text(node.top_right, text)
    end
end

function painter.PaintCraftable(node)
    if not node.is_crafter then return end

    if not global.settings.crafting then
        if node.bottom_left then rendering.destroy(node.bottom_left.id) end
        if node.top_right then rendering.destroy(node.top_right.id) end
        node.bottom_left = nil
        node.top_right = nil
        return
    end

    local entity = node.entity
    local inventory, recipe = entity.get_inventory(defines.inventory.assembling_machine_input), entity.get_recipe()
    if recipe == nil or inventory == nil then return end

    local count = 999
    local content = inventory.get_contents()
    for i = 1, #recipe.ingredients do
        if content[recipe.ingredients[i].name] then
            count = math.min(count, math.floor(content[recipe.ingredients[i].name] / recipe.ingredients[i].amount))
        else
            count = 0
        end
    end

    local time = entity.crafting_progress == 0 and (count * recipe.energy / entity.crafting_speed) or
        ((1-entity.crafting_progress + count) * recipe.energy / entity.crafting_speed)

    local time_60 = time * 60
    local color = time_60 <= global.settings.crafting_red_swap and RED or
        time_60 <= global.settings.crafting_yellow_swap and YELLOW or
        WHITE
    local text = time_60 <= global.settings.crafting_yellow_swap and math.floor(time_60) or math.floor(time)

    if not node.bottom_left then
        node.bottom_left = {
            text = text,
            color = color,
            id = rendering.draw_text{
                text = text,
                surface = entity.surface,
                target = {x = entity.bounding_box.left_top.x, y = entity.bounding_box.right_bottom.y -0.5}, --left bottom
                color = color,
            },
        }
    else
        set_text(node.bottom_left, text)
        set_color(node.bottom_left, color)
    end

    color = RED
    if entity.is_crafting() then
        count = count + 1
        color = WHITE
    end
    if not node.top_right then
        node.top_right = {
            text = count,
            color = color,
            id = rendering.draw_text{
                text = count,
                surface = entity.surface,
                target = {x = entity.bounding_box.right_bottom.x - 0.5, y = entity.bounding_box.left_top.y}, --right top
                color = color,
            },
        }
    else
        set_text(node.top_right, count)
        set_color(node.top_right, color)
    end
end

function painter.PaintBurn(node)
    if not node.is_burner then return end

    if not global.settings.burn then
        if node.bottom_left then rendering.destroy(node.bottom_left.id) end
        node.bottom_left = nil
        return
    end

    local entity = node.entity
    local fuel = entity.get_fuel_inventory()
    if  fuel == nil then return end

    local fuel_remain = 0
    for stack, count in pairs(fuel.get_contents()) do
        local stack_ent = game.item_prototypes[stack]
        fuel_remain = fuel_remain + stack_ent.fuel_value * count
    end

    local burner_time_raw = math.floor(
        (entity.burner.remaining_burning_fuel + fuel_remain) / (entity.prototype.max_energy_usage or entity.prototype.energy_usage)
    )
    local burner_time_sec = burner_time_raw / 60
    local use_tick = burner_time_raw <= global.settings.burn_yellow_swap
    local burner_time = math.floor(use_tick and burner_time_raw or burner_time_sec)
    local color = burner_time_raw <= global.settings.burn_red_swap and RED or
        use_tick and YELLOW or
        WHITE

    if not node.bottom_left then
        node.bottom_left = {
            text = burner_time,
            color = color,
            id = rendering.draw_text{
                text = burner_time,
                surface = entity.surface,
                target = {  x = entity.bounding_box.left_top.x,
                            y = entity.bounding_box.right_bottom.y - 0.5},
                color = color,
            },
        }
        return
    end
    set_text(node.bottom_left, burner_time)
    set_color(node.bottom_left, color)
end

function painter.PaintCycle(node)
    if not node.is_crafter and not node.is_furnace and not node.is_miner then return end

    if not global.settings.cycle or
        node.is_furnace and not global.settings.cycle_furnace or
        node.is_miner and not global.settings.cycle_miner
    then
        if node.top_left then rendering.destroy(node.top_left.id) end
        node.top_left = nil
        return
    end

    if node.is_miner then
        local ticks_left = math.ceil(60 * (1-node.entity.mining_progress) * (1/node.entity.prototype.mining_speed))

        if node.top_left then
            set_text(node.top_left, ticks_left)
        else
            node.top_left = {
                text = ticks_left,
                color = WHITE,
                id = rendering.draw_text{
                    text = ticks_left,
                    surface = node.entity.surface,
                    target = node.entity.bounding_box.left_top,
                    color = WHITE,
                },
            }
        end

        return
    end

    local entity = node.entity
    local rec = entity.get_recipe()

    if rec == nil then
        if node.top_left then
            rendering.destroy(node.top_left.id)
            node.top_left = nil
        end
        return
    end

    local ticks_left = not entity.is_crafting() and 0 or math.ceil(60*(1-entity.crafting_progress)*(rec.energy/entity.crafting_speed))
    --if not entity.is_crafting() then ticks_left = 0 end

    if node.top_left then
        set_text(node.top_left, ticks_left)
    else
        node.top_left = {
            text = ticks_left,
            color = WHITE,
            id = rendering.draw_text{
                text = ticks_left,
                surface = entity.surface,
                target = entity.bounding_box.left_top,
                color = WHITE,
            },
        }
    end
end

function painter.refresh()
    local nodes = global.entity_nodes or {}

    for index, node in pairs(nodes) do
        if not node.entity or (not node.entity.valid) then
            painter.destroy_node(node)
            global.entity_nodes[index] = nil
        else
            painter.PaintCycle(node)
            painter.PaintBurn(node)
            painter.PaintCraftable(node)
            painter.PaintLab(node)
            painter.PaintOutput(node)
        end
    end
end

---comment
---@param data EventData.on_built_entity | EventData.on_robot_built_entity | EventData.script_raised_built
local function EntityBuilt(data)
    local entity = data.created_entity or data.entity
    if entity.type == "entity-ghost" then return end

    local node = {
        entity = entity,
        is_burner = entity.burner ~= nil,
        is_crafter = entity.type == "assembling-machine",
        is_lab = entity.type == "lab",
        is_furnace = entity.type == "furnace",
        is_chest = entity.type == "container",
        is_miner = entity.type == "mining-drill",
    }

    global.entity_nodes = global.entity_nodes or {}
    if node.is_burner or node.is_crafter or node.is_lab or node.is_furnace or node.is_chest or node.is_miner then
        global.entity_nodes[entity.unit_number] = node
    end
end

function painter.init()
    local entities = game.surfaces[1].find_entities_filtered{
        force = game.forces["player"]
    }
    for _,entity in pairs(entities) do
        EntityBuilt({entity = entity})
    end
end

script.on_event(defines.events.script_raised_built, EntityBuilt)
script.on_event(defines.events.on_robot_built_entity, EntityBuilt)
script.on_event(defines.events.on_built_entity, EntityBuilt)

return painter
