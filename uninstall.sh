#!/usr/bin/env bash
# Reverse Voxtype config changes, remove copied agent skills,
# and delete local meeting notes. Run this BEFORE `omarchy plugin remove`.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
KEEP_NOTES=0

usage() {
  cat <<'EOF'
Usage: uninstall.sh [--keep-notes]

Restores Voxtype config from the backup taken before this plugin changed it,
asks Voxtype to reread that config, removes copied agent skills, deletes
onboarding state, and (unless --keep-notes) deletes local meeting markdown.

Then remove the plugin itself:
  omarchy plugin remove jlopezxs.meetings
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --keep-notes)
      KEEP_NOTES=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

args=(--uninstall)
if (( KEEP_NOTES )); then
  args+=(--keep-notes)
fi

python3 "$ROOT/scripts/meetings" "${args[@]}"
