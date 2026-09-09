import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "../DesktopModesModel.js" as Model

Rectangle {
  id: root

  property var conflict: ({})
  property color foreground: Color.foreground
  signal keepExternal()
  signal restoreBaseline()

  implicitHeight: content.implicitHeight + Style.space(20)
  radius: Style.cornerRadius
  color: Qt.alpha(Color.urgent, 0.1)
  border.width: 1
  border.color: Color.urgent

  ColumnLayout {
    id: content
    anchors.fill: parent
    anchors.margins: Style.space(10)
    spacing: Style.space(7)

    Text {
      Layout.fillWidth: true
      text: String(root.conflict.label || root.conflict.id || "Setting")
      color: root.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      font.bold: true
      wrapMode: Text.WordWrap
    }

    Text {
      Layout.fillWidth: true
      text: "External value: " + Model.formatValue(root.conflict.current)
        + "  •  Original value: " + Model.formatValue(root.conflict.baseline)
      color: Qt.alpha(root.foreground, 0.78)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(8)

      Button {
        Layout.fillWidth: true
        text: "Keep external"
        enabled: root.enabled
        focusable: true
        onClicked: root.keepExternal()
      }

      Button {
        Layout.fillWidth: true
        text: "Restore original"
        enabled: root.enabled
        focusable: true
        onClicked: root.restoreBaseline()
      }
    }
  }
}
