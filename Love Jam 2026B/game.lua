local Game = {}

-- We mainly use playerBody:setLinearVelocity() to change player's velocity
-- It is Love Engine's Box2D function of the linear velocity of a rigidbody object
local player = {x = 320, y = 320, w = 32, h = 64, isOnGround = false}

-- Temp Platforms
local platforms = {
    {x = 0, y = 544, w = 800, h = 64, tag = "ground"}, -- Temp Ground
    {x = 0, y = 0, w = 32, h = 544}, -- Temp Left Wall
    {x = 768, y = 0, w = 32, h =480}, -- Temp Right Wall
}

-- Temp Tray
local tray = {halfW = 64, gap = 24, offset = 0, x = 336, vx = 0, vy = 0, tilt = 0}

-- Haven't used
local items = {
    {x = 480, y = 524, w = 20, h = 20},
    {x = 700, y = 524, w = 20, h = 20},
}

-- Physics World (Box2D) from Love Engine
local world
local playerBody

local fixtureTags = {}

-- Is player on something(like ground)
local function isGrounded()
    for _, contact in ipairs(world:getContacts()) do
        if contact:isTouching() then
            local fixtureA, fixtureB = contact:getFixtures()

            local playerIsA = fixtureA:getBody() == playerBody
            local playerIsB = fixtureB:getBody() == playerBody

            if playerIsA or playerIsB then

                local otherFixture
                if playerIsA then
                    otherFixture = fixtureB
                else
                    otherFixture = fixtureA
                end

                -- check if the platform is ground so that can be used in jump
                if fixtureTags[otherFixture] == "ground" then
                    return true
                end
            end
        end
    end
    return false
end


-- tray has two endpoints they are calculated based on the position and tilt angle of the tray
local function trayEnds()
    local y = player.y - tray.gap + tray.offset
    local dx = math.cos(tray.tilt) * tray.halfW
    local dy = math.sin(tray.tilt) * tray.halfW
    return tray.x - dx, y + dy, tray.x + dx, y - dy
end

-- Verlet algorithm -> Rope Simulate as hands
local ropes = {}

-- The rope's offsets of player’s shoulder, left rope put it on player.x + 8, right rope put it on player.x + 24

local ROPE_SHOULDER_OFFSETS = {8, 24}

local function resetRopes()
    ropes = {}

    local leftX, leftY, rightX, rightY = trayEnds()

    for i, shoulderOffset in ipairs(ROPE_SHOULDER_OFFSETS) do
        local isLeftRope = (i == 1)

        -- player's shoulder position
        local startX = player.x + shoulderOffset
        local startY = player.y + 20

        -- the end position of rope, now is in the tray's left edge and right edge
        local endX, endY
        if isLeftRope then
            endX, endY = leftX, leftY
        else
            endX, endY = rightX, rightY
        end

        -- the rope is divided into 5 parts which also means it is consist of 6 mass points
        -- the length of the rope is 10% longer(x1.1) than a straight line
        -- Under the Verlet algorithm, the "hand" formed by the rope will be more "Jelly"
        local rope = {points = {}, shoulderOffset = shoulderOffset, isLeftRope = isLeftRope}
        local straightDistance = math.sqrt((endX - startX) ^ 2 + (endY - startY) ^ 2)
        rope.segmentLength = straightDistance / 5 * 1.1

        -- set the 6 mass points
        for j = 0, 5 do
            local t = j / 5
            local x = startX + (endX - startX) * t
            local y = startY + (endY - startY) * t
            rope.points[j + 1] = {x = x, y = y, px = x, py = y}
        end

        ropes[i] = rope
    end
end

local function updateRopes(dt)
    for _, rope in ipairs(ropes) do
        local points = rope.points
        local pointCount = #points

        -- the first point is on player's shoulder
        points[1].x = player.x + rope.shoulderOffset
        points[1].y = player.y + 20

        -- the last point is on the end of tray's edge
        local leftX, leftY, rightX, rightY = trayEnds()
        if rope.isLeftRope then
            points[pointCount].x, points[pointCount].y = leftX, leftY
        else
            points[pointCount].x, points[pointCount].y = rightX, rightY
        end

        -- the middle points use Verlet: "current position - the previous moment position" as velocity
        for j = 2, pointCount - 1 do
            local point = points[j]

            local vx = (point.x - point.px) * 0.97
            local vy = (point.y - point.py) * 0.97

            point.px, point.py = point.x, point.y
            point.x = point.x + vx
            point.y = point.y + vy + 900 * dt * dt
        end

        -- Repeatedly pull two adjacent points back to the set length, so that the rope can't be stretched
        for k = 1, 5 do
            for j = 1, pointCount - 1 do
                local a = points[j]
                local b = points[j + 1]

                local dx = b.x - a.x
                local dy = b.y - a.y
                local distance = math.sqrt(dx * dx + dy * dy)

                if distance > rope.segmentLength then
                    local diff = (distance - rope.segmentLength) / distance * 0.5

                    -- only move the points at the middle of the rope
                    if j > 1 then
                        a.x = a.x + dx * diff
                        a.y = a.y + dy * diff
                    end
                    if j < pointCount - 1 then
                        b.x = b.x - dx * diff
                        b.y = b.y - dy * diff
                    end
                end
            end
        end
    end
end

local function drawRopes()
    love.graphics.setColor(0, 0, 0)
    love.graphics.setLineWidth(3)

    for _, rope in ipairs(ropes) do
        -- love.graphics.line need a string of numbers x, y, x, y..., so make an array here first
        local linePoints = {}
        for _, point in ipairs(rope.points) do
            table.insert(linePoints, point.x)
            table.insert(linePoints, point.y)
        end
        
        love.graphics.line(linePoints)
    end

    love.graphics.setLineWidth(1)
end

function Game.enter(self)
    player.x, player.y = 320, 320
    player.isOnGround = false
    tray.offset, tray.vy = 0, 0
    tray.x, tray.vx = player.x + player.w * 0.5, 0
    tray.tilt = 0

    -- Gravity Settings (900 px/s²,now)
    love.physics.setMeter(64)
    world = love.physics.newWorld(0, 900, true)

    -- Player Settings
    playerBody = love.physics.newBody(world, player.x + player.w * 0.5, player.y + player.h * 0.5, "dynamic")
    playerBody:setFixedRotation(true)
    playerBody:setSleepingAllowed(false)

    local playerFixture = love.physics.newFixture(playerBody, love.physics.newRectangleShape(player.w, player.h))
    playerFixture:setFriction(0)

    -- Platforms Settings
    -- every platform is a rigidbody with tag
    fixtureTags = {}
    for _, platform in ipairs(platforms) do
        local platformCenterX = platform.x + platform.w * 0.5
        local platformCenterY = platform.y + platform.h * 0.5

        -- player's box2D
        local platformBody = love.physics.newBody(world, platformCenterX, platformCenterY, "static")

        local platformFixture = love.physics.newFixture(platformBody, love.physics.newRectangleShape(platform.w, platform.h))

        -- tag
        fixtureTags[platformFixture] = platform.tag
    end

    resetRopes()
end

function Game.update(self, dt)

    -- Player Input
    local speed = 320
    local moveX = 0
    if love.keyboard.isDown("right", "d") then
        moveX = moveX + speed
    end
    if love.keyboard.isDown("left", "a") then
        moveX = moveX - speed
    end

    -- keep our horizontal velocity, and use engine's rigidbody physics velocity(for gravity)
    local currentVx, currentVy = playerBody:getLinearVelocity()
    playerBody:setLinearVelocity(moveX, currentVy)

    world:update(dt)

    -- player's box2D position is the center of the rectangle, but player's position is the top-left corner, convert it here
    local bodyX, bodyY = playerBody:getPosition()
    player.x = bodyX - player.w * 0.5
    player.y = bodyY - player.h * 0.5

    -- Landing
    -- make the tray sink(more "jelly")
    local grounded = isGrounded()
    -- grounded is for checking if the player is currently on the ground
    -- not player.isOnGround is for checking if the player's previous position is on the ground
    -- so that can make the effect: when player landing the tray sinks
    if grounded and not player.isOnGround and currentVy > 100 then
        tray.vy = tray.vy + currentVy * 2
    end
    player.isOnGround = grounded

    -- the tray keeps following player but its velocity is less than player so that can be more "jelly"
    -- tray's velocity is like spring so I used spring physics to make it more "jelly"
    -- spring phsics(according to damped harmonic oscillator):F_spring = -k * displacement, F_damp = -c * velocity, F = -k*displacement - c*velocity
    -- so that we get a = -k*displacement - c*velocity which like the (-40 * (tray.x - targetX) - 5 * tray.vx) below times the time, get the spring-like velocity
    local targetX = player.x + player.w * 0.5
    tray.vx = tray.vx + (-40 * (tray.x - targetX) - 5 * tray.vx) * dt
    tray.x = tray.x + tray.vx * dt

    -- If the tray position is offset in the vertical direction
    -- pull it down if it is up, and pull it up if it is down, until it returns the original position
    tray.vy = tray.vy + (-500 * tray.offset - 7 * tray.vy) * dt
    tray.offset = tray.offset + tray.vy * dt

    -- Tray tilt(max is 0.35rads)
    local targetTilt = (targetX - tray.x) * 0.006
    local maxTilt = 0.35
    if targetTilt > maxTilt then
        targetTilt = maxTilt
    end
    if targetTilt < -maxTilt then
        targetTilt = -maxTilt
    end
    tray.tilt = tray.tilt + (targetTilt - tray.tilt) * 10 * dt

    updateRopes(dt)

end

function Game.keypressed(self, key)
    if key == "space" then
        if player.isOnGround then
            -- Jump
            local currentVx = playerBody:getLinearVelocity()
            playerBody:setLinearVelocity(currentVx, -320)
            player.isOnGround = false

            -- sink the tray when jumping
            tray.vy = tray.vy + 130
        end
    end

end

function Game.draw(self)

    -- Draw Temp Colour of Background
    love.graphics.clear(0.1, 0.1, 0.1)

    -- Draw Platforms (Temp Test)
    love.graphics.setColor(0.3, 0.3, 0.5)
    for _, platform in ipairs(platforms) do
        love.graphics.rectangle("fill", platform.x, platform.y, platform.w, platform.h)
    end

    drawRopes()

    -- Draw Player (Temp Test)
    love.graphics.setColor(0.9, 0.9, 1)
    love.graphics.rectangle("fill", player.x, player.y, player.w, player.h)

    -- Draw Tray (Temp Test)
    local leftX, leftY, rightX, rightY = trayEnds()
    love.graphics.setColor(0.5, 0.5, 1)
    love.graphics.setLineWidth(3)
    love.graphics.line(leftX, leftY, rightX, rightY)

    -- Draw Items (Temp Test)
    love.graphics.setColor(1, 0.8, 0.35)
    for _, item in ipairs(items) do
        love.graphics.rectangle("fill", item.x, item.y, item.w, item.h)
    end

end

return Game
