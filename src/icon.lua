-- The game's icon: a neon "ND" monogram on the dark backdrop, drawn in code
-- like everything else. main.lua uses it for the window/taskbar icon, and the
-- release build renders the same drawing into the exe's .ico, so the two can
-- never drift apart.
local Icon = {}

local BACKDROP = { 0.05, 0.05, 0.1 }
local NEON     = { 0, 1, 0.85 }
local CORE     = { 0.8, 1, 0.97 }

-- both letters as polylines on a 0..1 grid
local function letter_paths()
    local n = { 0.17, 0.70, 0.17, 0.30, 0.45, 0.70, 0.45, 0.30 }

    -- D: down the spine, along the top, round the bowl, back along the bottom
    local d = { 0.57, 0.70, 0.57, 0.30, 0.64, 0.30 }
    local steps = 24
    for i = 1, steps - 1 do
        local angle = -math.pi / 2 + math.pi * i / steps
        table.insert(d, 0.64 + math.cos(angle) * 0.20)
        table.insert(d, 0.50 + math.sin(angle) * 0.20)
    end
    table.insert(d, 0.64)
    table.insert(d, 0.70)
    table.insert(d, 0.57)
    table.insert(d, 0.70)

    return { n, d }
end

-- A polyline with round joints and ends: each segment as a plain line, plus a
-- disc at every vertex. Drawn opaque, so overlapping pieces never darken.
local function round_polyline(path, size, width)
    love.graphics.setLineWidth(width)
    love.graphics.setLineJoin("none")
    for i = 1, #path - 2, 2 do
        love.graphics.line(path[i] * size, path[i + 1] * size, path[i + 2] * size, path[i + 3] * size)
    end
    for i = 1, #path, 2 do
        love.graphics.circle("fill", path[i] * size, path[i + 1] * size, width / 2)
    end
end

-- the letters at one stroke width, as a solid white mask on its own canvas
local function stroke_mask(size, width)
    local mask = love.graphics.newCanvas(size, size, { msaa = 8 })
    love.graphics.setCanvas(mask)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(1, 1, 1, 1)
    for _, path in ipairs(letter_paths()) do
        round_polyline(path, size, width)
    end
    return mask
end

-- Renders the icon to ImageData, e.g. for love.window.setIcon.
function Icon.render(size)
    love.graphics.push("all")
    love.graphics.origin()

    local stroke = size * 0.075
    -- widest and faintest first, building a soft glow up to the solid tube
    local layers = {}
    for i = 1, 8 do
        local t = (i - 1) / 7 -- 0 = outermost glow, 1 = just outside the tube
        table.insert(layers, { width = stroke * (3.6 - 2.3 * t), color = NEON, alpha = 0.035 + 0.05 * t })
    end
    table.insert(layers, { width = stroke, color = NEON, alpha = 1 })
    table.insert(layers, { width = stroke * 0.4, color = CORE, alpha = 1 })
    local masks = {}
    for i, layer in ipairs(layers) do
        masks[i] = stroke_mask(size, layer.width)
    end

    local canvas = love.graphics.newCanvas(size, size, { msaa = 8 })
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)

    local radius = size * 0.2
    love.graphics.setColor(BACKDROP)
    love.graphics.rectangle("fill", 0, 0, size, size, radius, radius, 48)

    local inset = size * 0.04
    love.graphics.setLineWidth(size * 0.03)
    love.graphics.setLineJoin("miter")
    love.graphics.setColor(NEON[1], NEON[2], NEON[3], 0.35)
    love.graphics.rectangle("line", inset, inset, size - inset * 2, size - inset * 2, radius * 0.8, radius * 0.8, 48)

    -- a canvas holds premultiplied color, so its soft edges would be darkened
    -- twice under normal alpha blending; premultiplied blending (with the
    -- tint premultiplied to match) keeps them clean
    love.graphics.setBlendMode("alpha", "premultiplied")
    for i, layer in ipairs(layers) do
        local c, a = layer.color, layer.alpha
        love.graphics.setColor(c[1] * a, c[2] * a, c[3] * a, a)
        love.graphics.draw(masks[i])
    end

    love.graphics.pop()
    return canvas:newImageData()
end

return Icon
