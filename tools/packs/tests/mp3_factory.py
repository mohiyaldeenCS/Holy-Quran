"""Synthetic MPEG audio Layer III bytes for the reader's and the drift tool's tests.

Valid frame headers, side information whose part2_3_length and global_gain draw
a chosen loud and silent pattern, and zero main data. Written from the MPEG-1
and MPEG-2 Layer III layout, independently of hqpack/mp3.py: the other side
information fields are filled with set bits, so a reader that is off by one
field reads the wrong values.
"""

from __future__ import annotations

LOUD = (400, 170)
QUIET = (40, 120)
SILENT = (0, 0)

_VERSION_BITS = {"1": 0b11, "2": 0b10, "2.5": 0b00}
_RATE_INDEX = {
    ("1", 44100): 0, ("1", 48000): 1, ("1", 32000): 2,
    ("2", 22050): 0, ("2", 24000): 1, ("2", 16000): 2,
    ("2.5", 11025): 0, ("2.5", 12000): 1, ("2.5", 8000): 2,
}
_KBPS = {
    "1": (32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320),
    "2": (8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160),
}
_MODES = {"stereo": 0, "joint_stereo": 1, "dual_channel": 2, "mono": 3}


def _crc_table():
    table = []
    for n in range(256):
        c = n
        for _ in range(8):
            c = (c >> 1) ^ 0xA001 if c & 1 else c >> 1
        table.append(c)
    return table


_CRC_TABLE = _crc_table()


def crc16(data):
    crc = 0
    for byte in data:
        crc = (crc >> 8) ^ _CRC_TABLE[(crc ^ byte) & 0xFF]
    return crc


class _Writer:
    def __init__(self):
        self.value = 0
        self.length = 0

    def put(self, value, bits):
        assert 0 <= value < (1 << bits)
        self.value = (self.value << bits) | value
        self.length += bits

    def bytes(self):
        assert self.length % 8 == 0
        return self.value.to_bytes(self.length // 8, "big")


def side_info(granules, version, channels):
    mpeg1 = version == "1"
    w = _Writer()
    if mpeg1:
        w.put(0x1FF, 9)
        w.put(0, 5 if channels == 1 else 3)
        w.put((1 << (4 * channels)) - 1, 4 * channels)
    else:
        w.put(0xFF, 8)
        w.put(0, 1 if channels == 1 else 2)
    assert len(granules) == (2 if mpeg1 else 1)
    for number, granule in enumerate(granules):
        assert len(granule) == channels
        for part2_3_length, global_gain in granule:
            w.put(part2_3_length, 12)
            w.put(0x1FF, 9)
            w.put(global_gain, 8)
            w.put((1 << (4 if mpeg1 else 9)) - 1, 4 if mpeg1 else 9)
            w.put(number & 1, 1)
            w.put(0x3FFFFF, 22)
            w.put((1 << (3 if mpeg1 else 2)) - 1, 3 if mpeg1 else 2)
    return w.bytes()


def frame_length(version="1", sample_rate=32000, kbps=64, padding=0):
    return (144 if version == "1" else 72) * kbps * 1000 // sample_rate + padding


def frame(
    granules=None,
    version="1",
    sample_rate=32000,
    kbps=64,
    mode="mono",
    padding=0,
    protected=False,
    body=b"",
    version_bits=None,
    layer_bits=0b01,
    bitrate_index=None,
    rate_index=None,
    emphasis=0,
):
    """One frame; `granules` holds per granule (2 for MPEG 1, else 1) one (part2_3_length, global_gain) per channel."""
    channels = 1 if mode == "mono" else 2
    if granules is None:
        granules = [(SILENT,) * channels] * (2 if version == "1" else 1)
    b1 = 0xE0 | (_VERSION_BITS[version] if version_bits is None else version_bits) << 3
    b1 |= layer_bits << 1 | (0 if protected else 1)
    index = _KBPS["1" if version == "1" else "2"].index(kbps) + 1 if bitrate_index is None else bitrate_index
    rate = _RATE_INDEX[(version, sample_rate)] if rate_index is None else rate_index
    header = bytes([0xFF, b1, index << 4 | rate << 2 | padding << 1, _MODES[mode] << 6 | emphasis])
    data = header + (b"\x00\x00" if protected else b"") + side_info(granules, version, channels) + body
    length = frame_length(version, sample_rate, kbps, padding)
    assert len(data) <= length
    return data + bytes(length - len(data))


def stream(levels, version="1", sample_rate=32000, kbps=64, mode="mono", protected=False):
    """Frames whose granules carry `levels`, one (part2_3_length, global_gain) per granule for every channel."""
    channels = 1 if mode == "mono" else 2
    per_frame = 2 if version == "1" else 1
    assert len(levels) % per_frame == 0
    frames = []
    for i in range(0, len(levels), per_frame):
        granules = [(level,) * channels for level in levels[i:i + per_frame]]
        frames.append(frame(granules, version, sample_rate, kbps, mode, protected=protected))
    return b"".join(frames)


def pattern(*runs):
    """Levels from (level, count) runs."""
    return [level for level, count in runs for _ in range(count)]


def info_frame(
    frames=None,
    delay=None,
    padding=None,
    tag=b"Info",
    encoder=b"LAME3.100",
    flags=None,
    break_crc=False,
    version="1",
    sample_rate=32000,
    kbps=64,
    mode="mono",
):
    """An encoder info frame: a Xing or Info header, and a LAME tag when `delay` is given."""
    if flags is None:
        flags = 0x0F if frames is not None else 0x0E
    fields = b""
    if flags & 0x1:
        fields += frames.to_bytes(4, "big")
    if flags & 0x2:
        fields += (12345).to_bytes(4, "big")
    if flags & 0x4:
        fields += bytes(range(100))
    if flags & 0x8:
        fields += (57).to_bytes(4, "big")
    body = tag + flags.to_bytes(4, "big") + fields
    lame = b""
    if delay is not None:
        lame = encoder.ljust(9, b" ") + bytes(12)
        lame += bytes([delay >> 4, (delay & 0x0F) << 4 | padding >> 8, padding & 0xFF]) + bytes(10)
    data = bytearray(frame(None, version, sample_rate, kbps, mode, body=body + lame + b"\x00\x00"))
    if delay is not None:
        channels = 1 if mode == "mono" else 2
        side = {("1", 1): 17, ("1", 2): 32}.get((version, channels), 9 if channels == 1 else 17)
        crc_at = 4 + side + len(body) + 34
        crc = crc16(bytes(data[:crc_at])) ^ (1 if break_crc else 0)
        data[crc_at:crc_at + 2] = crc.to_bytes(2, "big")
    return bytes(data)


def id3v2(size=20, footer=False, version=4):
    synchsafe = bytes([(size >> 21) & 0x7F, (size >> 14) & 0x7F, (size >> 7) & 0x7F, size & 0x7F])
    head = b"ID3" + bytes([version, 0, 0x10 if footer else 0]) + synchsafe
    return head + bytes(size) + (b"3DI" + bytes([version, 0, 0x10]) + synchsafe if footer else b"")


def id3v1():
    return b"TAG" + bytes(125)


def apev2(items=b"\x00" * 24, header=True):
    size = len(items) + 32

    def block(flags):
        return b"APETAGEX" + (2000).to_bytes(4, "little") + size.to_bytes(4, "little") + (1).to_bytes(4, "little") + (
            flags.to_bytes(4, "little") + bytes(8)
        )

    has_header = 1 << 31 if header else 0
    return (block(has_header | 1 << 29) if header else b"") + items + block(has_header)
