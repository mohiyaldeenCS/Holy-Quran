# Recitation candidates for the first release (O-04)

Research by a read-only run in Actions on 2026-11-04 (run 41850166495, sonnet), kept as it came.
No audio or Quran text was downloaded. It is a proposal: the owner chooses (D-119, D-162 (10)),
and no recitation enters the app until its rights record in `RIGHTS_REGISTER.md` is complete
from his own papers. The owner's choice is recorded in `docs/DECISIONS.md` when he makes it.

# Candidate recitations for the first release (O-04, B0.5, D-119, D-162 (10)): research report

Read-only run. I committed nothing, edited no file and downloaded no audio or Quran text. Everything below comes from web pages, JSON metadata and directory listings. Every claim has a URL. Where I found nothing I wrote "not found".

## 1. What the app needs (from the repository)

- **File shapes.** The recitation pack indexes files per ayah or per surah, one unit per recitation (`unit` is `ayah` or `surah`). It also holds optional `basmala` and `istiadha` parts. Each file has `quality_kbps`, `bytes`, `sha256` and an optional `duration_ms` (`docs/CONTENT_PACKS.md`, "Recitation pack").
- **Highlighting and timing.**
  - Per-ayah recitations need no timing for ayah highlighting (D-112, D-152).
  - Surah files need ayah timing from SOURCES row 6.
  - Word highlighting (SY-02) and AU-20 need word timing from row 6, labelled only after drift is measured per recitation (PRD risk table).
- **Basmala and isti'adha.** AU-24 says they are heard as the reciter recorded them and are never built from another reciter's recording.
- **Rights.** SOURCES row 7 is "Ready" on the owner's statement of 2026-10-07. Each recitation still needs a complete rights record: stream, host, offline, cut or re-encode, credit (`docs/content/RIGHTS_REGISTER.md`, "Recitations", currently empty).
- **Excluded provider.** The Quran Foundation API cannot be used. Its terms bar caching beyond one week and a prepackaged database; audio is part of "QF Content": https://api-docs.quran.foundation/legal/developer-terms/

## 2. Providers: what their published terms and data say

### 2.1 everyayah.com

- **Layout.** Per-ayah `SSSAAA.mp3` in one folder per edition, for example `https://everyayah.com/data/Alafasy_128kbps/001001.mp3`. The editions and bit rates are in https://everyayah.com/data/recitations.js (79 entries). Bit rate is part of the folder name, and an edition often exists at several rates.
- **Extra files per edition.** The listings show `000_versebyverse.zip` (about 1 GB), `000_checksum.md5`, and `PageMp3s/` and `zips/` folders: https://everyayah.com/data/Alafasy_128kbps/ and https://everyayah.com/data/Husary_64kbps/
  - `Alafasy_128kbps` also has `000_unverified_checksum.md5` and `000_afasy_update_aug18_2010.zip`.
  - `Husary_64kbps` has `001000.mp3` (42 KB), which is not an ayah file. Its purpose is not stated.
- **Basmala and isti'adha.** The data root has two single files, `bismillah.mp3` (26 KB) and `audhubillah.mp3` (106 KB): https://everyayah.com/data/. Nothing states whose voice they are or that they belong to any reciter. Under AU-24 they cannot stand in for a reciter's own.
- **Missing files.** The only collections the site marks as incomplete are Warsh Abdul Basit, Ibrahim Akhdar 64, Menshawi 32 and Mustafa Ismail 48: https://everyayah.com/recitations_ayat.html. None of those is a candidate here.
- **Terms.**
  - No terms or copyright text on the home page, the ayat page or the data index (all three fetched; none found).
  - The only text I found is the timing files' disclaimer: https://everyayah.com/data/timings_files/000_disclaimer.txt. It says the content is copyrighted by VerseByVerseQuran.com and "You must link back to our site from your product and web-site to use these timings". It also says the files are provided as-is, and that many MP3s "were manually fixed after the files were split", so timings may not be fully accurate. The fetch tool paraphrased everything except the link-back sentence.
  - A third-party survey says everyayah.com publishes no site-wide licence and that the disclaimer's licence link no longer resolves: https://huggingface.co/datasets/maqra-project/ayah-images. This is secondary and I did not verify it on everyayah itself.
  - A command-line tool's page says the recitations' copyright belongs to the reciters: https://zff.dev/ReflectsLight/tilawah. Also secondary.
- **Reading.** everyayah is a convenient file source with checksums. It grants nothing about hosting, offline use or re-encoding. The rights holders' permission is the only basis.

### 2.2 Islamic Network CDN (alquran.cloud)

- **Layout.**
  - Per ayah: `https://cdn.islamic.network/quran/audio/{bitrate}/{edition}/{number}.mp3`, where `{number}` runs 1 to 6236, a global ayah number and not `SSSAAA`.
  - Per surah: `https://cdn.islamic.network/quran/audio-surah/{bitrate}/{edition}/{number}.mp3`.
  - Bit rates are 192, 128, 64, 48, 40 and 32 kbps, not all for every edition: https://alquran.cloud/cdn
- **Editions.** The edition list names match everyayah's labels (for example `ar.alafasy`, `ar.husary`, `ar.minshawi`, `ar.abdulbasitmurattal`, `ar.abdurrahmaansudais`, `ar.saoodshuraym`, `ar.hanirifai`): https://api.alquran.cloud/v1/edition?format=audio&language=ar. That the audio is the same recording as everyayah's is my inference from the names only. It is not stated.
- **`info.json`.** The page names `info.json` per edition as the place for sizes. My fetch of `https://cdn.islamic.network/quran/audio/128/ar.alafasy/info.json` returned 403, so its content is not found.
- **Terms, quoted from https://alquran.cloud/terms-and-conditions:**
  - "Recitations are licensed to us by the reciters or their estates for free, non-commercial redistribution".
  - "You may stream, embed and download them for personal and educational use."
  - "copyrights lie with the reciters and they may ask you to remove the conent."
  - "please cache aggressively at your own edge."
- **Reading.** This is the strongest published statement I found for non-commercial redistribution of Hafs recitations, and it fits a free, non-profit, ad-free app. It does not mention hosting on a third party's server, re-encoding or cutting. It is the CDN's licence from the reciters, not a grant to the owner. Its "reciters or their estates" claim is its own and is not something I could check.

### 2.3 mp3quran.net

- **API.**
  - `https://mp3quran.net/api/v3/reciters` returns, per moshaf, `server`, `surah_total`, `surah_list` and a name that carries riwaya and style (for example "Rewayat Hafs A'n Assem - Murattal"): https://www.mp3quran.net/ar/api
  - Examples of `server`, from the API output: `https://cdn.mp3quran.net/audio/abdulrahman-sudais/r1/` (reciter 54), `.../hani-rifai/r1/` (89), `.../mahmoud-husary/r1/` (118), `.../mishary-alafasy/r1/` (123), `.../muhammad-minshawi/r1/` (112), `.../abdulbasit-abdulsamad/r3/` (53). Each shows 114 surahs.
- **Layout.** Per-surah files. The filename pattern and the bit rates are not stated on the pages I read: not found.
- **Ayah timing.** `https://mp3quran.net/api/v3/ayat_timing?surah=S&read=ID`. Fields are `ayah`, `start_time`, `end_time`, `polygon`, `x`, `y`, `page`. The list of timed reads is https://mp3quran.net/api/v3/ayat_timing/reads (115 entries).
  - The ids in that list match the moshaf ids in the reciters API for Husary 118, Alafasy 123, Minshawi 112, Abdul Basit 53, Sudais 54, Shuraym 31, Ghamdi 30, Shatri 4, Hani Rifai 89, Tablawi 106 and Dossari 92. That a read id is the moshaf id is my inference.
  - Maher al-Muaiqly appears in the list only as id 133, labelled "المصحف المجود".
  - **Numbering.**
    - `read=118`, surah 1 returns entries 0 to 6 (seven entries). Entry 0 is 0 to 11,705.
    - `read=118`, surah 2 returns entries 0 to 286 (287 entries). Entry 0 is 0 to 6,054.
    - Entry 0 is therefore a lead-in segment before ayah 1, which the numbering of surah 1 does not match with 1 to 7.
  - **Units.** Not stated on the docs page.
- **Word timing.** None on mp3quran: not found. Its timing is ayah level, with page-image polygons.
- **Terms.** No terms of use, copyright or permission text on the home page, the API page or the About page (https://www.mp3quran.net/ar, https://www.mp3quran.net/ar/api, https://www.mp3quran.net/ar/about): not found. Its footer links an unread privacy page and contact form. The About page lists "Atheer, Haramain and Telawa" as partners without saying they supplied recordings. Permission would have to be asked of mp3quran and each reciter.

### 2.4 QUL by Tarteel

- **Catalogue.** https://qul.tarteel.ai/resources/recitation lists 133 recitations: 18 ayah-by-ayah (17 with segments) and 115 surah-by-surah (42 with segments).
  - Ayah-by-ayah with segments include Sudais, Husary (Muallim, Murattal, Mujawwad), Hani Rifai, Shuraym, Yasser al-Dosari, Minshawi, al-Tunaiji, Alafasy, Abdul Basit (Murattal and Mujawwad), al-Tablawi, Maher al-Mu'aiqly, Abu Bakr al-Shatri and Saad al-Ghamdi.
  - Surah-by-surah with segments include Alafasy (resource 414, "one file per surah, with timings for each word"), Minshawi, Abdul Basit, Husary, Rifai and Sudais, among many others.
- **Segment format.** `[word position, start ms, end ms]`, in milliseconds, relative to the ayah's own file for ayah-by-ayah sets. Surah-by-surah data is keyed `surah:ayah` and carries `timestamp_from` and `timestamp_to` on the same clock: https://qul.tarteel.ai/resources/recitation/102/docs
- **Audio edition.** The docs page names no audio edition or base URL. Its example `audio_url` is `https://.../001001.mp3`. The exact recording each QUL set was aligned to is therefore not stated. It would have to be matched by comparing durations or hashes.
- **Licence.** The Licence page of resources 102 (Sudais) and 414 (Alafasy) says "We don't have copyright information for this resource.": https://qul.tarteel.ai/resources/recitation/102/licence and https://qul.tarteel.ai/resources/recitation/414/licence. The Tarteel terms page (https://www.tarteel.ai/terms) returned only its title to my fetch, so its text is not found.
- **Audio files.** Only JSON and SQLite downloads are offered; I found no audio download.
- **Reading.** QUL is good for word timing on a named reciter, but it does not name the audio, and it is an aggregator. SOURCES says an aggregator is a channel, not a source.

### 2.5 quran-align (Charles Fair)

- **Data.** Word-by-word timing JSON, one entry per ayah with `segments` as `[word_start_index, word_end_index, start_msec, end_msec]`. The end index is exclusive, a "word" is text split on spaces, and a segment can cover several words: https://github.com/cpfair/quran-align
- **Licence.** "These data files are licensed under a Creative Commons Attribution 4.0 International License." The code is MIT. The audio is not included.
- **Input.** The tool is "Designed to work with EveryAyah style audio input": the same page.
- **Editions covered.** The release notes list exactly twelve everyayah editions: https://github.com/cpfair/quran-align/releases
  - `Abdul_Basit_Mujawwad_128kbps`, `Abdul_Basit_Murattal_64kbps`
  - `Abdurrahmaan_As-Sudais_192kbps`, `Abu_Bakr_Ash-Shaatree_128kbps`
  - `Alafasy_128kbps`, `Hani_Rifai_192kbps`
  - `Husary_64kbps`, `Husary_Muallim_128kbps`
  - `Minshawy_Mujawwad_192kbps`, `Minshawy_Murattal_128kbps`
  - `Mohammad_al_Tablaway_128kbps`, `Saood_ash-Shuraym_128kbps`
- **Accuracy as stated by the author.**
  - Against ElMohafez data, word starts were on average under 73 ms off, with standard deviations averaging 139 ms across 6 recordings.
  - 98.5 to 99.9% of words were individually segmented.
  - Errors concentrate where the reciter repeated or skipped a phrase.
  - "some words may be omitted from the result sequence if their bounds could not be determined."
- **Not found.** The page says nothing about the basmala. It does not say outright whether times are relative to each ayah file; per-ayah input suggests so, and QUL's per-ayah docs say it for QUL's own sets.
- **Reading.** This is the only word timing with a free licence and an exact audio edition. The timing must be used only with the exact recording it names. A 128 kbps edition and a 64 kbps edition of the same reciter are not interchangeable until compared. The row-6 drift check is still required.

### 2.6 Others, not recommended

- **quranicaudio.com.** MP3s "may be downloaded and used for personal use free of charge"; commercial use is not allowed and "many files have rules that restrict sale to publishing companies". Some files were ripped from CDs or taken from other sites: https://www.quranicaudio.com/about. No basis for hosting or bundling.
- **Quran Foundation API and Quran.com audio.** Barred; see section 1.

## 3. Candidates (Hafs 'an 'Asim only)

All everyayah folders are per-ayah `SSSAAA.mp3` in MP3. Bit rate is the one in the folder name. I did not measure real bit rates and did not hear any audio. Style follows the provider's name.

| # | Reciter (as the provider writes it) | Style | everyayah editions (per ayah) | Islamic Network | mp3quran (per surah) | Ayah timing | Word timing, for exactly which audio |
|---|---|---|---|---|---|---|---|
| 1 | Alafasy | Murattal | `Alafasy_64kbps`, `Alafasy_128kbps` | `ar.alafasy` (listed at 128) | read 123 | Not needed per ayah; mp3quran has surah timing | quran-align: `Alafasy_128kbps` only. QUL: ayah-by-ayah and surah sets, audio unnamed |
| 2 | Husary | Murattal | `Husary_64kbps`, `Husary_128kbps` | `ar.husary` (128) | read 118 | As above | quran-align: `Husary_64kbps` only. QUL: ayah-by-ayah and surah sets, audio unnamed |
| 3 | Husary (Muallim) | Teaching, repeated; neither murattal nor mujawwad | `Husary_Muallim_128kbps` | `ar.parhizgar` is listed as "Mahmoud Khalil Al-Husary (Muallim, 64)" on the CDN page; the edition's own name is "Parhizgar" | not found | Not needed per ayah | quran-align: `Husary_Muallim_128kbps`. QUL: Muallim sets |
| 4 | Husary Mujawwad | Mujawwad | `Husary_Mujawwad_64kbps`, `Husary_128kbps_Mujawwad` | `ar.husarymujawwad` | Moshaf 119 is listed under "المصحف المجود" | Not needed per ayah | quran-align: none for these. QUL: Mujawwad ayah-by-ayah set, audio unnamed |
| 5 | Minshawy Murattal | Murattal | `Minshawy_Murattal_128kbps` | `ar.minshawi` (128) | read 112 | As above | quran-align: `Minshawy_Murattal_128kbps` |
| 6 | Minshawy Mujawwad | Mujawwad | `Minshawy_Mujawwad_64kbps`, `Minshawy_Mujawwad_192kbps` | `ar.minshawimujawwad` (64) | not found | Not needed per ayah | quran-align: `Minshawy_Mujawwad_192kbps` |
| 7 | Abdul Basit Murattal | Murattal | `Abdul_Basit_Murattal_64kbps`, `Abdul_Basit_Murattal_192kbps` | `ar.abdulbasitmurattal` (192) | read 53 | As above | quran-align: `Abdul_Basit_Murattal_64kbps` |
| 8 | Abdul Basit Mujawwad | Mujawwad | `Abdul_Basit_Mujawwad_128kbps` | `ar.abdulbasitmujawwad` (192) | The API labels reciter 51 "المصحف المجود" | Not needed per ayah | quran-align: `Abdul_Basit_Mujawwad_128kbps` |
| 9 | Abdurrahmaan As-Sudais | Murattal | `Abdurrahmaan_As-Sudais_64kbps`, `Abdurrahmaan_As-Sudais_192kbps` | `ar.abdurrahmaansudais` | read 54 | As above | quran-align: `Abdurrahmaan_As-Sudais_192kbps`. QUL: resource 102, ayah-by-ayah |
| 10 | Saood bin Ibraaheem Ash-Shuraym | Murattal | `Saood_ash-Shuraym_64kbps`, `Saood_ash-Shuraym_128kbps` | `ar.saoodshuraym` | read 31 | As above | quran-align: `Saood_ash-Shuraym_128kbps` |
| 11 | Hani Rifai | Murattal | `Hani_Rifai_64kbps`, `Hani_Rifai_192kbps` | `ar.hanirifai` | read 89 | As above | quran-align: `Hani_Rifai_192kbps` |
| 12 | Abu Bakr Ash-Shaatree | Murattal | `Abu_Bakr_Ash-Shaatree_64kbps`, `Abu_Bakr_Ash-Shaatree_128kbps` | `ar.shaatree` | read 4 | As above | quran-align: `Abu_Bakr_Ash-Shaatree_128kbps` |
| 13 | Mohammad al Tablaway | Murattal | `Mohammad_al_Tablaway_64kbps`, `Mohammad_al_Tablaway_128kbps` | not found | read 106 | As above | quran-align: `Mohammad_al_Tablaway_128kbps` |
| 14 | Maher Al Muaiqly | Murattal | `Maher_AlMuaiqly_64kbps`, `MaherAlMuaiqly128kbps` | `ar.mahermuaiqly` | Reciter 102, murattal | As above | Not in quran-align. QUL: ayah-by-ayah set, audio unnamed |
| 15 | Ghamadi (Saad al-Ghamdi) | Murattal | `Ghamadi_40kbps` only | not found | read 30 | As above | Not in quran-align. QUL: ayah-by-ayah set, audio unnamed |

Row notes:
- **Provider pages.** Rows 1 to 15 draw on https://everyayah.com/data/recitations.js, https://alquran.cloud/cdn, https://api.alquran.cloud/v1/edition?format=audio&language=ar and https://www.mp3quran.net/api/v3/reciters?language=eng&rewaya=1. For Sudais (54) and Hani Rifai (89) I fetched the reciters API directly.
- **mp3quran.** I did not verify that every `read` has timing for all 114 surahs. The "Maher, Mujawwad" label in row 14 comes from the timing-read list only.
- **Basmala and volume.** Whether each reciter's first-ayah files already carry the basmala or isti'adha is not documented anywhere I read (not found for every row). Consistency of volume between files is also not documented. Both have to be measured when the pack is built.
- **Husary 128 versus 64.** Only the 64 kbps `Husary_64kbps` has quran-align timing. The listing hints at a possible mismatch of unit: `001000.mp3` exists only in the 64 kbps folder I fetched. I did not fetch `Husary_128kbps`.
- **Hafs 'an 'Asim.** everyayah's list marks Warsh entries explicitly. The candidates above are not under those labels. Strictly, riwaya is stated outright only on mp3quran ("Rewayat Hafs A'n Assem") and QUL ("Hafs" tag). On everyayah and Islamic Network it follows from the reciter, not from a statement.

## 4. Rights position per candidate

D-012 and SOURCES row 7 say the owner holds permissions for "the recitations to be used". The Rights Register has no recitation row yet. I cannot know whose recordings his papers name, so everything below is "likely" or "not found", never "covered".

| # | Reciter | What a provider states | Asking the owner |
|---|---|---|---|
| 1 | Alafasy | Islamic Network "licensed to us by the reciters or their estates for free, non-commercial redistribution" (all Islamic Network rows share this). everyayah: nothing. QUL: "We don't have copyright information for this resource." | Is the reciter or his organisation on his papers? Host and offline need a line |
| 2 to 4 | Husary | As for row 1. Reciter deceased; estate or producer unknown: not found | Which body signed? Does it cover Murattal, Muallim and Mujawwad separately? |
| 5, 6 | Minshawy | As above | As above |
| 7, 8 | Abdul Basit | As above | As above |
| 9 to 15 | Sudais, Shuraym, Rifai, Shaatree, Tablaway, Muaiqly, Ghamdi | As above | The owner's papers decide; no new request is certain without them |

Each recitation record also needs the credit wording. Where the timing comes from the everyayah files, VerseByVerseQuran.com asks for a link-back (https://everyayah.com/data/timings_files/000_disclaimer.txt). quran-align (CC BY 4.0) needs attribution.

## 5. Risks

- **No licence text at the file sources.** everyayah and QUL give none; mp3quran gave none on the pages I read. Only the Islamic Network statement exists, and it is a statement by an intermediary.
- **Basmala (AU-24).** everyayah's `bismillah.mp3` and `audhubillah.mp3` are single files whose voice is unknown. Using them for every reciter would break AU-24. Whether the pack may list no basmala part for a recitation without one is a pack/policy question for the lead (not checked here).
- **Quality of the files.**
  - everyayah's `000_unverified_checksum.md5` and the disclaimer's "manually fixed after the files were split" suggest files may differ from the checksum list. The pipeline's per-file SHA-256 is the control.
  - Volume consistency: not found for any candidate.
  - Known error reports: none found for these editions in what I read.
- **Timing that does not fit the file.** quran-align names the exact edition; an `_128kbps` edition and a `_64kbps` edition of the same reciter may differ in encoding delay or trimming. Measure drift on a sample per recitation (row 6).
- **Word-timing edge cases.** quran-align can omit words and merge words that cannot be separated; the app must accept segments that cover several words (SY-02). For stress points, QUL's and quran-align's timings both may be inaccurate where a reciter repeats or skips phrases.
- **mp3quran.** Surah-numbering in its timing (entry 0 lead-in; 0 to 6 for surah 1) must be mapped by the pipeline and checked. Units are unstated. It has no word timing.
- **Size.** everyayah lists about 1 GB for each per-ayah zip (Alafasy 128, Husary 64). That is a rough indication of hosting size per recitation at one bit rate.

## 6. Recommendation: five recitations, two word-timed

All five come from everyayah per-ayah editions, which suits the app: one file per ayah means the player's own boundaries drive ayah highlighting with no timing data (D-112). The first two are the word-timed pair, with quran-align timing for the named edition. Only drift measurement allows the "توقيت كلمات" label (PRD §12 risk table).

| # | Recitation | Edition to use | Word timing | Reason |
|---|---|---|---|---|
| 1 (موصى به) | Alafasy, Murattal | `Alafasy_128kbps` | Yes (quran-align, same edition) | Most widely known modern recitation; exact timed edition; Islamic Network also lists it |
| 2 (موصى به) | Husary, Murattal | `Husary_64kbps` | Yes (quran-align, same edition) | Classic, clear for study and memorisation; the timed edition is already the small 64 kbps one |
| 3 | Minshawy, Murattal | `Minshawy_Murattal_128kbps` | Available (quran-align) | Murattal; timed edition exists, so it may later become a third word-timed recitation |
| 4 | Abdul Basit, Murattal | `Abdul_Basit_Murattal_64kbps` | Available (quran-align) | Murattal; small timed edition |
| 5 | Abdurrahmaan As-Sudais | `Abdurrahmaan_As-Sudais_192kbps` | Available (quran-align) | Haramain voice; timed edition. Shuraym (`Saood_ash-Shuraym_128kbps`) is the same kind of alternative. The 192 kbps size must be weighed against `_64kbps`, which is not the timed edition |

Why these five: each has a quran-align edition (no unnamed audio, free CC BY licence), each is murattal per its provider's label, and each sits on Islamic Network's statement of a non-commercial licence from the reciter or estate. A Mujawwad or Muallim recitation can be added after these five; they are in the table (rows 3, 4, 6, 8).

What I could not establish: the owner's own permissions (the papers are his), who the rights holder is for each, and what each permits on hosting, offline use and cutting. That decides which of these five stand.

## 7. What the owner must confirm or obtain, per recommended recitation

For each of the five, the same five lines apply; I list them once per reciter with the recommended option first.

**1. الأفاسي** (`Alafasy_128kbps`)
- هل إذن صاحب التسجيل مكتوب باسم المقرئ أو مؤسسته؟ (موصى به: نعم، أرفق نصه)
- هل يجيز الاستضافة على خادمك؟ (موصى به: نعم)
- هل يجيز التنزيل دون اتصال؟ (موصى به: نعم)
- هل يجيز التقطيع وإعادة الترميز وإضافة بصمة لكل ملف؟ (موصى به: نعم)
- صيغة النسبة المطلوبة: (موصى به: «تلاوة مشاري راشد العفاسي»، بصيغتك أنت)

**2. الحصري، مرتل** (`Husary_64kbps`)
- من الجهة الموقِّعة (ورثة أو جهة إنتاج)؟ (موصى به: أرفق اسمها)
- هل الإذن يشمل «المرتل» تحديدًا؟ (موصى به: نعم)
- الاستضافة والتنزيل دون اتصال والتقطيع: (موصى به: مسموح كلها)
- صيغة النسبة: (موصى به: بصيغتك أنت)

**3. المنشاوي، مرتل** (`Minshawy_Murattal_128kbps`)
- الجهة الموقِّعة: (موصى به: أرفق اسمها)
- الاستضافة والتنزيل دون اتصال والتقطيع: (موصى به: مسموح كلها)
- صيغة النسبة: (موصى به: بصيغتك أنت)

**4. عبد الباسط عبد الصمد، مرتل** (`Abdul_Basit_Murattal_64kbps`)
- الجهة الموقِّعة: (موصى به: أرفق اسمها)
- الاستضافة والتنزيل دون اتصال والتقطيع: (موصى به: مسموح كلها)
- صيغة النسبة: (موصى به: بصيغتك أنت)

**5. السديس** (`Abdurrahmaan_As-Sudais_192kbps`)
- الجهة الموقِّعة (المقرئ أو الجهة المنتجة): (موصى به: أرفق اسمها)
- الاستضافة والتنزيل دون اتصال والتقطيع: (موصى به: مسموح كلها)
- هل تقبل اعتماد نسخة 192 كيلوبت/ث لأنها النسخة الموقّتة بالكلمة، مع حجم أكبر؟ (موصى به: نعم)
- صيغة النسبة: (موصى به: بصيغتك أنت)

**For all five**
- هل تقبل أن التوقيت بالكلمة يُسمّى «توقيت كلمات» بعد قياس الانحراف لكل تلاوة فقط؟ (موصى به: نعم)
- هل تقبل نسبة التوقيت إلى quran-align (CC BY 4.0) والرابط الراجع المطلوب إلى everyayah.com في صفحة المصادر؟ (موصى به: نعم)
- إن لم تغطِّ أوراقك تلاوة من الخمس: أي بديل تفضّل من الجدول؟ (موصى به: الشريم `Saood_ash-Shuraym_128kbps`، ثم الطبلاوي `Mohammad_al_Tablaway_128kbps`، ثم هاني الرفاعي `Hani_Rifai_192kbps`)

## 8. What I could not determine

- **Terms.** The full text of the Tarteel/QUL terms (https://www.tarteel.ai/terms) and mp3quran's terms. Neither was retrievable.
- **Bit rates and sizes.** Real bit rates and per-file sizes for mp3quran, and `info.json` for the Islamic Network CDN (403).
- **Basmala, isti'adha and volume.** Whether each reciter's first-ayah files include basmala or isti'adha, and loudness consistency. Both need listening or measurement at build time.
- **Ayah numbering and units.** The numbering of surah 1 in mp3quran's timing and the units of its times, and whether a `read` id always equals the moshaf id.
- **Which recording QUL's sets use.** Not stated.
- **Which of the owner's papers cover which recitation.** Not in the repository.

## 9. What the records should hold

**`docs/PROJECT_STATUS.md`** should record:
- O-04 candidate research done (this report), awaiting the owner's choice;
- the recommended five and the alternates (Shuraym, Tablaway, Hani Rifai);
- that no rights record exists for any of them yet;
- that mp3quran has no word timing and an off-by-one lead-in entry in its timing;
- that QUL names no audio edition.

**`docs/DECISIONS.md`** should record, once the owner chooses:
- the five recitations and their edition folders;
- per-ayah units from everyayah (hosted on the owner's server, per his permission);
- the Islamic Network statement as a supporting, not sufficient, basis;
- the credit lines for quran-align (CC BY 4.0) and the everyayah timing link-back;
- the rule that a timing file is used only with its named edition, and that a different bit rate counts as a different recording until drift is measured.

**`docs/content/RIGHTS_REGISTER.md`** "Recitations" table: one row per chosen reciter, from section 7; do not fill any cell the owner has not read from his paper.

**`docs/SOURCES.md`**:
- Row 6: add that the quran-align editions are listed above, and that mp3quran is ayah level only.
- Row 7: nothing changes until a rights record is complete.
