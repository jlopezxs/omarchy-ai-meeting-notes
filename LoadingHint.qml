import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Item {
  id: root

  property string iconText: "󰎤"
  property string title: "Generating summary"
  property string caption: ""
  property color foreground: Color.foreground
  property color accent: Color.accent
  property string fontFamily: Style.font.family

  readonly property color dim: Qt.darker(foreground, 1.55)

  ColumnLayout {
    id: body
    anchors.centerIn: parent
    width: Math.min(parent.width - Style.spacing.panelPadding * 2, Style.space(280))
    spacing: Style.space(12)

    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: Style.space(40)
      Layout.alignment: Qt.AlignHCenter

      OpticalGlyph {
        id: hintIcon
        anchors.centerIn: parent
        width: Style.space(36)
        height: Style.space(36)
        text: root.iconText
        fontFamily: root.fontFamily
        fontSize: Style.font.iconLarge
        color: root.accent
        opacity: pulse.lit ? 1 : 0.4
      }
    }

    Text {
      Layout.fillWidth: true
      text: root.title
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
      horizontalAlignment: Text.AlignHCenter
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(6)

      Repeater {
        model: 3
        delegate: Rectangle {
          required property int index
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(4)
          radius: Style.space(2)
          color: pulse.bar === index
            ? root.accent
            : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)
        }
      }
    }

    Text {
      Layout.fillWidth: true
      visible: root.caption !== ""
      text: root.caption
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.WordWrap
      horizontalAlignment: Text.AlignHCenter
    }
  }

  Timer {
    id: pulse
    property bool lit: true
    property int bar: 0
    interval: 280
    running: root.visible
    repeat: true
    onTriggered: {
      bar = (bar + 1) % 3
      if (bar === 0) lit = !lit
    }
  }
}
