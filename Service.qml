import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root

  property var shell: null
  property var manifest: null
  property var settings: ({})

  readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace("file://", "")
  readonly property string helper: pluginDir + "scripts/meetings"

  property var state: Model.emptyState()
  property bool helperReady: false
  property string lastError: ""
  property var commandQueue: []

  readonly property bool recording: state.recording === true
  readonly property bool busy: state.busy === true
  readonly property string badgeText: Model.barBadgeText(state)
  readonly property var meetings: Model.sortMeetings(state.meetings || [])

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function settingsPayload(overrides) {
    var base = {
      cmd: "reload-settings",
      notesDir: setting("notesDir", ""),
      chunkSeconds: Number(setting("chunkSeconds", 30)) || 30,
      whisperLanguage: String(setting("whisperLanguage", "auto") || "auto"),
      keepAudio: Model.normalizeBool(setting("keepAudio", false), false),
      autoEnableVoxtypeMeeting: Model.normalizeBool(setting("autoEnableVoxtypeMeeting", true), true),
      summaryPreprompt: String(setting("summaryPreprompt", "") || "")
    }
    if (!overrides) return base
    for (var key in overrides) base[key] = overrides[key]
    return base
  }

  function sendCommand(payload) {
    var body = payload || {}
    if (!helperReady || !daemonProc.running) {
      var queued = commandQueue.slice()
      queued.push(body)
      commandQueue = queued
      return
    }
    daemonProc.write(JSON.stringify(body) + "\n")
  }

  function drainQueue() {
    if (!helperReady || commandQueue.length === 0) return
    var queued = commandQueue.slice()
    commandQueue = []
    for (var i = 0; i < queued.length; i++)
      daemonProc.write(JSON.stringify(queued[i]) + "\n")
  }

  function reloadSettings(overrides) {
    sendCommand(settingsPayload(overrides))
  }

  function persistSetting(key, value) {
    var text = typeof value === "boolean" ? (value ? "true" : "false") : String(value)
    Quickshell.execDetached(["omarchy", "bar", "set", "jlopezxs.meetings", key, text])
    var overrides = {}
    overrides[key] = value
    reloadSettings(overrides)
  }

  function refresh() {
    sendCommand({ cmd: "refresh" })
  }

  function createMeeting(title) {
    sendCommand({ cmd: "create-meeting", title: title || "Meeting" })
  }

  function startRecording(title) {
    sendCommand({ cmd: "start", title: title || "Meeting" })
  }

  function stopRecording() {
    sendCommand({ cmd: "stop" })
  }

  function toggleRecording() {
    sendCommand({ cmd: "toggle-recording" })
  }

  function selectMeeting(path) {
    sendCommand({ cmd: "select-meeting", path: path || "" })
  }

  function saveNotes(path, content) {
    sendCommand({ cmd: "save-notes", path: path || state.meetingPath || "", content: content || "" })
  }

  function createNotes(path) {
    sendCommand({ cmd: "create-notes", path: path || state.meetingPath || "" })
  }

  function ask(question, path) {
    sendCommand({
      cmd: "ask",
      question: question || "",
      path: path || state.meetingPath || ""
    })
  }

  function openAgentWithMeeting(path) {
    sendCommand({ cmd: "open-agent", path: path || state.meetingPath || "" })
  }

  function openAgentWithSkill() {
    sendCommand({ cmd: "open-agent", skillOnly: true })
  }

  function deleteMeeting(path) {
    sendCommand({ cmd: "delete-meeting", path: path || state.meetingPath || "" })
  }

  function deleteAllMeetings() {
    sendCommand({ cmd: "delete-all-meetings" })
  }

  function completeOnboarding() {
    sendCommand({ cmd: "complete-onboarding" })
  }

  function resetSettings() {
    sendCommand({ cmd: "reset-settings" })
  }

  function installSkill() {
    sendCommand({ cmd: "install-skill" })
  }

  function openNotesDir() {
    sendCommand({ cmd: "open-notes-dir" })
  }

  function consumeLine(line) {
    var raw = String(line || "").trim()
    if (raw === "") return
    var parsed = Model.parseState(raw)
    state = parsed
    if (!parsed.ok && parsed.error !== "")
      lastError = parsed.error
    else if (parsed.ok)
      lastError = ""
  }

  onSettingsChanged: reloadSettings()

  Component.onCompleted: {
    daemonProc.running = true
  }

  Process {
    id: daemonProc
    command: [root.helper, "--daemon"]
    stdinEnabled: true
    stdout: SplitParser {
      onRead: function(line) { root.consumeLine(line) }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (raw !== "") root.lastError = Model.elide(raw, 120)
      }
    }
    onStarted: {
      root.helperReady = true
      root.drainQueue()
      root.reloadSettings()
    }
    onExited: {
      root.helperReady = false
      root.state = Model.emptyState("helper exited")
      daemonRetry.restart()
    }
  }

  Timer {
    id: daemonRetry
    interval: 1500
    repeat: false
    onTriggered: {
      if (!daemonProc.running)
        daemonProc.running = true
    }
  }

  IpcHandler {
    target: "jlopezxs.meetings"

    function toggleRecording(): void { root.toggleRecording() }
    function startRecording(title: string): void { root.startRecording(title || "Meeting") }
    function stopRecording(): void { root.stopRecording() }
    function refresh(): void { root.refresh() }
    function state(): string { return JSON.stringify(root.state) }
  }
}
