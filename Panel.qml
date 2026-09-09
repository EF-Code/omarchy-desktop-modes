import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "AccessModel.js" as Model
import "components"

Panel {
  id: root
  moduleName: "io.github.ef-code.access-profiles"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var profiles: []
  property int selectedIndex: 0
  property var selectedPlan: null
  property var backendStatus: ({ activeProfile: null, preview: null, conflicts: [] })
  property string statusMessage: ""
  property bool statusWarning: false
  property bool loading: false
  property bool confirmRestore: false
  property double nowMs: Date.now()
  property string pendingAction: ""
  property string lastOperationId: ""
  property string queuedProfileId: ""
  property bool editingProfile: false
  property int previewSeconds: 30
  readonly property string backendPath: decodeURIComponent(String(Qt.resolvedUrl("scripts/accessctl")).replace(/^file:\/\//, ""))
  readonly property var selectedProfile: profiles.length > 0 && selectedIndex >= 0 && selectedIndex < profiles.length ? profiles[selectedIndex] : null
  readonly property bool hasActionablePlan: Model.hasActionableChanges(selectedPlan)
  readonly property bool hasBaseline: backendStatus.baselineCaptured === true
  readonly property bool hasPendingConflicts: backendStatus.conflicts && backendStatus.conflicts.length > 0
  readonly property string barGlyph: "󰌵"
  readonly property bool barActive: !!backendStatus.activeProfile || !!backendStatus.preview || hasPendingConflicts
  readonly property string barTooltip: Model.barState(backendStatus).label

  function operationId() {
    var parts = []
    for (var i = 0; i < 32; i++) parts.push(Math.floor(Math.random() * 16).toString(16))
    return parts.slice(0, 8).join("") + "-" + parts.slice(8, 12).join("") + "-4" + parts.slice(13, 16).join("") + "-8" + parts.slice(17, 20).join("") + "-" + parts.slice(20).join("")
  }

  function runBackend(args, action) {
    if (backendProcess.running) return
    pendingAction = action
    loading = true
    backendProcess.command = ["bash", backendPath].concat(args)
    backendProcess.running = true
  }

  function load() { runBackend(["recover"], "recover") }
  function refresh() {
    if (profiles.length === 0) load()
    else runBackend(["status"], "status")
  }

  function loadProfiles() { runBackend(["list-profiles"], "profiles") }

  function selectProfile(index) {
    if (index < 0 || index >= profiles.length) return
    selectedIndex = index
    selectedPlan = null
    if (selectedProfile) runBackend(["plan", String(selectedProfile.id)], "plan")
  }

  function selectProfileById(profileId) {
    for (var i = 0; i < profiles.length; i++) {
      if (String(profiles[i].id) === String(profileId || "")) {
        selectedIndex = i
        return
      }
    }
  }

  function applyProfile(profileId) {
    var requested = String(profileId || "")
    if (profiles.length === 0) {
      queuedProfileId = requested
      load()
      return
    }
    if (loading || backendStatus.preview || hasPendingConflicts) {
      statusMessage = backendStatus.preview ? "Keep or revert the active preview before continuing."
        : (hasPendingConflicts ? "Resolve the pending external changes before applying another profile." : "Access is busy. Try again in a moment.")
      statusWarning = true
      return
    }
    for (var i = 0; i < profiles.length; i++) {
      if (String(profiles[i].id) !== requested) continue
      selectedIndex = i
      selectedPlan = null
      var id = operationId()
      lastOperationId = id
      runBackend(["apply", requested, "--operation-id", id], "apply")
      return
    }
    statusMessage = "Unknown profile"
    statusWarning = true
  }

  function planSelected() {
    if (selectedProfile) runBackend(["plan", String(selectedProfile.id)], "plan")
  }

  function editSelectedProfile() {
    if (!selectedProfile || loading) return
    editingProfile = true
    profileBuilder.reset(selectedProfile)
  }

  function saveCustomProfile(payload) { runBackend(["save-profile", payload], "save-profile") }

  function deleteSelectedProfile() {
    if (!selectedProfile || selectedProfile.source !== "custom" || loading) return
    runBackend(["delete-profile", String(selectedProfile.id)], "delete-profile")
  }

  function previewSelected() {
    if (!selectedProfile || !hasActionablePlan || loading || backendStatus.preview || hasPendingConflicts) return
    var id = operationId()
    lastOperationId = id
    runBackend(["preview", String(selectedProfile.id), "--seconds", String(previewSeconds), "--operation-id", id], "preview")
  }

  function applySelected() {
    if (!selectedProfile || !hasActionablePlan || loading || backendStatus.preview || hasPendingConflicts) return
    var id = operationId()
    lastOperationId = id
    runBackend(["apply", String(selectedProfile.id), "--operation-id", id], "apply")
  }

  function keepPreview() {
    if (!backendStatus.preview) return
    var id = String(backendStatus.preview.operationId || lastOperationId)
    runBackend(["keep-preview", "--operation-id", id], "keep-preview")
  }

  function cancelPreview() {
    if (!backendStatus.preview) return
    var id = String(backendStatus.preview.operationId || lastOperationId)
    runBackend(["cancel-preview", "--operation-id", id], "cancel-preview")
  }

  function requestRestore() {
    if (!opened) root.open()
    if (!hasBaseline) {
      statusMessage = "No Access baseline has been captured yet."
      statusWarning = false
      return
    }
    if (backendStatus.preview) {
      statusMessage = "Keep or revert the active preview before restoring."
      statusWarning = true
      return
    }
    if (hasPendingConflicts) {
      statusMessage = "Resolve each pending external change below."
      statusWarning = true
      return
    }
    confirmRestore = true
  }

  function restoreNow() {
    confirmRestore = false
    var id = operationId()
    lastOperationId = id
    runBackend(["restore", "--operation-id", id], "restore")
  }

  function resolveConflict(settingId, keepExternal) {
    if (loading || !hasPendingConflicts) return
    runBackend(["resolve-conflict", String(settingId), keepExternal ? "--keep-external" : "--restore-baseline"], "resolve-conflict")
  }

  function handleResponse(action, response, exitCode) {
    loading = false
    if (!response || response.ok !== true) {
      statusMessage = Model.backendErrorMessage(response && response.error ? response.error : "Access backend failed")
      statusWarning = true
      if (response && response.details && Array.isArray(response.details.conflicts))
        backendStatus.conflicts = response.details.conflicts
      if (action === "restore" || action === "resolve-conflict") refresh()
      return
    }

    statusWarning = false
    if (action === "profiles") {
      profiles = Model.profilesFromResponse(response)
      if (selectedIndex >= profiles.length) selectedIndex = Math.max(0, profiles.length - 1)
      if (queuedProfileId !== "") {
        var requestedProfile = queuedProfileId
        queuedProfileId = ""
        Qt.callLater(function() { root.applyProfile(requestedProfile) })
      } else planSelected()
      return
    }
    if (action === "status") {
      backendStatus = response
      nowMs = Date.now()
      if (backendStatus.preview) selectProfileById(backendStatus.preview.profileId)
      else if (backendStatus.activeProfile) selectProfileById(backendStatus.activeProfile)
      if (selectedProfile) planSelected()
      return
    }
    if (action === "plan") {
      if (selectedProfile && String(response.profileId || "") === String(selectedProfile.id)) selectedPlan = response
      else planSelected()
      return
    }
    if (action === "recover") {
      loadProfiles()
      return
    }
    if (action === "save-profile" || action === "delete-profile") {
      editingProfile = false
      statusMessage = action === "save-profile" ? "Custom mode saved." : "Custom mode deleted."
      loadProfiles()
      return
    }

    statusMessage = response.preservedExternal && response.preservedExternal.length > 0
      ? "Preview closed; changes made by another tool were preserved."
      : (action === "preview" ? "Preview active — keep it or revert now."
        : (action === "resolve-conflict" ? "External change resolved." : "Access settings updated."))
    if (hostWidget && typeof hostWidget.broadcast === "function")
      Qt.callLater(function() { hostWidget.broadcast("refresh") })
    else refresh()
  }

  onOpenedChanged: {
    if (opened) {
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
      refresh()
    } else {
      confirmRestore = false
      editingProfile = false
    }
  }

  Process {
    id: backendProcess
    stdout: StdioCollector { id: backendStdout; waitForEnd: true }
    stderr: StdioCollector { id: backendStderr; waitForEnd: true }
    onExited: function(exitCode) {
      var output = String(backendStdout.text || "").trim()
      var response = Model.parseResponse(output)
      if (exitCode !== 0 && response.ok === true) response = { ok: false, error: String(backendStderr.text || "Backend failed") }
      root.handleResponse(root.pendingAction, response, exitCode)
    }
  }

  Timer {
    id: previewTimer
    interval: 1000
    repeat: true
    running: !!root.backendStatus.preview
    onTriggered: {
      root.nowMs = Date.now()
      if (root.backendStatus.preview && Number(root.backendStatus.preview.deadline || 0) <= Math.floor(root.nowMs / 1000))
        root.refresh()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(contentFlick.contentHeight, Style.space(720))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (dx !== 0 || dy !== 0) {
          var next = root.selectedIndex + (dx > 0 || dy > 0 ? 1 : -1)
          if (next < 0) next = root.profiles.length - 1
          if (next >= root.profiles.length) next = 0
          root.selectProfile(next)
        }
      }
      onActivateRequested: root.applySelected()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(key) {
        if (key === "p" || key === "P") root.previewSelected()
        else if (key === "a" || key === "A") root.applySelected()
        else if (key === "r" || key === "R") root.requestRestore()
      }

      Flickable {
        id: contentFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
          id: contentColumn
          width: contentFlick.width
          spacing: Style.space(10)

          RowLayout {
            Layout.fillWidth: true
            Text {
              Layout.fillWidth: true
              text: "DESKTOP MODES"
              color: root.barForeground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
            }
            Text {
              text: root.backendStatus.preview ? "PREVIEWING" : (root.backendStatus.activeProfile ? "ACTIVE" : "ORIGINAL")
              color: root.backendStatus.conflicts && root.backendStatus.conflicts.length > 0 ? Color.urgent : root.barForeground
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }

          Text {
            Layout.fillWidth: true
            text: "Switch how Omarchy feels. Try every change before you keep it."
            color: Qt.alpha(root.barForeground, 0.78)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          StatusBanner {
            Layout.fillWidth: true
            message: root.statusMessage || (root.backendStatus.preview ? "Previewing " + root.backendStatus.preview.profileId + " — " + Model.formatCountdown(root.backendStatus.preview.deadline, root.nowMs) + " remaining."
              : (root.hasPendingConflicts ? "Some managed settings changed outside Access. Choose what to keep for each setting." : ""))
            warning: root.statusWarning || root.hasPendingConflicts
            foreground: root.barForeground
          }

          Flow {
            Layout.fillWidth: true
            spacing: Style.space(8)
            Repeater {
              model: root.profiles
              ProfileCard {
                required property var modelData
                required property int index
                profile: modelData
                selected: index === root.selectedIndex
                active: String(root.backendStatus.activeProfile || "") === String(modelData.id)
                foreground: root.barForeground
                onClicked: root.selectProfile(index)
              }
            }
          }

          Text {
            Layout.fillWidth: true
            text: root.selectedProfile ? String(root.selectedProfile.name || "Profile") : "Choose a profile"
            color: root.barForeground
            font.family: Style.font.family
            font.pixelSize: Style.font.subtitle
            font.bold: true
          }

          Text {
            Layout.fillWidth: true
            visible: root.selectedProfile && root.selectedProfile.source === "custom"
            text: "CUSTOM MODE"
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          Text {
            Layout.fillWidth: true
            text: root.selectedProfile ? String(root.selectedProfile.description || "") : "Profiles affect only listed settings."
            color: Qt.alpha(root.barForeground, 0.75)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)
            visible: !root.backendStatus.preview
            Text {
              text: "TRY FOR"
              color: Qt.alpha(root.barForeground, 0.58)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
            }
            Button { text: "30s"; selected: root.previewSeconds === 30; focusable: true; onClicked: root.previewSeconds = 30 }
            Button { text: "5m"; selected: root.previewSeconds === 300; focusable: true; onClicked: root.previewSeconds = 300 }
            Button { text: "25m focus"; selected: root.previewSeconds === 1500; focusable: true; onClicked: root.previewSeconds = 1500 }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)
            Button {
              Layout.fillWidth: true
              text: root.previewSeconds === 30 ? "Try for 30 seconds" : (root.previewSeconds === 300 ? "Try for 5 minutes" : "Start 25-minute session")
              enabled: root.hasActionablePlan && !root.loading && !root.backendStatus.preview && !root.hasPendingConflicts
              focusable: true
              onClicked: root.previewSelected()
            }
            Button {
              Layout.fillWidth: true
              text: "Use this mode"
              enabled: root.hasActionablePlan && !root.loading && !root.backendStatus.preview && !root.hasPendingConflicts
              focusable: true
              onClicked: root.applySelected()
            }
          }

          RowLayout {
            Layout.fillWidth: true
            visible: !!root.backendStatus.preview
            Button { Layout.fillWidth: true; text: "Keep"; enabled: !root.loading; focusable: true; onClicked: root.keepPreview() }
            Button { Layout.fillWidth: true; text: "Revert now"; enabled: !root.loading; focusable: true; onClicked: root.cancelPreview() }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(2)
            Repeater {
              model: Model.normalizedChanges(root.selectedPlan)
              ChangeRow {
                required property var modelData
                change: modelData
                Layout.fillWidth: true
                foreground: root.barForeground
              }
            }
          }

          Button {
            Layout.fillWidth: true
            text: root.selectedProfile && root.selectedProfile.source === "custom" ? "Edit this mode" : "Make this mode yours"
            iconText: "󰏫"
            enabled: !!root.selectedProfile && !root.loading && !root.backendStatus.preview
            focusable: true
            onClicked: root.editSelectedProfile()
          }

          ProfileBuilder {
            id: profileBuilder
            Layout.fillWidth: true
            visible: root.editingProfile
            foreground: root.barForeground
            onSaveRequested: function(payload) { root.saveCustomProfile(payload) }
            onCancelled: root.editingProfile = false
          }

          Button {
            Layout.fillWidth: true
            visible: root.selectedProfile && root.selectedProfile.source === "custom"
            text: "Delete custom mode"
            enabled: !root.loading && String(root.backendStatus.activeProfile || "") !== String(root.selectedProfile ? root.selectedProfile.id : "")
            focusable: true
            onClicked: root.deleteSelectedProfile()
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)
            visible: root.hasPendingConflicts

            Repeater {
              model: root.backendStatus.conflicts || []
              ConflictRow {
                required property var modelData
                conflict: modelData
                foreground: root.barForeground
                enabled: !root.loading
                Layout.fillWidth: true
                onKeepExternal: root.resolveConflict(String(modelData.id), true)
                onRestoreBaseline: root.resolveConflict(String(modelData.id), false)
              }
            }
          }

          Button {
            Layout.fillWidth: true
            text: "Return to Original"
            enabled: root.hasBaseline && !root.loading && !root.backendStatus.preview && !root.hasPendingConflicts
            focusable: true
            onClicked: root.requestRestore()
          }

          Text {
            Layout.fillWidth: true
            text: "GTK changes affect applications that honor the schema. Monitor scaling and screen-reader support are not managed here."
            color: Qt.alpha(root.barForeground, 0.58)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          ConfirmSheet {
            Layout.fillWidth: true
            visible: root.confirmRestore
            title: "Restore original settings?"
            message: "Access will restore its captured baseline and stop managing the active profile. External changes will be shown as conflicts first."
            foreground: root.barForeground
            onAccepted: root.restoreNow()
            onRejected: root.confirmRestore = false
          }
        }
      }
    }
  }
}
