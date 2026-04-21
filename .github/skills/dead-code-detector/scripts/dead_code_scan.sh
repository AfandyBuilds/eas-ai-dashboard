#!/usr/bin/env bash
# Dead Code Scanner — Codebase Hygiene Tool
# Usage: bash dead_code_scan.sh [project_root] [--incremental YYYY-MM-DD]
#
# Scans a project for unreferenced files, unused exports, orphaned CSS classes,
# unused imports, and dead code branches. Outputs a structured report.
#
# Options:
#   project_root       Path to the project root (default: current directory)
#   --incremental DATE Only scan files modified since DATE (YYYY-MM-DD format)

set -euo pipefail

PROJECT_ROOT="${1:-.}"
INCREMENTAL_DATE=""
REPORT_FILE="${PROJECT_ROOT}/DEAD_CODE_REPORT.md"

# Parse flags
shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --incremental)
      INCREMENTAL_DATE="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

# Directories to always exclude
EXCLUDE_DIRS="node_modules|\.git|dist|build|\.next|__pycache__|\.cache|coverage|\.nyc_output|vendor|\.github"

# File extensions to scan
SRC_EXTENSIONS="js|ts|jsx|tsx|html|css|sql|py|go|rs|java|rb|php|vue|svelte"

echo "=== Dead Code Scanner ==="
echo "Project: ${PROJECT_ROOT}"
echo "Date: $(date +%Y-%m-%d)"
echo ""

# ─── Step 1: Build file inventory ───
echo "[1/7] Building file inventory..."

if [[ -n "$INCREMENTAL_DATE" ]]; then
  echo "  Incremental mode: only files modified since $INCREMENTAL_DATE"
  FILES=$(find "$PROJECT_ROOT" -type f -newermt "$INCREMENTAL_DATE" \
    -regextype posix-extended -regex ".*\.(${SRC_EXTENSIONS})" \
    | grep -Ev "(${EXCLUDE_DIRS})" || true)
else
  FILES=$(find "$PROJECT_ROOT" -type f \
    -regextype posix-extended -regex ".*\.(${SRC_EXTENSIONS})" \
    | grep -Ev "(${EXCLUDE_DIRS})" || true)
fi

TOTAL_FILES=$(echo "$FILES" | grep -c . || echo 0)
echo "  Found $TOTAL_FILES source files"
echo ""

# ─── Step 2: Find unreferenced files ───
echo "[2/7] Scanning for unreferenced files..."

UNREFERENCED=()
ENTRY_POINTS="index\.html|main\.js|app\.js|server\.js|package\.json|\.env|tsconfig|webpack|vite\.config|next\.config|Makefile|Dockerfile|README|CHANGELOG|CLAUDE"

while IFS= read -r file; do
  [[ -z "$file" ]] && continue
  basename_f=$(basename "$file")
  name_no_ext="${basename_f%.*}"

  # Skip known entry points and config files
  if echo "$basename_f" | grep -qEi "$ENTRY_POINTS"; then
    continue
  fi

  # Skip migration files (usually referenced by runner, not imports)
  if echo "$file" | grep -qEi "migration|migrate|seed"; then
    continue
  fi

  # Count references to this file (by name, without extension)
  ref_count=$(grep -rl --include="*.js" --include="*.ts" --include="*.html" \
    --include="*.css" --include="*.jsx" --include="*.tsx" --include="*.vue" \
    --include="*.sql" \
    --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist \
    "$name_no_ext" "$PROJECT_ROOT" 2>/dev/null \
    | grep -v "$file" | wc -l || echo 0)

  if [[ "$ref_count" -eq 0 ]]; then
    file_size=$(du -h "$file" 2>/dev/null | cut -f1 || echo "?")
    last_mod=$(stat -c %y "$file" 2>/dev/null | cut -d' ' -f1 || echo "unknown")
    UNREFERENCED+=("$file|$last_mod|$file_size")
  fi
done <<< "$FILES"

echo "  Found ${#UNREFERENCED[@]} potentially unreferenced files"

# ─── Step 3: Find unused exports (JS/TS) ───
echo "[3/7] Scanning for unused exports..."

UNUSED_EXPORTS=()
JS_FILES=$(echo "$FILES" | grep -E '\.(js|ts|jsx|tsx)$' || true)

while IFS= read -r file; do
  [[ -z "$file" ]] && continue

  # Extract export names
  exports=$(grep -oP '(?:export\s+(?:default\s+)?(?:function|const|let|var|class)\s+)\K[a-zA-Z_$][a-zA-Z0-9_$]*' "$file" 2>/dev/null || true)

  while IFS= read -r exp_name; do
    [[ -z "$exp_name" ]] && continue
    [[ ${#exp_name} -lt 2 ]] && continue

    # Check if this export is imported/used anywhere else
    usage_count=$(grep -rl --include="*.js" --include="*.ts" --include="*.html" \
      --include="*.jsx" --include="*.tsx" \
      --exclude-dir=node_modules --exclude-dir=.git \
      "$exp_name" "$PROJECT_ROOT" 2>/dev/null \
      | grep -v "$file" | wc -l || echo 0)

    if [[ "$usage_count" -eq 0 ]]; then
      UNUSED_EXPORTS+=("$file|$exp_name")
    fi
  done <<< "$exports"
done <<< "$JS_FILES"

echo "  Found ${#UNUSED_EXPORTS[@]} potentially unused exports"

# ─── Step 4: Find unused CSS classes ───
echo "[4/7] Scanning for unused CSS classes..."

UNUSED_CSS=()
CSS_FILES=$(echo "$FILES" | grep -E '\.css$' || true)
HTML_JS_FILES=$(echo "$FILES" | grep -E '\.(html|js|ts|jsx|tsx|vue|svelte)$' || true)

while IFS= read -r css_file; do
  [[ -z "$css_file" ]] && continue

  # Extract class names from CSS
  classes=$(grep -oP '(?<!\w)\.[a-zA-Z_-][a-zA-Z0-9_-]*' "$css_file" 2>/dev/null \
    | sed 's/^\.//' | sort -u || true)

  while IFS= read -r class_name; do
    [[ -z "$class_name" ]] && continue
    [[ ${#class_name} -lt 2 ]] && continue

    # Check if class is used in any HTML or JS file
    used=$(echo "$HTML_JS_FILES" | xargs grep -l "$class_name" 2>/dev/null | wc -l || echo 0)

    if [[ "$used" -eq 0 ]]; then
      UNUSED_CSS+=("$css_file|$class_name")
    fi
  done <<< "$classes"
done <<< "$CSS_FILES"

echo "  Found ${#UNUSED_CSS[@]} potentially unused CSS classes"

# ─── Step 5: Find orphaned imports ───
echo "[5/7] Scanning for orphaned imports..."

ORPHANED_IMPORTS=()
while IFS= read -r file; do
  [[ -z "$file" ]] && continue

  # Extract import names (ES6 style)
  imports=$(grep -oP '(?:import\s+\{?\s*)\K[a-zA-Z_$][a-zA-Z0-9_$, ]*(?=\s*\}?\s+from)' "$file" 2>/dev/null || true)

  while IFS= read -r import_line; do
    [[ -z "$import_line" ]] && continue
    # Split comma-separated imports
    IFS=',' read -ra import_names <<< "$import_line"
    for imp in "${import_names[@]}"; do
      imp=$(echo "$imp" | xargs) # trim whitespace
      [[ -z "$imp" ]] && continue
      [[ ${#imp} -lt 2 ]] && continue

      # Check if the imported name is used in the file (excluding the import line)
      usage=$(grep -c "$imp" "$file" 2>/dev/null || echo 0)
      if [[ "$usage" -le 1 ]]; then
        ORPHANED_IMPORTS+=("$file|$imp")
      fi
    done
  done <<< "$imports"
done <<< "$JS_FILES"

echo "  Found ${#ORPHANED_IMPORTS[@]} potentially orphaned imports"

# ─── Step 6: Find commented-out code blocks ───
echo "[6/7] Scanning for large commented-out code blocks..."

COMMENTED_BLOCKS=()
while IFS= read -r file; do
  [[ -z "$file" ]] && continue

  # Find blocks of 5+ consecutive comment lines that look like code
  awk '
    /^[[:space:]]*(\/\/|#|--)[[:space:]]*[a-zA-Z]/ { count++; start = (count == 1) ? NR : start; next }
    { if (count >= 5) print FILENAME ":" start "-" NR-1 " (" count " lines)"; count = 0 }
    END { if (count >= 5) print FILENAME ":" start "-" NR " (" count " lines)" }
  ' "$file" 2>/dev/null
done <<< "$FILES" | while IFS= read -r block; do
  [[ -n "$block" ]] && COMMENTED_BLOCKS+=("$block")
  echo "$block"
done > /tmp/dead_code_comments.txt 2>/dev/null || true

COMMENT_COUNT=$(wc -l < /tmp/dead_code_comments.txt 2>/dev/null || echo 0)
echo "  Found $COMMENT_COUNT commented-out code blocks"

# ─── Step 7: Find unused npm dependencies ───
echo "[7/7] Scanning for unused npm dependencies..."

UNUSED_DEPS=()
if [[ -f "$PROJECT_ROOT/package.json" ]]; then
  # Extract dependency names
  deps=$(node -e "
    const pkg = require('$PROJECT_ROOT/package.json');
    const deps = Object.keys(pkg.dependencies || {});
    deps.forEach(d => console.log(d));
  " 2>/dev/null || true)

  while IFS= read -r dep; do
    [[ -z "$dep" ]] && continue

    # Check if dependency is imported/required anywhere in source
    usage=$(grep -rl --include="*.js" --include="*.ts" --include="*.jsx" --include="*.tsx" \
      --exclude-dir=node_modules --exclude-dir=.git \
      "$dep" "$PROJECT_ROOT" 2>/dev/null | wc -l || echo 0)

    if [[ "$usage" -eq 0 ]]; then
      UNUSED_DEPS+=("$dep")
    fi
  done <<< "$deps"

  echo "  Found ${#UNUSED_DEPS[@]} potentially unused dependencies"
else
  echo "  No package.json found, skipping"
fi

# ─── Generate Report ───
echo ""
echo "=== Generating Report ==="

TOTAL_FINDINGS=$(( ${#UNREFERENCED[@]} + ${#UNUSED_EXPORTS[@]} + ${#UNUSED_CSS[@]} + ${#ORPHANED_IMPORTS[@]} + ${#UNUSED_DEPS[@]} + COMMENT_COUNT ))

cat > "$REPORT_FILE" << EOF
# Dead Code Report

**Project:** $(basename "$PROJECT_ROOT")
**Scanned:** $(date +%Y-%m-%d)
**Files analyzed:** $TOTAL_FILES
**Total findings:** $TOTAL_FINDINGS

## Summary

| Category | Count | Severity |
|----------|-------|----------|
| Unreferenced Files | ${#UNREFERENCED[@]} | High |
| Unused Exports | ${#UNUSED_EXPORTS[@]} | Medium |
| Unused CSS Classes | ${#UNUSED_CSS[@]} | Low |
| Orphaned Imports | ${#ORPHANED_IMPORTS[@]} | Medium |
| Commented-Out Code | $COMMENT_COUNT | Low |
| Unused Dependencies | ${#UNUSED_DEPS[@]} | Medium |

---

## Unreferenced Files

| File | Last Modified | Size | Recommendation |
|------|--------------|------|----------------|
EOF

for item in "${UNREFERENCED[@]}"; do
  IFS='|' read -r f_path f_date f_size <<< "$item"
  echo "| \`$f_path\` | $f_date | $f_size | Review → Delete |" >> "$REPORT_FILE"
done

cat >> "$REPORT_FILE" << EOF

## Unused Exports

| File | Export Name | Recommendation |
|------|------------|----------------|
EOF

for item in "${UNUSED_EXPORTS[@]}"; do
  IFS='|' read -r f_path f_name <<< "$item"
  echo "| \`$f_path\` | \`$f_name\` | Remove export |" >> "$REPORT_FILE"
done

cat >> "$REPORT_FILE" << EOF

## Unused CSS Classes

| File | Class Name | Recommendation |
|------|-----------|----------------|
EOF

for item in "${UNUSED_CSS[@]}"; do
  IFS='|' read -r f_path f_class <<< "$item"
  echo "| \`$f_path\` | \`.$f_class\` | Remove rule |" >> "$REPORT_FILE"
done

cat >> "$REPORT_FILE" << EOF

## Orphaned Imports

| File | Import Name | Recommendation |
|------|------------|----------------|
EOF

for item in "${ORPHANED_IMPORTS[@]}"; do
  IFS='|' read -r f_path f_imp <<< "$item"
  echo "| \`$f_path\` | \`$f_imp\` | Remove import |" >> "$REPORT_FILE"
done

cat >> "$REPORT_FILE" << EOF

## Commented-Out Code Blocks

EOF

if [[ -f /tmp/dead_code_comments.txt ]]; then
  while IFS= read -r line; do
    [[ -n "$line" ]] && echo "- \`$line\`" >> "$REPORT_FILE"
  done < /tmp/dead_code_comments.txt
fi

cat >> "$REPORT_FILE" << EOF

## Unused Dependencies

| Package | Recommendation |
|---------|----------------|
EOF

for dep in "${UNUSED_DEPS[@]}"; do
  echo "| \`$dep\` | \`npm uninstall $dep\` |" >> "$REPORT_FILE"
done

cat >> "$REPORT_FILE" << EOF

---

*Generated by Dead Code Detector skill — $(date +%Y-%m-%d)*
EOF

echo "Report saved to: $REPORT_FILE"
echo "Done!"
