-- Skip Wait / 跳过人生 · MDL3 实时 mod 入口
-- 架构：snapshot（唯一读引擎）→ detectors（纯函数）→ arbiter（优先级）→ clock（唯一写时间步）
-- 安装：把整个文件夹放进 %LOCALAPPDATA%\MDL\Helldivers2\Mods\skip_wait（见 README 的 B 路线）
local ctx = ...

local VERSION = '0.12.1-beta.1'
local DIR = (type(ctx) == 'table' and type(ctx.dir) == 'string' and ctx.dir ~= '') and ctx.dir or '.'

-- MDL3 用「注册脚本的 chunk 源路径」给 mod 选项归组，格式是 mods/<作者>/<mod>/<文件>。
-- 我们是被 MDL 部署的 Lua mod，源路径是绝对路径，匹配不上；这里把 chunk 名写成
-- mods/Reroll24/skip_wait/<文件>，MDL3 才会把 6 个分节认成同一个 mod。
local OWNER = 'Reroll24'
local MOD = 'skip_wait'

local function open_module(rel)
    local path = DIR .. '/' .. rel
    local f = io.open(path, 'rb')
    if not f then
        path = DIR .. '\\' .. rel:gsub('/', '\\')
        f = io.open(path, 'rb')
    end
    if not f then return nil, 'cannot open ' .. DIR .. '/' .. rel end
    local src = f:read('*a')
    f:close()
    local leaf = rel:match('([^/]+)$') or rel
    local chunk, err = loadstring(src, '@mods/' .. OWNER .. '/' .. MOD .. '/' .. leaf)
    if not chunk then return nil, err end
    local ok, mod = pcall(chunk)
    if not ok then return nil, mod end
    return mod
end

local function empty_mod(why)
    if type(ctx) == 'table' and type(ctx.log) == 'function' then
        pcall(ctx.log, '[skipwait] not started: ' .. tostring(why))
    end
    return { name = 'Skip Wait (MDL3)', version = VERSION, on_enable = function() end,
             on_update = function() end, on_disable = function() end }
end

local loaded = {}
local function need(rel)
    local mod, err = open_module(rel)
    if not mod then return nil, rel .. ': ' .. tostring(err) end
    loaded[#loaded + 1] = rel
    return mod
end

local LogM      = need('core/log.lua')
local LocalesM  = need('core/locales.lua')
local DefaultsM = need('core/defaults.lua')
local SettingsM = need('core/settings.lua')
local SnapshotM = need('core/snapshot.lua')
local ClockM    = need('core/clock.lua')
local ArbiterM  = need('core/arbiter.lua')
local DebriefM  = need('detectors/debrief.lua')
local ElevatorM = need('detectors/elevator.lua')
local LoginM    = need('detectors/login.lua')
local FtlM      = need('detectors/ftl.lua')
local LobbyM    = need('detectors/lobby.lua')
local CryoM     = need('detectors/cryo.lua')
local HellpodM  = need('detectors/hellpod.lua')
local ExitM     = need('detectors/hellpod_exit.lua')
local DropM     = need('detectors/hellpod_drop.lua')
local PelicanM  = need('detectors/pelican.lua')
if not (LogM and DefaultsM and SettingsM and SnapshotM and ClockM and ArbiterM
        and DebriefM and ElevatorM and LoginM and FtlM and LobbyM and CryoM
        and HellpodM and ExitM and DropM and PelicanM) then
    return empty_mod('module load failed')
end

local sr = stingray
if type(sr) ~= 'table' or type(sr.Application) ~= 'table'
    or type(sr.Application.set_time_step_policy) ~= 'function' then
    return empty_mod('no Application.set_time_step_policy')
end

local now = os.clock
local log = LogM.new(ctx)

local DEFS = DefaultsM

local settings = SettingsM.new(log, now, LocalesM)
settings.register(DEFS)

local clock = ClockM.new(sr, log, now)
local snapshot = SnapshotM.new(sr, log, now)
local arbiter = ArbiterM.new(clock, log)
arbiter.add(DebriefM.new(settings, log))
arbiter.add(ElevatorM.new(settings, log))
arbiter.add(LoginM.new(settings, log))
arbiter.add(LobbyM.new(settings, log))
arbiter.add(CryoM.new(settings, log))
arbiter.add(HellpodM.new(settings, log))
arbiter.add(ExitM.new(settings, log))
arbiter.add(DropM.new(settings, log))
arbiter.add(PelicanM.new(settings, log))
arbiter.add(FtlM.new(settings, log))

log.fmt('Skip Wait v%s started; modules: %s', VERSION, table.concat(loaded, ', '))
local has_menu = false
do
    local ok, menu = pcall(function() return _G.ModOptionsMenu end)
    has_menu = ok and menu ~= nil
end
if has_menu then log.write('ModOptionsMenu present')
else log.write('ModOptionsMenu absent, using defaults') end
log.flush()

local active, errors = true, 0

local mod = {
    name = 'Skip Wait (MDL3)',
    version = VERSION,
    author = 'LuaModDev',

    on_enable = function()
        active = true
        log.write('enabled')
        log.flush()
    end,

    on_update = function(_, dt)
        if not active then return end
        local ok, err = pcall(function()
            settings.sync()
            log.verbose = settings.get('verbose') == true
            if not settings.get('enabled') then
                clock.restore('master off')
                log.flush()
                return
            end
            local snap = snapshot.update()
            arbiter.step(snap, dt or 0)
            log.flush()
        end)
        if not ok then
            errors = errors + 1
            log.error(tostring(err))
            if errors >= 5 then
                active = false
                clock.restore('too many errors')
                log.write('disabled after 5 errors')
                log.flush()
            end
        end
    end,

    on_disable = function()
        active = false
        clock.restore('disable')
        log.write('disabled')
        log.flush()
    end,
}

return mod
