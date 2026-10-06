# Zaydi Library (المكتبة الزيدية) content

The owner chose <https://ziydia.com> as the source of tafsir and reference books
(PRD §5.5, §8.8, decision of 2026-10-06). This file records what the site holds, what
has been extracted, how the extracted data is shaped, and what must happen before any
of it is shown in the app.

## Permission and method

- The site owner gave the product owner written, signed permission covering
  everything published on the site, including the contemporary works (owner's
  statement, 2026-10-07). The signed paper is kept by the product owner and is the
  reference for the in-app sources page.
- The site owner declined to hand over the database and said to take the text from
  the website. Extraction is done by the product owner, on his own computer, with
  `tools/ziydia/ziydia_fetch.py`: one request every 3 seconds, resumable, standard
  library only.
- The planning session never opened the site itself. Everything below comes from the
  files that tool produced and the owner uploaded on 2026-10-06.
- Raw extraction output is **not** in this repository. It stays on the owner's
  computer (`ziydia_out/`) until a verified content pack is built from it.

## What the site holds

604 books by 294 authors in 15 categories. The category used here is
«التفسير وعلوم القرآن» (id 5): 39 books. Other categories of possible later use:
«المعاجم» (id 19, 17 books), «النحو والصرف» (id 15, 46), «البلاغة» (id 18, 21).

Of the 39 books: **27 have extractable text**, **7 are scanned PDFs with no text** and
are excluded (text recognition on religious text would introduce errors; decision
D-019), and **5 have not been fetched yet**. Those five are contemporary works that
the tool leaves out unless `--include-skipped` is given; the owner confirmed that the
permission covers them (D-012).

## The 39 books

Site pages is the highest page number in the site's own table of contents; it is an
estimate until the book is fully extracted. Publisher and edition are quoted as the
site prints them.

| ID | Title | Author | d. (AH) | Form | Site pages | Parts | Publisher, edition | Plan |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 74 | زبر من الفوائد القرآنية ونوادر من الفرائد والفرائد القرآنية | السيد العلامة محمد بن عبد الله عوض المؤيدي | contemporary | not fetched | | | | Not fetched yet; format unknown |
| 102 | محاضرات رمضانية في تقريب معاني الآيات القرآنية | السيد العلامة محمد بن عبد الله عوض المؤيدي | contemporary | not fetched | | | | Not fetched yet; format unknown |
| 108 | الفقه القرآني | السيد العلامة محمد بن عبد الله عوض المؤيدي | contemporary | not fetched | | | | Not fetched yet; format unknown |
| 165 | الناسخ والمنسوخ من القرآن الكريم | الإمام المجتهد عبد الله بن الحسين الرسي | 300 | text | 151 | 1 | مؤسسة الإمام زيد بن علي الثقافية، الأولى، 1442 هـ - 2002 م | First release |
| 182 | تفسير الثمرات اليانعة | القاضي العلامة يوسف بن أحمد الثلائي | 832 | text | 2635 | 5 | مكتبة التراث الإسلامي، الأولى، 1423 هـ - 2002 م | Second wave |
| 183 | تفسير غريب القرآن للإمام زيد | الإمام الأعظم زيد بن علي بن الحسين | 122 | text | 343 | 1 | الدار العالمية، الأولى، 1412 هـ - 1992 م | First release |
| 190 | الكشاف عن حقائق غوامض التنزيل | العلامة المفسر محمود بن عمر الزمخشري | 538 | text | 2890 | 1 | دار الكتاب العربي - بيروت، الثالثة، 1407 هـ | Not planned (general classics, not needed for release 1) |
| 202 | إعراب القرآن للنحاس | العلامة النحوي أبو جعفر النحاس | 338 | text | 1427 | 5 | دار الكتب العلمية، الثانية، 1425 هـ - 2004 م | Not planned (general classics, not needed for release 1) |
| 204 | إعراب القرآن وبيانه | الأستاذ محيي الدين درويش | 1403 | not fetched | | | | Not fetched yet; format unknown. Candidate for full-ayah i'rab (LX-04) |
| 208 | تفسير وبيان لبعض آيات القرآن | القاضي العلامة عبد الرحيم بن محمد المتميز | contemporary | text | 1614 | 3 | الأولى، 1438 هـ - 2017 م | Later |
| 222 | البرهان في تفسير القرآن | الإمام أبو الفتح الناصر بن الحسين بن محمد الديلمي | 444 | text | 927 | 1 | not stated | Second wave |
| 271 | التمهيد في أحكام التجويد | مكتبة أهل البيت | contemporary | text | 60 | 1 | مكتبة أهل البيت (ع)، الثانية، 1437 هـ | Candidate text for tajweed lessons (TJ-07) |
| 276 | التبيان في الناسخ والمنسوخ في القرآن المجيد | القاضي العلامة عبدالله بن محمد بن أبي النجم | 647 | text | 135 | 1 | مؤسسة التاريخ العربي، الأولى، 1429 هـ - 2008 م | First release |
| 306 | تنبيه الغافلين عن فضائل الطالبيين | الحاكم الجشمي المحسن بن محمد بن كرامة | 494 | text | 240 | 1 | مكتبة أهل البيت (ع)، الأولى، 1421 هـ، 2000 م | Outside the app's subject |
| 314 | النور الساطع في الليل البهيم من تفسير القرآن الكريم | السيد العلامة علي بن محمد الرسي | 500 | text | 604 | 1 | not stated | Second wave |
| 315 | تفسير الحبري | العلامة المفسر الحسين بن الحكم الحبري | 286 | text | 537 | 1 | مؤسسة آل البيت (ع) لإحياء التراث، الثانية، 1408 هـ | Reference only; the religious reviewer decides |
| 316 | تنزيه القرآن عن المطاعن | قاضي القضاة عبد الجبار ابن أحمد الهمذاني | 415 | text | 491 | 1 | دار النهضة الحديثة، الثانية 1426 ه‍ - 2005 م | Later |
| 317 | شواهد التنزيل لقواعد التفضيل | الحاكم الحسكاني عبيد الله بن عبد الله بن أحمد | 481 | text | 1084 | 3 | مجمع احياء الثقافة الإسلامية، الأولى، 1411 هـ - 1990 م | Reference only; the religious reviewer decides |
| 318 | متشابه القرآن للقاضي عبدالجبار | قاضي القضاة عبد الجبار ابن أحمد الهمذاني | 415 | text | 809 | 1 | مكتبة دار التراث - مصر - قاهره، الأولى، 1969 م | Later |
| 421 | معاني القرآن | العلامة النحوي يحيى بن زياد الفراء | 207 | text | 1259 | 3 | الهيئة المصرية العامة للكتاب - مصر - قاهره، الثانية، 1980 م | Not planned (general classics, not needed for release 1) |
| 425 | الجدول في إعراب القرآن الكريم | الأستاذ محمود صافي | 1376 | not fetched | | | | Not fetched yet; format unknown. Candidate for full-ayah i'rab (LX-04) |
| 440 | مسائل نافع بن الأزرق | حبر الأمة ابن عباس | 68 | text | 165 | 1 | مكتبة التراث الإسلامي، الأولى، 1423 هـ - 2002 م | First release |
| 454 | تفسير القاضي عبد الجبار | قاضي القضاة عبد الجبار ابن أحمد الهمذاني | 415 | text | 369 | 1 | دار الكتب العلمية، الأولى، 2009 م | Later |
| 466 | التهذيب في التفسير (تفسير الحاكم) | الحاكم الجشمي المحسن بن محمد بن كرامة | 494 | text | 7325 | 10 | دار الكتاب المصري - القاهرة، دار الكتاب اللبناني - بيروت، الأولى، 1440 هـ - 2019 م | Second wave |
| 471 | تفسير الإمام الهادي يحيى بن الحسين (ع) | الإمام الهادي إلى الحق المبين يحيى بن الحسين بن القاسم | 298 | text | 596 | 2 | المحقق، الأولى، 1433 هـ - 2012 م | First release |
| 473 | تفسير الإمام المهدي العياني المسمى (تفسير غريب القرآن) | الإمام المهدي الحسين بن القاسم العياني | 404 | text | 823 | 2 | منشورات مركز الإمام المنصور بالله (ع)، الثانية، 1442 هـ - 2021 م | First release |
| 514 | التيسير في التفسير | السيد العلامة بدر الدين بن أمير الدين | 1431 | text | 4093 | 7 | مؤسسة المصطفى صلى الله عليه وآله وسلم الثقافية، الأولى، 1434 هـ - 2013 م | First release |
| 527 | المصابيح الساطعة الأنوار تفسير أهل البيت (ع) | السيد العلامة عبدالله بن أحمد الشرفي | 1062 | PDF only |  | 4 | منشورات مكتبة التراث الإسلامي، الأولى، 1424هـ - 2003م | Excluded: scanned PDF, no text |
| 531 | شافي العليل في شرح الخمسمائة آية من التنزيل | القاضي العلامة عبد الله بن محمد النجري | 877 | PDF only |  | 1 | مكتبة الجيل الجديد صنعاء - مؤسسة الكتب الثقافية بيروت، الأولى، 1406هـ - 1986م | Excluded: scanned PDF, no text |
| 555 | التبيان في الناسخ والمنسوخ ط بدر | القاضي العلامة عبدالله بن محمد بن أبي النجم | 647 | PDF only |  | 1 | مطبوعات مركز بدر العلمي والثقافي، الأولى، 1420 هـ - 1999 م | Excluded: scanned PDF, no text |
| 566 | مفتاح السعادة | السيد العلامة علي بن محمد العجري | 1407 | text | 3782 | 6 | مؤسسة الإمام زيد بن علي الثقافية، الأولى، 1424 هـ - 2003 م | Later |
| 567 | تفسير جزء عم وجزء تبارك | القاضي العلامة صلاح بن أحمد فليته | 1429 | text | 156 | 1 | مكتبة التراث الإسلامي، الأولى، 1424 هـ - 2003 م | Later |
| 609 | منتهى المرام شرح آيات الأحكام | السيد العلامة محمد بن الحسين بن القاسم | 1067 | PDF only |  | 1 | المطبعة الأميرية بصنعاء، الأولى، 1357 هـ | Excluded: scanned PDF, no text |
| 617 | تفسير مختصر فاتحة الكتاب | القاضي العلامة محمد بن عبدالله المهاجر | 1414 | PDF only |  | 1 | المؤلف، بدون | Excluded: scanned PDF, no text |
| 638 | تفسير فرات الكوفي | المحدث المفسر فرات بن إبراهيم الكوفي | 300 | text | 557 | 1 | مؤسسة الطبع والنشر، الأولى، 1410 هـ | Reference only; the religious reviewer decides |
| 737 | شافي العليل في شرح الخمسمائة آية من التنزيل | القاضي العلامة عبد الله بن محمد النجري | 877 | text | 356 | 1 | not stated | First release |
| 755 | المختار من كتاب الروضة والغدير | السيد العلامة محمد بن الهادي بن تاج الدين | 720 | text | 814 | 2 | مكتبة أهل البيت (ع)، الأولى، 1446 هـ 2024 م | Second wave |
| 756 | القراءات السبع المسمى الفتح الرباني في تشجير وتوضيح حرز الأماني | السيد العلامة عبد العظيم قاسم العزي | contemporary | PDF only |  | 1 | مكتبة أهل البيت (ع)، الأولى، 1446 هـ - 2024 م | Excluded: scanned PDF, no text |
| 841 | حقائق التأويل في متشابه التنزيل | الشريف الرضي محمد بن الحسين بن موسى | 406 | PDF only |  | 1 | دار الأضواء، الأولى، 1406 هـ - 1986 م | Excluded: scanned PDF, no text |

Notes on the table:

- 531 and 737 are the same work; only 737 has text. 276 and 555 are the same work;
  only 276 has text.
- Book 165: the site prints the edition as «1442 هـ - 2002 م»; the two years do not
  agree, so check the printed copy before citing the year.
- Book 183 is fully extracted: 339 pages saved, site page numbers 1–343.

## First release (candidates)

Eight books, chosen for being by Zaydi imams and scholars, concise, ordered by surah
and easy to link to an ayah. The list was shown to the owner on 2026-10-06; he added
«التيسير في التفسير». It becomes final book by book, as each one passes the checks in
"Before a book is shown".

| ID | Book | Serves | Extraction |
| --- | --- | --- | --- |
| 183 | تفسير غريب القرآن — الإمام زيد بن علي | Word meanings (LX-06) | Complete, checked |
| 471 | تفسير الإمام الهادي يحيى بن الحسين | Tafsir (TF) | Pending |
| 473 | تفسير غريب القرآن — الإمام المهدي العياني | Word meanings and tafsir | Pending |
| 514 | التيسير في التفسير — بدر الدين بن أمير الدين | Tafsir (TF) | Pending |
| 737 | شافي العليل في شرح الخمسمائة آية | Ayat al-ahkam | Pending |
| 165 | الناسخ والمنسوخ من القرآن الكريم — عبد الله بن الحسين الرسي | Abrogation | Pending |
| 276 | التبيان في الناسخ والمنسوخ — ابن أبي النجم | Abrogation | Pending |
| 440 | مسائل نافع بن الأزرق | Rare words with poetic evidence | Pending |

In Phase 1 every approved book is offered as a tafsir pack read by ayah
(`TF-01`…`TF-08`): its passage where it has one, and the fixed sentence of the `TF`
acceptance criteria where it has none. The further uses named in the Serves column
come when the PRD phases them: word meanings in the word sheet with `LX-06` and asbab
al-nuzul with `TF-09`, both in Phase 2. The tafsir milestone M1.7 therefore needs
task B0.6 as well as B0.7.

The seven pending books are about 6,300 site pages, roughly six hours of extraction:

```
py ziydia_fetch.py books 471 473 737 165 276 440 514
py ziydia_fetch.py pack
```

Open question for the owner: do the seven general tafsirs listed in PRD §8.8
(الميسر، المختصر، السعدي، الجلالين، البغوي، ابن كثير، الطبري) stay alongside these?

## Asbab al-nuzul

The category has no standalone asbab al-nuzul book. The candidate source is
«التهذيب في التفسير» (466): 7,325 site pages in 10 parts, about seven hours of
extraction.

Checked on the 30 pages already extracted (2026-10-07): the book treats each group of
ayat under fixed sub-headings, each written as a dark-red middle dot, the heading
word and a colon:

`<span style="color: #800000;">·</span> النزول:` and likewise «القراءة»، «اللغة»،
«الإعراب»، «النظم»، «المعنى»، «الأحكام».

Counts in those 30 pages: المعنى 8, اللغة 7, الإعراب 7, الأحكام 7, القراءة 6,
النزول 2, النظم 1. So the nuzul passage can be isolated mechanically, without
interpretation, and the same book can later feed the readings, language, i'rab,
meaning and rulings sections of the study hub from one classical source. This holds
for the sample only; confirm it on the whole book after extraction, and stop the
build on any passage whose sub-heading is not one of the seven.

Books 315, 317 and 638 collect reports on verses concerning Ahl al-Bayt; they are not
general asbab al-nuzul.

## Site structure (as observed)

| Thing | Shape |
| --- | --- |
| Book page | `/book/{id}` — JSON-LD with name, author, genre, date added; a card with publisher, edition, page count |
| Reader | `/book/{id}/read` redirects to `/book/{id}/page/1` (or `/page/1/{part}`) |
| A page | `/book/{id}/page/{n}/{part}`; `n` appears to run on across parts (the contents of the 10-part book 466 reach 7325) — confirm on the first multi-part extraction |
| Start of a part | `/book/{id}/p/0/{part}` |
| Text | `<div id="bookContent" class="reader-text book-content">` |
| Chapter title | `.reader-chapter__title` |
| Printed page label | `.reader-chapter__meta` — «صفحة 76» or «الجزء 1 · صفحة 199» |
| Next page | `<a class="reader-pager__btn">` whose label is «التالية» |
| Table of contents | links `/book/{id}/title/{n}`, where `n` is the site page the chapter starts on |
| Category list | `/categories/{id}?page={k}`, 12 books a page |

The site is behind Cloudflare and drops connections from time to time; the tool
retries with back-off and resumes from its saved state.

## Extracted data format

`ziydia_out/` after a run:

```
books_index.csv                 id, category, label, skipped_by_default
_raw/                           raw category pages and the terms page
book_<id>/
  meta.json                     id, url, title, author, category, date_added, author_id,
                                author_line, category_id, card[{label, value}]
  toc.json                      [{n, label, href}] — n is the site page number
  pages.jsonl                   one JSON object per page, in reading order
  state.json                    resume state; "done": true when the book is complete
  first_reader_page.html        raw HTML of the first page, for inspection
```

One line of `pages.jsonl`:

| Field | Meaning |
| --- | --- |
| `book` | Site book id |
| `seq` | 1-based order in which the page was read |
| `part` | Volume number |
| `url_page` | Site page number (continuous across parts) |
| `page_label` | Printed page label as shown, e.g. «صفحة 76» |
| `chapter` | Chapter title shown above the page |
| `url` | Page URL |
| `html` | Inner HTML of the text block as served. Only two things are done to it: UTF-8 decoding with invalid bytes replaced by U+FFFD, and removal of white space around the whole block |
| `text` | A plain-text rendering for inspection: tags removed, entities decoded, no-break spaces turned into spaces, runs of spaces collapsed, lines trimmed, empty lines dropped |

Content is built from `html` only. `text` loses markup that carries meaning and
changes spacing; it is for reading and searching by eye. A page whose `html` contains
U+FFFD is fetched again before use.

Markup inside `html` that carries meaning:

- `<span style="color: #00AA00;font-family: Ziydia-Q;">…</span>` — a Quran quotation
  inside the commentary.
- U+2063 (invisible separator) followed by `[٢٥]` — the ayah number of the quotation
  just before it (ranges appear as `[٤ - ٥]`).
- `<span style="font-family:Ziydia-Bold">` — emphasised lead-in words (وقوله تعالى:، قلنا:، ويقال:).
- `<p class="border-r-4 px-2" style="…font-family:Ziydia-Bold;color: #800000;">` — a
  chapter heading inside the text. In book 183 there are 114, each written
  «(٢) سورة البقرة» with the surah number in parentheses.
- `<span style="color: #800000;">·</span>` followed by a word and a colon — a
  sub-heading (book 466; see "Asbab al-nuzul").
- `<span style="font-size: 0.8em;">` — the bracketed ayah numbers.

A typical line in book 183:

```html
<p style="margin-top:1px;margin-bottom:1px">&nbsp&nbsp<span style="font-family:Ziydia-Bold">وقوله تعالى:</span>
{<span style="color: #00AA00;font-family: Ziydia-Q;">…</span>}⁣<span style="font-size: 0.8em;">[٢٥]</span> …</p>
```

(the Quran words are replaced by `…` here on purpose; this repository never carries
typed Quran text).

## Known issues to resolve before use

1. **Honorific glyph codes.** The site's font draws honorific phrases from single
   characters. Eight were seen in book 183: `@` (264 times, almost always after
   «زيد بن علي»), `#` (43), `÷` (35, after the Prophet's name), `ø` (16, after the
   name of God), `$` (14), `~` (7), `&` (2), `|` (2). `*` is an ordinary section
   separator. The meaning of each code must come from the site owner or be confirmed
   by the religious reviewer; some follow singular, dual and plural names, so
   context alone is not enough. Until the table is approved, no book is shown.
2. **Quran quotations inside commentary.** They are part of the book's text, written
   in the book's own orthography. Per `TF-08` they are displayed in the UI font as
   part of the source and are never treated as reference Quran text. The reference
   text shown above a commentary always comes from the Quran pack by address.
3. **Missing pages.** Editors' introductions are not published on the site (book 183
   jumps from printed page 3 to 76). In book 183 two single printed pages are absent
   (178 and 314); compare with the printed copy.
4. **Multi-part navigation** in the tool is untested until book 471 or 473 (two
   parts each) is extracted.
5. **Printed-edition rights.** Every book is a modern critical edition or a
   contemporary work. The basis for use is the site owner's signed permission held by
   the product owner; publisher, edition and editor are shown in the source badge and
   on the sources page.

## Linking commentary to ayat

For book 183 the link is mechanical: each in-text chapter heading carries the surah
number (114 headings, الفاتحة to الناس) and each quotation is followed by its ayah
number (2,863 positions). The linker reads the `html` field and must:

1. Take the surah number from the numeral in the chapter heading, and check the name
   against the surah names of the base pack; never fuzzy-match names.
2. Read ayah numbers only from the bracketed numerals after U+2063.
3. Emit segments `(book, surah, from_ayah, to_ayah, text, printed_page)`; a passage
   that covers several ayat is one segment with a range (`TF-04`).
4. Stop the build on any chapter title or number it cannot resolve. No guessing.
5. Produce a report the religious reviewer signs for a sample.

Each other book needs its own inspection first; structure differs between books.

## Before a book is shown in the app

1. Extraction complete (`state.json` says `done`) and page sequence checked for gaps.
2. Honorific table approved and applied by a pipeline step that is itself tested.
3. Ayah linking built and a sample reviewed by the religious reviewer.
4. Pack manifest filled in: source, edition, permission reference, trust grade,
   SHA-256, counts, reviewer and date (PRD §9.2).
5. The book's row in `docs/content/RIGHTS_REGISTER.md` is `Complete`: credit line with
   publisher, edition and editor, and the conditions of the site-wide permission.

The source as a whole is already `Ready` in `docs/SOURCES.md` (row 18); these steps
clear one book.
