# Changelog

## 1.1.0

- Renamed the public plugin from Access Profiles to Desktop Modes and added Large & Clear
  and Low Stimulation presets.
- Redesigned profile cards with icons, effect summaries, active-state labels,
  clearer actions, and less repetitive change rows.
- Added safe custom-mode duplication, editing, and deletion under XDG config.
- Added 30-second, 5-minute, and 25-minute timed sessions. The background
  service now monitors preview deadlines even while the panel is closed.
- Added a repository-root marketplace preview and expanded usage recipes.

## 1.0.1

- Hardened write-ahead recovery so incomplete operations roll back only
  journaled settings and committed operations survive stale journals.
- Preserved external changes across baseline restores, conflict resolution,
  preview cancellation, and preview timeout recovery.
- Blocked overlapping preview/conflict mutations and added conflict choices to
  the panel.
- Prevented multi-monitor IPC from applying one profile more than once.
- Added strict persisted-state, journal, profile, path, and adapter validation.

## 1.0.0

- Initial local-first Access Profiles plugin for Omarchy 4.x.
- Added four reversible profiles, a transactional backend, preview recovery,
  external-drift detection, and an anchored bar panel.
