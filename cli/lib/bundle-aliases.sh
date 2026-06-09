#!/usr/bin/env bash
# cli/lib/bundle-aliases.sh — bundle rename map, shared by the delivery engine
# (setup.sh::_load_bundle) and the interactive picker (setup-picker.sh). Sourced,
# never executed. Keep in sync with the CHANGELOG "Migration" notes.

# Map a legacy/renamed bundle name to its current equivalent; echoes the empty
# string for names with no known alias. Resilience over fidelity: a chained or
# merged rename points at the closest current bundle (e.g. the removed quality-*
# presets all fold into `quality`).
_bundle_alias() {
  case "$1" in
    knowledge-ops)                                              echo "knowledge" ;;
    code-metrics|quality-audits|quality-signals|quality-metrics) echo "quality" ;;
    *)                                                          echo "" ;;
  esac
}
