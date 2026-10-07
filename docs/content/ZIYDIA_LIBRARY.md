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

| ID | Book | Serves | Extraction | Linking to ayat |
| --- | --- | --- | --- | --- |
| 183 | تفسير غريب القرآن — الإمام زيد بن علي | Word meanings (LX-06) | Complete, checked | Linked by the tool; not reviewed |
| 471 | تفسير الإمام الهادي يحيى بن الحسين | Tafsir (TF) | Complete, checked | Partly linked by the tool; not reviewed |
| 473 | تفسير غريب القرآن — الإمام المهدي العياني | Word meanings and tafsir | Complete, checked | Not started; inspected |
| 514 | التيسير في التفسير — بدر الدين بن أمير الدين | Tafsir (TF) | Complete, checked | Linked by the tool; not reviewed |
| 737 | شافي العليل في شرح الخمسمائة آية | Ayat al-ahkam | Complete, checked | Not started; inspected |
| 165 | الناسخ والمنسوخ من القرآن الكريم — عبد الله بن الحسين الرسي | Abrogation | Complete, checked | Not started; inspected |
| 276 | التبيان في الناسخ والمنسوخ — ابن أبي النجم | Abrogation | Complete, checked | Partly linked by the tool; not reviewed |
| 440 | مسائل نافع بن الأزرق | Rare words with poetic evidence | Complete, checked | Not started; inspected |

In Phase 1 every approved book is offered as a tafsir pack read by ayah
(`TF-01`…`TF-08`): its passage where it has one, and the fixed sentence of the `TF`
acceptance criteria where it has none. The further uses named in the Serves column
come when the PRD phases them: word meanings in the word sheet with `LX-06` and asbab
al-nuzul with `TF-09`, both in Phase 2. The tafsir milestone M1.7 therefore needs
task B0.6 as well as B0.7.

### Extraction results

The owner extracted the seven remaining books on 2026-10-07; the planning session
checked the upload the same day. All eight first-release books are now complete.

| ID | Pages saved | Parts | Printed pages covered | Printed pages the site does not carry | Ayah numbers after quotations |
| --- | --- | --- | --- | --- | --- |
| 183 | 339 | 1 | 3, then 76 onwards | The editor's introduction; two single pages (178, 314) | 2,863 |
| 471 | 596 | 2 | Part 1: 1, then 121–452. Part 2: 7–459 | The editor's introduction (2–120); 2 or 3 pages at the end of most surahs | 610 |
| 473 | 836 | 2 | Part 1: 3–558. Part 2: 5–296 | Pages 83–91 (the manuscript plates); 4 single pages | 114 |
| 514 | 3,908 | 7 | Part 1: 1, then 23–609. Parts 2–7 from page 3 | Pages 2–22 of part 1; about 165 single pages across the parts | 3,829 |
| 737 | 350 | 1 | 1–356 | 6 single pages | None |
| 165 | 162 | 2 | 3–171 | Pages 34–38 (the manuscript plates); 2 single pages | 156 |
| 276 | 135 | 1 | 1, then 33–166 | The editor's introduction (2–32) | 211 |
| 440 | 163 | 1 | 3–167 | 2 single pages | 1 |

What the checks covered, for each book: `state.json` says done; page records run
1, 2, 3… with no repeat; site page numbers only increase; printed page numbers only
increase within a part; no page has empty text; no page holds U+FFFD.

What they show:

- **Nothing was lost in fetching.** The tool follows the site's own "next" link, so a
  site page number that is skipped is one the site does not have.
- **Skipped printed pages** fall where a printed book has blank or picture pages:
  after the short last page of a chapter, at part title pages, and at the plates of
  manuscripts. The longer runs at the start are the editors' introductions, which the
  site does not publish. This reading comes from the pattern, not from the printed
  copies; the reviewer confirms it on a sample when each book is reviewed.
- **Book 473 runs backwards through the mushaf**: it begins with the last parts of
  the Quran and ends with سورة البقرة, as its table of contents shows.
- **Book 737 has no ayah numbers** after its quotations, and book 440 has one. They
  cannot be linked the way book 183 is; see "Linking commentary to ayat".
- The last column counts bracketed references. For book 183 it gives those that hold
  one number; the book has 2,901 in all: those 2,863, 37 ranges and one that is not a
  number. For the other books it counts every reference, ranges included. Most of
  the references in books 514, 471 and 276 cite other ayat as evidence; they are not
  what links a passage.

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
| A page | `/book/{id}/page/{n}/{part}`; `n` runs on across parts, with numbers skipped where the site has no page (confirmed on books 165, 471, 473 and 514) |
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
- `<span style="font-size: 0.8em;">` — the bracketed ayah numbers. In books 276, 471
  and 514 the bracket names the surah as well: `[البقرة: ١٩٠]`.
- `<span style="color: #be0000;">` at the start of a paragraph — the number of an item
  (`[١٠]` in book 276, `٣٤٨ -` in book 471) or, in book 514, the ayah number that
  opens a commentary paragraph (`(٢٧٥)`). A range in book 514 is written without the
  span: `(١١ - ١٢)`.
- A paragraph of dashes (33 or 31 in the book; the tool takes 20 or more) — in book
  514 only, the rule between the text
  of the surah at the top of a page and the commentary below it.

A typical line in book 183:

```html
<p style="margin-top:1px;margin-bottom:1px">&nbsp&nbsp<span style="font-family:Ziydia-Bold">وقوله تعالى:</span>
{<span style="color: #00AA00;font-family: Ziydia-Q;">…</span>}⁣<span style="font-size: 0.8em;">[٢٥]</span> …</p>
```

(the Quran words are replaced by `…` here on purpose; this repository never carries
typed Quran text).

## Known issues to resolve before use

1. **Honorific glyph codes.** The site's font draws honorific phrases from single
   characters, each wrapped in its own span: `<span style="color: #800000;">X</span>`.
   Counted by that markup over the eight first-release books there are **sixteen**
   codes (the count of eleven given earlier came from looking at characters, and
   missed five):

   | Code | Unicode | Times | Books |
   | --- | --- | --- | --- |
   | `÷` | U+00F7 | 2,807 | all eight |
   | `#` | U+0023 | 2,573 | all eight |
   | `ø` | U+00F8 | 1,671 | all eight |
   | `@` | U+0040 | 686 | 183, 471, 473, 514, 737, 276 |
   | `~` | U+007E | 399 | all but 737 |
   | `$` | U+0024 | 280 | all but 440 |
   | the vertical line | U+007C | 151 | 183, 473, 514, 165, 276, 440 |
   | `ª` | U+00AA | 108 | 471, 473, 165 |
   | `À` | U+00C0 | 75 | 183, 471, 473, 514, 737, 165 |
   | `¥` | U+00A5 | 46 | all but 183 |
   | `®` | U+00AE | 19 | 514, 165, 440 |
   | `&` | U+0026 | 17 | all but 440 |
   | `¤` | U+00A4 | 8 | 473, 514, 276, 440 |
   | `¦` | U+00A6 | 7 | 473, 514, 165, 276 |
   | `^` | U+005E | 4 | 737 |
   | `¿` | U+00BF | 2 | 514 |

   The same span also wraps three real Unicode ligatures, which need no table:
   U+FDFD (146 times), U+FDFB (75) and U+FDFA (11); and a middle dot that marks a
   sub-heading (book 737, as in book 466). `*` is an ordinary section separator.
   `tools/ziydia/ziydia_link.py inspect <id>` prints the codes of any book. The
   meaning of each code must come from the site owner or be confirmed by the
   religious reviewer; some follow singular, dual and plural names, so context alone
   is not enough. Until the table is approved, no book is shown.
2. **Quran quotations inside commentary.** They are part of the book's text, written
   in the book's own orthography. Per `TF-08` they are displayed in the UI font as
   part of the source and are never treated as reference Quran text. The reference
   text shown above a commentary always comes from the Quran pack by address.
3. **Missing pages.** Editors' introductions are not published on the site (book 183
   jumps from printed page 3 to 76). In book 183 two single printed pages are absent
   (178 and 314); compare with the printed copy.
4. **The `part` field at a part boundary.** Multi-part navigation works (books 165,
   471, 473 and the seven-part 514). The `part` field of a record is one page late
   at each boundary: the first page of a new part still carries the old part's
   number. `page_label` is right; take the part from it.
5. **Printed-edition rights.** Every book is a modern critical edition or a
   contemporary work. The basis for use is the site owner's signed permission held by
   the product owner; publisher, edition and editor are shown in the source badge and
   on the sources page.

## Linking commentary to ayat

`tools/ziydia/ziydia_link.py` links the paragraphs of an extracted book to ayat
(decision D-081). Its rules:

1. A link rests only on what the book prints: a surah heading, an ayah number in
   brackets after a quotation, a number that opens a commentary paragraph. The wording
   of a quotation never makes a link.
2. No printed number is corrected. A number that looks wrong is kept and the passage
   is flagged for a person to check.
3. Every paragraph goes into the output exactly as it stands in `html`, and the tool
   proves it: the paragraphs it wrote equal the paragraphs it read. The only ones left
   out are the rules of dashes of book 514, which are counted.
4. A surprise in the structure stops the run: text outside paragraphs, a page label
   that cannot be read, and in books 183 and 514 a surah heading that cannot be read
   or is out of place. In books 276 and 471, where many headings are not surah
   headings, one that cannot be read is noted and gives no surah.
5. Each book has a profile that says how it prints its links. A book without one is
   not linked.

The output (`ziydia_links/`, outside Git like the extraction itself) is one passage
per line in `passages.jsonl`: kind, surah, ayah ranges, what the link rests on, review
flags, and the paragraphs with their site page, part and printed page. `report.json`
holds the counts and every note; `sample.html` is a fixed sample for the reviewer and
`review.html` lists every flagged passage. Commands are in `tools/ziydia/README.md`.

### The check against the printed text

Book 514 prints the whole text of the Quran, surah by surah, with its ayah numbers.
`compare` uses it to test the links of every book: is the quotation a link rests on
found in the ayat it is linked to? It compares letters only, and writes no text of
its own: `compare.json` holds numbers, and `compare.html` shows the passages it lists
as the book prints them. It is a check, never a way of making a link, and it changes
none (D-082). Outcomes: found; found when the spelling of alif, waw, ya, hamza and ta
is ignored (the books and the text of 514 do not always spell alike); too short to
compare; not found there. For those not found it says whether the words stand at
another ayah of the same surah, which is how a misprinted number shows itself.

What it reads: in book 183 every quotation that a number follows; in book 514 the
first quotation of the paragraph that opens a passage; in books 276 and 471 every
quotation of the item up to its first reference. It does not read the paragraphs
carried after the opening one. A quotation with fewer than four letters, once the
letters above are set aside, is not compared.

The text of book 514 is itself an extraction, not the reference text. When the base
pack exists (B0.2) the same check is run against it.

### Results, 2026-10-07

Run on the extraction of 2026-10-06 and 2026-10-07.

| Book | How it prints its links | Linked passages | Flagged by the linker | Confirmed by the text of 514 | Not compared | Not confirmed |
| --- | --- | --- | --- | --- | --- | --- |
| 183 | Heading with the surah number; `[N]` after a quotation | 2,721 | 166 | 2,647 | 66 too short | 8 |
| 514 | Text above a rule, commentary below; a paragraph opens with `(N)` | 5,488 | 12 | 5,306 | 151 too short; 2 whose printed range is not a range | 29 |
| 276 | Numbered items; `[surah: N]` after the item's quotation | 123 of 146 items | 3 | 116 | 1 without a quotation | 6 |
| 471 | Numbered questions; `[surah: N]` after the question's quotation | 302 of 361 items | 15 | 291 | 1 too short; 1 without a quotation | 9 |

SHA-256 of each `passages.jsonl`, so that a later run on the same extraction can be
compared with this one:

| Book | `passages.jsonl` |
| --- | --- |
| 183 | `cba1f8d987d738c157d100d48f33103b50fc94fe9cdae532e980ede80a07d2df` |
| 514 | `e9d7ec08492ae002c69871591f0922c6a3dc4477d90580e41f4329f568bbc37b` |
| 276 | `92e6a1f68a512b2b5947aa2485d08d4c930ad5bc32e92efc556f7e8c912d2f0b` |
| 471 | `d0638a75f5d3b7b2fa89463d0806d2d34000fc0be7405bb1456c90726aa300d4` |

**What an independent check covered.** A reviewing agent wrote its own parsing code,
applied the rules above to every paragraph of the four books, and found no difference
from the tool's output in kind, surah, ayah ranges, basis, carried mark or review
flags; it found the output paragraphs equal to the input paragraphs page by page,
apart from the 3,780 rules of book 514; and it reproduced
the comparison with ayah texts it assembled separately. That shows the tool does
what its rules say. It does not show that the rules give the right ayah: only the
comparison and the reviewer speak to that. It also measured how often a confirmed
quotation matches ayat it is not linked to: under 0.1% in book 183 and about 0.3% in
book 514. Its findings on the tool were applied in two rounds; it then verified every
figure in this section on the final output, whose SHA-256 values are the four above.
Nothing has been compared with a printed copy.

**Book 183.** 114 headings numbered 1 to 114. A paragraph with a bracketed number is
a passage; 152 paragraphs carry more than one number and keep them all. 32 paragraphs
without a number continue the passage before them. 23 paragraphs quote something of
their own and print no number for it; each starts a passage linked to the surah only.
107 lines of asterisks are kept apart. The 166 flags are ayah numbers out of order;
the text confirms 155 of them, so order alone is a weak sign in this book. The
comparison is what finds numbers that look wrong: 5 passages quote words that stand
at another ayah of the same surah in the text of book 514, in each case one digit
away from the printed number.

**Book 514.** Each page prints the text of the surah, a rule, then the commentary.
Every surah starts on a new page after a page that holds its title; all 114 headings
are the first paragraph of their page. The surah number is the order of the heading.
Two things support it: for the 102 surahs that books 183 and 514 name alike, the
order agrees with the number book 183 prints (for the other 12 nothing is checked);
and the last ayah number printed in each surah sums to 6,236 over the book. 112
surahs open with one and the same unnumbered line; surahs 1 and 9 do not. A
commentary paragraph that opens with a number starts the commentary on those ayat,
and the 10,960 unnumbered paragraphs after such paragraphs are carried with them. In
106 surahs every ayah is opened by a number. In the other 8, 13 ayat are not: 4 have
no number anywhere, 5 lie under the two ranges printed backwards, and 4 lie behind
numbers that the comparison finds one digit off. The passage before each gap is
flagged, because its unnumbered paragraphs may belong to those ayat. Commentary
before the first number of a surah (35 surahs) is linked to the surah only. Among the
29 not confirmed are those 4 numbers, which the linker had already flagged, one
quotation found in the ayah next to its own, and 24 whose quotation is found nowhere
in the surah as worded. In 19 of the 24 nine tenths
of the quotation's letters do stand, in order, in the ayat it is linked to: the
wording differs slightly from the text printed above the rule. The religious
reviewer says why, and what the app shows when a commentary quotes an ayah otherwise
than the text above it.

**Books 276 and 471.** An item is linked by the first reference of its own paragraph,
and the paragraphs up to the next item or heading go with it. A link rests on two statements
when the reference names the surah of the heading above it (117 items in 276, 297 in
471), and on the reference alone otherwise. The other items have no ayah: items
without a reference (21 and 46), references in a form the tool does not read (0 and
7), and surah names that are not in the table, which are never guessed (2 and 6; all
are misprints as far as seen). Of these, 10
in 276 and 54 in 471 stay linked to the surah of their heading; 13 and 5 have no
surah either. A paragraph carried after an item that opens with a quotation and a
reference of its own flags the item (3 in 276, 10 in 471), since it may be a unit the
book did not number. In book 471, 1,042 paragraphs are linked to a surah only; 622
of them are the running commentary on the surahs of the last parts (site pages 424
to 591), which is mostly not written as numbered questions. Book 276 opens with
chapters on abrogation that belong to no surah.

Surah names are looked up in a table built by `names` from the headings of books 183
and 514. The lookup ignores vowel marks, tatweel, the form of alif and a pair of
parentheses around the name. In book 276 eight names the table lacks are taken from
the book's own numbered headings, and each is noted.

### What is still to do

- **Review.** Nothing above has been seen by a reviewer. For each book: the religious
  reviewer marks `sample.html`; every passage in `review.html` and `compare.html` is
  checked against the printed copy. A link that is flagged, or that the check did
  not confirm, stays out of a pack until it is cleared (D-082). Most of the 166
  flags of book 183 are confirmed by the check, so clearing them should be quick.
- **Corrections.** Where the reviewer finds a printed number wrong, the correction is
  recorded in a reviewed file that names the passage, the printed number and the
  right one, and is applied by a tested step. That step is not written yet.
- **The four other books**, looked at with `inspect` only and not linked:
  - 473 prints ayah numbers inside 2,577 of its 5,298 quotations, under headings that
    name the surah, and runs from the end of the mushaf to its beginning. A profile
    of its own looks possible.
  - 165 has 156 references that name the surah, under headings by subject.
  - 737 has headings by surah and a number inside 140 of its 1,188 quotations.
  - 440 is 250 numbered questions, each a heading that holds the quotation asked
    about. 124 of its 302 quotations hold a number, and a number in parentheses
    follows the quotation in the headings. Whether those are ayah numbers or
    footnote marks has not been looked at.
  Matching a quotation's wording against the Quran text is not a basis for a link
  unless the reviewer approves the method and checks every link.
- **Surah numbers of book 514.** They rest on the order of its headings until the
  base pack gives the reference names and counts to check against.

## Before a book is shown in the app

1. Extraction complete (`state.json` says `done`) and page sequence checked for gaps.
2. Honorific table approved and applied by a pipeline step that is itself tested.
3. Ayah linking built; the sample reviewed by the religious reviewer; every flagged
   or unconfirmed passage checked against the printed copy.
4. Pack manifest filled in: source, edition, permission reference, trust grade,
   SHA-256, counts, reviewer and date (PRD §9.2).
5. The book's row in `docs/content/RIGHTS_REGISTER.md` is `Complete`: credit line with
   publisher, edition and editor, and the conditions of the site-wide permission.

The source as a whole is already `Ready` in `docs/SOURCES.md` (row 18); these steps
clear one book.
