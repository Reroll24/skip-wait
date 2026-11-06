-- detectors/elevator.lua · 回船电梯
-- 判定移植自 QuickDebrief 的 ElevatorGate：31 节点模型里 21..25 同步抬升才是平台。
-- build 26088801 的常数，换模型会失效（这是几何判据，不是状态判据）。
local M = {}

local WINDOW_LIMIT = 90      -- 全程自动播放，窗口按总窗走即可（原版是 15）
local OBSERVE_LIMIT = 90     -- 从船加载算起的总观察窗
local BOOST_CAP = 8
local PREROLL = 6            -- 船加载后的这段时间先按电梯倍速推：平台要等一会儿才动
local PROBE_SECONDS = 0.5    -- 探针：几何数字变了才记一行
local MOVING = { 22, 23, 24, 25, 26 }   -- Lua 1-based；引擎节点 0-based

-- 返回 floor, top, why；why 为空表示几何合格
local function geometry(s)
    local z = s.elevator
    if not z then return nil, nil, 'no unit' end
    if #z ~= 31 then return nil, nil, 'nodes=' .. tostring(#z) end
    if s.elevator_state ~= 1 then return nil, nil, 'state=' .. tostring(s.elevator_state) end
    local floor = z[2]
    if math.abs(z[27] - floor) > 0.01 then
        return nil, nil, 'z27 off floor ' .. string.format('%.3f', z[27] - floor)
    end
    local low, high = math.huge, -math.huge
    local top = 0
    for i = 23, 26 do
        low = math.min(low, z[i])
        high = math.max(high, z[i])
        top = top + z[i] / 4
    end
    if high - low > 0.03 then return nil, nil, 'platform not level ' .. string.format('%.3f', high - low) end
    if floor - top < 0.015 or floor - top > 3.5 then
        return nil, nil, 'gap ' .. string.format('%.3f', floor - top)
    end
    return floor, top
end

local function new_motion()
    local m = { samples = 0, observed = false, done = false }
    function m.step(now, s)
        if m.done then return 1, nil, true end
        local p = m.previous
        -- 快照每 0.2 秒才刷新，这里却每帧被调用：同一份快照不重复采样，
        -- 否则两次刷新之间的"零位移"会把 samples 清零（电梯永远确认不了）
        if p and p.elevator == s.elevator then
            return (m.observed and not m.done) and 2 or 1, nil, false
        end
        local floor = geometry(s)
        local rising = false
        if floor and p and p.world == s.world and p.elevator and #p.elevator == 31
            and now - m.time > 0 and now - m.time < 1
            and math.abs(floor - p.elevator[2]) < 0.001 then
            local least, most = math.huge, -math.huge
            for _, i in ipairs(MOVING) do
                local delta = s.elevator[i] - p.elevator[i]
                least = math.min(least, delta)
                most = math.max(most, delta)
            end
            rising = least > 0.0005 and most - least < 0.01
        end
        m.previous = s
        m.time = now
        if rising then
            m.samples = m.samples + 1
            if m.samples >= 2 then
                if not m.observed then
                    m.observed = true
                    m.boost_start = now
                    return 2, 'rise-confirmed', false
                end
                if now - m.boost_start >= BOOST_CAP then
                    m.done = true
                    return 1, 'cap' .. tostring(BOOST_CAP) .. 's', true
                end
                return 2, nil, false
            end
        else
            m.samples = 0
            if m.observed then
                m.done = true
                return 1, 'rise-ended-or-geometry-changed', true
            end
        end
        return 1, nil, false
    end
    return m
end

function M.new(settings, log)
    local self = { id = 'elevator', priority = 60, arrival = nil, served = nil,
                   settings = settings, log = log }

    function self.reset() self.arrival = nil end

    -- 探针：把判据真正看到的数字记下来，几何或状态一变就写一行
    local function probe(a, snap, now)
        local z = snap.elevator
        if not z then return end
        local sig = string.format('%s|%.3f|%.3f|%.3f|%.3f',
            tostring(snap.elevator_state), z[2] or 0, z[22] or 0, z[23] or 0, z[26] or 0)
        if sig == a.probe_sig then return end
        a.probe_sig = sig
        local _, _, why = geometry({ elevator = z, elevator_state = snap.elevator_state })
        self.log.fmt('ELEVATOR probe nodes=%d state=%s z2=%.3f z22=%.3f z23=%.3f z26=%.3f z27=%.3f rule=%s',
            #z, tostring(snap.elevator_state), z[2] or 0, z[22] or 0, z[23] or 0,
            z[26] or 0, z[27] or 0, why or 'ok')
    end

    function self.poll(snap)
        if not self.settings.get('enabled') then self.reset(); return nil end
        local rate = self.settings.get('elevator_multiplier') or 1
        if rate <= 1 then self.reset(); return nil end
        local now = snap.now
        local here = snap.markers == 3 and snap.avatars >= 1 and snap.elevator ~= nil

        -- 每次回船只开一个窗口（ship_at 每次任务后都会换新值）
        if not self.arrival and snap.ship_at and snap.ship_at ~= self.served
            and (now - snap.ship_at) <= OBSERVE_LIMIT then
            self.served = snap.ship_at
            self.arrival = { deadline = snap.ship_at + OBSERVE_LIMIT, begin = nil }
            self.log.fmt('ELEVATOR watching (%.1f s after the ship loaded)', now - snap.ship_at)
        end

        if self.arrival then
            local a = self.arrival
            if now > a.deadline then
                self.log.fmt('ELEVATOR stop (observation limit)')
                self.reset(); return nil
            end
            -- 船还在加载 / 场景还没起来：只是等，不消耗窗口
            if not here then
                if not a.said_waiting then
                    a.said_waiting = true
                    self.log.fmt('ELEVATOR waiting (markers=%d avatars=%d elevator=%s)',
                                 snap.markers, snap.avatars, snap.elevator and 'yes' or 'no')
                end
                return nil
            end
            if self.log.verbose and (not a.last_probe or now - a.last_probe >= PROBE_SECONDS) then
                a.last_probe = now
                probe(a, snap, now)
            end
            a.begin = a.begin or now
            if now - a.begin > WINDOW_LIMIT then
                self.log.fmt('ELEVATOR stop (window limit)')
                self.reset(); return nil
            end
            a.motion = a.motion or new_motion()
            local requested, event, finished = a.motion.step(now, {
                world = snap.world_index, elevator = snap.elevator, elevator_state = snap.elevator_state,
            })
            if event then self.log.fmt('ELEVATOR %s', event) end
            if finished then self.reset(); return nil end
            if requested == 2 then
                return { mode = 'fast', speed = rate, reason = 'elevator-rise' }
            end
            -- 平台要等一会儿才动，等位移确认会晚 1~2 秒：开局这几秒直接推
            if snap.ship_at and (now - snap.ship_at) <= PREROLL then
                return { mode = 'fast', speed = rate, reason = 'elevator-early' }
            end
            return nil
        end

        return nil
    end

    return self
end

return M
