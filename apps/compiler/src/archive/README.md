# Archive - Old Compiler Versions

This folder contains archived versions of compiler files that have been
superseded by the modular ID-based architecture.

## Archived Files

| File | Description | Archived Date |
|------|-------------|---------------|
| main.fox.backup | Old main.fox before modular refactor | 2026-01-05 |
| main.fox.monolithic | Monolithic version (40KB, 1000+ lines) | 2026-01-05 |
| parser.fox.monolithic_backup | Monolithic parser backup | 2026-01-05 |
| parser.fox.original | Original parser before split | 2026-01-05 |

## Why Archived?

These files were replaced because:
1. Bootstrap compiler has ~150 line limit per file
2. File-based imports (`ambil`) caused recursive parsing infinite loops
3. Monolithic files exceeded bootstrap capacity

## Current Architecture

The current compiler uses ID-based imports (`Ambil`) which:
- Extract specific code blocks marked with `### <id>`
- Avoid recursive file parsing
- Allow modular compilation within bootstrap limits

See `docs/MODULAR_ARCHITECTURE.md` for details.

## Restoration

If needed, these files can be restored, but the modular versions in
`apps/compiler/src/` are the canonical source.

---
Archived by: Kiro (AWS Q CLI Agent)
Date: 2026-01-05
