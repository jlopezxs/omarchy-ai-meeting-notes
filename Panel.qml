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
  property string pendingSettingsAction: ""
  property bool awaitingOnboardingReset: false

  readonly property var state: service ? service.state : Model.emptyState()
  readonly property var meetings: Model.sortMeetings(state.meetings || [])
  readonly property bool needsOnboarding: !onboardingDismissed
    && service
    && service.helperReady
    && state.onboardingComplete !== true
  readonly property var filteredMeetings: Model.filterMeetings(meetings, searchQuery)
  readonly property int listMeetingsMax: Model.normalizeListMeetingsMax(setting("listMeetingsMax", 5))
  readonly property int filteredMeetingsCount: filteredMeetings.length
  readonly property int safeListPage: Model.normalizeListPage(listPage, filteredMeetingsCount, listMeetingsMax)
  readonly property var visibleMeetings: Model.meetingsForList(meetings, searchQuery, listMeetingsMax, listPage)
  readonly property var meetingStats: Model.meetingStats(meetings, nowSeconds)
  readonly property string listPaginationLabel: Model.listMeetingsPaginationLabel(filteredMeetingsCount, safeListPage, listMeetingsMax)
  readonly property bool listPaginationVisible: Model.listPaginationVisible(filteredMeetingsCount, listMeetingsMax)
  readonly property int listRowHeight: Style.space(44)
  readonly property int listAreaHeight: listMeetingsMax * listRowHeight
  readonly property int detailNotesHeight: Style.space(220)
  readonly property bool recording: state.recording === true
  readonly property bool recordingThisMeeting: state.recordingThisMeeting === true
  readonly property string recordingMeetingPath: state.recordingMeetingPath || ""
  readonly property string detailMeetingPath: Model.resolveDetailMeetingPath(
    service ? service.state : null,
    lastDetailPath,
    detailMeeting,
    setting("panelDetailPath", "")
  )
  readonly property bool busy: state.busy === true
  readonly property bool actionBusy: Model.actionBusy(state)
  readonly property int displayDurationSecs: recordingThisMeeting && state.startedAt > 0
    ? Math.max(state.durationSecs, nowSeconds - state.startedAt)
    : state.durationSecs
  readonly property string detailHeaderTitle: Model.detailHeaderTitle(state, detailMeeting, titleDraft)
  readonly property string detailHeaderSubtitle: Model.detailHeaderSubtitle(state, detailMeeting)
  readonly property string lastError: Model.formatUserError(
    state.summaryError || state.error || (service ? service.lastError : "")
  )
  readonly property var detailTabs: Model.detailTabs(state)
  readonly property string detailPhase: Model.detailPhase(state)
  readonly property bool detailActive: detailPhase === "active"
  readonly property bool detailFinished: detailPhase === "finished"
  readonly property int safeDetailTabIndex: Model.normalizeDetailTabIndex(state, detailTabIndex)
  readonly property string activeDetailTabId: detailTabs.length > safeDetailTabIndex
    ? detailTabs[safeDetailTabIndex].id
    : "summary"
  readonly property string activeDetailText: Model.detailTabContent(state, activeDetailTabId)
  readonly property var summaryUiState: Model.withAiSummaries(state, setting("aiSummaries", false))
  readonly property int chunkSecondsSetting: Model.normalizeChunkSeconds(setting("chunkSeconds", 30))

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

  function installSkill() {
    if (service) service.installSkill()
  }

  function requestSettingsAction(action) {
    pendingSettingsAction = action
    settingsConfirm.selectedIndex = 1
  }

  function applyResetSettings() {
    awaitingOnboardingReset = true
    var defaults = Model.defaultWidgetSettings()
    for (var key in defaults)
      if (service) service.persistSetting(key, defaults[key])
    if (service) service.resetSettings()
    onboardingDismissed = false
    onboardingStep = 0
    screen = "list"
    copyMenuOpen = false
  }

  function applyDeleteAllMeetings() {
    if (service) service.deleteAllMeetings()
    detailMeeting = null
    lastDetailPath = ""
    notesDraft = ""
    if (screen === "detail") showList()
  }

  function nextOnboardingStep() {
    if (onboardingStep < 2) onboardingStep += 1
  }

  function prevOnboardingStep() {
    if (onboardingStep > 0) onboardingStep -= 1
  }

  function showDetail(path, options) {
    options = options || {}
    var meetingPath = String(path || root.state.meetingPath || "").trim()
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
      detailTabIndex = Model.tabIndexFor(root.state, "summary")
    notesDraft = root.state.meetingPath === meetingPath ? (root.state.notes || "") : ""
    notesEditorVisible = false
    copyMenuOpen = false
  }

  function openRecordingMeeting() {
    var path = Model.recordingOpenPath(root.state)
    if (path === "") {
      for (var i = 0; i < meetings.length; i++) {
        if (meetings[i] && meetings[i].isRecording === true && meetings[i].path) {
          path = String(meetings[i].path)
          break
        }
      }
    }
    if (path === "") return
    showDetail(path, {
      entry: Model.findMeetingByPath(meetings, path),
      resetTab: false
    })
  }

  function showSettings() {
    screen = "settings"
    copyMenuOpen = false
    if (service) {
      service.persistSetting("panelScreen", "settings")
      service.refresh()
    }
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
    if (!service || actionBusy) return
    createdMeetingGuardPath = String(state.meetingPath || "")
    waitingForCreatedMeeting = true
    service.createMeeting(titleDraft.trim() || "Meeting")
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
    root.copyMenuOpen = false
    if (!text) return
    copyProc.textToCopy = text
    copyProc.stdinEnabled = true
    copyProc.running = false
    Qt.callLater(function() { copyProc.running = true })
  }

  function askAgentWithMeeting() {
    if (!service || actionBusy) return
    if (root.state.skillInstalled !== true) {
      root.installSkill()
      return
    }
    service.openAgentWithMeeting(root.detailMeetingPath || root.state.meetingPath || "")
  }

  function askAgentFromList() {
    if (!service || actionBusy) return
    if (root.state.skillInstalled !== true) {
      root.installSkill()
      return
    }
    service.openAgentWithSkill()
  }

  function generateSummary() {
    if (!service) return
    var path = String(root.detailMeetingPath || root.state.meetingPath || "").trim()
    if (!path) return
    service.generateSummary(path)
  }

  function deleteMeeting(path) {
    var target = Model.resolveDetailMeetingPath(
      service ? service.state : null,
      path || lastDetailPath,
      detailMeeting,
      setting("panelDetailPath", "")
    )
    if (!service || !target) return
    service.deleteMeeting(target)
    if (screen === "detail") showList()
  }

  function copyCurrent(mode) {
    if (mode === "markdown") copyText(Model.buildCopyMarkdown(root.state))
    else copyText(Model.buildCopyText(root.state, activeDetailTabId))
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
    if (awaitingOnboardingReset) {
      if (state.onboardingComplete !== true) {
        awaitingOnboardingReset = false
        onboardingDismissed = false
      }
    } else if (state.onboardingComplete === true) {
      onboardingDismissed = true
    }
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

  Timer {
    interval: 2500
    running: root.opened && root.screen === "settings"
    repeat: true
    onTriggered: if (service) service.refresh()
  }

  Process {
    id: copyProc
    property string textToCopy: ""
    command: ["wl-copy"]
    stdinEnabled: true
    onStarted: {
      write(textToCopy)
      stdinEnabled = false
    }
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
      onCloseRequested: {
        if (root.pendingSettingsAction !== "") {
          root.pendingSettingsAction = ""
          return
        }
        if (needsOnboarding) root.close()
        else if (screen !== "list") showList()
        else root.close()
      }
      onMoveRequested: function(dx, dy) {
        if (root.pendingSettingsAction === "") return
        if (dx !== 0)
          settingsConfirm.selectedIndex = settingsConfirm.selectedIndex === 0 ? 1 : 0
      }
      onActivateRequested: {
        if (root.pendingSettingsAction === "") return
        if (settingsConfirm.selectedIndex === 0) settingsConfirm.canceled()
        else settingsConfirm.confirmed()
      }
      onTabRequested: function(direction) {
        if (root.pendingSettingsAction !== "") {
          settingsConfirm.selectedIndex = settingsConfirm.selectedIndex === 0 ? 1 : 0
          return
        }
        root.switchPanel(direction)
      }
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

    ConfirmDialog {
      id: settingsConfirm
      anchors.fill: parent
      opened: root.pendingSettingsAction !== ""
      z: 20
      message: root.pendingSettingsAction === "delete-all"
        ? "Delete all meetings permanently? This cannot be undone."
        : "Reset all settings and show onboarding again? Meetings stay on disk."
      confirmText: root.pendingSettingsAction === "delete-all" ? "Delete all" : "Reset"
      background: Color.popups.background
      foreground: root.foreground
      scrim: Qt.rgba(0, 0, 0, 0.55)
      selectedBackground: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
      selectedText: Color.accent
      fontFamily: root.fontFamily
      cornerRadius: Style.cornerRadius
      onCanceled: root.pendingSettingsAction = ""
      onConfirmed: {
        if (root.pendingSettingsAction === "delete-all")
          root.applyDeleteAllMeetings()
        else if (root.pendingSettingsAction === "reset")
          root.applyResetSettings()
        root.pendingSettingsAction = ""
      }
    }
  }

  Component {
    id: onboardingScreen

    ColumnLayout {
      width: parent.width
      spacing: Style.space(10)

      Text {
        text: "AI Meeting Notepad"
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
            text: Model.onboardingStepBody(onboardingStep, root.state.voxtypeReady)
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
          visible: !root.state.voxtypeReady
          label: "Install Voxtype"
          tooltip: "Open the Voxtype installer"
          labelColor: root.foreground
          accentColor: Color.accent
          fontFamily: root.fontFamily
          onActivated: root.installVoxtype()
        }

        PanelTextButton {
          Layout.fillWidth: true
          visible: !root.state.voxtypeReady
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
              text: "AI Meeting Notepad"
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
        visible: !root.recording
        text: "NEW MEETING"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      RowLayout {
        Layout.fillWidth: true
        visible: !root.recording
        spacing: Style.spacing.controlGap

        TextField {
          id: newMeetingTitle
          Layout.fillWidth: true
          Layout.fillHeight: true
          text: root.titleDraft
          placeholderText: "Meeting title"
          enabled: !root.actionBusy && root.state.voxtypeReady
          color: root.foreground
          placeholderTextColor: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          onTextChanged: root.titleDraft = text
        }

        PanelTextButton {
          Layout.fillHeight: true
          Layout.preferredHeight: newMeetingTitle.implicitHeight
          implicitHeight: newMeetingTitle.implicitHeight
          label: "Create"
          tooltip: "Create a draft meeting in the list"
          labelBold: true
          labelColor: root.foreground
          accentColor: Color.accent
          fontFamily: root.fontFamily
          actionable: !root.actionBusy && root.state.voxtypeReady && !root.recording
          onActivated: root.createMeeting()
        }
      }

      CaptureStatusBox {
        Layout.fillWidth: true
        visible: root.recording
        iconText: "󰻃"
        title: "TRANSCRIBING"
        titleTrailing: Model.recordingStatusDetail(root.state, root.nowSeconds)
        headline: Model.recordingBannerTitle(root.state)
        showDot: root.recording && !root.busy
        showOpenStop: true
        detail: ""
        footer: ""
        progress: -1
        foreground: root.foreground
        accent: root.urgent
        dim: root.dim
        fontFamily: root.fontFamily
        onOpenClicked: root.openRecordingMeeting()
        onStopClicked: root.stopTranscription()
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
        Layout.topMargin: Style.space(2)
        Layout.bottomMargin: Style.space(2)
        Layout.preferredHeight: 1
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.16)
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing.controlGap

        PanelSectionHeader {
          Layout.fillWidth: true
          text: "MEETINGS"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        PanelTextButton {
          label: Model.askAgentButtonLabel(root.state)
          tooltip: Model.askAgentListTooltip(root.state)
          labelColor: root.foreground
          accentColor: Color.accent
          fontFamily: root.fontFamily
          fontPixelSize: Style.font.bodySmall
          actionable: !root.actionBusy
          onActivated: root.askAgentFromList()
        }
      }

      Rectangle {
        Layout.fillWidth: true
        visible: meetings.length > 0
        radius: Style.cornerRadius
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)
        border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
        implicitHeight: statsRow.implicitHeight + Style.spacing.panelPadding * 2

        RowLayout {
          id: statsRow
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: Style.spacing.panelPadding
          anchors.rightMargin: Style.spacing.panelPadding
          spacing: Style.space(8)

          Column {
            Layout.fillWidth: true
            spacing: Style.space(2)

            Text {
              text: "MEETS"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 0.6
            }
            Text {
              text: meetingStats.countLabel
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
            }
          }

          Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: Style.space(28)
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
          }

          Column {
            Layout.fillWidth: true
            spacing: Style.space(2)

            Text {
              text: "TOTAL"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 0.6
            }
            Text {
              text: meetingStats.totalLabel
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
            }
          }

          Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: Style.space(28)
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
          }

          Column {
            Layout.fillWidth: true
            spacing: Style.space(2)

            Text {
              text: "AVG"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 0.6
            }
            Text {
              text: meetingStats.avgLabel
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
            }
          }

          Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: Style.space(28)
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
          }

          Column {
            Layout.fillWidth: true
            spacing: Style.space(2)

            Text {
              text: "PER DAY"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 0.6
            }
            Text {
              text: meetingStats.perDayLabel
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
            }
          }
        }
      }

      TextField {
        id: searchField
        Layout.fillWidth: true
        text: root.searchQuery
        placeholderText: "Search titles, notes, or transcripts…"
        color: root.foreground
        placeholderTextColor: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        onTextChanged: root.searchQuery = text
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
          spacing: Style.space(4)

        Text {
          Layout.fillWidth: true
          visible: filteredMeetings.length === 0
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          text: "No meetings match your search."
        }

        Repeater {
          model: root.visibleMeetings

          delegate: CursorSurface {
            id: meetingRow
            required property var modelData
            readonly property bool isRecordingRow: root.recordingMeetingPath !== "" && modelData.path === root.recordingMeetingPath
            readonly property bool canDelete: Model.canDeleteMeeting(root.state, modelData.path, root.recordingMeetingPath) && !root.busy

            Layout.fillWidth: true
            implicitHeight: rowBody.implicitHeight
            foreground: root.foreground
            accent: isRecordingRow ? root.urgent : Color.accent
            hasCursor: rowMouse.containsMouse && !deleteMouse.containsMouse
            current: isRecordingRow

                MouseArea {
                  id: rowMouse
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  height: rowBody.implicitHeight
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.showDetail(modelData.path, { entry: modelData, resetTab: false })
                }

                PanelToolTip {
                  visible: rowMouse.containsMouse && !deleteMouse.containsMouse
                  text: "Open this meeting"
                  fontFamily: root.fontFamily
                }

                Item {
                  id: rowBody
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.leftMargin: Style.space(10)
                  anchors.rightMargin: Style.space(10)
                  implicitHeight: Math.max(meetingInfo.implicitHeight, deleteAction.implicitHeight) + Style.spacing.rowPaddingX

                  Item {
                    id: deleteAction
                    width: Style.space(22)
                    implicitHeight: deleteGlyph.implicitHeight
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                      id: deleteGlyph
                      width: parent.width
                      anchors.verticalCenter: parent.verticalCenter
                      horizontalAlignment: Text.AlignHCenter
                      text: "󰅖"
                      color: deleteMouse.containsMouse && meetingRow.canDelete
                        ? root.urgent
                        : Qt.darker(root.foreground, 1.4)
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.subtitle
                      opacity: meetingRow.canDelete ? 1 : 0.35
                    }

                    MouseArea {
                      id: deleteMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      acceptedButtons: Qt.LeftButton
                      enabled: meetingRow.canDelete
                      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                      onClicked: root.deleteMeeting(modelData.path)
                    }

                    PanelToolTip {
                      visible: deleteMouse.containsMouse
                      text: Model.deleteMeetingTooltip(root.state, modelData.path, root.recordingMeetingPath)
                      fontFamily: root.fontFamily
                    }
                  }

                  Column {
                    id: meetingInfo
                    spacing: Style.space(1)
                    anchors.left: parent.left
                    anchors.right: deleteAction.left
                    anchors.rightMargin: Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                      text: Model.meetingLabel(modelData)
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      elide: Text.ElideRight
                      width: parent.width
                    }

                    Text {
                      text: Model.meetingListSubtitle(modelData, root.nowSeconds)
                      visible: text !== ""
                      height: visible ? implicitHeight : 0
                      color: meetingRow.isRecordingRow ? root.urgent : Qt.darker(root.foreground, 1.5)
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                      width: parent.width
                    }
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

        Item {
          visible: listPaginationVisible
          implicitWidth: Style.space(22)
          implicitHeight: Style.space(22)
          enabled: Model.canGoListPagePrev(safeListPage, filteredMeetingsCount, listMeetingsMax)
          opacity: enabled ? 1 : 0.4

          Text {
            anchors.centerIn: parent
            text: "󰁍"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.icon
          }

          MouseArea {
            id: prevPageMouse
            anchors.fill: parent
            enabled: parent.enabled
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.showPrevListPage()
          }

          PanelToolTip {
            visible: prevPageMouse.containsMouse
            text: "Previous page"
            fontFamily: root.fontFamily
          }
        }

        Text {
          Layout.fillWidth: true
          text: listPaginationLabel
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          horizontalAlignment: listPaginationVisible ? Text.AlignHCenter : Text.AlignRight
        }

        Item {
          visible: listPaginationVisible
          implicitWidth: Style.space(22)
          implicitHeight: Style.space(22)
          enabled: Model.canGoListPageNext(safeListPage, filteredMeetingsCount, listMeetingsMax)
          opacity: enabled ? 1 : 0.4

          Text {
            anchors.centerIn: parent
            text: "󰁔"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.icon
          }

          MouseArea {
            id: nextPageMouse
            anchors.fill: parent
            enabled: parent.enabled
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.showNextListPage()
          }

          PanelToolTip {
            visible: nextPageMouse.containsMouse
            text: "Next page"
            fontFamily: root.fontFamily
          }
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
          tooltipText: "Delete this meeting permanently"
          onClicked: root.deleteMeeting(root.lastDetailPath || root.detailMeetingPath)
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing.controlGap
        visible: Model.captureStatusVisible(root.state)

        CaptureStatusBox {
          Layout.fillWidth: true
          visible: recordingThisMeeting
          iconText: "󰻃"
          title: "TRANSCRIBING"
          titleTrailing: Model.recordingStatusDetail(root.state, nowSeconds)
          headline: Model.recordingBannerTitle(root.state)
          showDot: recordingThisMeeting && !root.busy
          showOpenStop: true
          showOpenAction: false
          detail: ""
          footer: ""
          progress: -1
          foreground: root.foreground
          accent: root.urgent
          dim: root.dim
          fontFamily: root.fontFamily
          onStopClicked: root.stopTranscription()
        }

        CaptureStatusBox {
          Layout.fillWidth: true
          visible: Model.isSavingMeeting(root.state)
          iconText: "󰷈"
          title: "SAVING"
          headline: Model.transcriptStatusHeadline(root.state)
          showDot: true
          detail: ""
          footer: Model.transcriptStatusFooter(root.state, nowSeconds, chunkSecondsSetting)
          progress: Model.transcriptProgressRatio(root.state, nowSeconds, chunkSecondsSetting)
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
          actionable: !root.busy && root.state.voxtypeReady
          onActivated: root.startTranscription()
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
        visible: root.detailFinished || Model.canAskAgent(root.state)

        PanelTextButton {
          Layout.fillWidth: true
          label: Model.askAgentButtonLabel(root.state)
          tooltip: Model.askAgentTooltip(root.state)
          labelBold: true
          labelColor: root.foreground
          accentColor: Color.accent
          fontFamily: root.fontFamily
          actionable: !root.actionBusy && Model.canAskAgent(root.state)
          onActivated: root.askAgentWithMeeting()
        }

        PanelTextButton {
          Layout.preferredWidth: implicitWidth
          label: "Copy"
          tooltip: "Copy notes, summary, and transcript"
          highlighted: root.copyMenuOpen
          labelColor: root.foreground
          accentColor: Color.accent
          fontFamily: root.fontFamily
          actionable: !root.busy && (Model.hasMeetingContent(root.state) || root.detailFinished)
          onActivated: root.copyMenuOpen = !root.copyMenuOpen
        }
      }

      Column {
        Layout.fillWidth: true
        visible: root.detailFinished && root.copyMenuOpen
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

          MarkdownView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: activeDetailTabId !== "notes"
              && !Model.summaryLoadingVisible(root.state, activeDetailTabId)
              && !Model.summaryEmptyVisible(root.summaryUiState, activeDetailTabId)
            markdown: activeDetailText
            foreground: root.foreground
            accent: Color.accent
            dim: root.dim
            fontFamily: root.fontFamily
          }

          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Model.summaryEmptyVisible(root.summaryUiState, activeDetailTabId)

            ColumnLayout {
              anchors.centerIn: parent
              width: Math.min(parent.width, Style.space(280))
              spacing: Style.space(10)

              Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Style.space(44)
                Layout.preferredHeight: Style.space(44)

                OpticalGlyph {
                  anchors.centerIn: parent
                  width: Style.space(36)
                  height: Style.space(36)
                  text: Model.summaryEmptyIcon(root.summaryUiState)
                  fontFamily: root.fontFamily
                  fontSize: Style.font.iconLarge
                  color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.42)
                }
              }

              Text {
                Layout.fillWidth: true
                text: Model.summaryEmptyTitle(root.summaryUiState)
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
              }

              Text {
                Layout.fillWidth: true
                text: Model.summaryEmptyCaption(root.summaryUiState)
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
              }

              PanelTextButton {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Style.space(4)
                label: Model.summaryEmptyActionLabel(root.summaryUiState)
                tooltip: Model.summaryEmptyActionTooltip(root.summaryUiState)
                labelBold: true
                labelColor: root.foreground
                accentColor: Color.accent
                fontFamily: root.fontFamily
                actionable: Model.summaryEmptyGenerate(root.summaryUiState)
                  ? Model.canGenerateSummary(root.summaryUiState)
                  : true
                onActivated: {
                  if (Model.summaryEmptyGenerate(root.summaryUiState))
                    root.generateSummary()
                  else
                    root.showSettings()
                }
              }
            }
          }

          LoadingHint {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Model.summaryLoadingVisible(root.state, activeDetailTabId)
            iconText: Model.onboardingStepIcon(1)
            title: Model.summaryLoadingTitle(root.state)
            caption: Model.summaryLoadingCaption(root.state)
            foreground: root.foreground
            accent: Color.accent
            fontFamily: root.fontFamily
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
        visible: lastError !== "" && !(
          String((root.state && root.state.summaryError) || "").trim() !== ""
          && Model.summaryEmptyVisible(root.summaryUiState, activeDetailTabId)
        )
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
        spacing: Style.spacing.controlGap

        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: Math.max(settingsHeroIcon.height, settingsHeroLabels.implicitHeight)

          OpticalGlyph {
            id: settingsHeroIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(36)
            height: Style.space(36)
            text: Model.settingsBackIcon()
            fontFamily: root.fontFamily
            fontSize: Style.font.display
            color: root.foreground
          }

          Column {
            id: settingsHeroLabels
            anchors.left: settingsHeroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "Settings"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              text: Model.settingsHeroSubtitle()
              color: Qt.darker(root.foreground, 1.4)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
              width: parent.width
            }
          }

          MouseArea {
            id: settingsBackHit
            anchors.fill: settingsHeroIcon
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.showList()
          }

          PanelToolTip {
            visible: settingsBackHit.containsMouse
            text: "Back to meetings list"
            fontFamily: root.fontFamily
          }
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
          placeholderText: root.state.notesDir || "~/.local/state/omarchy/meetings"
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
            current: setting("whisperLanguage", "auto") === modelData

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
        text: "AI SUMMARIES"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        text: "Off by default. When on, live and final summaries send the transcript to your default Omarchy agent, which may use a remote provider. Capture and transcripts stay local."
      }

      Row {
        spacing: Style.space(4)

        Repeater {
          model: [
            { id: "off", label: "Off" },
            { id: "on", label: "On" }
          ]

          delegate: CursorSurface {
            required property var modelData
            property bool pointerHot: false
            property bool selected: Model.normalizeBool(setting("aiSummaries", false), false) === (modelData.id === "on")
            width: aiLabel.implicitWidth + Style.space(18)
            height: aiLabel.implicitHeight + Style.space(12)
            foreground: root.foreground
            accent: Color.accent
            bordered: true
            hasCursor: pointerHot
            current: selected

            HoverHandler {
              onHoveredChanged: pointerHot = hovered
            }

            PanelToolTip {
              visible: pointerHot
              text: modelData.id === "on"
                ? "Send transcripts to your default Omarchy agent for summaries"
                : "Keep transcripts local; do not call an agent"
              fontFamily: root.fontFamily
            }

            Text {
              id: aiLabel
              anchors.centerIn: parent
              text: modelData.label
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (service) service.persistSetting("aiSummaries", modelData.id === "on")
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
        visible: busy
        wrapMode: Text.WordWrap
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        text: String(root.state.busyLabel || "Working…")
      }

      PanelTextButton {
        Layout.fillWidth: true
        label: Model.skillInstallLabel(root.state.skillInstalled === true)
        tooltip: Model.skillInstallTooltip(root.state.skillInstalled === true)
        labelBold: true
        labelColor: root.foreground
        accentColor: Color.accent
        fontFamily: root.fontFamily
        actionable: true
        onActivated: root.installSkill()
      }

      Text {
        Layout.fillWidth: true
        visible: String(root.state.skillInstallError || "") !== ""
        wrapMode: Text.WordWrap
        color: root.urgent
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        text: Model.formatUserError(root.state.skillInstallError)
      }

      PanelSectionHeader {
        Layout.fillWidth: true
        Layout.topMargin: Style.space(8)
        text: "DATA"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        text: "Reset restores defaults and onboarding. Meetings stay on disk. Removing the plugin does not reverse Voxtype or delete notes — run uninstall.sh first (see README)."
      }

      PanelTextButton {
        Layout.fillWidth: true
        label: "Reset all settings"
        tooltip: "Restore defaults and show onboarding again. Does not delete meetings."
        labelBold: true
        labelColor: root.foreground
        accentColor: Color.accent
        fontFamily: root.fontFamily
        actionable: !busy
        onActivated: root.requestSettingsAction("reset")
      }

      Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        text: "Permanently delete every meeting folder. Onboarding and settings stay."
      }

      PanelTextButton {
        Layout.fillWidth: true
        label: "Delete all meetings"
        tooltip: "Delete every meeting on disk. This cannot be undone."
        labelBold: true
        labelColor: root.foreground
        accentColor: Color.accent
        urgentColor: root.urgent
        urgent: true
        fontFamily: root.fontFamily
        actionable: !busy && !recording
        onActivated: root.requestSettingsAction("delete-all")
      }
    }
  }
}
