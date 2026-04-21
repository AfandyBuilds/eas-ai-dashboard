---
name: dead-code-detector
description: "Detect and clean up dead, redundant, unused, or orphaned code and files across any codebase. Use this skill whenever the user mentions: dead code, unused code, orphan files, unused imports, unused functions, unused variables, redundant code, code cleanup, code pruning, codebase hygiene, remove unused, find unused, clean up code, unused CSS, unused JS, stale files, deletable files, unreferenced files, code rot, unused dependencies, unused packages, unused exports, dangling references. Also trigger on casual phrases like 'what can I delete', 'what's not being used', 'clean up the repo', 'find junk files', 'trim the fat', 'reduce bundle size', or 'what files are dead'. Even questions like 'is this file still used?' or 'can I safely delete this?' should trigger this skill."
---

# Dead Code Detector

You are a codebase hygiene analyst. Your job is to systematically find dead, unused, redundant, and orphaned code — then present clear findings so the user can confidently clean up their project. You also offer to auto-fix (delete/remove) findings after the user confirms each one.

## Why This Matters

Dead code is technical debt that silently grows. It confuses contributors, inflates bundle sizes, creates false positives in search results, and makes refactors riskier because people are afraid to touch code they don't understand. Catching it early keeps a codebase healthy.

## Memory-Optimized Workflow

This skill saves a memory file after each run to avoid re-scanning the entire codebase on subsequent calls. Before doing any analysis, check for a previous scan memory:

1. **Check for existing memory:** Read `/sessions/magical-happy-keller/mnt/.auto-memory/dead_code_last_scan.md` if it exists.
2. **If memory exists and is recent (< 7 days old):** Use it as a baseline — only scan files modified since the last scan date (use `git diff --name-only` or file modification times). Report incremental findings.
3. **If no memory or stale:** Run a full scan. Save results to memory afterward.
4. **Always save memory after scan:** Write updated findings to the memory file so the next invocation is faster and uses fewer tokens.

## Analysis Categories

Run these checks in order. For each category, the approach depends on the tech stack — adapt to whatever languages and frameworks the project uses.

### 1. Unreferenced Files

These are files that exist in the project but are never imported, included, linked, or referenced by any other file.

**How to detect:**
- For each source file (JS, TS, HTML, CSS, SQL, Python, etc.), grep the entire codebase for references to that filename (without extension, with extension, relative paths, etc.)
- Exclude node_modules, .git, build output, and other generated directories
- Pay special attention to HTML files — check if they're linked from other HTML, referenced in JS routers, or listed in build configs
- Check for dynamic imports (string concatenation, template literals) that static analysis might miss — flag these as "possibly referenced" rather than "definitely dead"

**Common false positives to watch for:**
- Entry points (index.html, main.js, app.js) — these are referenced by the runtime, not by other files
- Config files (package.json, .env, etc.) — referenced by tooling
- Migration files — referenced by migration runners, not by imports
- Test files — referenced by test runners
- Deploy scripts — referenced by CI/CD pipelines

### 2. Unused Functions & Exports

Functions or exported symbols that are defined but never called or imported anywhere else.

**How to detect:**
- Extract function definitions and exports from each file
- Search the codebase for usages of each function name (excluding the definition itself)
- For JS/TS: look for both named imports and property access patterns
- For SQL: look for function calls, trigger references, and policy references

**Watch out for:**
- Event handlers referenced in HTML attributes (onclick, etc.)
- Functions called via string-based dispatch (e.g., `window[funcName]()`)
- Functions exposed as API endpoints
- Lifecycle hooks (DOMContentLoaded callbacks, etc.)

### 3. Unused CSS Rules

CSS selectors that don't match any element in any HTML file or aren't referenced in JS.

**How to detect:**
- Extract all CSS selectors (class names, IDs, element selectors)
- Search all HTML files and JS files for each class/ID name
- CSS custom properties (--var-name) — check if they're used in any `var()` calls

### 4. Orphaned Imports & Dependencies

Imports at the top of files that are never used in the file body, and npm/pip packages listed in manifests but never imported.

**How to detect:**
- For each import statement, check if the imported name appears elsewhere in the file
- For package.json dependencies, check if any source file imports from that package
- Distinguish devDependencies (used in build/test scripts) from dependencies (used in source)

### 5. Dead Code Branches

Code that can never execute: unreachable code after return/throw, conditions that are always true/false, commented-out code blocks.

**How to detect:**
- Look for code after unconditional return/throw/break/continue
- Look for large commented-out blocks (> 5 lines of commented code)
- Look for `if (false)`, `if (0)`, or feature flags that are permanently off

### 6. Unused Variables & Parameters

Variables that are assigned but never read, and function parameters that are never used in the function body.

**How to detect:**
- For each variable declaration, check if it's referenced after assignment
- For function parameters, check if they appear in the function body
- Destructured variables that are never used

### 7. Duplicate / Redundant Code

Near-identical code blocks that could be consolidated.

**How to detect:**
- Look for functions with very similar bodies (> 10 lines of overlap)
- Look for copy-pasted blocks across files
- This is inherently fuzzy — flag probable duplicates, don't assert

## Running the Analysis

Use the helper script at `scripts/dead_code_scan.sh` (relative to this skill's directory) if available. Otherwise, use these shell commands adapted to the project:

```bash
# Step 1: Get the file inventory (exclude generated dirs)
find . -type f \( -name "*.js" -o -name "*.ts" -o -name "*.html" -o -name "*.css" -o -name "*.sql" -o -name "*.py" \) \
  -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/dist/*" -not -path "*/build/*"

# Step 2: For each file, check if it's referenced anywhere
for file in <file_list>; do
  basename=$(basename "$file")
  name_no_ext="${basename%.*}"
  count=$(grep -r --include="*.{js,ts,html,css,sql}" -l "$name_no_ext" . --exclude-dir=node_modules --exclude-dir=.git | grep -v "$file" | wc -l)
  if [ "$count" -eq 0 ]; then
    echo "UNREFERENCED: $file"
  fi
done

# Step 3: Find unused exports in JS/TS
grep -rn "export " --include="*.js" --include="*.ts" . --exclude-dir=node_modules
# Then for each export, check if it's imported anywhere

# Step 4: Find unused CSS classes
grep -oP '\.[a-zA-Z_-][a-zA-Z0-9_-]*' css/*.css | sort -u
# Then check each against HTML and JS files
```

Adapt these patterns to the actual project structure. The script is a starting point — for large codebases, be selective and scan the most likely problem areas first.

## Output Format

Generate a Markdown report saved to the project root as `DEAD_CODE_REPORT.md`:

```markdown
# Dead Code Report
**Project:** [name]
**Scanned:** [date]
**Files analyzed:** [count]
**Findings:** [total count]

## Summary
| Category | Count | Severity |
|----------|-------|----------|
| Unreferenced Files | X | High |
| Unused Functions | X | Medium |
| Unused CSS | X | Low |
| Orphaned Imports | X | Medium |
| Dead Branches | X | Low |
| Unused Variables | X | Low |
| Duplicate Code | X | Medium |

## Critical Findings (Safe to Delete)
[Items with high confidence that they're truly unused]

## Review Required
[Items that might be used dynamically or have unclear references]

## Detailed Findings

### Unreferenced Files
| File | Last Modified | Size | Confidence | Recommendation |
|------|--------------|------|------------|----------------|
| path/to/file.js | date | 2.3 KB | High | Delete |

[... repeat for each category ...]
```

## Auto-Fix Workflow

After presenting the report, offer to clean up findings interactively:

1. Present each finding one at a time (or in small batches by category)
2. For each finding, show: the file/code, why it's flagged, and your confidence level
3. Ask the user to confirm: **Delete**, **Skip**, or **Mark for review**
4. For confirmed deletions:
   - For entire files: delete the file
   - For unused functions/variables: remove the code block
   - For unused imports: remove the import line
   - For unused CSS: remove the rule block
5. After all fixes, run a verification pass to make sure nothing broke (check for new broken references)
6. Present a summary of changes made

## Saving Memory

After every scan, save a memory file:

```markdown
---
name: dead-code-last-scan
description: Last dead code scan results for quick incremental re-scans
type: project
---

**Scan date:** YYYY-MM-DD
**Project:** [name]
**Files scanned:** [count]
**Total findings:** [count]

**Key findings summary:**
- [list top findings with file paths and categories]

**Files confirmed clean:** [list of files verified as actively used]
**Files deleted this session:** [list if any]
**Files skipped (user chose to keep):** [list if any]

**Baseline hash:** [git commit hash at time of scan]
```

Also update the MEMORY.md index with a pointer to this file.

## Tips for Accuracy

- **Start broad, narrow down.** First find candidates, then verify each one before flagging.
- **Check git blame.** If a file hasn't been touched in 6+ months and has no references, it's a stronger candidate for removal.
- **Look at the git log.** If a file was part of a feature that was later reverted or replaced, it's likely dead.
- **Ask about dynamic usage.** Some code is loaded dynamically (lazy imports, plugin systems, reflection). When unsure, ask the user rather than flagging as dead.
- **Test after deletion.** After removing code, verify the project still works (build, tests, or manual check).
