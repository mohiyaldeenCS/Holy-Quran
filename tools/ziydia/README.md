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

If the tool prints `no text block found`, it saves `problem_page.html` in the book's
folder. Send that file with the console output.

## Output must stay out of git

`ziydia_out/` and `ziydia_out.zip` are ignored by `.gitignore`. Raw extraction output
is input to the content pipeline, not source code, and no book text enters the
repository before it has been verified and packaged.
