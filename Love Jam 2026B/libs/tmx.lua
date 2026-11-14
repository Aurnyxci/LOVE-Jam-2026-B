-- Minimal Tiled (TMX) loader for Love2D
-- Supports: orthogonal maps, CSV tile layers (with or without CDATA),
-- inline / external TSX tilesets.
-- The loader is read-only: it only extracts what the game needs.

local TMX = {}

local imageCache = {}

-- ---------------------------------------------------------------------------
-- Tiny XML parser (enough for TMX files)
-- ---------------------------------------------------------------------------

local function decodeEntities(s)
    s = s:gsub("&quot;", '"'):gsub("&apos;", "'")
    s = s:gsub("&lt;", "<"):gsub("&gt;", ">")
    s = s:gsub("&#(%d+);", function(n) return string.char(tonumber(n)) end)
    return (s:gsub("&amp;", "&"))
end

local function parseAttributes(s)
    local attrs = {}
    for name, value in s:gmatch('([%w_:%-%.]+)%s*=%s*"([^"]*)"') do
        attrs[name] = decodeEntities(value)
    end
    return attrs
end

local function parseXML(xml)
    local root = { tag = "#root", attrs = {}, children = {}, text = "" }
    local stack = { root }
    local pos = 1

    while true do
        local open = xml:find("<", pos, true)
        if not open then break end

        if open > pos then
            local top = stack[#stack]
            top.text = top.text .. xml:sub(pos, open - 1)
        end

        if xml:sub(open, open + 3) == "<!--" then
            local close = xml:find("-->", open + 4, true)
            if not close then break end
            pos = close + 3
        else
            local close = xml:find(">", open, true)
            if not close then break end
            local inner = xml:sub(open + 1, close - 1)
            pos = close + 1

            if inner:sub(1, 1) == "?" then
                -- declaration / processing instruction
            elseif inner:sub(1, 1) == "/" then
                if #stack > 1 then table.remove(stack) end
            else
                local selfClosing = inner:sub(-1) == "/"
                if selfClosing then inner = inner:sub(1, -2) end

                local tag, attrText = inner:match("^([%w_:%-%.]+)%s*(.*)$")
                local node = {
                    tag = tag,
                    attrs = parseAttributes(attrText or ""),
                    children = {},
                    text = "",
                }
                local parent = stack[#stack]
                parent.children[#parent.children + 1] = node
                if not selfClosing then stack[#stack + 1] = node end
            end
        end
    end

    return root.children[1]
end

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function joinPath(dir, file)
    if file:match("^[/\\]") or file:match("^%a:") then return file end
    local path = dir == "" and file or dir .. "/" .. file

    -- Love only accepts paths inside the game folder, resolve "." and ".."
    local parts = {}
    for part in path:gmatch("[^/\\]+") do
        if part == ".." then
            if #parts > 0 then table.remove(parts) end
        elseif part ~= "." then
            parts[#parts + 1] = part
        end
    end
    return table.concat(parts, "/")
end

-- Tiled stores flip flags in the highest bits of the gid, strip them
local function cleanGid(gid)
    while gid >= 0x80000000 do gid = gid - 0x80000000 end
    return gid
end

local function readXML(path)
    local contents = love.filesystem.read(path)
    assert(contents, "TMX: cannot read " .. path)
    local root = parseXML(contents)
    assert(root, "TMX: empty file " .. path)
    return root
end

-- ---------------------------------------------------------------------------
-- Loading
-- ---------------------------------------------------------------------------

local function loadTileset(node, firstgid, dir)
    local tileset = {
        firstgid = tonumber(firstgid or node.attrs.firstgid) or 1,
        tileWidth = tonumber(node.attrs.tilewidth) or 16,
        tileHeight = tonumber(node.attrs.tileheight) or 16,
        columns = tonumber(node.attrs.columns) or 1,
        spacing = tonumber(node.attrs.spacing) or 0,
        margin = tonumber(node.attrs.margin) or 0,
        quads = {},
    }
    for _, child in ipairs(node.children) do
        if child.tag == "image" then
            local imagePath = joinPath(dir, child.attrs.source)
            -- tileset images are shared between levels
            imageCache[imagePath] = imageCache[imagePath] or love.graphics.newImage(imagePath)
            tileset.image = imageCache[imagePath]
        end
    end
    return tileset
end

local function parseLayerData(node, layerName)
    local dataNode
    for _, child in ipairs(node.children) do
        if child.tag == "data" then dataNode = child break end
    end
    assert(dataNode, "TMX: layer '" .. layerName .. "' has no data")

    local encoding = dataNode.attrs.encoding
    assert(encoding == "csv" or encoding == nil,
        "TMX: layer '" .. layerName .. "' uses unsupported encoding, please save the map as CSV")

    local text = (dataNode.text or ""):gsub("<!%[CDATA%[", ""):gsub("%]%]>", "")
    local data = {}
    for number in text:gmatch("(%-?%d+)") do
        data[#data + 1] = tonumber(number)
    end
    return data
end

-- Merge horizontal runs of solid tiles into rectangles so Box2D has few bodies
local function buildCollisionRects(map, layer)
    local rects = {}
    for y = 0, map.height - 1 do
        local x = 0
        while x < map.width do
            if cleanGid(layer.data[y * map.width + x + 1] or 0) > 0 then
                local start = x
                while x < map.width
                    and cleanGid(layer.data[y * map.width + x + 1] or 0) > 0 do
                    x = x + 1
                end
                rects[#rects + 1] = {
                    x = start * map.tileWidth,
                    y = y * map.tileHeight,
                    w = (x - start) * map.tileWidth,
                    h = map.tileHeight,
                }
            else
                x = x + 1
            end
        end
    end
    return rects
end

local function buildBatches(map, layer)
    if #map.tilesets == 0 then return end

    local function tilesetFor(gid)
        local found
        for _, tileset in ipairs(map.tilesets) do
            if gid >= tileset.firstgid then found = tileset end
        end
        return found
    end

    -- Count tiles per tileset first, a SpriteBatch needs its capacity up front
    local counts = {}
    for _, rawGid in ipairs(layer.data) do
        local gid = cleanGid(rawGid)
        if gid > 0 then
            local tileset = tilesetFor(gid)
            if tileset and tileset.image then
                counts[tileset] = (counts[tileset] or 0) + 1
            end
        end
    end

    layer.batches = {}
    for tileset, count in pairs(counts) do
        local batch = love.graphics.newSpriteBatch(tileset.image, count, "static")
        local imageWidth, imageHeight = tileset.image:getDimensions()

        for index, rawGid in ipairs(layer.data) do
            local gid = cleanGid(rawGid)
            if gid > 0 and tilesetFor(gid) == tileset then
                local id = gid - tileset.firstgid
                local quad = tileset.quads[id]
                if not quad then
                    local qx = tileset.margin + (id % tileset.columns) * (tileset.tileWidth + tileset.spacing)
                    local qy = tileset.margin + math.floor(id / tileset.columns) * (tileset.tileHeight + tileset.spacing)
                    quad = love.graphics.newQuad(qx, qy, tileset.tileWidth, tileset.tileHeight, imageWidth, imageHeight)
                    tileset.quads[id] = quad
                end

                local tileX = (index - 1) % map.width
                local tileY = math.floor((index - 1) / map.width)
                batch:add(quad, tileX * map.tileWidth, tileY * map.tileHeight)
            end
        end

        layer.batches[#layer.batches + 1] = batch
    end
end

function TMX.load(path)
    local root = readXML(path)
    assert(root.tag == "map", "TMX: " .. path .. " is not a map")

    local attrs = root.attrs
    local map = {
        path = path,
        dir = path:match("^(.*)/") or "",
        width = tonumber(attrs.width),
        height = tonumber(attrs.height),
        tileWidth = tonumber(attrs.tilewidth),
        tileHeight = tonumber(attrs.tileheight),
        layers = {},
        collision = {},
        tilesets = {},
    }

    for _, node in ipairs(root.children) do
        if node.tag == "tileset" then
            if node.attrs.source then
                local tsxPath = joinPath(map.dir, node.attrs.source)
                local tsx = readXML(tsxPath)
                map.tilesets[#map.tilesets + 1] =
                    loadTileset(tsx, node.attrs.firstgid, tsxPath:match("^(.*)/") or "")
            else
                map.tilesets[#map.tilesets + 1] = loadTileset(node, nil, map.dir)
            end

        elseif node.tag == "layer" then
            local layer = {
                name = node.attrs.name or "",
                visible = node.attrs.visible ~= "0",
            }
            layer.data = parseLayerData(node, layer.name)
            buildBatches(map, layer)
            map.layers[#map.layers + 1] = layer

            -- the layer named "collision" holds the solid tiles
            if layer.name:lower() == "collision" then
                local rects = buildCollisionRects(map, layer)
                for _, rect in ipairs(rects) do
                    map.collision[#map.collision + 1] = rect
                end
            end
        end
    end

    return map
end

function TMX.draw(map)
    for _, layer in ipairs(map.layers) do
        if layer.visible and layer.batches then
            love.graphics.setColor(1, 1, 1)
            for _, batch in ipairs(layer.batches) do
                love.graphics.draw(batch)
            end
        end
    end
end

return TMX
