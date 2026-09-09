import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.ef-code.desktop-modes"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }
  function refresh() { if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh() }
  function applyProfile(profileId) { if (panelLoader.item) panelLoader.item.applyProfile(String(profileId || "")) }
  function requestRestore() { if (panelLoader.item) panelLoader.item.requestRestore() }
  function restore() { root.requestRestore() }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

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

  IpcHandler {
    target: root.moduleName
    function open() { root.open() }
    function close() { root.close() }
    function show() { root.open() }
    function hide() { root.close() }
    function toggle() { root.toggle() }
    function refresh() { root.broadcast("refresh") }
    function applyProfile(profileId: string) { root.applyProfile(profileId) }
    function restore() { root.broadcast("requestRestore") }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: panelLoader.item ? panelLoader.item.barGlyph : "󰌵"
    active: panelLoader.item ? panelLoader.item.barActive : false
    tooltipText: panelLoader.item ? panelLoader.item.barTooltip : "Desktop Modes"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.restore()
      else root.toggle()
    }
  }
}
