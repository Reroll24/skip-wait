-- detectors/hellpod_drop.lua · 空投发射（只加速「舰桥内镜头向前推」那一段）
-- 用户实测的发射镜头顺序：
--   1. 舰桥内镜头向前推（这一小段要加速）
--   2. 飞船外看空投仓发射（不加速）
--   3. 空投仓往下坠落（不加速）
-- 判据：投放地图关上 = 点了确认 → 开始；带 launch kind 的小世界出现 = 镜头切到船外 → 停。
-- 取消空投也会关地图，但人会在 0.3 秒内离开 17、且永远等不到 launch 世界，这段交给 hellpod_exit。
-- 窗口按游戏秒计（和 hellpod_exit 同一套算法），8 游戏秒兜底。
local M = {}

local MAP_FOV = 1.2       -- 投放地图镜头（实测 1.222）
local BACK_FOV = 1.15     -- 低于它就算离开了投放地图（正常 1.134、舱内特写 0.698）
local RUN = 8.0           -- 舰桥推进约 6~7 游戏秒，留余量；到点必停
local AWAY_SECONDS = 0.3  -- 姿态离开 17 持续这么久才认定是「取消」

local POD_ENTER, POD_EXIT, POD_IN, NORMAL = 15, 16, 17, 36

function M.new(settings, log)
    local self = { id = 'hellpod_drop', priority = 68, stage = nil,
                   settings = settings, log = log }

    function self.reset()
        self.stage, self.seen_map, self.away = nil, false, nil
        self.run, self.started, self.last_now = 0, nil, nil
        self.last_key, self.last_posture, self.last_log = nil, nil, nil
    end

    local function our_posture(snap)
        local mine = snap.ours_posture
        if mine == nil and (snap.avatars or 0) <= 1 then
            if (snap.pod_enter or 0) > 0 then mine = POD_ENTER
            elseif (snap.pod_in or 0) > 0 then mine = POD_IN end
        end
        return mine
    end

    function self.note(mine, fov, snap)
        local posture_changed = self.last_posture ~= mine
        if not posture_changed and self.last_log and snap.now - self.last_log < 0.4 then return end
        local bucket = fov and string.format('%.2f', fov) or 'nil'
        local key = tostring(mine) .. '|' .. bucket
        if key == self.last_key and not posture_changed then return end
        self.last_key, self.last_posture, self.last_log = key, mine, snap.now
        self.log.fmt('HELLPOD DROP posture %s, fov %s', tostring(mine),
                     fov and string.format('%.3f', fov) or 'nil')
    end

    local function fov_text(fov) return fov and string.format('%.3f', fov) or 'nil' end

    local function leave(why, snap)
        self.log.fmt('HELLPOD DROP over (%s, %d game s / %.1f s real)',
                     why, math.floor((self.run or 0) + 0.5), snap.now - (self.started or snap.now))
        self.reset()
    end

    function self.poll(snap)
        if not self.settings.get('enabled') then self.reset(); return nil end
        local rate = self.settings.get('hellpod_drop') or 1
        if rate <= 1 then self.reset(); return nil end
        local instant = self.settings.get('skip_hellpod_drop') == true
        local now = snap.now

        -- 镜头切到船外（launch 世界出现）= 舰桥推进结束，立刻停；外面那两段不加速
        if snap.launcher then
            if self.stage == 'run' then leave('launch shot begins', snap) end
            self.reset()
            return nil
        end
        if snap.mode ~= 'ship' then
            if self.stage == 'run' then leave('left the ship', snap) end
            self.reset()
            return nil
        end

        local mine = our_posture(snap)
        local fov = snap.cam_fov

        if self.stage == nil then
            -- 人在舱里、镜头在投放地图上：武装，等玩家点确认
            if mine == POD_IN and fov and fov >= MAP_FOV then
                self.stage, self.seen_map = 'armed', true
                self.log.fmt('HELLPOD DROP armed (drop map, fov %s)', fov_text(fov))
            end
            return nil
        end

        if self.stage == 'armed' then
            if fov and fov < BACK_FOV then
                self.stage, self.started = 'run', now
                self.run, self.last_now, self.away = 0, now, nil
                self.last_key, self.last_posture, self.last_log = nil, nil, nil
                self.log.fmt('HELLPOD DROP starts (drop confirmed, posture %s, fov %s)',
                             tostring(mine), fov_text(fov))
            end
            return nil
        end

        -- stage == 'run'
        self.note(mine, fov, snap)

        -- 取消空投：人会离开舱内姿态并保持一小会儿，这段交给 hellpod_exit
        if mine == POD_EXIT or mine == POD_ENTER or mine == NORMAL then
            self.away = self.away or now
            if now - self.away >= AWAY_SECONDS then
                leave('cancelled', snap)
                return nil
            end
        else
            self.away = nil
        end

        local dt = now - (self.last_now or now)
        self.last_now = now
        self.run = (self.run or 0) + (instant and 1 or dt * rate)

        if self.run >= RUN then
            leave('window', snap)
            return nil
        end
        if instant then
            return { mode = 'instant', jump = 1, budget = 6, key = self.started, reason = 'hellpod-bridge' }
        end
        return { mode = 'fast', speed = rate, reason = 'hellpod-bridge' }
    end

    return self
end

return M
