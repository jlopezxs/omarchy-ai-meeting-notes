import QtQuick
import QtQuick.Controls
import qs.Commons
import "Model.js" as Model

Flickable {
  id: root

  property string markdown: ""
  property string emptyText: "Nothing here yet."
  property color foreground: Color.foreground
  property color accent: Color.accent
  property color dim: Qt.darker(foreground, 1.55)
  property string fontFamily: Style.font.family

  readonly property string displayText: root.empty
    ? root.emptyText
    : Model.markdownToPreviewHtml(markdown, Style.font.body, Style.font.bodySmall)
  readonly property bool empty: String(markdown || "").trim() === ""

  clip: true
  boundsBehavior: Flickable.StopAtBounds
  contentWidth: width
  contentHeight: Math.max(height, body.contentHeight)
  implicitHeight: body.contentHeight
  ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

  TextEdit {
    id: body
    width: root.width
    height: Math.max(root.height, contentHeight)
    readOnly: true
    selectByMouse: true
    wrapMode: TextEdit.Wrap
    textFormat: root.empty ? TextEdit.PlainText : TextEdit.RichText
    text: root.displayText
    color: root.empty ? root.dim : root.foreground
    selectedTextColor: root.foreground
    selectionColor: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.35)
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    activeFocusOnPress: true
    cursorVisible: false
  }
}
