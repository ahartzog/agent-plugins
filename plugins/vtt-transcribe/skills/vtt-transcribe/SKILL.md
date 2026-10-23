---
name: vtt-transcribe
description: >
  Ingest WebVTT (.vtt) caption or transcript files and turn them into whatever the user asks for:
  a summary, meeting notes, action items, a critical analysis, pulled quotes, structured data
  (JSON/CSV/table against a schema), or new entries in an existing note or knowledge base. Use when
  the user hands over a .vtt file (Zoom, Teams, Meet, YouTube, Otter, Whisper exports) or says
  "transcribe", "summarize this transcript", "pull action items from this call", or "ingest this VTT".
argument-hint: <file.vtt> [more.vtt ...] [what you want produced]
---

# vtt-transcribe

Turn one or more `.vtt` files into the output the user requested, with every claim traceable to a timestamp.

This skill reads existing transcripts. It does not convert audio or video to text. If the user hands over audio, video, or a URL, say so and ask for a `.vtt` (Zoom, Teams, Meet, YouTube, and Whisper all export one).

## Inputs

`$ARGUMENTS` holds file paths and, optionally, a free-text request. Split them:

- **Files:** every argument ending in `.vtt`, plus any glob or directory the user names (expand to its `.vtt` files).
- **Request:** everything else - "action items", "summary for my manager", "extract every product mentioned into a CSV", "add the decisions to `notes/project-x.md`".

If no request is given, ask one question offering the recipes in [references/recipes.md](references/recipes.md), with **Summary** as the default.

## Steps

1. **Digest each file.** Run the bundled script by its absolute path under this skill's base directory (shown when the skill loads), writing to a scratch location rather than next to the user's files:
   ```bash
   python3 -I <skill-dir>/scripts/vtt_digest.py <file.vtt> [more.vtt ...] > <scratch>/digest.txt
   ```
   The digest strips headers, `NOTE`/`STYLE`/`REGION` blocks, cue settings, markup, and rolling auto-caption repeats, and emits `[HH:MM:SS] Speaker: text` paragraphs. Use `--window 0` when the output needs per-cue precision (subtitle edits, exact quote timing), `--json` when the output is itself structured data. Exit 3 means no cues were found: read the raw file's first 40 lines and check it against [references/webvtt-format.md](references/webvtt-format.md) before giving up.

2. **Read the entire digest.** Use the Read tool with `offset`/`limit` in chunks until every line is read. Do not start producing output from a partial read - transcript conclusions routinely reverse late in a recording.

3. **Resolve the destination.**
   - **Chat** - the default when the user names no file.
   - **New file** - default path is the `.vtt`'s path with `.md` (or the requested extension). If the file exists, ask: overwrite, or a new name.
   - **Existing file or knowledge base** - read the target first and match its structure, heading levels, link style, and frontmatter. Append or insert; never rewrite content the transcript doesn't touch.

4. **Produce the output** using the matching recipe in [references/recipes.md](references/recipes.md), or the user's own format if they gave one. The user's format wins over a recipe.

5. **Verify before reporting.** For every direct quote and every timestamp in the output, `grep` the digest and confirm the text and time match. Fix or remove anything that doesn't.

## Rules for every output

- **Cite timestamps** as `[HH:MM:SS]`, or `[HH:MM:SS--HH:MM:SS]` for a span. Wrap them in backticks in prose and bullets; leave them bare in headings. With multiple files, prefix the file's short name: `[standup 00:12:40]`.
- **Source only from the transcript.** No outside knowledge about the speakers, company, or topic unless the user asks for it; if added, label it as outside the transcript.
- **Speakers:** use the labels the file gives. Don't infer who an unlabeled speaker is. If the user tells you who's who, apply it. Meeting tools label by device, so people sharing a room or mic get no label of their own, and short turns often land under the wrong name. When the content clearly contradicts the label (someone describing "my" work the other person did), keep the label and flag the likely misattribution.
- **Transcription errors:** auto-captions mishear names and jargon. When a word is likely misheard, keep the transcript's text and note the probable intended word in brackets - `"cooper netties" [Kubernetes?]` - rather than silently correcting it.
- **Entities spelled several ways:** when one name is transcribed inconsistently, pick one spelling, say so once in a caveats line, and use it throughout. If the correct spelling comes from outside the transcript, label it as such.
- **Numbers:** speech recognition guesses units and punctuation. Counts come out as currency (`"$3.40 per box"` for 340 units per box) and thousands separators come out as decimals. Quote the number as transcribed; when context shows the intended value, give it in brackets and list it in the caveats line. Never do arithmetic on a number you had to reinterpret without flagging it.
- **Quotes are verbatim** from the digest. Paraphrase without quotation marks.
- **Neutral tone** unless the recipe (e.g. Critical analysis) or the user asks for judgment.
- **Long transcripts:** if the digest exceeds roughly 2,000 lines, work section by section and keep a running outline, but still read every line before writing the final output.

## Bundled files

- `scripts/vtt_digest.py` - VTT to compact citable digest. Stdlib only. `--help` for flags.
- `references/recipes.md` - output recipes: summary, meeting notes, action items, critical analysis, quotes, structured extraction, knowledge-base ingest, Q&A.
- `references/webvtt-format.md` - the WebVTT format, for debugging files the script can't parse.
