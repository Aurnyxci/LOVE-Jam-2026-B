local currentScene

function LoadScene(scene, ...)
    currentScene = scene
    local inGame = currentScene == require("game")
    love.mouse.setVisible(not inGame)
    love.mouse.setGrabbed(inGame)
    if currentScene.enter then currentScene.enter(currentScene, ...) end

end

function love.load()
    local json = require("libs.json") --loads json library
    ctrls = json.decode(love.filesystem.read("controls.json")) --loads ctrls json

    screenWidth = love.graphics.getWidth() --finds the height and width of the screen
    screenHeight = love.graphics.getHeight()

    buttonPressed = love.graphics.newImage("assets/sprites/buttons/buttonPressed.png")
    buttonUnpressed = love.graphics.newImage("assets/sprites/buttons/buttonUnpressed.png")

    mainFont = love.graphics.newFont( --main font load
    "assets/fonts/Tiny5Duo-VariableFont_BLED,JITT,ROND,wdth,wght.ttf",
    24
    )

    love.graphics.setDefaultFilter("nearest","nearest")
    particles = require("particles")
    LoadScene(require("menus/main_menu")) --loads the main menu

end

function love.update(dt)
    particles:update(dt)
    love.mouse.setVisible(false)
    if currentScene.update then currentScene.update(currentScene, dt) end

end

function love.draw()
    if currentScene.draw then currentScene.draw(currentScene) end

end

function love.keypressed(key)
    if key == ctrls[5].keybind then LoadScene(require("menus/main_menu")) return end
    if key == ctrls[6].keybind then love.event.quit("restart") return end
    if currentScene.keypressed then currentScene.keypressed(currentScene,key) end

end

function love.mousepressed(x, y, button)
    if currentScene.mousepressed then
        currentScene:mousepressed(x, y, button)
    end
end