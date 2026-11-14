-- Per level setup. The map only provides tiles, everything else is set here.
local Levels = {}

Levels.level_0 = {
    spawn = { x = 320, y = 248 },

    items = {
        { x = 480, y = 520 },
        { x = 700, y = 520 },
    },

    exit = {
        x = 1000,
        y = 576,
        w = 128,
        h = 96,
        required = 2,
    },

    -- next level to load after the exit is filled (nil = stay on this level)
    next = "level_1",
}

return Levels
