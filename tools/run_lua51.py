"""用 lupa 的 Lua 5.1 运行时跑 mod 的离线测试。

用法：python tools/run_lua51.py
依赖：PYTHONPATH 指向已解包的 lupa（仓库里放 tools/pyenv/ 即可，已 gitignore）
"""
import os
import sys

_here = os.path.dirname(os.path.abspath(__file__))
for _cand in (os.path.join(_here, 'pyenv'),
              os.path.join(_here, '..', '..', 'tools', 'pyenv'),
              os.path.join(_here, '..', '..', '..', 'tools', 'pyenv')):
    if os.path.isdir(_cand):
        sys.path.insert(0, os.path.abspath(_cand))

from lupa.lua51 import LuaRuntime  # noqa: E402

mod_dir = os.path.abspath(os.path.join(_here, '..'))
os.chdir(mod_dir)

runtime = LuaRuntime(unpack_returned_tuples=True)
with open(os.path.join(mod_dir, 'tests', 'run.lua'), 'r', encoding='utf-8') as fh:
    source = fh.read()

runtime.execute(source)
