local Game = {}

local player = {x = 320, y = 320, w = 32, h = 64, vx = 0, vy = 0, isOnGround = false}

-- Temp Platforms
local platforms = {
    {x = 0, y = 544, w = 800, h = 64}, -- Temp Ground
    {x = 0, y = 0, w = 32, h = 544}, -- Temp Left Wall
    {x = 768, y = 0, w = 32, h =480}, -- Temp Right Wall
}

-- Temp Tray
local tray = {halfW = 64, gap = 24, offset = 0, x = 336, vx = 0, vy = 0, tilt = 0}

-- Haven't used
local items = {
    {x = 480, y = 524, w = 20, h = 20, vx = 0, vy = 0},
    {x = 700, y = 524, w = 20, h = 20, vx = 0, vy = 0},
}

-- Detect whether two objects collide
local function overlap(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end

-- Used for the calculation about the following Verlet algorithm
local function trayEnds()
    local y = player.y - tray.gap + tray.offset
    local dx = math.cos(tray.tilt) * tray.halfW
    local dy = math.sin(tray.tilt) * tray.halfW
    return tray.x - dx, y + dy, tray.x + dx, y - dy
end

-- Verlet algorithm -> Rope Simulate as hands
local ropes = {}

local function resetRopes()
    ropes = {}
    for i = 1, 2 do
        local sx = player.x + (i == 1 and 8 or 24)
        local sy = player.y + 20
        local lx, ly, rx, ry = trayEnds()
        local ex = (i == 1) and lx or rx
        local ey = (i == 1) and ly or ry
        local rope = {pts = {}}
        rope.len = math.sqrt((ex - sx) ^ 2 + (ey - sy) ^ 2) / 5 * 1.1
        for j = 0, 5 do
            local t = j / 5
            local x = sx + (ex - sx) * t
            local y = sy + (ey - sy) * t
            rope.pts[j + 1] = {x = x, y = y, px = x, py = y}
        end
        ropes[i] = rope
    end
end

local function updateRopes(dt)
    for i, rope in ipairs(ropes) do
        local p, n = rope.pts, #rope.pts
        p[1].x, p[1].y = player.x + (i == 1 and 8 or 24), player.y + 20
        local lx, ly, rx, ry = trayEnds()
        p[n].x = (i == 1) and lx or rx
        p[n].y = (i == 1) and ly or ry
        for j = 2, n - 1 do
            local q = p[j]
            local vx, vy = (q.x - q.px) * 0.97, (q.y - q.py) * 0.97
            q.px, q.py = q.x, q.y
            q.x = q.x + vx
            q.y = q.y + vy + 900 * dt * dt
        end
        for k = 1, 5 do
            for j = 1, n - 1 do
                local a, b = p[j], p[j + 1]
                local dx, dy = b.x - a.x, b.y - a.y
                local d = math.sqrt(dx * dx + dy * dy)
                if d > rope.len then
                    local s = (d - rope.len) / d * 0.5
                    if j > 1 then a.x, a.y = a.x + dx * s, a.y + dy * s end
                    if j < n - 1 then b.x, b.y = b.x - dx * s, b.y - dy * s end
                end
            end
        end
    end
end

local function drawRopes()
    love.graphics.setColor(0, 0, 0)
    love.graphics.setLineWidth(3)
    for i, rope in ipairs(ropes) do
        local v = {}
        for i, q in ipairs(rope.pts) do
            v[#v + 1] = q.x
            v[#v + 1] = q.y
        end
        love.graphics.line(v)
    end
    love.graphics.setLineWidth(1)
end

function Game.enter(self)
    player.x, player.y = 320, 320
    player.vx, player.vy = 0, 0
    player.isOnGround = false
    tray.offset, tray.vy = 0, 0
    tray.x, tray.vx = player.x + player.w * 0.5, 0
    tray.tilt = 0

    resetRopes()
end

function Game.update(self,dt)   

    -- Player Input
    local speed = 320
    player.vx = 0
    if love.keyboard.isDown("right","d") then
        player.vx = player.vx + speed
    end
    if love.keyboard.isDown("left","a") then 
        player.vx = player.vx - speed
    end

    -- World Gravity
    player.vy = player.vy + 900 * dt

    -- Move X
    player.x = player.x + player.vx * dt
    
    for i, platform in ipairs(platforms) do
        if overlap(player.x, player.y, player.w, player.h, platform.x, platform.y, platform.w, platform.h) then
            if player.vx > 0 then
                player.x = platform.x - player.w
            elseif player.vx < 0 then
                player.x = platform.x + platform.w
            end
        end
    end

    -- Move Y
    player.y = player.y + player.vy * dt
    player.isOnGround = false

    for i, platform in ipairs(platforms) do
        if overlap(player.x, player.y, player.w, player.h, platform.x, platform.y, platform.w, platform.h) then
            if player.vy > 0 then
                player.y = platform.y - player.h

                if player.vy > 100 then

                    -- Landing impulse -> the tray keeps moving when landing.
                    -- Like a spring 
                    tray.vy = tray.vy + player.vy * 2

                end

                player.vy = 0
                player.isOnGround = true
            elseif player.vy < 0 then
                player.y = platform.y + platform.h
                player.vy = 0
            end
        end
    end

    -- Tray Simulate Inertia Effect
    tray.vy = tray.vy + (-500 * tray.offset - 7 * tray.vy) * dt
    tray.offset = tray.offset + tray.vy * dt

    local targetX = player.x + player.w * 0.5
    tray.vx = tray.vx + (-40 * (tray.x - targetX) - 5 * tray.vx) * dt
    tray.x = tray.x + tray.vx * dt

    local targetTilt = (targetX - tray.x) * 0.006
    targetTilt = math.max(-0.35, math.min(0.35, targetTilt))
    tray.tilt = tray.tilt + (targetTilt - tray.tilt) * 10 * dt

    updateRopes(dt)

end

function Game.keypressed(self,key)
    if key == "space" then
        if player.isOnGround then
            player.vy = -320
            player.isOnGround = false

            -- Jump impulse -> make the tray lag and sink.
            tray.vy = tray.vy + 130
        end
    end

end

function Game.draw(self)

    -- Draw Temp Colour of Background 
    love.graphics.clear(0.1, 0.1, 0.1)

    -- Draw Platforms (Temp Test)
    love.graphics.setColor(0.3, 0.3, 0.5)
    for i, platform in ipairs(platforms) do
        love.graphics.rectangle("fill", platform.x, platform.y, platform.w, platform.h)
    end

    drawRopes()

    -- Draw Player (Temp Test)
    love.graphics.setColor(0.9, 0.9, 1)
    love.graphics.rectangle("fill", player.x, player.y, player.w, player.h)

    -- Draw Tray (Temp Test)
    local lx, ly, rx, ry = trayEnds()
    love.graphics.setColor(0.5, 0.5, 1)
    love.graphics.setLineWidth(3)
    love.graphics.line(lx, ly, rx, ry)

    -- Draw Items (Temp Test)
    love.graphics.setColor(1, 0.8, 0.35)
    for i, item in ipairs(items) do
        love.graphics.rectangle("fill", item.x, item.y, item.w, item.h)
    end

end

return Game
