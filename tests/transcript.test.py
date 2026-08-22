#!/usr/bin/env python3
from __future__ import annotations

import importlib.machinery
import importlib.util
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HELPER = ROOT / "scripts" / "meetings"

loader = importlib.machinery.SourceFileLoader("meetings_helper", str(HELPER))
spec = importlib.util.spec_from_loader(loader.name, loader)
assert spec is not None
mod = importlib.util.module_from_spec(spec)
sys.modules[loader.name] = mod
loader.exec_module(mod)

empty_export = """# Meeting 23423

## Meeting Info

- **Date:** 2026-08-21 17:07 UTC
- **Word Count:** 0
- **Segments:** 0

## Transcript
"""
assert mod.live_transcript_is_empty("")
assert mod.live_transcript_is_empty(empty_export)
assert not mod.live_transcript_is_empty("**Me** *[00:00]* hola")

segments = [
    {"text": "hola", "source": "microphone", "speaker_id": "You", "start_ms": 0},
    {"text": "hello", "source": "loopback", "speaker_id": "Remote", "start_ms": 1500},
]
md = mod.segments_to_live_markdown(segments)
assert "**Me**" in md
assert "**Attendee 1**" in md
assert "hola" in md
assert "hello" in md
assert "[00:01]" in md
assert mod.ask_agent_launch_prompt("Standup", 0) == "/omarchy-meetings Standup\n\n"
assert mod.ask_agent_launch_prompt("Meeting 23423", 1755792000).startswith("/omarchy-meetings Meeting 23423 · ")
assert mod.normalize_tag("#Standup") == "standup"
assert mod.normalize_tag("1:1") == "1-1"
assert mod.normalize_tags("standup, 1-1, standup") == ["standup", "1-1"]
assert mod.normalize_tags(["Interview", "interview", ""]) == ["interview"]
print("transcript.test.py: ok")
