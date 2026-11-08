local Game = {}

local player = {x = 320, y = 320, w = 32, h = 64, vx = 0, vy = 0, isOnGround = false}

-- Temp Platforms
local platforms = {
    {x = 0, y = 544, w = 800, h = 64}, -- Temp Ground
    {x = 0, y = 0, w = 32, h = 544}, -- Temp Left Wall
    {x = 768, y = 0, w = 32, h =480}, -- Temp Right Wall
}

-- Temp Tray
local tray = {halfW = 64, gap = 24, offset = 0, v = 0}

-- Haven't used
local items = {
    {x = 480, y = 524, w = 20, h = 20, vx = 0, vy = 0},
    {x = 700, y = 524, w = 20, h = 20, vx = 0, vy = 0},
}

-- Detect whether two objects collide
local function overlap(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end

function Game.enter(self)
    player.x, player.y = 320, 320
    player.vx, player.vy = 0, 0
    player.isOnGround = false
    tray.offset, tray.v = 0, 0

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
                    tray.v = tray.v + player.vy * 2

                end

                player.vy = 0
                player.isOnGround = true
            elseif player.vy < 0 then
                player.y = platform.y + platform.h
                player.vy = 0
            end
        end
    end

    -- Tray Effect
    -- the 500 = stiffness k: higher = faster, snappier wobble but smaller amplitude
    -- the 7 = damping c: higher = settles sooner, lower = wobbles longer
    tray.v = tray.v + (-500 * tray.offset - 7 * tray.v) * dt
    tray.offset = tray.offset + tray.v * dt

end

function Game.keypressed(self,key)
    if key == "space" then
        if player.isOnGround then
            player.vy = -320
            player.isOnGround = false

            -- Jump impulse -> make the tray lag and sink.
            tray.v = tray.v + 130
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

    -- Draw Player (Temp Test)
    love.graphics.setColor(0.9, 0.9, 1)
    love.graphics.rectangle("fill", player.x, player.y, player.w, player.h)

    -- Draw Tray (Temp Test)
    local cx = player.x + player.w * 0.5
    local trayY = player.y - tray.gap + tray.offset
    love.graphics.setColor(0.5, 0.5, 1)
    love.graphics.setLineWidth(3)
    love.graphics.line(cx - tray.halfW, trayY, cx + tray.halfW, trayY)

    -- Draw Items (Temp Test)
    love.graphics.setColor(1, 0.8, 0.35)
    for i, item in ipairs(items) do
        love.graphics.rectangle("fill", item.x, item.y, item.w, item.h)
    end

end

return Game
