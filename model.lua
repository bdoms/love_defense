-- contains the model classes/objects

love.filesystem.require("constants.lua")

love.filesystem.require("enemies.lua")
love.filesystem.require("attacks.lua")
love.filesystem.require("towers.lua")


-- wrap it in a parent - this emulates being a module, and allows use of dot notation
model = {
    
    -- make the required modules referencible from within model

    enemies = enemies,

    attacks = attacks,

    towers = towers,


    Star = {

            image = love.graphics.newImage("images/star.png"),

            new = function (self, x)
                -- create a new object, and initialize its attributes
                -- these first lines are magic for classes to work in lua
                local o = {}
                setmetatable(o, self)
                self.__index = self

                o.x = x
                o.y = math.random(love.graphics.getHeight() - 80)
                o.angle = math.random(360)
                o.size =  math.random(1, 6) / 10 -- random only takes integers as args
                o.speed = math.random(5, 20) -- pixels / second

                return o
            end,

            update = function (self, dt)
                -- move their x position according to some speed
                self.x = self.x - (self.speed * dt)
                if self.x < 0 then
                    -- reset to other side of screen
                    -- and randomize height so that it looks different
                    self.x = love.graphics.getWidth()
                    self.y = math.random(love.graphics.getHeight() - 80)
                end
            end,

            draw = function (self)
                love.graphics.draw(self.image, self.x, self.y, self.angle, self.size)
            end

           },

    TextMenuItem = {
            font = love.graphics.newFont(love.default_font, 18),

            new = function (self, text, x, y)
                -- create a new object, and initialize its attributes
                -- these first lines are magic for classes to work in lua
                local o = {}
                setmetatable(o, self)
                self.__index = self

                o.text = text
                o.x = x
                o.y = y

                return o
            end,

            update = function(self, dt)
                -- placeholder
            end,

            draw = function(self, selected)
                if selected then
                    love.graphics.setColor(0, 128, 255, 255)
                else
                    love.graphics.setColor(0, 128, 255, 128)
                end
                love.graphics.setFont(self.font)
                love.graphics.draw(self.text, self.x, self.y)
            end
            },

    ImageMenuItem = {
            outline = love.graphics.newImage("images/outline.png"),
            outline_selected = love.graphics.newImage("images/outline_selected.png"),

            new = function (self, image, x, y)
                -- create a new object, and initialize its attributes
                -- these first lines are magic for classes to work in lua
                local o = {}
                setmetatable(o, self)
                self.__index = self

                o.image = image
                o.x = x
                o.y = y
                -- a .turret object gets added immediately after creation here if it exists

                return o
            end,

            draw = function(self, selected)
                if selected then
                    love.graphics.draw(self.outline_selected, self.x, self.y)
                else
                    love.graphics.draw(self.outline, self.x, self.y)
                end
                love.graphics.draw(self.image, self.x, self.y)
                if self.turret then
                    love.graphics.draw(self.turret, self.x, self.y)
                end
            end
            },

    TowerMenuItem = {

            font = love.graphics.newFont(love.default_font, 18),
            vertical_spacing = 80, -- distance between towers appearing on top of each other

            new = function (self, x, y)
                -- create a new object, and initialize its attributes
                -- these first lines are magic for classes to work in lua
                local o = {}
                setmetatable(o, self)
                self.__index = self

                o.towers = {model.towers.PulseTower, model.towers.LaserTower, model.towers.MissileTower}
                o.items = {}
                for i, tower_model in ipairs(o.towers) do
                    o.items[i] = model.ImageMenuItem:new(tower_model.image, x, y - self.vertical_spacing * (i - 1))
                    if tower_model.turret then
                        o.items[i].turret = tower_model.turret
                    end
                end
                o.x = x
                o.y = y
                o.selected_index = 1
                o.vertical_offset = self.vertical_spacing * table.getn(o.towers) -- optimization so this calculation isn't done every draw

                return o
            end,

            update = function(self, dt)
                if love.keyboard.isDown(love.key_up) or love.keyboard.isDown(love.key_w) then
                    self.selected_index = self.selected_index + 1
                    if self.selected_index > table.getn(self.items) then
                        self.selected_index = 1
                    end
                elseif love.keyboard.isDown(love.key_down) or love.keyboard.isDown(love.key_s) then
                    self.selected_index = self.selected_index - 1
                    if self.selected_index < 1 then
                        self.selected_index = table.getn(self.items)
                    end
                end
            end,

            activate = function(self)
                -- these variables (like run, placement_mode, and grid) are globals defined in main.lua
                if run then
                    -- move the tower to the first spot if necessary
                    if self.selected_index ~= 1 then
                        local selected_tower = table.remove(self.towers, self.selected_index)
                        table.insert(self.towers, 1, selected_tower)
                        local selected_item = table.remove(self.items, self.selected_index)
                        table.insert(self.items, 1, selected_item)
                        self.selected_index = 1

                        -- move the y positions around to make sense again
                        for i, item in ipairs(self.items) do
                            item.y = self.y - self.vertical_spacing * (i - 1)
                        end
                    end

                    grid.tower_model = self.towers[self.selected_index]
                    grid.tower = grid.tower_model:new(grid.tower.x, grid.tower.y)
                    placement_mode = true
                end
            end,

            draw = function(self, selected)
                if selected then
                    if placement_mode or not run then
                        self.items[1]:draw(true)
                    else
                        -- draw a background for the towers to appear on
                        love.graphics.setColor(128, 128, 128, 64)
                        love.graphics.rectangle(love.draw_fill, self.x - 40, self.y - (self.vertical_offset - 40), 80, self.vertical_offset)

                        -- draw each of the image items
                        for i, item in ipairs(self.items) do
                            item:draw(self.selected_index == i)
                        end

                        -- draw the values to the right
                        -- background
                        love.graphics.setColor(128, 128, 128, 64)
                        love.graphics.rectangle(love.draw_fill, self.x + 60, self.y - 280, 300, 220)

                        -- text (name, cost, bar titles)
                        local tower = self.towers[self.selected_index]
                        love.graphics.setFont(self.font)
                        love.graphics.setColor(228, 228, 228, 255)
                        love.graphics.draw(tower.name, self.x + 70, self.y - 255)
                        love.graphics.draw("$"..model.towers.Tower.cost(tower), self.x + 305, self.y - 255)
                        love.graphics.setColor(196, 196, 196, 255)
                        love.graphics.draw("Firepower", self.x + 70, self.y - 225)
                        love.graphics.draw("Range", self.x + 70, self.y - 165)
                        love.graphics.draw("Health", self.x + 70, self.y - 105)

                        -- bars
                        local max_pixels = 280 -- number of pixels that represent 100% (width of background - 2 * padding)
                        local max_firepower = 50 -- the largest firepower (power / cooldown)
                        local max_range = 330 -- largest range
                        local max_health = 1200 -- largest health
                        love.graphics.setColor(128, 164, 196, 255)
                        love.graphics.rectangle(love.draw_fill, self.x + 70, self.y - 215, (model.towers.Tower.power(tower) / tower.cooldown) / max_firepower * max_pixels, 20) -- Tower of Power!
                        love.graphics.rectangle(love.draw_fill, self.x + 70, self.y - 155, model.towers.Tower.range(tower) / max_range * max_pixels, 20)
                        love.graphics.rectangle(love.draw_fill, self.x + 70, self.y - 95, model.towers.Tower.max_health(tower) / max_health * max_pixels, 20)
                    end
                else
                    self.items[1]:draw(false)
                end
            end
            },

    Menu = {
            image = love.graphics.newImage("images/interface_bg.png"),
            update_time = .07, -- time it takes in seconds for the interface to update
                             --     without this, the interface updates TOO FAST to be useful

            new = function (self, x, y, w)
                -- create a new object, and initialize its attributes
                -- these first lines are magic for classes to work in lua
                local o = {}
                setmetatable(o, self)
                self.__index = self

                o.x = x -- horizontal center of the menu
                o.y = y -- vertical center of the menu
                o.w = w -- width of the menu

                o.items = {}
                o.selected_index = 3
                o.last_update = 0 -- time since last selected index change

                -- construct the individual items of the menu
                local item_y = o.y + 7
                o.items[1] = model.TextMenuItem:new("Quit", 100, item_y)
                o.items[1].activate = function(self) love.system.exit() end
                o.items[2] = model.TextMenuItem:new("Restart Level", 240, item_y)
                o.items[2].activate = function(self) love.system.restart() end
                o.items[3] = model.TextMenuItem:new("Start Wave", 480, item_y)
                o.items[3].activate = function(self) if run then run_wave = true end end -- defined in main.lua
                o.items[4] = model.TowerMenuItem:new(720, item_y - 5) -- has a built-in activate method
                o.items[5] = model.TextMenuItem:new("Upgrade Tower", 900, item_y)
                o.items[5].activate = function(self)
                    if run then
                        if table.getn(towers) > 0 then
                            -- default to first tower's location
                            upgrade.cursor_x = towers[1].x
                            upgrade.cursor_y = towers[1].y
                        end
                        upgrade_mode = true
                    end
                end

                return o
            end,

            update = function(self, dt)
                if self.last_update >= self.update_time then
                    if love.keyboard.isDown(love.key_return) then
                        self.items[self.selected_index]:activate()
                    elseif love.keyboard.isDown(love.key_right) or love.keyboard.isDown(love.key_d) then
                        self.selected_index = self.selected_index + 1
                        if self.selected_index > table.getn(self.items) then
                            self.selected_index = 1
                        end
                    elseif love.keyboard.isDown(love.key_left) or love.keyboard.isDown(love.key_a) then
                        self.selected_index = self.selected_index - 1
                        if self.selected_index < 1 then
                            self.selected_index = table.getn(self.items)
                        end
                    elseif love.keyboard.isDown(love.key_escape) then
                        love.system.exit()
                    else
                        self.items[self.selected_index]:update()
                    end
                    self.last_update = 0
                else
                    self.last_update = self.last_update + dt
                end
            end,

            draw = function(self)
                -- draw the background first
                -- args for this are: (img, x, y, angle, x scale, y scale)
                love.graphics.draw(self.image, self.x, self.y, 0, self.w, 1)
                -- then each of the menu items, passing in whether it is selected or not
                for i, item in ipairs(self.items) do
                    item:draw(self.selected_index == i)
                end
            end
            },

    Grid = {

            update_time = .1,

            new = function (self, x, y, w, h)
                -- create a new object, and initialize its attributes
                -- these first lines are magic for classes to work in lua
                local o = {}
                setmetatable(o, self)
                self.__index = self

                o.x = x
                o.y = y
                o.w = w
                o.h = h

                o.last_update = 0
                o.tower_model = model.towers.PulseTower -- default
                o.tower = o.tower_model:new(o.x + o.w / 2 - GRID_SIZE / 2, o.y + o.h / 2 - GRID_SIZE / 2) -- close to center
                o.obstructed = false -- the tower is over something so it can't build there

                return o
            end,

            update = function(self, dt)
                if self.last_update >= self.update_time then
                    if love.keyboard.isDown(love.key_backspace) then
                        placement_mode = false

                    elseif love.keyboard.isDown(love.key_return) then
                        if not self.obstructed then
                            if bank >= self.tower:cost() then
                                -- put a new tower down here
                                bank = bank - self.tower:cost()
                                table.insert(towers, self.tower_model:new(self.tower.x, self.tower.y))
                                love.audio.play(self.tower_model.build_sound)
                                placement_mode = false
                                -- leave with obstructed being true, since there's a tower there now
                                self.obstructed = true
                            else
                                -- flash red to indicate they can't do it
                                self.obstructed = true
                            end
                        end

                    else

                        if love.keyboard.isDown(love.key_up) or love.keyboard.isDown(love.key_w) then
                            if self.tower.y > self.y + GRID_SIZE then
                                self.tower.y = self.tower.y - GRID_SIZE
                            end
                        end
                        if love.keyboard.isDown(love.key_right) or love.keyboard.isDown(love.key_d) then
                            if self.tower.x < self.x + self.w - GRID_SIZE then
                                self.tower.x = self.tower.x + GRID_SIZE
                            end
                        end
                        if love.keyboard.isDown(love.key_down) or love.keyboard.isDown(love.key_s) then
                            if self.tower.y < self.y + self.h - GRID_SIZE then
                                self.tower.y = self.tower.y + GRID_SIZE
                            end
                        end
                        if love.keyboard.isDown(love.key_left) or love.keyboard.isDown(love.key_a) then
                            if self.tower.x > self.x + GRID_SIZE then
                                self.tower.x = self.tower.x - GRID_SIZE
                            end
                        end

                        -- detect obstruction after a possible move
                        self.obstructed = false
                        for i, tower in ipairs(towers) do
                            local distance = ((tower.x - self.tower.x)^2 + (tower.y - self.tower.y)^2)^.5
                            if distance <= GRID_SIZE * 1.5 then
                                self.obstructed = true
                                break
                            end
                        end

                    end

                    self.last_update = 0
                else
                    self.last_update = self.last_update + dt
                end
            end,

            draw = function(self)
                -- draw transparent bg
                love.graphics.setColor(128, 128, 128, 96)
                love.graphics.rectangle(love.draw_fill, self.x, self.y, self.w, self.h)

                -- draw lines
                love.graphics.setColor(164, 164, 164, 196)
                love.graphics.setLineWidth(2)
                -- horizontal
                for line_y=self.y, self.y + self.h, GRID_SIZE do
                    love.graphics.line(self.x, line_y, self.x + self.w, line_y)
                end
                -- vertical
                for line_x=self.x, self.x + self.w, GRID_SIZE do
                    love.graphics.line(line_x, self.y, line_x, self.y + self.h)
                end

                -- draw where the tower currently is
                if self.obstructed then
                    love.graphics.setColor(196, 96, 128, 196)
                else
                    love.graphics.setColor(128, 164, 196, 196)
                end
                love.graphics.rectangle(love.draw_fill, self.tower.x - GRID_SIZE, self.tower.y - GRID_SIZE, self.tower.w, self.tower.h)
                self.tower:draw()
            end
            },

    Upgrade = {

            outline = love.graphics.newImage("images/outline_selected.png"),
            font = love.graphics.newFont(love.default_font, 18),
            update_time = .1,

            new = function (self, x, y, w, h)
                -- create a new object, and initialize its attributes
                -- these first lines are magic for classes to work in lua
                local o = {}
                setmetatable(o, self)
                self.__index = self

                -- limits of the cursor space (the grid coords and dimensions)
                o.x = x
                o.y = y
                o.w = w
                o.h = h

                -- default somewhere near the middle of the grid
                o.cursor_x = o.x + o.w / 2 - GRID_SIZE / 2
                o.cursor_y = o.y + o.h / 2 - GRID_SIZE / 2

                o.last_update = 0
                o.not_enough_funds = false -- if they can afford it or not
                o.tower = nil -- the tower it's over right now

                return o
            end,

            update = function(self, dt)
                if self.last_update >= self.update_time then
                    if love.keyboard.isDown(love.key_backspace) then
                        upgrade_mode = false

                    elseif love.keyboard.isDown(love.key_return) then
                        if self.tower then
                            local next_level = self.tower.level + 1
                            if next_level <= table.getn(self.tower.stats) then
                                -- tower is upgradeable
                                local tower_stats = self.tower.stats[next_level]
                                if bank >= tower_stats.cost then
                                    -- upgrade the tower
                                    bank = bank - tower_stats.cost
                                    self.tower.level = next_level
                                    love.audio.play(self.tower.build_sound)
                                    -- upgrade_mode = false -- assume that the user wants to upgrade more, for now they must manually back out
                                else
                                    -- flash red to indicate they can't afford it
                                    self.not_enough_funds = true
                                end
                            else
                                -- flash red to indicate they can't upgrade further
                                self.not_enough_funds = true
                            end
                        end
                    else

                        if love.keyboard.isDown(love.key_up) or love.keyboard.isDown(love.key_w) then
                            if self.cursor_y > self.y + GRID_SIZE then
                                self.cursor_y = self.cursor_y - GRID_SIZE
                            end
                        end
                        if love.keyboard.isDown(love.key_right) or love.keyboard.isDown(love.key_d) then
                            if self.cursor_x < self.x + self.w - GRID_SIZE then
                                self.cursor_x = self.cursor_x + GRID_SIZE
                            end
                        end
                        if love.keyboard.isDown(love.key_down) or love.keyboard.isDown(love.key_s) then
                            if self.cursor_y < self.y + self.h - GRID_SIZE then
                                self.cursor_y = self.cursor_y + GRID_SIZE
                            end
                        end
                        if love.keyboard.isDown(love.key_left) or love.keyboard.isDown(love.key_a) then
                            if self.cursor_x > self.x + GRID_SIZE then
                                self.cursor_x = self.cursor_x - GRID_SIZE
                            end
                        end

                        -- detect being over a tower after a possible move
                        self.tower = nil
                        for i, tower in ipairs(towers) do
                            if self.cursor_x == tower.x and self.cursor_y == tower.y then
                                self.tower = tower
                                break
                            end
                        end

                        -- reset after a potential flash
                        self.not_enough_funds = false
                    end

                    self.last_update = 0
                else
                    self.last_update = self.last_update + dt
                end
            end,

            draw = function(self)
                -- draw transparent bg
                love.graphics.setColor(128, 128, 128, 96)
                love.graphics.rectangle(love.draw_fill, self.x, self.y, self.w, self.h)

                -- draw lines
                love.graphics.setColor(164, 164, 164, 196)
                love.graphics.setLineWidth(2)
                -- horizontal
                for line_y=self.y, self.y + self.h, GRID_SIZE do
                    love.graphics.line(self.x, line_y, self.x + self.w, line_y)
                end
                -- vertical
                for line_x=self.x, self.x + self.w, GRID_SIZE do
                    love.graphics.line(line_x, self.y, line_x, self.y + self.h)
                end

                if self.tower then
                    local next_level = self.tower.level + 1
                    if next_level <= table.getn(self.tower.stats) then
                        -- tower is upgradeable
                        local tower_stats = self.tower.stats[next_level]
                        -- draw where the tower's radius will expand to
                        love.graphics.setColor(255, 196, 128, 64)
                        love.graphics.circle(love.draw_fill, self.tower.x, self.tower.y, tower_stats.range, 32) -- last is the number of points for the circle (default 10)

                        local left_edge = self.x - 350
                        local left_padding = left_edge + 10

                        -- the stuff below shares a lot with TowerMenuItem.draw, consider combining them somehow
                        -- draw the values to the right
                        -- background
                        love.graphics.setColor(128, 128, 128, 196)
                        love.graphics.rectangle(love.draw_fill, left_edge, self.y, 300, 250)

                        -- text (name, cost, bar titles)
                        love.graphics.setFont(self.font)
                        love.graphics.setColor(228, 228, 228, 255)
                        love.graphics.draw("Upgrade Level "..self.tower.level.." "..self.tower.name, left_padding, self.y + 25)
                        love.graphics.draw("$"..tower_stats.cost, left_padding, self.y + 55)
                        love.graphics.setColor(196, 196, 196, 255)
                        love.graphics.draw("Firepower", left_padding, self.y + 85)
                        love.graphics.draw("Range", left_padding, self.y + 145)
                        love.graphics.draw("Health", left_padding, self.y + 205)

                        -- bars
                        local max_pixels = 280 -- number of pixels that represent 100% (width of background - 2 * padding)
                        local max_firepower = 50 -- the largest firepower (power / cooldown)
                        local max_range = 330 -- largest range
                        local max_health = 1200 -- largest health

                        -- next level bars
                        love.graphics.setColor(128, 196, 164, 255)
                        love.graphics.rectangle(love.draw_fill, left_padding, self.y + 95, (tower_stats.power / self.tower.cooldown) / max_firepower * max_pixels, 20)
                        love.graphics.rectangle(love.draw_fill, left_padding, self.y + 155, tower_stats.range / max_range * max_pixels, 20)
                        love.graphics.rectangle(love.draw_fill, left_padding, self.y + 215, tower_stats.health / max_health * max_pixels, 20)

                        -- current level bars
                        love.graphics.setColor(128, 164, 196, 255)
                        love.graphics.rectangle(love.draw_fill, left_padding, self.y + 95, (self.tower:power() / self.tower.cooldown) / max_firepower * max_pixels, 20) -- Tower of Power!
                        love.graphics.rectangle(love.draw_fill, left_padding, self.y + 155, self.tower:range() / max_range * max_pixels, 20)
                        love.graphics.rectangle(love.draw_fill, left_padding, self.y + 215, self.tower:max_health() / max_health * max_pixels, 20)

                    else
                        -- display something about max level
                        -- background
                        love.graphics.setColor(128, 128, 128, 64)
                        love.graphics.rectangle(love.draw_fill, self.x - 350, self.y, 300, 250)

                        -- text (name, cost, bar titles)
                        love.graphics.setFont(self.font)
                        love.graphics.setColor(228, 228, 228, 255)
                        love.graphics.draw(self.tower.name.." - MAX LEVEL!", self.x - 340, self.y + 25)
                    end
                end

                -- draw the surrounding select box
                if self.tower then
                    self.tower:draw()
                end

                -- flash red if they can't afford it
                if self.not_enough_funds then
                    love.graphics.setColor(196, 96, 128, 196)
                    love.graphics.rectangle(love.draw_fill, self.tower.x - GRID_SIZE, self.tower.y - GRID_SIZE, self.tower.w, self.tower.h)
                end

                -- outer select box
                love.graphics.draw(self.outline, self.cursor_x, self.cursor_y)
            end
            },

    Level = {
            win_sound = love.audio.newSound("sounds/level_win.wav"),
            lose_sound = love.audio.newSound("sounds/level_lose.wav"),
            fade_rate = .1, -- % / s
            update_time = .2,

            new = function (self)
                -- create a new object, and initialize its attributes
                -- these first lines are magic for classes to work in lua
                local o = {}
                setmetatable(o, self)
                self.__index = self

                o.last_update = 0

                -- love can't handle 2 "music" pieces at once (or different music volumes ) - so we use sounds instead
                o.setup_music = love.audio.newSound("sounds/level_2_setup.ogg")
                o.setup_volume = 1
                
                o.battle_music = love.audio.newSound("sounds/level_2_battle.ogg")
                o.battle_volume = 0
                o.battle_music:setVolume(0) -- start this one at silent

                love.audio.play(o.setup_music, 0) -- 0 means loop forever
                love.audio.play(o.battle_music, 0)

                o.waves = {} -- wave data for this level

                local first_wave = {}
                local spacing = 60 -- pixels between enemies
                local total = 10 -- number of enemies
                for i=1, total, 1 do
                    local enemy = model.enemies.Enemy:new(love.graphics.getWidth() + (i * spacing))
                    table.insert(first_wave, enemy)
                end
                table.insert(o.waves, first_wave)

                -- second verse, same as the first (for now)
                local second_wave = {}
                for i=1, total, 1 do
                    local enemy = model.enemies.Enemy:new(love.graphics.getWidth() + (i * spacing))
                    table.insert(second_wave, enemy)
                end
                table.insert(o.waves, second_wave)

                o.active_wave = 1 -- index of which wave we're on

                return o
            end,

            update = function(self, dt)
                -- this is defined in main.lua
                if run_wave and not paused then
                    if self.setup_volume > 0 then
                        -- change the volume a little each update
                        self.setup_volume = self.setup_volume - (self.fade_rate * dt)
                        self.setup_music:setVolume(self.setup_volume)
                        self.battle_volume = self.battle_volume + (self.fade_rate * dt)
                        self.battle_music:setVolume(self.battle_volume)
                    end
                end
                if self.last_update >= self.update_time then
                    if run and love.keyboard.isDown(love.key_p) then
                        if paused then
                            love.audio.setVolume(1)
                            paused = false
                        else
                            love.audio.setVolume(.2)
                            paused = true
                        end
                        self.last_update = 0
                    end
                else
                    self.last_update = self.last_update + dt
                end
            end,

            draw = function(self)
                love.graphics.setColor(128, 164, 196, 255)
                love.graphics.setFont(normal_font)
                local wave_text = "WAVE " .. self.active_wave .. "/" .. table.getn(self.waves)
                love.graphics.draw(wave_text, love.graphics.getWidth() - 435, 36)

                if paused then
                    love.graphics.setColor(128, 128, 128, 128)
                    love.graphics.rectangle(love.draw_fill, 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
                    love.graphics.setFont(large_font)
                    love.graphics.setColor(228, 228, 255, 255)
                    love.graphics.drawf("PAUSED", 0, love.graphics.getHeight() / 2 - 16, love.graphics.getWidth() + 8, love.align_center)
                end
            end,

            win = function(self)
                love.audio.stop()
                love.audio.play(self.win_sound)
            end,

            lose = function(self)
                love.audio.stop()
                love.audio.play(self.lose_sound)
            end
            }

}
