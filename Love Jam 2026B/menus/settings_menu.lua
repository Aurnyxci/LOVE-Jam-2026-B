local settings = {}

function settings:enter()
    self.titleBackground = love.graphics.newImage("/assets/backgrounds/main_menu_placeholderbg.png") --short function for big image path

    self.buttonFont = love.graphics.newFont(
    "assets/fonts/Tiny5Duo-VariableFont_BLED,JITT,ROND,wdth,wght.ttf",
    24
)

    local screenWidth = love.graphics.getWidth()

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

function settings:draw()
    love.graphics.draw(self.titleBackground, 0, 0) --draw background

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
        love.graphics.setFont(self.buttonFont)
        love.graphics.printf(
            button.text, --the text
            button.x, --the x coordinate
            button.y + 10, --the y coordinate
            button.w, --the width
            "center" --CENTER THE TEXT :D
        )
    end
end

function settings:mousepressed(x, y, button)
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
            end
        end
    end
end

return settings