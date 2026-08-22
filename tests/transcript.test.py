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
assert mod.ask_agent_skill_prompt() == "/omarchy-meetings\n\n"
assert mod.ask_agent_launch_prompt("Meeting 23423", 1755792000).startswith("/omarchy-meetings Meeting 23423 · ")
assert mod.normalize_tag("#Standup") == "standup"
assert mod.normalize_tag("1:1") == "1-1"
assert mod.normalize_tags("standup, 1-1, standup") == ["standup", "1-1"]
assert mod.normalize_tags(["Interview", "interview", ""]) == ["interview"]

agents_marker = Path.home() / ".agents" / "skills" / "omarchy-meetings" / "SKILL.md"
claude_marker = Path.home() / ".claude" / "skills" / "omarchy-meetings" / "SKILL.md"
assert agents_marker in mod.SKILL_MARKER_PATHS
assert any(path.name == "SKILL.md" and path.parent.name == "omarchy-meetings" for path in mod.SKILL_MARKER_PATHS)
if agents_marker.is_file() or claude_marker.is_file():
    assert mod.skill_is_installed(), "global omarchy-meetings skill is present but not detected"

import tempfile

onboarding_dir = Path(tempfile.mkdtemp(prefix="meetings-onboarding-"))
onboarding_file = onboarding_dir / "onboarding.json"
onboarding_file.write_text('{"complete": true}\n', encoding="utf-8")
original_onboarding = mod.ONBOARDING_FILE
mod.ONBOARDING_FILE = onboarding_file
try:
    assert mod.onboarding_complete() is True
    mod.reset_onboarding()
    assert onboarding_file.is_file() is False
    assert mod.onboarding_complete() is False
finally:
    mod.ONBOARDING_FILE = original_onboarding

notes_root = Path(tempfile.mkdtemp(prefix="meetings-delete-all-"))
meeting_a = notes_root / "meeting-a"
meeting_b = notes_root / "meeting-b"
for folder in (meeting_a, meeting_b):
    folder.mkdir()
    (folder / "meta.json").write_text('{"title": "x", "status": "completed"}\n', encoding="utf-8")
(notes_root / "onboarding.json").write_text('{"complete": true}\n', encoding="utf-8")
(notes_root / "notes.md").write_text("keep\n", encoding="utf-8")
settings = mod.Settings(notes_dir=str(notes_root))
original_settings = mod.RUNTIME.settings
original_recording = mod.RUNTIME.recording_pending
original_query = mod.query_active_meeting
original_emit = mod.emit
mod.RUNTIME.settings = settings
mod.RUNTIME.recording_pending = False
mod.query_active_meeting = lambda: None
mod.emit = lambda payload: None
try:
    mod.cmd_delete_all_meetings({})
    assert meeting_a.is_dir() is False
    assert meeting_b.is_dir() is False
    assert (notes_root / "onboarding.json").is_file()
    assert (notes_root / "notes.md").is_file()
finally:
    mod.RUNTIME.settings = original_settings
    mod.RUNTIME.recording_pending = original_recording
    mod.query_active_meeting = original_query
    mod.emit = original_emit

print("transcript.test.py: ok")
