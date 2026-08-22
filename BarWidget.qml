import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "jlopezxs.meetings"

  readonly property string icon: Model.meetingIcon()
  readonly property string recordingIcon: "󰻃" // nf-md-record-circle-outline

  readonly property var service: bar && bar.shell && typeof bar.shell.serviceFor === "function"
    ? bar.shell.serviceFor("jlopezxs.meetings")
    : null

  readonly property var state: service ? service.state : Model.emptyState()
  readonly property bool recording: state.recording === true
  readonly property bool busy: state.busy === true

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool detached: detachedLoader.item ? detachedLoader.item.detached === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true
    : false

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    if ("service" in target) target.service = root.service
  }

  function injectDetached() {
    var target = detachedLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("hostWidget" in target) target.hostWidget = root
    if ("service" in target) target.service = root.service
  }

  function open() {
    injectPanel()
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function togglePanel() {
    if (root.detached) {
      if (detachedLoader.item) detachedLoader.item.focusWindow()
      return
    }
    injectPanel()
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function detachPanel() {
    injectDetached()
    root.close()
    if (detachedLoader.item) detachedLoader.item.show()
  }

  function attachPanel() {
    if (detachedLoader.item) detachedLoader.item.hide()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: {
    injectPanel()
    injectDetached()
  }
  onSettingsChanged: {
    injectPanel()
    injectDetached()
  }
  onServiceChanged: {
    injectPanel()
    injectDetached()
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  Loader {
    id: detachedLoader
    active: true
    source: Qt.resolvedUrl("DetachedWindow.qml")
    onLoaded: {
      root.injectDetached()
      Qt.callLater(root.injectDetached)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.recording ? root.recordingIcon : root.icon
    labelVisible: false
    hasVisualContent: true
    dimmed: !root.service
    active: root.recording
    fixedWidth: root.vertical ? -1 : Style.bar.iconSlot
    fixedHeight: root.vertical ? Style.bar.iconSlot : -1
    tooltipText: root.detached
      ? "AI Meeting Notepad is floating — click to focus"
      : Model.barTooltip(root.state)

    onPressed: function(b) {
      if (b === Qt.MiddleButton) return
      root.togglePanel()
    }

    Rectangle {
      visible: root.recording
      anchors.centerIn: parent
      width: Math.round(Math.min(parent.width, parent.height) * 0.78)
      height: width
      radius: width / 2
      color: button.activeColor

      SequentialAnimation on opacity {
        running: root.recording
        loops: Animation.Infinite
        NumberAnimation { from: 0.08; to: 0.34; duration: 750; easing.type: Easing.InOutSine }
        NumberAnimation { from: 0.34; to: 0.08; duration: 750; easing.type: Easing.InOutSine }
      }
    }

    OpticalGlyph {
      id: barGlyph
      anchors.centerIn: parent
      width: Style.bar.iconCanvas
      height: Style.bar.iconCanvas
      text: root.recording ? root.recordingIcon : root.icon
      fontFamily: button.fontFamily
      fontSize: Style.bar.iconFont
      color: root.recording ? button.activeColor : button.foreground

      SequentialAnimation on opacity {
        running: root.recording
        loops: Animation.Infinite
        onRunningChanged: if (!running) barGlyph.opacity = 1
        NumberAnimation { from: 1; to: 0.38; duration: 700; easing.type: Easing.InOutSine }
        NumberAnimation { from: 0.38; to: 1; duration: 700; easing.type: Easing.InOutSine }
      }
    }

    Rectangle {
      visible: root.recording
      width: Style.space(6)
      height: Style.space(6)
      radius: width / 2
      color: button.activeColor
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.rightMargin: Style.space(1)
      anchors.topMargin: Style.space(1)

      SequentialAnimation on opacity {
        running: root.recording
        loops: Animation.Infinite
        NumberAnimation { from: 1; to: 0.18; duration: 620; easing.type: Easing.InOutSine }
        NumberAnimation { from: 0.18; to: 1; duration: 620; easing.type: Easing.InOutSine }
      }
    }
  }
}
