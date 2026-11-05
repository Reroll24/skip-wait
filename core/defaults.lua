-- core/defaults.lua · 设置项的唯一定义处（mod.lua 与测试共用）
-- 顺序 = 菜单里的顺序；group = 分节标题，mod_id = 分节的稳定标识。
-- MDL3 的 ModOptionsMenu 每个 (mod, mod_id) 是一节；同一个 mod 的脚本路径相同才会归到一处
-- （mod.lua 把 chunk 名写成 mods/Reroll24/skip_wait/<文件>，让 MDL3 认成一个 mod 的多个分节）。
-- 倍速滑块 1 = 关闭；跳过开关与倍速是叠加关系：先跳，额度用完再按倍数播剩下的。
return {
    -- 入口名（MDL3 用第一节的标题当 mod 名）+ 总开关与诊断
    { key = 'enabled', type = 'toggle', default = true,
      group = 'Skip Wait / 跳过人生', mod_id = 'skipwait.settings',
      label = '总开关', description = '关闭后不做任何加速与跳过，并把时间步恢复 1x。' },
    { key = 'verbose', type = 'toggle', default = true,
      group = 'Skip Wait / 跳过人生', mod_id = 'skipwait.settings',
      label = '详细日志', description = '记录世界变动与电梯几何探针；反馈问题时请保持开启。' },

    -- 01 结算与电梯
    { key = 'debrief_multiplier', type = 'slider', default = 4, min = 1, max = 4, step = 1,
      group = '01 结算与电梯', mod_id = 'skipwait.debrief', gap = true,
      label = '结算 · 快放倍数', description = '任务结算画面的快放倍数（1 = 关闭）。结算由主机同步，只快放、不跳过。' },
    { key = 'debrief_cap', type = 'slider', default = 20, min = 5, max = 60, step = 5,
      group = '01 结算与电梯', mod_id = 'skipwait.debrief',
      label = '结算 · 快放上限（秒）', description = '单次结算最多快放的秒数，到点自动回 1x。' },
    { key = 'elevator_multiplier', type = 'slider', default = 2, min = 1, max = 4, step = 1,
      group = '01 结算与电梯', mod_id = 'skipwait.debrief',
      label = '回船电梯 · 快放倍数', description = '舰内电梯上升的快放倍数（1 = 关闭）。' },

    -- 02 冷冻舱与登录
    { key = 'cryo_multiplier', type = 'slider', default = 8, min = 1, max = 8, step = 1,
      group = '02 冷冻舱与登录', mod_id = 'skipwait.cryo', gap = true,
      label = '冷冻舱 · 快放倍数', description = '冷冻舱进出舱动画的快放倍数（1 = 关闭）。' },
    { key = 'skip_cryo', type = 'toggle', default = false,
      group = '02 冷冻舱与登录', mod_id = 'skipwait.cryo',
      label = '冷冻舱 · 跳过', description = '直接跳过冷冻舱动画；跳跃额度用完后，剩下的仍按上面的倍数播。' },
    { key = 'login_multiplier', type = 'slider', default = 8, min = 1, max = 8, step = 1,
      group = '02 冷冻舱与登录', mod_id = 'skipwait.cryo',
      label = '登录进船 · 快放倍数', description = '登录后飞入飞船、走向舰桥的快放倍数（1 = 关闭）。' },
    { key = 'skip_login', type = 'toggle', default = false,
      group = '02 冷冻舱与登录', mod_id = 'skipwait.cryo',
      label = '登录进船 · 跳过', description = '直接跳过登录的两段动画；额度用完后按倍数播剩下的。' },

    -- 03 FTL 与队伍外景
    { key = 'ftl_multiplier', type = 'slider', default = 8, min = 1, max = 8, step = 1,
      group = '03 FTL 与队伍外景', mod_id = 'skipwait.ftl', gap = true,
      label = 'FTL / 队伍外景 · 快放倍数', description = '超光速跳跃、加入或离开队伍时的飞船外景快放倍数（1 = 关闭）。' },
    { key = 'skip_ftl', type = 'toggle', default = false,
      group = '03 FTL 与队伍外景', mod_id = 'skipwait.ftl',
      label = 'FTL / 队伍外景 · 跳过', description = '直接跳过这类外景；额度用完后按倍数播剩下的。' },

    -- 04 空降舱
    { key = 'hellpod_entry', type = 'slider', default = 8, min = 1, max = 8, step = 1,
      group = '04 空降舱', mod_id = 'skipwait.hellpod', gap = true,
      label = '进空降舱 · 快放倍数', description = '转身走进空降舱、舱内等待；镜头拉到投放地图后自动停（1 = 关闭）。' },
    { key = 'skip_hellpod', type = 'toggle', default = false,
      group = '04 空降舱', mod_id = 'skipwait.hellpod',
      label = '进空降舱 · 跳过', description = '直接跳过走进舱与舱内等待；额度用完后按倍数播剩下的。' },
    { key = 'hellpod_exit', type = 'slider', default = 8, min = 1, max = 8, step = 1,
      group = '04 空降舱', mod_id = 'skipwait.hellpod',
      label = '出空降舱 · 快放倍数', description = '进舱后到发射前按 ESC 取消空投、从舱里爬出来的那段（1 = 关闭）。真投放不碰。' },
    { key = 'skip_hellpod_exit', type = 'toggle', default = false,
      group = '04 空降舱', mod_id = 'skipwait.hellpod',
      label = '出空降舱 · 跳过', description = '直接跳过出舱动画；额度用完后按倍数播剩下的。' },
    { key = 'hellpod_drop', type = 'slider', default = 1, min = 1, max = 8, step = 1,
      group = '04 空降舱', mod_id = 'skipwait.hellpod',
      label = '空投发射 · 快放倍数', description = '只快放「点了确认到空降舱弹出」这段舰桥内推进镜头；船外发射与坠落不碰（1 = 关闭）。' },
    { key = 'skip_hellpod_drop', type = 'toggle', default = false,
      group = '04 空降舱', mod_id = 'skipwait.hellpod',
      label = '空投发射 · 跳过', description = '直接跳过舰桥推进那段；船外发射与坠落不碰。' },

    -- 05 鹈鹕起飞
    { key = 'pelican_solo', type = 'slider', default = 1, min = 1, max = 8, step = 1,
      group = '05 鹈鹕起飞', mod_id = 'skipwait.pelican', gap = true,
      label = '鹈鹕起飞 · 快放倍数（单人）', description = '任务结束上机到结算之间，仅单人时生效；这段由主机同步，多人不碰（1 = 关闭）。' },
}
