import QtQuick
import qs.Commons
import qs.Ui

CursorSurface {
  id: root

  property string label: ""
  property string tooltip: ""
  property color labelColor: Color.foreground
  property color accentColor: Color.accent
  property color urgentColor: Color.urgent
  property string fontFamily: Style.font.family
  property real fontPixelSize: Style.font.body
  property bool labelBold: false
  property bool urgent: false
  property bool actionable: true
  property bool highlighted: false

  signal activated()

  property bool pointerHot: false

  implicitWidth: labelItem.implicitWidth + Style.space(24)
  implicitHeight: labelItem.implicitHeight + Style.space(14)

  hasCursor: pointerHot && actionable
  foreground: labelColor
  accent: urgent ? urgentColor : accentColor
  current: urgent || highlighted
  bordered: true

  HoverHandler {
    enabled: root.actionable
    onHoveredChanged: root.pointerHot = hovered
  }

  Text {
    id: labelItem
    anchors.centerIn: parent
    text: root.label
    color: !root.actionable
      ? Qt.darker(root.labelColor, 2.0)
      : (root.urgent ? root.urgentColor : root.labelColor)
    font.family: root.fontFamily
    font.pixelSize: root.fontPixelSize
    font.bold: root.labelBold
  }

  MouseArea {
    anchors.fill: parent
    enabled: root.actionable
    hoverEnabled: true
    cursorShape: root.actionable ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: root.activated()
  }

  PanelToolTip {
    visible: root.tooltip !== "" && root.pointerHot
    text: root.tooltip
    fontFamily: root.fontFamily
  }
}
