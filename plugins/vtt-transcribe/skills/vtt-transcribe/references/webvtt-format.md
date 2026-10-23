# WebVTT format reference

Source: [MDN - Web Video Text Tracks Format](https://developer.mozilla.org/en-US/docs/Web/API/WebVTT_API/Web_Video_Text_Tracks_Format). Read this when `scripts/vtt_digest.py` exits 3 (no cues) or its output looks wrong.

## Structure

```
WEBVTT - optional title text

NOTE a comment block, ignored

STYLE
::cue { color: yellow }

intro-cue
00:00:01.000 --> 00:00:04.000 align:start position:10%
<v Alice>First line of the cue
second line of the same cue

00:05.000 --> 00:07.500
A cue with no identifier and a short timestamp
```

- **Header:** the file starts with `WEBVTT` (optionally after a UTF-8 BOM), optionally followed by a space or tab and text. Header metadata lines (YouTube's `Kind:` / `Language:`) can follow before the first blank line.
- **Blocks** are separated by one or more empty lines. An empty line ends a cue; a line containing only spaces does not.
- **Cue:** optional identifier line, then a timing line, then one or more payload lines.
- **Timing line:** `start --> end`, each `hh:mm:ss.ttt` or `mm:ss.ttt` (hours optional). Cue settings may follow: `vertical`, `line`, `position`, `size`, `align`, `region`.
- **Non-cue blocks:** `NOTE` (comments), `STYLE` (CSS), `REGION` (layout). None carry transcript text.

## Payload markup

| Markup | Meaning | Digest handling |
|--------|---------|-----------------|
| `<v Name>` / `<v.class Name>` | Voice: the speaker | Becomes the `Speaker:` label |
| `<c>`, `<c.class>` | Class span | Stripped |
| `<i>`, `<b>`, `<u>` | Styling | Stripped |
| `<lang en>`, `<ruby>`, `<rt>` | Language, ruby annotations | Stripped |
| `<00:00:05.000>` | Karaoke-style timestamp inside a cue | Stripped |
| `&amp; &lt; &gt; &nbsp; &lrm; &rlm;` | Escapes | Unescaped |

## Exporter quirks

- **YouTube / auto-captions:** each cue repeats the previous line, plus near-zero-length cues duplicating text, plus `<c>` word-timing tags. The digest removes the repeats.
- **Zoom:** no `<v>` tags; the speaker appears as `Name: text` at the start of the payload. The digest treats that prefix as the speaker unless run with `--no-inline-speakers` (use that flag if ordinary text like `Note: ...` is being mistaken for a speaker).
- **Teams:** `<v Name>` voice tags, often with GUID-style cue identifiers.
- **SRT files renamed to `.vtt`:** no `WEBVTT` header and comma decimal separators (`00:00:01,000`). The digest accepts both; true SRT cue numbers are treated as identifiers.
