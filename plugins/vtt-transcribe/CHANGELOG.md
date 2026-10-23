# Changelog

All notable changes to the **vtt-transcribe** plugin are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this plugin uses [Semantic Versioning](https://semver.org/). The version at the top of each release must match `.claude-plugin/plugin.json`. See the repo-level [CONTRIBUTING.md](../../CONTRIBUTING.md) for change and versioning discipline.

## [0.1.0] — 2026-10-23

Initial release. Pre-1.0: the recipe set and digest format may still change.

### Added
- `/vtt-transcribe` skill: takes one or more `.vtt` files plus a free-text request and produces the requested output with `[HH:MM:SS]` citations, verified against the transcript before reporting.
- `scripts/vtt_digest.py` (stdlib only): converts VTT into a compact `[HH:MM:SS] Speaker: text` digest - strips headers, `NOTE`/`STYLE`/`REGION` blocks, cue settings and markup; reads `<v>` voice tags and Zoom-style `Name:` prefixes as speakers; removes rolling auto-caption repeats (only in files with word-timing tags, so repeated short replies in human-attributed transcripts survive); merges same-speaker cues within a time window. `--json` for structured segments, `--window 0` for per-cue output.
- Output rules for transcript defects found in real meeting exports: device-level speaker labels and misattributions, entities transcribed several ways, numbers with wrong units or separators. Meeting notes recipe gains a "Transcript caveats" line.
- `references/recipes.md`: summary, meeting notes, action items, critical analysis (adapted from jftuga/transcript-critic), quotes, structured extraction, knowledge-base ingest, Q&A.
- `references/webvtt-format.md`: format reference and exporter quirks (YouTube, Zoom, Teams, SRT-renamed files).
