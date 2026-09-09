# Contributing

Keep changes narrow, reviewable, and safe to undo. The backend is the only
component allowed to mutate desktop settings; QML should request an explicit
operation and render the structured result.

Before opening a change:

```sh
omarchy plugin validate .
bash -n scripts/desktop-modesctl tests/run.sh
node tests/model.test.js
bash tests/run.sh
qmllint -I "${OMARCHY_PATH:-/usr/share/omarchy}/shell" \
  BarWidget.qml Panel.qml Service.qml components/*.qml
```

Use the repository’s final plugin ID in examples. Do not add arbitrary command
fields to profile JSON, direct edits under `/usr/share/omarchy/`, privileged
operations, network dependencies, or machine-specific absolute paths.

Real graphical validation is separate from static checks. Record the Omarchy
and Hyprland versions, whether one or two monitors were used, and any rows in
the manual matrix that remain unverified.
