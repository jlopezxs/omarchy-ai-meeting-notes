import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: root

  property var bar: null
  property var settings: ({})
  property var hostWidget: null
  property var service: null

  property string notesDraft: ""
  property int nowSeconds: Math.floor(Date.now() / 1000)

  readonly property bool detached: window.visible
  readonly property var state: service ? service.state : Model.emptyState()
  readonly property bool recording: state.recording === true
  readonly property bool recordingThisMeeting: state.recordingThisMeeting === true
  readonly property bool busy: state.busy === true
  readonly property int displayDurationSecs: recordingThisMeeting && state.startedAt > 0
    ? Math.max(state.durationSecs, nowSeconds - state.startedAt)
    : state.durationSecs
  readonly property string liveTranscriptText: Model.liveTranscriptPreview(state)
  readonly property int chunkSecondsSetting: Model.normalizeChunkSeconds(setting("chunkSeconds", 30))
  readonly property string liveTranscriptWaitingText: Model.liveTranscriptWaitingText(state, nowSeconds, chunkSecondsSetting)
  readonly property string lastError: Model.formatUserError(state.error || (service ? service.lastError : ""))
  readonly property string headerTitle: Model.detailHeaderTitle(state, null, "Meeting")

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function show() {
    nowSeconds = Math.floor(Date.now() / 1000)
    notesDraft = state.notes || notesDraft
    window.visible = true
    window.minimized = false
  }

  function hide() {
    persistNotesDraft()
    window.visible = false
  }

  function focusWindow() {
    show()
    Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "title:Meeting notepad"])
  }

  function persistNotesDraft() {
    if (!service || !state.meetingPath) return
    service.saveNotes(state.meetingPath, notesDraft)
  }

  function scheduleNotesSave() {
    if (!state.meetingPath) return
    notesSaveTimer.restart()
  }

  function stopTranscription() {
    if (service) service.stopRecording()
  }

  function startTranscription() {
    if (!service || busy || recording) return
    service.startRecording(state.title || "Meeting")
  }

  function dock() {
    persistNotesDraft()
    window.visible = false
    if (hostWidget && typeof hostWidget.open === "function")
      Qt.callLater(function() { hostWidget.open() })
  }

  onStateChanged: {
    if (state.meetingPath)
      notesDraft = state.notes || notesDraft
  }

  Timer {
    id: notesSaveTimer
    interval: 600
    repeat: false
    onTriggered: root.persistNotesDraft()
  }

  Timer {
    interval: 1000
    running: root.detached && root.recording
    repeat: true
    onTriggered: nowSeconds = Math.floor(Date.now() / 1000)
  }

  FloatingWindow {
    id: window
    visible: false
    title: "Meeting notepad"
    color: Color.popups.background
    implicitWidth: 420
    implicitHeight: 720
    minimumSize: Qt.size(320, 420)

    onVisibleChanged: {
      if (!visible) root.persistNotesDraft()
    }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.spacing.panelPadding
      spacing: Style.spacing.panelGap

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing.controlGap

        OpticalGlyph {
          Layout.preferredWidth: Style.space(28)
          Layout.preferredHeight: Style.space(28)
          text: Model.meetingIcon()
          fontFamily: root.fontFamily
          fontSize: Style.font.iconLarge
          color: root.foreground
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.space(2)

          Text {
            text: root.headerTitle
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.bold: true
            elide: Text.ElideRight
            Layout.fillWidth: true
          }

          Text {
            visible: recordingThisMeeting
            text: Model.formatDuration(root.displayDurationSecs)
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            Layout.fillWidth: true
          }
        }

        PanelActionButton {
          iconText: "󰕰"
          foreground: root.foreground
          hoverColor: root.foreground
          fontFamily: root.fontFamily
          bordered: true
          tooltipText: "Dock back into the bar panel"
          onClicked: root.dock()
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing.controlGap
        visible: Model.captureStatusVisible(state)

        CaptureStatusBox {
          Layout.fillWidth: true
          visible: recordingThisMeeting
          iconText: "󰻃"
          title: "RECORDING STATUS"
          headline: Model.recordingStatusHeadline(state)
          showDot: recordingThisMeeting && !busy
          detail: Model.recordingStatusDetail(state, nowSeconds)
          footer: Model.recordingStatusFooter(state)
          progress: -1
          foreground: root.foreground
          accent: root.urgent
          dim: root.dim
          fontFamily: root.fontFamily
        }

        CaptureStatusBox {
          Layout.fillWidth: true
          iconText: "󰷈"
          title: "TRANSCRIPT PROGRESS"
          headline: Model.transcriptStatusHeadline(state)
          showDot: false
          detail: ""
          footer: Model.transcriptStatusFooter(state, nowSeconds, chunkSecondsSetting)
          progress: Model.transcriptProgressRatio(state, nowSeconds, chunkSecondsSetting)
          foreground: root.foreground
          accent: Color.accent
          dim: root.dim
          fontFamily: root.fontFamily
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing.controlGap
        visible: !!state.meetingPath

        PanelTextButton {
          Layout.fillWidth: true
          visible: recordingThisMeeting
          label: "Stop transcribing"
          tooltip: "Stop capture and save the meeting"
          labelBold: true
          labelColor: root.urgent
          accentColor: root.urgent
          urgentColor: root.urgent
          fontFamily: root.fontFamily
          fontPixelSize: Style.font.bodySmall
          onActivated: root.stopTranscription()
        }

        PanelTextButton {
          Layout.fillWidth: true
          visible: !recordingThisMeeting && !state.meetingFinished && !busy
          label: "Start transcribing"
          tooltip: "Capture audio and transcribe live"
          labelBold: true
          labelColor: root.foreground
          accentColor: Color.accent
          fontFamily: root.fontFamily
          fontPixelSize: Style.font.bodySmall
          actionable: !busy && state.voxtypeReady
          onActivated: root.startTranscription()
        }
      }

      Text {
        Layout.fillWidth: true
        visible: lastError !== ""
        wrapMode: Text.WordWrap
        color: root.urgent
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        text: lastError
      }

      PanelSectionHeader {
        Layout.fillWidth: true
        visible: recordingThisMeeting || liveTranscriptText !== ""
        text: liveTranscriptText !== "" ? "Live transcript" : "Live transcript · waiting"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: Style.space(240)
        visible: recordingThisMeeting || liveTranscriptText !== ""
        radius: Style.cornerRadius
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)
        border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)

        ScrollView {
          anchors.fill: parent
          anchors.margins: Style.spacing.panelPadding
          clip: true

          TextArea {
            readOnly: true
            wrapMode: TextArea.Wrap
            text: liveTranscriptText || liveTranscriptWaitingText
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            background: null
          }
        }
      }

      PanelSectionHeader {
        Layout.fillWidth: true
        text: "Your notes"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: Style.space(220)
        radius: Style.cornerRadius
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)
        border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)

        TextArea {
          anchors.fill: parent
          anchors.margins: Style.spacing.panelPadding
          text: root.notesDraft
          wrapMode: TextArea.Wrap
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          placeholderText: "Write your notes during the meeting…"
          placeholderTextColor: root.dim
          background: null
          onTextChanged: {
            root.notesDraft = text
            root.scheduleNotesSave()
          }
        }
      }
    }
  }
}
