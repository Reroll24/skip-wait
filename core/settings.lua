-- core/settings.lua · MDL3 ModOptionsMenu 的薄封装
-- 菜单不存在时退回默认值，绝不因为读设置失败而停下。
local M = {}

local PREFIX = 'skipwait.'
local RETRY = 0.5

function M.new(log, now)
    local self = { values = {}, registered = {}, defs = {}, log = log, next_try = 0, now = now or os.clock }

    local function menu()
        -- _G 在 MDL3 里是代理表，rawget 会绕过 __index，必须用普通索引
        local ok, m = pcall(function() return _G.ModOptionsMenu end)
        if not ok then return nil end
        if type(m) == 'table' and m.api == 1
            and type(m.register_option) == 'function' and type(m.get) == 'function' then
            return m
        end
        return nil
    end

    local function clamp(d, v)
        if d.type == 'toggle' then return v == true end
        local n = tonumber(v)
        if not n then return d.default end
        if d.min and n < d.min then n = d.min end
        if d.max and n > d.max then n = d.max end
        return n
    end

    function self.register(defs)
        self.defs = defs
        for _, d in ipairs(defs) do self.values[d.key] = d.default end
    end

    function self.get(key) return self.values[key] end

    -- 每帧调用；注册与读取都按 0.5 秒节流
    function self.sync()
        local t = self.now()
        if t < self.next_try then return end
        self.next_try = t + RETRY
        local m = menu()
        if not m then return end
        for _, d in ipairs(self.defs) do
            local id = PREFIX .. d.key
            if not self.registered[d.key] then
                -- 照 BFV 的做法：每节一个 spec.mod（显示名）+ 稳定的 mod_id。
                -- 能不能归到同一个 mod 入口，看 MDL3 是否按注册脚本的路径（mod.lua 里写死的 mods/<mod>/）
                -- 分组；BFV 是 addon，日志里带 [mods/test_author/...]。
                local spec = { mod = d.group or 'Skip Wait', mod_id = d.mod_id,
                               label = d.label, description = d.description,
                               type = d.type, default = d.default, min = d.min, max = d.max,
                               step = d.step, gap = d.gap }
                local ok, accepted = pcall(m.register_option, id, spec)
                if ok and accepted == true then
                    self.registered[d.key] = true
                    self.log.fmt('setting registered: %s = %s', d.key, tostring(d.default))
                end
            end
            if self.registered[d.key] then
                local ok, v = pcall(m.get, id)
                if ok and v ~= nil then self.values[d.key] = clamp(d, v) end
            end
        end
    end

    return self
end

return M
