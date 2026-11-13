local menu = {}

function menu:enter()
    self.titleBackground = love.graphics.newImage("/assets/backgrounds/main_menu_placeholderbg.png") --short function for big image path

    self.buttons = {
        {
            text = "Start Game",  --start game button data
            x = (screenWidth / 2) - 100, --screenwidth with half of the button's width taken off
            y = 200,
            w = 200,
            h = 50
        },
        {
            text = "Options",
            x = (screenWidth / 2) - 100,
            y = 300,
            w = 200,
            h = 50
        },
        {
            text = "Quit",  --quit button data
            x = (screenWidth / 2) - 100,
            y = 400,
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

function menu:draw()
    local bgw = love.graphics.getWidth() / self.titleBackground:getWidth()
    local bgh = love.graphics.getHeight() / self.titleBackground:getHeight()
    
    love.graphics.draw(self.titleBackground, 0, 0, 0, bgw, bgh) --draw background

    for _, button in ipairs(self.buttons) do --iterates through the data table

        if isMouseOver(button) then --check if mouse is inside button and change button color
            love.graphics.setColor(0.5, 0.85, 0.2)
        else
            love.graphics.setColor(0.0, 0.7, 0.3)
        end
        
        love.graphics.rectangle( --draw rectangle
            "fill", -- mode
            button.x,  --button x pos
            button.y,  --button y pos
            button.w,  --button width
            button.h  --button height
        )

        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(mainFont)
        love.graphics.printf(
            button.text, --sets the text it would be using
            button.x, --the x coordinate
            button.y + 10, --the y coordinate
            button.w, --the width
            "center" --CENTER THE TEXT :D
        )
    end
end

function menu:mousepressed(x, y, button) --checks if the mouse is pressed on the button and what to do afterwards
    if button ~=1 then
        return
    end

    for _, b in ipairs(self.buttons) do
        if x > b.x
        and x < b.x + b.w
        and y > b.y
        and y < b.y + b.h then

            if b.text == "Start Game" then --checks if the button starts the game so it starts
                LoadScene(require("game"))
                print("starting game")

            elseif b.text == "Options" then
                print("opening settings")
                LoadScene(require("menus/options_menu"))

            elseif b.text == "Quit" then --checks if the button is quit so then it quits
                print("quitting")
                love.event.quit()
            end
        end
    end
end

return menu