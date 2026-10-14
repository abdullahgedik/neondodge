local FXManager = {}

function FXManager.load()
    FXManager.active_particles = {}
    FXManager.active_rings = {}

    local p_data = love.image.newImageData(6, 6)
    for y = 0, 5 do for x = 0, 5 do p_data:setPixel(x, y, 1, 1, 1, 1) end end
    local p_img = love.graphics.newImage(p_data)

    FXManager.templates = {
        enemy_explosion = {
            image = p_img,
            buffer = 400,
            setup = function(ps)
                ps:setParticleLifetime(0.5, 0.8)
                ps:setSpeed(0)
                ps:setLinearAcceleration(-750, -750, 750, 750)
                ps:setEmissionArea("normal", 4, 4)
                ps:setColors(
                    1, 0, 0, 1,
                    1, 0, 0, 1,
                    1, 0, 0, 0
                )
                ps:setSizeVariation(0.6)
            end
        },
        zigzag_explosion = {
            image = p_img,
            buffer = 400,
            setup = function(ps)
                ps:setParticleLifetime(0.5, 0.8)
                ps:setSpeed(0)
                ps:setLinearAcceleration(-750, -750, 750, 750)
                ps:setEmissionArea("normal", 4, 4)
                ps:setColors(
                    1, 0.4, 0.05, 1,
                    1, 0.4, 0.05, 1,
                    1, 0.4, 0.05, 0
                )
                ps:setSizeVariation(0.6)
            end
        },
        homing_expire = {
            image = p_img,
            buffer = 300,
            setup = function(ps)
                ps:setParticleLifetime(0.4, 0.7)
                ps:setSpeed(0)
                ps:setLinearAcceleration(-650, -650, 650, 650)
                ps:setEmissionArea("normal", 5, 5)
                ps:setColors(
                    0.15, 0.9, 0.45, 1,
                    0.15, 0.9, 0.45, 1,
                    0.15, 0.9, 0.45, 0
                )
                ps:setSizeVariation(0.6)
            end
        },
        mine_explosion = {
            image = p_img,
            buffer = 500,
            setup = function(ps)
                ps:setParticleLifetime(0.5, 0.9)
                ps:setSpeed(0)
                ps:setLinearAcceleration(-900, -900, 900, 900)
                ps:setEmissionArea("normal", 8, 8)
                ps:setColors(
                    1, 0.45, 0.1, 1,
                    1, 0.25, 0.05, 1,
                    0.5, 0.1, 0.0, 0
                )
                ps:setSizeVariation(0.7)
            end
        },
        void_explosion = {
            image = p_img,
            buffer = 600,
            setup = function(ps)
                ps:setParticleLifetime(0.7, 1.2)
                ps:setSpeed(0)
                ps:setLinearAcceleration(-1000, -1000, 1000, 1000)
                ps:setEmissionArea("normal", 10, 10)

                ps:setColors(
                    0.7, 0.2, 1, 1,
                    0.6, 0.0, 1, 1,
                    0.5, 0.0, 0.8, 0
                )
                ps:setSizeVariation(0.8)
            end
        },
        player_damage = {
            image = p_img,
            buffer = 100,
            setup = function(ps)
                ps:setParticleLifetime(0.15, 0.35)
                ps:setSpeed(0)
                ps:setLinearAcceleration(-500, -500, 500, 500)
                ps:setEmissionArea("normal", 2, 2)
                ps:setColors(0, 1, 0.85, 1, 0, 0.6, 0.3, 1, 0, 1, 0.3, 0)
                ps:setSizeVariation(0.4)
            end
        },

        player_death = {
            image = p_img,
            buffer = 800,
            setup = function(ps)
                ps:setParticleLifetime(0.8, 1.5)
                ps:setSpeed(0)
                ps:setLinearAcceleration(-1200, -1200, 1200, 1200)
                ps:setEmissionArea("normal", 15, 15)
                ps:setColors(
                    0, 1, 0.85, 1,
                    0, 0.6, 0.3, 1,
                    0, 0.3, 0.2, 0
                )
                ps:setSizeVariation(0.7)
            end
        }
    }
end

-- Finished particle systems are kept per template and reused, rather than a
-- new one being allocated for every hit and explosion. A system's settings
-- survive ps:reset(), so a reused one only needs moving and re-emitting.
function FXManager.spawn(template_name, x, y, count)
    local template = FXManager.templates[template_name]
    if not template then return end

    template.free = template.free or {}
    local ps = table.remove(template.free)
    if ps then
        ps:reset()
    else
        ps = love.graphics.newParticleSystem(template.image, template.buffer)
        template.setup(ps)
    end

    ps:setPosition(x, y)
    ps:emit(count or 25)

    table.insert(FXManager.active_particles, { ps = ps, template = template })
end

function FXManager.spawn_ring(x, y, r, g, b, start_radius, max_radius, expand_speed)
    local ring = {
        x = x,
        y = y,
        r = r,
        g = g,
        b = b,
        start_radius = start_radius or 10,
        current_radius = start_radius or 10,
        max_radius = max_radius or 60,
        expand_speed = expand_speed or 150,
        alpha = 1.0
    }
    table.insert(FXManager.active_rings, ring)
end

function FXManager.update(dt)
    for i = #FXManager.active_particles, 1, -1 do
        local fx = FXManager.active_particles[i]
        fx.ps:update(dt)
        if fx.ps:getCount() == 0 then
            table.insert(fx.template.free, fx.ps)
            table.remove(FXManager.active_particles, i)
        end
    end

    for i = #FXManager.active_rings, 1, -1 do
        local ring = FXManager.active_rings[i]

        ring.current_radius = ring.current_radius + ring.expand_speed * dt

        -- fades from fully opaque at its own start radius to clear at max
        local progress = (ring.current_radius - ring.start_radius) / (ring.max_radius - ring.start_radius)
        ring.alpha = 1.0 - progress

        if ring.current_radius >= ring.max_radius or ring.alpha <= 0 then
            table.remove(FXManager.active_rings, i)
        end
    end
end

function FXManager.draw()
    love.graphics.setColor(1, 1, 1, 1)
    for _, fx in ipairs(FXManager.active_particles) do
        love.graphics.draw(fx.ps, 0, 0)
    end

    love.graphics.setLineWidth(3)
    for _, ring in ipairs(FXManager.active_rings) do
        love.graphics.setColor(ring.r, ring.g, ring.b, ring.alpha)
        love.graphics.circle("line", ring.x, ring.y, ring.current_radius)
    end
    love.graphics.setLineWidth(1)
end

function FXManager.reset()
    for _, fx in ipairs(FXManager.active_particles) do
        table.insert(fx.template.free, fx.ps)
    end
    FXManager.active_particles = {}
    FXManager.active_rings = {}
end

return FXManager
