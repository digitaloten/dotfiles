#!/usr/bin/env python3
"""Forensic log of every file mutation Claude makes, and everything that
mangles it afterwards.

Two kinds of mangling get traced:

  1. A PostToolUse hook (formatter, linter) rewrites the file after Write/Edit
     lands. Detected by comparing the content Claude INTENDED to be on disk
     against what is actually there once all hooks have run.
  2. An Edit call itself fails or misfires -- `old_string` not found, ambiguous
     match. Captured from PostToolUseFailure, and correlated against any earlier
     mangling of the same file in the same session, which is usually the cause.

Intent is computed, never guessed: Write supplies `content`; Edit supplies
`old_string`/`new_string`, which we apply to the pre-edit bytes ourselves. So
there is no race with a formatter hook running in parallel.

Resolution is deferred to the NEXT PreToolUse (any tool) or to Stop. By then
Claude Code has run every PostToolUse hook to completion, so the file has
settled. Nothing here polls or sleeps.

Modes (argv[1]):
  pre   -- PreToolUse, any tool: resolve outstanding records, then record intent
  fail  -- PostToolUseFailure on Write|Edit: log the failure
  stop  -- Stop / SessionEnd: resolve whatever is left

Log root: $CLAUDE_EDIT_AUDIT_DIR, else $XDG_STATE_HOME/claude/edit-audit,
else ~/.local/state/claude/edit-audit. Deliberately outside every git repo.
"""

import difflib
import hashlib
import json
import os
import shutil
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

EDIT_TOOLS = {"Write", "Edit", "MultiEdit", "NotebookEdit"}

MAX_FILE_BYTES = 2 * 1024 * 1024  # don't snapshot anything bigger
MAX_EVENTS_BYTES = 16 * 1024 * 1024  # rotate events.jsonl past this
EVENTS_KEEP = 3  # events.jsonl.1 .. .3
MAX_ARTIFACT_DIRS = 300  # prune oldest mangled/ dirs past this
MIN_FREE_BYTES = 1 * 1024 * 1024 * 1024  # below this, log but skip artifacts
PENDING_TTL_SEC = 6 * 3600  # orphaned pending records expire


def log_root() -> Path:
    env = os.environ.get("CLAUDE_EDIT_AUDIT_DIR")
    if env:
        return Path(env)
    xdg = os.environ.get("XDG_STATE_HOME")
    base = Path(xdg) if xdg else Path.home() / ".local" / "state"
    return base / "claude" / "edit-audit"


def now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()[:16]


def read_bytes(p: Path):
    """Return file bytes, or None if absent/too big/unreadable."""
    try:
        if not p.is_file():
            return None
        if p.stat().st_size > MAX_FILE_BYTES:
            return None
        return p.read_bytes()
    except OSError:
        return None


def unreadable_reason(p: Path) -> str:
    try:
        if not p.exists():
            return "pre-absent"
        if not p.is_file():
            return "pre-not-a-file"
        if p.stat().st_size > MAX_FILE_BYTES:
            return "pre-too-large"
        return "pre-unreadable"
    except OSError:
        return "pre-unreadable"


def free_bytes(p: Path) -> int:
    try:
        return shutil.disk_usage(p).free
    except OSError:
        return 0


def emit(root: Path, record: dict) -> None:
    """Append one JSON line. Rotate by size. Never raise."""
    try:
        root.mkdir(parents=True, exist_ok=True)
        events = root / "events.jsonl"
        try:
            if events.exists() and events.stat().st_size > MAX_EVENTS_BYTES:
                for i in range(EVENTS_KEEP, 0, -1):
                    src = events if i == 1 else root / f"events.jsonl.{i - 1}"
                    dst = root / f"events.jsonl.{i}"
                    if src.exists():
                        src.replace(dst)
        except OSError:
            pass
        with events.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(record, ensure_ascii=False) + "\n")
    except Exception:
        pass


def pending_dir(root: Path) -> Path:
    d = root / "pending"
    d.mkdir(parents=True, exist_ok=True)
    return d


def prune_artifacts(root: Path) -> None:
    try:
        base = root / "mangled"
        if not base.is_dir():
            return
        dirs = sorted((d for d in base.iterdir() if d.is_dir()), key=lambda d: d.stat().st_mtime)
        for d in dirs[:-MAX_ARTIFACT_DIRS]:
            shutil.rmtree(d, ignore_errors=True)
    except OSError:
        pass


def decode(data: bytes):
    """utf-8 text, or None if binary."""
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        return None


def compute_intent(tool: str, tool_input: dict, pre: bytes, path_note: str = "pre-unreadable"):
    """What SHOULD be on disk after this tool call.

    Returns (intent_bytes, note). intent_bytes None => cannot determine, and
    `note` says why. Mirrors the Edit tool's own matching rules.
    """
    if tool == "Write":
        content = tool_input.get("content")
        if content is None:
            return None, "write-without-content"
        return content.encode("utf-8"), None

    if tool == "Edit":
        old = tool_input.get("old_string")
        new = tool_input.get("new_string")
        if old is None or new is None:
            return None, "edit-missing-strings"
        if pre is None:
            return None, path_note
        text = decode(pre)
        if text is None:
            return None, "binary-file"
        count = text.count(old)
        if count == 0:
            return None, "old-string-absent"
        if tool_input.get("replace_all"):
            return text.replace(old, new).encode("utf-8"), None
        if count > 1:
            return None, "old-string-ambiguous"
        return text.replace(old, new, 1).encode("utf-8"), None

    # MultiEdit / NotebookEdit: record, but don't model their semantics.
    return None, f"intent-not-modelled:{tool}"


def save_artifact(root: Path, rec: dict, intent: bytes, final: bytes) -> str:
    """Write a unified diff of intent -> on-disk. Returns path, or '' if skipped."""
    if free_bytes(root) < MIN_FREE_BYTES:
        return ""
    try:
        day = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        d = root / "mangled" / day / f"{rec['ts'].replace(':', '').replace('.', '')}-{rec['tool_use_id'][:12]}"
        d.mkdir(parents=True, exist_ok=True)

        i_txt, f_txt = decode(intent), decode(final)
        if i_txt is None or f_txt is None:
            (d / "intent.bin").write_bytes(intent)
            (d / "ondisk.bin").write_bytes(final)
        else:
            diff = difflib.unified_diff(
                i_txt.splitlines(keepends=True),
                f_txt.splitlines(keepends=True),
                fromfile="intended-by-claude",
                tofile="actually-on-disk",
                n=3,
            )
            (d / "mangle.diff").write_text("".join(diff), encoding="utf-8")
            (d / "intent.txt").write_text(i_txt, encoding="utf-8")
            (d / "ondisk.txt").write_text(f_txt, encoding="utf-8")
        (d / "record.json").write_text(json.dumps(rec, indent=2, ensure_ascii=False), encoding="utf-8")
        prune_artifacts(root)
        return str(d)
    except Exception:
        return ""


def resolve_pending(root: Path) -> None:
    """Compare recorded intent against what settled on disk."""
    pd = pending_dir(root)
    now = time.time()
    for pf in sorted(pd.glob("*.json")):
        try:
            rec = json.loads(pf.read_text(encoding="utf-8"))
        except Exception:
            pf.unlink(missing_ok=True)
            continue

        if now - rec.get("epoch", 0) > PENDING_TTL_SEC:
            pf.unlink(missing_ok=True)
            continue

        path = Path(rec["file"])
        final = read_bytes(path)
        intent_path = pd / f"{pf.stem}.intent"
        intent = read_bytes(intent_path) if intent_path.exists() else None

        out = {
            "ts": now_iso(),
            "event": "resolve",
            "session_id": rec.get("session_id"),
            "tool": rec.get("tool"),
            "tool_use_id": rec.get("tool_use_id"),
            "file": rec["file"],
            "cwd": rec.get("cwd"),
            "pre_sha": rec.get("pre_sha"),
            "intent_sha": rec.get("intent_sha"),
            "intent_note": rec.get("intent_note"),
        }

        if final is None:
            out["status"] = "file_absent_or_unreadable"
        elif intent is None:
            out["status"] = "unverifiable"
            out["final_sha"] = sha(final)
        else:
            out["final_sha"] = sha(final)
            if out["final_sha"] == rec.get("intent_sha"):
                out["status"] = "clean"
            elif out["final_sha"] == rec.get("pre_sha"):
                # PreToolUse fires before the permission prompt. A denied,
                # interrupted, or errored tool leaves the file at its pre-edit
                # bytes. That is not mangling.
                out["status"] = "tool_not_applied"
            else:
                out["status"] = "MANGLED"
                out["mangler"] = "post-edit-hook-or-external-writer"
                out["artifact"] = save_artifact(root, out, intent, final)

        emit(root, out)
        pf.unlink(missing_ok=True)
        intent_path.unlink(missing_ok=True)


def record_intent(root: Path, payload: dict) -> None:
    tool = payload.get("tool_name", "")
    if tool not in EDIT_TOOLS:
        return
    ti = payload.get("tool_input") or {}
    fp = ti.get("file_path")
    if not fp:
        return

    path = Path(fp)
    pre = read_bytes(path)
    intent, note = compute_intent(tool, ti, pre, unreadable_reason(path) if pre is None else "")

    tuid = payload.get("tool_use_id") or f"noid-{int(time.time() * 1000)}"
    rec = {
        "epoch": time.time(),
        "ts": now_iso(),
        "event": "intent",
        "session_id": payload.get("session_id"),
        "cwd": payload.get("cwd"),
        "tool": tool,
        "tool_use_id": tuid,
        "file": str(path),
        "pre_sha": sha(pre) if pre is not None else None,
        "pre_bytes": len(pre) if pre is not None else None,
        "intent_sha": sha(intent) if intent is not None else None,
        "intent_note": note,
    }

    pd = pending_dir(root)
    safe = "".join(c for c in tuid if c.isalnum() or c in "-_")[:64]
    try:
        (pd / f"{safe}.json").write_text(json.dumps(rec), encoding="utf-8")
        if intent is not None and free_bytes(root) >= MIN_FREE_BYTES:
            (pd / f"{safe}.intent").write_bytes(intent)
    except OSError:
        pass

    emit(root, {k: v for k, v in rec.items() if k != "epoch"})


def log_failure(root: Path, payload: dict) -> None:
    tool = payload.get("tool_name", "")
    ti = payload.get("tool_input") or {}
    fp = ti.get("file_path")
    path = Path(fp) if fp else None
    cur = read_bytes(path) if path else None

    old = ti.get("old_string")
    rec = {
        "ts": now_iso(),
        "event": "tool_failure",
        "session_id": payload.get("session_id"),
        "cwd": payload.get("cwd"),
        "tool": tool,
        "tool_use_id": payload.get("tool_use_id"),
        "file": str(path) if path else None,
        "error": payload.get("error"),
        "is_interrupt": payload.get("is_interrupt"),
        "duration_ms": payload.get("duration_ms"),
        "current_sha": sha(cur) if cur is not None else None,
        "old_string_len": len(old) if isinstance(old, str) else None,
        "old_string_head": (old[:200] if isinstance(old, str) else None),
    }

    # The interesting correlation: did a hook rewrite this same file earlier in
    # this session? That is almost always why old_string no longer matches.
    if path is not None and cur is not None and isinstance(old, str):
        text = decode(cur)
        rec["old_string_present_now"] = (old in text) if text is not None else None
        rec["prior_mangle_of_this_file"] = prior_mangle(root, payload.get("session_id"), str(path))

    emit(root, rec)


def prior_mangle(root: Path, session_id, file_str: str):
    """Most recent MANGLED resolve for this file in this session, if any."""
    events = root / "events.jsonl"
    if not events.is_file():
        return None
    hit = None
    try:
        with events.open("r", encoding="utf-8", errors="replace") as fh:
            for line in fh:
                if '"MANGLED"' not in line:
                    continue
                try:
                    r = json.loads(line)
                except Exception:
                    continue
                if r.get("file") == file_str and r.get("session_id") == session_id:
                    hit = {"ts": r.get("ts"), "artifact": r.get("artifact")}
    except OSError:
        return None
    return hit


def main() -> int:
    mode = sys.argv[1] if len(sys.argv) > 1 else "pre"
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0
    if not isinstance(payload, dict):
        return 0

    root = log_root()
    try:
        root.mkdir(parents=True, exist_ok=True)
    except OSError:
        return 0

    if mode == "pre":
        resolve_pending(root)
        record_intent(root, payload)
    elif mode == "fail":
        resolve_pending(root)
        log_failure(root, payload)
    elif mode == "stop":
        resolve_pending(root)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        # An audit log must never break the tool call it is observing.
        sys.exit(0)
