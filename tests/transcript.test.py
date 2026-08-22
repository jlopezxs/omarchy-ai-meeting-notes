#!/usr/bin/env python3
from __future__ import annotations

import importlib.machinery
import importlib.util
import json
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
assert mod.live_transcript_is_empty("_No speech was captured in this meeting._\n")
assert mod.live_transcript_is_empty(
    "# Meeting\n\n## Transcript\n\n_No speech was captured in this meeting._\n"
)
assert not mod.live_transcript_is_empty("**Me** *[00:00]* hola")

assert mod.iso_from_unix(0) == ""
assert mod.iso_from_unix(1755792000) == "2025-08-21T16:00:00Z"
assert mod.format_timestamp_hms(72000) == "00:01:12"
assert mod.speaker_id_for_label("You") == "self"
assert mod.speaker_id_for_label("Attendee 1") == "attendee-1"

voxtype_md = """# Sprint Planning

## Meeting Info

- **Word Count:** 7
- **Segments:** 1

## Transcript

### You

*[00:00]* Ship billing API on Thursday
"""
turns = mod.turns_from_markdown(voxtype_md)
assert len(turns) == 1
assert turns[0]["speaker"] == "Me"
assert turns[0]["speakerId"] == "self"
assert turns[0]["t"] == "00:00:00"
assert "billing" in turns[0]["text"]

inline_turns = mod.turns_from_markdown("**Attendee 1** *[01:12]* Hello there")
assert len(inline_turns) == 1
assert inline_turns[0]["speaker"] == "Attendee 1"
assert inline_turns[0]["t"] == "00:01:12"

segment_turns = mod.turns_from_segments(
    [{"text": "hola", "source": "microphone", "speaker_id": "You", "start_ms": 0}]
)
assert segment_turns[0]["speaker"] == "Me"
assert segment_turns[0]["speakerId"] == "self"

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
original_legacy = mod.LEGACY_ONBOARDING_FILE
mod.ONBOARDING_FILE = onboarding_file
mod.LEGACY_ONBOARDING_FILE = onboarding_dir / "legacy-onboarding.json"
try:
    assert mod.onboarding_complete() is True
    mod.reset_onboarding()
    assert onboarding_file.is_file() is False
    assert mod.onboarding_complete() is False
finally:
    mod.ONBOARDING_FILE = original_onboarding
    mod.LEGACY_ONBOARDING_FILE = original_legacy

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
    assert (notes_root / "index.jsonl").is_file()
    assert (notes_root / "index.jsonl").read_text(encoding="utf-8") == ""
finally:
    mod.RUNTIME.settings = original_settings
    mod.RUNTIME.recording_pending = original_recording
    mod.query_active_meeting = original_query
    mod.emit = original_emit

catalog_root = Path(tempfile.mkdtemp(prefix="meetings-catalog-"))
meeting = catalog_root / "2026-08-22-sprint-planning"
meeting.mkdir()
(meeting / "transcript.md").write_text(voxtype_md, encoding="utf-8")
(meeting / "meta.json").write_text(
    '{"title": "Sprint Planning", "startedAt": 1755792000, "status": "completed", "notesDir": "/old"}\n',
    encoding="utf-8",
)
catalog_settings = mod.Settings(notes_dir=str(catalog_root), whisper_language="es")
mod.migrate_notes_root(catalog_settings)
meta = json.loads((meeting / "meta.json").read_text(encoding="utf-8"))
assert "notesDir" not in meta
assert meta["id"] == "2026-08-22-sprint-planning"
assert meta["startedAtIso"].endswith("Z")
assert meta["language"] == "es"
assert meta["participants"][0]["id"] == "self"
assert meta["stats"]["segmentCount"] == 1
jsonl = (meeting / "transcript.jsonl").read_text(encoding="utf-8").strip()
assert jsonl
turn = json.loads(jsonl.splitlines()[0])
assert turn["speaker"] == "Me"
assert "billing" in turn["text"]
index_line = (catalog_root / "index.jsonl").read_text(encoding="utf-8").strip()
record = json.loads(index_line)
assert record["id"] == "2026-08-22-sprint-planning"
assert record["hasTranscript"] is True
assert "Me" in record["speakers"]
insights = json.loads((meeting / "insights.json").read_text(encoding="utf-8"))
assert "Me" in insights["peopleMentioned"]

print("transcript.test.py: ok")
