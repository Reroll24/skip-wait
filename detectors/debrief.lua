-- detectors/debrief.lua · 任务结算
-- 判定逻辑移植自 QuickDebrief 0.4.3 的 Gate（作者未主张著作权；MIT/原仓库见 README）。
-- 有意的改动：去掉 is_host 门槛（客户端也要能加速），20 秒上限改成可配置。
-- 契约：poll(snap) 不碰引擎，只读快照。
local M = {}

local TRANSIT_LIMIT, CONFIRM_LIMIT, MAX_SAMPLE_GAP = 45, 1, 0.75
local ARM_SECONDS = 2
local RETURN_LIMIT = 90
local SLOW = 2

local function new_gate(start)
    local g = { stage = 'armed', start = start, speed = 1 }

    local function transition(stage, now, why)
        g.stage = stage
        g.changed = now
        return g.speed, stage .. ':' .. why
    end

    local function forget(now, why)
        g.seat_world, g.candidate_world, g.empty_since, g.candidate_sample = nil, nil, nil, nil
        return transition('mission', now, why)
    end

    local function wait_for_world(now, s, empty, ship)
        if ship then return transition('done', now, 'ship-before-debrief') end
        if now - g.last_seat > TRANSIT_LIMIT then return forget(now, 'extraction-transit-expired') end
        -- 刚验证过撤离还不够：绝不能加速原任务世界里的一段空场景
        if empty and s.world ~= g.seat_world then
            g.candidate_world = s.world
            g.empty_since = now
            g.candidate_sample = now
            return transition('confirming', now, 'new-empty-world-candidate')
        end
        if g.stage ~= 'transit' then return transition('transit', now, 'awaiting-new-world-45s-max') end
        return 1
    end

    function g.step(now, s, cap)
        cap = cap or 20
        if g.stage == 'done' then return 1, 'done' end
        if now - g.start >= 3600 or now < g.start then
            g.speed = 1
            return transition('done', now, 'session-limit')
        end
        local ship = s.markers >= 2
        local empty = s.world and s.markers == 0 and s.avatars == 0 and s.units >= 1 and s.units <= 64
        local mission = s.world and s.markers == 0 and s.avatars >= 1 and s.units >= 256

        if g.stage == 'fast' then
            if not empty or s.world ~= g.fast_world then
                g.speed = 1
                return transition(ship and 'done' or 'returnwatch', now, 'scene-changed')
            end
            if now - g.fast_start >= cap then
                g.speed = 1
                return transition('returnwatch', now, 'cap' .. tostring(cap) .. 's')
            end
        elseif g.stage == 'armed' then
            if mission and s.normal > 0 then
                g.mission_since = g.mission_since or now
                if now - g.mission_since >= 5 then return transition('mission', now, 'avatar-normal-stable') end
            else
                g.mission_since = nil
            end
        elseif g.stage == 'mission' then
            if ship then return transition('done', now, 'returned-without-extraction-cue') end
            if mission and s.boarding > 0 then return transition('boarding', now, '89-seen') end
        elseif g.stage == 'boarding' then
            if mission and s.seated > 0 then
                g.seat_start = now
                g.last_seat = now
                g.seat_world = s.world
                g.seat_qualified = false
                return transition('seated', now, '89-to-90')
            elseif now - g.changed > 5 or not mission or s.boarding == 0 then
                return transition('mission', now, 'boarding-cue-lost')
            end
        elseif g.stage == 'seated' or g.stage == 'transit' then
            if s.world == g.seat_world and mission and s.seated > 0 then
                g.last_seat = now
                if now - g.seat_start >= SLOW then g.seat_qualified = true end
                if g.stage ~= 'seated' then return transition('seated', now, 'seating-cue-returned') end
            elseif not g.seat_qualified then
                if ship then return transition('done', now, 'ship-before-debrief') end
                return forget(now, 'seating-not-confirmed-for-2s')
            else
                return wait_for_world(now, s, empty, ship)
            end
        elseif g.stage == 'confirming' then
            if ship then return transition('done', now, 'ship-before-debrief') end
            local gap = now - g.candidate_sample
            if not empty or s.world ~= g.candidate_world or gap <= 0 or gap > MAX_SAMPLE_GAP then
                g.candidate_world, g.empty_since, g.candidate_sample = nil, nil, nil
                return wait_for_world(now, s, empty, ship)
            end
            if now - g.empty_since > CONFIRM_LIMIT then return forget(now, 'empty-confirmation-timeout') end
            g.candidate_sample = now
            if now - g.empty_since >= 0.2 then
                g.speed = 2
                g.fast_start = now
                g.fast_world = s.world
                return transition('fast', now, 'extraction-then-empty-scene')
            end
        elseif g.stage == 'returnwatch' then
            if ship then return transition('done', now, 'ship-loaded') end
            if now - g.changed > RETURN_LIMIT then return transition('done', now, 'return-observation-limit') end
        end
        return g.speed
    end

    return g
end

function M.new(settings, log)
    local self = { id = 'debrief', priority = 50, gate = nil, ship_since = nil,
                   settings = settings, log = log, last_event = nil }

    function self.reset()
        self.gate, self.ship_since = nil, nil
    end

    function self.poll(snap)
        if not self.settings.get('enabled') then self.reset(); return nil end
        local rate = self.settings.get('debrief_multiplier') or 1
        if rate <= 1 then self.reset(); return nil end
        local cap = self.settings.get('debrief_cap') or 20
        local now = snap.now
        local s = {
            world = snap.world_index,
            markers = snap.markers, avatars = snap.avatars, units = snap.units,
            normal = snap.normal, boarding = snap.boarding, seated = snap.seated,
        }
        s.world = (snap.mode == 'none') and nil or snap.world_index

        if not self.gate then
            if snap.markers == 3 and snap.avatars >= 1 then
                self.ship_since = self.ship_since or now
                if now - self.ship_since >= ARM_SECONDS then
                    self.gate = new_gate(now)
                    self.ship_since = nil
                    self.log.fmt('DEBRIEF armed (units=%d avatars=%d)', snap.units, snap.avatars)
                end
            else
                self.ship_since = nil
            end
            return nil
        end

        local requested, event = self.gate.step(now, s, cap)
        if event and event ~= self.last_event then
            self.last_event = event
            self.log.fmt('DEBRIEF %s', event)
        end
        if self.gate.stage == 'done' then
            self.gate = nil
            self.last_event = nil
            return nil
        end
        if requested == 2 then
            return { mode = 'fast', speed = rate, reason = event or 'debrief' }
        end
        return nil
    end

    return self
end

return M
