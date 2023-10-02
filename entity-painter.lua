local painter = {}

local RED = {1,0,0}
--local GREEN = {0,1,0}
local YELLOW = {1,1,0}
local WHITE = {1,1,1}

local tick = 0

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
    local entity = node.entity
    local count = 0

    node.inventory = node.inventory and node.inventory.valid and node.inventory or entity.get_inventory(
        node.is_crafter and defines.inventory.assembling_machine_output or
        node.is_furnace and defines.inventory.furnace_result or
        defines.inventory.chest
    )
    local inventory = node.inventory
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

local research
local research_ingredients
local research_unit_energy
local researching_speed
local research_stack_names ={ -- somehow it is 30% faster to use this instead find_item_stack
    ["automation-science-pack"] = 1,
    ["logistic-science-pack"] = 2,
    ["military-science-pack"] = 3,
    ["chemical-science-pack"] = 4,
    ["production-science-pack"] = 5,
    ["utility-science-pack"] = 6,
    ["space-science-pack"] = 7,
}
function painter.PaintLab(node)
    local entity = node.entity
    node.inventory = node.inventory or entity.get_inventory(defines.inventory.lab_input)
    local inventory = node.inventory
    if inventory == nil or research == nil then return end
    local content = inventory.get_contents()
    local count = 9999.9
    for i = 1, #research_ingredients do
        local research_ingredients_name = research_ingredients[i].name
        local content_item = content[research_ingredients_name]
        if content_item then
            local stack = inventory[research_stack_names[research_ingredients_name]]--inventory.find_item_stack(research_ingredients_name)
            if stack then
                local new_count = (content_item - 1 + stack.durability) / research_ingredients[i].amount
                count = new_count < count and new_count or count
            else
                count = 0
                break
            end
        else
            count = 0
            break
        end
    end

    if not researching_speed then researching_speed = entity.prototype.researching_speed end

    local time = count * research_unit_energy / researching_speed
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
    local entity = node.entity

    if not node.crafting_inventory or not node.crafting_inventory_refresh or not (node.crafting_inventory_refresh + 9 > tick) or not node.crafting_inventory.valid then
        node.crafting_inventory = entity.get_inventory(defines.inventory.assembling_machine_input)
        node.crafting_inventory_refresh = node.crafting_inventory and tick or nil
    end
    if not node.recipe or not node.recipe_refresh or not (node.recipe_refresh + 9 > tick) or not node.recipe.valid then
        node.recipe = node.entity.get_recipe()
        node.recipe_refresh = node.recipe and tick or nil
    end
    if node.recipe == nil or node.crafting_inventory == nil then return end
    local recipe = node.recipe
    local inventory = node.crafting_inventory

    local count = 999
    local content = inventory.get_contents()
    for i = 1, #recipe.ingredients do
        local recipe_name = recipe.ingredients[i].name
        if content[recipe_name] then
            count = math.min(count, math.floor(content[recipe_name] / recipe.ingredients[i].amount))
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
    if not node.fuel or not node.fuel.valid then
        node.fuel = node.entity.get_fuel_inventory()
        if node.fuel == nil then return end
    end
    local entity = node.entity
    local fuel = node.fuel

    local fuel_remain = 0

    for stack, count in pairs(fuel.get_contents()) do
        global.fuel_value[stack] = global.fuel_value[stack] or game.item_prototypes[stack].fuel_value
        fuel_remain = fuel_remain + global.fuel_value[stack] * count
    end

    node.energy_usage = node.energy_usage or (entity.prototype.max_energy_usage or entity.prototype.energy_usage)
    local remaining_burning_fuel = entity.burner.remaining_burning_fuel
    remaining_burning_fuel = remaining_burning_fuel + fuel_remain
    remaining_burning_fuel = remaining_burning_fuel / node.energy_usage
    local burner_time_raw = math.floor(remaining_burning_fuel)

    --[[local burner_time_raw = math.floor(
        (entity.burner.remaining_burning_fuel + fuel_remain) / node.energy_usage
    )]]

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
    if node.is_furnace and not global.settings.cycle_furnace or
        node.is_miner and not global.settings.cycle_miner
    then
        return
    end

    if node.is_miner then
        node.mining_speed = node.mining_speed or node.entity.prototype.mining_speed
        local ticks_left = math.ceil(60 * (1-node.entity.mining_progress) * (1/node.mining_speed))

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

    if not node.recipe or not node.recipe_refresh or not (node.recipe_refresh + 15 > tick) or not node.recipe.valid then
        node.recipe = node.entity.get_recipe()
        node.recipe_refresh = node.recipe and tick or nil
    end

    local entity = node.entity

    if node.recipe == nil then
        if node.top_left then
            rendering.destroy(node.top_left.id)
            node.top_left = nil
        end
        return
    end

    local ticks_left = not entity.is_crafting() and 0 or math.ceil(60*(1-entity.crafting_progress)*(node.recipe.energy/entity.crafting_speed))
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
    global.burner_nodes = global.burner_nodes or {}
    global.lab_nodes = global.lab_nodes or {}
    global.craftable_nodes = global.craftable_nodes or {}
    global.cycle_nodes = global.cycle_nodes or {}
    global.output_nodes = global.output_nodes or {}

    tick = game and game.tick or 0

    if global.settings.cycle then
        for index, node in pairs(global.cycle_nodes) do
            if not node.entity or (not node.entity.valid) then
                painter.destroy_node(node)
                global.cycle_nodes[index] = nil
            else
                painter.PaintCycle(node)
            end
        end
    end
    if global.settings.crafting then
        for index, node in pairs(global.craftable_nodes) do
            if not node.entity or (not node.entity.valid) then
                painter.destroy_node(node)
                global.craftable_nodes[index] = nil
            else
                painter.PaintCraftable(node)
            end
        end
    end
    if global.settings.burn then
        global.fuel_value = global.fuel_value or {}
        for index, node in pairs(global.burner_nodes) do
            if not node.entity or (not node.entity.valid) then
                painter.destroy_node(node)
                global.burner_nodes[index] = nil
            else
                painter.PaintBurn(node)
            end
        end
    end
    if global.settings.lab then
        research = game.forces["player"].current_research
        research_ingredients = research and research.research_unit_ingredients or nil
        research_unit_energy = research and research.research_unit_energy or nil
        for index, node in pairs(global.lab_nodes) do
            if not node.entity or (not node.entity.valid) then
                painter.destroy_node(node)
                global.lab_nodes[index] = nil
            else
                painter.PaintLab(node)
            end
        end
    end
    if global.settings.output then
        for index, node in pairs(global.output_nodes) do
            if not node.entity or (not node.entity.valid) then
                painter.destroy_node(node)
                global.output_nodes[index] = nil
            else
                painter.PaintOutput(node)
            end
        end
    end
end

---Clears the paint on each entity on settings toggled
function painter.ClearPaint()
    if not global.settings.cycle or not global.settings.cycle_furnace or not global.settings.cycle_miner then
        for _, node in pairs(global.cycle_nodes) do
            if not global.settings.cycle or
                node.is_furnace and not global.settings.cycle_furnace or
                node.is_miner and not global.settings.cycle_miner
            then
                if node.top_left then rendering.destroy(node.top_left.id) end
                node.top_left = nil
            end
        end
    end
    if not global.settings.crafting then
        for _, node in pairs(global.craftable_nodes) do
            if node.bottom_left then rendering.destroy(node.bottom_left.id) end
            if node.top_right then rendering.destroy(node.top_right.id) end
            node.bottom_left = nil
            node.top_right = nil
        end
    end
    if not global.settings.burn then
        for _, node in pairs(global.burner_nodes) do
            if node.bottom_left then rendering.destroy(node.bottom_left.id) end
            node.bottom_left = nil
        end
    end
    if not global.settings.lab then
        for _, node in pairs(global.lab_nodes) do
            if node.bottom_left then rendering.destroy(node.bottom_left.id) end
            if node.top_right then rendering.destroy(node.top_right.id) end
            node.bottom_left = nil
            node.top_right = nil
        end
    end
    if not global.settings.output then
        for _, node in pairs(global.output_nodes) do
            if node.bottom_right then
                rendering.destroy(node.bottom_right.id)
            end
            node.bottom_right = nil
        end
    end
end

---comment
---@param data EventData.on_built_entity | EventData.on_robot_built_entity | EventData.script_raised_built
local function EntityBuilt(data)
    local entity = data.created_entity or data.entity or nil
    if not entity and entity.type == "entity-ghost" then return end

    local node = {
        entity = entity,
        is_burner = entity.burner ~= nil,
        is_crafter = entity.type == "assembling-machine",
        is_lab = entity.type == "lab",
        is_furnace = entity.type == "furnace",
        is_chest = entity.type == "container",
        is_miner = entity.type == "mining-drill",
    }

    global.burner_nodes = global.burner_nodes or {}
    global.lab_nodes = global.lab_nodes or {}
    global.craftable_nodes = global.craftable_nodes or {}
    global.cycle_nodes = global.cycle_nodes or {}
    global.output_nodes = global.output_nodes or {}

    if node.is_burner then
        global.burner_nodes[entity.unit_number] = node
    end
    if node.is_lab then
        global.lab_nodes[entity.unit_number] = node
    end
    if node.is_crafter then
        global.craftable_nodes[entity.unit_number] = node
    end
    if node.is_crafter or node.is_furnace or node.is_miner then
        global.cycle_nodes[entity.unit_number] = node
    end
    if node.is_crafter or node.is_furnace or node.is_chest then
        global.output_nodes[entity.unit_number] = node
    end
end

---Inits the painter by filtering and adding all entities to the global state
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
