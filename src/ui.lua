local GameState          = require("src/game_state")
local Screen             = require("src/screen")
local Mathx              = require("src/mathx")

local UI                 = {}

-- card-select appear animation: each card starts its own scale/fade-in
-- CARD_STAGGER seconds after the previous one, over CARD_ANIM_DURATION
local CARD_ANIM_DURATION = 0.35
local CARD_STAGGER       = 0.06

-- shared vertical button-list widget for simple menus (main menu, pause) --
-- unlike the card-select layout these are single-column, centered, and
-- don't need the appear animation since they're not the core roguelike
-- decision point, just navigation
local MENU_ITEM_WIDTH    = 312
local MENU_ITEM_HEIGHT   = 45
local MENU_ITEM_GAP      = 13

UI.MAIN_MENU_OPTIONS     = { "Start Game", "Boss Rush", "Reset Records", "Quit" }
UI.PAUSE_MENU_OPTIONS    = { "Resume", "Restart", "Quit to Menu" }

local function main_menu_top_y()
    return Screen.HEIGHT / 2 - 110
end

local function pause_menu_top_y()
    return Screen.HEIGHT / 2 - 45
end

-- nominal sizes in game units -- the actual fonts are built this many game
-- units tall *times the current scale*, so they rasterize at their real
-- on-screen size instead of being stretched (see Screen.new_font)
local MAIN_FONT_SIZE     = 24
local TITLE_FONT_SIZE    = 40
local SMALL_FONT_SIZE    = 16

function UI.load()
    UI.refresh_fonts()
end

-- rebuilt whenever the window scale changes (love.resize), since the pixel
-- size a font must be rasterized at depends on it. Skipped when the scale
-- hasn't actually moved, so dragging a window edge doesn't rebuild fonts on
-- every one of the many resize events that generates.
function UI.refresh_fonts()
    if UI.font_scale == Screen.scale then return end

    UI.font_scale = Screen.scale
    UI.main_font = Screen.new_font(MAIN_FONT_SIZE)
    UI.title_font = Screen.new_font(TITLE_FONT_SIZE)
    UI.small_font = Screen.new_font(SMALL_FONT_SIZE)
end

-- shared layout for any simple menu -- single source of truth for both
-- drawing and mouse-click hit-testing, same convention as UI.card_layout()
function UI.simple_menu_layout(count, top_y)
    local rects = {}
    for i = 1, count do
        table.insert(rects, {
            x = (Screen.WIDTH - MENU_ITEM_WIDTH) / 2,
            y = top_y + (i - 1) * (MENU_ITEM_HEIGHT + MENU_ITEM_GAP),
            w = MENU_ITEM_WIDTH,
            h = MENU_ITEM_HEIGHT,
        })
    end
    return rects
end

function UI.main_menu_layout()
    return UI.simple_menu_layout(#UI.MAIN_MENU_OPTIONS, main_menu_top_y())
end

function UI.pause_menu_layout()
    return UI.simple_menu_layout(#UI.PAUSE_MENU_OPTIONS, pause_menu_top_y())
end

function UI.draw_simple_menu(labels, cursor_index, top_y, danger_index)
    local rects = UI.simple_menu_layout(#labels, top_y)

    love.graphics.setFont(UI.main_font)

    for i, rect in ipairs(rects) do
        local is_hovered = cursor_index == i
        local is_danger = danger_index == i

        love.graphics.setColor(0.08, 0.08, 0.15, 0.95)
        love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 8, 8)

        love.graphics.setLineWidth((is_hovered or is_danger) and 3 or 2)
        if is_danger then
            love.graphics.setColor(1, 0.3, 0.15, 1)
        elseif is_hovered then
            love.graphics.setColor(0, 1, 0.85, 1)
        else
            love.graphics.setColor(0.4, 0.5, 0.6, 0.7)
        end
        love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 8, 8)
        love.graphics.setLineWidth(1)

        if is_danger then
            love.graphics.setColor(1, 0.4, 0.3, 1)
        elseif is_hovered then
            love.graphics.setColor(0, 1, 0.85, 1)
        else
            love.graphics.setColor(1, 1, 1, 1)
        end
        Screen.printf(labels[i], rect.x, rect.y + (rect.h - Screen.text_height(UI.main_font)) / 2, rect.w, "center")
    end

    love.graphics.setColor(1, 1, 1, 1)
end

local HEART_MARGIN_X = 30
local HEART_MARGIN_Y = 23
local HEART_SPACING  = 42
-- the most horizontal room the heart row may take, so a big Vitality stack
-- compresses the row instead of running into the centered score text
local HEART_ROW_MAX  = 330

-- a 24x24 heart with its top-left at (x, y)
local function draw_heart(x, y)
    love.graphics.circle("fill", x + 6, y + 6, 6)
    love.graphics.circle("fill", x + 18, y + 6, 6)
    love.graphics.polygon("fill", x, y + 8, x + 12, y + 24, x + 24, y + 8)
end

-- full hearts for current HP, dim ones for the HP that's missing, and a blue
-- shield badge at the end of the row while a shield is up
local function draw_hearts(lives, max_lives, has_shield)
    max_lives = math.max(max_lives or lives, lives)
    local spacing = math.min(HEART_SPACING, HEART_ROW_MAX / math.max(max_lives, 1))

    for i = 1, max_lives do
        if i <= lives then
            love.graphics.setColor(1, 0.2, 0.3)
        else
            love.graphics.setColor(0.35, 0.12, 0.18, 0.8)
        end
        draw_heart(HEART_MARGIN_X + (i - 1) * spacing, HEART_MARGIN_Y)
    end

    if has_shield then
        local cx = HEART_MARGIN_X + (max_lives - 1) * spacing + 24 + 20
        love.graphics.setLineWidth(3)
        love.graphics.setColor(0.3, 0.65, 1)
        love.graphics.circle("line", cx, HEART_MARGIN_Y + 12, 11)
        love.graphics.setLineWidth(1)
    end
end

-- index of "Reset Records" in UI.MAIN_MENU_OPTIONS
local MENU_RESET_INDEX = 3

function UI.draw_menu(high_score, cursor_index, reset_armed, rush_best)
    love.graphics.setFont(UI.title_font)
    love.graphics.setColor(0, 1, 0.85)
    Screen.print_centered(UI.title_font, "NEON DODGE", Screen.HEIGHT / 2 - 170)

    -- "Reset Records" arms instead of firing immediately -- a second confirm
    -- within a few seconds (see main.lua's reset_confirm_timer) actually
    -- resets, so a misclick can't silently erase either record
    local labels = UI.MAIN_MENU_OPTIONS
    local danger_index = nil
    if reset_armed then
        labels = {}
        for i, label in ipairs(UI.MAIN_MENU_OPTIONS) do labels[i] = label end
        labels[MENU_RESET_INDEX] = "Click again to confirm"
        danger_index = MENU_RESET_INDEX
    end
    UI.draw_simple_menu(labels, cursor_index, main_menu_top_y(), danger_index)

    love.graphics.setFont(UI.main_font)

    if high_score and high_score > 0 then
        love.graphics.setColor(1, 0.9, 0.2)
        Screen.print_centered(UI.main_font, "High Score: " .. high_score, Screen.HEIGHT / 2 + 135)
    end

    if rush_best and rush_best > 0 then
        love.graphics.setColor(1, 0.55, 0.2)
        Screen.print_centered(UI.main_font, "Boss Rush Best: " .. rush_best .. " cleared", Screen.HEIGHT / 2 + 165)
    end

    love.graphics.setFont(UI.small_font)
    love.graphics.setColor(0.55, 0.6, 0.7)
    Screen.print_centered(UI.small_font,
        "Move: WASD / Arrows / Left stick    Dash: Shift / A    Pause: P / Esc / Start    Fullscreen: F11",
        Screen.HEIGHT - 32)
    love.graphics.setColor(1, 1, 1, 1)
end

function UI.card_layout()
    local card_width, card_height = 264, 270
    local gap = 36
    local total_width = card_width * 3 + gap * 2
    local start_x = (Screen.WIDTH - total_width) / 2
    local y = 144

    local rects = {}
    for i = 1, 3 do
        local x = start_x + (i - 1) * (card_width + gap)
        table.insert(rects, { x = x, y = y, w = card_width, h = card_height })
    end

    return rects
end

-- the card screen's heading, by what opened it
local CARD_TITLES = {
    boss  = "BOSS DEFEATED",
    score = "SCORE MILESTONE",
}

function UI.draw_card_select(cards, cursor_index, elapsed, chosen_index, reason)
    elapsed = elapsed or CARD_ANIM_DURATION

    -- overlay itself fades in first; everything else rides on top of it
    local overlay_t = math.min(elapsed / CARD_ANIM_DURATION, 1)
    love.graphics.setColor(0, 0, 0, 0.75 * overlay_t)
    love.graphics.rectangle("fill", 0, 0, Screen.WIDTH, Screen.HEIGHT)

    if overlay_t <= 0 then return end

    love.graphics.setFont(UI.title_font)
    love.graphics.setColor(0, 1, 0.85, overlay_t)
    Screen.print_centered(UI.title_font, CARD_TITLES[reason] or "UPGRADE", 44)

    love.graphics.setFont(UI.main_font)
    love.graphics.setColor(1, 1, 1, overlay_t)
    Screen.print_centered(UI.main_font, "Choose an upgrade", 100)

    local rects = UI.card_layout()

    for i, rect in ipairs(rects) do
        local card = cards and cards[i]
        if card then
            -- cascade: card i doesn't start animating until the previous
            -- one is already CARD_STAGGER seconds into its own animation
            local card_t = Mathx.clamp((elapsed - (i - 1) * CARD_STAGGER) / CARD_ANIM_DURATION, 0, 1)

            if card_t > 0 then
                local is_hovered = cursor_index == i
                local is_chosen = chosen_index == i
                local is_other_chosen = chosen_index ~= nil and not is_chosen

                -- ease-out: scales up from 85% and rises into place, rather
                -- than just popping straight to full size
                local eased = Mathx.ease_out_strong(card_t)
                local scale = 0.85 + 0.15 * eased
                local rise = (1 - eased) * 24
                local alpha = eased * (is_other_chosen and 0.35 or 1)

                local cx, cy = rect.x + rect.w / 2, rect.y + rect.h / 2

                love.graphics.push()
                love.graphics.translate(cx, cy + rise)
                love.graphics.scale(scale, scale)
                love.graphics.translate(-cx, -cy)

                love.graphics.setColor(0.08, 0.08, 0.15, 0.95 * alpha)
                love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 10, 10)

                love.graphics.setLineWidth((is_hovered or is_chosen) and 4 or 2)
                if is_chosen then
                    love.graphics.setColor(1, 0.9, 0.2, alpha)
                elseif is_hovered then
                    love.graphics.setColor(0, 1, 0.85, alpha)
                else
                    love.graphics.setColor(0.4, 0.5, 0.6, 0.8 * alpha)
                end
                love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 10, 10)
                love.graphics.setLineWidth(1)

                love.graphics.setColor(1, 0.9, 0.2, alpha)
                Screen.print(tostring(i), rect.x + 14, rect.y + 12)

                love.graphics.setColor(0, 1, 0.85, alpha)
                Screen.printf(card.name, rect.x + 14, rect.y + 50, rect.w - 28, "center")

                love.graphics.setColor(1, 1, 1, alpha)
                Screen.printf(card.description, rect.x + 14, rect.y + 100, rect.w - 28, "center")

                love.graphics.pop()
            end
        end
    end

    love.graphics.setColor(0.7, 0.75, 0.8, overlay_t)
    Screen.print_centered(UI.main_font, "Click a card, press 1/2/3, or move + Enter / A", 432)

    love.graphics.setColor(1, 1, 1, 1)
end

-- the HUD's top-center banner: at most one of these is ever showing, and the
-- priority order matters (a live boss outranks its own telegraph, which
-- outranks any storm). Split out of UI.draw because it was the one part of it
-- doing real branching rather than just placing text.
local function draw_status_banner(view)
    local BANNER_Y = 72

    if view.boss_active then
        love.graphics.setColor(1, 0.2, 0.6)
        Screen.print_centered(UI.main_font, "BOSS", BANNER_Y)
    elseif view.boss_incoming then
        -- pulses so it reads as a telegraph/warning, not a static label
        local pulse = 0.6 + 0.4 * math.abs(math.sin(love.timer.getTime() * 6))
        love.graphics.setColor(1, 0.3, 0.2, pulse)
        Screen.print_centered(UI.main_font, "BOSS INCOMING", BANNER_Y)
    elseif view.storm_phase and view.storm_type then
        -- one banner for both storm phases, named and colored by the storm
        -- type itself so which storm is coming reads at a glance. The active
        -- phase flickers noticeably faster than the telegraph -- it means
        -- "danger right now", not "danger soon"
        local is_active = view.storm_phase == "active"
        local text = is_active and view.storm_type.name or (view.storm_type.name .. " INCOMING")
        local pulse = 0.5 + 0.5 * math.abs(math.sin(love.timer.getTime() * (is_active and 12 or 6)))
        local c = view.storm_type.color
        love.graphics.setColor(c[1], c[2], c[3], pulse)
        Screen.print_centered(UI.main_font, text, BANNER_Y)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

local function draw_pause_overlay(view)
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 0, Screen.WIDTH, Screen.HEIGHT)

    love.graphics.setFont(UI.title_font)
    love.graphics.setColor(0, 0.8, 1)
    Screen.print_centered(UI.title_font, "PAUSED", Screen.HEIGHT / 2 - 108)

    UI.draw_simple_menu(UI.PAUSE_MENU_OPTIONS, view.menu_cursor, pause_menu_top_y())

    love.graphics.setFont(UI.main_font)
    love.graphics.setColor(0.7, 0.75, 0.8)
    Screen.print_centered(UI.main_font, "Shortcuts still work: P/Esc resume, R restart, M menu", Screen.HEIGHT / 2 + 135)
    love.graphics.setColor(1, 1, 1, 1)
end

local function draw_game_over_overlay(view)
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", 0, 0, Screen.WIDTH, Screen.HEIGHT)

    love.graphics.setFont(UI.title_font)
    love.graphics.setColor(1, 0, 0)
    Screen.print_centered(UI.title_font, "GAME OVER", Screen.HEIGHT / 2 - 80)

    love.graphics.setFont(UI.main_font)

    local result_text, record_text
    if view.mode == "boss_rush" then
        result_text = "Bosses Cleared: " .. (view.rush_cleared or 0) .. "  (Lap " .. (view.rush_lap or 1) .. ")"
        record_text = view.new_record
            and ("New Boss Rush Best: " .. (view.rush_best or 0) .. "!")
            or ("Boss Rush Best: " .. (view.rush_best or 0))
    else
        result_text = "Score: " .. view.score
        record_text = view.new_record
            and ("New High Score: " .. (view.high_score or 0) .. "!")
            or ("High Score: " .. (view.high_score or 0))
    end

    love.graphics.setColor(1, 1, 1)
    Screen.print_centered(UI.main_font, result_text, Screen.HEIGHT / 2 - 10)

    love.graphics.setColor(1, 0.9, 0.2)
    Screen.print_centered(UI.main_font, record_text, Screen.HEIGHT / 2 + 22)

    love.graphics.setColor(0.7, 0.75, 0.8)
    Screen.print_centered(UI.main_font, "R / Enter / A: restart     M / Esc / B: menu", Screen.HEIGHT / 2 + 80)
    love.graphics.setColor(1, 1, 1, 1)
end

-- `view` is everything the HUD needs for this frame, as one named table --
-- see the call in main.lua's love.draw.
--
-- Expected fields: state, mode, score, new_record, lives, max_lives,
-- has_shield, orbs, wave, high_score, rush_cleared, rush_lap, rush_best,
-- boss_active, boss_incoming, storm_type, storm_phase, card_reason, cards,
-- card_cursor, card_elapsed, chosen_card, menu_cursor, reset_armed
function UI.draw(view)
    if view.state == GameState.MENU then
        UI.draw_menu(view.high_score, view.menu_cursor, view.reset_armed, view.rush_best)
        return
    end

    if view.state == GameState.CARD_SELECT then
        UI.draw_card_select(view.cards, view.card_cursor, view.card_elapsed, view.chosen_card, view.card_reason)
        return
    end

    draw_hearts(view.lives, view.max_lives, view.has_shield)

    love.graphics.setFont(UI.main_font)

    -- Boss Rush has no score/wave/orbs -- it tracks bosses cleared instead
    if view.mode == "boss_rush" then
        love.graphics.setColor(1, 0.55, 0.2)
        Screen.print_centered(UI.main_font,
            "Boss Rush -- Cleared: " .. (view.rush_cleared or 0) .. " (Lap " .. (view.rush_lap or 1) .. ")", 18)
    else
        love.graphics.setColor(1, 1, 1)
        Screen.print_centered(UI.main_font, "Score: " .. view.score, 18)

        if view.wave then
            love.graphics.setColor(0.7, 0.75, 1)
            Screen.print_centered(UI.main_font, "Wave: " .. view.wave, 45)
        end
    end

    draw_status_banner(view)

    if view.mode ~= "boss_rush" then
        -- progress toward the next 5-orb milestone, not the lifetime total --
        -- shows 5/5 right at the trigger moment rather than looping back to 0/5
        local orbs = view.orbs or 0
        local progress = orbs % 5
        if progress == 0 and orbs > 0 then progress = 5 end
        local orb_text = "Orbs: " .. progress .. "/5"

        love.graphics.setColor(1, 0.9, 0.2)
        Screen.print(orb_text, Screen.WIDTH - Screen.text_width(UI.main_font, orb_text) - HEART_MARGIN_X, 18)
    end

    if view.state == GameState.PAUSED then
        draw_pause_overlay(view)
    elseif view.state == GameState.GAME_OVER then
        draw_game_over_overlay(view)
    end
end

return UI
