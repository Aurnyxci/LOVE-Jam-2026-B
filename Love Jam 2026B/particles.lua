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

local function fanWindUp()
    local fwuIMAGE = love.graphics.newImage("assets/sprites/particles/fanWindUp.png")
    local fwuAnim8Prep = anim8.newGrid(4, 4, fwuIMAGE:getWidth(), fwuIMAGE:getHeight())
    local fwuAnimation = fwuAnim8Prep('1-12', 1)
    fwu = love.graphics.newParticleSystem(fwuIMAGE, 100)

    fwu:setQuads(fwuAnimation)
    fwu:setParticleLifetime(3, 3)
    fwu:setEmissionRate(5)
    fwu:setSizes(10, 0)
    fwu:setLinearAcceleration(0, 0, 0, 0)
    fwu:setDirection(math.rad(270))
    fwu:setSpeed(95, 100)

end

local function menuTitleParticles()
    local mtpIMAGE = love.graphics.newImage("assets/sprites/particles/menuTitleParticles.png")
    mtp = love.graphics.newParticleSystem(mtpIMAGE)

    mtp:setParticleLifetime(0.5, 1.5)
    mtp:setEmissionRate(200)
    mtp:setSizes(1.5, 0)
    mtp:setLinearAcceleration(50, 50, 50, 50)
    mtp:setSpeed(-400, 400)
    mtp:setColors(
        1, 1, 1, 1,
        0.3, 0.3, 0.3, 0
    )
end

function particles:enter()
    yellowJellySplat1()
    menuMouseParticles()
    fanWindUp()
    menuTitleParticles()
end

function particles:update(dt)
    yjs1:update(dt)
    mmp:update(dt)
    fwu:update(dt)
    mtp:update(dt)
end



return particles