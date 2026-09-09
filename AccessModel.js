.pragma library

var settingLabels = {
  "gtk.animations.enabled": "GTK animations",
  "gtk.cursor.size": "GTK cursor size",
  "gtk.text.scale": "GTK text scale",
  "hypr.animations.enabled": "Hyprland animations",
  "hypr.blur.enabled": "Blur",
  "hypr.border_size": "Window border size",
  "hypr.cursor.zoom_factor": "Cursor zoom",
  "hypr.dim_inactive": "Inactive-window dimming",
  "hypr.dim_strength": "Inactive dim strength",
  "hypr.shadow.enabled": "Window shadows",
  "input.repeat_delay": "Keyboard repeat delay",
  "input.repeat_rate": "Keyboard repeat rate"
}

function parseResponse(raw) {
  try {
    var value = JSON.parse(String(raw || ""))
    return value && typeof value === "object" && !Array.isArray(value) ? value : { ok: false, error: "Invalid backend response" }
  } catch (error) {
    return { ok: false, error: "Invalid backend response" }
  }
}

function profilesFromResponse(raw) {
  var response = typeof raw === "string" ? parseResponse(raw) : raw
  if (!response || !Array.isArray(response.profiles)) return []
  return response.profiles.filter(function(profile) {
    return profile && typeof profile.id === "string" && typeof profile.name === "string"
      && profile.settings && typeof profile.settings === "object" && !Array.isArray(profile.settings)
  })
}

function profileById(profiles, profileId) {
  var list = Array.isArray(profiles) ? profiles : []
  for (var i = 0; i < list.length; i++) {
    if (list[i] && String(list[i].id) === String(profileId)) return list[i]
  }
  return null
}

function normalizedChanges(plan) {
  var changes = plan && Array.isArray(plan.changes) ? plan.changes.slice() : []
  changes.sort(function(a, b) {
    return String(a.label || a.id).localeCompare(String(b.label || b.id))
  })
  return changes
}

function formatValue(value) {
  if (value === null || value === undefined) return "Unavailable"
  if (typeof value === "boolean") return value ? "On" : "Off"
  if (typeof value === "number") {
    if (Math.abs(value - Math.round(value)) < 0.0001) return String(Math.round(value))
    return String(Math.round(value * 100) / 100)
  }
  return String(value)
}

function changeText(change) {
  if (!change) return ""
  if (change.status === "unsupported" || change.status === "unavailable" || change.status === "error")
    return statusText(change.status)
  return formatValue(change.from) + " → " + formatValue(change.to)
}

function profileGlyph(profile) {
  var icons = {
    "accessibility": "󰖸", "motion-off": "󰆴", presentation: "󰐪",
    focus: "󰋱", clarity: "󰍉", "low-stimulation": "󰒲"
  }
  return icons[String(profile && profile.icon || "")] || "󰌵"
}

function profileEffects(profile) {
  if (!profile || !profile.settings) return []
  var settings = profile.settings
  var effects = []
  if (settings["gtk.text.scale"] !== undefined) effects.push("Text " + Math.round(Number(settings["gtk.text.scale"]) * 100) + "%")
  if (settings["gtk.cursor.size"] !== undefined) effects.push("Cursor " + settings["gtk.cursor.size"] + "px")
  if (settings["hypr.animations.enabled"] === false) effects.push("Motion off")
  if (settings["hypr.blur.enabled"] === false) effects.push("Blur off")
  if (settings["hypr.dim_inactive"] === true) effects.push("Focus cue")
  if (settings["hypr.border_size"] !== undefined) effects.push("Border " + settings["hypr.border_size"] + "px")
  return effects.slice(0, 2)
}

function profileName(profiles, id) {
  var profile = profileById(profiles, id)
  return profile ? String(profile.name) : String(id || "Original")
}

function statusText(status) {
  switch (String(status || "")) {
  case "supported": return "Supported"
  case "ready": return "Will change"
  case "unchanged": return "Already set"
  case "unsupported": return "Unavailable here"
  case "unavailable": return "Dependency unavailable"
  case "restart-required": return "Restart required"
  case "error": return "Probe error"
  default: return "Unknown"
  }
}

function warningSummary(plan) {
  var warnings = plan && Array.isArray(plan.warnings) ? plan.warnings : []
  if (warnings.length === 0) return ""
  return warnings.length + (warnings.length === 1 ? " setting is" : " settings are") + " unavailable"
}

function formatCountdown(deadline, nowMs) {
  var clock = nowMs === undefined || nowMs === null ? Date.now() : Number(nowMs)
  var remaining = Math.max(0, Number(deadline || 0) - Math.floor(clock / 1000))
  var minutes = Math.floor(remaining / 60)
  var seconds = remaining % 60
  return minutes > 0
    ? minutes + ":" + (seconds < 10 ? "0" : "") + seconds
    : String(seconds) + "s"
}

function barState(status) {
  if (!status) return { key: "baseline", label: "Access: original settings", glyph: "󰌵", warning: false }
  if (status.preview) return { key: "preview", label: "Previewing " + status.preview.profileId, glyph: "󰌵", warning: false }
  if (status.conflicts && status.conflicts.length > 0)
    return { key: "drift", label: "A managed setting changed outside Access", glyph: "󰌵", warning: true }
  if (status.activeProfile)
    return { key: "active", label: "Access: " + status.activeProfile + " active", glyph: "󰌵", warning: false }
  return { key: "baseline", label: "Access: original settings", glyph: "󰌵", warning: false }
}

function hasActionableChanges(plan) {
  var changes = normalizedChanges(plan)
  for (var i = 0; i < changes.length; i++) {
    if (changes[i].status === "ready") return true
  }
  return false
}

function backendErrorMessage(error) {
  switch (String(error || "")) {
  case "external-drift": return "Some managed settings changed outside Access. Resolve each choice below."
  case "external-drift-pending": return "Resolve the pending external changes before applying another profile."
  case "external-drift-changed": return "That setting changed again. Review its latest value before choosing again."
  case "preview-active": return "Keep or revert the active preview before continuing."
  case "operation-id-reused": return "That operation ID was already used for a different request. Try again."
  default: return String(error || "Access backend failed")
  }
}

if (typeof module !== "undefined") {
  module.exports = {
    parseResponse: parseResponse,
    profilesFromResponse: profilesFromResponse,
    profileById: profileById,
    normalizedChanges: normalizedChanges,
    formatValue: formatValue,
    changeText: changeText,
    profileGlyph: profileGlyph,
    profileEffects: profileEffects,
    profileName: profileName,
    statusText: statusText,
    warningSummary: warningSummary,
    formatCountdown: formatCountdown,
    barState: barState,
    hasActionableChanges: hasActionableChanges,
    backendErrorMessage: backendErrorMessage
  }
}
