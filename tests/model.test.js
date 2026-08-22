"use strict"

const assert = require("assert")
const Model = require("../Model.js")

assert.strictEqual(Model.formatRelativeTime(0), "")
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
  "Transcribing — click to open, middle-click to stop"
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
assert.strictEqual(Model.skillInstallLabel(false), "Install globally")
assert.strictEqual(Model.skillInstallLabel(true), "Reinstall globally")
assert.strictEqual(Model.skillInstallStatusText(false), "Not installed")
assert.ok(Model.skillGithubInstallCommand().indexOf("jlopezxs/omarchy-meetings-notepad-ai") >= 0)
assert.ok(Model.skillGithubInstallCommand().indexOf(" -g") >= 0)

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

assert.strictEqual(Model.meetingIcon(), "")
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

assert.strictEqual(Model.captureStatusVisible({ recordingThisMeeting: true }), true)
assert.strictEqual(Model.captureStatusVisible({ busy: true, busyLabel: "Saving meeting…" }), true)
assert.strictEqual(Model.captureStatusVisible({ busy: true, busyLabel: "Thinking…" }), false)
assert.strictEqual(Model.recordingStatusHeadline({ recordingThisMeeting: true }), "Recording")
assert.strictEqual(Model.transcriptStatusHeadline({ recordingThisMeeting: true, liveTranscript: "Hi" }), "Live")
assert.strictEqual(Model.transcriptStatusHeadline({ busy: true, busyLabel: "Generating summary…" }), "Summary")
assert.ok(Model.transcriptProgressRatio({ busy: true, busyLabel: "Exporting transcript…" }, 0, 30) > 0.5)
assert.strictEqual(Model.recordingStatusDetail({ recordingThisMeeting: true, startedAt: 100, durationSecs: 0 }, 173), "01:13")

assert.strictEqual(Model.askAgentButtonLabel({ skillInstalled: false }), "Install Agent skill")
assert.strictEqual(Model.askAgentButtonLabel({ skillInstalled: true }), "Ask Agent")
assert.ok(Model.askAgentTooltip({ skillInstalled: false }).indexOf("/omarchy-meetings") >= 0)
assert.strictEqual(Model.canAskAgent({ meetingFinished: true, skillInstalled: false }), true)
assert.strictEqual(Model.canAskAgent({ meetingFinished: true, skillInstalled: true, defaultAgent: "" }), true)
assert.strictEqual(Model.canAskAgent({ meetingFinished: true, skillInstalled: true, defaultAgent: "agent" }), true)
assert.strictEqual(Model.canAskAgent({ meetingFinished: false }), false)
assert.ok(Model.askAgentLaunchPrompt({ title: "Standup", startedAt: 0 }).indexOf("/omarchy-meetings Standup") === 0)

assert.strictEqual(Model.normalizeTag("#Standup"), "standup")
assert.strictEqual(Model.normalizeTag("1:1"), "1-1")
assert.deepStrictEqual(Model.normalizeTags("standup, 1-1, standup"), ["standup", "1-1"])
assert.strictEqual(Model.tagChipLabel("standup"), "#standup")
assert.strictEqual(Model.formatTagsPreview("standup, 1-1"), "#standup #1-1")
assert.deepStrictEqual(Model.addMeetingTag(["standup"], "1-1"), ["standup", "1-1"])
assert.deepStrictEqual(Model.removeMeetingTag(["standup", "1-1"], "standup"), ["1-1"])
assert.strictEqual(Model.toggleTagFilterQuery("", "standup"), "#standup")
assert.strictEqual(Model.toggleTagFilterQuery("#standup", "standup"), "")
assert.strictEqual(Model.isTagFilterQuery("#standup"), true)

const tagged = [
  { title: "Morning", id: "m", tags: ["standup"] },
  { title: "Catch-up", id: "c", tags: ["1-1"] },
  { title: "Also standup words", id: "x", searchText: "we talked about standup process" }
]
assert.strictEqual(Model.filterMeetings(tagged, "#standup").length, 1)
assert.strictEqual(Model.filterMeetings(tagged, "#standup")[0].id, "m")
assert.strictEqual(Model.filterMeetings(tagged, "standup").length, 2)
assert.deepStrictEqual(Model.uniqueMeetingTags(tagged), ["1-1", "standup"])
assert.ok(Model.meetingListSubtitle({ startedAt: 0, durationSecs: 0, tags: ["standup"] }).indexOf("#standup") >= 0)

const withTags = Model.parseState(JSON.stringify({
  ok: true,
  tags: ["Standup", "1:1"],
  meetings: [{ title: "A", path: "/tmp/a", tags: ["standup"] }]
}))
assert.deepStrictEqual(withTags.tags, ["standup", "1-1"])
assert.deepStrictEqual(withTags.meetings[0].tags, ["standup"])

console.log("model.test.js: ok")
