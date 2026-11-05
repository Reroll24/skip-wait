-- core/snapshot.lua · 唯一碰引擎的层
-- 三级刷新：每帧 O(1) / 单位数变化触发 / 慢节流。
-- 未知字段一律给默认值，detector 里不要写 if nil then。
local M = {}

local CENSUS_SECONDS = 0.2
local SESSION_SECONDS = 0.5
local CAM_RETRY = 1
local SLOW_MS = 8          -- 一次普查超过这个毫秒数就记一笔

local SMALL = 1200         -- 到这个规模的小世界才数 kind
local SHIP = 1000          -- 主世界比这个大：船
local MAX_WORLDS = 32

local KIND = {
    avatar   = '4d1c334d294dfa97',   -- content/fac_helldivers/cha_avatar/avatar_helldiver
    marker1  = '9dfd0e3b5172e41c',
    marker2  = 'f74fde620b7c9e60',
    marker3  = 'b91cc2ab0cfb2540',
    elevator = '02016f98826cc83c',
    camera   = '465f4895f3dc98d1',   -- core/units/camera
    launch   = 'e93e9835bce95d4a',   -- 只有空降舱发射那个小世界有
    mapfloor = '96af7d6acb949f34',   -- content/art_shared/meshes/plane_2x2m（配装页地面）
}
-- content/env_ship/hangar/se_destroyer_supportcannon_*
local CANNONS = { '03544419135a9935', '26ef7da30b82246d', '35035d21c9b68391', 'c8ccd4986bf70c7c' }

local function pack(...) return { n = select('#', ...), ... } end

function M.new(sr, log, now)
    local self = { sr = sr, log = log, now = now or os.clock, snap = {}, entries = {}, next_index = 1,
                   next_census = 0, next_session = 0, next_cam = 0, cam_unit = nil,
                   ship_seen = false, sig = nil }

    local snap = self.snap
    snap.units, snap.avatars, snap.markers = 0, 0, 0
    snap.normal, snap.boarding, snap.seated = 0, 0, 0
    snap.pod_loop, snap.pod_out = 0, 0
    snap.elevator, snap.elevator_state = nil, nil
    snap.players, snap.is_host = nil, nil
    snap.world_index, snap.mode, snap.ship_at = 0, 'unknown', nil
    snap.worlds, snap.destroyer, snap.cam_fov = {}, nil, nil

    local function idstring(hex)
        local IdString64 = sr.IdString64
        if IdString64 and IdString64.from_hex then return IdString64.from_hex(hex) end
        return hex
    end

    local function by_resource(world, hex)
        local f = sr.World and sr.World.units_by_resource
        if type(f) ~= 'function' then return nil end
        local ok, list = pcall(f, world, idstring(hex))
        if ok and type(list) == 'table' then return list end
        return nil
    end

    local function alive(u)
        local Unit = sr.Unit
        if not Unit or type(Unit.alive) ~= 'function' then return true end
        local ok, v = pcall(Unit.alive, u)
        return ok and v == true
    end

    local function any_alive(list)
        if not list then return false end
        for _, u in pairs(list) do if alive(u) then return true end end
        return false
    end

    local function posture(u)
        local Unit = sr.Unit
        if type(Unit.has_animation_state_machine) ~= 'function' then return nil end
        local ok, has = pcall(Unit.has_animation_state_machine, u)
        if not ok or has ~= true then return nil end
        local r = pack(pcall(Unit.animation_get_state, u))
        if r[1] == true and r.n >= 15 then return r[15] end
        return nil
    end

    function self.read_elevator(u)
        local Unit, Vector3 = sr.Unit, sr.Vector3
        if type(Unit.num_scene_graph_items) ~= 'function' then return nil, nil end
        local ok, nodes = pcall(Unit.num_scene_graph_items, u)
        if not ok or type(nodes) ~= 'number' then return nil, nil end
        local z = {}
        for node = 0, math.min(nodes - 1, 63) do
            local ok2, pos = pcall(Unit.world_position, u, node)
            if ok2 and pos then z[node + 1] = Vector3.z(pos) end
        end
        local state
        local ok3, has = pcall(Unit.has_animation_state_machine, u)
        if ok3 and has == true then
            local ok4, s = pcall(Unit.animation_get_state, u)
            if ok4 then state = s end
        end
        return z, state
    end

    local function ensure(world)
        for _, e in ipairs(self.entries) do
            if e.w == world then return e end
        end
        if #self.entries >= MAX_WORLDS then
            table.remove(self.entries, 1)
        end
        local e = { w = world, index = self.next_index, count = -1, cannons = false,
                    launch = false, mapfloor = false, diver = false }
        self.next_index = self.next_index + 1
        self.entries[#self.entries + 1] = e
        return e
    end

    -- 小世界：单位数变了才重数 kind（原版 Impatient Diver 的做法）
    local function recount(e)
        local had = e.cannons
        e.cannons, e.launch, e.mapfloor, e.diver = false, false, false, false
        for _, hex in ipairs(CANNONS) do
            if any_alive(by_resource(e.w, hex)) then e.cannons = true; break end
        end
        e.launch = any_alive(by_resource(e.w, KIND.launch))
        e.mapfloor = any_alive(by_resource(e.w, KIND.mapfloor))
        e.diver = any_alive(by_resource(e.w, KIND.avatar))
        if e.cannons and not had then
            e.cannons_at = self.now()
            -- 这次外景冒出来时我们是不是站在船上：加入/离开队伍符合；
            -- 任务结束回来时我们还在任务或空场景里
            e.from_ship = (self.last_mode == 'ship')
            self.log.fmt('WORLD %d outside shot, %d units%s%s%s', e.index, e.count,
                e.launch and ', launch kind' or '', e.mapfloor and ', map floor' or '',
                e.from_ship and ', from ship' or '')
        end
    end

    local function main_census(world)
        local avatars = 0
        local list = by_resource(world, KIND.avatar)
        if list then for _, u in pairs(list) do if alive(u) then avatars = avatars + 1 end end end
        local markers = 0
        for _, hex in ipairs({ KIND.marker1, KIND.marker2, KIND.marker3 }) do
            local l = by_resource(world, hex)
            if l then for _, u in pairs(l) do if alive(u) then markers = markers + 1 end end end
        end
        snap.avatars, snap.markers = avatars, markers
        snap.normal, snap.boarding, snap.seated = 0, 0, 0
        snap.pod_loop, snap.pod_out, snap.pod_enter, snap.pod_in = 0, 0, 0, 0
        snap.ours_posture, snap.ours_gap = nil, nil

        -- 第三人称下我们的 Helldiver 就在相机附近几米：用它把「我」认出来，
        -- 免得队友去坐空降舱时把我这边也加速。
        local cam_pos = nil
        if self.cam_unit and alive(self.cam_unit) then
            local Unit, Camera, Vector3 = sr.Unit, sr.Camera, sr.Vector3
            local ok, c = pcall(Unit.camera, self.cam_unit, 1)
            if ok and c then
                local ok2, p = pcall(Camera.world_position, c)
                if ok2 and p then
                    local ok3, x, y, z = pcall(Vector3.to_elements, p)
                    if ok3 then cam_pos = { x, y, z } end
                end
            end
        end

        if list then
            local best_gap = nil
            for _, u in pairs(list) do
                if alive(u) then
                    local p = posture(u)
                    if cam_pos then
                        local okp, pos = pcall(sr.Unit.world_position, u, 1)
                        if okp and pos then
                            local okv, x, y, z = pcall(sr.Vector3.to_elements, pos)
                            if okv then
                                local dx, dy, dz = x - cam_pos[1], y - cam_pos[2], z - cam_pos[3]
                                local gap = math.sqrt(dx * dx + dy * dy + dz * dz)
                                if not best_gap or gap < best_gap then
                                    best_gap, snap.ours_posture, snap.ours_gap = gap, p, gap
                                end
                            end
                        end
                    end
                    if p == 36 then snap.normal = snap.normal + 1
                    elseif p == 89 then snap.boarding = snap.boarding + 1
                    elseif p == 90 then snap.seated = snap.seated + 1
                    elseif p == 0 then snap.pod_loop = snap.pod_loop + 1
                    elseif p == 6 then snap.pod_out = snap.pod_out + 1
                    elseif p == 15 then snap.pod_enter = snap.pod_enter + 1
                    elseif p == 17 then snap.pod_in = snap.pod_in + 1 end
                end
            end
        end
        -- 电梯可能有不止一个单位，挑节点最多的那个（31 节点的才是平台）
        local elev = by_resource(world, KIND.elevator)
        snap.elevator, snap.elevator_state = nil, nil
        if elev then
            local best_z, best_state, best_n = nil, nil, -1
            for _, u in pairs(elev) do
                if alive(u) then
                    local z, state = self.read_elevator(u)
                    local n = z and #z or 0
                    if n > best_n then best_z, best_state, best_n = z, state, n end
                end
            end
            snap.elevator, snap.elevator_state = best_z, best_state
        end
    end

    local function refresh_cam(world, t)
        local Unit = sr.Unit
        if not Unit or type(Unit.camera) ~= 'function' then return end
        if self.cam_unit and alive(self.cam_unit) then return end
        self.cam_unit = nil
        if t < self.next_cam then return end
        self.next_cam = t + CAM_RETRY
        local list = by_resource(world, KIND.camera)
        if not list then return end
        for _, u in pairs(list) do
            if alive(u) then self.cam_unit = u; return end
        end
    end

    function self.census()
        local t0 = self.now()
        local Application = sr.Application
        snap.now = t0
        local main = Application.main_world()
        snap.main = main

        local seen = {}
        for _, w in pairs(Application.worlds()) do
            local e = ensure(w)
            seen[e] = true
            local ok, n = pcall(sr.World.num_units, w)
            n = (ok and type(n) == 'number') and n or 0
            if n ~= e.count then
                if e.count >= 0 then
                    if n > SHIP and e.count <= SHIP then
                        e.loaded_at = t0
                        if self.ship_seen then e.reloaded_at = t0 end
                    elseif n <= SHIP and e.count > SHIP then
                        e.emptied_at = t0
                    end
                elseif n > SHIP then
                    e.loaded_at = t0       -- 第一次见到就已经是船
                end
                if e.count < 0 then
                    -- 世界出现时我们是否正站在船上：加入/离开队伍的外景符合；
                    -- 任务结束回来的外景出现时，我们还在任务或空场景里
                    e.born_from_ship = (self.last_mode == 'ship')
                    self.log.fmt('WORLD %d new, %d units%s', e.index, n,
                                 e.born_from_ship and ' (from ship)' or '')
                end
                e.count = n
                if n > (e.max_count or 0) then e.max_count = n end
                if n >= 300 then e.big_at = t0 end
                if n <= SMALL then recount(e) end
            end
            if n > SHIP then self.ship_seen = true end
        end
        for i = #self.entries, 1, -1 do
            if not seen[self.entries[i]] then table.remove(self.entries, i) end
        end

        snap.ship_seen = self.ship_seen
        snap.worlds = self.entries

        local main_e, destroyer, launcher = nil, nil, nil
        for _, e in ipairs(self.entries) do
            if e.w == main then main_e = e end
            if e.cannons and e.count <= SMALL and (not destroyer or e.count < destroyer.count) then
                destroyer = e
            end
            if e.launch and (not launcher or e.count < launcher.count) then launcher = e end
        end
        snap.destroyer = destroyer
        snap.launcher = launcher
        snap.main_index = main_e and main_e.index or 0

        if not main then
            snap.world_index, snap.mode = 0, 'none'
            snap.units, snap.avatars, snap.markers = 0, 0, 0
            snap.normal, snap.boarding, snap.seated = 0, 0, 0
            snap.elevator, snap.elevator_state = nil, nil
            snap.ship_at = self.ship_at
            snap.cam_fov = nil
            return
        end

        snap.world_index = main_e.index
        snap.units = main_e.count
        main_census(main)

        if snap.markers >= 2 then snap.mode = 'ship'
        elseif snap.markers == 0 and snap.avatars >= 1 and snap.units >= 256 then snap.mode = 'mission'
        else snap.mode = 'transition' end

        self.last_mode = snap.mode
        if snap.mode == 'mission' then
            self.last_mission_at = t0
            self.ship_at = nil
            self.extracted = false
            if (snap.seated or 0) > 0 then self.extracted = true end
        elseif snap.mode == 'ship' and self.last_mission_at and not self.ship_at
            and self.extracted and t0 - self.last_mission_at <= 60 then
            -- 只有真的上机撤离的回船才开电梯窗口；中途放弃任务没有这段动画
            self.ship_at = t0
        end
        snap.ship_at = self.ship_at
        snap.last_mission_at = self.last_mission_at
        snap.extracted = self.extracted

        refresh_cam(main, t0)

        local ms = (self.now() - t0) * 1000
        if ms > SLOW_MS then
            self.log.fmt('CENSUS %.1f ms (%d units, mode=%s)', ms, snap.units, snap.mode)
        end
        self.sig = tostring(main) .. ':' .. snap.units
    end

    function self.session()
        local Network, GameSession = sr.Network, sr.GameSession
        if not Network or not GameSession then return end
        local ok, s = pcall(Network.game_session)
        if not ok or not s then snap.players, snap.is_host = nil, nil; return end
        local ok2, peers = pcall(GameSession.peers, s)
        if ok2 and type(peers) == 'table' then snap.players = #peers end
        local ok3, host = pcall(GameSession.game_session_host, s)
        local ok4, me = pcall(Network.peer_id)
        if ok3 and ok4 and host ~= nil then snap.is_host = (host == me) end
    end

    -- 每帧：主相机 FOV（只有主世界第一个相机会动）
    function self.read_cam()
        local Unit, Camera = sr.Unit, sr.Camera
        snap.cam_fov = nil
        if not self.cam_unit or not alive(self.cam_unit) then return end
        if type(Unit.camera) ~= 'function' or type(Camera) ~= 'table' then return end
        local ok, c = pcall(Unit.camera, self.cam_unit, 1)
        if not ok or not c then return end
        local ok2, fov = pcall(Camera.vertical_fov, c)
        if ok2 and type(fov) == 'number' then snap.cam_fov = fov end
    end

    function self.update()
        local t = self.now()
        snap.now = t
        if t >= self.next_census then
            self.next_census = t + CENSUS_SECONDS
            self.census()
        end
        if t >= self.next_session then
            self.next_session = t + SESSION_SECONDS
            self.session()
        end
        self.read_cam()
        return snap
    end

    function self.force_census() return self.census() end

    return self
end

return M
