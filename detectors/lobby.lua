-- detectors/lobby.lua · 加入 / 离开大厅时的飞船外景
-- 判据来自 Impatient Diver（MIT），和 FTL 共用同一行设置：
--   带炮的小世界，但只有 11~30 个单位，所以不是 FTL（那是 584~593）。
--   它成立的前提是「我们这艘船先加载好了，外景才起来」或「旧船正在清空」；
--   否则就是空降舱发射（那个带 launch kind，已经排除）。
local M = {}

local SHIP = 1000
local FTL_UNITS = 300
local EMPTIED_EARLY = 0.25

local function main_entry(snap)
    for _, e in ipairs(snap.worlds) do
        if e.index == snap.main_index then return e end
    end
end

local function reloaded_since(snap, t)
    for _, e in ipairs(snap.worlds) do
        if t and e.reloaded_at and e.reloaded_at >= t and e.count > SHIP then return true end
    end
    return false
end

local function emptied_since(snap, t)
    for _, e in ipairs(snap.worlds) do
        if t and e.emptied_at and e.emptied_at >= t - EMPTIED_EARLY then return true end
    end
    return false
end

function M.new(settings, log)
    local self = { id = 'lobby', priority = 70, active = nil, settings = settings, log = log }

    function self.reset() self.active = nil end

    function self.poll(snap)
        if not self.settings.get('enabled') then self.reset(); return nil end
        local rate = self.settings.get('ftl_multiplier') or 1
        if rate <= 1 then self.reset(); return nil end
        if snap.mode == 'mission' then self.reset(); return nil end

        local d = snap.destroyer
        if not d or d.launch then self.reset(); return nil end
        if d.count >= FTL_UNITS then self.reset(); return nil end   -- 那是 FTL，交给 ftl.lua
        -- 同一个世界可能先是 584 单位的 FTL，再缩成 23 单位的到达镜头：
        -- 只有「刚刚还是大世界」的才算同一段 FTL，一分钟前的旧账不算
        if d.big_at and (snap.now - d.big_at) < 60 then self.reset(); return nil end
        local t = d.cannons_at
        if not t then self.reset(); return nil end



        -- 中途放弃任务也会冒出一个回船外景，但它不是加入队伍：这段时间不碰
        if snap.last_mission_at and not snap.extracted
            and (snap.now - snap.last_mission_at) < 30 then
            self.reset(); return nil
        end

        local main = main_entry(snap)
        local over_our_ship = main and main.count > SHIP and main.loaded_at and main.loaded_at < t
        -- born_from_ship 是关键：这个外景是我们站在船上时冒出来的（加入/离开队伍），
        -- 而任务结束回来的外景出现时，我们还在任务或空场景里
        local ok = d.from_ship or reloaded_since(snap, t)
                   or over_our_ship or emptied_since(snap, t)

        if ok then
            if not self.active then
                self.active = d.index
                self.log.fmt('LOBBY outside shot (world %d, %d units, %.1f s after our ship)',
                             d.index, d.count, t - (main and main.loaded_at or t))
            end
            if self.settings.get('skip_ftl') == true then
                return { mode = 'instant', jump = 1, budget = 12, key = self.active, reason = 'lobby-change' }
            end
            return { mode = 'fast', speed = rate, reason = 'lobby-change' }
        end

        self.reset()
        return nil
    end

    return self
end

return M
