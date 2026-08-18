---@class DottedPurpleSoul : Soul
---@field isDotPurp boolean Always true. Identifies this soul as the dot-grid movement type
---@field grid_margin number Pixel gap kept between the grid and the arena's edge
---@field base_width number Arena width the base grid size (base_cols x base_rows) was designed for
---@field base_height number Arena height the base grid size (base_cols x base_rows) was designed for
---@field base_cols integer Grid column count when the arena matches base_width
---@field base_rows integer Grid row count when the arena matches base_height
---@field grid_cols integer Actual column count for the current arena size recomputed by updateGridSize().
---@field grid_rows integer Actual row count for the current arena size recomputed by updateGridSize().
---@field grid_col integer Column the soul currently occupies (Range: 0 to grid_cols)
---@field grid_row integer Row the soul currently occupies (Range: 0 to grid_rows)
---@field bufferedDirection string|nil Direction queued during cooldown to be executed once canMove is true again nil if nothing is buffered

local DottedPurpleSoul, super = Class(Soul)

function DottedPurpleSoul:init(x, y, color)
    super.init(self, x, y, color)
    local sprite_to_afterimage = self.sprite

    self.color = ColorUtils.hexToRGB("#C000FF")
    self.allow_focus = false
    self.isDotPurp = true

    self.grid_margin = 15
    self.base_width  = 142
    self.base_height = 142
    self.base_cols   = 3
    self.base_rows   = 3
    self.grid_col = 1
    self.grid_row = 1
    self.Timer = Timer()
    self:addChild(self.Timer)

    self.canMove = true

    -- Game.battle.arena:setShape({ {100, 100}, {100, -100}, {-100, -100}, {-100, 100} })

    self:updateGridSize()

    local long, high = Game.battle.arena:getDotGridPos(self, 1, 1)
    self.Timer:after(0.01, function ()
        self.Timer:tween(0.0025, self, { x = long, y = high }, "in-out-back")
        print("x: " .. self.x .. " y: " .. self.y)
    end)

    self.Timer:every(1/15, function()

        if not sprite_to_afterimage then
            return false
        end
    
        local after_image = AfterImage(sprite_to_afterimage, 0.4, 0.04)

        sprite_to_afterimage:addChild(after_image)
    end)

    self.x, self.y = Game.battle.arena:getDotGridPos(self, self.grid_col, self.grid_row)
    print("Top: " .. Game.battle.arena:getTop() .. "Bottom: " .. Game.battle.arena:getBottom() .. "Left: " .. Game.battle.arena:getLeft() .. "Right: " .. Game.battle.arena:getRight() .. "Center: " .. Game.battle.arena:getCenter())
    self.Timer:after(1, function()  self.canMove = true end)
end

--- <summary>
--- Updates the grid size in the arena (called automatically)
--- placed here in DottedPurpleSoul for convience
--- </summary>
function DottedPurpleSoul:updateGridSize()
    local arena = Game.battle.arena

    self.grid_cols = math.max(1, math.floor(self.base_cols * (arena.width  / self.base_width)  + 0.5))
    self.grid_rows = math.max(1, math.floor(self.base_rows * (arena.height / self.base_height) + 0.5))

    self.grid_col = MathUtils.clamp(self.grid_col, 0, self.grid_cols)
    self.grid_row = MathUtils.clamp(self.grid_row, 0, self.grid_rows)
end

--- <summary> basic debug draw nothing special </summary>
function DottedPurpleSoul:draw()
    super.draw(self)
    if DEBUG_RENDER then
        self.collider:draw(0, 1, 0)
        self.graze_collider:draw(1, 1, 1, 0.33)
    end
end

function DottedPurpleSoul:update()
    super.update(self)

    -- TODO: figure out dynamic rotation bs lmao
end

--- <summary>
--- called whenever super.domovement is ofc (See tryMove for the input buffer)
--- </summary>
function DottedPurpleSoul:doMovement()
    self:updateGridSize()

    local direction = nil
    if Input.pressed("left") then direction = "left"
    elseif Input.pressed("right") then direction = "right"
    elseif Input.pressed("up") then direction = "up"
    elseif Input.pressed("down") then direction = "down"
    end

    if direction then
        if self.canMove then
            self:tryMove(direction)
        else
            self.bufferedDirection = direction
        end
    end
end

--- <summary>
--- Handles input received and buffers it for 0.3 seconds if the soul can't move yet.
--- </summary>
---@param direction string Accepts "up", "down", "left", "right"
function DottedPurpleSoul:tryMove(direction)
    if direction == "left" then
        self.grid_col = math.max(0, self.grid_col - 1)
    elseif direction == "right" then
        self.grid_col = math.min(self.grid_cols, self.grid_col + 1)
    elseif direction == "up" then
        self.grid_row = math.max(0, self.grid_row - 1)
    elseif direction == "down" then
        self.grid_row = math.min(self.grid_rows, self.grid_row + 1)
    end

    local long, high = Game.battle.arena:getDotGridPos(self, self.grid_col, self.grid_row)
    self:spawnMoveAfterImage(direction)
    self.Timer:tween(0.25, self, { x = long, y = high }, "in-out-back")
    self.canMove = false
    self.bufferedDirection = nil

    self.Timer:after(0.3, function()
        self.canMove = true
        if self.bufferedDirection then
            local buffered = self.bufferedDirection
            self.bufferedDirection = nil
            self:tryMove(buffered)
        end
    end)
end

local push_back = {
    left  = { x =  1, y =  0 },
    right = { x = -1, y =  0 },
    up    = { x =  0, y =  1 },
    down  = { x =  0, y = -1 },
}

---@param direction string Accepts "up", "down", "left", "right"
--- <summary>
--- Spawns an after-image facing opposite the direction the soul is moving.
--- Called automatically by `tryMove`, but can also be triggered manually if needed.
--- </summary>
function DottedPurpleSoul:spawnMoveAfterImage(direction)
    local spread = 10
    local back   = 20
    local scale  = 1.4

    local pb = push_back[direction]
    local base_x = pb.x * back
    local base_y = pb.y * back

    local puff_offsets
    if direction == "left" then
        puff_offsets = {
            { x = base_x, y = base_y - spread, flip_x = true, flip_y = true  },
            { x = base_x, y = base_y + spread, flip_x = true, flip_y = false },
        }
    elseif direction == "right" then
        puff_offsets = {
            { x = base_x, y = base_y - spread, flip_x = false, flip_y = true  },
            { x = base_x, y = base_y + spread, flip_x = false, flip_y = false },
        }
    else
        local extra_flip_y = (direction == "down")
        puff_offsets = {
            { x = base_x - spread, y = base_y, flip_x = false, flip_y = extra_flip_y },
            { x = base_x + spread, y = base_y, flip_x = true,  flip_y = extra_flip_y },
        }
    end

    for _, off in ipairs(puff_offsets) do
        local dust = Sprite("effects/soul/spr_pinkdust", self.x + off.x, self.y + off.y)
        dust:setOrigin(0.5, 0.5)
        dust.layer = self.layer
        dust.scale_x = off.flip_x and -scale or scale
        dust.scale_y = off.flip_y and -scale or scale

        self.parent:addChild(dust)

        dust:play(1/15, false, function()
            dust:remove()
        end)
    end
end

return DottedPurpleSoul