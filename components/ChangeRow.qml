import QtQuick
import QtQuick.Layouts
import qs.Commons
import "../DesktopModesModel.js" as ModelText

Item {
  id: root

  property var change: ({})
  property color foreground: Color.foreground

  implicitHeight: row.implicitHeight + Style.space(10)

  RowLayout {
    id: row
    anchors.fill: parent
    spacing: Style.space(10)

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.space(2)

      Text {
        Layout.fillWidth: true
        text: String(root.change.label || root.change.id || "Setting")
        color: root.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      Text {
        Layout.fillWidth: true
        text: String(root.change.scope || "")
        color: Qt.alpha(root.foreground, 0.68)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }

    Text {
      Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
      text: ModelText.changeText(root.change)
      color: root.change.status === "unsupported" || root.change.status === "unavailable" || root.change.status === "error"
        ? Color.urgent : root.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      horizontalAlignment: Text.AlignRight
      wrapMode: Text.WordWrap
    }
  }

}
