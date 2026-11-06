"""Package Skip Wait as an Arsenal / HD2MM addon zip.

The manager-importable format is a ZIP with a manifest and an Addon/ folder
holding a .patch_0 archive. The archive carries one declared entry
(mods/Reroll24/skip_wait) plus the mod's modules as require-able resources.

Usage:
    python tools/pack_addon.py
    python tools/pack_addon.py --output D:\\out\\skip_wait-addon.zip
"""
import argparse
import io
import json
import os
import sys
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hd2_archive as A

HERE = os.path.dirname(os.path.abspath(__file__))
MOD_DIR = os.path.abspath(os.path.join(HERE, ".."))
NAME = "mods/Reroll24/skip_wait"
GUID = "8f5a3c61-7d2e-4b9a-9c41-2f6d1e8a3b57"
DISPLAY = "Skip Wait / 跳过人生"
DESCRIPTION = ("适配 MDL3 的过场动画跳过脚本（Lua）：可倍速跳过进入舰桥、FTL 跃迁、冷冻舱解冻、"
               "空降舱进出、空投发射的舰桥推进、任务结算与回船电梯等过场，并为每段提供独立的倍速与跳过选项。"
               "测试版。需要 MDL3 3.0.0-dev.x（addon 运行环境，写法沿用 HD2-Addon 规范）。")


def version():
    with io.open(os.path.join(MOD_DIR, "mod.lua"), encoding="utf-8") as fh:
        for line in fh:
            if line.startswith("local VERSION"):
                return line.split("'")[1]
    raise SystemExit("mod.lua: VERSION not found")


def body(path):
    with io.open(path, "rb") as fh:
        return fh.read()


def declared(name, source):
    marker = ("-- HD2-Addon: " + name + "\n").encode("utf-8")
    if source.startswith(b"-- HD2-Addon:"):
        line, _, rest = source.partition(b"\n")
        if line.rstrip(b"\r") != marker[:-1]:
            raise SystemExit("entry declaration does not match " + name)
        source = rest
    return marker + source


def modules():
    out = {}
    for folder, prefix in (("core", "core_"), ("detectors", "detectors_")):
        base = os.path.join(MOD_DIR, folder)
        for entry in sorted(os.listdir(base)):
            if not entry.endswith(".lua"):
                continue
            stem = entry[:-4]
            out[prefix + stem] = body(os.path.join(base, entry))
    return out


def build(output):
    ver = version()
    entry = declared(NAME, body(os.path.join(MOD_DIR, "addon", "entry.lua")))
    resources = {NAME: A.envelope(entry)}
    for suffix, source in modules().items():
        if source.startswith(b"-- HD2-Addon:"):
            raise SystemExit("module " + suffix + " must not declare itself")
        resources[NAME + "/" + suffix] = A.envelope(source)
    archive = A.make_archive(resources)

    # Options 只是管理器用来分组/展示的元数据，不是部署必需：实测去掉后仍可正常部署，
    # 所以包里不再写；组件就是根目录下的 Addon/。
    manifest = {
        "Version": 1,
        "Guid": GUID,
        "Name": DISPLAY,
        "Author": "Reroll24",
        "Description": DESCRIPTION,
    }

    files = {
        "manifest.json": (json.dumps(manifest, indent=2, ensure_ascii=False) + "\n").encode("utf-8"),
        "Addon/" + A.ARCHIVE_NAME: archive,
        "Addon/" + A.ARCHIVE_NAME + ".stream": b"",
        "Addon/" + A.ARCHIVE_NAME + ".gpu_resources": b"",
    }
    # 文档一起放进包根目录（管理器不会部署它们，但用户解压/查看时能看到）
    for doc in ("README.md", "LICENSE", "NOTICE", "CHANGELOG.md"):
        with io.open(os.path.join(MOD_DIR, doc), "rb") as fh:
            files[doc] = fh.read()
    out = os.path.abspath(output)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with zipfile.ZipFile(out, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for path in sorted(files):
            info = zipfile.ZipInfo(path, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            zf.writestr(info, files[path])
    return out, ver, resources, archive


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--output")
    a = ap.parse_args()
    default = os.path.join(MOD_DIR, "dist", "skip_wait-addon-%s.zip" % version())
    out, ver, resources, archive = build(a.output or default)
    print("Built " + out)
    print("  version: " + ver)
    print("  resources: %d, archive bytes: %d" % (len(resources), len(archive)))
    for name in sorted(resources):
        print("    " + name)


if __name__ == "__main__":
    main()
