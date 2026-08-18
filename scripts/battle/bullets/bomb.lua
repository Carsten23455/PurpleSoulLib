---@class bomb : Bullet
local bomb, super = Class(Bullet)

function bomb:init(x, y, slot, layer)
    super.init(self, x, y, "enemies/pink/pinkbomb_1")
    self.remove_offscreen = false

    self.ring_slot = slot
    self.ring_layer = layer
end

function bomb:update()
    local arena = Game.battle and Game.battle.arena
    local soul  = Game.battle and Game.battle.soul

    if arena and soul and soul.is3D then
        local x, y, scale = arena:getRing3DAnimPos(soul, self.ring_slot, self.ring_layer)
        self.x, self.y = x, y
        self.scale_x, self.scale_y = scale, scale

        local left, top = arena:getLeft(), arena:getTop()
        local margin = 4
        local inside = x >= left + margin and x <= left + arena.width - margin
                   and y >= top + margin and y <= top + arena.height - margin

        self.visible = inside
    end

    super.update(self)
end

return bomb