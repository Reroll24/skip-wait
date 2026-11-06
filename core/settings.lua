-- core/settings.lua · MDL3 ModOptionsMenu 的薄封装
-- 菜单不存在时退回默认值，绝不因为读设置失败而停下。
-- 文案全部走 core/locales.lua：MOM 的 api version >= 2 时用函数注册（每次打开菜单重新解析），
-- 老版本退回注册时的中文文本。
local M = {}

local PREFIX = 'skipwait.'
local RETRY = 0.5

function M.new(log, now, locales)
    local self = {
        values = {}, registered = {}, defs = {}, log = log, next_try = 0,
        now = now or os.clock, locales = locales, dynamic = false,
    }

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

    -- 当前语言代码（'zh' / 'en'），由 language 选项的下标决定。
    -- 每次都直接问菜单要，而不是只看 self.values：
    -- 菜单可能在我们这一帧的 update 之前重绘，直接读才能做到「切完立刻生效」。
    local function code()
        if self.locales == nil then return 'zh' end
        local m = menu()
        if m then
            local ok, v = pcall(m.get, PREFIX .. 'language')
            if ok and type(v) == 'number' then
                self.values.language = v
                return self.locales.code(v)
            end
        end
        return self.locales.code(self.values.language)
    end

    local function text(key)
        if self.locales == nil then return key end
        return self.locales.text(code(), key)
    end

    local function clamp(d, v)
        if d.type == 'toggle' then return v == true end
        if d.type == 'choice' then
            local n = math.floor(tonumber(v) or d.default)
            if n < 1 then n = 1 end
            local count = d.choices and #d.choices or 0
            if count > 0 and n > count then n = count end
            return n
        end
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

    -- 当前语言的代码，给别的模块（例如日志）用
    function self.language() return code() end

    -- 每帧调用；注册与读取都按 0.5 秒节流
    function self.sync()
        local t = self.now()
        if t < self.next_try then return end
        self.next_try = t + RETRY
        local m = menu()
        if not m then return end
        self.dynamic = type(m.version) == 'number' and m.version >= 2
        if not self.version_logged then
            self.version_logged = true
            self.log.fmt('mod options api version %s, text functions: %s',
                         tostring(m.version), tostring(self.dynamic))
        end
        for _, d in ipairs(self.defs) do
            -- 老版本 MOM 不支持文案函数，语言开关也就没法生效，直接不注册
            if not (d.key == 'language' and not self.dynamic) then
                local id = PREFIX .. d.key
                if not self.registered[d.key] then
                    -- 照 BFV 的做法：每节一个 spec.mod（显示名）+ 稳定的 mod_id。
                    -- 能不能归到同一个 mod 入口，看 MDL3 是否按注册脚本的路径（mod.lua 里写死的 mods/<mod>/）
                    -- 分组；BFV 是 addon，日志里带 [mods/test_author/...]。
                    local spec = { mod_id = d.mod_id, type = d.type, default = d.default,
                                   min = d.min, max = d.max, step = d.step, gap = d.gap }
                    local label_key = 'opt.' .. d.key .. '.label'
                    local desc_key = 'opt.' .. d.key .. '.desc'
                    if self.dynamic then
                        spec.mod = function() return text(d.group) end
                        spec.label = function() return text(label_key) end
                        spec.description = function() return text(desc_key) end
                        if d.choices then
                            spec.choices = {}
                            for index, choice in ipairs(d.choices) do
                                spec.choices[index] = function() return text('lang.' .. choice) end
                            end
                        end
                    else
                        spec.mod = text(d.group)
                        spec.label = text(label_key)
                        spec.description = text(desc_key)
                        if d.choices then
                            spec.choices = {}
                            for index, choice in ipairs(d.choices) do
                                spec.choices[index] = text('lang.' .. choice)
                            end
                        end
                    end
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
    end

    return self
end

return M
