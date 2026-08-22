---
name: omarchy-meeting-notepad
description: >
  Consult Omarchy AI Meeting Notepad notes from any project. Use when the user
  asks about meetings they had, meeting notes, transcripts, summaries, action
  items from calls, Granola-style notes, Voxtype meetings, the Meetings bar
  widget, or /omarchy-meeting-notepad. Defaults to the latest meeting unless the user
  names another. When looking up a meeting, always read transcript.jsonl (or
  transcript.md) first, not the AI summary.
---

# AI Meeting Notepad

Read the user's local meeting notes captured by the **AI Meeting Notepad** Omarchy bar widget (`jlopezxs.meetings`). Capture and transcripts are files on disk. Optional AI summaries, if the user enabled them, go through the user's default Omarchy agent (which may be a remote provider).

Use this skill whenever the user asks what was said in a meeting, wants action items, or wants to search past calls.

## Defaults

- **Latest meeting unless told otherwise.** If the user does not name a date, title, person, or topic, open the most recent meeting (`startedAt` descending; skip drafts without a transcript). Do not ask which meeting they mean.
- **Transcript first, never the summary.** Search and quote from `transcript.jsonl` (one spoken turn per line). Fall back to `transcript.md` only if jsonl is missing. Do not use `summary.md` or `insights.json` as the source of what was said. Use `notes.md` only as extra user-written context. Use `summary.md` only if the user explicitly asks for the summary.

## Widget

The widget lives in the Omarchy shell bar (plugin id `jlopezxs.meetings`).

- Click the notepad icon to open the notepad. Transcription starts only from **Start transcribing** on a meeting.
- **New meeting** creates a draft folder, then **Start transcribing** captures desktop + microphone audio with [Voxtype](https://voxtype.io/) meeting mode (no meeting bot).
- While active: a **Your notes** editor that auto-saves. After **Stop**, the transcript is saved. An AI summary is written only if the user enabled AI summaries in Settings.
- After **Stop**: tabs for **Your notes**, **Summary**, and **Transcript**. Search covers title, notes, summary, and transcript.

IPC (optional, for controlling capture — not for reading notes):

```bash
omarchy-shell shell call jlopezxs.meetings toggleRecording
omarchy-shell shell call jlopezxs.meetings startRecording "Standup"
omarchy-shell shell call jlopezxs.meetings stopRecording
```

Do not start or stop recording unless the user asked.

## Where notes live

Default root:

```
~/.local/state/omarchy/meetings/
```

Override: widget Settings → **Notes folder**, stored as `notesDir` on the `jlopezxs.meetings` entry in `~/.config/omarchy/shell.json`. Empty/`""` means the default.

Resolve the root in this order:

1. Read `~/.config/omarchy/shell.json` and find the object with `"id": "jlopezxs.meetings"`.
2. If `notesDir` is a non-empty string, expand `~` and use that path.
3. Otherwise use `~/.local/state/omarchy/meetings`.

Widget setup state lives at `~/.local/state/omarchy/meetings-onboarding.json`, **not** inside the notes root. Ignore `onboarding.json` if you still see it under the notes folder.

## Folder layout

```
<notes-root>/
  index.jsonl              # catalog — one JSON object per meeting
  YYYYMMDD_HHmmss_slug/
    meta.json              # identity, ISO dates, speakers, stats
    transcript.jsonl       # one spoken turn per line — grep this
    transcript.md          # same content, human-readable
    notes.md               # optional personal notes
    summary.md             # optional AI recap (never search source)
    insights.json          # optional routing: actions, topics, people
    chat.md                # Q&A history (if the user asked the widget)
    live-transcript.md     # ephemeral live text while recording
    summary.error.txt      # present when summary generation failed
```

Folder name: local date + time + slug of the title, e.g. `20260821_173101_standup`. Same-second duplicates get `_2`, `_3`, …

A directory is a meeting **only** if it contains `meta.json`. `index.jsonl` is a file in the root, not a meeting.

### `index.jsonl`

One JSON object per line. Read this single file to pick a meeting. Do not walk every folder to list calls.

| Field | Meaning |
|-------|---------|
| `id` | Folder name (stable key) |
| `title` | Display title |
| `startedAt` | ISO-8601 UTC, e.g. `2026-08-22T13:31:01Z` |
| `durationSecs` | Length in seconds |
| `status` | `draft`, `recording`, or `completed` |
| `speakers` | Display names (`Me`, `Attendee 1`, …) |
| `language` | `es` / `en` / `auto` |
| `tags` | Topics if set |
| `path` | Folder to open next |
| `hasTranscript` | Skip drafts with no speech |
| `wordCount` | Cheap signal of substance |

### `meta.json`

Same identity as the catalog, plus unix seconds for the widget (`startedAt` / `endedAt`), ISO twins (`startedAtIso` / `endedAtIso`), `timezone`, `participants` (`id`, `name`, `role`: `self` or `remote`), `language`, `tags`, `topics`, `stats` (`wordCount`, `segmentCount`, `speakerCount`), and `voxtypeId` (implementation detail, not a search key).

### `transcript.jsonl`

One utterance per line. This is the file to grep.

```json
{"i":0,"t":"00:01:12","ms":72000,"speaker":"Me","speakerId":"self","text":"Ship billing API on Thursday"}
```

| Field | Use |
|-------|-----|
| `i` | Stable turn index for citations |
| `t` | Human timestamp (`HH:MM:SS`) |
| `ms` | Milliseconds from start |
| `speaker` | Display name after diarization |
| `speakerId` | Join to `meta.participants` (`self` or `attendee-n`) |
| `text` | Spoken words — grep / quote this |

Cite like: **Sprint Planning (2026-08-22) · Me · 00:01:12 — “Ship billing API on Thursday.”**

`transcript.md` is the same content for humans. Prefer jsonl.

### `insights.json`

Optional routing only (`decisions`, `actionItems`, `peopleMentioned`, `topics`, `openQuestions`). Use it to pick a meeting (“which call had billing actions?”), then confirm in `transcript.jsonl`. Never treat insights as what was said.

## How to consult meetings

1. Resolve the notes root (above).
2. **Pick meeting(s) from `index.jsonl`.** Filter title, ISO date, speaker, tag, `hasTranscript`. Sort by `startedAt` descending. Skip walking every folder.
3. **Find the quote in that folder’s `transcript.jsonl`.** Grep `text` and `speaker`. Skip `summary.md`, `chat.md`, `live-transcript.md`, and `insights.json` as evidence.
4. **Answer** with matching turns plus meta title/date. Do not dump the full transcript unless the user asked for the full text.
5. If `index.jsonl` or `transcript.jsonl` is missing (older folders), fall back to listing `meta.json` directories and reading `transcript.md`.

Read files with the Read/Grep tools.

Do not create, edit, or delete meeting files unless the user explicitly asked to change notes.

## Examples

- “What did we talk about?” / “What was the last meeting?” → latest `hasTranscript` row in `index.jsonl`, then `transcript.jsonl`.
- “What did we decide in yesterday’s standup?” → filter index by date + title, read `transcript.jsonl` (then `notes.md` if present). Do not use `summary.md`.
- “Find meetings about billing” → grep `transcript.jsonl` under the notes root (or filter index tags/title first).
- “Action items from the design review” → pick folder from index, extract from `transcript.jsonl`. `insights.json` may hint; confirm in the transcript.
- “Quote what Maria said about the API” → matching `transcript.jsonl` lines with that speaker.
- “Show me the summary of the last call” → latest meeting, then `summary.md` is allowed because they asked for the summary.
- “Calls with Ana” → filter `index.jsonl` `speakers` before opening folders.
