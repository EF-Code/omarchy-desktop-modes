import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var shell: null
  property string pendingAction: ""
  property string activeProfile: ""
  property string backendOutput: ""
  property string backendError: ""
  property bool startupPhase: true
  property int previewDeadline: 0
  readonly property string backendPath: decodeURIComponent(String(Qt.resolvedUrl("scripts/accessctl")).replace(/^file:\/\//, ""))

  function operationId() {
    var hex = ""
    for (var i = 0; i < 32; i++) hex += Math.floor(Math.random() * 16).toString(16)
    return hex.slice(0, 8) + "-" + hex.slice(8, 12) + "-4" + hex.slice(13, 16) + "-8" + hex.slice(17, 20) + "-" + hex.slice(20)
  }

  function run(args, action) {
    if (backendProcess.running) return
    pendingAction = action
    backendProcess.command = ["bash", backendPath].concat(args)
    backendProcess.running = true
  }

  function startup() { run(["recover"], "recover") }

  function handle(action, raw, exitCode) {
    var response = {}
    try { response = JSON.parse(String(raw || "{}")) } catch (error) { response = { ok: false } }
    if (exitCode !== 0 || response.ok !== true) return
    if (action === "recover") {
      run(["status"], "status")
      return
    }
    if (action === "status") {
      activeProfile = String(response.activeProfile || "")
      previewDeadline = response.preview ? Number(response.preview.deadline || 0) : 0
      if (startupPhase) {
        startupPhase = false
        var conflicts = Array.isArray(response.conflicts) ? response.conflicts : []
        if (activeProfile !== "" && !response.preview && conflicts.length === 0)
          run(["apply", activeProfile, "--operation-id", operationId()], "reapply")
      }
    }
  }

  Process {
    id: backendProcess
    stdout: StdioCollector { id: backendStdout; waitForEnd: true }
    stderr: StdioCollector { id: backendStderr; waitForEnd: true }
    onExited: function(exitCode) {
      root.backendOutput = String(backendStdout.text || "")
      root.backendError = String(backendStderr.text || "")
      root.handle(root.pendingAction, root.backendOutput, exitCode)
    }
  }

  Timer {
    interval: 10000
    repeat: true
    running: root.activeProfile !== "" || root.previewDeadline > 0
    onTriggered: root.run(["status"], "status")
  }

  IpcHandler {
    target: "io.github.ef-code.access-profiles.service"
    function recover() { root.run(["recover"], "recover") }
    function refresh() { root.run(["status"], "status") }
  }

  Component.onCompleted: Qt.callLater(root.startup)
}
