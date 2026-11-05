# Skip Wait / 跳过人生

适配 **MDL3** 的《绝地潜兵 2》过场动画跳过脚本（Lua），为每一段过场提供独立的倍速与「跳过」开关。
An MDL3-compatible Lua mod for *Helldivers 2* that speeds up or skips cutscenes, with a separate speed and skip toggle for each segment.

> **状态 / Status: 测试版 beta `0.12.0-beta.1`**（构建于 2026-11-06）
> ⚠️ **早期预览版 / early preview**：各方面仍在优化，可能有 bug，有问题请[反馈](#反馈与日志--reporting)。
> 英文内容为翻译，可能有不准确之处。 / The English text is a translation and may be imprecise.

## 简介 / About

目前支持如下场景的倍速或跳过：游戏启动后进入舰桥、FTL 跃迁、冷冻仓解冻、空降仓进出、空降仓发射、任务结算动画、单人模式的鹈鹕起飞动画。目前处于早期测试阶段，可能会有 bug，请积极反馈。

Currently supports speed-up or skip for: entering the ship after the game starts, FTL jumps, cryo thaw, entering and leaving the hellpod, the hellpod drop launch, the mission debrief, and the Pelican takeoff in solo play. This is an early beta and may contain bugs — please report anything you run into.

## 功能 / Features

| 场景 | 默认 | 跳过开关 |
|---|---|---|
| 任务结算 | 4x（上限 20 真实秒） | — （由主机同步，只快放） |
| 回船电梯 | 2x | — （太短） |
| 登录进船 | 8x | ✅ |
| FTL / 加入·离开队伍外景 | 8x | ✅ |
| 冷冻舱（解冻/进出舱） | 8x | ✅ |
| 进空降舱（走进舱 + 等投放地图） | 8x | ✅ |
| 出空降舱（投放地图上按 ESC 取消） | 8x | ✅ |
| 空投发射（只快放舰桥内推进段；船外发射与坠落不碰） | 关 | ✅ |
| 鹈鹕起飞（仅单人） | 关 | — （由主机同步） |

| Scene | Default | Skip toggle |
|---|---|---|
| Mission debrief | 4x (capped at 20 real seconds) | — (host-synced, speed only) |
| Return elevator | 2x | — (too short) |
| Login / boarding | 8x | ✅ |
| FTL / join & leave squad exterior | 8x | ✅ |
| Cryo (thaw / in and out) | 8x | ✅ |
| Entering the hellpod (walk in + drop map) | 8x | ✅ |
| Leaving the hellpod (ESC on the drop map) | 8x | ✅ |
| Drop launch (bridge push-in only; exterior launch and the fall are untouched) | off | ✅ |
| Pelican takeoff (solo only) | off | — (host-synced) |

## 说明 / Notes

- 倍速滑块 1 = 关闭；跳过功能和倍速功能叠加。
- 目前对触发跳过动画的检测机制为寻找离主相机最近的玩家单位。
- 所有加速都经同一个时间步出口写入，不会和别的 mod 抢同一个开关。

- A speed slider of 1 means off. Skip and speed stack.
- Skip triggers are detected by picking the player unit closest to the main camera.
- Everything goes through one time-step exit, so it won't fight another mod over the same setting.

## 安装 / Installation

两种装法，**二选一，不要同时装**（会重复加速）。
Two install routes — **pick one, never both**; installing both double-accelerates.

### A. 管理器导入（addon 包）/ Manager import (addon package)

1. 导入 `skip_wait-addon-<version>.zip`（Arsenal / HD2MM），启用并 Deploy。
2. 设置：ESC → MOD 设置 → **Skip Wait / 跳过人生**（6 节、18 项）。
3. 日志：`%LOCALAPPDATA%\MDL\Helldivers2\Logs\SkipWait.log`（控制台也会打）。

1. Import `skip_wait-addon-<version>.zip` in Arsenal / HD2MM, enable it and Deploy.
2. Settings: ESC → Mod Options → **Skip Wait / 跳过人生** (6 sections, 18 options).
3. Log: `%LOCALAPPDATA%\MDL\Helldivers2\Logs\SkipWait.log` (also printed to the console).

### B. 本地 mod（复制文件夹）/ Local mod (copy the folder)

1. 把 `skip_wait` 文件夹放进 `%LOCALAPPDATA%\MDL\Helldivers2\Mods\`。
2. 在 MDL 里启用并重启游戏；设置同上。
3. 日志：`%LOCALAPPDATA%\MDL\Helldivers2\Logs\MDL.log`，搜 `[skipwait]`。

1. Drop the `skip_wait` folder into `%LOCALAPPDATA%\MDL\Helldivers2\Mods\`.
2. Enable it in MDL and restart the game. Settings are the same as above.
3. Log: `%LOCALAPPDATA%\MDL\Helldivers2\Logs\MDL.log`, search for `[skipwait]`.

## 构建 / Building

需要 Python 3。仓库根目录执行：
Requires Python 3; run from the repository root:

| 命令 | 产物 |
|---|---|
| `python tools/pack_addon.py` | `dist/skip_wait-addon-<version>.zip`（管理器导入 / manager import） |
| `python tools/pack_local.py` | `dist/skip_wait-<version>.zip`（本地 mod / local mod） |
| `python tools/run_lua51.py` | 跑 `tests/run.lua` 的 87 条断言（需 lupa 的 Lua 5.1） |

| Command | Output |
|---|---|
| `python tools/pack_addon.py` | `dist/skip_wait-addon-<version>.zip` (manager import) |
| `python tools/pack_local.py` | `dist/skip_wait-<version>.zip` (local mod) |
| `python tools/run_lua51.py` | Runs the 87 assertions in `tests/run.lua` (needs lupa's Lua 5.1) |

离线测试需要 `lupa`：把解包好的 `lupa` 放进 `tools/pyenv/`（已 gitignore），或自行设置 `PYTHONPATH`。
The offline tests need `lupa`: drop an unpacked `lupa` into `tools/pyenv/` (gitignored) or set `PYTHONPATH` yourself.

## 运行环境 / Requirements

| 项 | 值 |
|---|---|
| 游戏 | 《绝地潜兵 2》 |
| 加载器 | **MDL3 3.0.0-dev.33**（addon 包与本地 mod 都跑在 MDL3 上） |
| 脚本 VM | Lua 5.1（游戏内置） |
| 设置界面 | Mod Options Menu API（MDL3 内置） |

| Item | Value |
|---|---|
| Game | *Helldivers 2* |
| Loader | **MDL3 3.0.0-dev.33** (both the addon package and the local mod run on MDL3) |
| Script VM | Lua 5.1 (built into the game) |
| Settings UI | Mod Options Menu API (bundled with MDL3) |

> Bingus Shared Loader 自 2026-10-20 游戏更新后已失效，本项目不再以它为运行环境；`-- HD2-Addon` 只是沿用下来的资源写法规范。
> Bingus Shared Loader stopped working after the 2026-10-20 game update, so it is no longer a supported runtime; `-- HD2-Addon` remains only as the resource-writing convention.

## 致谢 / Credits

| 原型 / Prototype | 作者 / Author | 地址 / Link | 本项目用到什么 / Used here |
|---|---|---|---|
| Impatient Diver（MIT，已获作者授权 / MIT, permission granted） | Alomare | [GitHub](https://github.com/Alomare/ImpatientDiver) · [Nexus](https://www.nexusmods.com/helldivers2/mods/16624) | 世界识别、分阶段跳跃额度，以及空降舱 / 登录 / 冷冻舱判据的研究笔记（未使用其代码/资产）<br>World identification, per-stage jump budgets, and the hellpod / login / cryo criteria (no code or assets used) |
| QuickDebrief 0.4.3 host beta（已获原作者授权 / authorised by the author） | **w741**（Nexus）<br>**蒼耳_PaddyNeko**（Bilibili） | [Nexus](https://www.nexusmods.com/helldivers2/mods/17764)<br>[Bilibili](https://space.bilibili.com/36037388) | 任务结算状态机与回船电梯几何的判据<br>Debrief state machine and return-elevator geometry criteria |

| 项目 / Project | 作者 / Author | 地址 / Link | 用途 / Used for |
|---|---|---|---|
| Mod Options Menu（0BSD） | CowboyBingus | [GitHub](https://github.com/CowboyBingus/ModOptionsMenu) | 设置菜单的 API 参考<br>Settings menu API reference |
| MDL3 | **M!ni$try0fSc!eиce** | [发布页 / release page](https://ayakamods.com/mods/mdl3-preview-%E9%BA%A6%E5%BD%93%E5%8A%B33-%E9%A2%84%E8%A7%88%E7%89%88%EF%BC%81.5710/) | 运行平台 / runtime |

第三方许可全文见 [NOTICE](NOTICE)。 / Full third-party license texts: [NOTICE](NOTICE).

## 许可 / License

本项目代码以 **MIT** 许可发布，见 [LICENSE](LICENSE)。
Released under the **MIT** license — see [LICENSE](LICENSE).

## 反馈与日志 / Reporting

当前仍是早期预览版本，各方面都有优化空间；遇到问题请带日志反馈，并说明用的是哪种装法（A 管理器 / B 本地 mod）。

1. 设置里的「详细日志」默认已开启，请保持开启后再复现一次。
2. 取日志：A 路线看 `%LOCALAPPDATA%\MDL\Helldivers2\Logs\SkipWait.log`；B 路线看 `%LOCALAPPDATA%\MDL\Helldivers2\Logs\MDL.log`，搜以 `[skipwait]` 开头的行。
3. 把 `[skipwait]` 段落连同复现步骤发到 [GitHub Issues](https://github.com/Reroll24/skip-wait/issues)；不方便用 GitHub 的话，Nexus 页留言也可以。

This is still an early preview and everything can be improved. When reporting a problem, please include a log and say which install route you used (A manager / B local mod).

1. Keep the "verbose log" option on — it is enabled by default — then reproduce the issue once.
2. Grab the log: route A reads `%LOCALAPPDATA%\MDL\Helldivers2\Logs\SkipWait.log`; route B reads `%LOCALAPPDATA%\MDL\Helldivers2\Logs\MDL.log`, searching for lines starting with `[skipwait]`.
3. Post the `[skipwait]` block with the steps to reproduce in [GitHub Issues](https://github.com/Reroll24/skip-wait/issues); the Nexus comments section works too.

## 已知限制 / Known limitations

- 多人情况下，检测机制目前可能不完善，有更好的写法请反馈联系。
- 跳过功能目前还在测试阶段，出问题请带 `MDL.log` 的 `[skipwait]` 段落反馈。

- In multiplayer the detection may still be imperfect; if you know a better approach, please get in touch.
- Skip is still in testing; when reporting, attach the `[skipwait]` block from `MDL.log`.

## 免责声明 / Disclaimer

非 Arrowhead Game Studios 官方作品，与 Arrowhead、Sony 无关联。联机使用风险自负；出问题先关掉本 mod 复现。
Not affiliated with Arrowhead Game Studios or Sony. Use online at your own risk; if something misbehaves, disable the mod and try to reproduce.
