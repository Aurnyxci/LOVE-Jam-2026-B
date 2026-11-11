local Game = {}

-- We mainly use playerBody:setLinearVelocity() to change player's velocity
-- It is Love Engine's Box2D function of the linear velocity of a rigidbody object
local player = {x = 320, y = 320, w = 32, h = 64, isOnGround = false}

-- Temp Platforms
local platforms = {
    {x = 0, y = 544, w = 800, h = 64, tag = "ground"}, -- Temp Ground
    {x = 0, y = 0, w = 32, h = 544}, -- Temp Left Wall
    {x = 768, y = 0, w = 32, h = 480}, -- Temp Right Wall
}

-- Temp Tray
local tray = {halfW = 64, gap = 24, offset = 0, x = 336, y = 288, vx = 0, vy = 0, tilt = 0, sideH = 24}

-- Temp Items
local items = {
    {x = 480, y = 524, w = 24, h = 24},
    {x = 700, y = 524, w = 24, h = 24},
}

-- Physics World (Box2D) from Love Engine
local world
local playerBody
local trayBody
-- check if can pick up
local nearbyItem

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
    local dx = math.cos(tray.tilt) * tray.halfW
    local dy = math.sin(tray.tilt) * tray.halfW
    return tray.x - dx, tray.y + dy, tray.x + dx, tray.y - dy
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

            local vx = (point.x - point.px) * 0.985
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
    tray.y = player.y - tray.gap
    tray.tilt = 0
    nearbyItem = nil

    -- Gravity Settings (900 px/s²,now)
    love.physics.setMeter(64)
    world = love.physics.newWorld(0, 900, true)

    -- Player Settings
    playerBody = love.physics.newBody(world, player.x + player.w * 0.5, player.y + player.h * 0.5, "dynamic")
    playerBody:setFixedRotation(true)
    playerBody:setSleepingAllowed(false)

    local playerFixture = love.physics.newFixture(playerBody, love.physics.newRectangleShape(player.w, player.h))
    playerFixture:setFriction(0)
    playerFixture:setGroupIndex(-1)

    -- Platforms Settings
    -- every platform is a rigidbody with tag
    fixtureTags = {}
    for _, platform in ipairs(platforms) do
        local platformCenterX = platform.x + platform.w * 0.5
        local platformCenterY = platform.y + platform.h * 0.5

        -- player's box2D
        local platformBody = love.physics.newBody(world, platformCenterX, platformCenterY, "static")

        local platformFixture = love.physics.newFixture(platformBody, love.physics.newRectangleShape(platform.w, platform.h))
        platformFixture:setFriction(1.5)

        -- tag
        fixtureTags[platformFixture] = platform.tag
    end

    -- Tray Physics
    trayBody = love.physics.newBody(world, tray.x, player.y - tray.gap, "kinematic")
    local trayFixture = love.physics.newFixture(
        trayBody,
        love.physics.newRectangleShape(tray.halfW * 2, 6)
    )
    trayFixture:setFriction(1.5)
    trayFixture:setGroupIndex(-1)

    local leftTrayFixture = love.physics.newFixture(
        trayBody,
        love.physics.newRectangleShape(-tray.halfW + 3, -3 - tray.sideH * 0.5, 6, tray.sideH)
    )
    leftTrayFixture:setFriction(1.5)
    leftTrayFixture:setGroupIndex(-1)

    local rightTrayFixture = love.physics.newFixture(
        trayBody,
        love.physics.newRectangleShape(tray.halfW - 3, -3 - tray.sideH * 0.5, 6, tray.sideH)
    )
    rightTrayFixture:setFriction(1.5)
    rightTrayFixture:setGroupIndex(-1)

    -- Items Physics
    for _, item in ipairs(items) do
        item.body = love.physics.newBody(
            world,
            item.x + item.w * 0.5,
            item.y + item.h * 0.5,
            "dynamic"
        )
        item.body:setLinearDamping(2)
        item.body:setAngularDamping(8)
        item.fixture = love.physics.newFixture(
            item.body,
            love.physics.newRectangleShape(item.w, item.h)
        )
        item.fixture:setFriction(1.5)
        item.fixture:setRestitution(0.1)
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
    local _, currentVy = playerBody:getLinearVelocity()
    playerBody:setLinearVelocity(moveX, currentVy)

    world:update(dt)

    -- player's box2D position is the center of the rectangle, but player's position is the top-left corner, convert it here
    local bodyX, bodyY = playerBody:getPosition()
    player.x = bodyX - player.w * 0.5
    player.y = bodyY - player.h * 0.5

    local grounded = isGrounded()
    if grounded and not player.isOnGround and currentVy > 100 then
        tray.vy = tray.vy + currentVy * 2
    end
    player.isOnGround = grounded

    local playerCenterX = player.x + player.w * 0.5
    local playerCenterY = player.y + player.h * 0.5

    -- Horizontal spring makes the tray lag behind the player
    tray.vx = tray.vx + (-40 * (tray.x - playerCenterX) - 5 * tray.vx) * dt
    tray.x = tray.x + tray.vx * dt

    -- Soft vertical movement
    tray.vy = tray.vy + (-500 * tray.offset - 7 * tray.vy) * dt
    tray.offset = tray.offset + tray.vy * dt
    tray.y = player.y - tray.gap + tray.offset

    -- Slight tilt caused by the horizontal lag
    local targetTilt = math.max(-0.35, math.min(0.35, (playerCenterX - tray.x) * 0.006))
    tray.tilt = tray.tilt + (targetTilt - tray.tilt) * 10 * dt

    -- Move the tray with real velocities so collisions transfer momentum
    local trayBodyX, trayBodyY = trayBody:getPosition()
    trayBody:setLinearVelocity((tray.x - trayBodyX) / dt, (tray.y - trayBodyY) / dt)
    trayBody:setAngularVelocity((-tray.tilt - trayBody:getAngle()) / dt)

    -- Find the closest item within pickup range
    nearbyItem = nil
    local closestDistance = 50 * 50
    for _, item in ipairs(items) do
        local itemX, itemY = item.body:getPosition()
        local dx = itemX - playerCenterX
        local dy = itemY - playerCenterY
        local distance = dx * dx + dy * dy
        if distance < closestDistance then
            closestDistance = distance
            nearbyItem = item
        end
    end

    updateRopes(dt)
end

function Game.keypressed(self, key)     
    if key == "space" then
        if player.isOnGround then
            -- Jump
            local currentVx = playerBody:getLinearVelocity()
            playerBody:setLinearVelocity(currentVx, -320)
            player.isOnGround = false
            tray.vy = tray.vy + 130
        end
    end
    -- pick up item
    if key == "e" and nearbyItem then
        local trayY = tray.y
        local itemOffset = 4 + nearbyItem.h * 0.5
        local itemX = tray.x - math.sin(tray.tilt) * itemOffset
        local itemY = trayY - math.cos(tray.tilt) * itemOffset
        nearbyItem.body:setPosition(itemX, itemY)
        nearbyItem.body:setLinearVelocity(0, 0)
        nearbyItem.body:setAngularVelocity(0)
        nearbyItem.body:setAwake(true)
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

    local sideOffsetX = math.sin(tray.tilt) * tray.sideH
    local sideOffsetY = math.cos(tray.tilt) * tray.sideH
    love.graphics.line(leftX, leftY, leftX - sideOffsetX, leftY - sideOffsetY)
    love.graphics.line(rightX, rightY, rightX - sideOffsetX, rightY - sideOffsetY)

    -- Draw Items (Temp Test)
    for _, item in ipairs(items) do
        local itemX, itemY = item.body:getPosition()
        love.graphics.push()
        love.graphics.translate(itemX, itemY)
        love.graphics.rotate(item.body:getAngle())
        love.graphics.setColor(1, 0.8, 0.35)
        love.graphics.rectangle("fill", -item.w * 0.5, -item.h * 0.5, item.w, item.h)
        if item == nearbyItem then
            love.graphics.setColor(1, 1, 1)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", -item.w * 0.5 - 2, -item.h * 0.5 - 2, item.w + 4, item.h + 4)
        end
        love.graphics.pop()
    end
    love.graphics.setLineWidth(1)
end

return Game
