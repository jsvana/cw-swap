# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CW Swap is a ham radio classifieds aggregator. The native SwiftUI iOS app scrapes QRZ Forums and QTH.com directly (no backend required), parses listings with SwiftSoup, caches them in SwiftData, and stores QRZ credentials in the iOS Keychain.

The Rust backend in `backend/` is legacy reference code — it is not used at runtime.

## File Discovery Rules

**FORBIDDEN:**
- Scanning all `.swift` files (e.g., `Glob **/*.swift`, `Grep` across entire repo)
- Using Task/Explore agents to "find all files" or "explore the codebase structure"
- Any broad file discovery that reads more than 5 files at once

**REQUIRED:**
- Use the [File Index](docs/FILE_INDEX.md) to locate files by feature/purpose
- Read specific files by path from the index
- When editing files, update the file index if adding/removing/renaming files

## Model Selection

When spawning subagents via the Task tool, select models based on task complexity:

| Task Type | Model | Reasoning |
|-----------|-------|-----------|
| Exploration/search | Haiku | Fast, cheap, good enough for finding files |
| Simple edits | Haiku | Single-file changes, clear instructions |
| Multi-file implementation | Sonnet | Best balance for coding |
| Complex architecture | Opus | Deep reasoning needed |
| Debugging complex bugs | Opus | Needs to hold entire system in mind |
| Writing docs | Haiku | Structure is simple |

**Guidelines:**
- Default to **Sonnet** for 90% of coding tasks
- Upgrade to **Opus** when: first attempt failed, task spans 5+ files, architectural decisions, or security-critical code
- Downgrade to **Haiku** when: task is repetitive, instructions are very clear, or using as a "worker" in multi-agent setup

## Build & Test Commands

### iOS (SwiftUI)
```bash
xcodegen generate      # Regenerate Xcode project from project.yml
xcodebuild -project CWSwap.xcodeproj -scheme CWSwap \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Always run `xcodegen generate` after modifying `project.yml`.

### Backend (Rust — reference only)
```bash
cd backend && cargo check        # Type-check
cd backend && cargo test         # Run tests
```

## Architecture

### iOS App
- **XcodeGen** project generated from `project.yml` — iOS 18+ deployment target, Swift 6, strict concurrency
- **SPM deps**: SwiftSoup (HTML parsing), KeychainAccess (credential storage)
- **Models**: All conform to `Codable`, `Sendable`, `Hashable`. `PersistedListing` is SwiftData `@Model` for offline cache + bookmarks
- **Scrapers**: `QRZScraper` and `QTHScraper` are `final class: Sendable` using URLSession + SwiftSoup. `ScrapingService` coordinates both
- **Auth**: `AuthenticationService` handles QRZ login, `KeychainManager` stores credentials
- **Persistence**: `ListingStore` wraps SwiftData ModelContext for upsert, query, and bookmark operations
- **ViewModels**: `@MainActor @Observable` classes for Swift 6 safety
- **Views**: Tab-based navigation (Browse, Search, Messages, Saved, Settings). Browse has category chips + infinite scroll. Search has filter sheet. Saved shows bookmarked listings from SwiftData
- **Design**: Carrier Wave design language — system blue accent, `systemGray6` card backgrounds, no shadows, solid color status badges

### Data Flow
iOS Views → ViewModels (@Observable) → ScrapingService → QRZScraper/QTHScraper → QRZ Forums / QTH.com
                                     → ListingStore → SwiftData (PersistedListing)

### Backend (`backend/`) — reference only
- **axum** web server with REST API at `/api/v1/`
- **Scraper** (`scraper/qrz.rs`): original QRZ scraper implementation in Rust
- The Swift scrapers were ported from this code

## Key Conventions

### Swift 6 Concurrency
- `SWIFT_STRICT_CONCURRENCY: complete` is enabled
- ViewModels must be `@MainActor @Observable`
- Scrapers and services are `Sendable` (final classes or structs)
- All model types conform to `Sendable`
- KeychainAccess `Keychain` is `nonisolated(unsafe)` in the `Sendable` wrapper

### SwiftUI Tab Naming
SwiftUI's `Tab` type conflicts with a local enum. The codebase uses `AppTab` enum and `SwiftUI.Tab` for the framework type.

### Xcode 26 Simulators
Available simulators: iPhone 17 Pro, iPhone Air, iPad (no iPhone 16 series).

### Image URLs
Images are loaded directly from source URLs (QRZ, QTH) — no proxying needed since there's no backend.

## Investigation Traces (REQUIRED)

**When debugging or investigating any non-trivial issue, create a markdown artifact to document the investigation.**

**Location:** `docs/investigations/YYYY-MM-DD-<short-description>.md`

**When to create:**
- Debugging a bug that requires exploring multiple files or hypotheses
- Investigating user-reported issues
- Diagnosing build failures, crashes, or unexpected behavior
- Any investigation taking more than a few minutes

**Format:**

```markdown
# Investigation: <Short Description>

**Date:** YYYY-MM-DD
**Status:** In Progress | Resolved | Blocked | Abandoned
**Outcome:** <One-line summary of resolution, if resolved>

## Problem Statement
## Hypotheses
## Investigation Log
## Files Examined
## Root Cause
## Resolution
## Lessons Learned
```

**Guidelines:**
- Create the file at the START of the investigation, not the end
- Update incrementally as you discover new information
- Document dead ends too — they prevent re-investigating the same paths
- Mark the status as **Resolved** and add **Outcome** when done

## Issue Tracking

Use **Linear** (via the `linear-cli` skill) for issue tracking. Do NOT use beads.

## Git Workflow

**Do NOT use git worktrees.** All work should be done on the main branch or feature branches in the primary working directory.

## Reference Files
- `ham-classifieds-design.md` — Original architecture design document
- `qrz_sources/` — Sample HTML from QRZ forums used for scraper development
- `hamswap-prototype.jsx` — React prototype (reference only, not active code)
