<div align="center">

# 📝 AI Meeting Notepad for Omarchy

> *"Granola-style notes — local, no meeting bot."*

**AI Meeting Notepad** for the **Omarchy** bar — capture desktop and microphone audio with [Voxtype](https://voxtype.io/),  
Markdown on disk, AI summary, and your own notes. Inspired by [Granola](https://www.granola.ai/).

<br>

![AI Meeting Notepad for Omarchy preview](preview.png)

</div>

## Install

```bash
omarchy plugin add https://github.com/jlopezxs/omarchy-ai-meetings-notes.git --enable
```

`--enable` puts it straight into the bar's right section. Without it, add it later via **Omarchy menu → Bar → Widgets**, or with:

```bash
omarchy plugin enable jlopezxs.meetings --section right
```

Or develop from a checkout:

```bash
rm -rf ~/.config/omarchy/plugins/jlopezxs.meetings
cp -r omarchy-meetings-notepad-ai ~/.config/omarchy/plugins/jlopezxs.meetings
omarchy plugin enable jlopezxs.meetings --section right
```

### Uninstall

```bash
omarchy plugin remove jlopezxs.meetings
```

---

## ✨ Features


| | Feature | Description |
|:---:|:---|:---|
| 🎙️ | **Capture** | Desktop + microphone via [Voxtype](https://voxtype.io/) meeting mode — nothing joins the call |
| 📝 | **Transcript** | Whisper transcript saved when you stop the meeting |
| ✨ | **AI summary** | Summarize with your default Omarchy agent when you stop |
| 📋 | **Your notes** | Manual notes auto-saved next to the transcript |
| 🔍 | **Search** | Find by title, notes, summary, or transcript |
| 📌 | **Float** | Pin the notepad as a picture-in-picture window on every workspace |
| 🤖 | **Agent skill** | `/omarchy-meeting-notepad` so any agent can read your notes ([skills.sh](https://www.skills.sh/)) |
| 💾 | **Markdown on disk** | One folder per meeting — no cloud, no API |

---

## First launch

On first open, a **3-step onboarding** walks you through:

1. **What it does** — capture, transcribe, summarize, no meeting bot
2. **How it works** — Voxtype + PipeWire + Whisper + local Markdown
3. **Get set up** — **Install Voxtype** (opens the Omarchy installer) or **Get started** if already installed

Progress is saved to `~/.local/state/omarchy/meetings-onboarding.json`.

## Using it

**Search** past meetings by title, notes, summary, and transcript.

**New meeting** — enter a title, then Create meeting.

**Past meetings** — paginated list with relative time (`2 hours ago`) and duration. Tap a meeting to open the detail view.

While a meeting is active (draft or transcribing):

- **Start transcribing** on a meeting begins Voxtype transcription; **Stop** ends the meeting and saves transcript + AI summary
- **Your notes** auto-save below the controls
- Status shows **Transcribing · MM:SS**; the bar widget shows a duration badge
- Click the pin icon to **float** the notepad; **Dock** returns it to the bar panel

After you stop, the view switches to tabs: **Your notes** (once you have notes), **Summary**, and **Transcript**. The header has title, date/time, **Add notes**, and a **Copy** menu (plain text or Markdown).

## ⚙️ Settings

| Setting | Purpose |
|---------|---------|
| Notes folder | Where meetings are saved (default `~/.local/state/omarchy/meetings/`) |
| Meetings per page | How many meetings fit on each list page (default 5) |
| Default language | Whisper language (`auto`, `es`, `en`, …) |
| Summary preprompt | Extra instructions prepended to the AI summary |
| Agent skill | Install `/omarchy-meeting-notepad` **globally** so any agent can read your notes |

## Files

```
<notes-root>/
  index.jsonl            # catalog for agents — one meeting per line
  YYYY-MM-DD-slug/
    meta.json            # title, ISO + unix times, speakers, stats
    transcript.jsonl     # one spoken turn per line (grep / cite this)
    transcript.md        # same content, human-readable
    notes.md             # your manual notes (optional)
    summary.md           # AI recap (not the search source)
    insights.json        # optional actions / topics / people
    chat.md              # Q&A history
    live-transcript.md   # while recording
```

## Agent skill (`/omarchy-meeting-notepad`)

The plugin ships a [skills.sh](https://www.skills.sh/) skill at `skills/omarchy-meeting-notepad/`. It tells any agent how the widget works, where notes live, and how to read them.

**From Settings:** open the notepad → gear → **Install globally** (or **Already installed** to reinstall). That opens a terminal and runs the skills CLI with `-g --agent '*'` so every detected agent (Cursor, Claude Code, Codex, …) can use it.

**From GitHub:**

```bash
npx skills add jlopezxs/omarchy-ai-meetings-notes -g --skill omarchy-meeting-notepad --agent '*'
```

The skill lives at [`skills/omarchy-meeting-notepad`](https://github.com/jlopezxs/omarchy-ai-meetings-notes/tree/main/skills/omarchy-meeting-notepad) in the plugin repo.

[![skills.sh](https://skills.sh/b/jlopezxs/omarchy-ai-meetings-notes)](https://skills.sh/jlopezxs/omarchy-ai-meetings-notes)

## Requirements

- Omarchy 4 (Quickshell shell)
- Voxtype with meeting mode
- Default Omarchy agent for summaries (`omarchy default agent claude`)
- `wl-copy` for copy actions
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

## Screenshots

| Meetings list | Transcribing | Detail view |
|:---:|:---:|:---:|
| ![Meetings list](media/preview-list.png) | ![Transcribing](media/preview-transcribing.png) | ![Detail view](media/preview-2.png) |

## Attribution

- Inspired by [Granola](https://www.granola.ai/) — local meeting notes, no bot in the call
- Capture and transcription via [Voxtype](https://voxtype.io/) meeting mode
- README intro style inspired by [One Dark Pro Darker](https://github.com/jlopezxs/omarchy-one-dark-pro-darker-theme)
