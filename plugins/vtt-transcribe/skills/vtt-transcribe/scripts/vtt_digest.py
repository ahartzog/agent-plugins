#!/usr/bin/env python3
"""Turn a WebVTT caption file into a compact, citable transcript digest.

Raw VTT spends most of its tokens on cue numbers, timing lines, cue settings,
inline markup, and (for auto-generated captions) rolling duplicate lines. The
digest keeps only what an agent needs to read and cite:

  [HH:MM:SS] Speaker: text text text

Consecutive cues from the same speaker merge into one paragraph until the
--window is exceeded, so every paragraph still carries a usable timestamp.

Usage:
  vtt_digest.py talk.vtt                  # digest to stdout
  vtt_digest.py a.vtt b.vtt               # several files, one section each
  vtt_digest.py talk.vtt --window 60      # longer paragraphs
  vtt_digest.py talk.vtt --window 0       # one line per cue, no merging
  vtt_digest.py talk.vtt --json           # structured segments

Format reference:
  https://developer.mozilla.org/en-US/docs/Web/API/WebVTT_API/Web_Video_Text_Tracks_Format

Exit codes: 0 ok, 2 file unreadable, 3 no cues found.
"""

import argparse
import html
import json
import re
import sys

TIMING_RE = re.compile(
    r"^\s*((?:\d+:)?\d{1,2}:\d{2}[.,]\d{1,3})\s+-->\s+((?:\d+:)?\d{1,2}:\d{2}[.,]\d{1,3})"
)
VOICE_RE = re.compile(r"<v(?:\.[^\s>]+)?\s+([^>]+)>")
TAG_RE = re.compile(r"<[^>]*>")
# Zoom and some other exporters put the speaker in the payload as "Name: text".
INLINE_SPEAKER_RE = re.compile(r"^([A-Z][\w.'\- ]{0,40}?):\s+(.*)$")
NON_CUE_BLOCKS = ("NOTE", "STYLE", "REGION")
# Word-timing tags only appear in auto-generated captions, which also roll.
ROLLING_MARKERS_RE = re.compile(r"<\d{2}:\d{2}[:.]\d|<c[.>]")


def parse_ts(ts):
    parts = ts.replace(",", ".").split(":")
    seconds = float(parts[-1])
    minutes = int(parts[-2])
    hours = int(parts[-3]) if len(parts) == 3 else 0
    return hours * 3600 + minutes * 60 + seconds


def fmt_ts(seconds):
    s = int(seconds)
    return f"{s // 3600:02d}:{s % 3600 // 60:02d}:{s % 60:02d}"


def clean_line(line):
    return " ".join(html.unescape(TAG_RE.sub("", line)).split())


def parse_cues(text, inline_speakers):
    """Yield (start, end, speaker, [lines]) for each cue in a VTT document."""
    text = text.lstrip("﻿").replace("\r\n", "\n").replace("\r", "\n")
    # Only a truly empty line ends a cue; auto-captions use " " lines inside cues.
    blocks = re.split(r"\n\n+", text)
    if blocks and blocks[0].startswith("WEBVTT"):
        blocks = blocks[1:]
    for block in blocks:
        lines = block.strip("\n").split("\n")
        if not lines or not lines[0].strip():
            continue
        if lines[0].split(" ")[0].split("\t")[0] in NON_CUE_BLOCKS:
            continue
        timing_idx = next((i for i, l in enumerate(lines[:2]) if TIMING_RE.match(l)), None)
        if timing_idx is None:
            continue
        m = TIMING_RE.match(lines[timing_idx])
        start, end = parse_ts(m.group(1)), parse_ts(m.group(2))
        speaker = None
        payload = []
        for raw in lines[timing_idx + 1:]:
            v = VOICE_RE.search(raw)
            if v:
                speaker = v.group(1).strip()
            line = clean_line(raw)
            if not line:
                continue
            if inline_speakers and speaker is None:
                s = INLINE_SPEAKER_RE.match(line)
                if s:
                    speaker, line = s.group(1).strip(), s.group(2)
            payload.append(line)
        if payload:
            yield start, end, speaker, payload


def dedupe(cues):
    """Drop rolling-caption repeats: lines already emitted by recent cues.

    Auto-generated captions (YouTube and similar) repeat the previous line at
    the top of each cue, and often emit near-zero-length cues that duplicate
    text. Comparing against the last few emitted lines removes both without
    touching genuinely repeated speech further apart.
    """
    recent = []
    for start, end, speaker, lines in cues:
        fresh = []
        for line in lines:
            if line in recent:
                continue
            # Progressive captions grow a line word by word; keep the longest.
            if recent and line.startswith(recent[-1]) and fresh == []:
                line = line[len(recent[-1]):].strip()
                recent[-1] = recent[-1] + " " + line
                if line:
                    fresh.append(line)
                continue
            fresh.append(line)
            recent.append(line)
        recent = recent[-4:]
        if fresh:
            yield start, end, speaker, " ".join(fresh)


def merge(cues, window):
    segments = []
    for start, end, speaker, text in cues:
        last = segments[-1] if segments else None
        if (
            last
            and window > 0
            and last["speaker"] == speaker
            and start - last["start"] < window
        ):
            last["text"] += " " + text
            last["end"] = end
        else:
            segments.append({"start": start, "end": end, "speaker": speaker, "text": text})
    return segments


def digest(path, window, inline_speakers):
    with open(path, encoding="utf-8-sig", errors="replace") as f:
        raw = f.read()
    cues = parse_cues(raw, inline_speakers)
    # Only auto-captions roll; in a human-attributed transcript a repeated
    # "Yeah." is real speech and must survive.
    if ROLLING_MARKERS_RE.search(raw):
        cues = dedupe(cues)
    else:
        cues = ((start, end, speaker, " ".join(lines)) for start, end, speaker, lines in cues)
    segments = merge(cues, window)
    return raw, segments


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("files", nargs="+")
    ap.add_argument("--window", type=float, default=30.0,
                    help="max seconds per merged paragraph (0 = no merging; default 30)")
    ap.add_argument("--json", action="store_true", help="emit structured segments")
    ap.add_argument("--no-inline-speakers", action="store_true",
                    help="do not treat a leading 'Name:' in cue text as the speaker")
    args = ap.parse_args()

    results = []
    for path in args.files:
        try:
            raw, segments = digest(path, args.window, not args.no_inline_speakers)
        except OSError as e:
            print(f"error: cannot read {path}: {e}", file=sys.stderr)
            return 2
        if not segments:
            print(f"error: no cues found in {path}", file=sys.stderr)
            return 3
        results.append((path, raw, segments))

    if args.json:
        out = []
        for path, _, segments in results:
            out.append({
                "source": path,
                "duration": fmt_ts(segments[-1]["end"]),
                "speakers": sorted({s["speaker"] for s in segments if s["speaker"]}),
                "segments": [
                    {"start": fmt_ts(s["start"]), "end": fmt_ts(s["end"]),
                     "speaker": s["speaker"], "text": s["text"]}
                    for s in segments
                ],
            })
        print(json.dumps(out, indent=2, ensure_ascii=False))
    else:
        for i, (path, _, segments) in enumerate(results):
            if i:
                print()
            speakers = sorted({s["speaker"] for s in segments if s["speaker"]})
            print(f"# Source: {path}")
            print(f"# Duration: {fmt_ts(segments[-1]['end'])}"
                  f" | Segments: {len(segments)}"
                  f" | Speakers: {', '.join(speakers) if speakers else 'unlabeled'}")
            print()
            for s in segments:
                who = f"{s['speaker']}: " if s["speaker"] else ""
                print(f"[{fmt_ts(s['start'])}] {who}{s['text']}")

    for path, raw, segments in results:
        size = sum(len(s["text"]) for s in segments)
        print(f"{path}: {len(raw)} chars raw -> ~{size} chars digest", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
