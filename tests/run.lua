-- tests/run.lua · 离线跑 detector + 仲裁链，不需要游戏
-- 用法：在 mods/skip_wait 下执行  lua tests/run.lua
local ROOT = (arg and arg[1]) or '.'

local function load(rel)
    local chunk = assert(loadfile(ROOT .. '/' .. rel))
    return chunk()
end

local fake      = load('tests/fake.lua')
local LogM      = load('core/log.lua')
local SettingsM = load('core/settings.lua')
local SnapshotM = load('core/snapshot.lua')
local ClockM    = load('core/clock.lua')
local ArbiterM  = load('core/arbiter.lua')
local DebriefM  = load('detectors/debrief.lua')
local ElevatorM = load('detectors/elevator.lua')
local LoginM    = load('detectors/login.lua')
local FtlM      = load('detectors/ftl.lua')
local LobbyM    = load('detectors/lobby.lua')
local CryoM     = load('detectors/cryo.lua')
local HellpodM  = load('detectors/hellpod.lua')
local ExitM     = load('detectors/hellpod_exit.lua')
local DropM     = load('detectors/hellpod_drop.lua')
local PelicanM  = load('detectors/pelican.lua')
local DEFS      = load('core/defaults.lua')

local fails = 0
local function ok(cond, what)
    if cond then
        print('PASS  ' .. what)
    else
        fails = fails + 1
        print('FAIL  ' .. what)
    end
end

local function harness()
    local g = fake.new()
    local lines = {}
    local log = LogM.new({ log = function(text) lines[#lines + 1] = text end })
    local clock2 = function() return g.time end

    local settings = SettingsM.new(log, clock2)
    settings.register(DEFS)

    local snapshot = SnapshotM.new(g.sr, log, clock2)
    local clock = ClockM.new(g.sr, log, clock2)
    local arbiter = ArbiterM.new(clock, log)
    arbiter.add(DebriefM.new(settings, log))
    arbiter.add(ElevatorM.new(settings, log))
    arbiter.add(LoginM.new(settings, log))
    arbiter.add(FtlM.new(settings, log))
    arbiter.add(LobbyM.new(settings, log))
    arbiter.add(CryoM.new(settings, log))
    arbiter.add(HellpodM.new(settings, log))
    arbiter.add(ExitM.new(settings, log))
    arbiter.add(DropM.new(settings, log))
    arbiter.add(PelicanM.new(settings, log))

    local h = { g = g, log = log, settings = settings, clock = clock,
                snapshot = snapshot, arbiter = arbiter, lines = lines }

    function h.tick(dt)
        g.time = g.time + dt
        local snap = snapshot.update()
        arbiter.step(snap, dt)
        log.flush()
    end

    function h.step_to(t)
        local guard = 0
        while g.time < t - 1e-9 do
            h.tick(0.1)
            guard = guard + 1
            if guard > 100000 then error('runaway loop at ' .. tostring(g.time)) end
        end
    end

    return h
end

-- 1. 结算：船上 → 任务 → 上机 → 入座 → 空场景 → 4x → 20 秒上限
local function scenario_debrief()
    local h = harness()
    h.g.set_units{ markers = 3, avatars = 1, total = 3000, state = 36 }
    h.step_to(2.5)                                     -- 船上挂 2 秒 → armed
    ok(h.g.rate == 1, 'debrief: 船上不加速')

    h.g.set_units{ markers = 0, avatars = 1, total = 3000, state = 36 }
    h.step_to(8.0)                                     -- 任务内稳定 5 秒 → mission

    h.g.set_units{ markers = 0, avatars = 1, total = 3000, state = 89 }
    h.step_to(9.0)                                     -- 89 → boarding

    h.g.set_units{ markers = 0, avatars = 1, total = 3000, state = 90 }
    h.step_to(12.0)                                    -- 90 坐稳 → seated / transit

    h.g.new_world()                                    -- 换世界：空结算场景
    h.g.set_units{ markers = 0, avatars = 0, total = 12 }
    h.step_to(15.0)
    ok(h.g.rate == 4, 'debrief: 空结算场景加速到 4x')

    h.step_to(34.0)
    ok(h.g.rate == 1, 'debrief: 20 秒上限后回 1x')
end

-- 2. 电梯：必须先是任务、再回船；回船后平台同步抬升 → 2x；停止 → 1x
local function scenario_elevator()
    local h = harness()
    h.g.set_units{ markers = 0, avatars = 1, total = 3000, state = 36 }
    for _ = 1, 10 do h.tick(0.1) end                    -- 先处于任务世界
    h.g.set_units{ markers = 0, avatars = 1, total = 3000, state = 90 }
    for _ = 1, 5 do h.tick(0.1) end                     -- 上机撤离（这是回船电梯的前提）
    h.g.new_world()
    h.g.set_units{ markers = 3, avatars = 1, total = 300, elevator = true, floor = 5.0, rise = 0 }
    for _ = 1, 10 do h.tick(0.1) end                    -- 回船 → ship_at 落定

    for i = 1, 12 do
        h.g.set_units{ markers = 3, avatars = 1, total = 300, elevator = true, floor = 5.0, rise = 0.01 * i }
        h.tick(0.2)
    end
    ok(h.g.rate == 2, 'elevator: 平台同步抬升时 2x')

    for _ = 1, 8 do h.tick(0.2) end
    ok(h.g.rate == 1, 'elevator: 平台停下后回 1x')
end

-- 3. 没经历任务就不该盯电梯（上一版在船上一挂机就每 15 秒刷两条日志）
local function scenario_no_spurious_elevator()
    local h = harness()
    h.g.set_units{ markers = 3, avatars = 1, total = 300, elevator = true, floor = 5.0, rise = 0 }
    for _ = 1, 60 do h.tick(0.1) end
    local watched = 0
    for _, line in ipairs(h.lines) do
        if line:find('ELEVATOR watching') then watched = watched + 1 end
    end
    ok(watched == 0, 'elevator: 没经历任务时不上岗')
end

-- 4. 一次回船只开一个观察窗：窗口到期后不该原地重开
local function scenario_single_window()
    local h = harness()
    h.g.set_units{ markers = 0, avatars = 1, total = 3000, state = 36 }
    for _ = 1, 10 do h.tick(0.1) end
    h.g.set_units{ markers = 0, avatars = 1, total = 3000, state = 90 }
    for _ = 1, 5 do h.tick(0.1) end
    h.g.new_world()
    h.g.set_units{ markers = 3, avatars = 1, total = 300, elevator = true, floor = 5.0, rise = 0 }
    for _ = 1, 1100 do h.tick(0.1) end          -- 110 秒：跨过 60 秒窗口和 90 秒总窗
    local watched = 0
    for _, line in ipairs(h.lines) do
        if line:find('ELEVATOR watching') then watched = watched + 1 end
    end
    ok(watched == 1, 'elevator: 一次回船只开一个观察窗')
end

-- 5. 任务世界：一次都不该写非 1x
local function scenario_no_mission_boost()
    local h = harness()
    h.g.set_units{ markers = 0, avatars = 1, total = 3000, state = 36 }
    for _ = 1, 100 do h.tick(0.1) end
    ok(h.g.rate == 1, '任务世界内不加速')
    local writes = 0
    for _, c in ipairs(h.g.calls) do
        if c.kind == 'external_multiplier' and c.value ~= 1 then writes = writes + 1 end
    end
    ok(writes == 0, '任务世界内没有写过非 1x')
end

-- 6. FTL：主世界之外的小世界挂着炮 → 8x；外景结束 → 1x
local function scenario_ftl()
    local h = harness()
    h.g.set_units{ markers = 3, avatars = 1, total = 3000, state = 36, camera = true }
    local ftl = h.g.add_world{ total = 600, cannon = true }
    for _ = 1, 10 do h.tick(0.1) end
    ok(h.g.rate == 8, 'ftl: 炮舰小世界 600 单位 → 8x')

    ftl.units = {}
    for _ = 1, 10 do h.tick(0.1) end
    ok(h.g.rate == 1, 'ftl: 外景结束（炮没了）→ 1x')
end

-- 7. 登录：外景（主世界就是炮舰）→ 船加载 → 相机先窄后宽
local function scenario_login()
    local h = harness()
    h.g.set_units{ total = 60, cannon = true }
    for _ = 1, 10 do h.tick(0.1) end
    ok(h.g.rate == 8, 'login: 登录外景 8x')

    h.g.new_world()
    h.g.set_units{ markers = 3, avatars = 1, total = 3000, state = 36, camera = true }
    h.g.fov = 0.262
    for _ = 1, 10 do h.tick(0.1) end
    ok(h.g.rate == 8, 'login: 船加载后走舰桥 8x')

    h.g.fov = 1.134
    for _ = 1, 5 do h.tick(0.1) end
    ok(h.g.rate == 1, 'login: 相机放开 → 1x')
end

-- 8. 加入/离开大厅：11~30 单位的小外景，发生在我们已加载的船之上 → 8x
local function scenario_lobby()
    local h = harness()
    h.g.set_units{ markers = 3, avatars = 1, total = 3000, state = 36, camera = true }
    for _ = 1, 10 do h.tick(0.1) end              -- 船先加载好

    local shot = h.g.add_world{ total = 13, cannon = true }
    for _ = 1, 10 do h.tick(0.1) end
    ok(h.g.rate == 8, 'lobby: 加入大厅的小外景 8x')

    h.g.drop_world(shot)
    for _ = 1, 10 do h.tick(0.1) end
    ok(h.g.rate == 1, 'lobby: 外景结束 → 1x')
end

-- 9. 回归：真实循环是每帧调用、快照 0.2 秒才刷新。
--    上一版每帧都拿同一份快照采样，零位移把 samples 清零，电梯永远确认不了。
local function scenario_elevator_frame_poll()
    local h = harness()
    h.g.set_units{ markers = 0, avatars = 1, total = 3000, state = 36 }
    for _ = 1, 10 do h.tick(0.1) end
    h.g.set_units{ markers = 0, avatars = 1, total = 3000, state = 90 }
    for _ = 1, 5 do h.tick(0.1) end
    h.g.new_world()
    h.g.set_units{ markers = 3, avatars = 1, total = 300, elevator = true, floor = 5.0, rise = 0 }
    for _ = 1, 10 do h.tick(0.1) end

    for step = 1, 120 do
        if step % 12 == 0 then
            h.g.set_units{ markers = 3, avatars = 1, total = 300, elevator = true,
                           floor = 5.0, rise = (step / 12) * 0.02 }
        end
        h.tick(1 / 60)
    end
    ok(h.g.rate == 2, 'elevator: 60fps 轮询下也能确认抬升')
end

-- 10. FTL 到达时同一个世界会缩到 23 单位，不能被大厅检测器抢走
local function scenario_ftl_arrival_not_lobby()
    local h = harness()
    h.g.set_units{ markers = 3, avatars = 1, total = 3000, state = 36, camera = true }
    local w = h.g.add_world{ total = 584, cannon = true }
    for _ = 1, 10 do h.tick(0.1) end
    ok(h.g.rate == 8, 'ftl: 584 单位 → 8x')

    w.units = { { kind = '03544419135a9935', alive = true } }
    for _ = 1, 10 do h.tick(0.1) end
    ok(h.g.rate == 8, 'ftl: 缩成到达镜头仍是 8x')
    local lobby = 0
    for _, line in ipairs(h.lines) do
        if line:find('LOBBY outside shot') then lobby = lobby + 1 end
    end
    ok(lobby == 0, 'lobby: 不抢 FTL 的世界')
end

-- 11. 冷冻舱：舱内循环 → 出舱动画 → 结束
local function scenario_cryo()
    local h = harness()
    h.g.set_units{ markers = 3, avatars = 1, total = 3000, state = 0, camera = true }
    for _ = 1, 10 do h.tick(0.1) end
    ok(h.g.rate == 8, 'cryo: 舱内循环 8x')

    h.g.set_units{ markers = 3, avatars = 1, total = 3000, state = 6, camera = true }
    for _ = 1, 10 do h.tick(0.1) end
    ok(h.g.rate == 8, 'cryo: 出舱动画 8x')

    h.g.set_units{ markers = 3, avatars = 1, total = 3000, state = 36, camera = true }
    for _ = 1, 6 do h.tick(0.1) end
    ok(h.g.rate == 1, 'cryo: 出舱结束 → 1x')
end

-- 12. 电梯：平台还没动就要开始加速（用户反馈晚 1~2 秒）
local function scenario_elevator_early()
    local h = harness()
    h.g.set_units{ markers = 0, avatars = 1, total = 3000, state = 36 }
    for _ = 1, 10 do h.tick(0.1) end
    h.g.set_units{ markers = 0, avatars = 1, total = 3000, state = 90 }
    for _ = 1, 5 do h.tick(0.1) end
    h.g.new_world()
    h.g.set_units{ markers = 3, avatars = 1, total = 300, elevator = true, floor = 5.0, rise = 0 }
    for _ = 1, 5 do h.tick(0.1) end
    ok(h.g.rate == 2, 'elevator: 平台还没动就已经开始加速')
end

-- 13. 空降舱：踏进（15）→ 舱内（17）→ 结束；以及鹈鹕起飞默认关闭
local function scenario_hellpod()
    local h = harness()
    h.settings.values.hellpod_exit = 1                    -- 只测进舱，出舱另有一条
    h.g.set_units{ markers = 3, avatars = 1, total = 3000, state = 15, camera = true }
    for _ = 1, 10 do h.tick(0.1) end
    ok(h.g.rate == 8, 'hellpod: 踏进空降舱 8x')

    h.g.set_units{ markers = 3, avatars = 1, total = 3000, state = 17, camera = true }
    for _ = 1, 10 do h.tick(0.1) end
    ok(h.g.rate == 8, 'hellpod: 舱内循环 8x')

    h.g.fov = 1.222                      -- 镜头拉到投放地图
    for _ = 1, 6 do h.tick(0.1) end
    ok(h.g.rate == 1, 'hellpod: 镜头到投放地图 → 1x')

    h.g.fov = 1.134
    h.g.set_units{ markers = 3, avatars = 1, total = 3000, state = 36, camera = true }
    for _ = 1, 6 do h.tick(0.1) end
    ok(h.g.rate == 1, 'hellpod: 人出舱 → 1x')
end

local function scenario_pelican()
    local h = harness()
    h.g.set_units{ markers = 0, avatars = 1, total = 3000, state = 90 }
    for _ = 1, 10 do h.tick(0.1) end
    ok(h.g.rate == 1, 'pelican: 默认关闭，上机也不加速')

    h.settings.values.pelican_solo = 8
    for _ = 1, 10 do h.tick(0.1) end
    ok(h.g.rate == 8, 'pelican: 单人档打开 → 8x')

    h.g.set_players(2)
    for _ = 1, 10 do h.tick(0.1) end
    ok(h.g.rate == 1, 'pelican: 多人时一律不碰')
end

-- 14. 世界对象是复用的：FTL 用过的小世界，之后当「加入队伍外景」还要能加速
local function scenario_rejoin_after_ftl()
    local h = harness()
    h.g.set_units{ markers = 3, avatars = 1, total = 3000, state = 36, camera = true }
    local w = h.g.add_world{ total = 584, cannon = true }
    for _ = 1, 20 do h.tick(0.1) end
    ok(h.g.rate == 8, 'rejoin: 先当 FTL 8x')

    w.units = {}
    for _ = 1, 700 do h.tick(0.1) end          -- 70 秒后（超过 60 秒的 FTL 记忆）

    local units = {}
    for i = 1, 22 do units[i] = { kind = 'ffffffffffffffff', alive = true } end
    units[23] = { kind = '03544419135a9935', alive = true }
    w.units = units
    for _ = 1, 10 do h.tick(0.1) end
    ok(h.g.rate == 8, 'rejoin: 同一个世界再当加入外景仍加速')
end

-- 15. 空投发射：只加速「确认投放 → 舰桥镜头推进」；船外发射/坠落不碰
local function scenario_hellpod_drop()
    local h = harness()
    h.settings.values.hellpod_entry = 1
    h.settings.values.hellpod_exit = 1
    h.g.set_units{ markers = 3, avatars = 1, total = 3000, state = 17, camera = true }
    h.g.fov = 1.222
    for _ = 1, 6 do h.tick(0.1) end
    ok(h.g.rate == 1, 'hellpod drop: 默认关闭（投放地图上不加速）')

    h.settings.values.hellpod_drop = 8
    for _ = 1, 4 do h.tick(0.1) end                       -- 地图还开着时先武装
    h.g.fov = 1.134                                       -- 点确认，地图收起，舰桥镜头推进
    for _ = 1, 5 do h.tick(0.1) end
    ok(h.g.rate == 8, 'hellpod drop: 确认后舰桥推进 8x')

    h.g.add_world{ total = 24, cannon = true, launch = true }   -- 镜头切到船外
    for _ = 1, 6 do h.tick(0.1) end
    ok(h.g.rate == 1, 'hellpod drop: launch 世界出现（船外镜头）→ 1x')

    local over = 0
    for _, line in ipairs(h.lines) do
        if line:find('launch shot begins') then over = over + 1 end
    end
    ok(over == 1, 'hellpod drop: 在船外镜头开始处收工')
end

-- 15b. 空投发射：等不到 launch 世界（一直 17）也有 8 游戏秒兜底
local function scenario_hellpod_drop_window()
    local h = harness()
    h.settings.values.hellpod_entry = 1
    h.settings.values.hellpod_exit = 1
    h.settings.values.hellpod_drop = 8
    h.g.set_units{ markers = 3, avatars = 1, total = 3000, state = 17, camera = true }
    h.g.fov = 1.222
    for _ = 1, 6 do h.tick(0.1) end
    h.g.fov = 1.134
    for _ = 1, 4 do h.tick(0.1) end
    ok(h.g.rate == 8, 'hellpod drop: 舰桥推进中')

    for _ = 1, 20 do h.tick(0.1) end                      -- 2 秒真实 = 16 游戏秒
    ok(h.g.rate == 1, 'hellpod drop: 8 游戏秒后收工')
    local stopped = 0
    for _, line in ipairs(h.lines) do
        if line:find('HELLPOD DROP over (window', 1, true) then stopped = stopped + 1 end
    end
    ok(stopped == 1, 'hellpod drop: 兜底只报一次')
end

-- 15c. 空投发射：取消空投也会关地图，但不该一直占着（交给 hellpod_exit）
local function scenario_hellpod_drop_cancel()
    local h = harness()
    h.settings.values.hellpod_entry = 1
    h.settings.values.hellpod_exit = 8
    h.settings.values.hellpod_drop = 8
    h.g.set_units{ markers = 3, avatars = 1, total = 3000, state = 17, camera = true }
    h.g.fov = 1.222
    for _ = 1, 6 do h.tick(0.1) end
    h.g.fov = 1.134
    h.g.set_units{ markers = 3, avatars = 1, total = 3000, state = 16, camera = true }
    for _ = 1, 6 do h.tick(0.1) end
    ok(h.g.rate == 8, 'hellpod drop: 取消时出舱检测器继续 8x')

    for _ = 1, 30 do h.tick(0.1) end
    ok(h.g.rate == 1, 'hellpod drop: 取消段结束后 1x')
end

-- 16. 瞬时跳过：登录外景用 jump 推进，倍率保持 1x，额度用完退回 8x
local function scenario_instant()
    local h = harness()
    h.g.set_units{ total = 60, cannon = true }
    for _ = 1, 40 do h.tick(0.1) end
    ok(h.g.jumps == 0, 'instant: 开关关着时一次 jump 都不发')

    h.settings.values.skip_login = true
    for _ = 1, 10 do h.tick(0.1) end
    ok(h.g.jumps > 0, 'instant: 打开后用 jump 推进')
    ok(h.g.rate == 1, 'instant: 跳的时候倍率保持 1x')

    for _ = 1, 40 do h.tick(0.1) end
    ok(h.g.jumps == 22, 'instant: 额度用完就停（正好 22 次）')
    ok(h.g.rate == 8, 'instant: 额度用完后退回 8x')
end

-- 17. 「我」的判定：队友进空降舱不该让我加速
local function scenario_other_player_pod()
    local h = harness()
    h.g.set_units{ markers = 3, avatars = 2, total = 3000, state = 36, camera = true }
    for _ = 1, 10 do h.tick(0.1) end
    ok(h.g.rate == 1, 'ours: 两个人都在正常状态时不加速')

    local AVATAR = '4d1c334d294dfa97'
    for _, u in ipairs(h.g.world.units) do
        if u.kind == AVATAR and u.pos[1] == 20 then u.state = 15 end   -- 队友进舱
    end
    for _ = 1, 10 do h.tick(0.1) end
    ok(h.g.rate == 1, 'ours: 队友进空降舱不加速我')
end

-- 18. 投放地图上不许反复启停（上一版每帧「开始→立刻结束」，日志刷了几万行）
local function scenario_hellpod_latch()
    local h = harness()
    h.g.set_units{ markers = 3, avatars = 1, total = 3000, state = 17, camera = true }
    h.g.fov = 0.611
    for _ = 1, 10 do h.tick(0.1) end
    ok(h.g.rate == 8, 'hellpod: 舱内 8x')

    h.g.fov = 1.222
    for _ = 1, 30 do h.tick(0.1) end
    ok(h.g.rate == 1, 'hellpod: 到投放地图后回 1x')
    local starts = 0
    for _, line in ipairs(h.lines) do
        if line:find('HELLPOD starts') then starts = starts + 1 end
    end
    ok(starts == 1, 'hellpod: 到地图后不再反复启停')
end

-- 19. 出空降舱：投放地图上按 ESC 取消 → 镜头离开地图 → 8x；回到正常 → 1x
local function scenario_hellpod_exit()
    local h = harness()
    h.settings.values.hellpod_entry = 1                   -- 只测出舱，别让进舱检测器掺和
    h.g.set_units{ markers = 3, avatars = 1, total = 3000, state = 17, camera = true }
    h.g.fov = 1.222
    for _ = 1, 10 do h.tick(0.1) end
    ok(h.g.rate == 1, 'hellpod exit: 投放地图上不加速')

    h.g.fov = 1.134                                       -- 按 ESC，镜头离开投放地图
    for _ = 1, 4 do h.tick(0.1) end
    ok(h.g.rate == 8, 'hellpod exit: 镜头离开投放地图 → 8x')

    h.g.set_units{ markers = 3, avatars = 1, total = 3000, state = 36, camera = true }
    for _ = 1, 30 do h.tick(0.1) end
    ok(h.g.rate == 1, 'hellpod exit: 人回到正常 → 1x')

    local starts = 0
    for _, line in ipairs(h.lines) do
        if line:find('HELLPOD EXIT starts') then starts = starts + 1 end
    end
    ok(starts == 1, 'hellpod exit: 一次取消只开一段')
end

-- 19b. 出空降舱：地图还没出来就按 ESC（舱内 17 → 爬出 16 → 正常 36），也要跳
local function scenario_hellpod_exit_premap()
    local h = harness()
    h.settings.values.hellpod_entry = 1
    h.g.set_units{ markers = 3, avatars = 1, total = 3000, state = 17, camera = true }
    h.g.fov = 0.611                                       -- 舱内特写，地图还没开
    for _ = 1, 10 do h.tick(0.1) end
    ok(h.g.rate == 1, 'hellpod exit: 舱内等地图时不加速')

    h.g.set_units{ markers = 3, avatars = 1, total = 3000, state = 16, camera = true }
    for _ = 1, 8 do h.tick(0.1) end
    ok(h.g.rate == 8, 'hellpod exit: 地图出来前取消（姿态 16）也 → 8x')

    h.g.set_units{ markers = 3, avatars = 1, total = 3000, state = 36, camera = true }
    for _ = 1, 30 do h.tick(0.1) end
    ok(h.g.rate == 1, 'hellpod exit: 地图出来前取消，回正常后 → 1x')
end

-- 20. 出空降舱：真投放（launch 世界）不能被当成取消，也不跟 hellpod_drop 抢
local function scenario_hellpod_exit_launch()
    local h = harness()
    h.settings.values.hellpod_entry = 1
    h.g.set_units{ markers = 3, avatars = 1, total = 3000, state = 17, camera = true }
    h.g.fov = 1.222
    for _ = 1, 6 do h.tick(0.1) end
    h.g.add_world{ total = 30, cannon = true, launch = true }
    for _ = 1, 4 do h.tick(0.1) end                       -- 先让快照看到 launch 世界
    h.g.fov = 1.134                                       -- 点发射，地图收起
    for _ = 1, 15 do h.tick(0.1) end
    ok(h.g.rate == 1, 'hellpod exit: 真投放默认不加速（发射段开关关着）')
    local starts = 0
    for _, line in ipairs(h.lines) do
        if line:find('HELLPOD EXIT starts') then starts = starts + 1 end
    end
    ok(starts == 0, 'hellpod exit: 发射不启出舱段')
end

-- 21. 出空降舱：队友在舱里、我在船上，不该加速我
local function scenario_hellpod_exit_other_player()
    local h = harness()
    h.settings.values.hellpod_entry = 1
    h.g.set_units{ markers = 3, avatars = 2, total = 3000, state = 36, camera = true }
    local AVATAR = '4d1c334d294dfa97'
    for _, u in ipairs(h.g.world.units) do
        if u.kind == AVATAR and u.pos and u.pos[1] == 20 then u.state = 17 end
    end
    h.g.fov = 1.222
    for _ = 1, 10 do h.tick(0.1) end
    ok(h.g.rate == 1, 'hellpod exit: 队友在投放准备里不加速我')

    h.g.fov = 1.134
    for _ = 1, 10 do h.tick(0.1) end
    ok(h.g.rate == 1, 'hellpod exit: 队友那段结束也不误加速')
end

-- 22. 出空降舱：跳过开关用 jump；窗口到点必停（不再等 36）
local function scenario_hellpod_exit_skip()
    local h = harness()
    h.settings.values.hellpod_entry = 1
    h.settings.values.skip_hellpod_exit = true
    h.g.set_units{ markers = 3, avatars = 1, total = 3000, state = 17, camera = true }
    h.g.fov = 1.222
    for _ = 1, 6 do h.tick(0.1) end
    h.g.fov = 1.134                                       -- 按 ESC，姿态一直停在 17
    for _ = 1, 5 do h.tick(0.1) end
    ok(h.g.jumps > 0, 'hellpod exit: 打开「跳过」后改用 jump')
    ok(h.g.rate == 1, 'hellpod exit: 跳的时候倍率保持 1x')

    for _ = 1, 60 do h.tick(0.1) end                      -- 6 秒后窗口必须已经收了
    ok(h.g.rate == 1, 'hellpod exit: 窗口到点后不再申请')
    local over = 0
    for _, line in ipairs(h.lines) do
        if line:find('HELLPOD EXIT over') then over = over + 1 end
    end
    ok(over == 1, 'hellpod exit: 窗口只收一次')
end

-- 22b. 出空降舱：出舱途中又进舱（地图重开）→ 立刻收工，不去加速地图
local function scenario_hellpod_exit_reenter()
    local h = harness()
    h.settings.values.hellpod_entry = 1
    h.g.set_units{ markers = 3, avatars = 1, total = 3000, state = 17, camera = true }
    h.g.fov = 1.222
    for _ = 1, 6 do h.tick(0.1) end
    h.g.fov = 1.134
    for _ = 1, 5 do h.tick(0.1) end
    ok(h.g.rate == 8, 'hellpod exit: 出舱窗口 8x')

    h.g.fov = 1.222                                       -- 又进舱，投放地图重新打开
    for _ = 1, 4 do h.tick(0.1) end
    ok(h.g.rate == 1, 'hellpod exit: 重新进舱、地图重开就收工')

    local why = 0
    for _, line in ipairs(h.lines) do
        if line:find('back on the drop map') then why = why + 1 end
    end
    ok(why == 1, 'hellpod exit: 收工原因记为地图重开')
end

-- 23. 出空降舱：镜头还挂着投放地图、人先动起来（相机切得慢）也要认
local function scenario_hellpod_exit_camera_late()
    local h = harness()
    h.settings.values.hellpod_entry = 1
    h.g.set_units{ markers = 3, avatars = 1, total = 3000, state = 17, camera = true }
    h.g.fov = 1.222
    for _ = 1, 6 do h.tick(0.1) end
    ok(h.g.rate == 1, 'hellpod exit: 地图上先不动')

    h.g.set_units{ markers = 3, avatars = 1, total = 3000, state = 36, camera = true }
    for _ = 1, 6 do h.tick(0.1) end                    -- 镜头还没切回来
    ok(h.g.rate == 8, 'hellpod exit: 镜头没切回来也跟着动')

    h.g.fov = 1.134
    for _ = 1, 25 do h.tick(0.1) end
    ok(h.g.rate == 1, 'hellpod exit: 镜头回到正常后收工')
end

-- 25. 设置分类：每项都有 group，分类连续且编号有序
local function scenario_settings_groups()
    local order, all = {}, true
    for _, d in ipairs(DEFS) do
        if type(d.group) ~= 'string' or d.group == '' then all = false end
        if d.group ~= order[#order] then order[#order + 1] = d.group end
    end
    ok(all, 'settings: 每一项都有分类')
    ok(#order == 6, 'settings: 分成 6 组')
    ok(order[1] == 'Skip Wait / 跳过人生' and order[#order] == '05 鹈鹕起飞',
       'settings: 第一节同时也是菜单入口名')
end

-- 26. 设置只注册一个 mod 入口（spec.mod 不能拿来做分类，否则会变成 6 个 mod）
local function scenario_settings_group_spec()
    local seen = {}
    local saved = _G.ModOptionsMenu
    _G.ModOptionsMenu = {
        api = 1,
        register_option = function(id, spec) seen[id] = spec; return true end,
        get = function() return nil end,
    }
    local log = LogM.new({ log = function() end })
    local settings = SettingsM.new(log, function() return 0 end)
    settings.register(DEFS)
    settings.sync()
    _G.ModOptionsMenu = saved

    local groups, ids, count = {}, {}, 0
    for _, spec in pairs(seen) do
        groups[spec.mod] = true
        ids[spec.mod_id] = true
        count = count + 1
    end
    local ng, ni = 0, 0
    for _ in pairs(groups) do ng = ng + 1 end
    for _ in pairs(ids) do ni = ni + 1 end
    ok(ng == 6, 'settings: 6 个分节（spec.mod = 分节标题）')
    ok(ni == 6, 'settings: 每节一个稳定 mod_id')
    ok(count == 18, 'settings: 18 项都注册上了')
    ok(seen['skipwait.hellpod_entry'] and seen['skipwait.hellpod_entry'].mod == '04 空降舱'
       and seen['skipwait.hellpod_entry'].mod_id == 'skipwait.hellpod',
       'settings: 空降舱项归到 04 空降舱 / skipwait.hellpod')

    -- 组间用 gap 留空行做视觉分隔
    ok(seen['skipwait.hellpod_entry'] and seen['skipwait.hellpod_entry'].gap == true,
       'settings: 空降舱组前留空行')
    ok(seen['skipwait.hellpod_exit'] and seen['skipwait.hellpod_exit'].gap ~= true,
       'settings: 组内不留空行')
end

-- 24. 每个场景的独立开关
local function scenario_scene_skip()
    local h = harness()
    h.settings.values.skip_cryo = true
    h.g.set_units{ markers = 3, avatars = 1, total = 3000, state = 0, camera = true }
    for _ = 1, 10 do h.tick(0.1) end
    ok(h.g.jumps > 0, 'skip: 打开「冷冻舱 · 跳过」后改用 jump')
    ok(h.g.rate == 1, 'skip: 跳的时候倍率保持 1x')
end

-- 20. 中途放弃任务：没有上机姿态，回船不该开电梯窗口，也不该加速
local function scenario_abandon()
    local h = harness()
    h.g.set_units{ markers = 0, avatars = 1, total = 3000, state = 36 }
    for _ = 1, 20 do h.tick(0.1) end
    h.g.new_world()
    h.g.set_units{ markers = 3, avatars = 1, total = 300, elevator = true, floor = 5.0, rise = 0 }
    for _ = 1, 10 do h.tick(0.1) end                    -- 先让船稳定下来
    h.g.add_world{ total = 28, cannon = true }          -- 放弃任务时冒出的回船外景
    for _ = 1, 40 do h.tick(0.1) end
    ok(h.g.rate == 1, 'abandon: 中途放弃回船不加速')
    local watched = 0
    for _, line in ipairs(h.lines) do
        if line:find('ELEVATOR watching') then watched = watched + 1 end
    end
    ok(watched == 0, 'abandon: 不开电梯观察窗')
end

-- 16. 空降舱发射的小外景（带 launch kind）不该被当成大厅切换
local function scenario_launch_not_lobby()
    local h = harness()
    h.g.set_units{ markers = 3, avatars = 1, total = 3000, state = 36, camera = true }
    for _ = 1, 10 do h.tick(0.1) end
    h.g.add_world{ total = 30, cannon = true, launch = true }
    for _ = 1, 15 do h.tick(0.1) end
    ok(h.g.rate == 1, 'lobby: 发射外景不加速')
end

print('-- Skip Wait offline tests --')
scenario_debrief()
scenario_elevator()
scenario_no_spurious_elevator()
scenario_single_window()
scenario_no_mission_boost()
scenario_ftl()
scenario_login()
scenario_lobby()
scenario_elevator_frame_poll()
scenario_ftl_arrival_not_lobby()
scenario_cryo()
scenario_elevator_early()
scenario_hellpod()
scenario_pelican()
scenario_rejoin_after_ftl()
scenario_hellpod_drop()
scenario_hellpod_drop_window()
scenario_hellpod_drop_cancel()
scenario_instant()
scenario_other_player_pod()
scenario_hellpod_latch()
scenario_hellpod_exit()
scenario_hellpod_exit_premap()
scenario_hellpod_exit_launch()
scenario_hellpod_exit_other_player()
scenario_hellpod_exit_skip()
scenario_hellpod_exit_reenter()
scenario_hellpod_exit_camera_late()
scenario_scene_skip()
scenario_settings_groups()
scenario_settings_group_spec()
scenario_abandon()
scenario_launch_not_lobby()

-- 27. addon 入口（给 Bingus Loader 打包用）：require 打包模块 + 挂全局 update
local function scenario_addon_entry()
    local saved_clock, saved_print = os.clock, _G.print
    local saved_stingray, saved_require = _G.stingray, _G.require
    local saved_update, saved_shutdown = _G.update, _G.shutdown

    local g = fake.new()
    local cache = {}
    local PREFIX = 'mods/Reroll24/skip_wait/'
    local function fake_require(name)
        if cache[name] then return cache[name] end
        if name:sub(1, #PREFIX) ~= PREFIX then error('unexpected require ' .. name) end
        local suffix = name:sub(#PREFIX + 1)
        local folder = suffix:find('^core_') and 'core' or 'detectors'
        local stem = suffix:sub(suffix:find('_', 1, true) + 1)
        local chunk = assert(loadfile(folder .. '/' .. stem .. '.lua'))
        cache[name] = chunk()
        return cache[name]
    end

    os.clock = function() return g.time end
    _G.stingray, _G.require, _G.print = g.sr, fake_require, function() end
    _G.update, _G.shutdown = nil, nil

    local chunk = assert(loadfile('addon/entry.lua'))
    local loaded, err = pcall(chunk)
    ok(loaded and type(_G.update) == 'function',
       'addon: 入口可加载并挂上 update' .. (loaded and '' or (' — ' .. tostring(err))))

    g.set_units{ markers = 3, avatars = 1, total = 3000, state = 0, camera = true }
    for _ = 1, 10 do
        g.time = g.time + 0.1
        _G.update(0.1)
    end
    ok(g.rate == 8, 'addon: 冷冻舱同样 8x')

    g.set_units{ markers = 3, avatars = 1, total = 3000, state = 36, camera = true }
    for _ = 1, 6 do
        g.time = g.time + 0.1
        _G.update(0.1)
    end
    ok(g.rate == 1, 'addon: 出舱后 1x')

    os.clock = saved_clock
    _G.stingray, _G.require, _G.print = saved_stingray, saved_require, saved_print
    _G.update, _G.shutdown = saved_update, saved_shutdown
end
scenario_addon_entry()

print(string.format('%s (%d failed)', fails == 0 and 'ALL PASS' or 'FAILED', fails))
os.exit(fails == 0 and 0 or 1)
