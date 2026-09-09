#!/usr/bin/env bash
set -u
set -o pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd -P)
FIXTURE="$SCRIPT_DIR/fixtures/mock-values.json"
PASS=0
FAIL=0

record_pass() { PASS=$((PASS + 1)); printf 'ok - %s\n' "$1"; }
record_fail() { FAIL=$((FAIL + 1)); printf 'not ok - %s\n' "$1" >&2; }

new_env() {
  TEST_ROOT=$(mktemp -d)
  mkdir -p "$TEST_ROOT/mock"
  cp "$FIXTURE" "$TEST_ROOT/mock/values.json"
  export DESKTOP_MODESCTL_MOCK_DIR="$TEST_ROOT/mock"
  export DESKTOP_MODESCTL_CONFIG_HOME="$TEST_ROOT/config"
  export DESKTOP_MODESCTL_STATE_HOME="$TEST_ROOT/state"
  export DESKTOP_MODESCTL_RUNTIME_HOME="$TEST_ROOT/runtime"
  unset DESKTOP_MODESCTL_MOCK_FAIL_AFTER DESKTOP_MODESCTL_MOCK_UNSUPPORTED
}

cleanup_env() { rm -rf -- "$TEST_ROOT"; }

call() {
  OUTPUT=$("$PROJECT_ROOT/scripts/desktop-modesctl" "$@")
  STATUS=$?
  return 0
}

json_has() { jq -e "$1" <<< "$OUTPUT" >/dev/null 2>&1; }

test_plan_read_only() {
  new_env
  call plan comfortable
  local ok=$([ "$STATUS" -eq 0 ] && [ "$(jq '.changes | length' <<< "$OUTPUT")" -eq 8 ] && [ ! -e "$TEST_ROOT/state/omarchy-desktop-modes/baseline.json" ] && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "plan is read-only"; else record_fail "plan is read-only"; fi
  cleanup_env
}

test_capabilities_and_unsupported() {
  new_env
  call capabilities
  local ok=$([ "$STATUS" -eq 0 ] && json_has '.ok and (.capabilities | length == 12)' && echo yes || echo no)
  export DESKTOP_MODESCTL_MOCK_UNSUPPORTED=gtk.text.scale
  call plan comfortable
  ok=$([[ "$ok" == yes && "$STATUS" -eq 0 ]] && jq -e '.warnings[0].id == "gtk.text.scale"' <<< "$OUTPUT" >/dev/null 2>&1 && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "capability probe and partial support"; else record_fail "capability probe and partial support"; fi
  cleanup_env
}

test_apply_restore() {
  new_env
  local initial
  initial=$(jq -S -c . "$TEST_ROOT/mock/values.json")
  call apply comfortable --operation-id 11111111-1111-4111-8111-111111111111
  local ok=$([ "$STATUS" -eq 0 ] && jq -e '.activeProfile == "comfortable"' "$TEST_ROOT/state/omarchy-desktop-modes/state.json" >/dev/null 2>&1 && echo yes || echo no)
  call restore --operation-id 22222222-2222-4222-8222-222222222222
  local restored
  restored=$(jq -S -c . "$TEST_ROOT/mock/values.json")
  ok=$([[ "$ok" == yes && "$STATUS" -eq 0 && "$initial" == "$restored" ]] && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "apply and exact baseline restore"; else record_fail "apply and exact baseline restore"; fi
  cleanup_env
}

test_baseline_covers_profile_switches() {
  new_env
  local initial
  initial=$(jq -S -c . "$TEST_ROOT/mock/values.json")
  call apply comfortable --operation-id 56565656-5656-4565-8565-656565656565
  call apply focus --operation-id 57575757-5757-4575-8575-757575757575
  call restore --operation-id 58585858-5858-4585-8585-858585858585
  local restored
  restored=$(jq -S -c . "$TEST_ROOT/mock/values.json")
  local ok=$([ "$STATUS" -eq 0 ] && [ "$initial" = "$restored" ] && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "baseline restores settings introduced by later profiles"; else record_fail "baseline restores settings introduced by later profiles"; fi
  cleanup_env
}

test_rollback() {
  new_env
  export DESKTOP_MODESCTL_MOCK_FAIL_AFTER=2
  call apply comfortable --operation-id 33333333-3333-4333-8333-333333333333
  local ok=$([ "$STATUS" -ne 0 ] && [ "$(jq -S -c . "$FIXTURE")" = "$(jq -S -c . "$TEST_ROOT/mock/values.json")" ] && [ ! -e "$TEST_ROOT/state/omarchy-desktop-modes/pending.json" ] && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "transaction rollback after forced failure"; else record_fail "transaction rollback after forced failure"; fi
  cleanup_env
}

test_failed_apply_does_not_leave_a_new_baseline() {
  new_env
  export DESKTOP_MODESCTL_MOCK_FAIL_AFTER=1
  call apply comfortable --operation-id 34343434-3434-4343-8343-343434343434
  local ok=$([ "$STATUS" -ne 0 ] && [ ! -e "$TEST_ROOT/state/omarchy-desktop-modes/baseline.json" ] && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "failed apply removes its uncommitted baseline"; else record_fail "failed apply removes its uncommitted baseline"; fi
  cleanup_env
}

test_preview_recovery() {
  new_env
  call preview reduced-motion --seconds 30 --operation-id 44444444-4444-4444-8444-444444444444
  jq '.preview.deadline = 0' "$TEST_ROOT/state/omarchy-desktop-modes/state.json" > "$TEST_ROOT/state/expired"
  mv "$TEST_ROOT/state/expired" "$TEST_ROOT/state/omarchy-desktop-modes/state.json"
  call recover
  local ok=$([ "$STATUS" -eq 0 ] && jq -e '.recoveredPreview == true' <<< "$OUTPUT" >/dev/null 2>&1 && jq -e '.preview == null' "$TEST_ROOT/state/omarchy-desktop-modes/state.json" >/dev/null 2>&1 && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "expired preview recovery"; else record_fail "expired preview recovery"; fi
  cleanup_env
}

test_status_recovers_expired_preview() {
  new_env
  call preview comfortable --seconds 30 --operation-id 45454545-4545-4454-8454-545454545454
  jq '.preview.deadline = 0' "$TEST_ROOT/state/omarchy-desktop-modes/state.json" > "$TEST_ROOT/state/expired-status"
  mv "$TEST_ROOT/state/expired-status" "$TEST_ROOT/state/omarchy-desktop-modes/state.json"
  call status
  local ok=$([ "$STATUS" -eq 0 ] && jq -e '.preview == null and .activeProfile == null' <<< "$OUTPUT" >/dev/null 2>&1 && jq -e '.preview == null' "$TEST_ROOT/state/omarchy-desktop-modes/state.json" >/dev/null 2>&1 && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "status recovers expired preview"; else record_fail "status recovers expired preview"; fi
  cleanup_env
}

test_preview_revert_preserves_external_drift() {
  new_env
  call preview comfortable --seconds 30 --operation-id 46464646-4646-4464-8464-646464646464
  jq '."hypr.border_size" = 9' "$TEST_ROOT/mock/values.json" > "$TEST_ROOT/mock/changed"
  mv "$TEST_ROOT/mock/changed" "$TEST_ROOT/mock/values.json"
  call cancel-preview --operation-id 46464646-4646-4464-8464-646464646464
  local ok=$([ "$STATUS" -eq 0 ] && jq -e '.preservedExternal == ["hypr.border_size"]' <<< "$OUTPUT" >/dev/null 2>&1 && [ "$(jq -r '."hypr.border_size"' "$TEST_ROOT/mock/values.json")" = 9 ] && [ "$(jq -r '."gtk.text.scale"' "$TEST_ROOT/mock/values.json")" = 1.0 ] && jq -e '.preview == null and .activeProfile == null and (.lastApplied | length == 0)' "$TEST_ROOT/state/omarchy-desktop-modes/state.json" >/dev/null 2>&1 && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "preview revert preserves concurrent external changes"; else record_fail "preview revert preserves concurrent external changes"; fi
  cleanup_env
}

test_preview_revert_is_transactional() {
  new_env
  call preview comfortable --seconds 30 --operation-id 47474747-4747-4474-8474-747474747474
  export DESKTOP_MODESCTL_MOCK_FAIL_AFTER=2
  call cancel-preview --operation-id 47474747-4747-4474-8474-747474747474
  local ok=$([ "$STATUS" -ne 0 ] && jq -e '.preview.profileId == "comfortable"' "$TEST_ROOT/state/omarchy-desktop-modes/state.json" >/dev/null 2>&1 && [ "$(jq -r '."gtk.text.scale"' "$TEST_ROOT/mock/values.json")" = 1.25 ] && [ ! -e "$TEST_ROOT/state/omarchy-desktop-modes/pending.json" ] && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "failed preview revert restores the preview atomically"; else record_fail "failed preview revert restores the preview atomically"; fi
  cleanup_env
}

test_keep_preview_preserves_external_drift() {
  new_env
  call preview comfortable --seconds 30 --operation-id 48484848-4848-4484-8484-848484848484
  jq '."hypr.border_size" = 9' "$TEST_ROOT/mock/values.json" > "$TEST_ROOT/mock/changed"
  mv "$TEST_ROOT/mock/changed" "$TEST_ROOT/mock/values.json"
  call keep-preview --operation-id 48484848-4848-4484-8484-848484848484
  local ok=$([ "$STATUS" -eq 0 ] && jq -e '.preservedExternal == ["hypr.border_size"]' <<< "$OUTPUT" >/dev/null 2>&1 && jq -e '.preview == null and .activeProfile == null and (.lastApplied | has("hypr.border_size") | not)' "$TEST_ROOT/state/omarchy-desktop-modes/state.json" >/dev/null 2>&1 && echo yes || echo no)
  call restore --operation-id 49494949-4949-4494-8494-949494949494
  ok=$([[ "$ok" == yes && "$STATUS" -eq 0 ]] && [ "$(jq -r '."hypr.border_size"' "$TEST_ROOT/mock/values.json")" = 9 ] && [ "$(jq -r '."gtk.text.scale"' "$TEST_ROOT/mock/values.json")" = 1.0 ] && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "keeping a preview preserves concurrent external changes"; else record_fail "keeping a preview preserves concurrent external changes"; fi
  cleanup_env
}

test_conflict_resolution() {
  new_env
  call apply comfortable --operation-id 55555555-5555-4555-8555-555555555555
  jq '."hypr.border_size" = 9' "$TEST_ROOT/mock/values.json" > "$TEST_ROOT/mock/changed"
  mv "$TEST_ROOT/mock/changed" "$TEST_ROOT/mock/values.json"
  call restore --operation-id 66666666-6666-4666-8666-666666666666
  call resolve-conflict hypr.border_size --keep-external
  local ok=$([ "$STATUS" -eq 0 ] && jq -e '.activeProfile == null and (.conflicts | length == 0)' "$TEST_ROOT/state/omarchy-desktop-modes/state.json" >/dev/null 2>&1 && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "external conflict resolution"; else record_fail "external conflict resolution"; fi
  cleanup_env
}

test_restore_does_not_overwrite_unmanaged_baseline_value() {
  new_env
  call apply comfortable --operation-id 67676767-6767-4676-8676-676767676767
  jq '.values."hypr.blur.enabled" = true' "$TEST_ROOT/state/omarchy-desktop-modes/baseline.json" > "$TEST_ROOT/state/omarchy-desktop-modes/baseline-with-unmanaged"
  mv "$TEST_ROOT/state/omarchy-desktop-modes/baseline-with-unmanaged" "$TEST_ROOT/state/omarchy-desktop-modes/baseline.json"
  jq '."hypr.blur.enabled" = false' "$TEST_ROOT/mock/values.json" > "$TEST_ROOT/mock/changed"
  mv "$TEST_ROOT/mock/changed" "$TEST_ROOT/mock/values.json"
  call restore --operation-id 68686868-6868-4686-8686-686868686868
  local ok=$([ "$STATUS" -eq 0 ] && [ "$(jq -r '."hypr.blur.enabled"' "$TEST_ROOT/mock/values.json")" = false ] && [ ! -e "$TEST_ROOT/state/omarchy-desktop-modes/baseline.json" ] && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "restore leaves unmanaged baseline values untouched"; else record_fail "restore leaves unmanaged baseline values untouched"; fi
  cleanup_env
}

test_restore_applies_safe_values_before_conflict_resolution() {
  new_env
  call apply comfortable --operation-id 69696969-6969-4696-8696-696969696969
  jq '."hypr.border_size" = 9' "$TEST_ROOT/mock/values.json" > "$TEST_ROOT/mock/changed"
  mv "$TEST_ROOT/mock/changed" "$TEST_ROOT/mock/values.json"
  call restore --operation-id 70707070-7070-4707-8707-707070707070
  local ok=$([ "$STATUS" -ne 0 ] && [ "$(jq -r '."gtk.text.scale"' "$TEST_ROOT/mock/values.json")" = 1.0 ] && [ -e "$TEST_ROOT/state/omarchy-desktop-modes/baseline.json" ] && jq -e '.activeProfile == null and (.conflicts | length == 1) and (.lastApplied | keys == ["hypr.border_size"])' "$TEST_ROOT/state/omarchy-desktop-modes/state.json" >/dev/null 2>&1 && echo yes || echo no)
  call resolve-conflict hypr.border_size --keep-external
  ok=$([[ "$ok" == yes && "$STATUS" -eq 0 ]] && [ "$(jq -r '."hypr.border_size"' "$TEST_ROOT/mock/values.json")" = 9 ] && [ "$(jq -r '."gtk.text.scale"' "$TEST_ROOT/mock/values.json")" = 1.0 ] && [ ! -e "$TEST_ROOT/state/omarchy-desktop-modes/baseline.json" ] && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "safe restore continues while external conflict is pending"; else record_fail "safe restore continues while external conflict is pending"; fi
  cleanup_env
}

test_mutations_are_blocked_during_preview_and_conflicts() {
  new_env
  call preview reduced-motion --seconds 30 --operation-id 74747474-7474-4747-8747-747474747474
  call apply focus --operation-id 75757575-7575-4757-8757-757575757575
  local ok=$([ "$STATUS" -ne 0 ] && jq -e '.error == "preview-active"' <<< "$OUTPUT" >/dev/null 2>&1 && jq -e '.preview.profileId == "reduced-motion"' "$TEST_ROOT/state/omarchy-desktop-modes/state.json" >/dev/null 2>&1 && echo yes || echo no)
  call cancel-preview --operation-id 74747474-7474-4747-8747-747474747474
  call apply comfortable --operation-id 76767676-7676-4767-8767-767676767676
  jq '."hypr.border_size" = 9' "$TEST_ROOT/mock/values.json" > "$TEST_ROOT/mock/changed"
  mv "$TEST_ROOT/mock/changed" "$TEST_ROOT/mock/values.json"
  call restore --operation-id 78787878-7878-4787-8787-787878787878
  call preview focus --seconds 30 --operation-id 79797979-7979-4797-8797-797979797979
  ok=$([[ "$ok" == yes && "$STATUS" -ne 0 ]] && jq -e '.error == "external-drift-pending"' <<< "$OUTPUT" >/dev/null 2>&1 && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "mutations fail closed during previews and conflicts"; else record_fail "mutations fail closed during previews and conflicts"; fi
  cleanup_env
}

test_recovery_rolls_back_only_journaled_settings() {
  new_env
  mkdir -p "$TEST_ROOT/state/omarchy-desktop-modes"
  jq '."hypr.border_size" = 3 | ."gtk.text.scale" = 1.6' "$TEST_ROOT/mock/values.json" > "$TEST_ROOT/mock/changed"
  mv "$TEST_ROOT/mock/changed" "$TEST_ROOT/mock/values.json"
  jq -n '{schemaVersion:1,operationId:"80808080-8080-4808-8808-808080808080",kind:"apply",profileId:"comfortable",before:{"hypr.border_size":2,"gtk.text.scale":1.0},target:{"hypr.border_size":3,"gtk.text.scale":1.25},applied:["hypr.border_size"],phase:"applying",baselineChanged:false,baselinePrevious:null}' > "$TEST_ROOT/state/omarchy-desktop-modes/pending.json"
  call recover
  local ok=$([ "$STATUS" -eq 0 ] && [ "$(jq -r '."hypr.border_size"' "$TEST_ROOT/mock/values.json")" = 2 ] && [ "$(jq -r '."gtk.text.scale"' "$TEST_ROOT/mock/values.json")" = 1.6 ] && [ ! -e "$TEST_ROOT/state/omarchy-desktop-modes/pending.json" ] && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "recovery touches only write-ahead journal entries"; else record_fail "recovery touches only write-ahead journal entries"; fi
  cleanup_env
}

test_recovery_keeps_committed_settings() {
  new_env
  call apply comfortable --operation-id 81818181-8181-4818-8818-818181818181
  jq '."gtk.text.scale" = 1.6' "$TEST_ROOT/mock/values.json" > "$TEST_ROOT/mock/changed"
  mv "$TEST_ROOT/mock/changed" "$TEST_ROOT/mock/values.json"
  jq -n '{schemaVersion:1,operationId:"81818181-8181-4818-8818-818181818181",kind:"apply",profileId:"comfortable",before:{"gtk.text.scale":1.0},target:{"gtk.text.scale":1.25},applied:["gtk.text.scale"],phase:"applied",baselineChanged:false,baselinePrevious:null}' > "$TEST_ROOT/state/omarchy-desktop-modes/pending.json"
  call recover
  local ok=$([ "$STATUS" -eq 0 ] && [ "$(jq -r '."gtk.text.scale"' "$TEST_ROOT/mock/values.json")" = 1.6 ] && [ ! -e "$TEST_ROOT/state/omarchy-desktop-modes/pending.json" ] && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "recovery recognizes a durably committed operation"; else record_fail "recovery recognizes a durably committed operation"; fi
  cleanup_env
}

test_conflict_restore_rechecks_live_drift() {
  new_env
  call apply comfortable --operation-id 82828282-8282-4828-8828-828282828282
  jq '."hypr.border_size" = 9' "$TEST_ROOT/mock/values.json" > "$TEST_ROOT/mock/changed"
  mv "$TEST_ROOT/mock/changed" "$TEST_ROOT/mock/values.json"
  call restore --operation-id 83838383-8383-4838-8838-838383838383
  jq '."hypr.border_size" = 10' "$TEST_ROOT/mock/values.json" > "$TEST_ROOT/mock/changed-again"
  mv "$TEST_ROOT/mock/changed-again" "$TEST_ROOT/mock/values.json"
  call resolve-conflict hypr.border_size --restore-baseline
  local ok=$([ "$STATUS" -ne 0 ] && jq -e '.error == "external-drift-changed"' <<< "$OUTPUT" >/dev/null 2>&1 && [ "$(jq -r '."hypr.border_size"' "$TEST_ROOT/mock/values.json")" = 10 ] && echo yes || echo no)
  call resolve-conflict hypr.border_size --restore-baseline
  ok=$([[ "$ok" == yes && "$STATUS" -eq 0 ]] && [ "$(jq -r '."hypr.border_size"' "$TEST_ROOT/mock/values.json")" = 2 ] && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "conflict restore requires a fresh drift decision"; else record_fail "conflict restore requires a fresh drift decision"; fi
  cleanup_env
}

test_no_supported_settings_fails_without_baseline() {
  new_env
  export DESKTOP_MODESCTL_MOCK_UNSUPPORTED=hypr.animations.enabled,gtk.animations.enabled,hypr.blur.enabled,hypr.shadow.enabled
  call apply reduced-motion --operation-id 84848484-8484-4848-8848-848484848484
  local ok=$([ "$STATUS" -ne 0 ] && jq -e '.error | contains("no supported settings")' <<< "$OUTPUT" >/dev/null 2>&1 && [ ! -e "$TEST_ROOT/state/omarchy-desktop-modes/baseline.json" ] && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "empty runtime target cannot become active"; else record_fail "empty runtime target cannot become active"; fi
  cleanup_env
}

test_restore_tracks_managed_values_across_profile_switches() {
  new_env
  call apply comfortable --operation-id 71717171-7171-4717-8717-717171717171
  call apply focus --operation-id 72727272-7272-4727-8727-727272727272
  jq '."gtk.text.scale" = 1.5' "$TEST_ROOT/mock/values.json" > "$TEST_ROOT/mock/changed"
  mv "$TEST_ROOT/mock/changed" "$TEST_ROOT/mock/values.json"
  call restore --operation-id 73737373-7373-4737-8737-737373737373
  local ok=$([ "$STATUS" -ne 0 ] && [ "$(jq -r '."gtk.text.scale"' "$TEST_ROOT/mock/values.json")" = 1.5 ] && [ "$(jq -r '.details.conflicts[0].id' <<< "$OUTPUT")" = "gtk.text.scale" ] && echo yes || echo no)
  call resolve-conflict gtk.text.scale --keep-external
  ok=$([[ "$ok" == yes && "$STATUS" -eq 0 ]] && [ "$(jq -r '."gtk.text.scale"' "$TEST_ROOT/mock/values.json")" = 1.5 ] && [ ! -e "$TEST_ROOT/state/omarchy-desktop-modes/baseline.json" ] && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "restore tracks settings managed by earlier profiles"; else record_fail "restore tracks settings managed by earlier profiles"; fi
  cleanup_env
}

test_idempotency_and_diagnostics() {
  new_env
  call apply comfortable --operation-id 77777777-7777-4777-8777-777777777777
  call apply comfortable --operation-id 77777777-7777-4777-8777-777777777777
  local ok=$([ "$STATUS" -eq 0 ] && jq -e '.idempotent == true' <<< "$OUTPUT" >/dev/null 2>&1 && echo yes || echo no)
  call apply focus --operation-id 77777777-7777-4777-8777-777777777777
  ok=$([[ "$ok" == yes && "$STATUS" -ne 0 ]] && jq -e '.error == "operation-id-reused"' <<< "$OUTPUT" >/dev/null 2>&1 && echo yes || echo no)
  call export-diagnostics
  ok=$([[ "$ok" == yes && "$STATUS" -eq 0 ]] && jq -e '.ok and (.notes | length == 1)' <<< "$OUTPUT" >/dev/null 2>&1 && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "operation idempotency and redacted diagnostics"; else record_fail "operation idempotency and redacted diagnostics"; fi
  cleanup_env
}

test_profile_validation() {
  new_env
  mkdir -p "$TEST_ROOT/config/omarchy-desktop-modes"
  jq -n '{schemaVersion:1,profiles:[{id:"bad",name:"Bad",description:"",settings:{"not-registered":true}}]}' > "$TEST_ROOT/config/omarchy-desktop-modes/profiles.json"
  call list-profiles
  local ok=$([ "$STATUS" -ne 0 ] && jq -e '.error == "profile data is invalid"' <<< "$OUTPUT" >/dev/null 2>&1 && echo yes || echo no)
  jq -n '{schemaVersion:1,profiles:[{id:"empty",name:"Empty",description:"",settings:{}}]}' > "$TEST_ROOT/config/omarchy-desktop-modes/profiles.json"
  call list-profiles
  ok=$([[ "$ok" == yes && "$STATUS" -ne 0 ]] && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "user profile schema validation"; else record_fail "user profile schema validation"; fi
  cleanup_env
}

test_custom_profile_crud() {
  new_env
  local payload='{"id":"my-clear-mode","name":"My Clear Mode","description":"A personal clarity preset.","icon":"clarity","settings":{"gtk.text.scale":1.4,"gtk.cursor.size":48}}'
  call save-profile "$payload"
  local ok=$([ "$STATUS" -eq 0 ] && jq -e '.saved == true' <<< "$OUTPUT" >/dev/null 2>&1 && echo yes || echo no)
  call list-profiles
  ok=$([[ "$ok" == yes && "$STATUS" -eq 0 ]] && jq -e '.profiles[] | select(.id == "my-clear-mode" and .source == "custom")' <<< "$OUTPUT" >/dev/null 2>&1 && echo yes || echo no)
  call delete-profile my-clear-mode
  ok=$([[ "$ok" == yes && "$STATUS" -eq 0 ]] && echo yes || echo no)
  call list-profiles
  ok=$([[ "$ok" == yes && "$STATUS" -eq 0 ]] && ! jq -e '.profiles[] | select(.id == "my-clear-mode")' <<< "$OUTPUT" >/dev/null 2>&1 && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "custom profile save and delete"; else record_fail "custom profile save and delete"; fi
  cleanup_env
}

test_invalid_and_symlink_state() {
  new_env
  call plan 'comfortable;touch /tmp/desktop-modesctl-should-not-exist'
  local ok=$([ "$STATUS" -ne 0 ] && echo yes || echo no)
  local link_root="$TEST_ROOT/symlink-state"
  mkdir -p "$link_root/omarchy-desktop-modes" "$TEST_ROOT/target"
  ln -s "$TEST_ROOT/target/state.json" "$link_root/omarchy-desktop-modes/state.json"
  DESKTOP_MODESCTL_STATE_HOME="$link_root" call list-profiles
  ok=$([[ "$ok" == yes && "$STATUS" -ne 0 ]] && echo yes || echo no)
  local fifo_root="$TEST_ROOT/fifo-state"
  mkdir -p "$fifo_root/omarchy-desktop-modes"
  mkfifo "$fifo_root/omarchy-desktop-modes/state.json"
  DESKTOP_MODESCTL_STATE_HOME="$fifo_root" call status
  ok=$([[ "$ok" == yes && "$STATUS" -ne 0 ]] && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "strict input and symlink rejection"; else record_fail "strict input and symlink rejection"; fi
  cleanup_env
}

test_malformed_state() {
  new_env
  mkdir -p "$TEST_ROOT/state/omarchy-desktop-modes"
  printf '%s\n' '{not-json' > "$TEST_ROOT/state/omarchy-desktop-modes/state.json"
  call status
  local ok=$([ "$STATUS" -ne 0 ] && jq -e '.error | contains("malformed")' <<< "$OUTPUT" >/dev/null 2>&1 && echo yes || echo no)
  printf '%s\n' '{"schemaVersion":1,"activeProfile":null,"lastApplied":{"not-registered":true},"preview":null,"conflicts":[],"lastOperationId":null}' > "$TEST_ROOT/state/omarchy-desktop-modes/state.json"
  call status
  ok=$([[ "$ok" == yes && "$STATUS" -ne 0 ]] && echo yes || echo no)
  printf '%s\n' '{"schemaVersion":1,"activeProfile":"comfortable","lastApplied":{"gtk.text.scale":1.25},"preview":null,"conflicts":[],"lastOperationId":"85858585-8585-4858-8858-858585858585"}' > "$TEST_ROOT/state/omarchy-desktop-modes/state.json"
  call status
  ok=$([[ "$ok" == yes && "$STATUS" -ne 0 ]] && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "malformed state fails closed"; else record_fail "malformed state fails closed"; fi
  cleanup_env
}

test_malformed_pending_journal() {
  new_env
  mkdir -p "$TEST_ROOT/state/omarchy-desktop-modes"
  jq -n '{schemaVersion:1,operationId:"86868686-8686-4868-8868-868686868686",kind:"apply",profileId:"comfortable",before:{"gtk.text.scale":1.0},target:{"gtk.text.scale":1.25},applied:["hypr.border_size"],phase:"applying",baselineChanged:false,baselinePrevious:null}' > "$TEST_ROOT/state/omarchy-desktop-modes/pending.json"
  call recover
  local ok=$([ "$STATUS" -ne 0 ] && jq -e '.error == "pending journal is malformed"' <<< "$OUTPUT" >/dev/null 2>&1 && [ "$(jq -S -c . "$FIXTURE")" = "$(jq -S -c . "$TEST_ROOT/mock/values.json")" ] && echo yes || echo no)
  if [[ "$ok" == yes ]]; then record_pass "malformed recovery journal fails closed"; else record_fail "malformed recovery journal fails closed"; fi
  cleanup_env
}

test_plan_read_only
test_capabilities_and_unsupported
test_apply_restore
test_baseline_covers_profile_switches
test_rollback
test_failed_apply_does_not_leave_a_new_baseline
test_preview_recovery
test_status_recovers_expired_preview
test_preview_revert_preserves_external_drift
test_preview_revert_is_transactional
test_keep_preview_preserves_external_drift
test_conflict_resolution
test_restore_does_not_overwrite_unmanaged_baseline_value
test_restore_applies_safe_values_before_conflict_resolution
test_restore_tracks_managed_values_across_profile_switches
test_mutations_are_blocked_during_preview_and_conflicts
test_recovery_rolls_back_only_journaled_settings
test_recovery_keeps_committed_settings
test_conflict_restore_rechecks_live_drift
test_no_supported_settings_fails_without_baseline
test_idempotency_and_diagnostics
test_profile_validation
test_custom_profile_crud
test_invalid_and_symlink_state
test_malformed_state
test_malformed_pending_journal

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
