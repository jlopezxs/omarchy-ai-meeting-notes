# Meetings Notepad for Omarchy

Granola-style meeting notes on Omarchy: capture desktop and microphone audio with [Voxtype](https://voxtype.io/) meeting mode, live chunked transcription, markdown export, AI summary, and manual notes.

Inspired by [Granola](https://www.granola.ai/) — local, no meeting bot.

## Install

```bash
rm -rf ~/.config/omarchy/plugins/jlopezxs.meetings
cp -r omarchy-meetings-notepad-ai ~/.config/omarchy/plugins/jlopezxs.meetings
omarchy plugin enable jlopezxs.meetings --section right
```

## First launch

On first open, a **3-step onboarding** walks you through:

1. **What it does** — capture, transcribe, summarize, no meeting bot
2. **How it works** — Voxtype + PipeWire + Whisper + local Markdown
3. **Get set up** — **Install Voxtype** (opens the Omarchy installer) or **Get started** if already installed

Progress is saved to `~/.local/state/omarchy/meetings/onboarding.json`.

## Main screen

After onboarding:

- **Search** past meetings by title, tags, notes, summary, and transcript. Type `#standup` or click a tag chip to show only that type.
- **New meeting** — title, optional tags (`standup, 1-1`), then Create meeting (opens detail view)
- **Past meetings** — paginated list with relative time (`2 hours ago`), duration, `#tags`; arrows move between pages
- Tap a meeting to open the detail view

## Meeting detail

### While the meeting is active (draft or transcribing)

- **Start** — begins Voxtype transcription
- **Stop** — ends the meeting and saves transcript + AI summary
- **Your notes** — write manual notes below the controls (auto-saved)
- Status shows **Transcribing · MM:SS** while active
- **Settings** — gear icon in the header or the Settings row at the bottom of the list

During recording, the bar widget shows a duration badge and **Transcribing · MM:SS** in the tooltip.

Click the pin icon in the meeting header to **float** the notepad as a pinned window (stays on every workspace, like picture-in-picture). Click the bar calendar icon to focus it again, or **Dock** to return it to the bar panel.

### After you stop

The view switches to tabs:

- **Your notes** — only if you wrote notes during the meeting
- **Summary** — AI summary from the transcript
- **Transcript** — full meeting transcript

- Title, date/time, and **tags** in the header (add or click a chip to remove)
- **Start / Stop meeting**
- **Add notes** — creates `notes.md` (the “Your notes” tab appears once you save content)
- **Copy** menu — plain text or Markdown (notes + summary + transcript)
- Tabs: **Your notes** (hidden until notes exist), **Summary**, **Transcript**

During recording, the transcript tab shows live chunked output.

### Settings

| Setting | Purpose |
|---------|---------|
| Notes folder | Where meetings are saved (default `~/.local/state/omarchy/meetings/`) |
| Meetings per page | How many meetings fit on each list page (default 5). Older meetings are on the next pages. |
| Default language | Whisper language (`auto`, `es`, `en`, …) |
| Summary preprompt | Extra instructions prepended to the AI summary |
| Auto record when camera is active | Starts when `/dev/video*` is in use; stops when camera turns off |
| Agent skill | Install `/omarchy-meetings` **globally** so any agent can read your notes ([skills.sh](https://www.skills.sh/)) |

## Files per meeting

```
meta.json            # title, timestamps, tags
notes.md             # your manual notes (optional)
transcript.md
summary.md
chat.md              # Q&A history
live-transcript.md   # while recording
```

## Agent skill (`/omarchy-meetings`)

The plugin ships a [skills.sh](https://www.skills.sh/) skill at `skills/omarchy-meetings/`. It tells any agent how the widget works, where notes live, how to read them, and how **tags** group meetings of the same type (`standup`, `1-1`, …) via `meta.json`.

**From Settings:** open the notepad → gear → **Install globally**. That runs the skills CLI with `-g --agent '*'` so every detected agent (Cursor, Claude Code, Codex, …) can use it.

**From GitHub** (after the repo is published under `jlopezxs`):

```bash
npx skills add jlopezxs/omarchy-meetings-notepad-ai -g
```

[![skills.sh](https://skills.sh/b/jlopezxs/omarchy-meetings-notepad-ai)](https://skills.sh/jlopezxs/omarchy-meetings-notepad-ai)

## Requirements

- Omarchy 4 (Quickshell shell)
- Voxtype with meeting mode
- Default Omarchy agent for summaries (`omarchy default agent claude`)
- `wl-copy` for copy actions
- `fuser` for camera auto-toggle detection
- Node.js / `npx` to install the global agent skill from Settings

## Validate

```bash
./tests/validate.sh
```

## IPC

```bash
omarchy-shell shell call jlopezxs.meetings toggleRecording
omarchy-shell shell call jlopezxs.meetings startRecording "Standup"
omarchy-shell shell call jlopezxs.meetings stopRecording
```
