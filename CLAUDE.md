# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is **freewrite-color**, a fork of the freewrite macOS journaling app with AI-powered text highlighting. It's a native SwiftUI app that uses Apple's on-device Foundation Models framework to analyze and color text as you write.

## Build Commands

```bash
# Build the app
xcodebuild -scheme freewrite -configuration Debug build

# Build and run (use Xcode UI for best experience)
# Open freewrite.xcodeproj in Xcode and click Run
```

## System Requirements

- **macOS 26.0+** (Tahoe) - Required for Foundation Models framework
- **Xcode 26** - Required for building
- **Apple Silicon** - Required for on-device AI

## Architecture

### Text Editor Architecture

The app replaces SwiftUI's `TextEditor` (which doesn't support attributed text) with a custom solution:

1. **ColoredTextEditor** (`ColoredTextEditor.swift`)
   - `NSViewRepresentable` wrapper around `NSTextView`
   - Accepts `highlightRanges: [(range: NSRange, color: NSColor)]` binding
   - Applies color attributes to text ranges while preserving editability
   - Handles cursor position preservation during updates
   - Centers text in a 650px column

2. **ContentView** (`ContentView.swift`)
   - Main app view (~1400 lines, single file architecture)
   - Replaces standard `TextEditor` with `ColoredTextEditor`
   - Manages `highlightRanges` state array
   - Triggers highlighting on text changes with debouncing

### AI Highlighting System

The app uses Apple's **Foundation Models framework** for on-device text analysis:

1. **AdjectiveHighlighter** (`AdjectiveHighlighter.swift`)
   - Uses `LanguageModelSession` for AI inference
   - Defines `@Generable` structs (`AdjectiveAnalysis`, `AdjectiveMatch`) for structured output
   - `findAdjectives(in:)` streams responses and returns adjective positions
   - **Critical**: `LanguageModelSession` does NOT allow concurrent requests

2. **Concurrency Management** (in `ContentView.swift`)
   - `highlightingTask: Task<Void, Never>?` - Tracks current task
   - `isHighlighting: Bool` - Prevents concurrent AI calls
   - On text change: cancels previous task, starts new one after 3-second delay
   - Guards prevent concurrent `LanguageModelSession` requests (will error otherwise)

### Data Flow

```
User types → onChange(text) → Cancel previous task → Wait 3s →
Check !isHighlighting → AdjectiveHighlighter.findAdjectives() →
AI returns positions → Convert to NSRange → Update highlightRanges →
ColoredTextEditor applies colors via NSAttributedString
```

## Key Implementation Details

### Why Custom Text Editor?

SwiftUI's `TextEditor` doesn't expose `NSTextStorage`, making attributed text (colors) impossible. `NSViewRepresentable` is the standard SwiftUI pattern for bridging to AppKit when needed.

### Preventing Concurrent AI Requests

Every keystroke triggers `onChange(text)`. Without proper guards, this creates multiple overlapping AI requests. The error looks like:
```
concurrentRequests(FoundationModels.LanguageModelSession.GenerationError.Context...)
```

**Solution**: Task cancellation + `isHighlighting` flag ensures only one AI request runs at a time.

### Text Formatting Preservation

Text must always start with `"\n\n"` (enforced in `ContentView`). The custom editor preserves:
- Font selection (Lato, Arial, System, Serif, Random)
- Font size (16-26px)
- Line spacing
- Light/dark mode colors
- 650px max width centering

### File Storage

Entries are saved as markdown files in `~/Documents/Freewrite/` with pattern:
```
[uuid]-[yyyy-MM-dd-HH-mm-ss].md
```

## Common Patterns

### Adding New Text Analysis Features

1. Create new `@Generable` struct in separate file (like `AdjectiveHighlighter.swift`)
2. Add `LanguageModelSession` with custom instructions
3. Add state to `ContentView`: ranges array, analyzer instance, task tracker, `isAnalyzing` flag
4. Add to `onChange(text)` with task cancellation pattern
5. Pass highlight ranges to `ColoredTextEditor`

### Working with FoundationModels

- Always use `@available(macOS 26.0, *)` annotations
- Use `@Generable` macro for structured output
- Stream responses with `streamResponse(generating:)`
- Access partial data: `partialResponse.content.fieldName`
- Never make concurrent requests to same session

## File Organization

- `freewriteApp.swift` - App entry point, font registration
- `ContentView.swift` - Main UI and business logic (monolithic by design)
- `ColoredTextEditor.swift` - Custom editable text view with color support
- `AdjectiveHighlighter.swift` - AI-powered adjective detection
- `AdjectiveHighlightTestView.swift` - Standalone test view for highlighting
- `TextAnalysisTest.swift` - Original MVP test (kept for reference)
- `default.md` - Welcome message for first-time users
- `fonts/` - Lato font family (registered at app launch)
