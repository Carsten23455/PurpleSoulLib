local Basic, super = Class(Wave)
-- this entire class is for testing its uh evil lmao (direct copy paste frpm my fangame lol)
function Basic:init()
    super.init(self)
    self.time = 20
    self.spawned_layers = {}
end

function Basic:onStart()
    Game.battle:swapSoul(PurpleSoul3D())

    self.timer:every(0.6, function()
        self:spawnRing3DBullet()
    end)
end

function Basic:spawnRing3DBullet()
    local soul = Game.battle.soul
    local arena = Game.battle.arena
    if not (soul and soul.is3D and arena) then return end

    local spawn_layer = soul.grid_layer + 2

    if self.spawned_layers[spawn_layer] then
        return
    end
    self.spawned_layers[spawn_layer] = true

    local safe_slot = love.math.random(0, soul.ring_count - 1)

    for slot = 0, soul.ring_count - 1 do
        if slot ~= safe_slot then
            local x, y = arena:getRing3DAnimPos(soul, slot, spawn_layer)

            local bullet = self:spawnBullet("bomb", x, y, slot, spawn_layer)
            bullet.remove_offscreen = false
        end
    end
end

function Basic:update()
    super.update(self)
end

function Basic:draw()
    local arena = Game.battle and Game.battle.arena
    local soul  = Game.battle and Game.battle.soul

    if arena and soul and soul.is3D then
        love.graphics.stencil(function()
            love.graphics.rectangle("fill", arena:getLeft(), arena:getTop(), arena.width, arena.height)
        end, "replace", 1)
        love.graphics.setStencilTest("greater", 0)

        super.draw(self)

        love.graphics.setStencilTest()
    else
        super.draw(self)
    end
end

return Basic