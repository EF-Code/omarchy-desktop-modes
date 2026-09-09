import QtQuick
import QtQuick.Layouts
import qs.Commons
import "../AccessModel.js" as Model

Rectangle {
  id: root

  property var profile: ({})
  property bool selected: false
  property bool active: false
  property color foreground: Color.foreground
  signal clicked()

  implicitWidth: Style.space(180)
  implicitHeight: Style.space(112)
  clip: true
  radius: Style.cornerRadius
  color: selected ? Qt.alpha(Color.accent, 0.18) : Qt.alpha(foreground, 0.05)
  border.width: selected ? 2 : 1
  border.color: selected ? Color.accent : Qt.alpha(foreground, 0.22)

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.space(10)
    spacing: Style.space(3)

    RowLayout {
      Layout.fillWidth: true
      Text {
        text: Model.profileGlyph(root.profile)
        color: root.selected ? Color.accent : root.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.subtitle
      }
      Text {
        Layout.fillWidth: true
        text: String(root.profile.name || "Profile")
        color: root.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
        elide: Text.ElideRight
      }
      Text {
        visible: root.active
        text: "ACTIVE"
        color: Color.accent
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
      }
    }

    Text {
      Layout.fillWidth: true
      text: String(root.profile.description || "")
      color: Qt.alpha(root.foreground, 0.7)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
      maximumLineCount: 2
      elide: Text.ElideRight
    }

    Flow {
      Layout.fillWidth: true
      spacing: Style.space(4)
      Repeater {
        model: Model.profileEffects(root.profile)
        Rectangle {
          required property string modelData
          implicitWidth: chipText.implicitWidth + Style.space(10)
          implicitHeight: chipText.implicitHeight + Style.space(5)
          radius: height / 2
          color: Qt.alpha(root.foreground, 0.08)
          Text {
            id: chipText
            anchors.centerIn: parent
            text: modelData
            color: Qt.alpha(root.foreground, 0.76)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
