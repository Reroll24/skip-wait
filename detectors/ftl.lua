-- detectors/ftl.lua · FTL 跳跃 / 进出大厅时的飞船外景
-- 判据来自 Impatient Diver（MIT）：小世界里挂着 se_destroyer_supportcannon_* 就是超光速的外景世界，
-- 单位数 584~593；进出大厅的外景世界只有 11~30 个，空降舱发射的那个带 launch kind。
local M = {}

local FTL_UNITS = 300      -- 低于这个数的小世界不是 FTL（可能是大厅切换或发射）

function M.new(settings, log)
    local self = { id = 'ftl', priority = 70, active = nil, settings = settings, log = log }

    function self.reset() self.active = nil end

    function self.poll(snap)
        if not self.settings.get('enabled') then self.reset(); return nil end
        local rate = self.settings.get('ftl_multiplier') or 1
        if rate <= 1 then self.reset(); return nil end
        local instant = self.settings.get('skip_ftl') == true
        if snap.mode == 'mission' then self.reset(); return nil end

        local d = snap.destroyer
        if not d or d.launch then self.reset(); return nil end

        if d.count >= FTL_UNITS then
            if not self.active then
                self.active = d.index
                self.log.fmt('FTL starts (world %d, %d units)', d.index, d.count)
            end
            if instant then
                return { mode = 'instant', jump = 1, budget = 20, key = self.active, reason = 'ftl' }
            end
            return { mode = 'fast', speed = rate, reason = 'ftl' }
        end

        -- 已经在 FTL 里：世界为到达而缩小时继续跑（外景还在），炮没了才结束
        if self.active and d.index == self.active then
            if instant then
                return { mode = 'instant', jump = 1, budget = 20, key = self.active, reason = 'ftl-arrival' }
            end
            return { mode = 'fast', speed = rate, reason = 'ftl-arrival' }
        end

        self.reset()
        return nil
    end

    return self
end

return M
