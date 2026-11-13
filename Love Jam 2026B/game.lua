local Game = {}

-- We mainly use playerBody:setLinearVelocity() to change player's velocity
-- It is Love Engine's Box2D function of the linear velocity of a rigidbody object
local player = {
    x = 320,
    y = 248,
    w = 64,
    h = 128,
    isOnGround = false,
    scaleX = 1,
    scaleY = 1,
    squash = 1,
    squashV = 0,
    lastMoveX = 0,
    facing = 1
}

-- Temp Platforms
local platforms = {
    { -- Temp Ground
        x = 0,
        y = (love.graphics.getWidth())/2+16,
        w = love.graphics.getWidth(),
        h = 64,
        tag = "ground"
    },
    { -- Temp Left Wall
        x = 0,
        y = 0,
        w = 64,
        h = love.graphics.getHeight()
    },
    { -- Temp Right Wall
        x = love.graphics.getWidth()-64,
        y = 0,
        w = 64,
        h = love.graphics.getHeight()
    },
    { -- Temp Ceiling
        x = 0,
        y = 0,
        w = love.graphics.getWidth(),
        h = 64
    },
}

-- Temp Tray
local tray = {
    halfW = 64, 
    gap = 8, 
    offset = 0, 
    x = 336, 
    y = 288,
    vx = 0, 
    vy = 0, 
    tilt = 0, 
    extend = 16
}

-- Temp Items
local items = {
    {
        x = 480, 
        y = 524, 
        w = 45, 
        h = 30
    },
    {
        x = 700, 
        y = 524, 
        w = 45, 
        h = 30
    }
}

-- Physics World (Box2D) from Love Engine
local world
local playerBody
local trayBody
-- check if can pick up
local nearbyItem

-- The player is assembled from several layered sprites (body, legs, head)
local playerSprites
local itemSprite
-- Left and right arm sprites with their own shoulder(anchor)/hand positions
local armLSprite
local armRSprite
local ARM_L_ANCHOR_X, ARM_L_ANCHOR_Y = 37, 41
local ARM_L_HAND_X, ARM_L_HAND_Y = 14, 6
local ARM_R_ANCHOR_X, ARM_R_ANCHOR_Y = 2, 41
local ARM_R_HAND_X, ARM_R_HAND_Y = 27, 6
local traySprite

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

local function drawArm(sprite, anchorX, anchorY, handX, handY, startX, startY, endX, endY)
    local dx = endX - startX
    local dy = endY - startY
    local armLength = math.sqrt((handX - anchorX) ^ 2 + (handY - anchorY) ^ 2)
    local stretch = math.sqrt(dx * dx + dy * dy) / armLength
    local width = 1 + (stretch - 1) * 0.2
    local handAngle = math.atan2(
        (handY - anchorY) * stretch,
        (handX - anchorX) * width
    )

    love.graphics.draw(sprite, startX, startY, math.atan2(dy, dx) - handAngle, width, stretch, anchorX, anchorY)
end

local function drawArms()
    love.graphics.setColor(1, 1, 1)

    local leftX, leftY, rightX, rightY = trayEnds()

    -- shoulders follow the body scale
    local shoulderX = player.x + player.w * 0.5
    local shoulderY = player.y + player.h - 81 * player.scaleY

    drawArm(armLSprite, ARM_L_ANCHOR_X, ARM_L_ANCHOR_Y, ARM_L_HAND_X, ARM_L_HAND_Y, shoulderX - 7 * player.scaleX, shoulderY, leftX, leftY)
    drawArm(armRSprite, ARM_R_ANCHOR_X, ARM_R_ANCHOR_Y, ARM_R_HAND_X, ARM_R_HAND_Y, shoulderX + 7 * player.scaleX, shoulderY, rightX, rightY)
end

function Game.enter(self)
    player.x, player.y = 320, 248
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

    -- Tray Physics, collider matches the flat plate sprite
    trayBody = love.physics.newBody(world, tray.x, player.y - tray.gap, "kinematic")
    local trayFixture = love.physics.newFixture(
        trayBody,
        love.physics.newRectangleShape(tray.halfW * 2, 8)
    )
    trayFixture:setFriction(1.5)
    trayFixture:setGroupIndex(-1)

    -- Items Physics
    for _, item in ipairs(items) do
        item.body = love.physics.newBody(
            world,
            item.x + item.w * 0.5,
            item.y + item.h * 0.5,
            "dynamic"
        )
        item.body:setLinearDamping(2)
        -- keep the jelly upright, only slides instead of rolling
        item.body:setFixedRotation(true)
        item.fixture = love.physics.newFixture(
            item.body,
            -- trapezoid fitted to the jelly sprite -> wide bottom, narrower top
            love.physics.newPolygonShape(-18, 15, 18, 15, 13.5, -15, -13.5, -15)
        )
        item.fixture:setFriction(1.5)
        item.fixture:setRestitution(0.1)

        item.squash = 1
        item.squashV = 0
        item.lastVy = 0
    end

    -- Player Sprites, the layered images share the same 96x128 canvas so drawing them in order
    -- Don't draw arms here because they are drawn as soft arms following the tray
    playerSprites = {}
    for _, partName in ipairs({
        "1-body",
        "2-right_leg",
        "3-left_leg",
        "6-head"
    }) do
        table.insert(playerSprites, love.graphics.newImage("assets/sprites/layered/" .. partName .. ".png"))
    end

    -- Arms
    armLSprite = love.graphics.newImage("assets/sprites/unique/armL_rev01.png")
    armRSprite = love.graphics.newImage("assets/sprites/unique/armR_rev01.png")

    -- Tray
    traySprite = love.graphics.newImage("assets/sprites/unique/plate_rev01.png")

    -- Item
    itemSprite = love.graphics.newImage("assets/sprites/unique/7-jelly.png")
end

function Game.update(self, dt)
    -- Player Input
    local speed = 320
    local moveX = 0
    if love.keyboard.isDown(ctrls[2].keybind) then
        moveX = moveX + speed
    end
    if love.keyboard.isDown(ctrls[1].keybind) then
        moveX = moveX - speed
    end

    -- face the walking direction
    if moveX ~= 0 then
        player.facing = moveX > 0 and 1 or -1
    end

    -- keep our horizontal velocity, and use engine's rigidbody physics velocity(for gravity)
    local _, currentVy = playerBody:getLinearVelocity()
    playerBody:setLinearVelocity(moveX, currentVy)

    -- soft body -> starting or stopping gives the body an impulse, then the spring wobbles it back to its normal shape
    if moveX ~= player.lastMoveX then
        player.squashV = player.squashV - (moveX - player.lastMoveX) * 0.008
        player.lastMoveX = moveX
    end

    player.squashV = player.squashV + ((1 - player.squash) * 300 - player.squashV * 12) * dt
    player.squash = player.squash + player.squashV * dt
    player.scaleX = 1 + (1 - player.squash) * 0.7
    player.scaleY = player.squash

    world:update(dt)

    -- player's box2D position is the center of the rectangle, but player's position is the top-left corner, convert it here
    local bodyX, bodyY = playerBody:getPosition()
    player.x = bodyX - player.w * 0.5
    player.y = bodyY - player.h * 0.5

    local grounded = isGrounded()
    if grounded and not player.isOnGround and currentVy > 100 then
        tray.vy = tray.vy + currentVy * 2
        -- squashes the body when landing
        player.squashV = player.squashV - math.min(currentVy, 480) * 0.01
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

    -- Items soft body -> landings squash the jelly, then the spring wobbles it back
    for _, item in ipairs(items) do
        local _, itemVy = item.body:getLinearVelocity()
        -- squashes the jelly when landing
        if item.lastVy > 40 and itemVy < item.lastVy then
            item.squashV = item.squashV - math.min(item.lastVy - itemVy, 480) * 0.01
        end
        item.lastVy = itemVy

        item.squashV = item.squashV + ((1 - item.squash) * 300 - item.squashV * 12) * dt
        item.squash = item.squash + item.squashV * dt
    end

    -- Find the closest item within pickup range
    nearbyItem = nil
    local closestDistance = 100 * 100
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
end

function Game.keypressed(self, key)     
    if key == ctrls[3].keybind then
        if player.isOnGround then
            -- Jump
            local currentVx = playerBody:getLinearVelocity()
            playerBody:setLinearVelocity(currentVx, -320)
            player.isOnGround = false
            tray.vy = tray.vy + 130
            -- stretches the body when jumping
            player.squashV = player.squashV + 2.5
        end
    end
    -- pick up item
    if key == ctrls[4].keybind and nearbyItem then
        local trayY = tray.y
        local itemOffset = 4 + nearbyItem.h * 0.5
        local itemX = tray.x - math.sin(tray.tilt) * itemOffset
        local itemY = trayY - math.cos(tray.tilt) * itemOffset
        nearbyItem.body:setPosition(itemX, itemY)
        nearbyItem.body:setLinearVelocity(0, 0)
        nearbyItem.body:setAwake(true)
    end
end

function Game.draw(self)
    -- Draw Temp Colour of Background
    love.graphics.clear(0.13, 0.84, 0.78)

    -- Draw Platforms (Temp Test)
    love.graphics.setColor(0.00, 0.58, 0.91)
    for _, platform in ipairs(platforms) do
        love.graphics.rectangle("fill", platform.x, platform.y, platform.w, platform.h)
    end

    -- Draw Tray (behind hands)
    love.graphics.setColor(1, 1, 1)
    local s = (tray.halfW * 2 + tray.extend * 2) / traySprite:getWidth()
    love.graphics.draw(traySprite, tray.x, tray.y, -tray.tilt, s, s, traySprite:getWidth() * 0.5, traySprite:getHeight() * 0.5)

    drawArms()

    -- Draw Player
    -- The layered canvas is 96x128 and every part shares it, so the whole character is drawn by stacking the images in order
    -- Keep the skates on the player's feet, and line up the middle of the body (x = 31 in the canvas) with the player's center
    love.graphics.setColor(1, 1, 1)

    -- draw from the feet, so the character squashes and stretches on the ground
    for _, sprite in ipairs(playerSprites) do
        love.graphics.draw(sprite, player.x + player.w * 0.5, player.y + player.h, 0, player.scaleX * player.facing, player.scaleY, 31, 128)
    end

    -- Draw Items
    for _, item in ipairs(items) do
        local itemX, itemY = item.body:getPosition()
        love.graphics.push()
        love.graphics.translate(itemX, itemY)
        love.graphics.setColor(1, 1, 1)
        -- scale around the sprite's bottom, keep the jelly stays on the ground
        love.graphics.draw(itemSprite, 0, 15, 0, 1.5 * (1 + (1 - item.squash) * 0.7), 1.5 * item.squash, itemSprite:getWidth() * 0.5, itemSprite:getHeight())
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
