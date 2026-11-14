local options = {}

function options:enter()
    self.titleBackground = love.graphics.newImage("/assets/backgrounds/main_menu_placeholderbg.png") --short function for big image path

    local setButtonType = buttonUnpressed

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
    mx, my = love.mouse.getPosition() --finds the mouse position

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
            setButtonType = buttonPressed
        else
            setButtonType = buttonUnpressed
        end

        love.graphics.draw(
            setButtonType,
            button.x,
            button.y
        )

        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(mainFont)
        love.graphics.printf(
            button.text,
            button.x,
            button.y + 10,
            button.w,
            "center"
        )
    end

    local i = 1

    for _, c in ipairs(ctrls) do
        love.graphics.setColor(0.4, 0.4, 0.4)
        love.graphics.printf(
            ctrls[i].action .. ": " .. ctrls[i].keybind,
            (screenWidth / 2) - ((screenWidth / 2) / 2),
            (i * 50) + 100,
            (screenWidth / 2),
            "center"
        )
        i = i + 1
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(mmp, mx, my)

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