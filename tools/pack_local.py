"""把仓库打成「本地 mod」zip：解压后直接是一个 skip_wait/ 文件夹。

用法：
    python tools/pack_local.py
    python tools/pack_local.py --output D:\\out\\skip_wait.zip

装法见 README 的 B 路线（放进 %LOCALAPPDATA%/MDL/Helldivers2/Mods/）。
管理器导入用的是 tools/pack_addon.py 产出的 addon 包，两者二选一。
"""
import argparse
import io
import os
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
MOD_DIR = os.path.abspath(os.path.join(HERE, ".."))
FOLDER = "skip_wait"
SKIP_DIRS = ("tests", "tools", "addon", "dist", ".git")
SKIP_FILES = ("HANDOFF.md", ".gitignore")
# 发布页文案只留本地（docs/nexus*、docs/ayaka*），不进发布包
SKIP_PREFIXES = ("docs/nexus", "docs/ayaka")


def version():
    with io.open(os.path.join(MOD_DIR, "mod.lua"), encoding="utf-8") as fh:
        for line in fh:
            if line.startswith("local VERSION"):
                return line.split("'")[1]
    raise SystemExit("mod.lua: VERSION not found")


def collect():
    out = []
    for folder, dirs, files in os.walk(MOD_DIR):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for name in files:
            if name in SKIP_FILES or name.endswith((".zip", ".log", ".pyc")):
                continue
            path = os.path.join(folder, name)
            rel = os.path.relpath(path, MOD_DIR).replace("\\", "/")
            if any(rel.startswith(prefix) for prefix in SKIP_PREFIXES):
                continue
            out.append((FOLDER + "/" + rel, path))
    return sorted(out)


def build(output):
    ver = version()
    files = collect()
    out = os.path.abspath(output)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with zipfile.ZipFile(out, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for arcname, path in files:
            info = zipfile.ZipInfo(arcname, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            with io.open(path, "rb") as fh:
                zf.writestr(info, fh.read())
    return out, ver, files


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--output")
    a = ap.parse_args()
    default = os.path.join(MOD_DIR, "dist", "skip_wait-%s.zip" % version())
    out, ver, files = build(a.output or default)
    print("Built " + out)
    print("  version: " + ver)
    print("  files: %d" % len(files))
    for arcname, _ in files:
        print("    " + arcname)


if __name__ == "__main__":
    main()
