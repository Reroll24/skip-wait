-- detectors/hellpod.lua · 进入空降舱 → 投放地图
-- 判据：姿态层 14 的 15（踏进）与 17（舱内）；镜头拉到投放地图（1.222）就结束。
-- 「我」用离主相机最近的那个 Helldiver 判定，队友去坐舱不会连累我（多人认不出来就不动）。
local M = {}

local POD_ENTER, POD_IN = 15, 17
local MAP_FOV = 1.2
local CAP = 30

function M.new(settings, log)
    local self = { id = 'hellpod', priority = 66, scene = nil, latched = false,
                   settings = settings, log = log }

    function self.reset() self.scene = nil end

    function self.poll(snap)
        if not self.settings.get('enabled') then self.reset(); self.latched = false; return nil end
        local rate = self.settings.get('hellpod_entry') or 1
        if rate <= 1 then self.reset(); self.latched = false; return nil end

        local mine = snap.ours_posture
        if mine == nil and (snap.avatars or 0) <= 1 then
            if (snap.pod_enter or 0) > 0 then mine = POD_ENTER
            elseif (snap.pod_in or 0) > 0 then mine = POD_IN end
        end
        if mine == nil then self.reset(); self.latched = false; return nil end

        local entering, inside = mine == POD_ENTER, mine == POD_IN
        if not entering and not inside then
            if self.scene then
                self.log.fmt('HELLPOD over (%.1f s)', snap.now - self.scene.start)
                self.reset()
            end
            self.latched = false
            return nil
        end

        -- 镜头已经在投放地图上：这一段结束，并锁住直到姿态变化。
        -- 不锁的话每帧都会「开始→立刻结束」，日志刷爆、加速也停不下来。
        if inside and snap.cam_fov and snap.cam_fov >= MAP_FOV then
            if self.scene then
                self.log.fmt('HELLPOD over (camera on the drop map, %.1f s)', snap.now - self.scene.start)
                self.reset()
            end
            self.latched = true
            return nil
        end
        if self.latched then return nil end

        if not self.scene then
            self.scene = { start = snap.now }
            self.log.fmt('HELLPOD starts (%s)', entering and 'stepping in' or 'inside the pod')
        end
        if snap.now - self.scene.start > CAP then
            self.log.fmt('HELLPOD stop (cap %ds)', CAP)
            self.reset()
            self.latched = true
            return nil
        end
        if self.settings.get('skip_hellpod') == true then
            return { mode = 'instant', jump = 1, budget = 12, key = self.scene.start,
                     reason = entering and 'hellpod-enter' or 'hellpod-in' }
        end
        return { mode = 'fast', speed = rate, reason = entering and 'hellpod-enter' or 'hellpod-in' }
    end

    return self
end

return M
