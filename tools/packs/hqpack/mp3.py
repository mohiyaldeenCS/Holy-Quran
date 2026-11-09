"""A strict reader of MPEG audio Layer III files that decodes no audio sample (B0.5, D-179).

It skips one ID3v2 tag at the start and an ID3v1 and an APEv2 tag at the end,
then walks every frame header from the first byte after the ID3v2 tag to the
first byte of the end tags: MPEG 1, 2 and 2.5, Layer III, a bitrate from the
table (free bitrate refused). A lost sync, a truncated frame, or a frame whose
MPEG version, sample rate or channel count differs from the first is refused
with its byte offset. The last 128 bytes are an ID3v1 tag when they begin with
`TAG`, unless the frame walk from the start ends exactly at the end of the
file: then `TAG` lies inside the last frame and the bytes are audio.

A first frame that holds a Xing or Info header, or a Fraunhofer VBRI header,
is the encoder's info frame, not audio. Its frame count, when it has one, must
equal the audio frames (`xing_count` "equal") or exceed them by one, for
encoders that count the info frame itself ("includes_info_frame"); any other
count is refused. A LAME tag after a Xing or Info header gives the encoder
delay and padding when its CRC-16 holds. A tag whose CRC fails is reported
(`lame_tag` "crc_mismatch") and its delay and padding are not used: ffmpeg is
said to compute the CRC over a fixed 190 bytes, which differs from LAME's rule
outside MPEG 1 stereo, and an unverified value is never guessed at.

The level proxy is read from each audio frame's side information: per granule
and channel, `part2_3_length` (the bits of that granule's main data) and
`global_gain` (its quantiser step, 1.5 dB a step).
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Optional

from .errors import PackError

GRANULE_SAMPLES = 576
# LAME's documented decoder delay (528 samples, plus one), which a gapless
# decoder removes at the start together with the encoder delay.
DECODER_DELAY = 529
CHANNEL_MODES = ("stereo", "joint_stereo", "dual_channel", "mono")
LAME_NONE = "none"
LAME_VALID = "valid"
LAME_CRC_MISMATCH = "crc_mismatch"
XING_COUNT_EQUAL = "equal"
XING_COUNT_INCLUDES_INFO_FRAME = "includes_info_frame"

_VERSIONS = {0b11: "1", 0b10: "2", 0b00: "2.5"}
_SAMPLE_RATES = {
    "1": (44100, 48000, 32000),
    "2": (22050, 24000, 16000),
    "2.5": (11025, 12000, 8000),
}
_BITRATES_KBPS = {
    "1": (32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320),
    "2": (8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160),
}
_LAYERS = {0b01: "III", 0b10: "II", 0b11: "I"}
_INFO_TAGS = (b"Xing", b"Info")
_XING_FLAGS = 0x0F
# The VBRI header starts 32 bytes after the frame header, whatever the side
# information's size; its frame count is at byte 14 and its fixed part 26 bytes.
_VBRI_TAG = b"VBRI"
_VBRI_AT = 36
_VBRI_FRAMES_AT = 14
_VBRI_LENGTH = 26
_ID3V2_FOOTER_VERSION = 4
_LAME_ENCODERS = (b"LAME", b"Lavf", b"Lavc")
_LAME_TAG_LENGTH = 36
_LAME_CRC_AT = 34
_APE_PREAMBLE = b"APETAGEX"
_APE_HAS_HEADER = 1 << 31
_APE_IS_HEADER = 1 << 29


@dataclass(frozen=True)
class Granule:
    """One granule of 576 samples: its start in the playable timeline and (part2_3_length, global_gain) per channel."""

    start_ms: float
    channels: tuple


@dataclass(frozen=True)
class Mp3Audio:
    version: str
    sample_rate: int
    channel_mode: str
    channels: int
    frames: int
    samples_per_frame: int
    frame_ms: float
    granule_ms: float
    duration_ms: float
    delay_known: bool
    encoder_delay: Optional[int]
    padding: Optional[int]
    lame_tag: str
    xing_count: Optional[str]
    granules: tuple


@dataclass(frozen=True)
class _Header:
    offset: int
    version: str
    protected: bool
    sample_rate: int
    length: int
    channel_mode: str
    channels: int

    @property
    def mpeg1(self):
        return self.version == "1"

    @property
    def samples(self):
        return 1152 if self.mpeg1 else 576

    @property
    def side_info_offset(self):
        return self.offset + 4 + (2 if self.protected else 0)

    @property
    def side_info_size(self):
        if self.mpeg1:
            return 17 if self.channels == 1 else 32
        return 9 if self.channels == 1 else 17


def read_mp3(data: bytes) -> Mp3Audio:
    start = _id3v2_end(data)
    end = _audio_end(data, start)
    headers = []
    info = None
    position = start
    while position < end:
        header = _header(data, position, end)
        if headers:
            _check_same(headers[0], header)
        frame_end = position + header.length
        if frame_end > end:
            raise PackError(
                "the frame at byte %d is truncated: %d of its %d bytes are present"
                % (position, end - position, header.length)
            )
        if not headers:
            info = _info_frame(data, header)
        headers.append(header)
        position = frame_end
    audio = headers[1:] if info is not None else headers
    if not audio:
        raise PackError("no MPEG audio frame after byte %d" % start)
    return _audio(data, audio, audio[0], info, _xing_count(info, len(audio)))


@dataclass(frozen=True)
class _Info:
    kind: str
    offset: int
    frames: Optional[int]
    lame_tag: str
    encoder_delay: Optional[int]
    padding: Optional[int]


def _xing_count(info, frames):
    if info is None or info.frames is None:
        return None
    if info.frames == frames:
        return XING_COUNT_EQUAL
    if info.frames == frames + 1:
        return XING_COUNT_INCLUDES_INFO_FRAME
    raise PackError(
        "the %s header at byte %d counts %d frames, the file has %d (or %d with the info frame)"
        % (info.kind, info.offset, info.frames, frames, frames + 1)
    )


def _audio(data, audio, first, info, xing_count):
    total = len(audio) * first.samples
    delay_known = info is not None and info.encoder_delay is not None
    if delay_known:
        removed = info.encoder_delay + info.padding
        if removed >= total:
            raise PackError(
                "the LAME tag at byte %d removes %d samples of %d" % (info.offset, removed, total)
            )
        playable = total - removed
        skip = info.encoder_delay + DECODER_DELAY
    else:
        playable = total
        skip = 0
    rate = first.sample_rate
    granules = []
    for header in audio:
        for channels in _side_info(data, header):
            granules.append(
                Granule(start_ms=(len(granules) * GRANULE_SAMPLES - skip) * 1000.0 / rate, channels=channels)
            )
    return Mp3Audio(
        version=first.version,
        sample_rate=rate,
        channel_mode=first.channel_mode,
        channels=first.channels,
        frames=len(audio),
        samples_per_frame=first.samples,
        frame_ms=first.samples * 1000.0 / rate,
        granule_ms=GRANULE_SAMPLES * 1000.0 / rate,
        duration_ms=playable * 1000.0 / rate,
        delay_known=delay_known,
        encoder_delay=info.encoder_delay if delay_known else None,
        padding=info.padding if delay_known else None,
        lame_tag=info.lame_tag if info is not None else LAME_NONE,
        xing_count=xing_count,
        granules=tuple(granules),
    )


def _id3v2_end(data):
    if not data.startswith(b"ID3"):
        return 0
    if len(data) < 10:
        raise PackError("the ID3v2 tag at byte 0 is truncated")
    if data[3] not in (2, 3, 4) or data[4] == 0xFF:
        raise PackError("the ID3v2 tag at byte 0 has version %d.%d, not 2.2, 2.3 or 2.4" % (data[3], data[4]))
    if any(b & 0x80 for b in data[6:10]):
        raise PackError("the ID3v2 tag at byte 0 has a size that is not synchsafe")
    size = (data[6] << 21) | (data[7] << 14) | (data[8] << 7) | data[9]
    footer = data[3] == _ID3V2_FOOTER_VERSION and data[5] & 0x10
    end = 10 + size + (10 if footer else 0)
    if end > len(data):
        raise PackError("the ID3v2 tag at byte 0 runs past the end of the file")
    return end


def _audio_end(data, start):
    end = len(data)
    if end - start >= 128 and data[end - 128:end - 125] == b"TAG" and not _walk_ends_at(data, start, end):
        end -= 128
    if end - start >= 32 and data[end - 32:end - 24] == _APE_PREAMBLE:
        footer = end - 32
        size = int.from_bytes(data[footer + 12:footer + 16], "little")
        flags = int.from_bytes(data[footer + 20:footer + 24], "little")
        if flags & _APE_IS_HEADER:
            raise PackError("the APEv2 footer at byte %d is marked as a header" % footer)
        total = size + (32 if flags & _APE_HAS_HEADER else 0)
        if size < 32 or total > end - start:
            raise PackError("the APEv2 tag at byte %d has a size of %d bytes, which does not fit" % (footer, size))
        if flags & _APE_HAS_HEADER and data[end - total:end - total + 8] != _APE_PREAMBLE:
            raise PackError("the APEv2 tag at byte %d lacks the header its flags announce" % footer)
        end -= total
    return end


def _walk_ends_at(data, start, end):
    """Whether frame headers, each read from where the previous frame ends, lead from `start` exactly to `end`."""
    position = start
    while position < end:
        try:
            position += _header(data, position, end).length
        except PackError:
            return False
    return position == end


def _header(data, offset, end):
    if end - offset < 4 or data[offset] != 0xFF or data[offset + 1] & 0xE0 != 0xE0:
        raise PackError("lost sync at byte %d: no frame header" % offset)
    b1, b2, b3 = data[offset + 1], data[offset + 2], data[offset + 3]
    version = _VERSIONS.get((b1 >> 3) & 0b11)
    if version is None:
        raise PackError("the frame at byte %d has the reserved MPEG version" % offset)
    layer = _LAYERS.get((b1 >> 1) & 0b11)
    if layer is None:
        raise PackError("the frame at byte %d has the reserved layer" % offset)
    if layer != "III":
        raise PackError("the frame at byte %d is Layer %s, not Layer III" % (offset, layer))
    bitrate_index = b2 >> 4
    if bitrate_index == 0:
        raise PackError("the frame at byte %d has a free bitrate" % offset)
    if bitrate_index == 15:
        raise PackError("the frame at byte %d has the bad bitrate index 15" % offset)
    rate_index = (b2 >> 2) & 0b11
    if rate_index == 3:
        raise PackError("the frame at byte %d has the reserved sample rate" % offset)
    if b3 & 0b11 == 0b10:
        raise PackError("the frame at byte %d has the reserved emphasis" % offset)
    sample_rate = _SAMPLE_RATES[version][rate_index]
    bitrate = _BITRATES_KBPS["1" if version == "1" else "2"][bitrate_index - 1] * 1000
    coefficient = 144 if version == "1" else 72
    mode = CHANNEL_MODES[b3 >> 6]
    return _Header(
        offset=offset,
        version=version,
        protected=not b1 & 1,
        sample_rate=sample_rate,
        length=coefficient * bitrate // sample_rate + ((b2 >> 1) & 1),
        channel_mode=mode,
        channels=1 if mode == "mono" else 2,
    )


def _check_same(first, header):
    if header.version != first.version:
        raise PackError(
            "the frame at byte %d is MPEG %s, the first frame MPEG %s" % (header.offset, header.version, first.version)
        )
    if header.sample_rate != first.sample_rate:
        raise PackError(
            "the frame at byte %d changes the sample rate from %d to %d Hz"
            % (header.offset, first.sample_rate, header.sample_rate)
        )
    if header.channels != first.channels:
        raise PackError(
            "the frame at byte %d changes the channels from %d to %d"
            % (header.offset, first.channels, header.channels)
        )


def _info_frame(data, header):
    tag = header.side_info_offset + header.side_info_size
    frame_end = header.offset + header.length
    if data[tag:tag + 4] not in _INFO_TAGS:
        return _vbri_frame(data, header)
    position = tag + 8
    if position > frame_end:
        raise PackError("the Xing header at byte %d is truncated" % tag)
    flags = int.from_bytes(data[tag + 4:position], "big")
    if flags & ~_XING_FLAGS:
        raise PackError("the Xing header at byte %d has unknown flags %#x" % (tag, flags))
    frames = None
    for flag, length in ((0x1, 4), (0x2, 4), (0x4, 100), (0x8, 4)):
        if flags & flag:
            if position + length > frame_end:
                raise PackError("the Xing header at byte %d is truncated" % tag)
            if flag == 0x1:
                frames = int.from_bytes(data[position:position + 4], "big")
            position += length
    state, delay, padding = _lame_tag(data, header, position)
    return _Info(kind="Xing", offset=tag, frames=frames, lame_tag=state, encoder_delay=delay, padding=padding)


def _vbri_frame(data, header):
    tag = header.offset + _VBRI_AT
    if data[tag:tag + 4] != _VBRI_TAG:
        return None
    if tag + _VBRI_LENGTH > header.offset + header.length:
        raise PackError("the VBRI header at byte %d is truncated" % tag)
    count = tag + _VBRI_FRAMES_AT
    frames = int.from_bytes(data[count:count + 4], "big")
    return _Info(kind="VBRI", offset=tag, frames=frames, lame_tag=LAME_NONE, encoder_delay=None, padding=None)


def _lame_tag(data, header, lame):
    frame_end = header.offset + header.length
    if lame + _LAME_TAG_LENGTH > frame_end or data[lame:lame + 4] not in _LAME_ENCODERS:
        return LAME_NONE, None, None
    crc_at = lame + _LAME_CRC_AT
    stored = int.from_bytes(data[crc_at:crc_at + 2], "big")
    if crc16_arc(data[header.offset:crc_at]) != stored:
        return LAME_CRC_MISMATCH, None, None
    b0, b1, b2 = data[lame + 21], data[lame + 22], data[lame + 23]
    return LAME_VALID, (b0 << 4) | (b1 >> 4), ((b1 & 0x0F) << 8) | b2


def crc16_arc(data: bytes) -> int:
    """CRC-16/ARC (reflected polynomial 0xA001, initial 0), the LAME tag's checksum."""
    crc = 0
    for byte in data:
        crc ^= byte
        for _ in range(8):
            crc = (crc >> 1) ^ 0xA001 if crc & 1 else crc >> 1
    return crc


def _side_info(data, header):
    """((part2_3_length, global_gain) per channel) per granule, from the frame's side information."""
    size = header.side_info_size
    bits = int.from_bytes(data[header.side_info_offset:header.side_info_offset + size], "big")
    reader = _Bits(bits, size * 8)
    channels = header.channels
    if header.mpeg1:
        reader.skip(9 + (5 if channels == 1 else 3) + 4 * channels)
        granules = 2
    else:
        reader.skip(8 + (1 if channels == 1 else 2))
        granules = 1
    result = []
    for _ in range(granules):
        values = []
        for _ in range(channels):
            part2_3_length = reader.take(12)
            reader.skip(9)  # big_values
            global_gain = reader.take(8)
            # scalefac_compress; window_switching_flag and its 22 bits either way;
            # (preflag,) scalefac_scale, count1table_select.
            reader.skip((4 if header.mpeg1 else 9) + 1 + 22 + (3 if header.mpeg1 else 2))
            values.append((part2_3_length, global_gain))
        result.append(tuple(values))
    return result


class _Bits:
    def __init__(self, value, length):
        self._value = value
        self._left = length

    def take(self, count):
        self._left -= count
        return (self._value >> self._left) & ((1 << count) - 1)

    def skip(self, count):
        self._left -= count
