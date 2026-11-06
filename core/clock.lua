-- core/clock.lua · 全进程唯一允许改时间步的模块
-- 合并后两个 mod 抢同一个开关的问题，靠「只有一个写者」从结构上消掉。
local M = {}

local FAST = 8
local STEP_MOST = 0.2
local IDLE_RESET = 2      -- 两秒没再申请，就忘掉这个场景的跳跃额度

function M.new(sr, log, now)
    local self = { rate = 1, broken = false, log = log, now = now or os.clock,
                   app = sr and sr.Application, budgets = {}, last_use = {} }

    local function write(value)
        if self.broken or not self.app then return false end
        local ok, err = pcall(self.app.set_time_step_policy, 'external_multiplier', value)
        if not ok then
            self.broken = true
            self.log.error('set_time_step_policy failed, no more speed changes: ' .. tostring(err))
            return false
        end
        return true
    end

    function self.get_rate() return self.rate end

    function self.set_rate(value, why)
        if self.broken or value == self.rate then return end
        if not write(value) then return end
        self.rate = value
        self.log.fmt('RATE x%s (%s)', tostring(value), why or '?')
    end

    function self.restore(why)
        self.set_rate(1, why or 'restore')
        self.budgets, self.last_use = {}, {}
    end

    -- 跳跃额度按 (detector, 场景) 记账：同一场景反复进出不会把额度重置成满
    function self.jump_left(id, key)
        local k = tostring(id) .. ':' .. tostring(key)
        local t = self.now()
        if self.last_use[k] and t - self.last_use[k] > IDLE_RESET then self.budgets[k] = nil end
        self.last_use[k] = t
        return self.budgets[k]
    end

    function self.spend_jump(id, key, cap)
        local k = tostring(id) .. ':' .. tostring(key)
        local left = self.jump_left(id, key)
        if left == nil then left = cap end
        if left <= 0 then return false end
        self.budgets[k] = left - 1
        local ok = pcall(self.app.set_time_step_policy, 'jump', 1)
        if not ok then
            self.broken = true
            self.log.error('jump failed, no more speed changes')
            return false
        end
        return true
    end

    -- 瞬时跳过：每帧让「下一步」多跳 jump 秒，额度用完就退回 fast 把剩下的播完。
    -- 额度按 (detector, 场景) 记账，同一场景反复进出不会重新领满。
    function self.instant(id, key, budget, jump)
        if self.broken then return end
        local k = tostring(id) .. ':' .. tostring(key)
        local left = self.jump_left(id, key)
        if left == nil then
            left = budget or 12
            self.budgets[k] = left
        end
        if left <= 0 then
            self.set_rate(FAST, 'instant done')
            return
        end
        self.budgets[k] = left - 1
        local ok = pcall(self.app.set_time_step_policy, 'jump', jump or 1)
        if not ok then
            self.broken = true
            self.log.error('jump failed, no more speed changes')
            return
        end
        self.set_rate(1, 'instant')
    end

    return self
end

M.FAST = FAST
M.STEP_MOST = STEP_MOST
return M
