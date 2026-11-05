-- core/log.lua · ctx.log 分块缓冲
-- ctx.log 有单条长度上限，所以按行攒、按 800 字节切、每帧只 flush 一次。
local M = {}

local LINES_PER_SECOND = 20   -- 超过就丢，并记下丢了多少

function M.new(ctx, now)
    local self = { buf = {}, size = 0, seen = {}, ctx = ctx, now = now or os.clock,
                   window = 0, count = 0, dropped = 0 }
    -- MDL 只给每条 ctx.log 的第一行加 mod 前缀，所以每行自己带
    local function raw(text)
        if type(ctx) == 'table' and type(ctx.log) == 'function' then
            pcall(ctx.log, text)
        end
    end

    function self.flush()
        if #self.buf == 0 then return end
        raw(table.concat(self.buf, '\n'))
        self.buf, self.size = {}, 0
    end

    function self.write(text)
        text = tostring(text)
        -- 限流：检测器抖动时（曾经的 HELLPOD 每帧启停）不能把日志刷成几 MB
        local t = self.now()
        if t - self.window >= 1 then
            if self.dropped > 0 then
                self.buf[#self.buf + 1] = '[skipwait] ... ' .. self.dropped .. ' lines dropped (rate limit)'
                self.dropped = 0
            end
            self.window, self.count = t, 0
        end
        self.count = self.count + 1
        if self.count > LINES_PER_SECOND then
            self.dropped = self.dropped + 1
            return
        end
        if self.size + #text > 800 then self.flush() end
        local line = '[skipwait] ' .. text
        self.buf[#self.buf + 1] = line
        self.size = self.size + #line + 1
    end

    function self.fmt(f, ...) self.write(string.format(f, ...)) end

    -- 只在第一次写：给每帧都可能重复的状态用
    function self.once(key, text)
        if self.seen[key] then return end
        self.seen[key] = true
        self.write(text)
    end

    function self.reset(key) self.seen[key] = nil end

    function self.error(text) self.write('ERROR ' .. tostring(text)); self.flush() end

    return self
end

return M
