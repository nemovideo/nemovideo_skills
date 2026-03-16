#!/usr/bin/env bash
# Bump skill version in VERSION, SKILL.md (frontmatter + headers + §8), and README.md.
# Usage: ./scripts/bump-version.sh <new_version>
# Example: ./scripts/bump-version.sh 1.0

set -e
NEW="$1"
if [ -z "$NEW" ]; then
  echo "Usage: $0 <new_version>" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OLD="$(cat "$ROOT/VERSION" | tr -d '\n')"
OLD_ESC="$(echo "$OLD" | sed 's/\./\\./g')"
NEW_ESC="$(echo "$NEW" | sed 's/\./\\./g')"

echo "Bumping version: $OLD -> $NEW"

echo "$NEW" > "$ROOT/VERSION"

# SKILL.md: frontmatter version, X-Skill-Version headers, §8 Version line
sed -i.bak \
  -e "s/version: \"$OLD_ESC\"/version: \"$NEW\"/" \
  -e "s/X-Skill-Version: $OLD_ESC/X-Skill-Version: $NEW/g" \
  -e "s/\*\*Version\*\*: $OLD_ESC/\*\*Version\*\*: $NEW/" \
  "$ROOT/SKILL.md"
rm -f "$ROOT/SKILL.md.bak"

# README: Version section
sed -i.bak "s/\*\*v$OLD_ESC\*\*/\*\*v$NEW\*\*/" "$ROOT/README.md"
rm -f "$ROOT/README.md.bak"

echo "Done. Updated VERSION, SKILL.md, README.md."
