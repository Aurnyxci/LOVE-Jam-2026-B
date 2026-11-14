local particles = {}

local function yellowJellySplat1()
    local yjs1IMAGE = love.graphics.newImage("assets/sprites/particles/yellowJellySplat1.png")
    yjs1 = love.graphics.newParticleSystem(yjs1IMAGE)

    yjs1:setParticleLifetime(0.5, 1.5)
    yjs1:setEmissionRate(100)
    yjs1:setSizes(3, 0)
    yjs1:setLinearAcceleration(-50, 50, -50, 50)
    yjs1:setSpeed(-50, 75)
    yjs1:setColors(
        1, 1, 0, 1,   -- yellow
        1, 0, 0, 0    -- red, fade out
    )
end

local function menuMouseParticles()
    local mmpIMAGE = love.graphics.newImage("assets/sprites/particles/menuMouseParticles.png")
    mmp = love.graphics.newParticleSystem(mmpIMAGE)

    mmp:setParticleLifetime(0.5, 1.5)
    mmp:setEmissionRate(100)
    mmp:setSizes(1.5, 0)
    mmp:setLinearAcceleration(-50, 50, -50, 50)
    mmp:setSpeed(-50, 75)
    mmp:setColors(
        1, 1, 1, 1,   -- white
        0, 0, 0, 0    -- black, fade out
    )
end

function particles:enter()
    yellowJellySplat1()
    menuMouseParticles()
end

function particles:update(dt)
    yjs1:update(dt)
    mmp:update(dt)
end



return particles