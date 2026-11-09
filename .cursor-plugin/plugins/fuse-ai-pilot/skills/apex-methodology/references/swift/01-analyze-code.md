---
name: 01-analyze-code
description: Explore and understand Swift codebase structure
prev_step: references/swift/00-init-branch.md
next_step: references/swift/02-features-plan.md
---

# Swift Code Analysis

## Project Structure Exploration

```bash
# List Swift files
find . -name "*.swift" -type f | head -30

# Find files exceeding FUSE_SOLID_MAX_LINES (default 200)
fuse_solid_max_lines="${FUSE_SOLID_MAX_LINES:-200}"
case "$fuse_solid_max_lines" in ''|*[!0-9]*|0) echo "FUSE_SOLID_MAX_LINES must be a positive integer" >&2; exit 2;; esac
find . -name "*.swift" -exec sh -c 'wc -l "$1"' _ {} \; | awk -v max="$fuse_solid_max_lines" '$1 > max'

# Count lines per file
find . -name "*.swift" -exec wc -l {} + | sort -rn | head -15
```

## Architecture Detection

```bash
# Find ViewModels (MVVM)
find . -name "*ViewModel.swift"

# Find @Observable (modern)
grep -rn "@Observable" --include="*.swift"

# Find ObservableObject (legacy)
grep -rn "ObservableObject" --include="*.swift"

# Find Protocols
grep -rn "^protocol " --include="*.swift"
```

## SPM Analysis

```bash
# Show dependencies
cat Package.swift | grep -A 15 "dependencies:"

# Dependency tree
swift package show-dependencies --format tree

# Resolve dependencies
swift package resolve
```

## Code Quality Check

```bash
# Find force unwraps
grep -rn "!" --include="*.swift" | grep -v "//" | head -15

# Find TODO/FIXME
grep -rn "TODO\|FIXME" --include="*.swift"

# Find hardcoded strings
grep -rn 'Text("' --include="*.swift" | grep -v "LocalizedStringKey"
```

## Xcode Build

```bash
# Clean build
xcodebuild clean -scheme MyApp

# Build with timing
xcodebuild build -scheme MyApp -showBuildTimingSummary

# List schemes
xcodebuild -list -json
```

## SwiftUI vs UIKit

```bash
# Count SwiftUI views
grep -rn "struct.*: View" --include="*.swift" | wc -l

# Count UIKit controllers
grep -rn "class.*: UIViewController" --include="*.swift" | wc -l
```

## Task Phase

Phase: `analyze-code`. Do not create or write `.cursor/apex/task.json`: on Cursor no tool syncs it (the harness task sync is Claude-only). State the phase in your REPORT; tracking lives in the agents' REPORTs and `docs/decisions.md`.

## Next Phase

→ Proceed to `02-features-plan.md`
