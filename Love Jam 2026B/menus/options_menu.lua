local options = {}

musicOrSound = true

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
        },
        {
            text = "Button Map",
            x = (screenWidth / 2) - 250,
            y = 100,
            w = 200,
            h = 50
        },
        {
            text = "Sound: ",
            x = (screenWidth / 2) + 50,
            y = 100,
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
            setButtonType = buttonPressed
        else
            setButtonType = buttonUnpressed
        end
        love.graphics.draw(
            setButtonType,
            button.x,
            button.y
        )

        love.graphics.setFont(mainFont)

        if button.text == "Sound: " then
            if musicOrSound then
                love.graphics.setColor(1, 1, 1)
                love.graphics.printf(
                    button.text .. "on",
                    button.x,
                    button.y + 10,
                    button.w,
                    "center"
                )
            else
                love.graphics.setColor(1, 1, 1)
                love.graphics.printf(
                    button.text .. "off",
                    button.x,
                    button.y + 10,
                    button.w,
                    "center"
                )
            end
        else
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(
                button.text,
                button.x,
                button.y + 10,
                button.w,
                "center"
        )
        end
    end
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
                LoadScene(require("menus/main_menu"))
                print("returning to main menu")
            elseif b.text == "Button Map" then
                LoadScene(require("menus/button_map_menu"))
                print("going to button map menu")
            elseif b.text == "Sound: " then
                if musicOrSound then
                    musicOrSound = false
                else
                    musicOrSound = true
                end
            end
        end
    end
end

return options