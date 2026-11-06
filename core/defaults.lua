-- core/defaults.lua · 设置项的唯一定义处（mod.lua 与测试共用）
-- 顺序 = 菜单里的顺序；group = 分节文案的 key（见 core/locales.lua），mod_id = 分节的稳定标识。
-- MDL3 的 ModOptionsMenu 每个 (mod, mod_id) 是一节；同一个 mod 的脚本路径相同才会归到一处
-- （mod.lua 把 chunk 名写成 mods/Reroll24/skip_wait/<文件>，让 MDL3 认成一个 mod 的多个分节）。
-- 倍速滑块 1 = 关闭；跳过开关与倍速是叠加关系：先跳，额度用完再按倍数播剩下的。
-- 选项文案同样只写 key：opt.<key>.label / opt.<key>.desc。
return {
    -- 入口名（MDL3 用第一节的标题当 mod 名）+ 语言 / 总开关与诊断
    -- 语言放第一项：MOM 会在注册后面的项时调用文案函数，先读到它的值。
    { key = 'language', type = 'choice', default = 1, choices = { 'zh', 'en' },
      group = 'group.entry', mod_id = 'skipwait.settings' },
    { key = 'enabled', type = 'toggle', default = true,
      group = 'group.entry', mod_id = 'skipwait.settings' },
    { key = 'verbose', type = 'toggle', default = true,
      group = 'group.entry', mod_id = 'skipwait.settings' },

    -- 01 结算与电梯
    { key = 'debrief_multiplier', type = 'slider', default = 4, min = 1, max = 4, step = 1,
      group = 'group.debrief', mod_id = 'skipwait.debrief', gap = true },
    { key = 'debrief_cap', type = 'slider', default = 20, min = 5, max = 60, step = 5,
      group = 'group.debrief', mod_id = 'skipwait.debrief' },
    { key = 'elevator_multiplier', type = 'slider', default = 2, min = 1, max = 4, step = 1,
      group = 'group.debrief', mod_id = 'skipwait.debrief' },

    -- 02 冷冻舱与登录
    { key = 'cryo_multiplier', type = 'slider', default = 8, min = 1, max = 8, step = 1,
      group = 'group.cryo', mod_id = 'skipwait.cryo', gap = true },
    { key = 'skip_cryo', type = 'toggle', default = false,
      group = 'group.cryo', mod_id = 'skipwait.cryo' },
    { key = 'login_multiplier', type = 'slider', default = 8, min = 1, max = 8, step = 1,
      group = 'group.cryo', mod_id = 'skipwait.cryo' },
    { key = 'skip_login', type = 'toggle', default = false,
      group = 'group.cryo', mod_id = 'skipwait.cryo' },

    -- 03 FTL 与队伍外景
    { key = 'ftl_multiplier', type = 'slider', default = 8, min = 1, max = 8, step = 1,
      group = 'group.ftl', mod_id = 'skipwait.ftl', gap = true },
    { key = 'skip_ftl', type = 'toggle', default = false,
      group = 'group.ftl', mod_id = 'skipwait.ftl' },

    -- 04 空降舱
    { key = 'hellpod_entry', type = 'slider', default = 8, min = 1, max = 8, step = 1,
      group = 'group.hellpod', mod_id = 'skipwait.hellpod', gap = true },
    { key = 'skip_hellpod', type = 'toggle', default = false,
      group = 'group.hellpod', mod_id = 'skipwait.hellpod' },
    { key = 'hellpod_exit', type = 'slider', default = 8, min = 1, max = 8, step = 1,
      group = 'group.hellpod', mod_id = 'skipwait.hellpod' },
    { key = 'skip_hellpod_exit', type = 'toggle', default = false,
      group = 'group.hellpod', mod_id = 'skipwait.hellpod' },
    { key = 'hellpod_drop', type = 'slider', default = 1, min = 1, max = 8, step = 1,
      group = 'group.hellpod', mod_id = 'skipwait.hellpod' },
    { key = 'skip_hellpod_drop', type = 'toggle', default = false,
      group = 'group.hellpod', mod_id = 'skipwait.hellpod' },

    -- 05 鹈鹕起飞
    { key = 'pelican_solo', type = 'slider', default = 1, min = 1, max = 8, step = 1,
      group = 'group.pelican', mod_id = 'skipwait.pelican', gap = true },
}
