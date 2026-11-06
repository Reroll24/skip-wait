-- tests/fake.lua · 假引擎，只实现 snapshot 真正会碰的那一小撮函数
local M = {}

local KINDS = {
    avatar   = '4d1c334d294dfa97',
    marker1  = '9dfd0e3b5172e41c',
    marker2  = 'f74fde620b7c9e60',
    marker3  = 'b91cc2ab0cfb2540',
    elevator = '02016f98826cc83c',
    camera   = '465f4895f3dc98d1',
    launch   = 'e93e9835bce95d4a',
    mapfloor = '96af7d6acb949f34',
    cannon   = '03544419135a9935',
    filler   = 'ffffffffffffffff',
}
M.KINDS = KINDS

local function pack_state(state, layer0)
    local t = {}
    for i = 1, 18 do t[i] = 0 end
    t[1] = layer0 or 0
    t[14] = state or 0
    return unpack(t, 1, 18)
end

function M.new()
    local g = { calls = {}, rate = 1, jumps = 0, time = 0, fov = 1.134 }
    g.world = { units = {} }
    g.worlds = { g.world }

    local sr = {}

    sr.Application = {
        main_world = function() return g.world end,
        worlds = function() return g.worlds end,
        set_time_step_policy = function(kind, value)
            g.calls[#g.calls + 1] = { kind = kind, value = value, t = g.time }
            if kind == 'external_multiplier' then g.rate = value
            elseif kind == 'jump' then g.jumps = g.jumps + 1 end
        end,
    }

    sr.IdString64 = { from_hex = function(hex) return { hex = hex } end }

    sr.World = {
        num_units = function(w) return #w.units end,
        units = function(w)
            local out = {}
            for i = 1, #w.units do out[i] = w.units[i] end
            return out
        end,
        units_by_resource = function(w, id)
            local hex = type(id) == 'table' and id.hex or id
            local out = {}
            for i = 1, #w.units do
                if w.units[i].kind == hex then out[#out + 1] = w.units[i] end
            end
            return out
        end,
    }

    sr.Unit = {
        alive = function(u) return u.alive ~= false end,
        has_animation_state_machine = function(u)
            return u.kind == KINDS.avatar or u.kind == KINDS.elevator
        end,
        animation_get_state = function(u) return pack_state(u.state, u.layer0) end,
        num_scene_graph_items = function(u) return u.nodes and #u.nodes or 0 end,
        world_position = function(u, node)
            if u.pos then return u.pos end
            return { z = (u.nodes[node + 1]) or 0 }
        end,
        camera = function(u) return { unit = u } end,
    }

    sr.Vector3 = {
        z = function(v) return v.z end,
        to_elements = function(v) return v[1], v[2], v[3] end,
    }
    sr.Camera = {
        vertical_fov = function() return g.fov end,
        world_position = function(c) return c.unit.pos or { 0, 0, 0 } end,
    }
    sr.Network = { game_session = function() return g.session end, peer_id = function() return 'me' end }
    sr.GameSession = {
        peers = function(s) return s.peers end,
        game_session_host = function(s) return s.host end,
    }

    -- players = 玩家总数（含自己）；1 或不设 = 单人
    function g.set_players(n)
        if not n or n <= 1 then g.session = nil; return end
        local peers = {}
        for i = 1, n do peers[i] = 'p' .. i end
        g.session = { peers = peers, host = 'me' }
    end

    g.sr = sr

    function g.new_world()
        g.world = { units = {} }
        g.worlds = { g.world }
        return g.world
    end

    -- 给任意世界填单位；total 只是补齐的填充单位
    local function fill(w, opt)
        opt = opt or {}
        local units = {}
        for i = 1, (opt.avatars or 0) do
            units[#units + 1] = { kind = KINDS.avatar, state = opt.state or 36, alive = true,
                                  pos = { i * 10, 0, 0 } }
        end
        for _ = 1, (opt.markers or 0) do
            units[#units + 1] = { kind = KINDS.marker1, alive = true }
        end
        if opt.elevator then
            local nodes = {}
            for i = 1, 31 do nodes[i] = 0 end
            local floor = opt.floor or 5.0
            nodes[2], nodes[27] = floor, floor
            for i = 22, 26 do nodes[i] = floor - 1.0 + (opt.rise or 0) end
            units[#units + 1] = { kind = KINDS.elevator, layer0 = 1, nodes = nodes, alive = true }
        end
        if opt.camera then units[#units + 1] = { kind = KINDS.camera, alive = true, pos = { 0, 0, 0 } } end
        if opt.cannon then units[#units + 1] = { kind = KINDS.cannon, alive = true } end
        if opt.launch then units[#units + 1] = { kind = KINDS.launch, alive = true } end
        if opt.mapfloor then units[#units + 1] = { kind = KINDS.mapfloor, alive = true } end
        local total = opt.total or #units
        while #units < total do units[#units + 1] = { kind = KINDS.filler, alive = true } end
        w.units = units
    end

    function g.set_units(opt) fill(g.world, opt) end

    function g.add_world(opt)
        local w = { units = {} }
        fill(w, opt)
        g.worlds[#g.worlds + 1] = w
        return w
    end

    function g.drop_world(w)
        for i = #g.worlds, 1, -1 do
            if g.worlds[i] == w then table.remove(g.worlds, i) end
        end
    end

    return g
end

return M
