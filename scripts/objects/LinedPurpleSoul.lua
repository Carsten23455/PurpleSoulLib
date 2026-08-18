---@class LinedPurpleSoul : Soul

---@field isUTPurple boolean Always true. Identifies this soul as the horizontal-lane movement type.
---@field lane_index integer Index (1-based) of the lane the soul currently occupies, into the array from getUTPurpleLanes().
---@field target_y number World Y position the soul is easing toward — the Y of the current lane.
---@field moving_x number Horizontal input direction from the last doMovement call (-1, 0, or 1).
---@field moving_y number Current vertical velocity toward target_y (0 once the lane snap is complete).
local LinedPurpleSoul, super = Class(Soul)

function LinedPurpleSoul:init(x, y, color)
    super.init(self, x, y, color)
    -- Game.battle.arena:setShape({ {200, 200}, {200, -200}, {-200, -200}, {-200, 200} })
    self.color = ColorUtils.hexToRGB("#C000FF")

    self.allow_focus = false
    self.isUTPurple = true

    -- Start on the middle lane (rounds up for even lane counts)
    local lanes = Game.battle.arena:getUTPurpleLanes()
    self.lane_index = math.ceil(#lanes / 2)
    self.target_y = lanes[self.lane_index]
end

--- <summary> Basic debug draw, nothing special. </summary>
function LinedPurpleSoul:draw()
    super.draw(self)

    if DEBUG_RENDER then
        self.collider:draw(0, 1, 0)
        self.graze_collider:draw(1, 1, 1, 0.33)
    end
end

--- <summary>
--- Moves the soul freely left/right within the current lane and switches
--- lanes on up/down input vertical movement eases toward the target lane's
--- Y rather than snapping instantly
--- </summary>
function LinedPurpleSoul:doMovement()
    local speed = self.speed
    if self.allow_focus then
        if Input.down("cancel") then speed = speed / 2 end
    end

    -- Free horizontal movement unrelated to lanes
    local move_x = 0
    if Input.down("left") then move_x = move_x - 1 end
    if Input.down("right") then move_x = move_x + 1 end

    -- Re-clamp in case the arena's lane count changed (e.g. resize) since last frame
    local lanes = Game.battle.arena:getUTPurpleLanes()
    self.lane_index = MathUtils.clamp(self.lane_index, 1, #lanes)

    -- Switch lanes one at a time on discrete up/down presses
    if Input.pressed("up") then
        self.lane_index = math.max(1, self.lane_index - 1)
    end
    if Input.pressed("down") then
        self.lane_index = math.min(#lanes, self.lane_index + 1)
    end

    self.target_y = lanes[self.lane_index]

    -- Apply horizontal movement cancel if blocked (e.g. hit arena edge)
    self.moving_x = move_x
    if move_x ~= 0 then
        if not self:move(move_x, 0, speed * DTMULT) then
            self.moving_x = 0
        end
    end

    -- Ease vertically toward the target lane rather than snapping instantly
    local dy = self.target_y - self.y
    if math.abs(dy) > 0.5 then
        local vy = MathUtils.sign(dy) * math.min(math.abs(dy), speed * 4 * DTMULT)
        self.moving_y = vy
        self:move(0, vy, 1)
    else
        -- Close enough — snap exactly onto the lane and stop easing
        self.y = self.target_y
        self.moving_y = 0
    end
end

return LinedPurpleSoul