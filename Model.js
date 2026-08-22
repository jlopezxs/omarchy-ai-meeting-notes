// Pure helpers for the meetings notepad panel. No QML types.

var MEETING_ICON = "󱘓" // nf-md-notebook-plus-outline

function meetingIcon() {
  return MEETING_ICON
}

function elide(text, max) {
  var value = String(text || "").replace(/\s+/g, " ").trim()
  if (max === undefined) max = 140
  return value.length > max ? value.substring(0, max - 1) + "…" : value
}

function compactMarkdownHeadings(markdown) {
  return String(markdown || "").replace(/^(#{1,6})(\s+)/gm, function(_, hashes, space) {
    var n = Math.min(6, hashes.length + 2)
    var out = ""
    for (var i = 0; i < n; i++) out += "#"
    return out + space
  })
}

function escapeHtml(text) {
  return String(text || "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
}

function inlineMarkdownToHtml(text) {
  var html = escapeHtml(text)
  html = html.replace(/\*\*(.+?)\*\*/g, "<b>$1</b>")
  html = html.replace(/\*(.+?)\*/g, "<i>$1</i>")
  html = html.replace(/`(.+?)`/g, "<code>$1</code>")
  return html
}

function headingStyle(level, isFirst, headingPx, bodyPx) {
  var size = level <= 1 ? headingPx : bodyPx
  var top = isFirst ? 8 : (level <= 1 ? 18 : 16)
  var bottom = level <= 1 ? 10 : 8
  return "margin-top:" + top + "px;margin-bottom:" + bottom + "px;font-size:" + size + "px;"
}

function markdownToPreviewHtml(markdown, headingPx, bodyPx) {
  var hPx = Math.max(1, Math.floor(Number(headingPx) || 13))
  var bPx = Math.max(1, Math.floor(Number(bodyPx) || 11))
  var lines = String(markdown || "").replace(/\r\n/g, "\n").split("\n")
  var html = []
  var firstHeading = true
  var i = 0
  while (i < lines.length) {
    var line = lines[i]
    var heading = /^(#{1,6})\s+(.*)$/.exec(line)
    if (heading) {
      html.push(
        "<p style=\"" + headingStyle(heading[1].length, firstHeading, hPx, bPx) + "\"><b>" +
        inlineMarkdownToHtml(heading[2]) +
        "</b></p>"
      )
      firstHeading = false
      i += 1
      continue
    }
    var unordered = /^\s*[-*]\s+(.*)$/.exec(line)
    var ordered = /^\s*(\d+)\.\s+(.*)$/.exec(line)
    if (unordered || ordered) {
      while (i < lines.length) {
        unordered = /^\s*[-*]\s+(.*)$/.exec(lines[i])
        ordered = /^\s*(\d+)\.\s+(.*)$/.exec(lines[i])
        if (!unordered && !ordered) break
        var marker = unordered ? "•" : (ordered[1] + ".")
        var item = unordered ? unordered[1] : ordered[2]
        html.push(
          "<p style=\"margin-top:2px;margin-bottom:2px;margin-left:10px;font-size:" + bPx + "px;\">" +
          marker + " " + inlineMarkdownToHtml(item) +
          "</p>"
        )
        i += 1
      }
      continue
    }
    if (String(line).trim() === "") {
      i += 1
      continue
    }
    html.push(
      "<p style=\"margin-top:4px;margin-bottom:4px;font-size:" + bPx + "px;\">" +
      inlineMarkdownToHtml(line) +
      "</p>"
    )
    i += 1
  }
  return html.join("")
}

function formatDuration(seconds) {
  var total = Math.max(0, Math.floor(Number(seconds) || 0))
  var h = Math.floor(total / 3600)
  var m = Math.floor((total % 3600) / 60)
  var s = total % 60
  if (h > 0) return h + ":" + String(m).padStart(2, "0") + ":" + String(s).padStart(2, "0")
  return String(m).padStart(2, "0") + ":" + String(s).padStart(2, "0")
}

function formatDateTime(timestamp) {
  var ts = Number(timestamp) || 0
  if (ts <= 0) return ""
  var d = new Date(ts * 1000)
  var date = d.toLocaleDateString(undefined, { weekday: "short", year: "numeric", month: "short", day: "numeric" })
  var time = d.toLocaleTimeString(undefined, { hour: "2-digit", minute: "2-digit" })
  return date + " · " + time
}

function meetingCreatedAtLabel(state) {
  if (!state || typeof state !== "object") return ""
  return formatDateTime(state.startedAt || 0)
}

function findMeetingByPath(meetings, path) {
  var target = String(path || "").trim()
  if (target === "") return null
  var list = Array.isArray(meetings) ? meetings : []
  for (var i = 0; i < list.length; i++) {
    if (String(list[i].path || "") === target) return list[i]
  }
  return null
}

function detailHeaderTitle(state, entry, titleDraftFallback) {
  var path = state && state.meetingPath ? String(state.meetingPath) : ""
  if (path !== "" && state.title) return String(state.title)
  if (entry && entry.title) return String(entry.title)
  return String(titleDraftFallback || "Meeting")
}

function detailHeaderSubtitle(state, entry) {
  var parts = []
  var startedAt = 0
  if (state && state.startedAt > 0) startedAt = Number(state.startedAt) || 0
  else if (entry && entry.startedAt > 0) startedAt = Number(entry.startedAt) || 0
  var when = formatDateTime(startedAt)
  if (when) parts.push(when)

  if (state && state.recordingThisMeeting) {
    parts.push("Transcribing")
    if (state.speakerCount > 0)
      parts.push(String(state.speakerCount) + " speaker" + (state.speakerCount === 1 ? "" : "s"))
  }
  else if (state && state.meetingFinished) parts.push("Completed")
  else if (state && state.meetingDraft) parts.push("Draft")
  else if (entry && entry.isRecording) parts.push("Transcribing")
  else if (entry && entry.isDraft) parts.push("Draft")
  else if (entry && (entry.hasTranscript || entry.hasSummary)) parts.push("Completed")

  return parts.join(" · ")
}

function normalizeMeeting(entry) {
  var item = (entry && typeof entry === "object") ? entry : {}
  return {
    id: String(item.id || item.path || ""),
    path: String(item.path || ""),
    title: String(item.title || "Untitled meeting"),
    startedAt: Number(item.startedAt) || 0,
    endedAt: Number(item.endedAt) || 0,
    durationSecs: Number(item.durationSecs) || 0,
    voxtypeId: item.voxtypeId ? String(item.voxtypeId) : "",
    hasSummary: item.hasSummary === true,
    hasTranscript: item.hasTranscript !== false,
    hasNotes: item.hasNotes === true,
    isDraft: item.isDraft === true,
    isRecording: item.isRecording === true,
    tags: normalizeTags(item.tags),
    searchText: String(item.searchText || "")
  }
}

function normalizeChatMessage(entry) {
  var item = (entry && typeof entry === "object") ? entry : {}
  return {
    role: String(item.role || "assistant"),
    text: String(item.text || ""),
    timestamp: Number(item.timestamp) || 0
  }
}

function parseState(raw) {
  var text = String(raw || "").trim()
  if (!text) return emptyState("no output")
  try {
    var data = JSON.parse(text)
    if (!data || typeof data !== "object") throw new Error("not an object")
    var meetings = Array.isArray(data.meetings) ? data.meetings.map(normalizeMeeting) : []
    var chat = Array.isArray(data.chat) ? data.chat.map(normalizeChatMessage) : []
    return {
      ok: data.ok !== false,
      error: data.error ? String(data.error) : "",
      recording: data.recording === true,
      recordingThisMeeting: data.recordingThisMeeting === true,
      recordingMeetingPath: data.recordingMeetingPath ? String(data.recordingMeetingPath) : "",
      paused: data.paused === true,
      voxtypeReady: data.voxtypeReady !== false,
      voxtypeMeetingEnabled: data.voxtypeMeetingEnabled !== false,
      defaultAgent: data.defaultAgent ? String(data.defaultAgent) : "",
      title: data.title ? String(data.title) : "",
      meetingId: data.meetingId ? String(data.meetingId) : "",
      meetingPath: data.meetingPath ? String(data.meetingPath) : "",
      startedAt: Number(data.startedAt) || 0,
      endedAt: Number(data.endedAt) || 0,
      durationSecs: Number(data.durationSecs) || 0,
      chunkCount: Number(data.chunkCount) || 0,
      pendingChunks: Number(data.pendingChunks) || 0,
      chunkSeconds: normalizeChunkSeconds(data.chunkSeconds),
      liveTranscript: data.liveTranscript ? String(data.liveTranscript) : "",
      speakerCount: Number(data.speakerCount) || 0,
      summary: data.summary ? String(data.summary) : "",
      summaryRefreshing: data.summaryRefreshing === true,
      transcript: data.transcript ? String(data.transcript) : "",
      notes: data.notes ? String(data.notes) : "",
      hasNotes: data.hasNotes === true,
      tags: normalizeTags(data.tags),
      meetingDraft: data.meetingDraft === true,
      meetingFinished: data.meetingFinished === true,
      notesDir: data.notesDir ? String(data.notesDir) : "",
      summaryPreprompt: data.summaryPreprompt ? String(data.summaryPreprompt) : "",
      whisperLanguage: data.whisperLanguage ? String(data.whisperLanguage) : "",
      onboardingComplete: data.onboardingComplete === true,
      skillInstalled: data.skillInstalled === true,
      skillInstallError: data.skillInstallError ? String(data.skillInstallError) : "",
      meetings: meetings,
      chat: chat,
      busy: data.busy === true,
      busyLabel: data.busyLabel ? String(data.busyLabel) : ""
    }
  } catch (e) {
    return emptyState("invalid helper output")
  }
}

function emptyState(error) {
  return {
    ok: false,
    error: error || "",
    recording: false,
    recordingThisMeeting: false,
    recordingMeetingPath: "",
    paused: false,
    voxtypeReady: false,
    voxtypeMeetingEnabled: false,
    defaultAgent: "",
    title: "",
    meetingId: "",
    meetingPath: "",
    startedAt: 0,
    endedAt: 0,
    durationSecs: 0,
    chunkCount: 0,
    pendingChunks: 0,
    chunkSeconds: 30,
    liveTranscript: "",
    speakerCount: 0,
    summary: "",
    summaryRefreshing: false,
    transcript: "",
    notes: "",
    hasNotes: false,
    tags: [],
    meetingDraft: false,
    meetingFinished: false,
    notesDir: "",
    summaryPreprompt: "",
    whisperLanguage: "",
    onboardingComplete: false,
    skillInstalled: false,
    skillInstallError: "",
    meetings: [],
    chat: [],
    busy: false,
    busyLabel: ""
  }
}

function normalizeBool(value, fallback) {
  if (value === true || value === false) return value
  if (value === "true" || value === 1 || value === "1") return true
  if (value === "false" || value === 0 || value === "0") return false
  return fallback === true
}

function barBadgeText(state) {
  if (!state || typeof state !== "object") return ""
  if (state.recording) return ""
  if (state.pendingChunks > 0) return "…"
  return ""
}

function barTooltip(state) {
  if (!state || typeof state !== "object") return "Meetings — notes from audio"
  if (state.recording) return "Transcribing — click to open"
  if (state.busy) return String(state.busyLabel || "Working…")
  return "Open meeting notepad"
}

function meetingLabel(entry) {
  if (!entry) return ""
  return elide(entry.title, 48)
}

function formatUserError(message) {
  var text = String(message || "").trim()
  if (text === "") return ""
  if (text.indexOf("Permission denied") >= 0 || text.indexOf("Cannot create notes folder") >= 0) {
    return "Cannot write to the notes folder. Choose a writable path in Settings."
  }
  if (text.indexOf("Traceback") >= 0) {
    var lines = text.split("\n")
    for (var i = lines.length - 1; i >= 0; i--) {
      var line = String(lines[i] || "").trim()
      if (line !== "") return elide(line, 180)
    }
  }
  return elide(text, 180)
}

function formatRelativeTime(timestamp, nowSeconds) {
  var ts = Number(timestamp) || 0
  if (ts <= 0) return ""
  var now = Number(nowSeconds) || Math.floor(Date.now() / 1000)
  var delta = Math.max(0, now - ts)
  if (delta < 60) return "just now"
  if (delta < 3600) {
    var mins = Math.floor(delta / 60)
    return mins === 1 ? "1 minute ago" : mins + " minutes ago"
  }
  if (delta < 86400) {
    var hours = Math.floor(delta / 3600)
    return hours === 1 ? "1 hour ago" : hours + " hours ago"
  }
  if (delta < 604800) {
    var days = Math.floor(delta / 86400)
    return days === 1 ? "yesterday" : days + " days ago"
  }
  if (delta < 2592000) {
    var weeks = Math.floor(delta / 604800)
    return weeks === 1 ? "1 week ago" : weeks + " weeks ago"
  }
  return formatDateTime(ts)
}

function normalizeTag(value) {
  var text = String(value || "").trim().toLowerCase().replace(/#/g, "")
  text = text.replace(/[^a-z0-9]+/g, "-").replace(/-+/g, "-").replace(/^-|-$/g, "")
  if (text.length > 32) text = text.substring(0, 32).replace(/-$/g, "")
  return text
}

function normalizeTags(value) {
  var raw = []
  if (Array.isArray(value)) {
    for (var i = 0; i < value.length; i++) raw.push(String(value[i] || ""))
  } else if (value !== undefined && value !== null && String(value).trim() !== "") {
    raw = String(value).split(/[,;\n]+/)
  }
  var out = []
  var seen = {}
  for (var j = 0; j < raw.length; j++) {
    var tag = normalizeTag(raw[j])
    if (!tag || seen[tag]) continue
    seen[tag] = true
    out.push(tag)
    if (out.length >= 8) break
  }
  return out
}

function meetingSearchHaystack(item) {
  if (!item) return ""
  return (
    String(item.title || "") + "\n" +
    String(item.id || "") + "\n" +
    String(item.searchText || "")
  ).toLowerCase()
}

function filterMeetings(meetings, query) {
  var list = Array.isArray(meetings) ? meetings : []
  var raw = String(query || "").trim()
  if (raw === "") return list
  var needle = raw.toLowerCase()
  var out = []
  for (var i = 0; i < list.length; i++) {
    var item = list[i]
    if (!item) continue
    if (meetingSearchHaystack(item).indexOf(needle) >= 0)
      out.push(item)
  }
  return out
}

function meetingsForList(meetings, query, max, page) {
  var filtered = filterMeetings(meetings, query)
  var size = normalizeListMeetingsMax(max)
  var safePage = normalizeListPage(page, filtered.length, size)
  var start = safePage * size
  return filtered.slice(start, start + size)
}

function startOfLocalDay(timestamp) {
  var ts = Number(timestamp) || 0
  if (ts <= 0) return 0
  var d = new Date(ts * 1000)
  d.setHours(0, 0, 0, 0)
  return Math.floor(d.getTime() / 1000)
}

function formatDurationShort(seconds) {
  var total = Math.max(0, Math.floor(Number(seconds) || 0))
  if (total < 60) return String(total) + "s"
  var h = Math.floor(total / 3600)
  var m = Math.floor((total % 3600) / 60)
  if (h > 0) return m > 0 ? String(h) + "h " + String(m) + "m" : String(h) + "h"
  return String(m) + "m"
}

function formatPerDay(value) {
  var n = Number(value) || 0
  if (n <= 0) return "0"
  if (n >= 10) return String(Math.round(n))
  var rounded = Math.round(n * 10) / 10
  return rounded % 1 === 0 ? String(Math.round(rounded)) : rounded.toFixed(1)
}

function meetingStats(meetings, nowSeconds) {
  var list = Array.isArray(meetings) ? meetings : []
  var count = list.length
  var totalSecs = 0
  var withDuration = 0
  var earliest = 0
  for (var i = 0; i < list.length; i++) {
    var dur = Number(list[i] && list[i].durationSecs) || 0
    if (dur > 0) {
      totalSecs += dur
      withDuration += 1
    }
    var started = Number(list[i] && list[i].startedAt) || 0
    if (started > 0 && (earliest === 0 || started < earliest)) earliest = started
  }
  var avgSecs = withDuration > 0 ? Math.round(totalSecs / withDuration) : 0
  var now = Number(nowSeconds) || Math.floor(Date.now() / 1000)
  var daySpan = 1
  if (earliest > 0) {
    var startDay = startOfLocalDay(earliest)
    var nowDay = startOfLocalDay(now)
    daySpan = Math.max(1, Math.round((nowDay - startDay) / 86400) + 1)
  }
  return {
    count: count,
    countLabel: String(count),
    totalLabel: formatDurationShort(totalSecs),
    avgLabel: formatDurationShort(avgSecs),
    perDayLabel: formatPerDay(count / daySpan)
  }
}

var LIST_MEETINGS_DEFAULT = 5
var LIST_MEETINGS_MIN = 1
var LIST_MEETINGS_LIMIT = 10

function normalizeListMeetingsMax(value) {
  var parsed = Number(value)
  var n = Number.isFinite(parsed) ? Math.floor(parsed) : LIST_MEETINGS_DEFAULT
  if (n < LIST_MEETINGS_MIN) return LIST_MEETINGS_MIN
  if (n > LIST_MEETINGS_LIMIT) return LIST_MEETINGS_LIMIT
  return n
}

function listMeetingsMaxOptions() {
  var out = []
  for (var i = LIST_MEETINGS_MIN; i <= LIST_MEETINGS_LIMIT; i++) out.push(i)
  return out
}

function limitMeetings(meetings, max) {
  var list = Array.isArray(meetings) ? meetings : []
  var cap = Math.max(0, Math.floor(Number(max) || 0))
  if (cap <= 0 || list.length <= cap) return list
  return list.slice(0, cap)
}

function listPageCount(total, pageSize) {
  var count = Math.max(0, Math.floor(Number(total) || 0))
  var size = normalizeListMeetingsMax(pageSize)
  if (count <= 0) return 1
  return Math.max(1, Math.ceil(count / size))
}

function normalizeListPage(page, total, pageSize) {
  var pages = listPageCount(total, pageSize)
  var n = Math.floor(Number(page) || 0)
  if (!Number.isFinite(n) || n < 0) return 0
  if (n > pages - 1) return pages - 1
  return n
}

function listMeetingsCountBadge(total, max) {
  var count = Number(total) || 0
  var cap = normalizeListMeetingsMax(max)
  if (count <= 0) return ""
  if (count <= cap) return String(count)
  return cap + "/" + count
}

function listMeetingsPaginationLabel(total, page, pageSize) {
  var count = Number(total) || 0
  if (count <= 0) return ""
  if (pageSize === undefined) return "TOTAL " + String(count)
  var size = normalizeListMeetingsMax(pageSize)
  var pages = listPageCount(count, size)
  if (pages <= 1) return "TOTAL " + String(count)
  var safePage = normalizeListPage(page, count, size)
  var from = safePage * size + 1
  var to = Math.min(count, (safePage + 1) * size)
  return from + "–" + to + " OF " + count
}

function listMeetingsPageLabel(total, page, pageSize) {
  var count = Number(total) || 0
  var size = normalizeListMeetingsMax(pageSize)
  var pages = listPageCount(count, size)
  var safePage = normalizeListPage(page, count, size)
  return String(safePage + 1) + " / " + String(pages)
}

function canGoListPagePrev(page, total, pageSize) {
  return normalizeListPage(page, total, pageSize) > 0
}

function canGoListPageNext(page, total, pageSize) {
  return normalizeListPage(page, total, pageSize) < listPageCount(total, pageSize) - 1
}

function listPaginationVisible(total, pageSize) {
  var count = Number(total) || 0
  return count > 0 && listPageCount(count, pageSize) > 1
}

function meetingListSubtitle(entry, nowSeconds) {
  if (!entry) return ""
  var parts = []
  if (entry.startedAt > 0) parts.push(formatRelativeTime(entry.startedAt, nowSeconds))
  if (entry.durationSecs > 0) parts.push(formatDuration(entry.durationSecs))
  var tags = []
  if (entry.hasNotes) tags.push("notes")
  if (entry.hasSummary) tags.push("summary")
  if (entry.hasTranscript) tags.push("transcript")
  if (entry.isRecording) tags.push("transcribing")
  else if (entry.isDraft) tags.push("draft")
  if (tags.length > 0) parts.push(tags.join(", "))
  return parts.join(" · ")
}

function sortMeetings(meetings) {
  var list = Array.isArray(meetings) ? meetings.slice() : []
  list.sort(function(a, b) {
    return (b.startedAt || 0) - (a.startedAt || 0)
  })
  return list
}

function meetingExists(meetings, path) {
  var target = String(path || "").trim()
  if (target === "") return false
  var list = Array.isArray(meetings) ? meetings : []
  for (var i = 0; i < list.length; i++) {
    if (String(list[i].path || "") === target) return true
  }
  return false
}

function canOpenMeetingDetail(state, path) {
  var target = String(path || "").trim()
  if (target === "") return false
  if (String(state.meetingPath || "") === target) return true
  if (String(state.recordingMeetingPath || "") === target) return true
  return meetingExists(state.meetings, target)
}

function onboardingStepIcon(step) {
  var index = Number(step) || 0
  if (index === 0) return meetingIcon()
  if (index === 1) return "󰎤"
  return "󰒧"
}

function onboardingStepTitle(step) {
  var index = Number(step) || 0
  if (index === 0) return "What it does"
  if (index === 1) return "How it works"
  return "Get set up"
}

function onboardingStepBody(step, voxtypeReady) {
  var index = Number(step) || 0
  if (index === 0) {
    return "Capture meeting audio from your microphone and computer. Get a transcript, an AI summary, and searchable notes — without inviting a bot to your call."
  }
  if (index === 1) {
    return "Voxtype records system audio and your mic through PipeWire, transcribes speech in chunks with Whisper, and saves everything as Markdown on your machine. Summaries use your default Omarchy agent."
  }
  if (voxtypeReady) {
    return "Voxtype is installed and ready. You can start capturing meetings from the list view."
  }
  return "Voxtype powers transcription and needs a one-time install (~150MB model). Open the installer, complete setup, then come back here."
}

function panelHeroSubtitle() {
  return "RECORD · TRANSCRIBE · SUMMARIZE"
}

function settingsBackIcon() {
  return "󰁍" // nf-md-arrow-left
}

function settingsHeroSubtitle() {
  return "FOLDER · LANGUAGE · SKILL · DATA"
}

function detailTabTooltip(tabId) {
  if (tabId === "notes") return "View your notes"
  if (tabId === "summary") return "View AI summary"
  if (tabId === "transcript") return "View transcript"
  return "Switch tab"
}

function whisperLanguageTooltip(code) {
  if (code === "auto") return "Multilingual Whisper (base). For Spanish audio, choose es."
  if (code === "es") return "Spanish — uses multilingual model (required for non-English audio)"
  if (code === "en") return "English — can use the faster base.en model"
  if (code === "fr") return "Transcribe in French"
  if (code === "de") return "Transcribe in German"
  return "Use " + String(code || "auto") + " for transcription"
}

function listMeetingsMaxTooltip(max) {
  return "Show " + String(max) + " meetings per page"
}

var SKILL_GITHUB_SOURCE = "jlopezxs/omarchy-ai-meetings-notes"

function skillGithubSource() {
  return SKILL_GITHUB_SOURCE
}

function skillGithubInstallCommand() {
  return "npx --yes skills add " + SKILL_GITHUB_SOURCE + " -g --skill omarchy-meetings --agent '*' -y"
}

function skillInstallLabel(installed) {
  return installed ? "Already installed" : "Install globally"
}

function skillInstallTooltip(installed) {
  if (installed)
    return "Opens a terminal to reinstall /omarchy-meetings globally"
  return "Opens a terminal to install /omarchy-meetings globally so any agent can read your meetings"
}

function skillInstallStatusText(installed) {
  return installed ? "Already installed" : "Not installed"
}

function skillInstallHelpText() {
  return "Installs /omarchy-meetings globally via the skills.sh CLI so Cursor, Claude Code, Codex, and other agents can find and read your meeting notes from any project."
}

function defaultWidgetSettings() {
  return {
    notesDir: "",
    chunkSeconds: 30,
    whisperLanguage: "auto",
    keepAudio: false,
    autoEnableVoxtypeMeeting: true,
    summaryPreprompt: "",
    listMeetingsMax: 5,
    panelScreen: "list",
    panelDetailPath: "",
    panelDetailTab: "0"
  }
}

function liveSummaryPreview(state) {
  if (!state || typeof state !== "object") return ""
  return String(state.summary || "").trim()
}

function liveSummaryStatusText(state, chunkSeconds) {
  if (!state || state.recordingThisMeeting !== true) return ""
  var secs = normalizeChunkSeconds(chunkSeconds || state.chunkSeconds)
  if (state.summaryRefreshing) return "Updating summary…"
  if (liveSummaryPreview(state)) return "Updates every ~" + secs + "s with each audio chunk"
  if (!state.defaultAgent) return "Set a default Omarchy agent to enable live summaries"
  return "First summary after ~" + secs + "s of audio"
}

function liveTranscriptPreview(state) {
  if (!state || typeof state !== "object") return ""
  return String(state.liveTranscript || "").trim()
}

function normalizeChunkSeconds(value) {
  var seconds = Math.floor(Number(value) || 30)
  if (seconds < 15) return 15
  if (seconds > 120) return 120
  return seconds
}

function recordingElapsedSecs(state, nowSeconds) {
  if (!state || typeof state !== "object") return 0
  var startedAt = Number(state.startedAt) || 0
  if (startedAt > 0 && nowSeconds > startedAt) return nowSeconds - startedAt
  return Math.max(0, Math.floor(Number(state.durationSecs) || 0))
}

function recordingChunkProgress(state, nowSeconds, fallbackChunkSeconds) {
  if (!state || state.recordingThisMeeting !== true) return ""
  var chunkSecs = normalizeChunkSeconds(state.chunkSeconds || fallbackChunkSeconds)
  var elapsed = recordingElapsedSecs(state, nowSeconds)
  var chunkCount = Math.max(0, Math.floor(Number(state.chunkCount) || 0))
  var secondsIntoChunk = elapsed % chunkSecs
  var secondsUntilNext = chunkSecs - secondsIntoChunk
  if (secondsUntilNext <= 0 || secondsUntilNext > chunkSecs) secondsUntilNext = chunkSecs
  var hasLiveText = liveTranscriptPreview(state) !== ""

  if (!hasLiveText && chunkCount === 0)
    return "Audio chunks every " + chunkSecs + "s · first text in ~" + secondsUntilNext + "s"

  var chunkLabel = chunkCount > 0 ? ("chunk " + chunkCount + " · ") : ""
  return "Audio chunks every " + chunkSecs + "s · " + chunkLabel + "next update in ~" + secondsUntilNext + "s"
}

function recordingChunkTooltip(state, fallbackChunkSeconds) {
  var chunkSecs = normalizeChunkSeconds(state && state.chunkSeconds ? state.chunkSeconds : fallbackChunkSeconds)
  return "Voxtype transcribes ~" + chunkSecs + " seconds of audio at a time. Text appears after each chunk is processed."
}

function liveTranscriptWaitingText(state, nowSeconds, fallbackChunkSeconds) {
  if (!state || state.recordingThisMeeting !== true) return ""
  var progress = recordingChunkProgress(state, nowSeconds, fallbackChunkSeconds)
  if (!progress) return "Listening…"
  return "Listening… " + progress + ". Speakers appear as Me and Attendee 1, 2, 3."
}

function isSavingMeeting(state) {
  if (!state || state.busy !== true) return false
  var label = String(state.busyLabel || "").toLowerCase()
  return (
    label.indexOf("saving") >= 0 ||
    label.indexOf("exporting") >= 0 ||
    label.indexOf("generating") >= 0 ||
    label.indexOf("stopping") >= 0
  )
}

function isGeneratingSummary(state) {
  if (!state || typeof state !== "object") return false
  if (state.summaryRefreshing === true) return true
  if (state.busy !== true) return false
  var label = String(state.busyLabel || "").toLowerCase()
  return label.indexOf("generating") >= 0 || label.indexOf("summary") >= 0
}

function actionBusy(state) {
  if (!state || state.busy !== true) return false
  return !isGeneratingSummary(state)
}

function summaryLoadingVisible(state, tabId) {
  if (String(tabId || "") !== "summary") return false
  if (String((state && state.summary) || "").trim() !== "") return false
  if (!state) return false
  return state.busy === true || state.summaryRefreshing === true
}

function summaryLoadingTitle(state) {
  if (isGeneratingSummary(state)) return "Generating summary"
  var label = String((state && state.busyLabel) || "").toLowerCase()
  if (label.indexOf("exporting") >= 0) return "Saving transcript"
  if (label.indexOf("stopping") >= 0) return "Stopping capture"
  return "Working"
}

function summaryLoadingCaption(state) {
  var label = String((state && state.busyLabel) || "").trim()
  if (label !== "") return label
  return "Working…"
}

function captureStatusVisible(state) {
  if (!state || typeof state !== "object") return false
  return state.recordingThisMeeting === true || isSavingMeeting(state)
}

function recordingStatusHeadline(state) {
  if (!state) return "Recording"
  if (isSavingMeeting(state) && state.recordingThisMeeting !== true) return "Stopped"
  return "Recording"
}

function recordingStatusDetail(state, nowSeconds) {
  return formatDuration(recordingElapsedSecs(state, nowSeconds))
}

function recordingStatusFooter(state) {
  return recordingBannerTitle(state)
}

function recordingOpenPath(state) {
  if (!state || typeof state !== "object") return ""
  var path = String(state.recordingMeetingPath || "").trim()
  if (path !== "") return path
  path = String(state.meetingPath || "").trim()
  if (path !== "") return path
  var list = Array.isArray(state.meetings) ? state.meetings : []
  for (var i = 0; i < list.length; i++) {
    var entry = list[i] || {}
    if (entry.isRecording === true) {
      var recordingPath = String(entry.path || "").trim()
      if (recordingPath !== "") return recordingPath
    }
  }
  return ""
}

function recordingBannerTitle(state) {
  var path = recordingOpenPath(state)
  var match = findMeetingByPath(state && state.meetings, path)
  if (match && match.title) return String(match.title)
  var title = String((state && state.title) || "").trim()
  return title || "Meeting"
}

function transcriptStatusHeadline(state) {
  if (isSavingMeeting(state)) {
    var label = String(state.busyLabel || "").trim()
    if (label.indexOf("Generating") >= 0) return "Summary"
    if (label.indexOf("Exporting") >= 0) return "Saving"
    if (label.indexOf("Stopping") >= 0) return "Stopping"
    return "Saving"
  }
  if (liveTranscriptPreview(state)) return "Live"
  return "Waiting"
}

function transcriptStatusFooter(state, nowSeconds, fallbackChunkSeconds) {
  if (isSavingMeeting(state))
    return String(state.busyLabel || "Saving transcript and summary…")
  if (liveTranscriptPreview(state)) return "Live transcription enabled"
  return recordingChunkProgress(state, nowSeconds, fallbackChunkSeconds) || "Live transcription enabled"
}

function transcriptProgressRatio(state, nowSeconds, fallbackChunkSeconds) {
  if (isSavingMeeting(state)) {
    var label = String(state.busyLabel || "").toLowerCase()
    if (label.indexOf("stopping") >= 0) return 0.2
    if (label.indexOf("exporting") >= 0) return 0.55
    if (label.indexOf("generating") >= 0) return 0.82
    if (label.indexOf("saving") >= 0) return 0.4
    return 0.5
  }
  if (!state || state.recordingThisMeeting !== true) return 0
  var chunkSecs = normalizeChunkSeconds(state.chunkSeconds || fallbackChunkSeconds)
  var elapsed = recordingElapsedSecs(state, nowSeconds)
  var into = elapsed % chunkSecs
  return Math.max(0, Math.min(1, into / chunkSecs))
}

function detailPhase(state) {
  if (!state || typeof state !== "object") return "active"
  if (state.meetingFinished) return "finished"
  if (state.recording || state.meetingDraft) return "active"
  return "active"
}

function detailTabs(state) {
  if (detailPhase(state) !== "finished") return []
  var tabs = []
  if (state.hasNotes) tabs.push({ id: "notes", label: "Your notes" })
  tabs.push({ id: "summary", label: "Summary" })
  tabs.push({ id: "transcript", label: "Transcript" })
  return tabs
}

function detailTabContent(state, tabId) {
  if (tabId === "notes") return state.notes || ""
  if (tabId === "summary") return state.summary || ""
  if (tabId === "transcript") {
    if (state.recording && state.liveTranscript) return state.liveTranscript
    return state.transcript || ""
  }
  return ""
}

function buildCopyText(state, tabId) {
  var title = state.title || "Meeting"
  var when = formatDateTime(state.startedAt || 0)
  var parts = [title]
  if (when) parts.push(when)
  parts.push("")

  if (state.hasNotes && state.notes) {
    parts.push("Notes")
    parts.push(state.notes)
    parts.push("")
  }
  if (state.summary) {
    parts.push("Summary")
    parts.push(state.summary.replace(/^#+\s*/gm, ""))
    parts.push("")
  }
  var transcript = detailTabContent(state, "transcript")
  if (transcript) {
    parts.push("Transcript")
    parts.push(transcript.replace(/^#+\s*/gm, ""))
  }
  return parts.join("\n").trim()
}

function buildCopyMarkdown(state) {
  var title = state.title || "Meeting"
  var when = formatDateTime(state.startedAt || 0)
  var parts = ["# " + title]
  if (when) parts.push("*" + when + "*")
  parts.push("")

  if (state.hasNotes && state.notes) {
    parts.push("## Your notes")
    parts.push(state.notes)
    parts.push("")
  }
  if (state.summary) {
    parts.push("## Summary")
    parts.push(state.summary)
    parts.push("")
  }
  var transcript = state.recording && state.liveTranscript ? state.liveTranscript : state.transcript
  if (transcript) {
    parts.push("## Transcript")
    parts.push(transcript)
  }
  return parts.join("\n").trim()
}

function hasMeetingContent(state) {
  if (!state || typeof state !== "object") return false
  return Boolean(
    (state.hasNotes && state.notes) ||
    state.summary ||
    state.transcript ||
    state.liveTranscript
  )
}

function resolveDetailMeetingPath(state, lastPath, entry, savedPath) {
  var fromState = ""
  if (state && typeof state === "object") fromState = String(state.meetingPath || "")
  var fromEntry = entry && entry.path ? String(entry.path) : ""
  var candidates = [lastPath, fromEntry, fromState, savedPath]
  for (var i = 0; i < candidates.length; i++) {
    var path = String(candidates[i] || "").trim()
    if (path) return path
  }
  return ""
}

function canDeleteMeeting(state, meetingPath, recordingMeetingPath) {
  var path = String(meetingPath || "").trim()
  if (!path) return false
  var recordingPath = String(
    recordingMeetingPath || (state && typeof state === "object" ? state.recordingMeetingPath : "") || ""
  ).trim()
  if (state && state.recording === true && recordingPath !== "" && path === recordingPath) return false
  return true
}

function deleteMeetingTooltip(state, meetingPath, recordingMeetingPath) {
  if (!canDeleteMeeting(state, meetingPath, recordingMeetingPath))
    return "Stop transcribing before deleting"
  return "Delete this meeting permanently"
}

function askAgentLaunchPrompt(state) {
  var title = String((state && state.title) || "Meeting").trim() || "Meeting"
  var when = formatDateTime(state && state.startedAt ? state.startedAt : 0)
  var line = "/omarchy-meetings " + title
  if (when) line += " · " + when
  return line + "\n\n"
}

function askAgentSkillPrompt() {
  return "/omarchy-meetings\n\n"
}

function askAgentButtonLabel(state) {
  if (state && state.skillInstalled === true) return "Ask Agent"
  return "Install Agent skill"
}

function canAskAgent(state) {
  if (!state || typeof state !== "object") return false
  if (state.recording === true || state.recordingThisMeeting === true) return false
  return state.meetingFinished === true || isGeneratingSummary(state)
}

function askAgentTooltip(state) {
  if (!state || state.skillInstalled !== true) {
    return "Installs the /omarchy-meetings skill globally so your default agent can read this meeting's transcript and notes from any project. After that, Ask Agent opens a prompt with the meeting title and date so you can add your question."
  }
  if (!state.defaultAgent)
    return "Set default agent: omarchy default agent <name>"
  return "Open your default agent with /omarchy-meetings plus this meeting's title and date, then add your question"
}

function askAgentListTooltip(state) {
  if (!state || state.skillInstalled !== true)
    return "Install /omarchy-meetings globally so any agent can read your meeting notes"
  if (!state.defaultAgent)
    return "Set default agent: omarchy default agent <name>"
  return "Open your default agent with /omarchy-meetings"
}

function normalizeDetailTabIndex(state, tabIndex) {
  var tabs = detailTabs(state)
  if (tabs.length === 0) return 0
  return Math.max(0, Math.min(tabIndex, tabs.length - 1))
}

function tabIndexFor(state, tabId) {
  var tabs = detailTabs(state)
  for (var i = 0; i < tabs.length; i++) {
    if (tabs[i].id === tabId) return i
  }
  return 0
}

if (typeof module !== "undefined") {
  module.exports = {
    meetingIcon: meetingIcon,
    elide: elide,
    compactMarkdownHeadings: compactMarkdownHeadings,
    markdownToPreviewHtml: markdownToPreviewHtml,
    formatDuration: formatDuration,
    formatDateTime: formatDateTime,
    formatRelativeTime: formatRelativeTime,
    formatUserError: formatUserError,
    normalizeBool: normalizeBool,
    meetingSearchHaystack: meetingSearchHaystack,
    filterMeetings: filterMeetings,
    meetingsForList: meetingsForList,
    meetingStats: meetingStats,
    formatDurationShort: formatDurationShort,
    limitMeetings: limitMeetings,
    normalizeListMeetingsMax: normalizeListMeetingsMax,
    listMeetingsMaxOptions: listMeetingsMaxOptions,
    listPageCount: listPageCount,
    normalizeListPage: normalizeListPage,
    listMeetingsCountBadge: listMeetingsCountBadge,
    listMeetingsPaginationLabel: listMeetingsPaginationLabel,
    listMeetingsPageLabel: listMeetingsPageLabel,
    canGoListPagePrev: canGoListPagePrev,
    canGoListPageNext: canGoListPageNext,
    listPaginationVisible: listPaginationVisible,
    normalizeMeeting: normalizeMeeting,
    normalizeChatMessage: normalizeChatMessage,
    parseState: parseState,
    emptyState: emptyState,
    barBadgeText: barBadgeText,
    barTooltip: barTooltip,
    onboardingStepIcon: onboardingStepIcon,
    onboardingStepTitle: onboardingStepTitle,
    onboardingStepBody: onboardingStepBody,
    meetingLabel: meetingLabel,
    meetingCreatedAtLabel: meetingCreatedAtLabel,
    findMeetingByPath: findMeetingByPath,
    detailHeaderTitle: detailHeaderTitle,
    detailHeaderSubtitle: detailHeaderSubtitle,
    panelHeroSubtitle: panelHeroSubtitle,
    settingsBackIcon: settingsBackIcon,
    settingsHeroSubtitle: settingsHeroSubtitle,
    meetingListSubtitle: meetingListSubtitle,
    liveTranscriptPreview: liveTranscriptPreview,
    liveSummaryPreview: liveSummaryPreview,
    liveSummaryStatusText: liveSummaryStatusText,
    normalizeChunkSeconds: normalizeChunkSeconds,
    recordingChunkProgress: recordingChunkProgress,
    recordingChunkTooltip: recordingChunkTooltip,
    liveTranscriptWaitingText: liveTranscriptWaitingText,
    isSavingMeeting: isSavingMeeting,
    isGeneratingSummary: isGeneratingSummary,
    actionBusy: actionBusy,
    summaryLoadingVisible: summaryLoadingVisible,
    summaryLoadingTitle: summaryLoadingTitle,
    summaryLoadingCaption: summaryLoadingCaption,
    captureStatusVisible: captureStatusVisible,
    recordingStatusHeadline: recordingStatusHeadline,
    recordingStatusDetail: recordingStatusDetail,
    recordingStatusFooter: recordingStatusFooter,
    recordingOpenPath: recordingOpenPath,
    recordingBannerTitle: recordingBannerTitle,
    transcriptStatusHeadline: transcriptStatusHeadline,
    transcriptStatusFooter: transcriptStatusFooter,
    transcriptProgressRatio: transcriptProgressRatio,
    detailPhase: detailPhase,
    detailTabTooltip: detailTabTooltip,
    whisperLanguageTooltip: whisperLanguageTooltip,
    listMeetingsMaxTooltip: listMeetingsMaxTooltip,
    skillGithubSource: skillGithubSource,
    skillGithubInstallCommand: skillGithubInstallCommand,
    skillInstallLabel: skillInstallLabel,
    skillInstallTooltip: skillInstallTooltip,
    skillInstallStatusText: skillInstallStatusText,
    skillInstallHelpText: skillInstallHelpText,
    defaultWidgetSettings: defaultWidgetSettings,
    sortMeetings: sortMeetings,
    meetingExists: meetingExists,
    canOpenMeetingDetail: canOpenMeetingDetail,
    detailTabs: detailTabs,
    detailTabContent: detailTabContent,
    buildCopyText: buildCopyText,
    buildCopyMarkdown: buildCopyMarkdown,
    hasMeetingContent: hasMeetingContent,
    resolveDetailMeetingPath: resolveDetailMeetingPath,
    canDeleteMeeting: canDeleteMeeting,
    deleteMeetingTooltip: deleteMeetingTooltip,
    askAgentLaunchPrompt: askAgentLaunchPrompt,
    askAgentSkillPrompt: askAgentSkillPrompt,
    askAgentButtonLabel: askAgentButtonLabel,
    canAskAgent: canAskAgent,
    askAgentTooltip: askAgentTooltip,
    askAgentListTooltip: askAgentListTooltip,
    normalizeDetailTabIndex: normalizeDetailTabIndex,
    tabIndexFor: tabIndexFor
  }
}
