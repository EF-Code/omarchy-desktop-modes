# Manual Omarchy validation matrix

Static checks and mock transactions do not prove real Wayland geometry or
focus. Run this matrix in a graphical Omarchy 4.x session after installing the
plugin from a clean checkout.

| Area | Check | Evidence |
| --- | --- | --- |
| Install | `omarchy plugin validate`, enable, place in right section | command output + screenshot |
| Panel | click, shell IPC summon/hide, Escape, click-away | short recording |
| Profiles | plan and preview all six built-in modes | captured JSON responses |
| Timers | close the panel during 30s, 5m, and 25m trials; confirm automatic return | response + shell log |
| Custom modes | duplicate, rename, apply, edit, and delete a custom mode | response + config readback |
| Preview | wait for timeout, Keep, Revert now, shell restart during preview | response + shell log |
| Restore | switch profiles, restore baseline, external drift conflict | response + before/after values |
| Keyboard | Tab, arrows, Enter, Space, P, A, R, Escape | keyboard-only checklist |
| Layout | narrow display, 125–150% text, vertical bar | screenshots |
| Monitors | one and two monitors, open on intended monitor | screenshot + notes |
| Dependencies | missing `gsettings` or schema | capability response |
| Removal | restore first, then remove plugin | exact terminal transcript |

Record unexecuted rows as unverified; do not infer live-session success from
static QML checks, SSH, or IPC alone.
