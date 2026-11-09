"""The MPEG audio reader, on synthetic frames with zero main data."""

import unittest

from hqpack.errors import PackError
from hqpack.mp3 import crc16_arc, read_mp3

from tests import mp3_factory as f

# MPEG 1, 32 kHz, mono: 1,152 samples (36 ms) a frame, 576 (18 ms) a granule.
TEN_FRAMES = f.pattern((f.LOUD, 20))
# A LAME delay of 47 makes the start skip 47 + 529 = 576 samples, one granule;
# 47 + 1,105 = 1,152 samples, one frame, are removed in all.
DELAY = 47
PADDING = 1105


class DurationTest(unittest.TestCase):
    def test_without_an_info_frame_every_sample_plays(self):
        audio = read_mp3(f.stream(TEN_FRAMES))
        self.assertEqual((audio.version, audio.sample_rate, audio.channel_mode), ("1", 32000, "mono"))
        self.assertEqual((audio.frames, audio.samples_per_frame), (10, 1152))
        self.assertEqual((audio.frame_ms, audio.granule_ms), (36.0, 18.0))
        self.assertEqual(audio.duration_ms, 360.0)
        self.assertFalse(audio.delay_known)
        self.assertIsNone(audio.encoder_delay)
        self.assertIsNone(audio.padding)
        self.assertEqual([g.start_ms for g in audio.granules], [18.0 * i for i in range(20)])

    def test_the_lame_tag_removes_delay_and_padding(self):
        data = f.info_frame(frames=10, delay=DELAY, padding=PADDING) + f.stream(TEN_FRAMES)
        audio = read_mp3(data)
        self.assertEqual(audio.frames, 10)
        self.assertTrue(audio.delay_known)
        self.assertEqual(audio.lame_tag, "valid")
        self.assertEqual((audio.encoder_delay, audio.padding), (DELAY, PADDING))
        self.assertEqual(audio.duration_ms, 324.0)
        self.assertEqual(audio.granules[0].start_ms, -18.0)
        self.assertEqual(audio.granules[1].start_ms, 0.0)
        self.assertEqual(len(audio.granules), 20)

    def test_an_info_frame_without_a_lame_tag_is_not_audio(self):
        for tag in (b"Info", b"Xing"):
            audio = read_mp3(f.info_frame(frames=10, tag=tag) + f.stream(TEN_FRAMES))
            self.assertEqual(audio.frames, 10)
            self.assertFalse(audio.delay_known)
            self.assertEqual(audio.duration_ms, 360.0)

    def test_a_xing_header_without_a_frame_count(self):
        audio = read_mp3(f.info_frame(delay=DELAY, padding=PADDING) + f.stream(TEN_FRAMES))
        self.assertEqual((audio.frames, audio.duration_ms), (10, 324.0))

    def test_a_lame_tag_whose_crc_fails_is_not_used(self):
        data = f.info_frame(frames=10, delay=DELAY, padding=PADDING, break_crc=True) + f.stream(TEN_FRAMES)
        audio = read_mp3(data)
        self.assertEqual((audio.lame_tag, audio.delay_known, audio.encoder_delay), ("crc_mismatch", False, None))
        self.assertEqual((audio.frames, audio.duration_ms, audio.granules[0].start_ms), (10, 360.0, 0.0))

    def test_a_lame_tag_that_does_not_fit_the_frame_is_none(self):
        # MPEG 2, 16 kHz, 8 kbps: a 36-byte frame; the tag would need 36 bytes after the Xing fields.
        body = b"Xing" + (1).to_bytes(4, "big") + (2).to_bytes(4, "big") + b"LAME3.100"
        info = f.frame(None, version="2", sample_rate=16000, kbps=8, body=body)
        audio = read_mp3(info + f.stream([f.LOUD] * 2, version="2", sample_rate=16000, kbps=8))
        self.assertEqual((audio.lame_tag, audio.delay_known, audio.frames), ("none", False, 2))

    def test_an_ffmpeg_tag_is_a_lame_tag(self):
        data = f.info_frame(frames=10, delay=DELAY, padding=PADDING, encoder=b"Lavc58.13") + f.stream(TEN_FRAMES)
        self.assertTrue(read_mp3(data).delay_known)

    def test_another_encoder_string_is_no_lame_tag(self):
        data = f.info_frame(frames=10, delay=DELAY, padding=PADDING, encoder=b"Other1.0") + f.stream(TEN_FRAMES)
        audio = read_mp3(data)
        self.assertFalse(audio.delay_known)
        self.assertEqual(audio.duration_ms, 360.0)

    def test_crc16_arc(self):
        self.assertEqual(crc16_arc(b"123456789"), 0xBB3D)
        self.assertEqual(crc16_arc(b""), 0)

    def test_the_padding_bit_lengthens_a_frame(self):
        frames = [
            f.frame([(f.LOUD, f.LOUD)] * 2, sample_rate=44100, kbps=128, mode="joint_stereo", padding=p)
            for p in (0, 1, 1, 0)
        ]
        self.assertEqual([len(x) for x in frames], [417, 418, 418, 417])
        audio = read_mp3(b"".join(frames))
        self.assertEqual((audio.frames, audio.channels, audio.channel_mode), (4, 2, "joint_stereo"))
        self.assertAlmostEqual(audio.duration_ms, 4 * 1152 * 1000.0 / 44100)


class LevelTest(unittest.TestCase):
    def test_each_granule_and_channel_of_mpeg_1_stereo(self):
        granules = [((100, 160), (7, 30)), ((0, 210), (4095, 255))]
        audio = read_mp3(f.frame(granules, sample_rate=48000, kbps=128, mode="stereo"))
        self.assertEqual([g.channels for g in audio.granules], granules)
        self.assertEqual([g.start_ms for g in audio.granules], [0.0, 12.0])

    def test_mpeg_2_and_2_5(self):
        for version, rate, granule_ms in (("2", 16000, 36.0), ("2.5", 8000, 72.0)):
            for mode in ("mono", "dual_channel"):
                channels = 1 if mode == "mono" else 2
                values = [((300 + i, 140 + i),) * channels for i in range(3)]
                data = b"".join(f.frame([v], version=version, sample_rate=rate, kbps=16, mode=mode) for v in values)
                audio = read_mp3(data)
                self.assertEqual((audio.version, audio.sample_rate, audio.samples_per_frame), (version, rate, 576))
                self.assertEqual([g.channels for g in audio.granules], values)
                self.assertEqual(audio.granule_ms, granule_ms)
                self.assertEqual(audio.duration_ms, 3 * granule_ms)

    def test_a_crc_protected_frame(self):
        granules = [((123, 150),), ((0, 0),)]
        audio = read_mp3(f.frame(granules, protected=True) + f.frame(granules, protected=True))
        self.assertEqual([g.channels for g in audio.granules], granules * 2)

    def test_a_lame_tag_of_mpeg_2_stereo(self):
        data = f.info_frame(frames=4, delay=DELAY, padding=PADDING, version="2", sample_rate=16000, mode="stereo")
        data += f.stream([f.LOUD] * 4, version="2", sample_rate=16000, mode="stereo")
        audio = read_mp3(data)
        self.assertTrue(audio.delay_known)
        self.assertEqual((audio.frames, audio.encoder_delay, audio.padding), (4, DELAY, PADDING))
        self.assertEqual(audio.duration_ms, 72.0)


class TagTest(unittest.TestCase):
    def test_tags_at_either_end_are_skipped(self):
        audio = f.stream(TEN_FRAMES)
        expected = read_mp3(audio)
        for data in (
            f.id3v2() + audio,
            f.id3v2(footer=True) + audio,
            f.id3v2(version=3) + audio + f.id3v1(),
            audio + f.apev2(),
            audio + f.apev2(header=False),
            f.id3v2() + audio + f.apev2() + f.id3v1(),
        ):
            self.assertEqual(read_mp3(data), expected)

    def test_a_bad_id3v2_tag(self):
        audio = f.stream(TEN_FRAMES)
        not_synchsafe = bytearray(f.id3v2() + audio)
        not_synchsafe[9] |= 0x80
        self._refused(bytes(not_synchsafe), "not synchsafe")
        self._refused(f.id3v2(size=10000)[:10] + audio[:100], "runs past the end")
        self._refused(f.id3v2(version=5) + audio, "version 5.0")
        self._refused(b"ID3\x04\x00", "truncated")

    def test_a_bad_apev2_tag(self):
        audio = f.stream(TEN_FRAMES)
        marked = bytearray(audio + f.apev2(header=False))
        marked[-9] |= 0x20
        self._refused(bytes(marked), "marked as a header")
        self._refused(audio + f.apev2()[32:], "lacks the header")
        oversized = bytearray(audio + f.apev2(header=False))
        oversized[-20:-16] = (len(audio) + 100).to_bytes(4, "little")
        self._refused(bytes(oversized), "does not fit")

    def _refused(self, data, words):
        with self.assertRaises(PackError) as caught:
            read_mp3(data)
        self.assertIn(words, str(caught.exception))


class RefusalTest(unittest.TestCase):
    def assert_refused(self, data, words, offset):
        with self.assertRaises(PackError) as caught:
            read_mp3(data)
        message = str(caught.exception)
        self.assertIn(words, message)
        self.assertIn("byte %d" % offset, message)

    def test_lost_sync(self):
        audio = f.stream(TEN_FRAMES)
        self.assert_refused(audio[:288] + b"\x00" + audio[288:], "lost sync", 288)
        self.assert_refused(b"\x00" + audio, "lost sync", 0)
        self.assert_refused(f.id3v2(size=20) + b"\x00\x00" + audio, "lost sync", 30)
        self.assert_refused(audio + b"\xff\xfb\x00", "lost sync", len(audio))

    def test_a_truncated_frame(self):
        audio = f.stream(TEN_FRAMES)
        self.assert_refused(audio[:-1], "truncated", 288 * 9)
        self.assert_refused(audio[:-1] + f.id3v1(), "truncated", 288 * 9)

    def test_a_change_of_sample_rate_version_or_channels(self):
        first = f.frame()
        self.assert_refused(first + f.frame(sample_rate=48000), "sample rate from 32000 to 48000", 288)
        self.assert_refused(first + f.frame([(f.SILENT,)], version="2", sample_rate=16000), "MPEG 2", 288)
        self.assert_refused(first + f.frame(mode="stereo"), "channels from 1 to 2", 288)

    def test_a_change_between_stereo_modes_is_accepted(self):
        data = f.frame(mode="stereo") + f.frame(mode="joint_stereo")
        self.assertEqual(read_mp3(data).channel_mode, "stereo")

    def test_header_fields_outside_layer_iii(self):
        first = f.frame()
        for options, words in (
            ({"layer_bits": 0b10}, "Layer II, not Layer III"),
            ({"layer_bits": 0b11}, "Layer I, not Layer III"),
            ({"layer_bits": 0b00}, "reserved layer"),
            ({"version_bits": 0b01}, "reserved MPEG version"),
            ({"bitrate_index": 0}, "free bitrate"),
            ({"bitrate_index": 15}, "bad bitrate index 15"),
            ({"rate_index": 3}, "reserved sample rate"),
            ({"emphasis": 2}, "reserved emphasis"),
        ):
            with self.subTest(words):
                self.assert_refused(first + f.frame(**options), words, 288)

    def test_a_broken_info_frame(self):
        audio = f.stream(TEN_FRAMES)
        miscounted = f.info_frame(frames=9, delay=DELAY, padding=PADDING)
        self.assert_refused(miscounted + audio, "counts 9 frames, the file has 10", 21)
        self.assert_refused(f.info_frame(frames=10, flags=0x1F) + audio, "unknown flags", 21)
        cut = f.frame(None, version="2", sample_rate=16000, kbps=8, body=b"Xing" + (0x0F).to_bytes(4, "big"))
        self.assert_refused(cut + f.frame([(f.LOUD,)], version="2", sample_rate=16000, kbps=8), "is truncated", 13)
        too_much = f.info_frame(frames=1, delay=2000, padding=2000)
        self.assert_refused(too_much + f.frame(), "removes 4000 samples of 1152", 21)

    def test_no_audio_frame(self):
        self.assert_refused(f.info_frame(frames=0), "no MPEG audio frame", 0)
        self.assert_refused(f.id3v2(size=20), "no MPEG audio frame", 30)
        self.assert_refused(b"", "no MPEG audio frame", 0)


if __name__ == "__main__":
    unittest.main()
