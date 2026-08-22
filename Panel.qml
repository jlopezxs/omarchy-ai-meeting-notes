import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "jlopezxs.meetings"
  ipcTarget: "jlopezxs.meetings"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var service: null

  // onboarding | list | detail | settings
  property string screen: "list"
  property string lastDetailPath: ""
  property bool pendingViewRestore: false
  property int onboardingStep: 0
  property string searchQuery: ""
  property int listPage: 0
  property string titleDraft: "Meeting"
  property string tagsDraft: ""
  property string tagDraft: ""
  property var detailMeeting: null
  property int detailTabIndex: 0
  property string notesDraft: ""
  property bool notesEditorVisible: false
  property bool copyMenuOpen: false
  property bool waitingForCreatedMeeting: false
  property string createdMeetingGuardPath: ""
  property bool wasRecording: false
  property int nowSeconds: Math.floor(Date.now() / 1000)

  property bool onboardingDismissed: false

  readonly property var state: service ? service.state : Model.emptyState()
  readonly property var meetings: Model.sortMeetings(state.meetings || [])
  readonly property bool needsOnboarding: !onboardingDismissed
    && service
    && service.helperReady
    && state.onboardingComplete !== true
  readonly property var filteredMeetings: Model.filterMeetings(meetings, searchQuery)
  readonly property var availableTags: Model.uniqueMeetingTags(meetings)
  readonly property var currentMeetingTags: Model.meetingTags(state)
  readonly property int listMeetingsMax: Model.normalizeListMeetingsMax(setting("listMeetingsMax", 5))
  readonly property int filteredMeetingsCount: filteredMeetings.length
  readonly property int safeListPage: Model.normalizeListPage(listPage, filteredMeetingsCount, listMeetingsMax)
  readonly property var visibleMeetings: Model.meetingsForList(meetings, searchQuery, listMeetingsMax, listPage)
  readonly property string listPaginationLabel: Model.listMeetingsPaginationLabel(filteredMeetingsCount, safeListPage, listMeetingsMax)
  readonly property bool listPaginationVisible: Model.listPaginationVisible(filteredMeetingsCount, listMeetingsMax)
  readonly property int listRowHeight: Style.space(56)
  readonly property int listAreaHeight: listMeetingsMax * listRowHeight
  readonly property int detailNotesHeight: Style.space(220)
  readonly property bool recording: state.recording === true
  readonly property bool recordingThisMeeting: state.recordingThisMeeting === true
  readonly property string recordingMeetingPath: state.recordingMeetingPath || ""
  readonly property bool busy: state.busy === true
  readonly property int displayDurationSecs: recordingThisMeeting && state.startedAt > 0
    ? Math.max(state.durationSecs, nowSeconds - state.startedAt)
    : state.durationSecs
  readonly property string detailHeaderTitle: Model.detailHeaderTitle(state, detailMeeting, titleDraft)
  readonly property string detailHeaderSubtitle: Model.detailHeaderSubtitle(state, detailMeeting)
  readonly property string lastError: Model.formatUserError(state.error || (service ? service.lastError : ""))
  readonly property var detailTabs: Model.detailTabs(state)
  readonly property string detailPhase: Model.detailPhase(state)
  readonly property bool detailActive: detailPhase === "active"
  readonly property bool detailFinished: detailPhase === "finished"
  readonly property int safeDetailTabIndex: Model.normalizeDetailTabIndex(state, detailTabIndex)
  readonly property string activeDetailTabId: detailTabs.length > safeDetailTabIndex
    ? detailTabs[safeDetailTabIndex].id
    : "summary"
  readonly property string activeDetailText: Model.detailTabContent(state, activeDetailTabId)
  readonly property int chunkSecondsSetting: Model.normalizeChunkSeconds(setting("chunkSeconds", 30))
  readonly property string recordingChunkProgress: Model.recordingChunkProgress(state, nowSeconds, chunkSecondsSetting)
  readonly property string liveTranscriptText: Model.liveTranscriptPreview(state)
  readonly property string liveSummaryText: Model.liveSummaryPreview(state)
  readonly property string liveSummaryStatus: Model.liveSummaryStatusText(state, chunkSecondsSetting)
  readonly property string liveTranscriptWaitingText: Model.liveTranscriptWaitingText(state, nowSeconds, chunkSecondsSetting)

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function boolSetting(name, fallback) {
    return Model.normalizeBool(setting(name, fallback), fallback === true)
  }

  onSearchQueryChanged: listPage = 0

  onFilteredMeetingsCountChanged: {
    listPage = Model.normalizeListPage(listPage, filteredMeetingsCount, listMeetingsMax)
  }

  onListMeetingsMaxChanged: {
    listPage = Model.normalizeListPage(listPage, filteredMeetingsCount, listMeetingsMax)
  }

  function persistPluginSettings(values) {
    var entry = { id: root.moduleName }
    for (var existing in settings) if (existing !== "id") entry[existing] = settings[existing]
    for (var key in values) entry[key] = values[key]
    root.settings = entry
    if (hostWidget && "settings" in hostWidget) hostWidget.settings = entry
    if (bar && bar.shell && typeof bar.shell.updateEntryInline === "function")
      bar.shell.updateEntryInline(moduleName, entry)
    if (service) {
      for (var name in values)
        service.persistSetting(name, values[name])
    }
  }

  function showList() {
    screen = "list"
    lastDetailPath = ""
    detailMeeting = null
    copyMenuOpen = false
    notesEditorVisible = false
    searchQuery = ""
    if (service) {
      service.persistSetting("panelScreen", "list")
      service.persistSetting("panelDetailPath", "")
    }
  }

  function showPrevListPage() {
    if (!Model.canGoListPagePrev(safeListPage, filteredMeetingsCount, listMeetingsMax)) return
    listPage = safeListPage - 1
  }

  function showNextListPage() {
    if (!Model.canGoListPageNext(safeListPage, filteredMeetingsCount, listMeetingsMax)) return
    listPage = safeListPage + 1
  }

  function finishOnboarding() {
    onboardingDismissed = true
    if (service) service.completeOnboarding()
    onboardingStep = 0
    showList()
  }

  function installVoxtype() {
    Quickshell.execDetached([
      "omarchy-launch-floating-terminal-with-presentation",
      "omarchy-voxtype-install"
    ])
  }

  function nextOnboardingStep() {
    if (onboardingStep < 2) onboardingStep += 1
  }

  function prevOnboardingStep() {
    if (onboardingStep > 0) onboardingStep -= 1
  }

  function showDetail(path, options) {
    options = options || {}
    var meetingPath = String(path || state.meetingPath || "").trim()
    if (meetingPath === "") return
    lastDetailPath = meetingPath
    detailMeeting = options.entry
      ? Model.normalizeMeeting(options.entry)
      : Model.findMeetingByPath(meetings, meetingPath)
    if (service) {
      service.selectMeeting(meetingPath)
      service.persistSetting("panelScreen", "detail")
      service.persistSetting("panelDetailPath", meetingPath)
    }
    screen = "detail"
    if (options.resetTab !== false)
      detailTabIndex = Model.tabIndexFor(state, "summary")
    notesDraft = state.meetingPath === meetingPath ? (state.notes || "") : ""
    notesEditorVisible = false
    copyMenuOpen = false
    tagDraft = ""
  }

  function showSettings() {
    screen = "settings"
    copyMenuOpen = false
    if (service) service.persistSetting("panelScreen", "settings")
  }

  function loadPersistedPanelNavigation() {
    var savedScreen = String(setting("panelScreen", "") || "")
    if (savedScreen === "detail" || savedScreen === "settings")
      screen = savedScreen
    var savedPath = String(setting("panelDetailPath", "") || "")
    if (savedPath !== "") lastDetailPath = savedPath
    var savedTab = parseInt(String(setting("panelDetailTab", "0")), 10)
    if (Number.isFinite(savedTab)) detailTabIndex = savedTab
  }

  function persistPanelNavigation() {
    if (!service) return
    service.persistSetting("panelScreen", screen)
    if (screen === "detail") {
      service.persistSetting("panelDetailPath", lastDetailPath || state.meetingPath || "")
      service.persistSetting("panelDetailTab", String(detailTabIndex))
    } else {
      service.persistSetting("panelDetailPath", "")
    }
  }

  function restorePanelView() {
    if (needsOnboarding) {
      onboardingStep = 0
      return
    }
    if (screen === "settings") return
    if (screen !== "detail") return

    var path = String(lastDetailPath || state.meetingPath || setting("panelDetailPath", "") || "").trim()
    if (!Model.canOpenMeetingDetail(state, path)) {
      showList()
      return
    }

    lastDetailPath = path
    detailMeeting = Model.findMeetingByPath(meetings, path) || detailMeeting
    if (service) service.selectMeeting(path)
    notesDraft = state.notes || notesDraft
    detailTabIndex = Model.normalizeDetailTabIndex(state, detailTabIndex)
  }

  function createMeeting() {
    if (!service || busy) return
    createdMeetingGuardPath = String(state.meetingPath || "")
    waitingForCreatedMeeting = true
    service.createMeeting(titleDraft.trim() || "Meeting", tagsDraft)
    tagsDraft = ""
  }

  function persistTags(tags) {
    if (!service || !state.meetingPath) return
    service.saveTags(state.meetingPath, tags)
  }

  function addDetailTag() {
    var next = Model.addMeetingTag(state.tags, tagDraft)
    tagDraft = ""
    persistTags(next)
  }

  function removeDetailTag(tag) {
    persistTags(Model.removeMeetingTag(state.tags, tag))
  }

  function applyTagFilter(tag) {
    searchQuery = Model.toggleTagFilterQuery(searchQuery, tag)
  }

  function startTranscription() {
    if (!service || busy || recording) return
    var title = state.title || titleDraft.trim() || "Meeting"
    service.startRecording(title)
  }

  function stopTranscription() {
    if (!service) return
    service.stopRecording()
  }

  function toggleRecording() {
    if (recording) stopTranscription()
    else startTranscription()
  }

  function addNotes() {
    if (!service || !state.meetingPath) return
    service.createNotes(state.meetingPath)
    notesDraft = state.notes || ""
  }

  function saveNotesDraft() {
    if (!service || !state.meetingPath) return
    service.saveNotes(state.meetingPath, notesDraft)
    if (detailFinished) notesEditorVisible = false
  }

  function persistNotesDraft() {
    if (!service || !state.meetingPath) return
    service.saveNotes(state.meetingPath, notesDraft)
  }

  function scheduleNotesSave() {
    if (!state.meetingPath) return
    notesSaveTimer.restart()
  }

  function copyText(text) {
    copyMenuOpen = false
    if (!text) return
    copyProc.textToCopy = text
    copyProc.running = false
    Qt.callLater(function() { copyProc.running = true })
  }

  function askAgentWithMeeting() {
    if (!service || busy) return
    if (state.skillInstalled !== true) {
      service.installSkill()
      return
    }
    service.openAgentWithMeeting(state.meetingPath || "")
  }

  function deleteMeeting(path) {
    var target = String(path || state.meetingPath || "").trim()
    if (!service || busy || !target) return
    if (!Model.canDeleteMeeting(state, target, recordingMeetingPath)) return
    service.deleteMeeting(target)
    if (screen === "detail" && (target === state.meetingPath || target === lastDetailPath))
      showList()
  }

  function copyCurrent(mode) {
    if (mode === "markdown") copyText(Model.buildCopyMarkdown(state))
    else copyText(Model.buildCopyText(state, activeDetailTabId))
  }

  function openNotesDir() {
    if (service) service.openNotesDir()
  }

  function detachPanel() {
    persistNotesDraft()
    persistPanelNavigation()
    if (hostWidget && typeof hostWidget.detachPanel === "function")
      hostWidget.detachPanel()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  Component.onCompleted: {
    if (service && service.state && service.state.onboardingComplete === true)
      onboardingDismissed = true
    loadPersistedPanelNavigation()
  }

  onOpenedChanged: {
    if (opened) {
      nowSeconds = Math.floor(Date.now() / 1000)
      if (needsOnboarding) onboardingStep = 0
      pendingViewRestore = true
      if (service) service.refresh()
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    } else {
      persistPanelNavigation()
      onboardingStep = 0
    }
  }

  onStateChanged: {
    if (state.onboardingComplete === true)
      onboardingDismissed = true
    if (screen === "detail" && state.meetingPath) {
      lastDetailPath = state.meetingPath
      if (!detailMeeting || detailMeeting.path !== state.meetingPath)
        detailMeeting = Model.findMeetingByPath(meetings, state.meetingPath) || detailMeeting
    }
    if (pendingViewRestore && opened) {
      pendingViewRestore = false
      restorePanelView()
    }
    if (screen === "detail" && !notesEditorVisible && detailFinished)
      notesDraft = state.notes || ""
    if (screen === "detail" && detailActive && state.meetingPath)
      notesDraft = state.notes || notesDraft
    if (recording && state.title && titleDraft === "Meeting")
      titleDraft = state.title
    if (waitingForCreatedMeeting) {
      var createdPath = String(state.meetingPath || "")
      if (createdPath !== "" && createdPath !== createdMeetingGuardPath) {
        waitingForCreatedMeeting = false
        createdMeetingGuardPath = ""
        showDetail(createdPath, { resetTab: false })
      } else if (state.ok === false) {
        waitingForCreatedMeeting = false
        createdMeetingGuardPath = ""
      }
    }
    if (wasRecording && !recording && state.meetingFinished) {
      detailTabIndex = Model.tabIndexFor(state, "summary")
      detailMeeting = Model.findMeetingByPath(meetings, state.meetingPath) || detailMeeting
    }
    if (wasRecording && !recording && busy)
      detailMeeting = Model.findMeetingByPath(meetings, state.meetingPath) || detailMeeting
    if (!wasRecording && recording && screen === "list" && state.meetingPath)
      showDetail(state.meetingPath, { resetTab: false })
    if (state.hasNotes && detailTabIndex >= detailTabs.length)
      detailTabIndex = Model.normalizeDetailTabIndex(state, detailTabIndex)
    wasRecording = recording
  }

  Timer {
    id: notesSaveTimer
    interval: 600
    repeat: false
    onTriggered: root.persistNotesDraft()
  }

  Timer {
    interval: 1000
    running: root.recording
    repeat: true
    onTriggered: nowSeconds = Math.floor(Date.now() / 1000)
  }

  Timer {
    interval: 30000
    running: root.opened && root.screen === "list" && !root.needsOnboarding && !root.recording
    repeat: true
    onTriggered: nowSeconds = Math.floor(Date.now() / 1000)
  }

  Process {
    id: copyProc
    property string textToCopy: ""
    command: ["wl-copy"]
    stdinEnabled: true
    onStarted: write(textToCopy)
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(root.needsOnboarding ? Style.space(360) : Style.space(440))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: notesField.activeFocus || activeNotesField.activeFocus || settingsPrepromptField.activeFocus
        || searchField.activeFocus
        || tagsCreateField.activeFocus
        || tagAddField.activeFocus
      onCloseRequested: {
        if (needsOnboarding) root.close()
        else if (screen !== "list") showList()
        else root.close()
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }
    }

    ColumnLayout {
      id: contentColumn
      width: parent.width
      spacing: Style.spacing.panelGap

      Loader {
        Layout.fillWidth: true
        sourceComponent: root.needsOnboarding ? onboardingScreen
          : (root.screen === "settings" ? settingsScreen
          : (root.screen === "detail" ? detailScreen : listScreen))
      }
    }
  }

  Component {
    id: onboardingScreen

    ColumnLayout {
      width: parent.width
      spacing: Style.space(10)

      Text {
        text: "Meetings Notepad"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.title
        font.bold: true
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
      }

      Text {
        text: "Step " + String(onboardingStep + 1) + " of 3"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(Style.space(220), onboardingBody.implicitHeight + Style.spacing.panelPadding * 2)
        radius: Style.cornerRadius
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)
        border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)

        ColumnLayout {
          id: onboardingBody
          anchors.fill: parent
          anchors.margins: Style.spacing.panelPadding
          spacing: Style.space(12)

              Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(40)
                Layout.alignment: Qt.AlignHCenter

                OpticalGlyph {
                  id: onboardStepIcon
                  anchors.centerIn: parent
                  width: Style.space(36)
                  height: Style.space(36)
                  text: Model.onboardingStepIcon(onboardingStep)
                  fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                  fontSize: Style.font.iconLarge
                  color: Color.accent
                }
              }

              Text {
                Layout.fillWidth: true
                text: Model.onboardingStepTitle(onboardingStep)
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
              }

              Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
              }

          Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            horizontalAlignment: Text.AlignLeft
            text: Model.onboardingStepBody(onboardingStep, state.voxtypeReady)
          }

          Row {
            Layout.fillWidth: true
            spacing: Style.space(6)

            Repeater {
              model: 3
              delegate: Rectangle {
                required property int index
                width: Math.max(Style.space(24), (parent.width - Style.space(6) * 2) / 3)
                height: Style.space(4)
                radius: Style.space(2)
                color: onboardingStep === index
                  ? Color.accent
                  : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)
              }
            }
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing.controlGap
        visible: onboardingStep > 0 && onboardingStep < 2

        CursorSurface {
          Layout.preferredWidth: backOnboardLabel.implicitWidth + Style.space(24)
          Layout.preferredHeight: backOnboardLabel.implicitHeight + Style.space(14)
          property bool pointerHot: false
          foreground: root.foreground
          accent: Color.accent
          bordered: true
          hasCursor: pointerHot

          HoverHandler {
            onHoveredChanged: pointerHot = hovered
          }

          PanelToolTip {
            visible: pointerHot
            text: "Previous onboarding step"
            fontFamily: root.fontFamily
          }

          Text {
            id: backOnboardLabel
            anchors.centerIn: parent
            text: "Back"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.prevOnboardingStep()
          }
        }

        PanelTextButton {
          Layout.fillWidth: true
          label: "Next"
          tooltip: "Next onboarding step"
          labelColor: root.foreground
          accentColor: Color.accent
          fontFamily: root.fontFamily
          onActivated: root.nextOnboardingStep()
        }
      }

      PanelTextButton {
        Layout.fillWidth: true
        visible: onboardingStep === 0
        label: "Next"
        tooltip: "Next onboarding step"
        labelColor: root.foreground
        accentColor: Color.accent
        fontFamily: root.fontFamily
        onActivated: root.nextOnboardingStep()
      }

      ColumnLayout {
        Layout.fillWidth: true
        visible: onboardingStep === 2
        spacing: Style.spacing.controlGap

        PanelTextButton {
          Layout.fillWidth: true
          visible: !state.voxtypeReady
          label: "Install Voxtype"
          tooltip: "Open the Voxtype installer"
          labelColor: root.foreground
          accentColor: Color.accent
          fontFamily: root.fontFamily
          onActivated: root.installVoxtype()
        }

        PanelTextButton {
          Layout.fillWidth: true
          visible: !state.voxtypeReady
          label: "Check again"
          tooltip: "Refresh Voxtype install status"
          labelColor: root.foreground
          accentColor: Color.accent
          fontFamily: root.fontFamily
          onActivated: { if (service) service.refresh() }
        }

        PanelTextButton {
          Layout.fillWidth: true
          label: "Get started"
          tooltip: "Finish setup and open the list"
          labelBold: true
          labelColor: root.foreground
          accentColor: Color.accent
          fontFamily: root.fontFamily
          highlighted: true
          onActivated: root.finishOnboarding()
        }
      }
    }
  }

  Component {
    id: listScreen

    ColumnLayout {
      width: parent.width
      spacing: Style.spacing.panelGap

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing.controlGap

        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: Math.max(listHeroIcon.height, listHeroLabels.implicitHeight)

          OpticalGlyph {
            id: listHeroIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(36)
            height: Style.space(36)
            text: Model.meetingIcon()
            fontFamily: root.fontFamily
            fontSize: Style.font.display
            color: root.foreground
          }

          Column {
            id: listHeroLabels
            anchors.left: listHeroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "Meeting Notepad"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              text: Model.panelHeroSubtitle()
              color: Qt.darker(root.foreground, 1.4)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
              width: parent.width
            }
          }
        }

        PanelActionButton {
          iconText: "󰒓"
          foreground: root.foreground
          hoverColor: root.foreground
          fontFamily: root.fontFamily
          bordered: true
          tooltipText: "Open plugin settings"
          onClicked: root.showSettings()
        }
      }

      PanelSectionHeader {
        Layout.fillWidth: true
        text: "NEW MEETING"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      TextField {
        Layout.fillWidth: true
        text: root.titleDraft
        placeholderText: "Meeting title"
        enabled: !busy && state.voxtypeReady
        color: root.foreground
        placeholderTextColor: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        onTextChanged: root.titleDraft = text
      }

      TextField {
        id: tagsCreateField
        Layout.fillWidth: true
        text: root.tagsDraft
        placeholderText: "Tags · standup, 1-1"
        enabled: !busy && state.voxtypeReady
        color: root.foreground
        placeholderTextColor: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        onTextChanged: root.tagsDraft = text
      }

      Text {
        Layout.fillWidth: true
        visible: Model.formatTagsPreview(root.tagsDraft) !== ""
        text: "Saved as " + Model.formatTagsPreview(root.tagsDraft)
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }

      PanelTextButton {
        Layout.fillWidth: true
        label: "Create meeting"
        tooltip: "Create a draft meeting in the list"
        labelBold: true
        labelColor: root.foreground
        accentColor: Color.accent
        fontFamily: root.fontFamily
        actionable: !busy && state.voxtypeReady && !recording
        onActivated: root.createMeeting()
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing.controlGap
        visible: recording

        PanelTextButton {
          Layout.fillWidth: true
          label: "󰻃  Transcribing — open meeting"
          tooltip: "Open the meeting being transcribed"
          labelColor: root.urgent
          accentColor: root.urgent
          urgentColor: root.urgent
          urgent: true
          fontFamily: root.fontFamily
          fontPixelSize: Style.font.bodySmall
          labelBold: true
          onActivated: root.showDetail(state.meetingPath)
        }

        PanelTextButton {
          label: "Stop"
          tooltip: "Stop transcribing and save"
          labelColor: root.urgent
          accentColor: root.urgent
          urgentColor: root.urgent
          urgent: true
          fontFamily: root.fontFamily
          fontPixelSize: Style.font.bodySmall
          labelBold: true
          onActivated: root.stopTranscription()
        }
      }

      Text {
        Layout.fillWidth: true
        visible: recording && recordingChunkProgress !== ""
        text: recordingChunkProgress
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WordWrap
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

      Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: Style.space(20)
        Layout.bottomMargin: Style.space(12)
        Layout.preferredHeight: 1
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.16)
      }

      PanelSectionHeader {
        Layout.fillWidth: true
        text: "MEETINGS"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      TextField {
        id: searchField
        Layout.fillWidth: true
        text: root.searchQuery
        placeholderText: "Search titles, notes, transcripts, or #tag…"
        color: root.foreground
        placeholderTextColor: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        onTextChanged: root.searchQuery = text
      }

      Flow {
        Layout.fillWidth: true
        spacing: Style.space(6)
        visible: availableTags.length > 0

        Repeater {
          model: availableTags

          delegate: CursorSurface {
            required property var modelData
            property bool pointerHot: false
            implicitWidth: tagFilterLabel.implicitWidth + Style.space(16)
            implicitHeight: tagFilterLabel.implicitHeight + Style.space(10)
            foreground: root.foreground
            accent: Color.accent
            bordered: true
            hasCursor: pointerHot
            current: Model.isTagFilterQuery(root.searchQuery) && Model.normalizeTag(root.searchQuery) === modelData

            HoverHandler {
              onHoveredChanged: pointerHot = hovered
            }

            PanelToolTip {
              visible: pointerHot
              text: current ? "Clear #tag filter" : ("Show meetings tagged " + Model.tagChipLabel(modelData))
              fontFamily: root.fontFamily
            }

            Text {
              id: tagFilterLabel
              anchors.centerIn: parent
              text: Model.tagChipLabel(modelData)
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: parent.current
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.applyTagFilter(modelData)
            }
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: listAreaHeight
        visible: meetings.length === 0
        radius: Style.cornerRadius
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)
        border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)

        ColumnLayout {
          anchors.centerIn: parent
          width: Math.min(parent.width - Style.spacing.panelPadding * 2, Style.space(320))
          spacing: Style.space(10)

          Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Style.space(44)
            Layout.preferredHeight: Style.space(44)

            OpticalGlyph {
              anchors.centerIn: parent
              width: Style.space(36)
              height: Style.space(36)
              text: Model.meetingIcon()
              fontFamily: root.fontFamily
              fontSize: Style.font.iconLarge
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.42)
            }
          }

          Text {
            Layout.fillWidth: true
            text: "No meetings yet"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
          }

          Text {
            Layout.fillWidth: true
            text: "Create your first one above to get started."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
          }
        }
      }

      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: listAreaHeight
        visible: meetings.length > 0

        ColumnLayout {
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          spacing: Style.space(6)

        Text {
          Layout.fillWidth: true
          visible: filteredMeetings.length === 0
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          text: Model.isTagFilterQuery(root.searchQuery)
            ? ("No meetings tagged " + Model.tagChipLabel(root.searchQuery) + ".")
            : "No meetings match your search."
        }

        Repeater {
          model: visibleMeetings

          delegate: CursorSurface {
            id: meetingRow
            required property var modelData
            property bool pointerHot: false
            Layout.fillWidth: true
            Layout.preferredHeight: listRowHeight - Style.space(6)
            foreground: root.foreground
            accent: (root.recordingMeetingPath !== "" && modelData.path === root.recordingMeetingPath) ? root.urgent : Color.accent
            bordered: true
            hasCursor: pointerHot || (root.recordingMeetingPath !== "" && modelData.path === root.recordingMeetingPath)
            current: root.recordingMeetingPath !== "" && modelData.path === root.recordingMeetingPath

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.spacing.controlPaddingX
              anchors.rightMargin: Style.space(6)
              spacing: Style.space(4)

              Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                HoverHandler {
                  onHoveredChanged: meetingRow.pointerHot = hovered
                }

                PanelToolTip {
                  visible: meetingRow.pointerHot
                  text: "Open this meeting"
                  fontFamily: root.fontFamily
                }

                ColumnLayout {
                  anchors.fill: parent
                  spacing: Style.space(2)

                  Text {
                    text: Model.meetingLabel(modelData)
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                  }

                  Text {
                    text: Model.meetingListSubtitle(modelData, root.nowSeconds)
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    Layout.fillWidth: true
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.showDetail(modelData.path, { entry: modelData, resetTab: false })
                }
              }

              PanelActionButton {
                Layout.alignment: Qt.AlignVCenter
                iconText: "󰅖"
                foreground: root.dim
                hoverColor: root.urgent
                fontFamily: root.fontFamily
                bordered: false
                tooltipText: Model.deleteMeetingTooltip(state, modelData.path, recordingMeetingPath)
                enabled: Model.canDeleteMeeting(state, modelData.path, recordingMeetingPath) && !busy
                onClicked: root.deleteMeeting(modelData.path)
              }
            }
          }
        }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Style.space(8)
        visible: listPaginationLabel !== ""
        spacing: Style.spacing.controlGap

        PanelActionButton {
          visible: listPaginationVisible
          iconText: "󰁍"
          foreground: root.foreground
          hoverColor: root.foreground
          fontFamily: root.fontFamily
          bordered: true
          tooltipText: "Previous page"
          enabled: Model.canGoListPagePrev(safeListPage, filteredMeetingsCount, listMeetingsMax)
          onClicked: root.showPrevListPage()
        }

        Text {
          Layout.fillWidth: true
          text: listPaginationLabel
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          horizontalAlignment: listPaginationVisible ? Text.AlignHCenter : Text.AlignRight
        }

        PanelActionButton {
          visible: listPaginationVisible
          iconText: "󰁔"
          foreground: root.foreground
          hoverColor: root.foreground
          fontFamily: root.fontFamily
          bordered: true
          tooltipText: "Next page"
          enabled: Model.canGoListPageNext(safeListPage, filteredMeetingsCount, listMeetingsMax)
          onClicked: root.showNextListPage()
        }
      }
    }
  }

  Component {
    id: detailScreen

    ColumnLayout {
      width: parent.width
      spacing: Style.spacing.panelGap

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing.controlGap

        PanelActionButton {
          iconText: "󰁍"
          foreground: root.foreground
          hoverColor: root.foreground
          fontFamily: root.fontFamily
          bordered: true
          tooltipText: "Back to meetings list"
          onClicked: root.showList()
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.space(2)

          Text {
            text: root.detailHeaderTitle
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
            elide: Text.ElideRight
            Layout.fillWidth: true
          }

          Text {
            visible: root.detailHeaderSubtitle !== ""
            text: root.detailHeaderSubtitle
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            Layout.fillWidth: true
          }
        }

        PanelActionButton {
          iconText: "󰐃"
          foreground: root.foreground
          hoverColor: root.foreground
          fontFamily: root.fontFamily
          bordered: true
          tooltipText: "Float as a pinned window you can keep using during the call"
          onClicked: root.detachPanel()
        }

        PanelActionButton {
          iconText: "󰆴"
          foreground: root.urgent
          hoverColor: root.urgent
          fontFamily: root.fontFamily
          bordered: true
          tooltipText: Model.deleteMeetingTooltip(state, state.meetingPath, recordingMeetingPath)
          enabled: Model.canDeleteMeeting(state, state.meetingPath, recordingMeetingPath) && !busy
          onClicked: root.deleteMeeting(state.meetingPath)
        }
      }

      Flow {
        Layout.fillWidth: true
        spacing: Style.space(6)
        visible: currentMeetingTags.length > 0

        Repeater {
          model: currentMeetingTags

          delegate: CursorSurface {
            required property var modelData
            property bool pointerHot: false
            implicitWidth: detailTagLabel.implicitWidth + Style.space(16)
            implicitHeight: detailTagLabel.implicitHeight + Style.space(10)
            foreground: root.foreground
            accent: Color.accent
            bordered: true
            hasCursor: pointerHot

            HoverHandler {
              onHoveredChanged: pointerHot = hovered
            }

            PanelToolTip {
              visible: pointerHot
              text: "Remove " + Model.tagChipLabel(modelData)
              fontFamily: root.fontFamily
            }

            Text {
              id: detailTagLabel
              anchors.centerIn: parent
              text: Model.tagChipLabel(modelData)
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.removeDetailTag(modelData)
            }
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing.controlGap
        visible: state.meetingPath !== ""

        TextField {
          id: tagAddField
          Layout.fillWidth: true
          text: root.tagDraft
          placeholderText: currentMeetingTags.length > 0 ? "Add another tag" : "Add tags · standup, 1-1"
          enabled: !busy
          color: root.foreground
          placeholderTextColor: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          onTextChanged: root.tagDraft = text
          Keys.onReturnPressed: root.addDetailTag()
          Keys.onEnterPressed: root.addDetailTag()
        }

        PanelTextButton {
          label: "Add"
          tooltip: "Save this tag on the meeting"
          labelColor: root.foreground
          accentColor: Color.accent
          fontFamily: root.fontFamily
          fontPixelSize: Style.font.bodySmall
          actionable: !busy && Model.normalizeTag(root.tagDraft) !== ""
          onActivated: root.addDetailTag()
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
        visible: detailActive && !recordingThisMeeting && !busy

        PanelTextButton {
          Layout.fillWidth: true
          label: "Start transcribing"
          tooltip: "Capture audio and transcribe live"
          labelBold: true
          labelColor: root.foreground
          accentColor: Color.accent
          fontFamily: root.fontFamily
          actionable: !busy && state.voxtypeReady
          onActivated: root.startTranscription()
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing.controlGap
        visible: detailActive && recordingThisMeeting

        PanelTextButton {
          Layout.fillWidth: true
          label: "Stop transcribing"
          tooltip: "Stop capture and save the meeting"
          labelBold: true
          labelColor: root.urgent
          accentColor: root.urgent
          urgentColor: root.urgent
          fontFamily: root.fontFamily
          onActivated: root.stopTranscription()
        }
      }

      PanelSectionHeader {
        Layout.fillWidth: true
        visible: detailActive && recordingThisMeeting
        text: liveSummaryText !== ""
          ? "Live summary"
          : (state.summaryRefreshing ? "Live summary · updating…" : "Live summary · waiting")
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      Text {
        Layout.fillWidth: true
        visible: detailActive && recordingThisMeeting && liveSummaryStatus !== ""
        text: liveSummaryStatus
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WordWrap
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(Style.space(240), Math.max(Style.space(120), liveSummaryField.contentHeight + Style.space(24)))
        visible: detailActive && recordingThisMeeting
        radius: Style.cornerRadius
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)
        border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)

        ScrollView {
          anchors.fill: parent
          anchors.margins: Style.spacing.panelPadding
          clip: true

          TextArea {
            id: liveSummaryField
            readOnly: true
            wrapMode: TextArea.Wrap
            text: liveSummaryText || (state.summaryRefreshing ? "Generating summary…" : "")
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            background: null
          }
        }
      }

      PanelSectionHeader {
        Layout.fillWidth: true
        visible: detailActive && recordingThisMeeting
        text: liveTranscriptText !== ""
          ? (state.speakerCount > 0
            ? ("Live transcript · " + state.speakerCount + " speaker" + (state.speakerCount === 1 ? "" : "s"))
            : "Live transcript")
          : ("Live transcript · waiting for first chunk")
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Style.space(200)
        visible: detailActive && recordingThisMeeting
        radius: Style.cornerRadius
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)
        border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)

        ScrollView {
          anchors.fill: parent
          anchors.margins: Style.spacing.panelPadding
          clip: true

          TextArea {
            id: liveTranscriptField
            readOnly: true
            wrapMode: TextArea.Wrap
            text: liveTranscriptText || (busy ? "" : liveTranscriptWaitingText)
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            background: null
          }
        }
      }

      PanelSectionHeader {
        Layout.fillWidth: true
        visible: detailActive
        text: "Your notes"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: detailNotesHeight
        visible: detailActive
        radius: Style.cornerRadius
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)
        border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)

        TextArea {
          id: activeNotesField
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

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing.controlGap
        visible: detailFinished

        PanelTextButton {
          Layout.fillWidth: true
          label: Model.askAgentButtonLabel(root.state)
          tooltip: Model.askAgentTooltip(root.state)
          labelBold: true
          labelColor: root.foreground
          accentColor: Color.accent
          fontFamily: root.fontFamily
          actionable: !root.busy && Model.canAskAgent(root.state)
          onActivated: root.askAgentWithMeeting()
        }

        PanelTextButton {
          Layout.preferredWidth: implicitWidth
          label: "Copy"
          tooltip: "Copy notes, summary, and transcript"
          highlighted: copyMenuOpen
          labelColor: root.foreground
          accentColor: Color.accent
          fontFamily: root.fontFamily
          actionable: !root.busy && (Model.hasMeetingContent(root.state) || root.detailFinished)
          onActivated: copyMenuOpen = !copyMenuOpen
        }
      }

      Column {
        Layout.fillWidth: true
        visible: detailFinished && copyMenuOpen
        spacing: Style.space(4)

        PanelTextButton {
          width: parent.width
          label: "Copy as text"
          tooltip: "Copy meeting content as plain text"
          labelColor: root.foreground
          accentColor: Color.accent
          fontFamily: root.fontFamily
          fontPixelSize: Style.font.bodySmall
          onActivated: root.copyCurrent("text")
        }

        PanelTextButton {
          width: parent.width
          label: "Copy as Markdown"
          tooltip: "Copy meeting content as Markdown"
          labelColor: root.foreground
          accentColor: Color.accent
          fontFamily: root.fontFamily
          fontPixelSize: Style.font.bodySmall
          onActivated: root.copyCurrent("markdown")
        }
      }

      Row {
        Layout.fillWidth: true
        spacing: Style.space(6)
        visible: detailFinished

        Repeater {
          model: detailTabs

          delegate: CursorSurface {
            required property int index
            required property var modelData
            property bool pointerHot: false
            width: Math.max(Style.space(80), (parent.width - Style.space(6) * Math.max(detailTabs.length - 1, 0)) / Math.max(detailTabs.length, 1))
            height: detailTabLabel.implicitHeight + Style.space(14)
            foreground: root.foreground
            accent: Color.accent
            bordered: true
            hasCursor: pointerHot
            current: safeDetailTabIndex === index

            HoverHandler {
              onHoveredChanged: pointerHot = hovered
            }

            PanelToolTip {
              visible: pointerHot
              text: Model.detailTabTooltip(modelData.id)
              fontFamily: root.fontFamily
            }

            Text {
              id: detailTabLabel
              anchors.centerIn: parent
              text: modelData.label
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: safeDetailTabIndex === index
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                detailTabIndex = index
                notesEditorVisible = modelData.id === "notes"
              }
            }
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: detailNotesHeight
        visible: detailFinished
        radius: Style.cornerRadius
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)
        border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)

        ColumnLayout {
          id: detailBody
          anchors.fill: parent
          anchors.margins: Style.spacing.panelPadding
          spacing: Style.spacing.controlGap

          ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: activeDetailTabId === "notes"
            clip: true

            TextArea {
              id: notesField
              text: root.notesDraft
              wrapMode: TextArea.Wrap
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              placeholderText: "Your meeting notes…"
              placeholderTextColor: root.dim
              background: null
              onTextChanged: {
                root.notesDraft = text
                root.scheduleNotesSave()
              }
            }
          }

          ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: activeDetailTabId !== "notes"
            clip: true

            TextArea {
              id: detailReadOnly
              readOnly: true
              wrapMode: TextArea.Wrap
              text: activeDetailText || (busy ? String(state.busyLabel || "Working…") : "Nothing here yet.")
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              background: null
            }
          }

          PanelTextButton {
            Layout.fillWidth: true
            visible: activeDetailTabId === "notes"
            label: "Save notes"
            tooltip: "Save notes to this meeting folder"
            labelColor: root.foreground
            accentColor: Color.accent
            fontFamily: root.fontFamily
            actionable: !busy
            onActivated: root.saveNotesDraft()
          }
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
    }
  }

  Component {
    id: settingsScreen

    ColumnLayout {
      width: parent.width
      spacing: Style.spacing.panelGap

      RowLayout {
        Layout.fillWidth: true

        PanelActionButton {
          iconText: "󰁍"
          foreground: root.foreground
          hoverColor: root.foreground
          fontFamily: root.fontFamily
          bordered: true
          tooltipText: "Back to meetings list"
          onClicked: root.showList()
        }

        Text {
          text: "Settings"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
          Layout.fillWidth: true
        }
      }

      PanelSectionHeader {
        Layout.fillWidth: true
        text: "NOTES FOLDER"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing.controlGap

        TextField {
          Layout.fillWidth: true
          text: setting("notesDir", "")
          placeholderText: state.notesDir || "~/.local/state/omarchy/meetings"
          foreground: root.foreground
          accent: Color.accent
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          onEditingFinished: if (service) service.persistSetting("notesDir", text.trim())
        }

        PanelActionButton {
          iconText: ""
          foreground: root.foreground
          hoverColor: root.foreground
          fontFamily: root.fontFamily
          bordered: true
          tooltipText: "Open notes folder in file manager"
          onClicked: root.openNotesDir()
        }
      }

      PanelSectionHeader {
        Layout.fillWidth: true
        Layout.topMargin: Style.space(8)
        text: "MEETINGS PER PAGE"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      Flow {
        Layout.fillWidth: true
        spacing: Style.space(4)

        Repeater {
          model: Model.listMeetingsMaxOptions()

          delegate: CursorSurface {
            required property int modelData
            property bool pointerHot: false
            width: listMaxLabel.implicitWidth + Style.space(18)
            height: listMaxLabel.implicitHeight + Style.space(12)
            foreground: root.foreground
            accent: Color.accent
            bordered: true
            hasCursor: pointerHot
            current: listMeetingsMax === modelData

            HoverHandler {
              onHoveredChanged: pointerHot = hovered
            }

            PanelToolTip {
              visible: pointerHot
              text: Model.listMeetingsMaxTooltip(modelData)
              fontFamily: root.fontFamily
            }

            Text {
              id: listMaxLabel
              anchors.centerIn: parent
              text: String(modelData)
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (service) service.persistSetting("listMeetingsMax", String(modelData))
              }
            }
          }
        }
      }

      Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        text: "How many meetings to show per page. Use the arrows under the list to see older meetings."
      }

      PanelSectionHeader {
        Layout.fillWidth: true
        Layout.topMargin: Style.space(8)
        text: "DEFAULT LANGUAGE"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      Row {
        spacing: Style.space(4)

        Repeater {
          model: ["auto", "es", "en", "fr", "de"]

          delegate: CursorSurface {
            required property string modelData
            property bool pointerHot: false
            width: langLabel.implicitWidth + Style.space(18)
            height: langLabel.implicitHeight + Style.space(12)
            foreground: root.foreground
            accent: Color.accent
            bordered: true
            hasCursor: pointerHot
            current: setting("whisperLanguage", "es") === modelData

            HoverHandler {
              onHoveredChanged: pointerHot = hovered
            }

            PanelToolTip {
              visible: pointerHot
              text: Model.whisperLanguageTooltip(modelData)
              fontFamily: root.fontFamily
            }

            Text {
              id: langLabel
              anchors.centerIn: parent
              text: modelData
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (service) service.persistSetting("whisperLanguage", modelData)
              }
            }
          }
        }
      }

      PanelSectionHeader {
        Layout.fillWidth: true
        Layout.topMargin: Style.space(8)
        text: "SUMMARY PREPROMPT"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      BorderSurface {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(Style.space(120), Math.max(Style.space(60), settingsPrepromptField.contentHeight + Style.space(16)))
        radius: Style.cornerRadius
        color: Style.controlFill(
          settingsPrepromptField.activeFocus,
          settingsPrepromptField.hovered,
          root.foreground,
          Color.accent
        )
        borderSpec: Border.controlSpec(
          settingsPrepromptField.activeFocus ? "focus" : "normal",
          root.foreground,
          Color.accent
        )

        TextArea {
          id: settingsPrepromptField
          anchors.fill: parent
          anchors.margins: Style.spacing.controlPaddingX
          text: setting("summaryPreprompt", "")
          wrapMode: TextArea.Wrap
          placeholderText: "Extra instructions for the AI summary…"
          color: root.foreground
          placeholderTextColor: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          background: null
          onEditingFinished: if (service) service.persistSetting("summaryPreprompt", text.trim())
        }
      }

      PanelSectionHeader {
        Layout.fillWidth: true
        Layout.topMargin: Style.space(8)
        text: "AGENT SKILL"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        text: Model.skillInstallHelpText()
      }

      Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        text: Model.skillInstallStatusText(state.skillInstalled === true)
      }

      Text {
        Layout.fillWidth: true
        visible: busy
        wrapMode: Text.WordWrap
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        text: String(state.busyLabel || "Working…")
      }

      PanelTextButton {
        Layout.fillWidth: true
        label: Model.skillInstallLabel(state.skillInstalled === true)
        tooltip: Model.skillInstallTooltip(state.skillInstalled === true)
        labelBold: true
        labelColor: root.foreground
        accentColor: Color.accent
        fontFamily: root.fontFamily
        actionable: !busy
        onActivated: {
          if (service) service.installSkill()
        }
      }

      Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        text: Model.skillGithubInstallCommand()
      }

      Text {
        Layout.fillWidth: true
        visible: String(state.skillInstallError || "") !== ""
        wrapMode: Text.WordWrap
        color: root.urgent
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        text: Model.formatUserError(state.skillInstallError)
      }
    }
  }
}
