-- detectors/cryo.lua · 冷冻舱过渡
-- 姿态层 14：0 = 舱内循环，6 = 出舱动画。
-- 只认「离主相机最近」的那个 Helldiver：队友的舱不该让我加速。
local M = {}

local POD_LOOP, POD_OUT = 0, 6
local CAP = 30

function M.new(settings, log)
    local self = { id = 'cryo', priority = 65, scene = nil, settings = settings, log = log }

    function self.reset() self.scene = nil end

    function self.poll(snap)
        if not self.settings.get('enabled') then self.reset(); return nil end
        local rate = self.settings.get('cryo_multiplier') or 1
        if rate <= 1 then self.reset(); return nil end

        local mine = snap.ours_posture
        if mine == nil and (snap.avatars or 0) <= 1 then
            if (snap.pod_loop or 0) > 0 then mine = POD_LOOP
            elseif (snap.pod_out or 0) > 0 then mine = POD_OUT end
        end
        if mine == nil then self.reset(); return nil end

        local in_pod, walking_out = mine == POD_LOOP, mine == POD_OUT
        if not in_pod and not walking_out then
            if self.scene then
                self.log.fmt('CRYO over (%.1f s)', snap.now - self.scene.start)
                self.reset()
            end
            return nil
        end

        if not self.scene then
            self.scene = { start = snap.now, walk_at = walking_out and snap.now or nil }
            self.log.fmt('CRYO starts (%s)', walking_out and 'walk-out clip' or 'pod loop')
        elseif walking_out and not self.scene.walk_at then
            self.scene.walk_at = snap.now
            self.log.fmt('CRYO walk-out after %.1f s', snap.now - self.scene.start)
        end
        if snap.now - self.scene.start > CAP then
            self.log.fmt('CRYO stop (cap %ds)', CAP)
            self.reset(); return nil
        end
        if self.settings.get('skip_cryo') == true then
            return { mode = 'instant', jump = 1, budget = 24, key = self.scene.start,
                     reason = walking_out and 'cryo-walk-out' or 'cryo-pod' }
        end
        return { mode = 'fast', speed = rate, reason = walking_out and 'cryo-walk-out' or 'cryo-pod' }
    end

    return self
end

return M
