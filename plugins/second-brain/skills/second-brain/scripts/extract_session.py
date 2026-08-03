#!/usr/bin/env python3
"""Extract a compact digest of a Claude Code session transcript for wrap mode.

Reads the session JSONL that Claude Code writes to
~/.claude/projects/<slug>/<session-id>.jsonl and emits the substantive turns —
user messages and assistant prose — with tool noise stripped.

The transcript is the source of truth for "what did this session learn?"
because it survives context compaction: the model's recall does not.

Usage:
  extract_session.py                      # newest session for $PWD
  extract_session.py --session-id <uuid>
  extract_session.py --cwd /path/to/hub
  extract_session.py --json               # structured output for an agent

Exit codes: 0 ok, 2 no transcript found, 3 transcript has no substantive turns.
"""

import argparse
import json
import os
import sys

# Prefixes that mark harness-injected user turns rather than human input.
INJECTED_MARKERS = (
    "<system-reminder>",
    "<local-command-stdout>",
    "<command-name>",
    "Caveat: The messages below",
    "[SYSTEM NOTIFICATION",
    "<task-notification>",
)


def project_slug(cwd):
    """Claude Code slugifies the cwd by replacing / and . with -."""
    return cwd.replace("/", "-").replace(".", "-")


def find_transcript(cwd, session_id=None, projects_dir=None):
    base = projects_dir or os.path.expanduser("~/.claude/projects")
    d = os.path.join(base, project_slug(os.path.abspath(cwd)))
    if not os.path.isdir(d):
        return None
    if session_id:
        p = os.path.join(d, f"{session_id}.jsonl")
        return p if os.path.isfile(p) else None
    files = [
        os.path.join(d, f) for f in os.listdir(d) if f.endswith(".jsonl")
    ]
    if not files:
        return None
    return max(files, key=os.path.getmtime)


def block_text(content):
    """Flatten a message content field to plain text, dropping tool traffic."""
    if isinstance(content, str):
        return content
    if not isinstance(content, list):
        return ""
    out = []
    for b in content:
        if not isinstance(b, dict):
            continue
        # tool_use / tool_result / thinking are deliberately excluded: tool
        # traffic is bulk, and thinking is not what the session concluded.
        if b.get("type") == "text":
            out.append(b.get("text", ""))
    return "\n".join(out).strip()


def is_injected(text):
    t = text.lstrip()
    return any(t.startswith(m) for m in INJECTED_MARKERS)


def extract(path):
    turns = []
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                d = json.loads(line)
            except json.JSONDecodeError:
                continue  # tolerate partial writes on a live session
            if d.get("type") not in ("user", "assistant"):
                continue
            if d.get("isSidechain"):
                continue  # subagent traffic, not this conversation
            msg = d.get("message")
            if not isinstance(msg, dict):
                continue
            text = block_text(msg.get("content"))
            if not text or is_injected(text):
                continue
            turns.append(
                {
                    "role": msg.get("role"),
                    "text": text,
                    "timestamp": d.get("timestamp"),
                }
            )
    return turns


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--session-id")
    ap.add_argument("--cwd", default=os.getcwd())
    ap.add_argument("--projects-dir")
    ap.add_argument("--json", action="store_true", dest="as_json")
    ap.add_argument(
        "--max-chars",
        type=int,
        default=4000,
        help="truncate each turn to this many chars (0 = no limit)",
    )
    args = ap.parse_args()

    path = find_transcript(args.cwd, args.session_id, args.projects_dir)
    if not path:
        print(
            "No transcript found for this working directory. Wrap needs the "
            "session that did the work.",
            file=sys.stderr,
        )
        return 2

    turns = extract(path)
    if args.max_chars:
        for t in turns:
            if len(t["text"]) > args.max_chars:
                t["text"] = t["text"][: args.max_chars] + "\n[...truncated]"

    user_turns = sum(1 for t in turns if t["role"] == "user")
    if user_turns == 0:
        print(
            f"Transcript {os.path.basename(path)} has no substantive user "
            "turns — nothing to verify.",
            file=sys.stderr,
        )
        return 3

    if args.as_json:
        json.dump(
            {"transcript": path, "turn_count": len(turns), "turns": turns},
            sys.stdout,
            indent=2,
        )
        sys.stdout.write("\n")
        return 0

    print(f"# Session digest — {os.path.basename(path)}")
    print(f"# {len(turns)} substantive turns ({user_turns} from the user)\n")
    for i, t in enumerate(turns, 1):
        who = "USER" if t["role"] == "user" else "ASSISTANT"
        stamp = f" [{t['timestamp']}]" if t.get("timestamp") else ""
        print(f"## Turn {i} — {who}{stamp}")
        print(t["text"])
        print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
