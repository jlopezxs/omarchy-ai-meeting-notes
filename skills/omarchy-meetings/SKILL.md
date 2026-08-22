---
name: omarchy-meetings
description: >
  Consult Omarchy Meetings Notepad notes from any project. Use when the user
  asks about meetings they had, meeting notes, transcripts, summaries, action
  items from calls, Granola-style notes, Voxtype meetings, the Meetings bar
  widget, /omarchy-meetings, or meetings grouped by tag/type (standups, 1-1s,
  interviews). Defaults to the latest meeting unless the user names another.
  When looking up a meeting, always read the original transcript first, not
  the AI summary. When the user asks for meetings of the same type, filter by
  meta.json tags first.
---

# Omarchy Meetings

Read the user's local meeting notes captured by the **Meetings Notepad** Omarchy bar widget (`jlopezxs.meetings`). Notes are Markdown on disk — no API, no cloud.

Use this skill whenever the user asks what was said in a meeting, wants action items, wants to search past calls, or wants meetings of the same type (standups, 1-1s, interviews, and so on).

## Defaults

- **Latest meeting unless told otherwise.** If the user does not name a date, title, person, topic, or tag, open the most recent meeting (`startedAt` descending; skip drafts without a transcript). Do not ask which meeting they mean.
- **Transcript first, never the summary, when looking up a meeting.** Whenever the user is searching for, recalling, or asking about a meeting, read `transcript.md` (the original transcription). Do not use `summary.md` as the source of truth. The summary is AI-generated and may omit or distort what was said. Use `notes.md` only as extra user-written context after the transcript. Use `summary.md` only if the user explicitly asks for the summary.
- **Tags group meetings by type.** If the user asks for standups, 1-1s, interviews, or “meetings like this one”, filter `meta.json` `tags` first. Do not rely on the title alone.

## Widget

The widget lives in the Omarchy shell bar (plugin id `jlopezxs.meetings`).

- Click the calendar icon to open the notepad. Middle-click starts/stops transcription.
- **New meeting** creates a draft folder (optional comma-separated tags), then **Start transcribing** captures desktop + microphone audio with [Voxtype](https://voxtype.io/) meeting mode (no meeting bot).
- While active: live chunked Whisper transcript, optional live AI summary, and a **Your notes** editor that auto-saves.
- After **Stop**: tabs for **Your notes**, **Summary**, and **Transcript**. Search covers title, tags, notes, summary, and transcript. Click a `#tag` chip in the list to show only meetings with that tag.

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
    meta.json              # required — identity, timestamps, and tags
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
  "tags": ["standup"],
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
| `tags` | User labels for grouping by type. Slugs: lowercase `a-z0-9-`, max 32 chars, max 8 tags. Empty or missing on older meetings. |
| `voxtypeId` | Voxtype session id (optional) |

Drafts may omit `endedAt`, `durationSecs`, and transcript/summary files.

### Tags (grouping by type)

Tags are **how the user groups meetings of the same kind**. They are not speakers, dates, or free-text search.

Typical values: `standup`, `1-1`, `interview`, `design-review`, `customer`. The widget stores them on `meta.json` and shows them as `#standup` chips. A `#tag` search in the notepad is an exact tag filter.

**When to use tags**

- “All my standups”, “1-1s this week”, “meetings tagged hiring”, “other meetings like this one”
- Any request that is about **type / series / category**, not a single named meeting

**How to filter**

1. Resolve the notes root (above).
2. List subdirectories that contain `meta.json`.
3. Normalize the requested type the same way the widget does: lowercase, strip `#`, replace non-alphanumerics with `-` (`1:1` and `1-1` both become `1-1`).
4. Keep meetings whose `tags` array contains that slug. Missing `tags` means untagged — do not guess from the title unless zero meetings have that tag.
5. Then apply date / person / topic filters. Sort by `startedAt` descending.
6. For each match, **read `transcript.md` first** (same rule as a single meeting).

Do not invent tags. If none of the meetings have `tags`, say so and fall back to title/transcript search.

If the user points at the current/latest meeting and asks for others of the same type, read that meeting’s `tags` and reuse them.

### Content files

- **transcript.md** — original Whisper transcription. **Always prioritize this** when the user is looking up a meeting. Speakers are `You` / `Me` vs `Remote` / `Attendee N`; timestamps look like `*[00:00]*`.
- **notes.md** — what the user typed. Extra context after the transcript, not a substitute for it.
- **summary.md** — AI recap. Do **not** use it when searching or answering from a meeting unless the user asked for the summary.
- **chat.md** — later Q&A with the widget's agent, not part of the original meeting.

## How to consult meetings

1. Resolve the notes root (above).
2. List subdirectories that contain `meta.json`. Sort by `startedAt` descending.
3. **Pick the meeting(s):**
   - No name/date/tag → latest completed meeting (has `transcript.md` or `status: completed`).
   - Named type (`standup`, `1-1`, …) → filter `meta.json` `tags` first, then take the requested set (or the latest match).
   - Named date, title, person, or topic → filter to that, then take the latest match.
4. **Read `transcript.md` first.** Answer from the original transcript. Then optionally `notes.md`. Skip `summary.md` unless the user asked for it.
5. To search across meetings, grep `transcript.md` and titles/`meta.json` (including `tags`) first (skip `onboarding.json` and `summary.md`). Only widen to `notes.md` if the transcript hits are not enough.

Read files with the Read/Grep tools. Do not dump entire transcripts unless the user asked for the full text.

Do not create, edit, or delete meeting files unless the user explicitly asked to change notes.

## Examples

- “What did we talk about?” / “What was the last meeting?” → latest meeting, read `transcript.md`.
- “What did we decide in yesterday’s standup?” → matching folder, read `transcript.md` (then `notes.md` if present). Do not use `summary.md`.
- “Find meetings about billing” → grep `transcript.md` under the notes root, then open the matching transcript.
- “All my standups” / “meetings tagged standup” → folders whose `meta.json` `tags` contain `standup`.
- “Other 1-1s like this one” → read the current meeting’s `tags`, then list other folders with the same tag.
- “Action items from the design review” → folder whose title/slug or `design-review` tag matches, extract them from `transcript.md`.
- “Quote what Maria said about the API” → `transcript.md` for that meeting.
- “Show me the summary of the last call” → latest meeting, then `summary.md` is allowed because they asked for the summary.
