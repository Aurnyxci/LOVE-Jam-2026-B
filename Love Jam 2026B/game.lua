local Game = {}

local tmx = require("libs.tmx")
local Levels = require("level")

local DEFAULT_LEVEL = "maps/tmx/level_0.tmx"

local function levelFile(name)
    if not name then return DEFAULT_LEVEL end
    if name:find("%.tmx$") then return name end
    return "maps/tmx/" .. name .. ".tmx"
end

-- The exit is like a bucket now
local BUCKET_WALL = 8 -- temp bucket look

-- We mainly use playerBody:setLinearVelocity() to change player's velocity
-- It is Love Engine's Box2D function of the linear velocity of a rigidbody object
local JUMP_VELOCITY = 320

-- The jelly works like a spring pad, it only bounces the player when stepped on from above and it can still be pushed left/right
local ITEM_BOUNCE_SQUASH = 0.5
local ITEM_BOUNCE_SQUEEZE = 0.15
local ITEM_HEIGHT_VISUAL = 30
local ITEM_BOUNCE_VELOCITY = JUMP_VELOCITY * math.sqrt(4)

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
    sink = 0,
    lastMoveX = 0,
    facing = 1
}

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

local items = {}

-- Physics World (Box2D) from Love Engine
local world
local playerBody
local playerFixture
local trayBody
local trayFixture
-- current level's solid fixtures
-- Every rigidbody things is in solids.
local solids
local map
local exit
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

-- Is player on something(like ground)
local function isGrounded()
    for _, contact in ipairs(world:getContacts()) do
        if contact:isTouching() then
            local fixtureA, fixtureB = contact:getFixtures()

            local otherFixture
            if fixtureA:getBody() == playerBody then
                otherFixture = fixtureB
            elseif fixtureB:getBody() == playerBody then
                otherFixture = fixtureA
            end
            local solid = otherFixture and solids[otherFixture]
            if solid and player.y + player.h <= solid.y + 6 then
                return true
            end
        end
    end
    return false
end

-- The player must be standing on top of the jelly (not just touching its sides)
local function isStandingOnItem(item)
    for _, contact in ipairs(world:getContacts()) do
        if contact:isTouching() then
            local fixtureA, fixtureB = contact:getFixtures()

            local otherFixture
            if fixtureA == playerFixture then
                otherFixture = fixtureB
            elseif fixtureB == playerFixture then
                otherFixture = fixtureA
            end

            if otherFixture == item.fixture then
                return player.y + player.h <= select(2, item.body:getPosition()) - 2
            end
        end
    end
    return false
end

-- The player is above the jelly (used for the launch, since the soft jelly can
-- physically pop the player off its surface during the compression).
-- The x range covers the whole body width, so standing on the jelly's edge still counts.
local function isOnItemTop(item)
    local itemX, itemY = item.body:getPosition()
    return math.abs(player.x + player.w * 0.5 - itemX) <= (item.w + player.w) * 0.5 - 8
        and player.y + player.h <= itemY - 2
        and player.y + player.h >= itemY - 40
end

-- Another jelly is above this one (position only: the soft contact can pop it up a
-- few pixels during the compression, which must not cancel the launch)
local function isItemAbove(bottom, top)
    local bottomX, bottomY = bottom.body:getPosition()
    local topX, topY = top.body:getPosition()
    return math.abs(topX - bottomX) <= (bottom.w + top.w) * 0.5 - 8
        and topY + top.h * 0.5 <= bottomY - 2
        and topY + top.h * 0.5 >= bottomY - 40
end

-- Another jelly resting on top of this one -> jellies can bounce each other too
local function isItemOnItemTop(bottom, top)
    if not isItemAbove(bottom, top) then return false end
    for _, contact in ipairs(world:getContacts()) do
        if contact:isTouching() then
            local a, b = contact:getFixtures()
            if (a == bottom.fixture and b == top.fixture)
                or (a == top.fixture and b == bottom.fixture) then
                return true
            end
        end
    end
    return false
end

local function releaseHeldItems()
    for _, item in ipairs(items) do
        if item.held then
            item.held = false
            item.flying = true
            -- keeps moving with the player and gets an extra push sideways
            item.body:setLinearVelocity(
                playerBody:getLinearVelocity() * 1.5,
                select(2, playerBody:getLinearVelocity())
            )
        end
    end
end

-- Returns true when enough of them have been collected
local function collectItemsInExit()
    if not exit then return false end
    for index = #items, 1, -1 do
        local itemX, itemY = items[index].body:getPosition()
        if itemX > exit.x and itemX < exit.x + exit.w
            and itemY > exit.y and itemY < exit.y + exit.h then
            items[index].body:destroy()
            if items[index] == nearbyItem then nearbyItem = nil end
            table.remove(items, index)
            exit.collected = exit.collected + 1
        end
    end

    return exit.next ~= nil and exit.collected >= exit.required
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

local function drawArms(offsetY)
    love.graphics.setColor(1, 1, 1)

    local leftX, leftY, rightX, rightY = trayEnds()
    leftY = leftY + offsetY
    rightY = rightY + offsetY

    -- shoulders follow the body scale
    local shoulderX = player.x + player.w * 0.5
    local shoulderY = player.y + player.h - 81 * player.scaleY + offsetY

    drawArm(armLSprite, ARM_L_ANCHOR_X, ARM_L_ANCHOR_Y, ARM_L_HAND_X, ARM_L_HAND_Y, shoulderX - 7 * player.scaleX, shoulderY, leftX, leftY)
    drawArm(armRSprite, ARM_R_ANCHOR_X, ARM_R_ANCHOR_Y, ARM_R_HAND_X, ARM_R_HAND_Y, shoulderX + 7 * player.scaleX, shoulderY, rightX, rightY)
end

function Game.enter(self, level)
    map = tmx.load(levelFile(level))

    -- Level setup comes from level.lua alone
    local config = Levels[map.path:match("([^/]+)%.tmx$")] or {}

    items = {}
    for _, entry in ipairs(config.items or {}) do
        items[#items + 1] = {
            x = entry.x,
            y = entry.y,
            w = entry.w or 45,
            h = entry.h or 30,
        }
    end

    exit = nil
    if config.exit then
        exit = {
            x = config.exit.x,
            y = config.exit.y,
            w = config.exit.w or 64,
            h = config.exit.h or 64,
            -- how many jellies have to be thrown in
            required = config.exit.required or 1,
            collected = 0,
            next = config.next and levelFile(config.next),
        }
    end

    player.x = config.spawn and config.spawn.x or 320
    player.y = config.spawn and config.spawn.y or 248
    player.isOnGround = false
    player.sink = 0
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

    playerFixture = love.physics.newFixture(playerBody, love.physics.newRectangleShape(player.w, player.h))
    playerFixture:setFriction(0)
    playerFixture:setGroupIndex(-1)

    -- Solid Settings, every solid rectangle becomes a static body
    solids = {}
    local function addSolid(rect)
        local body = love.physics.newBody(world, rect.x + rect.w * 0.5, rect.y + rect.h * 0.5, "static")
        local fixture = love.physics.newFixture(body, love.physics.newRectangleShape(rect.w, rect.h))
        fixture:setFriction(1.5)
        solids[fixture] = rect
    end

    for _, rect in ipairs(map.collision) do addSolid(rect) end

    -- Tray Physics, collider matches the flat plate sprite
    trayBody = love.physics.newBody(world, tray.x, player.y - tray.gap, "kinematic")
    trayFixture = love.physics.newFixture(
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
        item.bounceTimer = 0
        item.bounceCooldown = 0
        item.isBouncing = false
        item.bounceTarget = nil
        item.sink = 0
        item.held = false
        item.flying = false
        item.holdOffset = 0
    end

    -- Player Sprites, the layered images share the same 96x128 canvas so drawing them in order
    -- Don't draw arms here because they are drawn as soft arms following the tray
    -- Loaded once and reused when switching levels
    if not playerSprites then
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

    -- >>>>>>>> PARTICLE HOOK: init <<<<<<<<
    -- Create the particle systems here -> particles:enter()
    -- Game.enter runs again on every level switch, so you may need wrap the creation in "if not ... then" (like the sprites above) to avoid rebuilding them.
end

function Game.update(self, dt)
    -- >>>>>>>> PARTICLE HOOK -> particles update
    -- set a particles:update(dt) or something.

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

    -- >>>>>>>> PARTICLE HOOK -> Player Movement <<<<<<<<
    -- Spawn walking particles here.
    -- some values you may used explain:
    -- moveX -> current horizontal input: -320 left / 0 idle / 320 right
    -- player.facing -> facing direction: 1 right / -1 left
    -- feet center:playerCenterX, player.y + player.h
    -- Example: if moveX ~= 0 then particles:walk(playerCenterX, player.y + player.h, player.facing) end

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
        local onGround = false
        local onTray = false
        for _, contact in ipairs(world:getContacts()) do
            if contact:isTouching() then
                local fixtureA, fixtureB = contact:getFixtures()

                local otherFixture
                if fixtureA == item.fixture then
                    otherFixture = fixtureB
                elseif fixtureB == item.fixture then
                    otherFixture = fixtureA
                end

                if solids[otherFixture] then
                    onGround = true
                    -- lower friction so a push makes the jelly slide a little before it stops
                    contact:setFriction(0.35)
                elseif otherFixture == trayFixture then
                    onTray = true
                end
            end
        end

        local itemX, itemY = item.body:getPosition()
        local itemVx, itemVy = item.body:getLinearVelocity()

        item.onGround = onGround

        if item.held then
            -- stuck to the tray where it sits: no left/right movement of its own,
            -- but vertical physics and the spring stay untouched
            item.body:setPosition(tray.x + item.holdOffset, itemY)
            item.body:setLinearVelocity(0, itemVy)
        elseif onTray and itemVy >= 0 then
            -- anything that comes to rest on the tray sticks to it
            item.held = true
            item.flying = false
            item.holdOffset = itemX - tray.x
            item.body:setLinearVelocity(0, itemVy)
        else
            -- keeps sliding on the ground, the tray slows it down faster.
            if onGround then item.flying = false end
            if not item.flying then
                local glide = 0.2
                if onTray then
                    glide = 2.5
                elseif onGround then
                    glide = 0.6
                end
                item.body:setLinearVelocity(itemVx * math.exp(-glide * dt), itemVy)
            end
        end

        local _, itemVy = item.body:getLinearVelocity()
        -- squashes the jelly when landing
        if item.lastVy > 40 and itemVy < item.lastVy then
            item.squashV = item.squashV - math.min(item.lastVy - itemVy, 480) * 0.01
        end
        item.lastVy = itemVy

        item.squashV = item.squashV + ((1 - item.squash) * 300 - item.squashV * 12) * dt
        item.squash = item.squash + item.squashV * dt

        -- The jelly is like a spring pad
        if item.bounceCooldown > 0 then
            item.bounceCooldown = item.bounceCooldown - dt
        end

        if item.isBouncing then
            item.bounceTimer = item.bounceTimer - dt
            -- squash the jelly down (squashV is parked so the spring does not fight it)
            item.squash = 1 - (1 - ITEM_BOUNCE_SQUASH)
                * (1 - math.max(item.bounceTimer, 0) / ITEM_BOUNCE_SQUEEZE)
            item.squashV = 0

            local target = item.bounceTarget
            if target == "player" then
                -- the player sinks with the compressed jelly
                player.sink = (1 - item.squash) * ITEM_HEIGHT_VISUAL
                -- keep them seated, otherwise the soft contact pops them off and the launch would be skipped
                if isOnItemTop(item) then
                    local playerVx, playerVy = playerBody:getLinearVelocity()
                    if playerVy < 0 then
                        playerBody:setLinearVelocity(playerVx, 0)
                    end
                end
            elseif target and isItemAbove(item, target) then
                -- the jelly on top sinks along with the one below it
                target.sink = (1 - item.squash) * ITEM_HEIGHT_VISUAL
                local targetVx, targetVy = target.body:getLinearVelocity()
                if targetVy < 0 then
                    target.body:setLinearVelocity(targetVx, 0)
                end
            end

            if item.bounceTimer <= 0 then
                item.isBouncing = false
                item.bounceCooldown = 0.4
                -- release the spring, so the jelly wobbles back up into a stretch
                item.squashV = 14

                if target == "player" then
                    player.sink = 0
                    if isOnItemTop(item) then
                        playerBody:setLinearVelocity(playerBody:getLinearVelocity(), -ITEM_BOUNCE_VELOCITY)
                        -- stretches as the launch pushes the player up
                        player.squashV = player.squashV + 2.5
                        releaseHeldItems()

                        -- >>>>>>>> PARTICLE HOOK -> When player jump to the jelly <<<<<<<<
                        -- Center position of the jelly: item.body:getPosition()
                        -- Jelly's visual height：ITEM_HEIGHT_VISUAL，player's feet：player.y + player.h
                    end
                elseif target then
                    target.sink = 0
                    if isItemAbove(item, target) then
                        target.body:setLinearVelocity(target.body:getLinearVelocity(), -ITEM_BOUNCE_VELOCITY)
                        target.squashV = target.squashV + 4

                        -- >>>>>>>> PARTICLE HOOK -> When a jelly jump to another jelly <<<<<<<<
                        -- above has just applied an upward velocity to the target, so you can set the particles here
                        -- target.body:getPosition()(the one who jumped)
                    end
                end
                item.bounceTarget = nil
            end
        elseif item.bounceCooldown <= 0 then
            -- the player has priority, otherwise another jelly can be bounced on top of this one
            local target
            if isStandingOnItem(item) then
                target = "player"
            else
                for _, other in ipairs(items) do
                    if other ~= item and isItemOnItemTop(item, other) then
                        target = other
                        break
                    end
                end
            end

            if target then
                item.isBouncing = true
                item.bounceTimer = ITEM_BOUNCE_SQUEEZE
                item.bounceTarget = target

                -- >>>>>>>> PARTICLE HOOK -> Jump to Jelly <<<<<<<<
                -- You can set a trigger first when jelly is flattened, get its position:item.body:getPosition()
                -- And then after ITEM_BOUNCE_SQUEEZE seconds trigger again(the jelly bounce back)
                if target == "player" then
                    -- the player's weight pushes the jelly down before the launch
                    player.squashV = player.squashV - 1.2
                end
            end
        end
    end

    -- Find the closest item within pickup range
    nearbyItem = nil
    local closestDistance = 100*100
    for _, item in ipairs(items) do
        if item.onGround then
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

    -- Load Scene when collceting enough jellies
    if collectItemsInExit() then
        LoadScene(Game, exit.next)
    end
end

function Game.keypressed(self, key)     
    if key == ctrls[3].keybind then
        if player.isOnGround then
            -- Jump
            playerBody:setLinearVelocity(playerBody:getLinearVelocity(), -JUMP_VELOCITY)
            player.isOnGround = false
            tray.vy = tray.vy + 130
            -- stretches the body when jumping
            player.squashV = player.squashV + 2.5
            releaseHeldItems()

            -- >>>>>>>> PARTICLE HOOK -> Player Jump <<<<<<<<
            -- You can put jumping Particules here(green particules)
            -- Player feet's center position: player.x + player.w * 0.5, player.y + player.h

        end
    end
    -- when on the tray it sticks
    if key == ctrls[4].keybind and nearbyItem then
        local itemOffset = 4 + nearbyItem.h * 0.5
        local itemX = tray.x - math.sin(tray.tilt) * itemOffset
        local itemY = tray.y - math.cos(tray.tilt) * itemOffset
        nearbyItem.body:setPosition(itemX, itemY)
        nearbyItem.body:setLinearVelocity(0, 0)
        nearbyItem.body:setAwake(true)
        nearbyItem.held = true
        nearbyItem.flying = false
        nearbyItem.holdOffset = itemX - tray.x
    end
end

function Game.draw(self)
    -- Draw Temp Colour of Background
    love.graphics.clear(0.13, 0.84, 0.78)

    -- Draw the tile layers of the level
    tmx.draw(map)

    -- The exit and how many jellies are already inside
    if exit then
        love.graphics.setColor(0.45, 0.30, 0.18)
        love.graphics.rectangle("fill", exit.x, exit.y, BUCKET_WALL, exit.h)
        love.graphics.rectangle("fill", exit.x + exit.w - BUCKET_WALL, exit.y, BUCKET_WALL, exit.h)
        love.graphics.rectangle("fill", exit.x, exit.y + exit.h - BUCKET_WALL, exit.w, BUCKET_WALL)

        love.graphics.setColor(1, 1, 1)
        love.graphics.print(exit.collected .. "/" .. exit.required, exit.x, exit.y - 26, 0, 2, 2)
    end

    -- Draw Tray (behind hands)
    love.graphics.setColor(1, 1, 1)
    local s = (tray.halfW * 2 + tray.extend * 2) / traySprite:getWidth()
    love.graphics.draw(traySprite, tray.x, tray.y + player.sink, -tray.tilt, s, s, traySprite:getWidth() * 0.5, traySprite:getHeight() * 0.5)

    drawArms(player.sink)

    -- Draw Player

    for _, sprite in ipairs(playerSprites) do
        love.graphics.draw(sprite, player.x + player.w * 0.5, player.y + player.h + player.sink, 0, player.scaleX * player.facing, player.scaleY, 31, 128)
    end

    -- Draw Items
    for _, item in ipairs(items) do
        local itemX, itemY = item.body:getPosition()
        love.graphics.push()
        love.graphics.translate(itemX, itemY + item.sink)
        -- scale around the sprite's bottom, keep the jelly stays on the ground
        love.graphics.draw(itemSprite, 0, 15, 0, 1.5 * (1 + (1 - item.squash) * 0.7), 1.5 * item.squash, itemSprite:getWidth() * 0.5, itemSprite:getHeight())
        if item == nearbyItem then
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", -item.w * 0.5 - 2, -item.h * 0.5 - 2, item.w + 4, item.h + 4)
        end
        love.graphics.pop()
    end

    -- >>>>>>>> PARTICLE HOOK -> Draw particles Here <<<<<<<<
    -- particles:draw(), and to call in Game.update
end

return Game
