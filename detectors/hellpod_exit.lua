-- detectors/hellpod_exit.lua · 出空降舱（进舱后按 ESC 取消空投、从舱里爬出来）
-- 取消不只发生在投放地图上：从踏进空降舱到真正发射之前都能取消，所以武装点提前到「人在舱里（17）」。
-- 判据是时间窗，不依赖具体姿态码：
--   1. 「我」在舱内（17）→ 武装；
--   2. 出舱开始 = 镜头离开投放地图（前提是到过地图），或姿态变成 16/15/36 并持续 0.25 秒；
--   3. 窗口按「游戏秒」计时：用户实测动画约 3~4 秒——注意这是不加速时的 3~4 秒。
--      8x 下动画 0.5 秒就播完了；如果按真实秒数等 4.5 秒，就会多快 4 秒（上一版的毛病）。
--      所以每帧累加 dt * 倍率（jump 模式每帧算 1 秒），累计到 EXIT_RUN 游戏秒就收工；
--   4. 提前收工：投放地图重新打开（又进舱了）、launch 世界出现（真投放）、离开船、或回到 36 + 正常镜头。
-- 实测出舱后姿态是 16（偶尔 3/15/17），走不到 36，所以时间窗是主判据。
local M = {}

local MAP_FOV = 1.2      -- 投放地图镜头（实测 1.222）
local BACK_FOV = 1.15    -- 低于它就算离开了投放地图（正常 1.134、舱内特写 0.611）
local EXIT_RUN = 4.5     -- 出舱动画约 3~4 游戏秒，留余量；到点必停
local SETTLE = 3         -- 连续 3 次普查（约 0.6 秒）确认回到 36 才提前收工
local AWAY_SECONDS = 0.25 -- 姿态离开 17 要持续这么久才算数（轮询是每帧，不能按次数算）

local POD_ENTER, POD_EXIT, POD_IN, NORMAL = 15, 16, 17, 36

function M.new(settings, log)
    local self = { id = 'hellpod_exit', priority = 67, stage = nil,
                   settings = settings, log = log }

    function self.reset()
        self.stage, self.started, self.seen_map = nil, nil, false
        self.normal, self.away, self.last_key = 0, nil, nil
        self.run, self.last_now, self.last_log = 0, nil, nil
    end

    local function our_posture(snap)
        local mine = snap.ours_posture
        if mine == nil and (snap.avatars or 0) <= 1 then
            if (snap.pod_enter or 0) > 0 then mine = POD_ENTER
            elseif (snap.pod_in or 0) > 0 then mine = POD_IN end
        end
        return mine
    end

    -- 出舱窗口里记姿态/镜头变化：姿态变了立刻记，镜头每 0.4 秒最多记一行（原来每帧都记，日志被限流吞了）
    function self.note(mine, fov, snap)
        local posture_changed = self.last_posture ~= mine
        if not posture_changed and self.last_log and snap.now - self.last_log < 0.4 then return end
        local bucket = fov and string.format('%.2f', fov) or 'nil'
        local key = tostring(mine) .. '|' .. bucket
        if key == self.last_key and not posture_changed then return end
        self.last_key, self.last_posture, self.last_log = key, mine, snap.now
        self.log.fmt('HELLPOD EXIT posture %s, fov %s', tostring(mine),
                     fov and string.format('%.3f', fov) or 'nil')
    end

    local function fov_text(fov) return fov and string.format('%.3f', fov) or 'nil' end

    local function begin_exit(why, mine, fov, snap)
        self.stage, self.started = 'exit', snap.now
        self.normal, self.away, self.last_key = 0, nil, nil
        self.run, self.last_now, self.last_posture, self.last_log = 0, snap.now, nil, nil
        self.log.fmt('HELLPOD EXIT starts (%s, posture %s, fov %s)', why,
                     tostring(mine), fov_text(fov))
    end

    local function leave(why, snap)
        self.log.fmt('HELLPOD EXIT over (%s, %d game s / %.1f s real)',
                     why, math.floor((self.run or 0) + 0.5), snap.now - self.started)
        self.reset()
    end

    function self.poll(snap)
        if not self.settings.get('enabled') then self.reset(); return nil end
        local rate = self.settings.get('hellpod_exit') or 1
        if rate <= 1 then self.reset(); return nil end
        local instant = self.settings.get('skip_hellpod_exit') == true

        local mine = our_posture(snap)
        local fov = snap.cam_fov

        -- 真投放：发射用的那个小世界出现，让给 hellpod_drop
        if snap.launcher then
            if self.stage == 'exit' then leave('launched', snap) end
            self.reset()
            return nil
        end
        if snap.mode ~= 'ship' then
            if self.stage == 'exit' then leave('left the ship', snap) end
            self.reset()
            return nil
        end

        -- 武装：人在舱里（17）。踏进（15）不武装——那是进舱动画本身，会误判成出舱。
        if self.stage == nil then
            if mine == POD_IN then
                self.stage, self.started, self.seen_map = 'pod', snap.now, false
                self.log.fmt('HELLPOD EXIT armed (in the pod, fov %s)', fov_text(fov))
            end
            return nil
        end

        if self.stage == 'pod' then
            if fov and fov >= MAP_FOV then self.seen_map = true end

            if self.seen_map and fov and fov < BACK_FOV then
                -- 到过投放地图、镜头又离开它：最直接的信号（覆盖地图上按 ESC）
                begin_exit('camera left the map', mine, fov, snap)
            elseif mine == POD_EXIT or mine == POD_ENTER or mine == NORMAL then
                -- 人已经不在舱内姿态：爬出来的动画开始了（覆盖地图出来之前按 ESC）。
                -- 要持续 0.25 秒才认，防止单帧抖动误开窗口；检测器每帧被调用，不能按次数算。
                self.away = self.away or snap.now
                if snap.now - self.away >= AWAY_SECONDS then
                    begin_exit('posture left the pod', mine, fov, snap)
                else
                    return nil
                end
            else
                self.away = nil
                return nil
            end
        end

        -- stage == 'exit'
        self.note(mine, fov, snap)

        -- 游戏时间：jump 模式每帧推进约 1 秒；fast 模式按真实 dt * 倍率
        local now = snap.now
        local dt = now - (self.last_now or now)
        self.last_now = now
        self.run = (self.run or 0) + (instant and 1 or dt * rate)

        -- 又回到舱内、投放地图重新打开：这轮取消结束了，别把地图 UI 也带着加速
        if mine == POD_IN and fov and fov >= MAP_FOV then
            leave('back on the drop map', snap)
            return nil
        end

        -- 人回到 36 且镜头正常：正常收工（实测常走不到，靠下面的时间窗兜底）
        if mine == NORMAL and (fov == nil or fov < BACK_FOV) then
            self.normal = self.normal + 1
        else
            self.normal = 0
        end
        if self.normal >= SETTLE then
            leave('back to normal', snap)
            return nil
        end

        if self.run >= EXIT_RUN then
            leave('window', snap)
            return nil
        end

        if instant then
            return { mode = 'instant', jump = 1, budget = 8, key = self.started, reason = 'hellpod-exit' }
        end
        return { mode = 'fast', speed = rate, reason = 'hellpod-exit' }
    end

    return self
end

return M
