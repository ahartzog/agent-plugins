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


def read_manifest(path, hub=None):
    """Files the session opened, in order, with the turn index they belong to.

    Wrap's Connections bucket needs to know which files were read *together* — two
    files opened for one answer is a traversal, which is the evidence an edge is
    missing. extract() deliberately drops tool traffic, so that signal is only
    available here.

    Deliberately incomplete: sees Read/Edit/Write only. Files reached via Grep,
    Glob, Bash, a subagent, or an external store fetch do not appear. A thin
    manifest is thin evidence, not proof that nothing was traversed.
    """
    seen = []
    turn = 0
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                d = json.loads(line)
            except json.JSONDecodeError:
                continue
            if d.get("type") == "user" and not d.get("isSidechain"):
                # Tool results also arrive as type "user"; counting them would make
                # "turn" a tool-call index and destroy the co-read grouping this
                # exists for. Only a real user message with prose advances the turn
                # — the same test extract() applies.
                msg_u = d.get("message")
                if isinstance(msg_u, dict):
                    t_u = block_text(msg_u.get("content"))
                    if t_u and not is_injected(t_u):
                        turn += 1
            msg = d.get("message")
            if not isinstance(msg, dict):
                continue
            content = msg.get("content")
            if not isinstance(content, list):
                continue
            for b in content:
                if not isinstance(b, dict) or b.get("type") != "tool_use":
                    continue
                if b.get("name") not in ("Read", "Edit", "Write", "NotebookEdit"):
                    continue
                fp = (b.get("input") or {}).get("file_path")
                if not fp or not fp.endswith(".md"):
                    continue
                if hub and not os.path.abspath(fp).startswith(os.path.abspath(hub)):
                    continue
                seen.append({"turn": turn, "file": fp, "via": b.get("name")})
    return seen


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--session-id")
    ap.add_argument("--cwd", default=os.getcwd())
    ap.add_argument("--projects-dir")
    ap.add_argument("--json", action="store_true", dest="as_json")
    ap.add_argument(
        "--read-manifest",
        nargs="?",
        const=True,
        default=None,
        metavar="HUB_PATH",
        help="also emit the markdown files this session opened, with turn index. "
        "Pass a hub path to restrict to files under it. Feeds wrap's Connections bucket.",
    )
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

    manifest = None
    if args.read_manifest is not None:
        hub = args.read_manifest if isinstance(args.read_manifest, str) else None
        manifest = read_manifest(path, hub)

    if args.as_json:
        out = {"transcript": path, "turn_count": len(turns), "turns": turns}
        if manifest is not None:
            out["read_manifest"] = manifest
        json.dump(out, sys.stdout, indent=2)
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

    if manifest is not None:
        print("# Read manifest — markdown files opened, by turn")
        print("# (Read/Edit/Write only; Grep/Glob/Bash/subagent reads are not visible here)")
        by_turn = {}
        for m in manifest:
            by_turn.setdefault(m["turn"], []).append(m["file"])
        if not by_turn:
            print("# (none)")
        for t in sorted(by_turn):
            uniq = list(dict.fromkeys(by_turn[t]))
            print(f"## Turn {t} — {len(uniq)} file(s)")
            for f in uniq:
                print(f"- {f}")
        print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
