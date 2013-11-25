require("AnAL")

require("constants")

require("utils")

towers = {


    Tower = {

            -- convenience functions to lookup stats for a specific level
            range = function(self)
                -- radius of pixels the tower can attack
                if self.level then
                    return self.stats[self.level].range
                else
                    -- tower might not have been built yet, so default to level 1
                    return self.stats[1].range
                end
            end,

            power = function(self)
                if self.level then
                    return self.stats[self.level].power
                else
                    return self.stats[1].power
                end
            end,

            -- this one is different because the property "health" is the currently changing health of the tower
            max_health = function(self)
                if self.level then
                    return self.stats[self.level].health
                else
                    return self.stats[1].health
                end
            end,

            cost = function(self)
                -- how much it costs to build this tower
                if self.level then
                    return self.stats[self.level].cost
                else
                    return self.stats[1].cost
                end
            end,

            update = function (self, dt, enemies)
                -- figure out if the tower can fire at all
                if self.last_firing >= self.cooldown then
                    -- find a target if one doesn't exist already
                    if not self.target then
                        self.target = self:findTarget(enemies)
                        if self.target then
                            -- attack!
                            self.last_firing = 0 -- set time since last fire to 0
                        end
                    end
                else
                    self.last_firing = self.last_firing + dt
                end

                -- respond to the current state of the tower's animation
                local current_frame = self.animation:getCurrentFrame()
                
                --  detect end of animation and reset animation to first frame
                if current_frame == self.animation:getSize() - 1 then
                    self.animation:reset()
                    self.animation:stop() -- keep it from starting over again
                end

                if self.target and self.target.alive then
                    -- rotate the turrent slightly, if there is one and it needs it
                    -- the 5 here is the number of degrees of leeway - i.e. a turret may be within X degrees to either side of the desired actual before we force the correct angle
                    if self.turret and math.abs(self.current_rotation - self.destination_rotation) > math.rad(5) then
                        -- determine which rotation direction is faster
                        if self.destination_rotation > self.current_rotation and self.destination_rotation - self.current_rotation <= math.rad(180) then
                            self.current_rotation = self.current_rotation + self.rotation_speed * dt
                            if self.current_rotation > math.rad(360) then
                                self.current_rotation = self.current_rotation - math.rad(360)
                            end
                        else
                            self.current_rotation = self.current_rotation - self.rotation_speed * dt
                            if self.current_rotation < 0 then
                                self.current_rotation = self.current_rotation + math.rad(360)
                            end
                        end
                    elseif self.turret then
                        -- just force the current rotation to be the destination now that it's close enough
                        self.current_rotation = self.destination_rotation
                    end

                    if current_frame == 1 then
                        -- first instant of the attack, so start animation
                        self.animation:play()
                    end
                    
                    -- WARNING! the order of these means sound_frame MUST BE <= attack_frame in order to play
                    if current_frame >= self.sound_frame and not self.is_playing_attack then 
                        love.audio.play(self.attack_sound)
                        self.is_playing_attack = true
                    end

                    if current_frame >= self.attack_frame then
                        table.insert(attacks, self.attack:new(self, self.target))
                        -- throw target away here so that a new target has to be aquired before attacking again
                        self.target = nil
                        self.is_playing_attack = false -- we reset this too so that a new sound is played next time
                    end
                elseif current_frame > 1 and current_frame < self.attack_frame then
                    -- in this situation, the animation is playing but there is no target, so attempt to find one
                    -- as we assume that here the target was aquired, animation started, and then target destroyed by a third party
                    self.target = self:findTarget(enemies)
                    if not self.target then
                        -- if there's nothing in range, then reset the animation and give it chance to re-aquire on the next pass
                        self.animation:reset()
                        self.animation:stop()
                        self.last_firing = self.cooldown
                    end
                end

                self.animation:update(dt)
            end,

            draw = function (self)
                -- draw the radius when the grid is on
                if placement_mode or upgrade_mode then
                    -- draw a circle showing the tower's effective radius
                    love.graphics.setColor(196, 196, 128, 128)
                    love.graphics.circle("fill", self.x + self.w / 2, self.y + self.h / 2, self:range(), 32) -- last is the number of points for the circle (default 10)
                end
                if not self.animation or self.animation:getCurrentFrame() == 1 then
                    love.graphics.draw(self.image, self.x, self.y)
                else
                    if self.tower_rotation then
                        self.animation:draw(self.x + self.w / 2, self.y + self.h / 2, self.tower_rotation, 1, 1, self.w / 2, self.h / 2)
                    else
                        self.animation:draw(self.x, self.y)
                    end
                end
                if self.turret then
                    love.graphics.draw(self.turret, self.x + self.w / 2, self.y + self.h / 2, self.current_rotation, 1, 1, self.w / 2, self.h / 2)
                end

                -- health bar on top of tower, which stretches the width of the tower along the bottom
                local left = self.x
                local bottom = self.y + self.h
                local health_percent = self.health / self:max_health() -- affects color and width of the bar

                if health_percent <= .2 then
                    love.graphics.setColor(180, 96, 96, 255)
                elseif health_percent <= .6 then
                    love.graphics.setColor(180, 180, 96, 255)
                else
                    love.graphics.setColor(96, 180, 96, 255)
                end
                love.graphics.rectangle("fill", left, bottom - 2, health_percent * self.w, 2)
            end

            },

    LaserTower = {

            image = love.graphics.newImage("images/laser_cannon.png"),
            build_sound = love.audio.newSource("sounds/build_laser_cannon.wav"),
            cooldown = 3, -- time between firings in seconds
            w = GRID_SIZE * 2,
            h = GRID_SIZE * 2,
            name = "Laser Cannon",
            animation_source = love.graphics.newImage("images/laser_animation.png"),
            attack_frame = 21,
            sound_frame = 14,

            stats = {{range = 130, power = 25, health = 200,  cost = 200},  -- level 1
                     {range = 135, power = 30, health = 400,  cost = 200},  -- level 2
                     {range = 140, power = 35, health = 600,  cost = 400},  -- level 3
                     {range = 160, power = 50, health = 800,  cost = 800},  -- level 4
                     {range = 200, power = 80, health = 1000, cost = 1600}},-- level 5

            new = function (self, x, y)
                -- create a new instance, clone its parent's attributes, and initialize new attributes
                -- these first lines are magic for classes to work in lua
                local o = clone({}, model.towers.Tower)
                setmetatable(o, self)
                self.__index = self

                o.level = 1 -- tower's current level
                o.health = 200 -- current health (should be identical to level 1 health)
                o.x = x
                o.y = y
                o.last_firing = 3 -- time since last firing (should default to at least cooldown amount)
                o.target = nil
                o.attack = model.attacks.LaserAttack -- needs to be in a function to reference model.*

                o.is_playing_attack = false
                o.attack_sound = love.audio.newSource("sounds/attack_laser_cannon.wav")
                o.animation = newAnimation(self.animation_source, self.w, self.h, .05, 0) -- second to last is frame speed
                o.animation:setMode("once") -- ensure that the animation doesn't loop
                o.animation:stop() -- don't play immediately

                return o
            end,

            findTarget = function (self, enemies)
                -- find the first enemy the tower can attack
                -- this is detects all enemies in range, and finds the weakest
                local weakest = nil
                for i, enemy in ipairs(enemies) do
                    -- only check the distance for enemies that are actually on the screen
                    if enemy.alive and enemy.x <= love.graphics.getWidth() then
                        local distance = ((enemy.x - self.x)^2 + (enemy.y - self.y)^2)^.5
                        if distance <= self:range() then
                            if not weakest or enemy.health < weakest.health then
                                weakest = enemy
                            end
                        end
                    end
                end

                return weakest
            end

            },

    PulseTower = {

            image = love.graphics.newImage("images/pulse_cannon.png"),
            turret = love.graphics.newImage("images/pulse_turret.png"),
            build_sound = love.audio.newSource("sounds/build_pulse_cannon.wav"),
            rotation_speed = math.rad(150), -- number of degrees per second the turret on the tower rotates
            cooldown = 2.4, -- time between firings in seconds
            w = GRID_SIZE * 2,
            h = GRID_SIZE * 2,
            name = "Pulse Cannon",
            animation_source = love.graphics.newImage("images/pulse_animation.png"),
            attack_frame = 29,
            sound_frame = 29,

            stats = {{range = 110, power = 10, health = 150,  cost = 150},  -- level 1
                     {range = 130, power = 20, health = 160,  cost = 150},  -- level 2
                     {range = 150, power = 30, health = 170,  cost = 300},  -- level 3
                     {range = 170, power = 50, health = 300,  cost = 700},  -- level 4
                     {range = 220, power = 100, health = 500, cost = 1500}},-- level 5

            new = function (self, x, y)
                -- create a new object, and initialize its attributes
                -- these first lines are magic for classes to work in lua
                local o = clone({}, model.towers.Tower)
                setmetatable(o, self)
                self.__index = self

                o.level = 1
                o.health = 150
                o.x = x
                o.y = y
                o.last_firing = 3 -- time since last firing (should default to at least cooldown amount)
                o.target = nil
                o.attack = model.attacks.PulseAttack -- needs to be in a function to reference model.*
                o.current_rotation = 0 -- how the turret is currently oriented
                o.destination_rotation = 0 -- where the turret should be

                o.is_playing_attack = false
                o.attack_sound = love.audio.newSource("sounds/attack_pulse_cannon.wav")
                o.animation = newAnimation(self.animation_source, self.w, self.h, .05, 0) -- second to last is frame speed
                o.animation:setMode("once") -- ensure that the animation doesn't loop
                o.animation:stop() -- don't play immediately

                return o
            end,

            findTarget = function(self, enemies)
                -- this algorithm just finds the closest enemy
                local nearest = nil
                local nearest_distance = love.graphics.getWidth()
                for i, enemy in ipairs(enemies) do
                    -- only check the distance for enemies that are actually on the screen
                    if enemy.alive and enemy.x <= love.graphics.getWidth() then
                        local distance = ((enemy.x - self.x)^2 + (enemy.y - self.y)^2)^.5
                        if distance <= self:range() then
                            if not nearest or distance < nearest_distance then
                                nearest = enemy
                                nearest_distance = distance
                            end
                        end
                    end
                end

                -- determine destination_rotation here
                if nearest then
                    -- NOTE: the first part of this chunk is largely the same as the prediction code in the pulse attack

                    -- predict the enemy's position when the attack starts to make this more accurate
                    local attack_x = nearest.x - (nearest.speed * self.attack_frame * .05)
                    local attack_y = nearest.y
                    local distance = ((attack_x - self.x)^2 + (attack_y - self.y)^2)^.5

                    -- this check is for seeing if the enemy is coming at or going away from the tower (flips the signs on the math)
                    local duration
                    if attack_x > self.x then
                        duration = distance / (self.attack.speed + nearest.speed)
                    else
                        duration = distance / (self.attack.speed - nearest.speed)
                    end

                    local future_x = attack_x - (nearest.speed * duration)
                    local future_y = attack_y -- no y component for now
                    -- different equation and offset for each quadrant
                    if future_x >= self.x and future_y >= self.y then
                        self.destination_rotation = math.atan2(future_y - self.y, future_x - self.x) -- atan2 takes either (opposite / adjacent) or (opposite, adjacent); the latter is faster
                    elseif future_x < self.x and future_y >= self.y then
                        self.destination_rotation = math.atan2(self.x - future_x, future_y - self.y) + math.rad(90)
                    elseif future_x < self.x and future_y < self.y then
                        self.destination_rotation = math.atan2(self.y - future_y, self.x - future_x) + math.rad(180)
                    else
                        self.destination_rotation = math.atan2(future_x - self.x, self.y - future_y) + math.rad(270)
                    end
                end

                return nearest
            end

            },

    MissileTower = {

            image = love.graphics.newImage("images/missile_cannon.png"),
            build_sound = love.audio.newSource("sounds/build_missile_cannon.wav"),
            cooldown = 4, -- time between firings in seconds
            w = GRID_SIZE * 2,
            h = GRID_SIZE * 2,
            name = "Missile Cannon",
            animation_source = love.graphics.newImage("images/missile_animation.png"),
            attack_frame = 16,
            sound_frame = 10,

            stats = {{range = 250, power = 60,  health = 500,  cost = 325},  -- level 1
                     {range = 265, power = 80,  health = 600,  cost = 325},  -- level 2
                     {range = 280, power = 100, health = 700,  cost = 650},  -- level 3
                     {range = 300, power = 130, health = 900,  cost = 1300}, -- level 4
                     {range = 330, power = 170, health = 1200, cost = 2600}},-- level 5

            new = function (self, x, y)
                -- create a new object, and initialize its attributes
                -- these first lines are magic for classes to work in lua
                local o = clone({}, model.towers.Tower)
                setmetatable(o, self)
                self.__index = self

                o.level = 1
                o.health = 500
                o.x = x
                o.y = y
                o.last_firing = 4 -- time since last firing (should default to at least cooldown amount)
                o.target = nil
                o.attack = model.attacks.MissileAttack -- needs to be in a function to reference model.*
                o.tower_rotation = 0 -- how much the tower should be rotated when drawn

                o.is_playing_attack = false
                o.attack_sound = love.audio.newSource("sounds/attack_missile_cannon.wav")
                o.animation = newAnimation(self.animation_source, self.w, self.h, .05, 0) -- second to last is frame speed
                o.animation:setMode("once") -- ensure that the animation doesn't loop
                o.animation:stop() -- don't play immediately

                return o
            end,

            findTarget = function(self, enemies)
                -- this algorithm just finds the closest enemy
                local nearest = nil
                local nearest_distance = love.graphics.getWidth()
                for i, enemy in ipairs(enemies) do
                    -- only check the distance for enemies that are actually on the screen
                    if enemy.alive and enemy.x <= love.graphics.getWidth() then
                        local distance = ((enemy.x - self.x)^2 + (enemy.y - self.y)^2)^.5
                        if distance <= self:range() then
                            if not nearest or distance < nearest_distance then
                                nearest = enemy
                                nearest_distance = distance
                            end
                        end
                    end
                end

                if nearest then
                    -- find rotation for animation
                    -- predict the enemy's position when the attack starts to make this more accurate
                    local attack_x = nearest.x - (nearest.speed * self.attack_frame * .05)
                    local attack_y = nearest.y

                    -- find the diff between the enemy's future location and the tower
                    local delta_x = attack_x - self.x
                    local delta_y = attack_y - self.y

                    -- we use four quadrants shaped like an X to figure out the rotation
                    if math.abs(delta_x) >= math.abs(delta_y) and delta_x >= 0 then
                        self.tower_rotation = 0
                    elseif math.abs(delta_x) < math.abs(delta_y) and delta_y >= 0 then
                        self.tower_rotation = math.rad(90)
                    elseif math.abs(delta_x) >= math.abs(delta_y) and delta_x < 0 then
                        self.tower_rotation = math.rad(180)
                    else
                        self.tower_rotation = math.rad(270)
                    end
                end

                return nearest
            end

            }

}

