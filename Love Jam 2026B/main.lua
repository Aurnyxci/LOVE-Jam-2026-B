local currentScene

function LoadScene(scene)
    currentScene = scene
    if currentScene.enter then currentScene.enter(currentScene) end

end

function love.load()
    love.graphics.setDefaultFilter("nearest","nearest")
    --LoadScene(require("menu"))
    LoadScene(require("game"))

end

function love.update(dt)
    if currentScene.update then currentScene.update(currentScene, dt) end

end

function love.draw()
    if currentScene.draw then currentScene.draw(currentScene) end

end

function love.keypressed(key)
    if key == "escape" then love.event.quit() return end
    if key == "f5"  then love.event.quit("restart") return end
    if currentScene.keypressed then currentScene.keypressed(currentScene,key) end

end