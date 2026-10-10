# ziydia_fetch.py

Extracts the text of books from <https://ziydia.com> (المكتبة الزيدية) page by page.
It is run by the product owner on his own computer, under the site owner's written
permission. Context, findings and the data format are in
`docs/content/ZIYDIA_LIBRARY.md`.

- Python 3.8+, standard library only. Nothing to install.
- One request every 3 seconds over a single kept-alive connection.
- Retries with back-off (the site drops connections now and then).
- Resumable: rerun the same command and it continues from the last saved page.
- Saves each page's text block as served, in the `html` field. It corrects and
  rewrites nothing. See "What is saved" for the two small things it does do.

## Commands

```
py ziydia_fetch.py list [category ids]        # default: 5 (التفسير وعلوم القرآن)
py ziydia_fetch.py books <id> [<id> …] [--max-pages N] [--include-skipped]
py ziydia_fetch.py pack                       # zip ziydia_out/ into ziydia_out.zip
```

On Linux or macOS use `python3` instead of `py`.

| Command | Result |
| --- | --- |
| `list` | `ziydia_out/books_index.csv` and the raw category pages |
| `books 183` | `ziydia_out/book_183/{meta.json, toc.json, pages.jsonl, state.json}` |
| `books 183 466 --max-pages 30` | A short trial: at most 30 new pages per book in this run |
| `pack` | `ziydia_out.zip`, ready to upload |

A book is complete when the tool prints `COMPLETE` and `state.json` has `"done": true`.

## Settings at the top of the file

| Name | Default | Meaning |
| --- | --- | --- |
| `DELAY` | `3.0` | Seconds between requests. Do not lower it. |
| `RETRIES` | `7` | Attempts per page before it counts as a failure |
| `MAX_FAILS_IN_ROW` | `3` | Consecutive failed pages before the run stops |
| `CONTACT` | `""` | Optional e-mail added to the User-Agent. Empty by design. |
| `SKIP_IDS` | `{204, 425, 74, 108, 102}` | Five contemporary works, left out of a run unless `--include-skipped` is given, so that a long run does not fetch them by accident. The owner confirmed on 2026-10-07 that the permission covers them (decision D-012). |

## What is saved

For every page the tool writes one line in `pages.jsonl` (all fields are listed in
`docs/content/ZIYDIA_LIBRARY.md`). Two of them hold the text:

| Field | What it is | Use |
| --- | --- | --- |
| `html` | The inner HTML of the page's text block as the site served it. Two things are done to it and no others: the response is decoded as UTF-8, with any invalid byte replaced by U+FFFD, and white space before and after the whole block is removed. | The only input for building content. Look for U+FFFD in it before trusting a page |
| `text` | A plain-text rendering for reading and searching by eye: tags removed, entities decoded, no-break spaces turned into spaces, runs of spaces collapsed, lines trimmed, empty lines dropped. | Inspection only. Never build content from it |

## Status

| What | State |
| --- | --- |
| Category listing with pagination | Works: 39 books found on 4 pages (2026-10-06) |
| Single-part book | Works: book 183 extracted completely, 339 pages |
| Resume after interruption | Works: book 183 continued from page 30 |
| Moving to the next part of a multi-part book | Works: books 165, 471, 473 (two parts) and 514 (seven parts), 2026-10-07. The `part` field is one page late at each boundary; `page_label` is right. |
| Scanned-PDF books | Produce empty pages. Seven such books are listed in `docs/content/ZIYDIA_LIBRARY.md`; do not fetch them. |
| Page labels | The site prints them with Western digits («صفحة 80», «الجزء 7 · صفحة 618»); the linker stops on a label it cannot read |

If the tool prints `no text block found`, it saves `problem_page.html` in the book's
folder. Send that file with the console output.

## Output must stay out of git

`ziydia_out/`, `ziydia_out.zip` and the linker's `ziydia_links/` are ignored by
`.gitignore`. Raw extraction output and what is derived from it are input to the
content pipeline, not source code, and no book text enters the repository before it
has been verified and packaged. `ziydia_links/book_514/passages.jsonl` holds the
whole Quran text as that book prints it, which this repository never carries.

# ziydia_link.py

Links the paragraphs of an extracted book to ayat. The rules, the output and the
results so far are in `docs/content/ZIYDIA_LIBRARY.md`, "Linking commentary to ayat".
In short: a link rests only on what the book prints (surah headings and ayah
numbers); no number is corrected; every paragraph is carried unchanged, except the
lines that divide a page (the rule of dashes of book 514, the line above the
footnotes of books 473 and 440), which are counted; a surprise in the structure
stops the run (in books 276 and 471 a heading that cannot be read is noted instead,
because many of their headings are not surah headings).

- Python 3.8+, standard library only. It reads `ziydia_out/` and never opens the site.
- Books with a profile: 183, 514, 276, 471, 473, 440. Any other book: `inspect` only.
- Tests: `py -m unittest test_ziydia_link` in this folder. They use made-up pages.

## Commands, in this order

```
py ziydia_link.py link 183
py ziydia_link.py link 514
py ziydia_link.py names 183 514
py ziydia_link.py link 183 --surahs ziydia_links/surahs.json
py ziydia_link.py link 276 --surahs ziydia_links/surahs.json
py ziydia_link.py link 471 --surahs ziydia_links/surahs.json
py ziydia_link.py link 473 --surahs ziydia_links/surahs.json
py ziydia_link.py link 440 --surahs ziydia_links/surahs.json
py ziydia_link.py compare 183        # then 514, 276, 471, 473 and 440
py ziydia_link.py inspect 165        # markup inventory of any extracted book
```

Options: `--in DIR` (default `ziydia_out`), `--out DIR` (default `ziydia_links`).

| Command | Result |
| --- | --- |
| `link <id>` | `ziydia_links/book_<id>/{passages.jsonl, report.json, sample.html, review.html}` |
| `names 183 514` | `ziydia_links/surahs.json`: surah names as the two books print them, and the last ayah number book 514 prints in each surah. It stops if a name stands for two surahs |
| `link 183 --surahs …` | The same links, and a flag on any number beyond the end of its surah. Book 473 takes the table in the same way; books 276, 471 and 440 cannot be linked without it |
| `compare <id>` | `compare.json` and `compare.html` in the book's folder: the linked passages whose quotation is not found in the ayat they are linked to, as book 514 prints them. It changes no link |
| `inspect <id>` | Counts of headings, quotations, reference shapes, numbered openings and every honorific code, printed to the console. Only the twelve most frequent reference shapes and openings are shown |

Exit code 0 means done, with points for review listed in `report.json`. Exit code 2
means stopped: a wrong command line, a missing or unreadable input, or a book that
broke a rule of its profile. Once `link` has found the book's pages it removes the
book's earlier results, so a stopped run leaves none behind.

## What a line of `passages.jsonl` holds

| Field | Meaning |
| --- | --- |
| `n`, `book` | Order of the passage in the book; site book id |
| `kind` | `passage` (linked to ayat), `unlinked` (no ayah; `surah` may still be known), `heading`, `text` (book 514: the text of the surah as the book prints it), `title_page`, `ornament` (a line of asterisks), `footnote` (473, 440: the footnotes of one page) |
| `surah` | Surah number, or null |
| `refs` | Ayah ranges as printed: `[[first, last], …]`. Several when a paragraph prints several numbers |
| `basis` | What the link rests on: `heading+number`, `heading+reference`, `reference`, `footnote` (440), `printed_numbers` (text), `heading` (surah only), `none` |
| `review` | Present when a person must check the link before it is used, with the reasons |
| `item`, `heading` | Item or question number (276, 471, 440); words of a heading |
| `starts_inside_ayah`, `ends_inside_ayah` | Book 514 text: the paragraph begins or ends in the middle of an ayah |
| `paragraphs` | `site_page`, `part`, `printed_page`, `html` (unchanged), `carried` when the paragraph has no number of its own and follows a numbered one, `role` `opening` for the line a surah opens with |

## Review flags

| Flag | Meaning |
| --- | --- |
| `ayah_number_out_of_order` | The number is lower than the one before it, or it is the one before a step back. In books 183 and 473 also when the numbers of one paragraph go back |
| `number_in_the_quotation_differs_from_the_footnote` | 440: the quotation of a question prints one ayah number and its footnote another |
| `range_is_not_valid` | The printed range ends before it starts, or starts at zero |
| `ayah_beyond_the_end_of_the_surah` | The number is higher than the last ayah number of its surah in book 514 |
| `numbers_are_not_a_range` | Book 514: a paragraph opens with three or more numbers that do not follow one another |
| `the_ayat_after_it_have_no_number` | Book 514: the next ayah or ayat are opened by no number, so the unnumbered paragraphs of this passage may belong to them |
| `reference_names_another_surah_than_the_heading` | 276, 471: the item's reference and the heading above it disagree |
| `carried_paragraph_opens_with_its_own_reference` | 276, 471: a paragraph after the item opens as an item does |

## Limits

- `compare` reads the paragraph that opens a passage, not the paragraphs carried
  after it; in book 514 it reads the first quotation of that paragraph only.
- The surah numbers of book 514 come from the order of its 114 headings, and the ayah
  counts from the numbers it prints. The order agrees with book 183's numbered
  headings for the 102 surahs the two books name alike; all of it is to be checked
  against the base pack when it exists.
- The surah numbers of book 473 come from the order of its 114 surah headings: the
  first is surah 1, then 114 down to 2, as the book is arranged. 90 of the headings
  name their surah as the table does.
- In books 276 and 471 a carried paragraph that cites an ayah after a few words of
  its own is not flagged; only one that opens with the quotation is.
- In book 473 a quotation that prints no number links nothing, and a number printed
  inside a quotation is read as an ayah of the surah being explained. If the author
  cites another surah there, the link is wrong; the comparison is what shows it.
  The paragraphs that close the book are carried into its last passage.
- In book 440 the link follows the footnote. Where the quotation prints another
  number, the passage is flagged and the footnote is still what links it.
- Nothing here has been compared with a printed copy.
