---@class PurpleSoul3D : Soul
---@field is3D boolean Always true. Identifies this soul as the ring/depth (3D tunnel) movement type.
---@field grid_margin number Pixel gap kept between the ring grid and the arena's edge.
---@field base_width number Arena width the base ring/layer counts were designed for.
---@field base_height number Arena height the base ring/layer counts were designed for.
---@field base_ring_count integer Number of slots per ring at the base arena size.
---@field base_layers integer Default number of visible depth layers.
---@field grid_depth_scale number Scale multiplier applied per layer of depth (how much smaller each successive ring appears).
---@field grid_slot integer Slot (position around the ring) the soul currently occupies. Wraps via modulo, range 0 to ring_count-1.
---@field grid_layer integer Depth layer the soul currently occupies. Increases as the soul moves "forward"; never decreases.
---@field anim_slot number Animated/eased slot value used for rendering and rotation. Tweens toward grid_slot's equivalent.
---@field anim_layer number Animated/eased layer value used for rendering and depth scale. Tweens toward grid_layer.
---@field layers_ahead_buffer integer Minimum number of empty layers always kept visible ahead of the soul's current layer.
---@field ring_count integer Actual slot count for the current arena size. Set by updateGridSize().
---@field grid_layers integer Actual total layer count currently allocated. Grows as the soul moves forward; never shrinks.
---@field bufferedDirection string|nil Direction queued during move cooldown, executed once canMove is true again.
local PurpleSoul3D, super = Class(Soul)

function PurpleSoul3D:init(x, y, color)
    super.init(self, x, y, color)
    local sprite_to_afterimage = self.sprite

    --- Resets the soul back to the start of the tunnel (layer 0, no animation offset).
    function PurpleSoul3D:resetLayers()
        self.grid_layer  = 0
        self.grid_layers = self.layers_ahead_buffer + 1
        self.anim_layer  = 0
    end

    self.color = ColorUtils.hexToRGB("#C000FF")
    self.allow_focus = false
    self.is3D = true

    self.grid_margin = 15
    self.base_width  = 142
    self.base_height = 142
    self.base_ring_count = 4
    self.base_layers     = 5
    self.grid_depth_scale = 0.6

    -- grid_* = logical position (what the soul actually occupies)
    -- anim_*  = animated position (what's currently drawn, eases toward grid_* over time)
    self.grid_slot  = 0
    self.grid_layer = 0
    self.anim_slot  = 0
    self.anim_layer = 0
    self.layers_ahead_buffer = 1

    self:updateGridSize()
    --self.x, self.y, self.depth_scale = Game.battle.arena:getRing3DPos(self, self.grid_slot, self.grid_layer)

    self.Timer = Timer()
    self:addChild(self.Timer)

    self.canMove = true

    self.Timer:every(1/15, function()
        if not sprite_to_afterimage then
            return false
        end

        local after_image = AfterImage(sprite_to_afterimage, 0.4, 0.04)

        sprite_to_afterimage:addChild(after_image)
    end)

    print("Top: " .. Game.battle.arena:getTop() .. "Bottom: " .. Game.battle.arena:getBottom() .. "Left: " .. Game.battle.arena:getLeft() .. "Right: " .. Game.battle.arena:getRight() .. "Center: " .. Game.battle.arena:getCenter())
    self.Timer:after(1, function()  self.canMove = true end)
end

--- <summary>
--- Recomputes the soul's screen position and depth scale every frame from
--- its current animated slot/layer, since this soul doesn't move via
--- direct x/y translation like the other soul types.
--- </summary>
function PurpleSoul3D:update()
    super.update(self)

    local arena = Game.battle and Game.battle.arena
    if not arena then return end

    local x, y, scale = arena:getRing3DPos(self, self.grid_slot, self.grid_layer)
    self.x, self.y, self.depth_scale = x, y, scale
end

--- <summary>
--- Keeps grid_layers large enough to always show layers_ahead_buffer
--- empty layers beyond the soul's current depth, and wraps grid_slot
--- to stay within a valid ring position.
--- </summary>
function PurpleSoul3D:updateGridSize()
    self.ring_count  = self.base_ring_count
    self.grid_layers = math.max(self.grid_layers or self.base_layers, self.grid_layer + self.layers_ahead_buffer + 1)

    self.grid_slot = self.grid_slot % self.ring_count
end

--- <summary> Basic debug draw, nothing special. </summary>
function PurpleSoul3D:draw()
    super.draw(self)
    if DEBUG_RENDER then
        self.collider:draw(0, 1, 0)
        self.graze_collider:draw(1, 1, 1, 0.33)
    end
end

--- <summary>
--- Reads directional input and starts a move if the soul isn't on
--- cooldown, otherwise buffers it (see tryMove).
--- Up moves the soul forward (deeper into the tunnel) rather than
--- switching rings, since there's no "down" direction in this soul type.
--- </summary>
function PurpleSoul3D:doMovement()
    self:updateGridSize()

    local direction = nil
    if Input.pressed("left") then direction = "left"
    elseif Input.pressed("right") then direction = "right"
    elseif Input.pressed("up") then direction = "forward"
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
--- Executes a move: updates the soul's logical slot/layer, then tweens
--- the animated slot/layer to match (producing the rotate/zoom visual).
--- Buffers one queued direction if called again before the cooldown ends.
--- </summary>
---@param direction string Accepts "left", "right", "forward"
function PurpleSoul3D:tryMove(direction)
    local target_slot, target_layer = self.anim_slot, self.anim_layer

    if direction == "left" then
        self.grid_slot = (self.grid_slot - 1) % self.ring_count
        target_slot = self.anim_slot - 1
    elseif direction == "right" then
        self.grid_slot = (self.grid_slot + 1) % self.ring_count
        target_slot = self.anim_slot + 1
    elseif direction == "forward" then
        self.grid_layer = self.grid_layer + 1
        self.grid_layers = math.max(self.grid_layers, self.grid_layer + self.layers_ahead_buffer + 1)
        target_layer = self.anim_layer + 1
    end

    self.Timer:tween(0.25, self, { anim_slot = target_slot, anim_layer = target_layer }, "in-out-back")

    -- tactile squash feedback since the soul itself no longer translates
    self.scale_x, self.scale_y = 1, 1
    self.Timer:tween(0.12, self, { scale_x = 1.25, scale_y = 0.8 }, "out-quad")
    self.Timer:after(0.12, function()
        self.Timer:tween(0.13, self, { scale_x = 1, scale_y = 1 }, "out-back")
    end)

    self:spawnMoveAfterImage(direction == "forward" and "down" or direction)
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

--- <summary>
--- Spawns an after-image facing opposite the direction the soul is moving.
--- Called automatically by tryMove, but can also be triggered manually if needed.
--- </summary>
---@param direction string Accepts "left", "right", "up"
function PurpleSoul3D:spawnMoveAfterImage(direction)
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
    else -- "up"
        puff_offsets = {
            { x = base_x - spread, y = base_y, flip_x = false, flip_y = false },
            { x = base_x + spread, y = base_y, flip_x = true,  flip_y = false },
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

return PurpleSoul3D