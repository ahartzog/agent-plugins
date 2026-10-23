# vtt-transcribe

Turn WebVTT (`.vtt`) transcripts from Zoom, Teams, Meet, YouTube, or Whisper into the output you ask for - a summary, meeting notes, action items, a critical analysis, quotes, structured data, or entries in an existing note - with every claim cited to a timestamp.

The skill reads existing transcripts. It does not convert audio or video to text.

## Install

```bash
claude plugin install vtt-transcribe@ahartzog
```

## Use

```
/vtt-transcribe standup.vtt action items
/vtt-transcribe talk.vtt critical analysis, write to talk.md
/vtt-transcribe calls/*.vtt extract every customer objection into objections.csv
/vtt-transcribe review.vtt add the decisions to notes/project-x.md
```

With no request, the skill asks which recipe you want and defaults to a summary.

## How it works

1. `scripts/vtt_digest.py` compresses the VTT into `[HH:MM:SS] Speaker: text` paragraphs. On auto-generated captions this typically cuts the text to a fraction of the raw file, which is what makes long recordings fit in one read.
2. The agent reads the whole digest before writing anything.
3. It produces the output from a recipe in `skills/vtt-transcribe/references/recipes.md`, or your own format.
4. It greps every quote and timestamp back against the digest before reporting.

The digest script runs standalone too: `python3 skills/vtt-transcribe/scripts/vtt_digest.py file.vtt --help`.

## Credits

The critical-analysis recipe is adapted from [jftuga/transcript-critic](https://github.com/jftuga/transcript-critic).
