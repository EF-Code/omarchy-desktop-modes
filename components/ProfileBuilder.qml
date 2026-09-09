import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Rectangle {
  id: root

  property var baseProfile: ({ settings: {} })
  property color foreground: Color.foreground
  signal saveRequested(string payload)
  signal cancelled()

  function slug(value) {
    return String(value || "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 64)
  }

  function reset(profile) {
    baseProfile = profile || { settings: {} }
    nameField.text = String(baseProfile.name || "") + (baseProfile.source === "custom" ? "" : " Copy")
    descriptionField.text = String(baseProfile.description || "")
  }

  implicitHeight: content.implicitHeight + Style.space(24)
  radius: Style.cornerRadius
  color: Qt.alpha(root.foreground, 0.055)
  border.width: 1
  border.color: Qt.alpha(root.foreground, 0.24)

  ColumnLayout {
    id: content
    anchors.fill: parent
    anchors.margins: Style.space(12)
    spacing: Style.space(8)

    Text {
      text: root.baseProfile.source === "custom" ? "Edit custom mode" : "Make this mode yours"
      color: root.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.subtitle
      font.bold: true
    }
    Text {
      Layout.fillWidth: true
      text: "Start with these safe, allowlisted settings. You can fine-tune the JSON later."
      color: Qt.alpha(root.foreground, 0.7)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }
    TextField {
      id: nameField
      Layout.fillWidth: true
      placeholderText: "Mode name"
      maximumLength: 80
    }
    TextField {
      id: descriptionField
      Layout.fillWidth: true
      placeholderText: "What this mode helps with"
      maximumLength: 240
    }
    RowLayout {
      Layout.fillWidth: true
      Button { text: "Cancel"; focusable: true; onClicked: root.cancelled() }
      Button {
        Layout.fillWidth: true
        text: "Save custom mode"
        focusable: true
        enabled: root.slug(nameField.text).length > 0
        onClicked: {
          var existing = root.baseProfile.source === "custom" ? String(root.baseProfile.id) : ""
          var id = existing || root.slug(nameField.text)
          root.saveRequested(JSON.stringify({
            id: id,
            name: String(nameField.text),
            description: String(descriptionField.text),
            icon: String(root.baseProfile.icon || "accessibility"),
            settings: root.baseProfile.settings || {}
          }))
        }
      }
    }
  }
}
