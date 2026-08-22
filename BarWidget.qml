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
  readonly property string recordingIcon: "󰻃"

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

  function toggleRecording() {
    if (service) service.toggleRecording()
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
    text: root.vertical ? "" : (root.recording ? root.recordingIcon : root.icon)
    labelVisible: !root.vertical
    hasVisualContent: true
    dimmed: !root.service
    active: root.recording
    tooltipText: root.detached
      ? "Meeting notepad is floating — click to focus"
      : Model.barTooltip(root.state)

    onPressed: function(b) {
      if (b === Qt.MiddleButton) root.toggleRecording()
      else root.togglePanel()
    }

    Column {
      visible: root.vertical
      anchors.fill: parent

      OpticalGlyph {
        width: button.width
        height: Style.bar.iconSlot
        text: root.recording ? root.recordingIcon : root.icon
        fontFamily: button.fontFamily
        fontSize: button.fontSize
        color: root.recording ? (root.bar ? root.bar.urgent : Color.urgent) : button.foreground
      }
    }
  }
}
