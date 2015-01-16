require("utils")

attacks = {

    Attack = {

            -- NOTE: this should just be called "update" but there's some conflict with the cloning where children don't override the name
            attackUpdate = function (self, dt)

                if self:complete() then
                    -- only play noises and actually attack the enemy if it is still alive
                    if self.target.alive then
                        -- subtract health from the enemy at the end of the attack
                        self.target:attack(self.power)

                        -- play hit noise if one exists
                        if self.hit_sound then
                            love.audio.play(self.hit_sound)
                        end
                    end

                    -- perform some extra special attack action if it exists
                    if self.extraAttack then
                        self:extraAttack()
                    end

                    -- mark self for destruction now that the attack is complete
                    self.active = false
                end

            end

            },

    LaserAttack = {

            -- OPTIONAL
            duration = .9, -- how many seconds the attack lasts

            new = function (self, tower, target)
                -- create a new instance, clone its parent's attributes, and initialize new attributes
                -- these first lines are magic for classes to work in lua
                local o = clone({}, model.attacks.Attack)
                setmetatable(o, self)
                self.__index = self

                -- REQUIRED Attack properties
                o.target = target
                o.active = true
                o.power = tower:power() -- how strong the attack is

                -- OPTIONAL Attack properties
                o.tower = tower
                o.elapsed = 0 -- time attack has taken so far

                return o
            end,

            complete = function(self)
                if self.elapsed >= self.duration or not self.target.alive then
                    return true
                else
                    return false
                end
            end,

            update = function(self, dt)
                -- do whatever is necessary and then call super's update
                self.elapsed = self.elapsed + dt
                -- this may seem counterintuitive to use model here, but this is called from the main loop, which only has model as an import
                model.attacks.Attack.attackUpdate(self, dt)
            end,

            draw = function (self)
                love.graphics.setLineWidth(2)
                love.graphics.setColor(255, 0, 0, 164)
                love.graphics.line(self.tower.x + self.tower.w / 2, self.tower.y + self.tower.h / 2, self.target.x + self.target.w / 2, self.target.y + self.target.h / 2)
                love.graphics.setColor(255, 255, 255)
            end

            },

    PulseAttack = {

            -- OPTIONAL
            speed = 120, -- how fast the projectile attack travels
            projectile = love.graphics.newImage("images/pulse.png"),

            new = function (self, tower, target)
                -- create a new instance, clone its parent's attributes, and initialize new attributes
                -- these first lines are magic for classes to work in lua
                local o = clone({}, model.attacks.Attack)
                setmetatable(o, self)
                self.__index = self

                -- REQUIRED Attack properties
                o.target = target
                o.active = true
                o.power = tower:power() -- how strong the attack is

                -- OPTIONAL Attack properties
                o.x = tower.x + tower.w / 2 -- we record these rather than the tower to make this attack independent once launched
                o.y = tower.y + tower.h / 2
                o.start_x = o.x -- coords for where the projectile begins
                o.start_y = o.y

                -- figure out where the projectile is headed
                -- TODO: this section will need revising when enemies vary their vertical as well as horizontal

                -- check it out, for this algorithm, there's a simple formula to figure out the duration of the shot:
                -- time = current distance / (projectile speed - enemy speed)

                -- but now we need to predict the future a bit to account for the animation
                local distance = ((target.x + target.w / 2 - o.x)^2 + (target.y + target.h / 2 - o.y)^2)^.5

                -- this check is for seeing if the enemy is coming at or going away from the tower (flips the signs on the math)
                local duration
                if target.x > o.x then
                    duration = distance / (self.speed + target.speed)
                else
                    duration = distance / (self.speed - target.speed)
                end

                -- more OPTIONAL properties
                o.destination_x = target.x + target.w / 2 - (target.speed * duration)
                o.destination_y = target.y + target.h / 2 -- no y component for now

                -- and how much of that is each component
                local destination_distance = ((o.destination_x - o.x)^2 + (o.destination_y - o.y)^2)^.5
                o.percent_x = math.abs(o.destination_x - o.x) / destination_distance
                o.percent_y = math.abs(o.destination_y - o.y) / destination_distance

                return o
            end,

            complete = function(self)
                -- the attack is complete if the distance from the projectile to the enemy is < a grid square
                if self.target.alive then
                    local distance = ((self.target.x + self.target.w / 2 - self.x)^2 + (self.target.y + self.target.h / 2 - self.y)^2)^.5
                    -- NOTE: anything less than 11 here and the prediction algorithm will (rarely) miss the target - looks really buggy
                    if distance < 11 then
                        return true
                    else
                        return false
                    end
                else
                    -- when the enemy is dead, we actually keep the projectile going until it exits the screen

                    -- reset the destination coords to be off the screen if they're still on it
                    if (self.destination_x > 0 and self.destination_x < love.graphics.getWidth()) or (self.destination_y > 0 and self.destination_y < love.graphics.getHeight()) then
                        if self.x > self.destination_x then
                            self.destination_x = self.destination_x - self.percent_x * 10000
                        else
                            self.destination_x = self.destination_x + self.percent_x * 10000
                        end
                        if self.y > self.destination_y then
                            self.destination_y = self.destination_y - self.percent_y * 10000
                        else
                            self.destination_y = self.destination_y + self.percent_y * 10000
                        end
                    end

                    -- now we just need to know if the attack is off the screen yet or not to be successful
                    if self.x < 0 or self.x > love.graphics.getWidth() or self.y < 0 or self.y > love.graphics.getHeight() then
                        return true
                    else
                        return false
                    end
                end
            end,

            update = function(self, dt)
                -- do whatever is necessary and then call super's update

                -- move the projectile toward the enemy a certain distance every second
                if self.x > self.destination_x then
                    self.x = self.x - (self.speed * dt * self.percent_x)
                else
                    self.x = self.x + (self.speed * dt * self.percent_x)
                end
                if self.y > self.destination_y then
                    self.y = self.y - (self.speed * dt * self.percent_y)
                else
                    self.y = self.y + (self.speed * dt * self.percent_y)
                end

                -- this may seem counterintuitive to use model here, but this is called from the main loop, which only has model as an import
                model.attacks.Attack.attackUpdate(self, dt)
            end,

            draw = function (self)
                -- this hides the projectile until it is "out" of the cannon
                local distance = ((self.x - self.start_x)^2 + (self.y - self.start_y)^2)^.5
                if distance > 30 then
                    love.graphics.draw(self.projectile, self.x, self.y)
                end
            end

            },

    MissileAttack = {

            -- OPTIONAL
            speed = 100, -- how fast the projectile attack travels
            hit_sound = love.audio.newSource("sounds/hit_missile_cannon.wav"),
            projectile = love.graphics.newImage("images/missile.png"),
            time_to_clear = .3, -- the amount of time required for the missile to clear the tower
            splash_range = 120, -- the radius in pixels of how far the splash damage extends out to

            new = function (self, tower, target)
                -- create a new instance, clone its parent's attributes, and initialize new attributes
                -- these first lines are magic for classes to work in lua
                local o = clone({}, model.attacks.Attack)
                setmetatable(o, self)
                self.__index = self

                -- REQUIRED Attack properties
                o.target = target
                o.active = true
                o.power = tower:power() -- how strong the attack is

                -- OPTIONAL Attack properties
                o.elapsed = 0 -- how long the attack has been going for
                o.rotation = tower.tower_rotation
                -- the rotation of the tower effects the starting position of the missile
                if o.rotation == 0 then
                    o.x = tower.x + tower.w / 2 + 15
                    o.y = tower.y + tower.h / 2 - 12
                elseif o.rotation == math.rad(90) then
                    o.x = tower.x + tower.w / 2 + 12
                    o.y = tower.y + tower.h / 2 + 15
                elseif o.rotation == math.rad(180) then
                    o.x = tower.x + tower.w / 2 - 15
                    o.y = tower.y + tower.h / 2 + 12
                else
                    o.x = tower.x + tower.w / 2 - 12
                    o.y = tower.y + tower.h / 2 - 15
                end

                return o
            end,

            complete = function(self)
                -- the attack is complete if the distance from the projectile to the enemy is < a grid square
                local distance = ((self.target.x + self.target.w / 2 - self.x)^2 + (self.target.y + self.target.h / 2 - self.y)^2)^.5
                if distance < 10 or not self.target.alive then
                    return true
                else
                    return false
                end
            end,

            extraAttack = function(self)
                for i, enemy in ipairs(enemies) do
                    -- only check the distance for enemies that are actually on the screen
                    if enemy.alive and enemy.x <= love.graphics.getWidth() then
                        local distance = ((enemy.x + enemy.h / 2 - self.x)^2 + (enemy.y + enemy.h / 2 - self.y)^2)^.5
                        if enemy ~= self.target and distance < self.splash_range then
                            -- linear dropoff of damage
                            local percent_damage = self.power * (distance / self.splash_range)
                            enemy:attack(percent_damage)
                        end
                    end
                end
            end,

            update = function(self, dt)
                -- do whatever is necessary and then call super's update

                -- update how much time has passed
                self.elapsed = self.elapsed + dt

                -- update the attack's position and rotation based on the target's position
                -- but only if enough time has passed for the missile to clear the tower
                if self.elapsed > self.time_to_clear then
                    -- move the projectile's position toward the enemy a certain distance every second
                    if self.x > self.target.x + self.target.w / 2 then
                        self.x = self.x - (self.speed * dt)
                    else
                        self.x = self.x + (self.speed * dt)
                    end
                    if self.y > self.target.y + self.target.h / 2 then
                        self.y = self.y - (self.speed * dt)
                    else
                        self.y = self.y + (self.speed * dt)
                    end

                    -- rotation
                    if self.target.x + self.target.w / 2 >= self.x and self.target.y + self.target.h / 2 >= self.y then
                        self.rotation = math.atan2(self.target.y + self.target.h / 2 - self.y, self.target.x + self.target.w / 2 - self.x) -- atan2 takes either (opposite / adjacent) or (opposite, adjacent); the latter is faster
                    elseif self.target.x + self.target.w / 2 < self.x and self.target.y + self.target.h / 2 >= self.y then
                        self.rotation = math.atan2(self.x - (self.target.x + self.target.w / 2), self.target.y + self.target.h / 2 - self.y) + math.rad(90)
                    elseif self.target.x + self.target.w / 2 < self.x and self.target.y + self.target.h / 2 < self.y then
                        self.rotation = math.atan2(self.y - (self.target.y + self.target.h / 2), self.x - (self.target.x + self.target.w / 2)) + math.rad(180)
                    else
                        self.rotation = math.atan2(self.target.x + self.target.w / 2 - self.x, self.y - (self.target.y + self.target.h / 2)) + math.rad(270)
                    end
                else
                    -- otherwise, just move it in a straight line according to the rotation
                    if self.rotation == 0 then
                        self.x = self.x + (self.speed * dt)
                    elseif self.rotation == math.rad(90) then
                        self.y = self.y + (self.speed * dt)
                    elseif self.rotation == math.rad(180) then
                        self.x = self.x - (self.speed * dt)
                    else
                        self.y = self.y - (self.speed * dt)
                    end
                end

                -- this may seem counterintuitive to use model here, but this is called from the main loop, which only has model as an import
                model.attacks.Attack.attackUpdate(self, dt)
            end,

            draw = function (self)
                -- make sure the enemy is still alive
                love.graphics.draw(self.projectile, self.x, self.y, self.rotation)
            end

            }

}

