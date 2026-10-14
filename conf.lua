function love.conf(t)
    -- the save folder name, fixed so scores land in the same place whether
    -- the game runs from source or as the packaged exe
    t.identity = "NeonDodge"
    t.version = "11.5"

    t.window.title = "Neon Dodge"
    -- The window is only a viewport: the game itself is always drawn at
    -- Screen.WIDTH x Screen.HEIGHT (960x540) and scaled up to fit whatever
    -- size this is, so these are a comfort default rather than a constraint.
    -- 16:9 to match the game's own ratio, so a fresh window has no letterbox
    -- bars, and small enough to leave the title bar reachable on a 1080p
    -- display.
    t.window.width = 1024
    t.window.height = 576
    t.window.resizable = true
    -- below this the HUD text stops being legible; the scaling itself would
    -- happily go smaller
    t.window.minwidth = 640
    t.window.minheight = 360
    -- VSync açık olsun ki iş bilgisayarında ekran kartını gereksiz yormasın
    t.window.vsync = 1
end
