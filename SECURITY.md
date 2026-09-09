# Security model

Desktop Modes runs inside the long-lived `omarchy-shell` process. Omarchy
plugins are unsandboxed code, so users should inspect this repository before
enabling it.

The plugin invokes `scripts/accessctl` with the user’s existing permissions. It
does not use `sudo`, `pkexec`, an install hook, a network service, telemetry,
or an account. The helper accepts only profile IDs, registered setting IDs,
and bounded typed values. It never evaluates profile data as shell code and
passes adapter values as argument-array elements.

State is stored under XDG config/state/runtime directories outside the
checkout. Absolute paths, symlink components, and state-file symlinks are
rejected. Mutations use a short exclusive lock, an atomic pending journal,
read-back verification, reverse-order rollback, and a bounded local history.
The journal remains until the matching state transition is durable, and crash
recovery touches only entries recorded as possibly applied. Restore compares
the live value with the last value Access verified; external drift becomes an
explicit conflict and is rechecked before Access overwrites it.

Diagnostics are privacy-safe by construction: they contain plugin/runtime
capability results and profile IDs, not usernames, home paths, window titles,
command history, cookies, tokens, or application content.

Report suspected security issues privately through the repository’s GitHub
security channel. Do not include private state files or credential-bearing
URLs in a public issue.
