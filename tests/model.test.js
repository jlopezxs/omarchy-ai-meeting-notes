"use strict"

const assert = require("assert")
const Model = require("../Model.js")

assert.strictEqual(Model.elide("short"), "short")
assert.strictEqual(Model.formatRelativeTime(0), "")
assert.strictEqual(Model.compactMarkdownHeadings("# Title\n\n## Section\n\n- item"), "### Title\n\n#### Section\n\n- item")
assert.strictEqual(Model.compactMarkdownHeadings("### Sub\n\n###### Max"), "##### Sub\n\n###### Max")
assert.strictEqual(Model.compactMarkdownHeadings("see #hashtag in a line"), "see #hashtag in a line")
const preview = Model.markdownToPreviewHtml("# Title\n\n## Section\n\n- item", 13, 11)
assert.ok(preview.indexOf("<b>Title</b>") >= 0)
assert.ok(preview.indexOf("margin-left:10px") >= 0)
assert.ok(preview.indexOf("margin-top:16px") >= 0)
assert.ok(preview.indexOf("• item") >= 0)
assert.ok(preview.indexOf("<b>Date:</b>") >= 0 || Model.markdownToPreviewHtml("- **Date:** today", 13, 11).indexOf("<b>Date:</b>") >= 0)
assert.strictEqual(Model.formatRelativeTime(Math.floor(Date.now() / 1000) - 120, Math.floor(Date.now() / 1000)), "2 minutes ago")

const filtered = Model.filterMeetings([
  { title: "Team sync", id: "a" },
  { title: "Design review", id: "b" }
], "design")
assert.strictEqual(filtered.length, 1)
assert.strictEqual(filtered[0].title, "Design review")

const byTranscript = Model.filterMeetings([
  { title: "Sprint planning", id: "c", searchText: "we decided to ship the billing API" },
  { title: "Design review", id: "b", searchText: "typography tokens" }
], "billing api")
assert.strictEqual(byTranscript.length, 1)
assert.strictEqual(byTranscript[0].title, "Sprint planning")

const six = [
  { title: "One", id: "1" },
  { title: "Two", id: "2" },
  { title: "Old billing call", id: "3", searchText: "invoice overdue" },
  { title: "Four", id: "4" },
  { title: "Five", id: "5" },
  { title: "Six", id: "6" }
]
assert.strictEqual(Model.meetingsForList(six, "", 5).length, 5)
assert.strictEqual(Model.meetingsForList(six, "", 5, 1).length, 1)
assert.strictEqual(Model.meetingsForList(six, "", 5, 1)[0].title, "Six")
assert.strictEqual(Model.meetingsForList(six, "invoice", 5).length, 1)
assert.strictEqual(Model.listPageCount(12, 5), 3)
assert.strictEqual(Model.listPageCount(5, 5), 1)
assert.strictEqual(Model.listPageCount(0, 5), 1)
assert.strictEqual(Model.normalizeListPage(9, 12, 5), 2)
assert.strictEqual(Model.normalizeListPage(-1, 12, 5), 0)
assert.strictEqual(Model.canGoListPagePrev(0, 12, 5), false)
assert.strictEqual(Model.canGoListPageNext(0, 12, 5), true)
assert.strictEqual(Model.canGoListPageNext(2, 12, 5), false)
assert.strictEqual(Model.listPaginationVisible(12, 5), true)
assert.strictEqual(Model.listPaginationVisible(3, 5), false)
assert.strictEqual(Model.listMeetingsPageLabel(12, 1, 5), "2 / 3")
assert.strictEqual(Model.listMeetingsPaginationLabel(12, 1, 5), "6–10 OF 12")

const draft = Model.parseState(JSON.stringify({
  ok: true,
  meetingDraft: true,
  meetingFinished: false,
  recording: false,
  meetingPath: "/tmp/meeting",
  meetings: []
}))
assert.strictEqual(Model.detailPhase(draft), "active")
assert.strictEqual(Model.detailTabs(draft).length, 0)

const finished = Model.parseState(JSON.stringify({
  ok: true,
  onboardingComplete: false,
  meetingDraft: false,
  meetingFinished: true,
  hasNotes: true,
  notes: "My bullet",
  summary: "## Summary\n- Done",
  transcript: "Hello",
  meetings: []
}))
assert.strictEqual(Model.detailPhase(finished), "finished")
assert.strictEqual(Model.detailTabs(finished).length, 3)

const finishedNoNotes = Model.parseState(JSON.stringify({
  ok: true,
  meetingFinished: true,
  hasNotes: false,
  summary: "Summary",
  transcript: "Hello",
  meetings: []
}))
assert.strictEqual(Model.detailTabs(finishedNoNotes).length, 2)

assert.strictEqual(
  Model.barTooltip({ recording: true, durationSecs: 125, startedAt: 0 }),
  "Transcribing — click to open"
)
assert.strictEqual(Model.findMeetingByPath([{ path: "/tmp/a", title: "Sync" }], "/tmp/a").title, "Sync")
assert.strictEqual(
  Model.detailHeaderTitle({ meetingPath: "/tmp/a", title: "Live" }, { path: "/tmp/a", title: "Sync" }, "Meeting"),
  "Live"
)
assert.strictEqual(
  Model.detailHeaderTitle({ meetingPath: "", title: "" }, { path: "/tmp/a", title: "Meeting 1" }, "Meeting"),
  "Meeting 1"
)
assert.ok(Model.detailHeaderSubtitle({ meetingDraft: true, startedAt: 0 }, { startedAt: 1700000000, isDraft: true }).indexOf("Draft") >= 0)
assert.strictEqual(Model.detailTabTooltip("summary"), "View AI summary")
assert.strictEqual(Model.barBadgeText({ recording: true, durationSecs: 125 }), "")

assert.strictEqual(Model.limitMeetings([1, 2, 3, 4, 5, 6], 5).length, 5)
assert.strictEqual(Model.listMeetingsCountBadge(3, 5), "3")
assert.strictEqual(Model.listMeetingsCountBadge(12, 5), "5/12")
assert.strictEqual(Model.listMeetingsPaginationLabel(3, 0, 5), "TOTAL 3")
assert.strictEqual(Model.listMeetingsPaginationLabel(12, 0, 5), "1–5 OF 12")
assert.strictEqual(Model.listMeetingsPaginationLabel(0, 0, 5), "")
assert.strictEqual(Model.parseState(JSON.stringify({ onboardingComplete: true })).onboardingComplete, true)
assert.strictEqual(Model.parseState(JSON.stringify({ onboardingComplete: false })).onboardingComplete, false)
assert.strictEqual(Model.parseState(JSON.stringify({ skillInstalled: true })).skillInstalled, true)
assert.strictEqual(Model.parseState(JSON.stringify({})).skillInstalled, false)
assert.strictEqual(Model.skillInstallLabel(false), "Install for agents")
assert.strictEqual(Model.skillInstallLabel(true), "Already installed")
assert.strictEqual(Model.skillInstallStatusText(false), "Not installed")
assert.strictEqual(Model.skillInstallStatusText(true), "Already installed")
assert.ok(Model.skillInstallTooltip(false).indexOf("bundled") >= 0)
assert.ok(Model.skillInstallTooltip(true).indexOf("bundled") >= 0)
assert.ok(Model.skillInstallHelpText().indexOf("npm") >= 0)
assert.strictEqual(Model.defaultWidgetSettings().aiSummaries, false)
assert.strictEqual(Model.parseState(JSON.stringify({ aiSummaries: true })).aiSummaries, true)
assert.strictEqual(Model.parseState(JSON.stringify({ aiSummaries: "true" })).aiSummaries, true)
assert.strictEqual(Model.withAiSummaries({ aiSummaries: false }, "true").aiSummaries, true)
assert.strictEqual(Model.summaryEmptyGenerate(Model.withAiSummaries({ aiSummaries: false }, true)), true)
assert.ok(Model.liveSummaryStatusText({ recordingThisMeeting: true, aiSummaries: false }, 30).indexOf("off") >= 0)
assert.strictEqual(Model.defaultWidgetSettings().listMeetingsMax, 5)
assert.strictEqual(Model.defaultWidgetSettings().notesDir, "")
assert.strictEqual(Model.defaultWidgetSettings().whisperLanguage, "auto")
assert.strictEqual(Model.defaultWidgetSettings().panelScreen, "list")

assert.strictEqual(Model.normalizeListMeetingsMax(5), 5)
assert.strictEqual(Model.normalizeListMeetingsMax(0), 1)
assert.strictEqual(Model.normalizeListMeetingsMax(99), 10)
assert.strictEqual(Model.listMeetingsMaxOptions().length, 10)

assert.strictEqual(Model.onboardingStepTitle(0), "What it does")
assert.strictEqual(Model.onboardingStepIcon(1), "󰎤")
assert.ok(Model.onboardingStepBody(2, true).indexOf("ready") >= 0)

assert.strictEqual(Model.meetingExists([{ path: "/tmp/a" }], "/tmp/a"), true)
assert.strictEqual(Model.meetingExists([{ path: "/tmp/a" }], "/tmp/b"), false)
assert.strictEqual(Model.canOpenMeetingDetail({ meetingPath: "/tmp/live", meetings: [] }, "/tmp/live"), true)
assert.strictEqual(Model.canOpenMeetingDetail({ meetingPath: "", meetings: [{ path: "/tmp/a" }] }, "/tmp/a"), true)
assert.strictEqual(Model.canOpenMeetingDetail({ meetingPath: "", meetings: [] }, "/tmp/missing"), false)

assert.strictEqual(Model.normalizeBool("true", false), true)
assert.strictEqual(Model.normalizeBool("false", true), false)
assert.strictEqual(Model.normalizeBool(undefined, true), true)

assert.strictEqual(Model.meetingIcon(), "󱘓")
assert.strictEqual(Model.panelHeroSubtitle(), "RECORD · TRANSCRIBE · SUMMARIZE")
assert.strictEqual(Model.settingsBackIcon(), "󰁍")
assert.strictEqual(Model.settingsHeroSubtitle(), "FOLDER · LANGUAGE · AI · SKILL · DATA")
assert.strictEqual(Model.liveTranscriptPreview({ liveTranscript: " **Me** hello" }), "**Me** hello")
assert.strictEqual(Model.parseState(JSON.stringify({ speakerCount: 3 })).speakerCount, 3)

assert.strictEqual(Model.normalizeChunkSeconds(10), 15)
assert.strictEqual(Model.normalizeChunkSeconds(30), 30)
assert.strictEqual(Model.normalizeChunkSeconds(200), 120)
assert.ok(
  Model.recordingChunkProgress({
    recordingThisMeeting: true,
    startedAt: 100,
    chunkCount: 0,
    chunkSeconds: 30,
    liveTranscript: ""
  }, 115, 30).indexOf("first text in ~15s") >= 0
)
assert.ok(
  Model.recordingChunkProgress({
    recordingThisMeeting: true,
    startedAt: 100,
    chunkCount: 2,
    chunkSeconds: 30,
    liveTranscript: "Hello"
  }, 145, 30).indexOf("chunk 2") >= 0
)

assert.strictEqual(Model.canDeleteMeeting({ recording: false }, "/tmp/a", ""), true)
assert.strictEqual(
  Model.canDeleteMeeting({ recording: true, recordingMeetingPath: "/tmp/a" }, "/tmp/a", "/tmp/a"),
  false
)
assert.strictEqual(
  Model.resolveDetailMeetingPath({ meetingPath: "/tmp/state" }, "/tmp/open", { path: "/tmp/entry" }, "/tmp/saved"),
  "/tmp/open"
)
assert.strictEqual(
  Model.resolveDetailMeetingPath({ meetingPath: "" }, "", { path: "/tmp/entry" }, "/tmp/saved"),
  "/tmp/entry"
)
assert.strictEqual(
  Model.resolveDetailMeetingPath({ meetingPath: "/tmp/state" }, "", null, ""),
  "/tmp/state"
)
assert.strictEqual(Model.resolveDetailMeetingPath(null, "", null, "/tmp/saved"), "/tmp/saved")
assert.strictEqual(Model.resolveDetailMeetingPath("", "", null, ""), "")

assert.strictEqual(Model.captureStatusVisible({ recordingThisMeeting: true }), true)
assert.strictEqual(Model.captureStatusVisible({ busy: true, busyLabel: "Saving meeting…" }), true)
assert.strictEqual(Model.captureStatusVisible({ busy: true, busyLabel: "Thinking…" }), false)
assert.strictEqual(Model.recordingStatusHeadline({ recordingThisMeeting: true }), "Recording")
assert.strictEqual(Model.transcriptStatusHeadline({ recordingThisMeeting: true, liveTranscript: "Hi" }), "Live")
assert.strictEqual(Model.transcriptStatusHeadline({ busy: true, busyLabel: "Generating summary…" }), "Summary")
assert.strictEqual(Model.isGeneratingSummary({ busy: true, busyLabel: "Generating summary…" }), true)
assert.strictEqual(Model.isGeneratingSummary({ summaryRefreshing: true }), true)
assert.strictEqual(Model.isGeneratingSummary({ busy: true, busyLabel: "Exporting transcript…" }), false)
assert.strictEqual(Model.actionBusy({ busy: true, busyLabel: "Generating summary…" }), false)
assert.strictEqual(Model.actionBusy({ busy: true, busyLabel: "Saving meeting…" }), true)
assert.strictEqual(Model.actionBusy({ busy: false }), false)
assert.strictEqual(Model.summaryLoadingVisible({ busy: true, busyLabel: "Generating summary…", summary: "" }, "summary"), true)
assert.strictEqual(Model.summaryLoadingVisible({ busy: true, busyLabel: "Generating summary…", summary: "Done" }, "summary"), false)
assert.strictEqual(Model.summaryLoadingVisible({ busy: true, busyLabel: "Generating summary…" }, "transcript"), false)
assert.strictEqual(Model.summaryLoadingTitle({ busy: true, busyLabel: "Generating summary…" }), "Generating summary")
assert.strictEqual(Model.summaryLoadingCaption({ busy: true, busyLabel: "Generating summary…" }), "Generating summary…")
assert.strictEqual(Model.summaryDisabledVisible({ aiSummaries: false, summary: "" }, "summary"), true)
assert.strictEqual(Model.summaryDisabledVisible({ aiSummaries: true, summary: "" }, "summary"), false)
assert.strictEqual(Model.summaryDisabledVisible({ aiSummaries: false, summary: "Done" }, "summary"), false)
assert.strictEqual(Model.summaryDisabledVisible({ aiSummaries: false, summary: "" }, "transcript"), false)
assert.strictEqual(Model.summaryDisabledTitle(), "AI summary is off")
assert.ok(Model.summaryDisabledCaption().indexOf("Settings") >= 0)
assert.strictEqual(Model.summaryEmptyVisible({ aiSummaries: true, summary: "" }, "summary"), true)
assert.strictEqual(Model.summaryEmptyGenerate({ aiSummaries: true }), true)
assert.strictEqual(Model.summaryEmptyTitle({ aiSummaries: true }), "No summary yet")
assert.strictEqual(Model.summaryEmptyActionLabel({ aiSummaries: true }), "Generate summary")
assert.strictEqual(Model.canGenerateSummary({
  aiSummaries: true,
  defaultAgent: "claude",
  transcript: "hello",
  busy: false
}), true)
assert.strictEqual(Model.canGenerateSummary({
  aiSummaries: true,
  defaultAgent: "claude",
  transcript: "",
  busy: false
}), true)
assert.strictEqual(Model.canGenerateSummary({
  aiSummaries: true,
  recording: true,
  recordingThisMeeting: false,
  transcript: "hello"
}), true)
assert.strictEqual(Model.canGenerateSummary({
  aiSummaries: true,
  recordingThisMeeting: true,
  transcript: "hello"
}), false)
assert.strictEqual(Model.canGenerateSummary({
  aiSummaries: false,
  defaultAgent: "claude",
  transcript: "hello"
}), false)
assert.strictEqual(Model.summaryEmptyTitle({ aiSummaries: true, summaryError: "agent failed" }), "Summary failed")
assert.strictEqual(Model.summaryEmptyCaption({ aiSummaries: true, summaryError: "agent failed" }), "agent failed")
assert.strictEqual(Model.parseState(JSON.stringify({ summaryError: "nope" })).summaryError, "nope")
assert.ok(Model.transcriptProgressRatio({ busy: true, busyLabel: "Exporting transcript…" }, 0, 30) > 0.5)
assert.strictEqual(Model.recordingStatusDetail({ recordingThisMeeting: true, startedAt: 100, durationSecs: 0 }, 173), "01:13")
assert.strictEqual(Model.recordingOpenPath({ recordingMeetingPath: "/tmp/live", meetingPath: "/tmp/other" }), "/tmp/live")
assert.strictEqual(Model.recordingOpenPath({
  recordingMeetingPath: "",
  meetingPath: "",
  meetings: [{ path: "/tmp/rec", isRecording: true }]
}), "/tmp/rec")
assert.strictEqual(Model.canOpenMeetingDetail({
  meetingPath: "",
  recordingMeetingPath: "/tmp/live",
  meetings: []
}, "/tmp/live"), true)
assert.strictEqual(Model.recordingBannerTitle({
  recordingMeetingPath: "/tmp/live",
  title: "Selected",
  meetings: [{ path: "/tmp/live", title: "Standup now" }]
}), "Standup now")

assert.strictEqual(Model.askAgentButtonLabel({ skillInstalled: false }), "Install Agent skill")
assert.strictEqual(Model.askAgentButtonLabel({ skillInstalled: true }), "Ask Agent")
assert.ok(Model.askAgentTooltip({ skillInstalled: false }).indexOf("/omarchy-meeting-notepad") >= 0)
assert.strictEqual(Model.canAskAgent({ meetingFinished: true, skillInstalled: false }), true)
assert.strictEqual(Model.canAskAgent({ meetingFinished: true, skillInstalled: true, defaultAgent: "" }), true)
assert.strictEqual(Model.canAskAgent({ meetingFinished: true, skillInstalled: true, defaultAgent: "agent" }), true)
assert.strictEqual(Model.canAskAgent({ meetingFinished: false }), false)
assert.strictEqual(Model.canAskAgent({ busy: true, busyLabel: "Generating summary…" }), true)
assert.strictEqual(Model.canAskAgent({ recording: true, summaryRefreshing: true }), false)
assert.ok(Model.askAgentLaunchPrompt({ title: "Standup", startedAt: 0 }).indexOf("/omarchy-meeting-notepad Standup") === 0)
assert.strictEqual(Model.askAgentSkillPrompt(), "/omarchy-meeting-notepad\n\n")
assert.ok(Model.askAgentListTooltip({ skillInstalled: false }).indexOf("/omarchy-meeting-notepad") >= 0)
assert.ok(Model.askAgentListTooltip({ skillInstalled: true, defaultAgent: "claude" }).indexOf("title") < 0)

const weekNow = 1755900000
assert.strictEqual(Model.meetingStats([], weekNow).countLabel, "0")
assert.strictEqual(Model.meetingStats([], weekNow).perDayLabel, "0")

const stats = Model.meetingStats([
  { startedAt: weekNow - 86400, durationSecs: 600 },
  { startedAt: weekNow, durationSecs: 1200 }
], weekNow)
assert.strictEqual(stats.countLabel, "2")
assert.strictEqual(stats.totalLabel, "30m")
assert.strictEqual(stats.avgLabel, "15m")
assert.ok(stats.perDayLabel !== "")
assert.strictEqual(Model.formatDurationShort(3720), "1h 2m")

const searchable = [
  { title: "Morning standup", id: "m", searchText: "" },
  { title: "Catch-up", id: "c", searchText: "" },
  { title: "Also standup words", id: "x", searchText: "we talked about standup process" }
]
assert.strictEqual(Model.filterMeetings(searchable, "standup").length, 2)
assert.strictEqual(Model.filterMeetings(searchable, "catch").length, 1)
assert.ok(Model.meetingListSubtitle({ startedAt: 0, durationSecs: 90, hasNotes: true }).indexOf("notes") >= 0)
assert.ok(Model.meetingListSubtitle({ startedAt: 0, durationSecs: 0, tags: ["standup"] }).indexOf("#standup") < 0)

const copied = Model.buildCopyText({
  title: "Standup",
  startedAt: 0,
  hasNotes: true,
  notes: "Ship billing",
  summary: "We shipped it",
  transcript: "Hello from the call"
}, "summary")
assert.ok(copied.indexOf("Standup") >= 0)
assert.ok(copied.indexOf("Ship billing") >= 0)
assert.ok(copied.indexOf("We shipped it") >= 0)
assert.ok(copied.indexOf("Hello from the call") >= 0)

console.log("model.test.js: ok")
