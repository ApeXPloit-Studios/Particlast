
local width, height = 200, 150
local scale = 4
local grid = {}
local current_type = "sand"
local ui_open = true
local selected_category = "solids"

local elements = {
    solids = { "sand", "stone", "wood", "metal", "ice", "brick", "ash", "glass", "dirt" },
    liquids = { "water", "acid", "oil", "lava", "blood" },
    gases = { "steam", "smoke", "poison", "helium" },
    explosives = { "tnt", "thermite", "firework" },
    special = { "fire" }
}
local categories = { "solids", "liquids", "gases", "explosives", "special" }

local elementProps = {
    sand = {type="powder", color={0.76, 0.7, 0.5}},
    ash = {type="powder", color={0.5, 0.5, 0.5}},
    dirt = {type="powder", color={0.45, 0.3, 0.15}},
    glass = {type="powder", color={0.9, 1, 1}},
    wood = {type="solid", color={0.4, 0.25, 0.1}, flammable=true},
    metal = {type="solid", color={0.7, 0.7, 0.75}},
    brick = {type="solid", color={0.7, 0.2, 0.2}},
    ice = {type="solid", color={0.6, 0.9, 1}, melts=true},
    stone = {type="solid", color={0.4, 0.4, 0.4}},
    water = {type="liquid", color={0.3, 0.5, 1}},
    acid = {type="liquid", color={0.5, 1, 0.3}, dissolves=true},
    oil = {type="liquid", color={0.1, 0.1, 0.05}, flammable=true},
    lava = {type="liquid", color={1, 0.3, 0}, burns=true},
    blood = {type="liquid", color={0.6, 0, 0}},
    steam = {type="gas", color={1, 1, 1}, rises=true},
    smoke = {type="gas", color={0.2, 0.2, 0.2}, rises=true},
    poison = {type="gas", color={0.4, 1, 0.4}, rises=true},
    helium = {type="gas", color={1, 0.7, 1}, rises=true},
    tnt = {type="explosive", color={1, 0.2, 0.2}},
    thermite = {type="explosive", color={1, 0.5, 0.1}},
    firework = {type="explosive", color={1, 0.7, 0.2}},
    fire = {type="flame", color={1, 0.5, 0}}
}

function love.load()
    love.window.setMode(width * scale + 120, height * scale)
    for x = 1, width do
        grid[x] = {}
        for y = 1, height do
            grid[x][y] = { type = "air", updated = false, shade = 0 }
        end
    end
end


local paint_timer = 0
function love.update(dt)
    paint_timer = paint_timer + dt
    if love.mouse.isDown(1) and paint_timer >= 0.01 then
        local mx, my = love.mouse.getPosition()
        paint(mx, my)
        paint_timer = 0
    end

    for x = 1, width do
        for y = 1, height do
            grid[x][y].updated = false
        end
    end
    for y = height - 1, 1, -1 do
        for x = 1, width do
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

function updatePowder(x, y)
    if moveIf(x, y, x, y+1, {"air", "liquid"}) then return end
    if moveIf(x, y, x-1, y+1, {"air", "liquid"}) then return end
    if moveIf(x, y, x+1, y+1, {"air", "liquid"}) then return end
end

function updateLiquid(x, y)
    if moveIf(x, y, x, y+1, {"air"}) then return end
    if moveIf(x, y, x+1, y, {"air"}) then return end
    if moveIf(x, y, x-1, y, {"air"}) then return end
end

function updateGas(x, y)
    if moveIf(x, y, x, y-1, {"air"}) then return end
    if moveIf(x, y, x+1, y-1, {"air"}) then return end
    if moveIf(x, y, x-1, y-1, {"air"}) then return end
end

function updateFire(x, y)
    if y > 1 then
        if moveIf(x, y, x, y-1, {"air"}) then return end
        if moveIf(x, y, x-1, y-1, {"air"}) then return end
        if moveIf(x, y, x+1, y-1, {"air"}) then return end
    end
end

function moveIf(x1, y1, x2, y2, valid)
    if x2 < 1 or y2 < 1 or x2 > width or y2 > height then return false end
    local target = grid[x2][y2]
    if not target.updated and (target.type == "air" or tableHas(valid, target.type)) then
        grid[x2][y2], grid[x1][y1] = grid[x1][y1], grid[x2][y2]
        grid[x2][y2].updated = true
        return true
    end
end

function tableHas(t, val)
    for _, v in ipairs(t) do if v == val then return true end end
end

function love.draw()
    for x = 1, width do
        for y = 1, height do
            local cell = grid[x][y]
            local c = elementProps[cell.type]
            if c then
                local r, g, b = unpack(c.color)
                love.graphics.setColor(r * (0.9 + (cell.shade or 0) * 0.2), g * (0.9 + (cell.shade or 0) * 0.2), b * (0.9 + (cell.shade or 0) * 0.2))
                love.graphics.rectangle("fill", (x-1)*scale, (y-1)*scale, scale, scale)
            end
        end
    end

    if ui_open then
        local px = width * scale
        love.graphics.setColor(0.1,0.1,0.1)
        love.graphics.rectangle("fill", px, 0, 120, height * scale)

        for i, cat in ipairs(categories) do
            local y = 5 + (i-1) * 25
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(cat:upper(), px + 10, y)
        end

        local y = 140
        for _, el in ipairs(elements[selected_category]) do
            local color = elementProps[el] and elementProps[el].color or {1,1,1}
            love.graphics.setColor(color[1], color[2], color[3])
            love.graphics.rectangle("fill", px + 10, y, 100, 20)
            love.graphics.setColor(0, 0, 0)
            love.graphics.print(el, px + 15, y + 3)
            y = y + 25
        end
    end
end


function love.mousepressed(mx, my, button)
    if ui_open and mx > width * scale then
        local px = width * scale
        for i, cat in ipairs(categories) do
            local ty = 5 + (i - 1) * 25
            if mx > px + 10 and mx < px + 110 and my > ty and my < ty + 20 then
                selected_category = cat
                return
            end
        end
    end
    if ui_open and mx > width * scale then
        local px = width * scale
        local y = 140
        for _, el in ipairs(elements[selected_category]) do
            if mx > px + 10 and mx < px + 110 and my > y and my < y + 20 then
                current_type = el
                return
            end
            y = y + 25
        end
    else
        paint(mx, my)
    end
end

function paint(mx, my)
    local x = math.floor(mx / scale) + 1
    local y = math.floor(my / scale) + 1
    if grid[x] and grid[x][y] then
        grid[x][y] = { type = current_type, updated = true, shade = love.math.random() }
    end
end
