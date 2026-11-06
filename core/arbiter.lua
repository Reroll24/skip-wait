-- core/arbiter.lua · 谁在开车由优先级决定，只在结果变化时下发
local M = {}

local FAST_SEEN = 8

function M.new(clock, log)
    local self = { detectors = {}, clock = clock, log = log, current = nil }

    function self.add(detector, priority)
        detector.priority = priority or detector.priority or 0
        self.detectors[#self.detectors + 1] = detector
        table.sort(self.detectors, function(a, b) return a.priority > b.priority end)
    end

    local function signature(req)
        if not req then return nil end
        return string.format('%s|%s|%s|%s', tostring(req.mode), tostring(req.speed),
                             tostring(req.jump), tostring(req.reason))
    end

    function self.step(snap, dt)
        local best, best_req = nil, nil
        for _, d in ipairs(self.detectors) do
            -- poll 是闭包（自捕获 self），只接一个参数
            local ok, req = pcall(d.poll, snap)
            if not ok then
                self.log.once('fail:' .. tostring(d.id), 'detector ' .. tostring(d.id) .. ' failed: ' .. tostring(req))
                req = nil
            end
            if req and (not best or d.priority > best.priority) then
                best, best_req = d, req
            end
        end

        if not best_req then
            if self.current then
                self.current = nil
                self.clock.restore('scene over')
            end
            return nil
        end

        best_req.id = best.id

        -- 瞬时跳过：每帧都要重新下单，不能走「变化才下发」
        if best_req.mode == 'instant' then
            self.clock.instant(best.id, best_req.key or 'scene', best_req.budget, best_req.jump)
            local sig = signature(best_req)
            if sig ~= self.current then
                self.current = sig
                self.log.fmt('CMD instant %s (budget %s)', tostring(best_req.reason),
                             tostring(best_req.budget or '?'))
            end
            return best_req
        end

        local sig = signature(best_req)
        if sig == self.current then return best_req end

        self.current = sig
        self.clock.set_rate(best_req.mode == 'instant' and FAST_SEEN or (best_req.speed or 1),
                            tostring(best_req.reason))
        self.log.fmt('CMD x%s %s', tostring(self.clock.get_rate()), tostring(best_req.reason))
        return best_req
    end

    return self
end

return M
