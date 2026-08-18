local Battle, super = HookSystem.hookScript(Battle)

function Battle:update()
    super.update(self)
    
  --  local soul = self.soul
--    local hide = soul and soul.is3D or false

    --for _, battler in ipairs(self.party) do
        --if battler.visible ~= (not hide) then
        --    battler.visible = not hide
      --  end
    --end

    --for _, enemy in ipairs(self.enemies) do
      --  if enemy.visible ~= (not hide) then
    --        enemy.visible = not hide
  --      end
--    end

    --if self.battle_ui then
      --  self.battle_ui.visible = not hide
    --end
end

return Battle