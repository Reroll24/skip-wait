"""Helldivers 2 Lua patch archive (.patch_N) reader/writer.

Vendored from MrChengl11/hd2-lua-mod-skill (MIT), which mirrors
BingusSharedLoader scripts/archive.py. Used only by the local packaging tool;
not shipped inside the mod.

Format (little-endian):
  offset 0   72-byte header   <III20sQQ24s
  offset 72  32 bytes per type table
  offset 104 80 bytes per resource entry
  data       resource bodies, each 16-byte aligned:
             u32 body_length, u32 version(=2), body, pad to 16
"""
import struct

MAGIC = 0xF0000011
TYPE = 0xA14E8DFA2CD117E2
ENVELOPE_VERSION = 2
FAMILY = "9ba626afa44a3aa3"
ARCHIVE_NAME = FAMILY + ".patch_0"

_M = (1 << 64) - 1
_MIX = 0xC6A4A7935BD1E995


def resource_hash(name: str) -> int:
    """Seed-zero MurmurHash64A over the UTF-8 resource path."""
    data = name.encode("utf-8")
    value = len(data) * _MIX & _M
    end = len(data) // 8 * 8
    for (word,) in struct.iter_unpack("<Q", data[:end]):
        word = word * _MIX & _M
        word ^= word >> 47
        value = (value ^ (word * _MIX & _M)) * _MIX & _M
    if data[end:]:
        value = (value ^ int.from_bytes(data[end:], "little")) * _MIX & _M
    value ^= value >> 47
    value = value * _MIX & _M
    return value ^ (value >> 47)


def make_archive_raw(pairs) -> bytes:
    pairs = list(pairs)
    if not pairs:
        raise ValueError("an archive needs at least one resource")
    count = len(pairs)
    offset = (104 + 80 * count + 15) & ~15
    entries, body = bytearray(), bytearray(offset)
    for index, (name_hash, resource) in enumerate(pairs):
        entries += struct.pack("<7Q6I", name_hash, TYPE, offset,
                               0, 0, 0, 0, len(resource), 0, 0, 16, 16, index)
        body += resource
        body += b"\0" * (-len(body) % 16)
        offset = len(body)
    header = struct.pack("<III20sQQ24s", MAGIC, 1, count, b"", offset, 0, b"")
    types = struct.pack("<IIQIIII", 0, 0, TYPE, count, 0, 16, 16)
    body[:104 + len(entries)] = header + types + entries
    return bytes(body)


def make_archive(resources: dict) -> bytes:
    return make_archive_raw((resource_hash(n), r) for n, r in sorted(resources.items()))


def envelope(body: bytes) -> bytes:
    return struct.pack("<II", len(body), ENVELOPE_VERSION) + body
