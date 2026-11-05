-- detectors/login.lua · 登录后飞入飞船 + 走向舰桥
-- 判据来自 Impatient Diver（MIT）：
--   第一段：主世界就是那个带炮的小世界，而且还没见过船（登录外景，54~63 单位）；
--   第二段：船加载完成后主相机 FOV 收窄（0.262）再放开（> 1.0）就是走完舰桥。
local M = {}

local WIDE_FOV = 1.0
local WALK_WAIT = 3        -- 船加载后等相机收窄的上限（游戏秒）
local CAP = 45             -- 整段最多加速

function M.new(settings, log)
    local self = { id = 'login', priority = 80, scene = nil, settings = settings, log = log }

    function self.reset() self.scene = nil end

    function self.poll(snap)
        if not self.settings.get('enabled') then self.reset(); return nil end
        local rate = self.settings.get('login_multiplier') or 1
        if rate <= 1 then self.reset(); return nil end
        local instant = self.settings.get('skip_login') == true
        local now = snap.now
        local d = snap.destroyer

        if not self.scene then
            if d and d.index == snap.main_index and not snap.ship_seen then
                self.scene = { start = now, walk_at = nil, narrowed = false }
                self.log.fmt('LOGIN outside (world %d, %d units)', d.index, d.count)
            end
            return nil
        end

        local sc = self.scene
        if now - sc.start > CAP then
            self.log.fmt('LOGIN stop (cap %ds)', CAP)
            self.reset(); return nil
        end

        -- 第一段：外面还没船
        if not sc.walk_at then
            if snap.units > 1000 then
                sc.walk_at = now
                self.log.fmt('LOGIN walk to the bridge (ship up, %.1f s in)', now - sc.start)
            elseif not d or d.index ~= snap.main_index then
                self.log.write('LOGIN stop (outside shot gone)')
                self.reset(); return nil
            end
            if not sc.walk_at then
                if instant then
                    return { mode = 'instant', jump = 1, budget = 22, key = sc.start, reason = 'login-outside' }
                end
                return { mode = 'fast', speed = rate, reason = 'login-outside' }
            end
        end

        -- 第二段：走舰桥，相机先窄后宽
        local fov = snap.cam_fov
        if fov and fov <= WIDE_FOV then sc.narrowed = true end
        if sc.narrowed and fov and fov > WIDE_FOV then
            self.log.write('LOGIN stop (camera wide again)')
            self.reset(); return nil
        end
        if not sc.narrowed and (now - sc.walk_at) > WALK_WAIT then
            self.log.write('LOGIN stop (no walk to the bridge)')
            self.reset(); return nil
        end
        if instant then
            return { mode = 'instant', jump = 1, budget = 22, key = sc.start, reason = 'login-walk' }
        end
        return { mode = 'fast', speed = rate, reason = 'login-walk' }
    end

    return self
end

return M
