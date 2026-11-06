-- HD2-Addon: mods/Reroll24/skip_wait
-- Skip Wait / 跳过人生 —— addon 包入口（运行环境是 MDL3；写法沿用 HD2-Addon 规范，BSL 已失效）。
-- 本地 mod 版入口在 mod.lua；这里是同一套检测器的单资源入口，模块由打包器放在
-- mods/Reroll24/skip_wait/<core_log 之类> 里，用 require 取回。
local NAME = 'mods/Reroll24/skip_wait'
local VERSION = '0.12.2-beta.1'

local function log_path()
    local base = os.getenv('LOCALAPPDATA')
    if type(base) ~= 'string' or base == '' then return nil end
    return base .. '/MDL/Helldivers2/Logs/SkipWait.log'
end

-- 日志：控制台 + MDL 日志目录里的 SkipWait.log
local function say(text)
    text = tostring(text)
    pcall(print, text)
    local path = log_path()
    if not path then return end
    pcall(function()
        local file = io.open(path, 'a')
        if not file then return end
        file:write(text, '\n')
        file:close()
    end)
end

local ctx = { log = say }

local function need(suffix)
    local ok, mod = pcall(require, NAME .. '/' .. suffix)
    if not ok or type(mod) ~= 'table' then
        say('[skipwait] cannot load module ' .. suffix .. ': ' .. tostring(mod))
        return nil
    end
    return mod
end

local LogM      = need('core_log')
local LocalesM  = need('core_locales')
local DefaultsM = need('core_defaults')
local SettingsM = need('core_settings')
local SnapshotM = need('core_snapshot')
local ClockM    = need('core_clock')
local ArbiterM  = need('core_arbiter')
local DebriefM  = need('detectors_debrief')
local ElevatorM = need('detectors_elevator')
local LoginM    = need('detectors_login')
local FtlM      = need('detectors_ftl')
local LobbyM    = need('detectors_lobby')
local CryoM     = need('detectors_cryo')
local HellpodM  = need('detectors_hellpod')
local ExitM     = need('detectors_hellpod_exit')
local DropM     = need('detectors_hellpod_drop')
local PelicanM  = need('detectors_pelican')

if not (LogM and DefaultsM and SettingsM and SnapshotM and ClockM and ArbiterM
        and DebriefM and ElevatorM and LoginM and FtlM and LobbyM and CryoM
        and HellpodM and ExitM and DropM and PelicanM) then
    return
end

local sr = stingray
if type(sr) ~= 'table' or type(sr.Application) ~= 'table'
    or type(sr.Application.set_time_step_policy) ~= 'function' then
    say('[skipwait] not started: no Application.set_time_step_policy')
    return
end

local now = os.clock
local log = LogM.new(ctx)

local settings = SettingsM.new(log, now, LocalesM)
settings.register(DefaultsM)

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

log.fmt('Skip Wait v%s started (addon)', VERSION)
local has_menu = false
do
    local ok, menu = pcall(function() return _G.ModOptionsMenu end)
    has_menu = ok and menu ~= nil
end
if has_menu then log.write('ModOptionsMenu present')
else log.write('ModOptionsMenu absent, using defaults') end
log.flush()

local errors = 0
local function step(dt)
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
end

local previous_update = rawget(_G, 'update')
rawset(_G, 'update', function(...)
    if errors < 5 then
        local ok, err = pcall(step, ...)
        if not ok then
            errors = errors + 1
            log.error(tostring(err))
            if errors >= 5 then
                clock.restore('too many errors')
                log.write('disabled after 5 errors')
                log.flush()
            end
        end
    end
    if type(previous_update) == 'function' then return previous_update(...) end
end)

local previous_shutdown = rawget(_G, 'shutdown')
rawset(_G, 'shutdown', function(...)
    pcall(clock.restore, 'shutdown')
    log.flush()
    if type(previous_shutdown) == 'function' then return previous_shutdown(...) end
end)
