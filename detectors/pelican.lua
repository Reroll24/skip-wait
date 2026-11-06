-- detectors/pelican.lua · 鹈鹕起飞（任务结束、全员上机到结算之间）
-- 这个是实验性的：Impatient Diver 的作者明确写了「任务里、空降舱发射、任务归来三处不加速」，
-- 因为那几段的世界推进由主机同步，本地加速可能和主机进度不一致。
-- 所以倍速默认 1（关），要试的话在设置里拉起来。
local M = {}

local SEATED = 90     -- 姿态层 14：坐在鹈鹕里
local CAP = 30

function M.new(settings, log)
    local self = { id = 'pelican', priority = 45, scene = nil, settings = settings, log = log }

    function self.reset() self.scene = nil end

    function self.poll(snap)
        if not self.settings.get('enabled') then self.reset(); return nil end
        local players = snap.players or 1
        -- 多人不碰：实测里加速会让别人上机时也被推快，起飞后还要等主机同步，
        -- 鹈鹕会挂在半空迟迟不结算。这条只在单人时工作。
        if players > 1 then self.reset(); return nil end
        local rate = self.settings.get('pelican_solo') or 1
        if rate <= 1 then self.reset(); return nil end
        local now = snap.now

        local aboard = snap.mode == 'mission' and (snap.seated or 0) > 0
        if not aboard then
            if self.scene then
                self.log.fmt('PELICAN over (%.1f s)', now - self.scene.start)
                self.reset()
            end
            return nil
        end

        if not self.scene then
            self.scene = { start = now }
            self.log.write('PELICAN starts (everyone aboard, solo)')
        end
        if now - self.scene.start > CAP then
            self.log.fmt('PELICAN stop (cap %ds)', CAP)
            self.reset(); return nil
        end
        return { mode = 'fast', speed = rate, reason = 'pelican-takeoff' }
    end

    return self
end

return M
