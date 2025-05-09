local width, height = 1280, 720
local scale = 4
local grid = {}
local current_type = "sand"
local ui_open = true
local selected_category = "solids"
local ui_slide = 0  -- 0 to 1 for sliding animation
local ui_target = 0 -- Target slide position
local UI_WIDTH = 300
local TAB_HEIGHT = 40
local ELEMENT_SIZE = 30
local ELEMENTS_PER_ROW = 2
local PADDING = 10
local paint_timer = 0
local tab_was_down = false
local clear_confirmation = false
local clear_timer = 0

-- Constants
local ROOM_TEMP = 20
local MAX_TEMP = 1000
local MIN_TEMP = -100
local TEMP_DIFFUSION = 0.1
local TEMP_DECAY = 0.99
local VELOCITY_DECAY = 0.95
local PRESSURE_DIFFUSION = 0.1
local GRAVITY = 0.5
local MAX_VELOCITY = 5
local LAVA_GLOW = 0.3  -- Intensity of lava glow

local elements = {
    solids = { "sand", "stone", "wood", "metal", "ice", "brick", "ash", "glass", "dirt" },
    liquids = { "water", "acid", "oil", "lava", "blood" },
    gases = { "steam", "smoke", "poison", "helium" },
    explosives = { "tnt", "thermite", "firework" },
    special = { "fire" }
}
local categories = { "solids", "liquids", "gases", "explosives", "special" }

local elementProps = {
    sand = {type="powder", color={0.76, 0.7, 0.5}, temp=ROOM_TEMP, conductivity=0.3, specific_heat=0.8, density=1.5, friction=0.8},
    ash = {type="powder", color={0.5, 0.5, 0.5}, temp=ROOM_TEMP, conductivity=0.1, specific_heat=0.5, density=0.3, friction=0.6},
    dirt = {type="powder", color={0.45, 0.3, 0.15}, temp=ROOM_TEMP, conductivity=0.2, specific_heat=0.7, density=1.2, friction=0.7},
    glass = {type="powder", color={0.9, 1, 1}, temp=ROOM_TEMP, conductivity=0.05, specific_heat=0.6, melts_at=1500, density=2.5, friction=0.9},
    wood = {type="solid", color={0.4, 0.25, 0.1}, temp=ROOM_TEMP, conductivity=0.1, specific_heat=0.6, flammable=true, ignition_temp=300, density=0.8, friction=0.7},
    metal = {type="solid", color={0.7, 0.7, 0.75}, temp=ROOM_TEMP, conductivity=0.9, specific_heat=0.4, melts_at=1500, density=7.8, friction=0.6, conducts_electricity=true},
    brick = {type="solid", color={0.7, 0.2, 0.2}, temp=ROOM_TEMP, conductivity=0.3, specific_heat=0.8, density=1.8, friction=0.8},
    ice = {type="solid", color={0.6, 0.9, 1}, temp=0, conductivity=0.2, specific_heat=0.5, melts=true, melts_at=0, density=0.9, friction=0.3},
    stone = {type="solid", color={0.4, 0.4, 0.4}, temp=ROOM_TEMP, conductivity=0.4, specific_heat=0.7, density=2.7, friction=0.9},
    water = {type="liquid", color={0.3, 0.5, 1}, temp=ROOM_TEMP, conductivity=0.6, specific_heat=1.0, freezes_at=0, evaporates_at=100, density=1.0, viscosity=0.8},
    acid = {type="liquid", color={0.5, 1, 0.3}, temp=ROOM_TEMP, conductivity=0.7, specific_heat=0.9, dissolves=true, density=1.2, viscosity=0.6},
    oil = {type="liquid", color={0.1, 0.1, 0.05}, temp=ROOM_TEMP, conductivity=0.1, specific_heat=0.5, flammable=true, ignition_temp=250, density=0.9, viscosity=1.2},
    lava = {type="liquid", color={1, 0.4, 0.1}, temp=1200, conductivity=0.8, specific_heat=0.3, burns=true, cools_to="stone", density=3.1, viscosity=1.5},
    blood = {type="liquid", color={0.6, 0, 0}, temp=ROOM_TEMP, conductivity=0.5, specific_heat=0.9, density=1.1, viscosity=1.0},
    steam = {type="gas", color={1, 1, 1}, temp=150, conductivity=0.2, specific_heat=0.4, rises=true, condenses_at=100, density=0.6, pressure=1.2},
    smoke = {type="gas", color={0.2, 0.2, 0.2}, temp=200, conductivity=0.1, specific_heat=0.3, rises=true, density=0.4, pressure=1.0},
    poison = {type="gas", color={0.4, 1, 0.4}, temp=ROOM_TEMP, conductivity=0.2, specific_heat=0.4, rises=true, density=0.7, pressure=1.1},
    helium = {type="gas", color={1, 0.7, 1}, temp=ROOM_TEMP, conductivity=0.3, specific_heat=0.5, rises=true, density=0.2, pressure=1.3},
    tnt = {type="explosive", color={1, 0.2, 0.2}, temp=ROOM_TEMP, conductivity=0.2, specific_heat=0.6, explosive=true, ignition_temp=300, density=1.6, friction=0.8},
    thermite = {type="explosive", color={1, 0.5, 0.1}, temp=ROOM_TEMP, conductivity=0.4, specific_heat=0.5, explosive=true, ignition_temp=800, density=2.0, friction=0.7},
    firework = {type="explosive", color={1, 0.7, 0.2}, temp=ROOM_TEMP, conductivity=0.2, specific_heat=0.6, explosive=true, ignition_temp=400, density=1.4, friction=0.6},
    fire = {type="flame", color={1, 0.5, 0}, temp=800, conductivity=0.3, specific_heat=0.4, density=0.3, pressure=1.1}
}

function love.load()
    love.window.setMode(width, height)
    local grid_width = math.floor(width / scale)
    local grid_height = math.floor(height / scale)
    
    for x = 1, grid_width do
        grid[x] = {}
        for y = 1, grid_height do
            local cell_type = "air"
            local prop = elementProps[cell_type]
            grid[x][y] = { 
                type = cell_type, 
                updated = false, 
                shade = 0, 
                temp = prop and prop.temp or ROOM_TEMP,
                vx = 0,
                vy = 0,
                pressure = prop and prop.pressure or 1.0
            }
        end
    end
end

function updatePowder(x, y)
    local cell = grid[x][y]
    local prop = elementProps[cell.type]
    if not prop then return end
    
    -- Initialize velocity if not present
    cell.vx = cell.vx or 0
    cell.vy = cell.vy or 0
    
    -- Apply gravity
    cell.vy = cell.vy + GRAVITY
    
    -- Try to move down
    if moveIf(x, y, x, y+1, {"air", "liquid"}) then return end
    
    -- Try to move diagonally down
    local dir = love.math.random() > 0.5 and 1 or -1
    if moveIf(x, y, x+dir, y+1, {"air", "liquid"}) then return end
    if moveIf(x, y, x-dir, y+1, {"air", "liquid"}) then return end
    
    -- Try to move horizontally if in liquid
    if y < math.floor(height / scale) and grid[x][y+1] and 
       elementProps[grid[x][y+1].type] and 
       elementProps[grid[x][y+1].type].type == "liquid" then
        if moveIf(x, y, x+dir, y, {"air", "liquid"}) then return end
        if moveIf(x, y, x-dir, y, {"air", "liquid"}) then return end
    end
    
    -- Apply friction when on solid ground
    if y < math.floor(height / scale) and grid[x][y+1] and 
       elementProps[grid[x][y+1].type] and 
       elementProps[grid[x][y+1].type].type == "solid" then
        cell.vx = cell.vx * (1 - prop.friction)
    end
end

function updateLiquid(x, y)
    local cell = grid[x][y]
    local prop = elementProps[cell.type]
    if not prop then return end
    
    -- Initialize velocity if not present
    cell.vx = cell.vx or 0
    cell.vy = cell.vy or 0
    
    -- Apply gravity
    cell.vy = cell.vy + GRAVITY * 0.5  -- Liquids fall slower
    
    -- Try to move down
    if moveIf(x, y, x, y+1, {"air"}) then return end
    
    -- Try to spread horizontally
    local dir = love.math.random() > 0.5 and 1 or -1
    if moveIf(x, y, x+dir, y, {"air"}) then return end
    if moveIf(x, y, x-dir, y, {"air"}) then return end
    
    -- Try to move diagonally down
    if moveIf(x, y, x+dir, y+1, {"air"}) then return end
    if moveIf(x, y, x-dir, y+1, {"air"}) then return end
    
    -- Try to displace less dense liquids
    if y < math.floor(height / scale) then
        local below = grid[x][y+1]
        if below and below.type ~= "air" and elementProps[below.type] and 
           elementProps[below.type].type == "liquid" and 
           prop.density > elementProps[below.type].density then
            if moveIf(x, y, x, y+1, {"liquid"}) then return end
        end
    end
    
    -- Apply viscosity
    if prop.viscosity then
        cell.vx = cell.vx * (1 - prop.viscosity)
        cell.vy = cell.vy * (1 - prop.viscosity)
    end
end

function love.update(dt)
    -- Update UI slide animation
    ui_slide = ui_slide + (ui_target - ui_slide) * 10 * dt
    
    -- Handle tab key for UI (toggle instead of hold)
    if love.keyboard.isDown("tab") and not tab_was_down then
        ui_target = ui_target == 0 and 1 or 0
    end
    tab_was_down = love.keyboard.isDown("tab")
    
    -- Update clear confirmation timer
    if clear_confirmation then
        clear_timer = clear_timer + dt
        if clear_timer > 2 then  -- Reset confirmation after 2 seconds
            clear_confirmation = false
            clear_timer = 0
        end
    end

    paint_timer = paint_timer + dt
    if love.mouse.isDown(1) and paint_timer >= 0.01 then
        local mx, my = love.mouse.getPosition()
        if mx > UI_WIDTH * ui_slide then  -- Only paint if not clicking UI
            local grid_x = math.floor(mx / scale) + 1
            local grid_y = math.floor(my / scale) + 1
            if grid[grid_x] and grid[grid_x][grid_y] then
                paint(grid_x, grid_y)
            end
        end
        paint_timer = 0
    end

    for x = 1, math.floor(width / scale) do
        for y = 1, math.floor(height / scale) do
            grid[x][y].updated = false
        end
    end
    
    -- Update temperature first
    for y = 1, math.floor(height / scale) do
        for x = 1, math.floor(width / scale) do
            updateTemperature(x, y)
        end
    end
    
    -- Update positions and effects
    for y = math.floor(height / scale) - 1, 1, -1 do
        for x = 1, math.floor(width / scale) do
            local cell = grid[x][y]
            local prop = elementProps[cell.type]
            if not cell.updated and prop then
                applyEffects(x, y)
                if prop.type == "powder" then updatePowder(x, y)
                elseif prop.type == "liquid" then updateLiquid(x, y)
                elseif prop.type == "gas" then updateGas(x, y)
                elseif prop.type == "flame" then updateFire(x, y)
                end
            end
        end
    end
end

function love.draw()
    -- Draw grid
    for x = 1, math.floor(width / scale) do
        for y = 1, math.floor(height / scale) do
            local cell = grid[x][y]
            local c = elementProps[cell.type]
            if c then
                local r, g, b = unpack(c.color)
                -- Add temperature-based color tinting
                local temp = cell.temp or ROOM_TEMP
                local temp_factor = math.max(0, math.min(1, (temp - ROOM_TEMP) / 500))
                
                -- Special handling for lava
                if cell.type == "lava" then
                    -- Dynamic lava colors based on temperature
                    local lava_temp = math.max(0, math.min(1, (temp - 800) / 1000))
                    r = 1.0
                    g = 0.3 + lava_temp * 0.4  -- More yellow at higher temps
                    b = 0.1 + lava_temp * 0.2
                    
                    -- Add glow effect
                    love.graphics.setColor(r, g, b, LAVA_GLOW)
                    love.graphics.rectangle("fill", (x-1)*scale - 1, (y-1)*scale - 1, scale + 2, scale + 2)
                else
                    r = math.min(1, r + temp_factor * 0.5)
                    g = math.max(0, g - temp_factor * 0.3)
                    b = math.max(0, b - temp_factor * 0.3)
                end
                
                love.graphics.setColor(r * (0.9 + (cell.shade or 0) * 0.2), 
                                    g * (0.9 + (cell.shade or 0) * 0.2), 
                                    b * (0.9 + (cell.shade or 0) * 0.2))
                love.graphics.rectangle("fill", (x-1)*scale, (y-1)*scale, scale, scale)
            end
        end
    end

    -- Draw UI panel
    local panel_x = -UI_WIDTH * (1 - ui_slide)
    love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
    love.graphics.rectangle("fill", panel_x, 0, UI_WIDTH, height)
    
    -- Draw category tabs
    local tab_width = (UI_WIDTH - PADDING * 2) / #categories
    for i, cat in ipairs(categories) do
        local tab_x = panel_x + PADDING + (i-1) * tab_width
        local is_selected = cat == selected_category
        love.graphics.setColor(is_selected and 0.3 or 0.2, 0.2, 0.2, 0.9)
        love.graphics.rectangle("fill", tab_x, PADDING, tab_width - PADDING, TAB_HEIGHT - PADDING)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(cat:upper(), tab_x + (tab_width - PADDING - love.graphics.getFont():getWidth(cat:upper())) / 2, PADDING + (TAB_HEIGHT - PADDING - love.graphics.getFont():getHeight()) / 2)
    end
    
    -- Draw elements
    local y = TAB_HEIGHT + PADDING * 2
    local current_x = panel_x + PADDING
    for _, el in ipairs(elements[selected_category]) do
        local color = elementProps[el] and elementProps[el].color or {1,1,1}
        -- Draw colored background
        love.graphics.setColor(color[1], color[2], color[3], 0.3)
        love.graphics.rectangle("fill", current_x, y, UI_WIDTH - PADDING * 2, ELEMENT_SIZE)
        -- Draw text
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(el:upper(), current_x + PADDING, y + (ELEMENT_SIZE - love.graphics.getFont():getHeight()) / 2)
        
        y = y + ELEMENT_SIZE + PADDING
        if y > height - ELEMENT_SIZE - PADDING then
            y = TAB_HEIGHT + PADDING * 2
            current_x = current_x + (UI_WIDTH - PADDING * 2) / 2
        end
    end

    -- Draw clear all button at the bottom
    local button_y = height - ELEMENT_SIZE - PADDING
    local button_color = clear_confirmation and {1, 0.3, 0.3} or {0.7, 0.2, 0.2}
    love.graphics.setColor(button_color[1], button_color[2], button_color[3], 0.9)
    love.graphics.rectangle("fill", panel_x + PADDING, button_y, UI_WIDTH - PADDING * 2, ELEMENT_SIZE)
    love.graphics.setColor(1, 1, 1)
    local button_text = clear_confirmation and "CLICK AGAIN TO CLEAR" or "CLEAR ALL"
    love.graphics.print(button_text, 
        panel_x + PADDING + (UI_WIDTH - PADDING * 2 - love.graphics.getFont():getWidth(button_text)) / 2,
        button_y + (ELEMENT_SIZE - love.graphics.getFont():getHeight()) / 2)
end

function love.mousepressed(mx, my, button)
    if mx < UI_WIDTH * ui_slide then
        -- Check clear all button
        local button_y = height - ELEMENT_SIZE - PADDING
        if mx > -UI_WIDTH * (1 - ui_slide) + PADDING and 
           mx < -UI_WIDTH * (1 - ui_slide) + UI_WIDTH - PADDING and
           my > button_y and my < button_y + ELEMENT_SIZE then
            if clear_confirmation then
                -- Clear all cells
                for x = 1, math.floor(width / scale) do
                    for y = 1, math.floor(height / scale) do
                        local prop = elementProps["air"]
                        grid[x][y] = { 
                            type = "air", 
                            updated = false, 
                            shade = 0, 
                            temp = prop and prop.temp or ROOM_TEMP,
                            vx = 0,
                            vy = 0,
                            pressure = prop and prop.pressure or 1.0
                        }
                    end
                end
                clear_confirmation = false
                clear_timer = 0
            else
                clear_confirmation = true
                clear_timer = 0
            end
            return
        end

        -- Check category tabs
        local tab_width = (UI_WIDTH - PADDING * 2) / #categories
        for i, cat in ipairs(categories) do
            local tab_x = -UI_WIDTH * (1 - ui_slide) + PADDING + (i-1) * tab_width
            if mx > tab_x and mx < tab_x + tab_width - PADDING and 
               my > PADDING and my < TAB_HEIGHT then
                selected_category = cat
                return
            end
        end
        
        -- Check elements
        local y = TAB_HEIGHT + PADDING * 2
        local current_x = -UI_WIDTH * (1 - ui_slide) + PADDING
        for _, el in ipairs(elements[selected_category]) do
            if mx > current_x and mx < current_x + UI_WIDTH - PADDING * 2 and
               my > y and my < y + ELEMENT_SIZE then
                current_type = el
                return
            end
            y = y + ELEMENT_SIZE + PADDING
            if y > height - ELEMENT_SIZE - PADDING then
                y = TAB_HEIGHT + PADDING * 2
                current_x = current_x + (UI_WIDTH - PADDING * 2) / 2
            end
        end
    else
        local grid_x = math.floor(mx / scale) + 1
        local grid_y = math.floor(my / scale) + 1
        if grid[grid_x] and grid[grid_x][grid_y] then
            paint(grid_x, grid_y)
        end
    end
end

function paint(x, y)
    if grid[x] and grid[x][y] then
        local prop = elementProps[current_type]
        if prop then
            grid[x][y] = { 
                type = current_type, 
                updated = true, 
                shade = love.math.random(),
                temp = prop.temp or ROOM_TEMP,
                vx = 0,
                vy = 0,
                pressure = prop.pressure or 1.0
            }
        end
    end
end

function updateTemperature(x, y)
    local cell = grid[x][y]
    local prop = elementProps[cell.type]
    if not prop then return end

    -- Initialize temperature if not present
    cell.temp = cell.temp or (prop.temp or ROOM_TEMP)

    -- Temperature diffusion
    local total_temp = cell.temp
    local count = 1
    
    for dx = -1, 1 do
        for dy = -1, 1 do
            if dx ~= 0 or dy ~= 0 then
                local nx, ny = x + dx, y + dy
                if nx >= 1 and nx <= math.floor(width / scale) and ny >= 1 and ny <= math.floor(height / scale) then
                    local neighbor = grid[nx][ny]
                    if neighbor then  -- Check if neighbor exists
                        local neighbor_prop = elementProps[neighbor.type]
                        if neighbor_prop then
                            -- Initialize neighbor temperature if not present
                            neighbor.temp = neighbor.temp or (neighbor_prop.temp or ROOM_TEMP)
                            
                            local conductivity = (prop.conductivity + neighbor_prop.conductivity) / 2
                            total_temp = total_temp + neighbor.temp * conductivity
                            count = count + conductivity
                        end
                    end
                end
            end
        end
    end
    
    -- Update temperature
    cell.temp = (total_temp / count) * TEMP_DECAY
    
    -- Temperature effects
    if prop.melts and cell.temp > (prop.melts_at or 0) then
        if cell.type == "ice" then
            grid[x][y] = { 
                type = "water", 
                updated = true, 
                shade = love.math.random(), 
                temp = cell.temp,
                vx = cell.vx or 0,
                vy = cell.vy or 0,
                pressure = cell.pressure or 1.0
            }
        elseif cell.type == "glass" then
            grid[x][y] = { 
                type = "lava", 
                updated = true, 
                shade = love.math.random(), 
                temp = cell.temp,
                vx = cell.vx or 0,
                vy = cell.vy or 0,
                pressure = cell.pressure or 1.0
            }
        end
    end
    
    if prop.evaporates_at and cell.temp > prop.evaporates_at then
        if cell.type == "water" then
            grid[x][y] = { 
                type = "steam", 
                updated = true, 
                shade = love.math.random(), 
                temp = cell.temp,
                vx = cell.vx or 0,
                vy = cell.vy or 0,
                pressure = cell.pressure or 1.0
            }
        end
    end
    
    if prop.freezes_at and cell.temp < prop.freezes_at then
        if cell.type == "water" then
            grid[x][y] = { 
                type = "ice", 
                updated = true, 
                shade = love.math.random(), 
                temp = cell.temp,
                vx = cell.vx or 0,
                vy = cell.vy or 0,
                pressure = cell.pressure or 1.0
            }
        end
    end
    
    if prop.condenses_at and cell.temp < prop.condenses_at then
        if cell.type == "steam" then
            grid[x][y] = { 
                type = "water", 
                updated = true, 
                shade = love.math.random(), 
                temp = cell.temp,
                vx = cell.vx or 0,
                vy = cell.vy or 0,
                pressure = cell.pressure or 1.0
            }
        end
    end
    
    if prop.flammable and cell.temp > (prop.ignition_temp or 300) then
        grid[x][y] = { 
            type = "fire", 
            updated = true, 
            shade = love.math.random(), 
            temp = cell.temp,
            vx = cell.vx or 0,
            vy = cell.vy or 0,
            pressure = cell.pressure or 1.0
        }
    end
end

function updateVelocity(x, y)
    local cell = grid[x][y]
    local prop = elementProps[cell.type]
    if not prop then return end

    -- Apply gravity to non-gases
    if prop.type ~= "gas" then
        cell.vy = cell.vy + GRAVITY
    end

    -- Apply pressure forces for gases
    if prop.type == "gas" then
        local pressure_diff = 0
        local count = 0
        for dx = -1, 1 do
            for dy = -1, 1 do
                if dx ~= 0 or dy ~= 0 then
                    local nx, ny = x + dx, y + dy
                    if nx >= 1 and nx <= width and ny >= 1 and ny <= height then
                        local neighbor = grid[nx][ny]
                        if neighbor.type == "air" or elementProps[neighbor.type].type == "gas" then
                            pressure_diff = pressure_diff + (neighbor.pressure - cell.pressure)
                            count = count + 1
                        end
                    end
                end
            end
        end
        if count > 0 then
            local force = pressure_diff / count * PRESSURE_DIFFUSION
            cell.vx = cell.vx + force
            cell.vy = cell.vy - force * 0.5 -- Gas rises
        end
    end

    -- Apply viscosity for liquids
    if prop.type == "liquid" then
        local vx_sum, vy_sum = 0, 0
        local count = 0
        for dx = -1, 1 do
            for dy = -1, 1 do
                if dx ~= 0 or dy ~= 0 then
                    local nx, ny = x + dx, y + dy
                    if nx >= 1 and nx <= width and ny >= 1 and ny <= height then
                        local neighbor = grid[nx][ny]
                        if neighbor.type == cell.type then
                            vx_sum = vx_sum + neighbor.vx
                            vy_sum = vy_sum + neighbor.vy
                            count = count + 1
                        end
                    end
                end
            end
        end
        if count > 0 then
            cell.vx = cell.vx * (1 - prop.viscosity) + (vx_sum / count) * prop.viscosity
            cell.vy = cell.vy * (1 - prop.viscosity) + (vy_sum / count) * prop.viscosity
        end
    end

    -- Apply friction
    if prop.friction then
        cell.vx = cell.vx * (1 - prop.friction)
        cell.vy = cell.vy * (1 - prop.friction)
    end

    -- Limit velocity
    local speed = math.sqrt(cell.vx * cell.vx + cell.vy * cell.vy)
    if speed > MAX_VELOCITY then
        cell.vx = (cell.vx / speed) * MAX_VELOCITY
        cell.vy = (cell.vy / speed) * MAX_VELOCITY
    end

    -- Apply velocity decay
    cell.vx = cell.vx * VELOCITY_DECAY
    cell.vy = cell.vy * VELOCITY_DECAY
end

function moveWithVelocity(x, y)
    local cell = grid[x][y]
    if not cell then return end

    local new_x = x + cell.vx
    local new_y = y + cell.vy

    -- Round to nearest grid position
    local target_x = math.floor(new_x + 0.5)
    local target_y = math.floor(new_y + 0.5)

    -- Check if target position is valid
    if target_x >= 1 and target_x <= width and target_y >= 1 and target_y <= height then
        local target = grid[target_x][target_y]
        if target.type == "air" or (elementProps[cell.type] and elementProps[target.type] and 
            elementProps[cell.type].density > elementProps[target.type].density) then
            -- Swap cells
            grid[target_x][target_y], grid[x][y] = grid[x][y], grid[target_x][target_y]
            grid[target_x][target_y].updated = true
        end
    end
end

function applyEffects(x, y)
    local cell = grid[x][y]
    local prop = elementProps[cell.type]
    if not prop then return end

    local function burnTarget(tx, ty)
        local target = grid[tx] and grid[tx][ty]
        if target and not target.updated and elementProps[target.type] and elementProps[target.type].flammable then
            grid[tx][ty] = { type = "fire", updated = true, shade = love.math.random() }
        end
    end

    local function dissolveTarget(tx, ty)
        local target = grid[tx] and grid[tx][ty]
        if target and not target.updated and elementProps[target.type] and elementProps[target.type].type == "solid" then
            grid[tx][ty] = { type = "air", updated = true }
        end
    end

    if cell.type == "fire" then
        burnTarget(x+1, y)
        burnTarget(x-1, y)
        burnTarget(x, y+1)
        burnTarget(x, y-1)
    elseif cell.type == "acid" then
        dissolveTarget(x+1, y)
        dissolveTarget(x-1, y)
        dissolveTarget(x, y+1)
        dissolveTarget(x, y-1)
    elseif cell.type == "lava" then
        burnTarget(x+1, y)
        burnTarget(x-1, y)
        burnTarget(x, y+1)
        burnTarget(x, y-1)
    end
end

function updateGas(x, y)
    local cell = grid[x][y]
    local prop = elementProps[cell.type]
    if not prop then return end
    
    -- Initialize velocity and pressure if not present
    cell.vx = cell.vx or 0
    cell.vy = cell.vy or 0
    cell.pressure = cell.pressure or (prop.pressure or 1.0)
    
    -- Apply upward force
    cell.vy = cell.vy - GRAVITY * 0.3  -- Gases rise
    
    -- Try to move up
    if moveIf(x, y, x, y-1, {"air"}) then return end
    
    -- Try to move diagonally up
    local dir = love.math.random() > 0.5 and 1 or -1
    if moveIf(x, y, x+dir, y-1, {"air"}) then return end
    if moveIf(x, y, x-dir, y-1, {"air"}) then return end
    
    -- Try to spread horizontally
    if moveIf(x, y, x+dir, y, {"air"}) then return end
    if moveIf(x, y, x-dir, y, {"air"}) then return end
    
    -- Apply pressure forces
    if prop.pressure then
        local pressure_diff = 0
        local count = 0
        for dx = -1, 1 do
            for dy = -1, 1 do
                if dx ~= 0 or dy ~= 0 then
                    local nx, ny = x + dx, y + dy
                    if nx >= 1 and nx <= math.floor(width / scale) and 
                       ny >= 1 and ny <= math.floor(height / scale) then
                        local neighbor = grid[nx][ny]
                        if neighbor then
                            -- Initialize neighbor pressure if needed
                            if not neighbor.pressure then
                                local neighbor_prop = elementProps[neighbor.type]
                                neighbor.pressure = neighbor_prop and neighbor_prop.pressure or 1.0
                            end
                            
                            if neighbor.type == "air" or 
                               (elementProps[neighbor.type] and 
                                elementProps[neighbor.type].type == "gas") then
                                pressure_diff = pressure_diff + (neighbor.pressure - cell.pressure)
                                count = count + 1
                            end
                        end
                    end
                end
            end
        end
        if count > 0 then
            local force = pressure_diff / count * PRESSURE_DIFFUSION
            cell.vx = cell.vx + force
            cell.vy = cell.vy - force * 0.5
        end
    end
end

function updateFire(x, y)
    if y > 1 then
        if moveIf(x, y, x, y-1, {"air"}) then return end
        if moveIf(x, y, x-1, y-1, {"air"}) then return end
        if moveIf(x, y, x+1, y-1, {"air"}) then return end
    end
end

function moveIf(x1, y1, x2, y2, valid)
    if x2 < 1 or y2 < 1 or x2 > math.floor(width / scale) or y2 > math.floor(height / scale) then 
        return false 
    end
    
    local source = grid[x1][y1]
    local target = grid[x2][y2]
    
    if not source or not target or target.updated then 
        return false 
    end
    
    local source_prop = elementProps[source.type]
    local target_prop = elementProps[target.type]
    
    if not source_prop then 
        return false 
    end
    
    -- Check if target is air or a valid type to move into
    local can_move = target.type == "air"
    if not can_move and valid then
        for _, v in ipairs(valid) do
            if target.type == v then
                can_move = true
                break
            end
        end
    end
    
    if not can_move then 
        return false 
    end
    
    -- Check density for non-air moves
    if target.type ~= "air" and target_prop then
        if not (source_prop.density > target_prop.density) then
            return false
        end
    end
    
    -- Transfer velocity and properties
    target.vx = source.vx
    target.vy = source.vy
    target.temp = source.temp
    target.pressure = source.pressure
    target.shade = source.shade
    
    -- Swap cells
    grid[x2][y2], grid[x1][y1] = grid[x1][y1], grid[x2][y2]
    grid[x2][y2].updated = true
    return true
end

function tableHas(t, val)
    if not t then return false end
    for _, v in ipairs(t) do 
        if v == val then 
            return true 
        end 
    end
    return false
end
