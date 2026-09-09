# Desktop Modes repository rules

## Scope

This repository contains an Omarchy Quickshell plugin. Keep the normal plugin
path local-first, unprivileged, offline, and reversible. The helper may change
only the allowlisted desktop settings declared in `profiles/defaults.json`.

## Safety rules

- Never add `sudo`, `pkexec`, install hooks, network calls, telemetry, or
  arbitrary shell execution.
- Keep mutable state under XDG directories, outside this checkout.
- Treat profile IDs, setting IDs, and values as untrusted input.
- Preserve and review external drift before restoring a baseline.
- Do not edit `/usr/share/omarchy/`; it is only a runtime reference.
- Do not commit build guides, credentials, private state, or machine-specific
  absolute paths.

## Validation

```sh
omarchy plugin validate .
qmllint -I "${OMARCHY_PATH:-/usr/share/omarchy}/shell" \
  BarWidget.qml Panel.qml Service.qml components/*.qml
bash tests/run.sh
node tests/model.test.js
bash tests/repository-check.sh
```

If Python is introduced for tests or tooling, invoke `/home/hiro/.venv/bin/python`
on the development machine. Do not put that developer-specific path in the
plugin itself.
