---
name: omarchy-meetings
description: >
  Consult Omarchy Meetings Notepad notes from any project. Use when the user
  asks about meetings they had, meeting notes, transcripts, summaries, action
  items from calls, Granola-style notes, Voxtype meetings, the Meetings bar
  widget, or /omarchy-meetings. Defaults to the latest meeting unless the user
  names another. When looking up a meeting, always read the original transcript
  first, not the AI summary.
---

# Omarchy Meetings

Read the user's local meeting notes captured by the **Meetings Notepad** Omarchy bar widget (`jlopezxs.meetings`). Notes are Markdown on disk — no API, no cloud.

Use this skill whenever the user asks what was said in a meeting, wants action items, or wants to search past calls.

## Defaults

- **Latest meeting unless told otherwise.** If the user does not name a date, title, person, or topic, open the most recent meeting (`startedAt` descending; skip drafts without a transcript). Do not ask which meeting they mean.
- **Transcript first, never the summary, when looking up a meeting.** Whenever the user is searching for, recalling, or asking about a meeting, read `transcript.md` (the original transcription). Do not use `summary.md` as the source of truth. The summary is AI-generated and may omit or distort what was said. Use `notes.md` only as extra user-written context after the transcript. Use `summary.md` only if the user explicitly asks for the summary.

## Widget

The widget lives in the Omarchy shell bar (plugin id `jlopezxs.meetings`).

- Click the notepad icon to open the notepad. Transcription starts only from **Start transcribing** on a meeting.
- **New meeting** creates a draft folder, then **Start transcribing** captures desktop + microphone audio with [Voxtype](https://voxtype.io/) meeting mode (no meeting bot).
- While active: a **Your notes** editor that auto-saves. After **Stop**, the transcript and AI summary are saved.
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

`onboarding.json` in the root is widget setup state, **not** a meeting. Ignore it.

## Folder layout

Each meeting is one directory:

```
<notes-root>/
  YYYY-MM-DD-<slug>/
    meta.json              # required — identity and timestamps
    notes.md               # optional personal notes
    transcript.md          # Whisper transcript after stop (or live export)
    summary.md             # AI summary
    chat.md                # Q&A history (if the user asked the widget)
    live-transcript.md     # ephemeral live text while recording
    summary.error.txt      # present when summary generation failed
```

Folder name: UTC date + slug of the title, e.g. `2026-08-21-standup`. Duplicates get `-2`, `-3`, …

A directory is a meeting **only** if it contains `meta.json`.

### `meta.json`

```json
{
  "title": "Standup",
  "startedAt": 1755792000,
  "endedAt": 1755792600,
  "durationSecs": 600,
  "voxtypeId": "uuid",
  "status": "completed",
  "createdAt": 1755792000,
  "exportedAt": 1755792610
}
```

| Field | Meaning |
|-------|---------|
| `title` | Display title |
| `startedAt` / `endedAt` / `createdAt` / `exportedAt` | Unix seconds |
| `durationSecs` | Length in seconds |
| `status` | `draft` (created, not recorded), `recording`, or `completed` |
| `voxtypeId` | Voxtype session id (optional) |

Drafts may omit `endedAt`, `durationSecs`, and transcript/summary files.

### Content files

- **transcript.md** — original Whisper transcription. **Always prioritize this** when the user is looking up a meeting. Speakers are `You` / `Me` vs `Remote` / `Attendee N`; timestamps look like `*[00:00]*`.
- **notes.md** — what the user typed. Extra context after the transcript, not a substitute for it.
- **summary.md** — AI recap. Do **not** use it when searching or answering from a meeting unless the user asked for the summary.
- **chat.md** — later Q&A with the widget's agent, not part of the original meeting.

## How to consult meetings

1. Resolve the notes root (above).
2. List subdirectories that contain `meta.json`. Sort by `startedAt` descending.
3. **Pick the meeting(s):**
   - No name/date/topic → latest completed meeting (has `transcript.md` or `status: completed`).
   - Named date, title, person, or topic → filter to that, then take the latest match.
4. **Read `transcript.md` first.** Answer from the original transcript. Then optionally `notes.md`. Skip `summary.md` unless the user asked for it.
5. To search across meetings, grep `transcript.md` and titles/`meta.json` first (skip `onboarding.json` and `summary.md`). Only widen to `notes.md` if the transcript hits are not enough.

Read files with the Read/Grep tools. Do not dump entire transcripts unless the user asked for the full text.

Do not create, edit, or delete meeting files unless the user explicitly asked to change notes.

## Examples

- “What did we talk about?” / “What was the last meeting?” → latest meeting, read `transcript.md`.
- “What did we decide in yesterday’s standup?” → matching folder, read `transcript.md` (then `notes.md` if present). Do not use `summary.md`.
- “Find meetings about billing” → grep `transcript.md` under the notes root, then open the matching transcript.
- “Action items from the design review” → folder whose title/slug matches, extract them from `transcript.md`.
- “Quote what Maria said about the API” → `transcript.md` for that meeting.
- “Show me the summary of the last call” → latest meeting, then `summary.md` is allowed because they asked for the summary.
