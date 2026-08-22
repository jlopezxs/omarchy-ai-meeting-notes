#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

python3 -m py_compile scripts/meetings
node tests/model.test.js
python3 tests/transcript.test.py

python3 - <<'PY'
from pathlib import Path
skill = Path("skills/omarchy-meeting-notepad/SKILL.md")
assert skill.is_file(), "missing skills/omarchy-meeting-notepad/SKILL.md"
text = skill.read_text(encoding="utf-8")
assert text.startswith("---"), "SKILL.md must start with YAML frontmatter"
assert "name: omarchy-meeting-notepad" in text
assert "description:" in text
assert "index.jsonl" in text
assert "transcript.jsonl" in text
assert "meta.json" in text
assert "transcript.md" in text
print("skill: ok")
PY

if command -v omarchy >/dev/null 2>&1; then
  omarchy plugin validate "$ROOT"
fi

if [[ -n "${OMARCHY_PATH:-}" ]] && command -v qmllint >/dev/null 2>&1; then
  qmllint -I "$OMARCHY_PATH/shell" Service.qml
  qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml Panel.qml || true
fi

echo "validate.sh: ok"
