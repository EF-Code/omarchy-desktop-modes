const assert = require("node:assert/strict")
const fs = require("node:fs")
const vm = require("node:vm")
const path = require("node:path")
const source = fs.readFileSync(path.join(__dirname, "..", "AccessModel.js"), "utf8").replace(/^\.pragma library\s*/m, "")
const sandbox = { module: { exports: {} }, exports: {}, Date }
vm.runInNewContext(source, sandbox, { filename: "AccessModel.js" })
const model = sandbox.module.exports

const profiles = [
  { id: "comfortable", name: "Comfortable", settings: {} },
  { id: "focus", name: "Focus", settings: {} }
]

assert.equal(model.profileById(profiles, "focus").name, "Focus")
assert.equal(model.profileById(profiles, "missing"), null)
assert.equal(model.formatValue(false), "Off")
assert.equal(model.formatValue(1.25), "1.25")
assert.equal(model.formatValue(36), "36")
assert.equal(model.formatValue(null), "Unavailable")

const plan = {
  changes: [
    { id: "b", label: "Zed", status: "ready", from: true, to: false },
    { id: "a", label: "Alpha", status: "unchanged", from: 1, to: 1 }
  ],
  warnings: [{ id: "x" }]
}
assert.deepEqual(model.normalizedChanges(plan).map((item) => item.id), ["a", "b"])
assert.equal(model.warningSummary(plan), "1 setting is unavailable")
assert.equal(model.changeText(plan.changes[0]), "On → Off")
assert.equal(model.profileGlyph({ icon: "focus" }), "󰋱")
assert.deepEqual(Array.from(model.profileEffects({ settings: { "gtk.text.scale": 1.25, "hypr.animations.enabled": false } })), ["Text 125%", "Motion off"])
assert.equal(model.profileName(profiles, "focus"), "Focus")
assert.equal(model.statusText("restart-required"), "Restart required")
assert.equal(model.formatCountdown(130, 100000), "30s")
assert.equal(model.formatCountdown(130, 0), "2:10")
assert.equal(model.formatCountdown(1788960717, 1788960417000), "5:00")
assert.equal(model.hasActionableChanges(plan), true)
assert.equal(model.barState({ activeProfile: "focus", preview: null, conflicts: [] }).key, "active")
assert.equal(model.barState({ activeProfile: null, preview: null, conflicts: [{ id: "x" }] }).warning, true)
assert.equal(model.parseResponse("[]").ok, false)
assert.equal(model.profilesFromResponse({ profiles: [{ id: "bad", name: "Bad", settings: [] }] }).length, 0)
assert.equal(model.backendErrorMessage("preview-active"), "Keep or revert the active preview before continuing.")

console.log("model tests passed")
