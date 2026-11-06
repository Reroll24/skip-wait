-- core/locales.lua · 界面文案的唯一来源（中文 / English）
-- 设置项只写 key，文案在这里查；settings.lua 用函数形式注册，MOM 重新解析时会按当前语言取。
local M = {}

-- 顺序 = 菜单里「语言」choice 的取值（1 起）
M.codes = { 'zh', 'en' }

local T = {
    zh = {
        ['mod.name'] = 'Skip Wait / 跳过人生',

        ['group.entry'] = 'Skip Wait / 跳过人生',
        ['group.debrief'] = '01 结算与电梯',
        ['group.cryo'] = '02 冷冻舱与登录',
        ['group.ftl'] = '03 FTL 与队伍外景',
        ['group.hellpod'] = '04 空降舱',
        ['group.pelican'] = '05 鹈鹕起飞',

        ['lang.zh'] = '中文',
        ['lang.en'] = 'English',

        ['opt.language.label'] = '语言',
        ['opt.language.desc'] = '界面语言（本 mod 的设置菜单），切换后立即生效。',

        ['opt.enabled.label'] = '总开关',
        ['opt.enabled.desc'] = '关闭后不做任何加速与跳过，并把时间步恢复 1x。',
        ['opt.verbose.label'] = '详细日志',
        ['opt.verbose.desc'] = '记录世界变动与电梯几何探针；反馈问题时请保持开启。',

        ['opt.debrief_multiplier.label'] = '结算 · 快放倍数',
        ['opt.debrief_multiplier.desc'] = '任务结算画面的快放倍数（1 = 关闭）。结算由主机同步，只快放、不跳过。',
        ['opt.debrief_cap.label'] = '结算 · 快放上限（秒）',
        ['opt.debrief_cap.desc'] = '单次结算最多快放的秒数，到点自动回 1x。',
        ['opt.elevator_multiplier.label'] = '回船电梯 · 快放倍数',
        ['opt.elevator_multiplier.desc'] = '舰内电梯上升的快放倍数（1 = 关闭）。',

        ['opt.cryo_multiplier.label'] = '冷冻舱 · 快放倍数',
        ['opt.cryo_multiplier.desc'] = '冷冻舱进出舱动画的快放倍数（1 = 关闭）。',
        ['opt.skip_cryo.label'] = '冷冻舱 · 跳过',
        ['opt.skip_cryo.desc'] = '直接跳过冷冻舱动画；跳跃额度用完后，剩下的仍按上面的倍数播。',
        ['opt.login_multiplier.label'] = '登录进船 · 快放倍数',
        ['opt.login_multiplier.desc'] = '登录后飞入飞船、走向舰桥的快放倍数（1 = 关闭）。',
        ['opt.skip_login.label'] = '登录进船 · 跳过',
        ['opt.skip_login.desc'] = '直接跳过登录的两段动画；额度用完后按倍数播剩下的。',

        ['opt.ftl_multiplier.label'] = 'FTL / 队伍外景 · 快放倍数',
        ['opt.ftl_multiplier.desc'] = '超光速跳跃、加入或离开队伍时的飞船外景快放倍数（1 = 关闭）。',
        ['opt.skip_ftl.label'] = 'FTL / 队伍外景 · 跳过',
        ['opt.skip_ftl.desc'] = '直接跳过这类外景；额度用完后按倍数播剩下的。',

        ['opt.hellpod_entry.label'] = '进空降舱 · 快放倍数',
        ['opt.hellpod_entry.desc'] = '转身走进空降舱、舱内等待；镜头拉到投放地图后自动停（1 = 关闭）。',
        ['opt.skip_hellpod.label'] = '进空降舱 · 跳过',
        ['opt.skip_hellpod.desc'] = '直接跳过走进舱与舱内等待；额度用完后按倍数播剩下的。',
        ['opt.hellpod_exit.label'] = '出空降舱 · 快放倍数',
        ['opt.hellpod_exit.desc'] = '进舱后到发射前按 ESC 取消空投、从舱里爬出来的那段（1 = 关闭）。真投放不碰。',
        ['opt.skip_hellpod_exit.label'] = '出空降舱 · 跳过',
        ['opt.skip_hellpod_exit.desc'] = '直接跳过出舱动画；额度用完后按倍数播剩下的。',
        ['opt.hellpod_drop.label'] = '空投发射 · 快放倍数',
        ['opt.hellpod_drop.desc'] = '只快放「点了确认到空降舱弹出」这段舰桥内推进镜头；船外发射与坠落不碰（1 = 关闭）。',
        ['opt.skip_hellpod_drop.label'] = '空投发射 · 跳过',
        ['opt.skip_hellpod_drop.desc'] = '直接跳过舰桥推进那段；船外发射与坠落不碰。',

        ['opt.pelican_solo.label'] = '鹈鹕起飞 · 快放倍数（单人）',
        ['opt.pelican_solo.desc'] = '任务结束上机到结算之间，仅单人时生效；这段由主机同步，多人不碰（1 = 关闭）。',
    },
    en = {
        ['mod.name'] = 'Skip Wait',

        ['group.entry'] = 'Skip Wait',
        ['group.debrief'] = '01 Debrief & Elevator',
        ['group.cryo'] = '02 Cryo & Login',
        ['group.ftl'] = '03 FTL & Squad Exterior',
        ['group.hellpod'] = '04 Hellpod',
        ['group.pelican'] = '05 Pelican Takeoff',

        ['lang.zh'] = '中文',
        ['lang.en'] = 'English',

        ['opt.language.label'] = 'Language',
        ['opt.language.desc'] = 'Language of this mod\'s settings menu. Applies immediately.',

        ['opt.enabled.label'] = 'Master switch',
        ['opt.enabled.desc'] = 'Off means no speed-up and no skip; the time step returns to 1x.',
        ['opt.verbose.label'] = 'Verbose log',
        ['opt.verbose.desc'] = 'Logs world changes and the elevator geometry probe. Keep it on when reporting a problem.',

        ['opt.debrief_multiplier.label'] = 'Debrief · speed',
        ['opt.debrief_multiplier.desc'] = 'Speed of the mission debrief screen (1 = off). The debrief is host-synced: speed only, never skipped.',
        ['opt.debrief_cap.label'] = 'Debrief · cap (seconds)',
        ['opt.debrief_cap.desc'] = 'Longest time one debrief may be sped up; it then returns to 1x.',
        ['opt.elevator_multiplier.label'] = 'Return elevator · speed',
        ['opt.elevator_multiplier.desc'] = 'Speed of the elevator ride back up the ship (1 = off).',

        ['opt.cryo_multiplier.label'] = 'Cryo · speed',
        ['opt.cryo_multiplier.desc'] = 'Speed of the cryo pod entry and exit animations (1 = off).',
        ['opt.skip_cryo.label'] = 'Cryo · skip',
        ['opt.skip_cryo.desc'] = 'Skip the cryo animation outright; whatever is left after the jump budget plays at the speed above.',
        ['opt.login_multiplier.label'] = 'Login · speed',
        ['opt.login_multiplier.desc'] = 'Speed of the flight in after login and the walk to the bridge (1 = off).',
        ['opt.skip_login.label'] = 'Login · skip',
        ['opt.skip_login.desc'] = 'Skip both login animations; whatever is left plays at the speed above.',

        ['opt.ftl_multiplier.label'] = 'FTL / squad exterior · speed',
        ['opt.ftl_multiplier.desc'] = 'Speed of the ship exterior during FTL jumps and when joining or leaving a squad (1 = off).',
        ['opt.skip_ftl.label'] = 'FTL / squad exterior · skip',
        ['opt.skip_ftl.desc'] = 'Skip these exterior shots; whatever is left plays at the speed above.',

        ['opt.hellpod_entry.label'] = 'Enter hellpod · speed',
        ['opt.hellpod_entry.desc'] = 'Speed of turning into the hellpod and the wait inside; stops once the camera reaches the drop map (1 = off).',
        ['opt.skip_hellpod.label'] = 'Enter hellpod · skip',
        ['opt.skip_hellpod.desc'] = 'Skip the walk in and the wait inside; whatever is left plays at the speed above.',
        ['opt.hellpod_exit.label'] = 'Leave hellpod · speed',
        ['opt.hellpod_exit.desc'] = 'Speed of the climb out after pressing ESC on the drop map, before launch (1 = off). A real drop is untouched.',
        ['opt.skip_hellpod_exit.label'] = 'Leave hellpod · skip',
        ['opt.skip_hellpod_exit.desc'] = 'Skip the climb-out animation; whatever is left plays at the speed above.',
        ['opt.hellpod_drop.label'] = 'Drop launch · speed',
        ['opt.hellpod_drop.desc'] = 'Speeds up only the bridge push-in from confirming to the pod launching; the exterior shot and the fall are untouched (1 = off).',
        ['opt.skip_hellpod_drop.label'] = 'Drop launch · skip',
        ['opt.skip_hellpod_drop.desc'] = 'Skip the bridge push-in itself; the exterior shot and the fall are untouched.',

        ['opt.pelican_solo.label'] = 'Pelican takeoff · speed (solo)',
        ['opt.pelican_solo.desc'] = 'Between boarding after a mission and the debrief, solo only; the host drives this segment, so multiplayer is untouched (1 = off).',
    },
}

-- 语言索引（MOM choice 的 1 起下标）→ 语言代码
function M.code(index)
    local code = M.codes[tonumber(index) or 1]
    return code or 'zh'
end

-- 取当前语言的文案；缺 key 时退回中文，再退回 key 本身
function M.text(index_or_code, key)
    local code = T[index_or_code] and index_or_code or M.code(index_or_code)
    local set = T[code] or T.zh
    local text = set[key]
    if text == nil then text = T.zh[key] end
    return text or key
end

-- 供测试与调试：某种语言下的全部文案
function M.all(code)
    return T[code] or T.zh
end

return M
