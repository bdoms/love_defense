
enemies = {

    Enemy = {

            image = love.graphics.newImage("images/enemy.png"),
            destroy_sound = love.audio.newSound("sounds/enemy_explosion.wav"),
            win_sound = love.audio.newSound("sounds/enemy_reaches_planet.wav"),
            speed = 50, -- pixels / second

            new = function (self, x)
                -- create a new object, and initialize its attributes
                -- these first lines are magic for classes to work in lua
                local o = {}
                setmetatable(o, self)
                self.__index = self

                o.x = x
                o.y = love.graphics.getHeight() / 2 - 40
                o.health = 100
                o.alive = true

                -- setup engine particle system
                o.particles = love.graphics.newParticleSystem(model.Star.image, 100)
                o.particles:setEmissionRate(80)
                o.particles:setParticleLife(.6)
                o.particles:setDirection(0)
                o.particles:setSpread(180)
                o.particles:setSpeed(20)
                o.particles:setSize(.2, .7)
                o.particles:setRadialAcceleration(-20)
                start_color = love.graphics.newColor(220, 105, 20, 255) --(255, 0, 0)
                end_color = love.graphics.newColor(194, 30, 18, 0) --(255, 255, 0)
                o.particles:setColor(start_color, end_color)
                o.particles:start()

                return o
            end,

            update = function (self, dt)
                self.particles:update(dt)
                self.x = self.x - (self.speed * dt)
                if self.x < finish_line then
                    love.audio.play(self.win_sound)
                    -- take the enemy out of game
                    self:destroy()
                    -- and register the hit by returning true
                    return true
                end
                return false
            end,

            draw = function (self)
                love.graphics.draw(self.image, self.x, self.y)
                love.graphics.setColorMode(love.color_modulate)
                love.graphics.draw(self.particles, self.x + 8, self.y)
                love.graphics.setColorMode(love.color_normal)
            end,

            attack = function(self, power)
                self.health = self.health - power
                if self.health <= 0 then
                    love.audio.play(self.destroy_sound)
                    self:destroy()
                end
            end,

            destroy = function (self)
                self.particles:stop()
                self.alive = false -- don't update or draw this enemy and flag it for gc
            end

            }
}

