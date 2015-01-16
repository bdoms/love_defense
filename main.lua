-- demo of space tower defense game
-- current resolution (defined in game.conf) is 1080p / 2

require("model")

-- globals
elapsed = 0
health = 100
run = true
paused = false
victory = false
run_wave = false -- is the wave going or not
placement_mode = false -- interaction is in the placement grid or not
upgrade_mode = false -- interaction is in the upgrade grid or not
finish_line = 400 -- the x position of the vertical edge that enemies need to get to
bank = 1000 -- amount of funds available for purchasing towers

level = nil
grid = nil
upgrade = nil

-- entities
stars = {}
enemies = {}
towers = {}
attacks = {}


-- each of these three top-level functions is required for love

function love.load()

    -- font must be set before ANYTHING can be written
    normal_font = love.graphics.newFont(18)
    large_font = love.graphics.newFont(72)
    love.graphics.setFont(large_font)

    -- initiate the level data
    level = model.Level:new()

    -- set the bg to something a little off-black
    love.graphics.setBackgroundColor(8, 8, 12)

    -- load up the image and set it's static position
    -- note that image coordinates in love are for the image CENTER (this changes in version 0.6)
    planet = love.graphics.newImage("images/planet.png")
    planet_x = 170 - planet:getWidth() / 2
    planet_y = love.graphics.getHeight() / 2 - planet:getHeight() / 2 - 50

    -- setup the user interface
    menu = model.Menu:new(0, love.graphics.getHeight() - 80, love.graphics.getWidth())

    grid = model.Grid:new(finish_line, 60, love.graphics.getWidth() - finish_line - 10, love.graphics.getHeight() - 150)

    upgrade = model.Upgrade:new(finish_line, 60, love.graphics.getWidth() - finish_line - 10, love.graphics.getHeight() - 150)

    -- health bar
    health_border = {love.graphics.getWidth() - 220, 20, 200, 20}
    health_bar = {love.graphics.getWidth() - 218, 22, 196, 16}

    -- background stars
    for star_x=0, love.graphics.getWidth(), 20 do -- last is step size
        local star = model.Star:new(star_x)
        table.insert(stars, star)
    end

    -- towers
    -- added by user

    -- enemies (add them from the level)
    enemies = level.waves[level.active_wave]

end

function love.update(dt)
    -- dt is delta time: time in seconds since last update
    elapsed = elapsed + dt

    if elapsed % 1 < .1 then
        -- this ensures that our manual garbage collection only happens about 10% of the time
        garbageCollect()
    end

    level:update(dt)

    if not paused then
        if run then
            -- bg stars
            for i, star in ipairs(stars) do
                star:update(dt)
            end
    
            -- towers
            for i, tower in ipairs(towers) do
                tower:update(dt, enemies)
            end

            -- attacks
            for i, attack in ipairs(attacks) do
                if attack.active then
                    attack:update(dt)
                end
            end

            -- enemies
            if run_wave then
                for i, enemy in ipairs(enemies) do
                    if enemy.alive then
                        success = enemy:update(dt)
                        if success then
                            -- enemy scores a hit
                            health = health - 10
                        end
                    end
                end
            end
    
            -- check for and respond to ending conditions
    
            -- failure: loss of all health
            if health <= 0 then
                -- game over!
                run = false
                level:lose()
                return
            end
    
            -- success: no remaining enemies, no remaining waves
            remaining = false
            for i, enemy in ipairs(enemies) do
                if enemy.alive then
                    remaining = true
                    break
                end
            end
            if not remaining then
                -- there are no enemies left alive - check to see if there's another wave
                if level.active_wave + 1 > table.getn(level.waves) then
                    -- no enemies and no more waves - win!
                    victory = true
                    run = false
                    level:win()
                else
                    -- advance the wave
                    run_wave = false
                    level.active_wave = level.active_wave + 1
                    enemies = level.waves[level.active_wave]
                end
            end
        end
    
        -- interface
        if placement_mode and run then
            grid:update(dt)
        elseif upgrade_mode and run then
            upgrade:update(dt)
        else
            menu:update(dt)
        end
    end

end

function love.draw()

    -- bg stars
    for i, star in ipairs(stars) do
        star:draw()
    end

    -- towers
    for i, tower in ipairs(towers) do
        tower:draw()
    end

    -- enemies
    for i, enemy in ipairs(enemies) do
        if enemy.alive then
            enemy:draw()
        end
    end

    -- attacks
    -- do this after everything else so that they all appear on top
    for i, attack in ipairs(attacks) do
        if attack.active then
            attack:draw()
        end
    end

    -- planet
    love.graphics.draw(planet, planet_x, planet_y)

    if placement_mode then
        grid:draw()
    elseif upgrade_mode then
        upgrade:draw()
    end

    -- bottom interface
    menu:draw()

    -- money
    love.graphics.setColor(128, 164, 196, 255)
    love.graphics.setFont(normal_font)
    love.graphics.print("$"..bank, love.graphics.getWidth() - 310, 20)
    love.graphics.setColor(255, 255, 255)

    -- health bar
    --love.graphics.setColor(128, 164, 196, 255)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", health_border[1], health_border[2], health_border[3], health_border[4])

    if health <= 20 then
        love.graphics.setColor(180, 96, 96, 255)
    elseif health <= 60 then
        love.graphics.setColor(180, 180, 96, 255)
    else
        love.graphics.setColor(96, 180, 96, 255)
    end
    love.graphics.rectangle("fill", health_bar[1], health_bar[2], health_bar[3] * health / 100, health_bar[4])
    love.graphics.setColor(255, 255, 255)

    level:draw()

    -- ending screen
    if not run then
        love.graphics.setFont(large_font)
        if victory then
            love.graphics.setColor(32, 64, 196, 255)
            love.graphics.printf("YOU WIN!", 0, love.graphics.getHeight() / 2 - 16, love.graphics.getWidth() + 8, "center")
            love.graphics.setColor(255, 255, 255, 255)
            love.graphics.printf("YOU WIN!", 0, love.graphics.getHeight() / 2 - 20, love.graphics.getWidth(), "center")
        else
            love.graphics.setColor(196, 32, 64, 255)
            love.graphics.printf("GAME OVER", 0, love.graphics.getHeight() / 2 - 16, love.graphics.getWidth() + 8, "center")
            love.graphics.setColor(255, 255, 255, 255)
            love.graphics.printf("GAME OVER", 0, love.graphics.getHeight() / 2 - 20, love.graphics.getWidth(), "center")
        end
        love.graphics.setColor(255, 255, 255)
    end

end

function garbageCollect()
    -- remove objects that are no longer used by implicitly removing their reference in their respective global list

    -- attacks
    local active_attacks = {}
    for i, attack in ipairs(attacks) do
        if attack.active then
            table.insert(active_attacks, attack)
        end
    end
    attacks = active_attacks

    -- enemies
    local alive_enemies = {}
    for i, enemy in ipairs(enemies) do
        if enemy.alive then
            table.insert(alive_enemies, enemy)
        end
    end
    enemies = alive_enemies
end
