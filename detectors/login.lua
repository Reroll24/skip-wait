-- detectors/login.lua · 登录后飞入飞船 + 走向舰桥
-- 判据来自 Impatient Diver（MIT）：
--   第一段：主世界就是那个带炮的小世界，而且还没见过船（登录外景，54~63 单位）；
--   第二段：船加载后主相机视角先收窄、再变宽，就是走完了舰桥。
--
-- 2026-11-06 修：原来的「宽」是绝对值（fov > 1.0），玩家把游戏 FOV 调小之后，
-- 正常视角本身就可能低于 1.0，于是永远等不到收工，只能靠 45 秒（真实时间）兜底，
-- 玩家恢复操作后还带着 x8。现在改成：
--   * 视角阈值按本场过场里见过的最宽视角取比例，跟玩家 FOV 设置无关；
--   * 上限按「游戏秒」记账（每帧 dt * 倍率），走桥段最多 4 游戏秒、整段 12 游戏秒；
--   * 另外接受「姿态回到 36（normal）+ 镜头已经很宽」作为恢复操作的信号。
local M = {}

local WIDE_RATIO = 0.85     -- 相对本场最宽视角，超过就算「已经变宽」
local NARROW_RATIO = 0.55   -- 低于这个比例算「镜头收窄」
local WALK_GRACE = 0.6      -- 进入走桥段后至少观察这么久才认「变宽」（游戏秒）
local WALK_CAP = 4          -- 走桥段最多加速的游戏秒数（原版这段 3~5 秒）
local GAME_CAP = 12         -- 整段（外景 + 走桥）最多加速的游戏秒数

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
                self.scene = { start = now, last = now, game = 0, walk_at = nil, walk_game = nil,
                               fov_max = snap.cam_fov or 0, narrowed = false, normals = 0, walk_frames = 0 }
                self.log.fmt('LOGIN outside (world %d, %d units)', d.index, d.count)
            end
            return nil
        end

        local sc = self.scene

        -- 游戏秒记账：真实 dt * 当前倍率。所有上限都按它算，跟帧率、倍率无关。
        local dt = now - sc.last
        if dt < 0 then dt = 0 end
        sc.last = now
        -- 瞬时跳过时实际倍率是 1（靠 jump 推），别按 rate 记账
        sc.game = sc.game + dt * (instant and 1 or rate)


        local fov = snap.cam_fov
        if fov and fov > sc.fov_max then sc.fov_max = fov end
        if fov and sc.fov_max > 0 and fov < sc.fov_max * NARROW_RATIO then sc.narrowed = true end

        if not instant and sc.game > GAME_CAP then
            self.log.fmt('LOGIN stop (cap %ds game time)', GAME_CAP)
            self.reset(); return nil
        end

        -- 第一段：外面还没船
        if not sc.walk_at then
            if snap.units > 1000 then
                sc.walk_at = now
                sc.walk_game = sc.game
                self.log.fmt('LOGIN walk to the bridge (ship up, %.1f s game time, fov %.3f of %.3f)',
                             sc.walk_game, fov or 0, sc.fov_max)
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

        -- 第二段：走舰桥。收工的判据按「先便宜、后兜底」排。
        local since_walk = sc.game - sc.walk_game
        if instant then
            -- jump 模式的兜底：走桥段最多再跳这么多帧，额度用完后别继续按 8x 播
            sc.walk_frames = sc.walk_frames + 1
            if sc.walk_frames > 40 then
                self.log.fmt('LOGIN stop (instant walk %d frames)', sc.walk_frames)
                self.reset(); return nil
            end
        end
        -- 「变宽」必须真的先见过收窄，否则 fov 一路不动也会被当成变宽
        local wide = sc.narrowed and fov and sc.fov_max > 0 and fov > sc.fov_max * WIDE_RATIO

        if since_walk >= WALK_GRACE then
            -- 1. 镜头回到宽角（比例判据；不要求之前一定见过 narrow）
            if wide then
                self.log.fmt('LOGIN stop (camera wide again, fov %.3f of %.3f)', fov, sc.fov_max)
                self.reset(); return nil
            end
            -- 2. 姿态回到 36（normal）且镜头已经很宽：玩家已经能操作了
            if snap.normal > 0 then
                sc.normals = sc.normals + dt
                if sc.normals >= 0.3 then
                    self.log.write('LOGIN stop (normal control back)')
                    self.reset(); return nil
                end
            else
                sc.normals = math.max(0, sc.normals - dt * 2)
            end
        end

        -- 3. 走桥段自己的游戏秒上限（兜底，比原来的 45 真实秒短一个数量级）
        if not instant and since_walk > WALK_CAP then
            self.log.fmt('LOGIN stop (walk cap %ds game time)', WALK_CAP)
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
