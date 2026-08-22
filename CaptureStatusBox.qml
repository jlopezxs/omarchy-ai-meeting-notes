import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Rectangle {
  id: root

  property string iconText: ""
  property string title: ""
  property string headline: ""
  property bool showDot: false
  property string detail: ""
  property string footer: ""
  property real progress: -1
  property color foreground: Color.foreground
  property color accent: Color.accent
  property color dim: Qt.darker(foreground, 1.55)
  property string fontFamily: Style.font.family

  radius: Style.cornerRadius
  color: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.04)
  border.color: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.12)
  implicitHeight: body.implicitHeight + Style.spacing.panelPadding * 2
  implicitWidth: Style.space(160)
  clip: true

  ColumnLayout {
    id: body
    anchors.fill: parent
    anchors.margins: Style.spacing.panelPadding
    spacing: Style.space(8)

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(8)

      OpticalGlyph {
        Layout.preferredWidth: Style.space(16)
        Layout.preferredHeight: Style.space(16)
        text: root.iconText
        fontFamily: root.fontFamily
        fontSize: Style.font.bodySmall
        color: root.accent
      }

      Text {
        Layout.fillWidth: true
        text: root.title
        color: root.accent
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 0.8
        elide: Text.ElideRight
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(8)

      Text {
        text: root.headline
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }

      Rectangle {
        visible: root.showDot
        Layout.preferredWidth: Style.space(8)
        Layout.preferredHeight: Style.space(8)
        radius: width / 2
        color: root.accent
        opacity: pulse.lit ? 1 : 0.35
      }

      Item { Layout.fillWidth: true }
    }

    Text {
      Layout.fillWidth: true
      visible: root.detail !== ""
      text: root.detail
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.WordWrap
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: Style.space(4)
      visible: root.progress >= 0
      radius: Style.space(2)
      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.14)

      Rectangle {
        width: Math.max(Style.space(4), parent.width * Math.max(0, Math.min(1, root.progress)))
        height: parent.height
        radius: parent.radius
        color: root.accent
      }
    }

    Text {
      Layout.fillWidth: true
      visible: root.footer !== ""
      text: root.footer
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }
  }

  Timer {
    id: pulse
    property bool lit: true
    interval: 700
    running: root.visible && root.showDot
    repeat: true
    onTriggered: lit = !lit
  }
}
