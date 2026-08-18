---@class Arena

local Arena, super = HookSystem.hookScript(Arena)

function Arena:init(x, y, shape)
    super.init(self, x, y, shape)
end

--- <summary>
--- Renders the active soul-movement overlay for the current battle if any
--- Exactly one branch runs per wave chosen by which flag is set on Game.battle.soul:
---   isUTPurple -> horizontal lane guide lines (see LinedPurpleSoul)
---   isDotPurp  -> a fixed dot grid the soul snaps between (see DottedPurpleSoul)
---   is3D       -> a rotating ring/orbit grid drawn as concentric circles receding into the screen
--- If none of these flags are set only the base arena (super.draw) is drawn
--- </summary>
function Arena:draw()
    super.draw(self)

    if Game.battle.soul and Game.battle.soul.isUTPurple then
        -- Draw horizontal lane lines across the full arena width.
        love.graphics.setColor(170/255, 0, 170/255)
        love.graphics.setLineWidth(1)

        for _, ly in ipairs(self:getUTPurpleLaneLocalYs()) do
            love.graphics.line(0, ly, self.width, ly)
        end

        love.graphics.setColor(Game.battle.soul.color)

    elseif Game.battle.soul and Game.battle.soul.isDotPurp then
        -- Draw the dot grid: grid lines first, then a dot at every intersection.
        love.graphics.setColor(170/255, 0, 170/255)
        love.graphics.setLineWidth(0.1125)

        local left, top, cell_size, cols, rows = self:getDotGridLocalCells(Game.battle.soul)
        local right, bottom = left + cell_size * cols, top + cell_size * rows

        -- Horizontal grid lines
        for i = 0, rows do
            local y = top + i * cell_size
            love.graphics.line(left, y, right, y)
        end
        -- Vertical grid lines
        for i = 0, cols do
            local x = left + i * cell_size
            love.graphics.line(x, top, x, bottom)
        end
        -- Dots at every grid intersection
        for i = 0, cols do
            local x = left + i * cell_size
            for j = 0, rows do
                local y = top + j * cell_size
                love.graphics.circle("fill", x, y, 0.1125)
            end
        end

        love.graphics.setColor(1, 1, 1, 1)

    elseif Game.battle.soul and Game.battle.soul.is3D then
        -- Ring grid: several concentric "layers" of rings around a shared center (vp_x, vp_y)
        -- each layer scaled smaller than the one before it (g.k) to fake depth/perspective
        -- The whole thing rotates as the soul moves between slots on the current ring

        -- Clip all drawing below to the arena's bounds
        love.graphics.stencil(function()
            love.graphics.rectangle("fill", 0, 0, self.width, self.height)
        end, "replace", 1)
        love.graphics.setStencilTest("greater", 0)

        love.graphics.setColor(170/255, 0, 170/255)

        local soul = Game.battle.soul
        local g = self:getRing3DLocalCells(soul)
        local anim_layer = soul.anim_layer
        -- Rotate the whole grid around its center to visually reflect the soul's current slot
        local angle = -(2 * math.pi / g.ring_count) * soul.anim_slot

        love.graphics.push()
        love.graphics.translate(g.vp_x, g.vp_y)
        love.graphics.rotate(angle)
        love.graphics.translate(-g.vp_x, -g.vp_y)

        -- Layers scaled below/above these thresholds are skipped entirely (too small/large to matter)
        local MIN_VISIBLE_SCALE = 0.02
        local MAX_VISIBLE_SCALE = 3.0

        -- Draw from the farthest layer to the nearest so nearer rings draw on top
        for layer = g.layers - 1, 0, -1 do
            local is_current = (layer == soul.grid_layer)
            local rel_layer  = layer - anim_layer
            local scale      = g.k ^ rel_layer -- depth scale relative to the soul's current layer

            if scale >= MIN_VISIBLE_SCALE and scale <= MAX_VISIBLE_SCALE then
                local radius = g.max_radius * scale

                -- The ring outline thicker if this is the soul's current layer
                love.graphics.setLineWidth(is_current and 3 or 1)
                love.graphics.circle("line", g.vp_x, g.vp_y, radius)

                -- Connector lines from this ring's slots down to the next ring inward
                -- giving the "receding tunnel" look skipped if the next ring is too small to see
                if layer > 0 then
                    local next_scale = g.k ^ (rel_layer - 1)
                    if next_scale >= MIN_VISIBLE_SCALE then
                        love.graphics.setLineWidth(1)
                        for slot = 0, g.ring_count - 1 do
                            local x1, y1 = self:getRing3DBasePos(g, slot, layer, anim_layer)
                            local x2, y2 = self:getRing3DBasePos(g, slot, layer - 1, anim_layer)
                            love.graphics.line(x1, y1, x2, y2)
                        end
                    end
                end

                -- A dot at each slot around this ring the soul's own slot is drawn larger
                for slot = 0, g.ring_count - 1 do
                    local x, y, node_scale = self:getRing3DBasePos(g, slot, layer, anim_layer)
                    local r = 4 * node_scale
                    if is_current and slot == soul.grid_slot then
                        r = r * 1.6
                    end
                    love.graphics.circle("fill", x, y, r)
                end
            end
        end

        love.graphics.pop()

        love.graphics.setStencilTest()
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

--- <summary>
--- called internally and gets the local positions of each line
--- </summary>
function Arena:getUTPurpleLaneLocalYs()
    local baseHeight = 142
    local baseLanes  = 3
    local margin     = 20

    local numLanes = math.max(1, math.floor(baseLanes * (self.height / baseHeight) + 0.5))

    local top, bottom = margin, self.height - margin
    local lanes = {}

    if numLanes == 1 then
        lanes[1] = (top + bottom) / 2
    else
        local spacing = (bottom - top) / (numLanes - 1)
        for i = 0, numLanes - 1 do
            lanes[i + 1] = top + i * spacing
        end
    end
    return lanes
end

---@return number[] lanes A list of world-space Y positions for each lane
function Arena:getUTPurpleLanes()
    local top = self:getTop()
    local worldLanes = {}
    for i, localY in ipairs(self:getUTPurpleLaneLocalYs()) do
        worldLanes[i] = top + localY
    end
    return worldLanes
end

--- Called internally
---@return number left the left side of the arena
---@return number top the top of the arena
---@return number cell_size the size between each column and row
---@return number cols the number of columns
---@return number rows the number of rows
function Arena:getDotGridLocalCells(soul)
    local margin = soul.grid_margin
    local cols, rows = soul.grid_cols, soul.grid_rows

    local avail_w = self.width - margin * 2
    local avail_h = self.height - margin * 2

    local cell_size = math.min(avail_w / cols, avail_h / rows)
    local grid_w = cell_size * cols
    local grid_h = cell_size * rows

    local left = (self.width - grid_w) / 2
    local top  = (self.height - grid_h) / 2

    return left, top, cell_size, cols, rows
end

---@param soul Soul the current soul
---@param col integer the column of the dot you want (Range: 0 to grid_cols)
---@param row integer the row of the dot you want (Range: 0 to grid_rows)
---@return number x the x position of the arena for the specified column and row
---@return number y the y position of the arena for the specified column and row
function Arena:getDotGridPos(soul, col, row)
    local left, top, cell_size = self:getDotGridLocalCells(soul)
    local worldLeft = self:getLeft()
    local worldTop  = self:getTop()

    return worldLeft + left + col * cell_size, worldTop + top + row * cell_size
end

--- <summary>
--- Works out the basic shape of the ring grid: how big it is where its
--- center is and how much smaller each ring gets the further back it is
--- tthe other getRing3D* functions all use this instead of recalculating
--- it themselves
--- </summary>
---@param soul PurpleSoul3D The soul whose settings (ring count, layers, etc) define the grid
---@return table g A table with everything needed to draw the grid: ring_count, layers, k (shrink amount per layer), max_radius, vp_x, vp_y (center point)
function Arena:getRing3DLocalCells(soul)
    local margin = soul.grid_margin
    local ring_count, layers = soul.ring_count, soul.grid_layers
    local k = soul.grid_depth_scale or 0.8

    local max_radius = math.min(self.width, self.height) / 2 - margin

    return {
        ring_count = ring_count, layers = layers, k = k,
        max_radius = max_radius,
        vp_x = self.width / 2, vp_y = self.height / 2,
    }
end

--- <summary>
--- Finds where a ring dot should be drawn, positioned relative to the
--- soul itself (so the soul is always treated as slot 0, layer 0) his
--- is what's used to actually move the soul
--- </summary>
---@param g table The grid info from getRing3DLocalCells
---@param slot integer Which ring position we're finding
---@param layer integer How deep in the tunnel we're finding
---@param current_slot integer The soul's current position (used as the center point)
---@param current_layer integer The soul's current depth (used as the zero point for depth)
---@return number x
---@return number y
---@return number scale How small/big this point is compared to the soul's depth
function Arena:getRing3DLocalPos(g, slot, layer, current_slot, current_layer)
    local rel_layer = layer - current_layer
    local scale  = g.k ^ rel_layer
    local radius = g.max_radius * scale

    local rel_slot = slot - current_slot
    local theta = (2 * math.pi / g.ring_count) * rel_slot + math.pi / 2

    local x = g.vp_x + radius * math.cos(theta)
    local y = g.vp_y + radius * math.sin(theta)
    return x, y, scale
end

--- <summary>
--- Finds where a ring dot should be drawn WITHOUT rotating it for
--- the soul's current position used for drawing the whole grid since
--- the drawing code rotates everything itself afterward instead
--- </summary>
---@param g table The grid info from getRing3DLocalCells
---@param slot integer Which ring position we're finding
---@param layer integer How deep in the tunnel we're finding
---@param anim_layer number The soul's current (animated) depth used as the zero point
---@return number x
---@return number y
---@return number scale How small/big this point is compared to the soul"s depth
function Arena:getRing3DBasePos(g, slot, layer, anim_layer)
    local rel_layer = layer - anim_layer
    local scale  = g.k ^ rel_layer
    local radius = g.max_radius * scale

    local theta = (2 * math.pi / g.ring_count) * slot + math.pi / 2
    local x = g.vp_x + radius * math.cos(theta)
    local y = g.vp_y + radius * math.sin(theta)
    return x, y, scale
end

--- <summary>
--- Same as getRing3DLocalPos butt returns a real world position (on
--- screen) instead of a position relative to the arena this is what
--- actually moves the soul each frame
--- </summary>
---@param soul PurpleSoul3D The soul to position.
---@param slot integer Which ring position we're finding.
---@param layer integer How deep in the tunnel we're finding.
---@return number x
---@return number y
---@return number scale
function Arena:getRing3DPos(soul, slot, layer)
    local g = self:getRing3DLocalCells(soul)
    local x, y, scale = self:getRing3DLocalPos(g, slot, layer, soul.grid_slot, soul.grid_layer)
    return self:getLeft() + x, self:getTop() + y, scale
end

--- <summary>
--- Same idea as getRing3DPos but also spins the point around to match
--- wherever the soul is currently animating tto not currently used by
--- the drawing code (it rotates a different way), kept here in case
--- something needs a rotated position without using LÖVE's rotate function.
--- (see batlle/wave/3DBombWall.lua)
--- </summary>
---@param soul PurpleSoul3D The soul to position
---@param slot integer Which ring position we're finding
---@param layer integer How deep in the tunnel we're finding
---@return number x
---@return number y
---@return number scale
function Arena:getRing3DAnimPos(soul, slot, layer)
    local g = self:getRing3DLocalCells(soul)
    local x, y, scale = self:getRing3DBasePos(g, slot, layer, soul.anim_layer)

    -- spin the point around the center to match the soul's current rotation
    local angle = -(2 * math.pi / g.ring_count) * soul.anim_slot
    local dx, dy = x - g.vp_x, y - g.vp_y
    local rx = g.vp_x + dx * math.cos(angle) - dy * math.sin(angle)
    local ry = g.vp_y + dx * math.sin(angle) + dy * math.cos(angle)

    return self:getLeft() + rx, self:getTop() + ry, scale
end

return Arena