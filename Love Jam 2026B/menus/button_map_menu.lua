local options = {}

function options:enter()
    self.titleBackground = love.graphics.newImage("/assets/backgrounds/main_menu_placeholderbg.png") --short function for big image path

    self.buttonFont = love.graphics.newFont(
    "assets/fonts/Tiny5Duo-VariableFont_BLED,JITT,ROND,wdth,wght.ttf",
    24
    )

    self.buttons = {
        {
            text = "Exit",
            x = (screenWidth / 2) - 100,
            y = 650,
            w = 200,
            h = 50
        }
    }
end

local function isMouseOver(button)
    local mx, my = love.mouse.getPosition() --finds the mouse position

    return mx > button.x  --checks if mouse is inside the button
        and mx < button.x + button.w
        and my > button.y
        and my < button.y + button.h
end

function options:draw()
    local bgw = love.graphics.getWidth() / self.titleBackground:getWidth()
    local bgh = love.graphics.getHeight() / self.titleBackground:getHeight()

    love.graphics.draw(self.titleBackground, 0, 0, 0, bgw, bgh) --draw background

    for _, button in ipairs(self.buttons) do --iterates through the data table

        if isMouseOver(button) then --check if mouse is inside button and change button color
            love.graphics.setColor(0.5, 0.85, 0.2)
        else
            love.graphics.setColor(0.0, 0.7, 0.3)
        end
        
        love.graphics.rectangle( --draw rectangle for button
            "fill",
            button.x,
            button.y,
            button.w,
            button.h
        )

        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(self.buttonFont)
        love.graphics.printf(
            button.text,
            button.x,
            button.y + 10,
            button.w,
            "center"
        )
    end


    --im trying to make a ctrls viewer but its not wroking atp and irdk why :sob:
    --[[for _, c in ipairs(ctrls) do
        love.graphics.printf(
            ctrls[i].action .. ": " .. ctrls[i].keybind,
            screenWidth / 2,
            (i * 50) + 100,
            200,
            "center"
        )
    end]]

end

function options:mousepressed(x, y, button) --checks if the mouse is pressed on the button and what to do afterwards
    if button ~=1 then
        return
    end

    for _, b in ipairs(self.buttons) do
        if x > b.x
        and x < b.x + b.w
        and y > b.y
        and y < b.y + b.h then

            if b.text == "Exit" then
                LoadScene(require("menus/options_menu"))
                print("returning to options menu")
            end
        end
    end
end

return options