# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is **Writers Lens**, a macOS writing analysis app with real-time text highlighting. It's a native SwiftUI app that uses Apple's Natural Language framework to analyze and highlight writing patterns.

Forked from the original Freewrite app by Farza (github.com/farzaa/freewrite).

## Build Commands

```bash
# Build the app
xcodebuild -scheme WritersLens -configuration Debug build

# Build and run (use Xcode UI for best experience)
# Open WritersLens.xcodeproj in Xcode and click Run
```

## System Requirements

- **macOS 13.0+** (Ventura) - Required for SwiftUI and Natural Language framework
- **Xcode 15+** - Required for building
- **Apple Silicon or Intel** - Universal app support

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

### Writing Analysis System

The app uses a **lens-based architecture** for real-time text analysis:

1. **LensEngine** (`LensEngine.swift`)
   - Manages multiple writing analysis lenses
   - Available lenses: Parts of Speech, Adverb Overuse, Passive Voice, Filler Words, Sentence Length, Word Repetition, Rhythm
   - Each lens implements the `WritingLens` protocol
   - Uses Natural Language framework for tokenization and linguistic analysis

2. **Concurrency Management** (in `ContentView.swift`)
   - `analysisTask: Task<Void, Never>?` - Tracks current analysis task
   - `isAnalyzing: Bool` - Prevents concurrent analysis runs
   - On text change: cancels previous task, starts new one with debouncing
   - Lens selection: user can select one lens at a time via sidebar UI

### Data Flow

```
User types → onChange(text) → Cancel previous task → Debounce →
Check !isAnalyzing → LensEngine.analyze() →
Lens returns highlights → Convert to NSRange → Update highlightRanges →
ColoredTextEditor applies colors via NSAttributedString
```

## Key Implementation Details

### Why Custom Text Editor?

SwiftUI's `TextEditor` doesn't expose `NSTextStorage`, making attributed text (colors) impossible. `NSViewRepresentable` is the standard SwiftUI pattern for bridging to AppKit when needed.

### Text Formatting Preservation

Text must always start with `"\n\n"` (enforced in `ContentView`). The custom editor preserves:
- Font selection (Lato, Arial, System, Serif, Random)
- Font size (16-26px)
- Line spacing
- Light/dark mode colors
- 650px max width centering

### File Storage

Entries are saved as markdown files in `~/Documents/WritersLens/` with pattern:
```
[uuid]-[yyyy-MM-dd-HH-mm-ss].md
```

## Common Patterns

### Adding New Lenses

1. Create a new struct that implements the `WritingLens` protocol in `LensEngine.swift`
2. Implement the `analyze(document:colorScheme:)` method using Natural Language framework
3. Add the lens to `availableLenses` array in `LensEngine`
4. Use tokenization and NLTagger for linguistic analysis
5. Return `[Highlight]` array with ranges, colors, and categories

## File Organization

The project follows Swift best practices with organized folders:

```
WritersLens/
├── App/
│   ├── WritersLensApp.swift - App entry point, font registration, menu commands
│   └── ContentView.swift - Main UI and business logic (monolithic by design)
├── Views/
│   └── ColoredTextEditor.swift - Custom editable text view with color support
├── Lenses/
│   └── LensEngine.swift - Writing analysis lens system and implementations
├── Resources/
│   ├── FlexokiColors.swift - Color palette for lens highlighting
│   ├── default.md - Welcome/demo message for first-time users
│   └── fonts/ - Lato font family (registered at app launch)
├── Legacy/
│   ├── AdjectiveHighlighter.swift - Legacy AI-powered adjective detection
│   ├── AdjectiveHighlightTestView.swift - Standalone test view
│   └── TextAnalysisTest.swift - Original MVP test
├── Assets.xcassets - App icons and assets
├── Preview Content/ - SwiftUI preview assets
└── WritersLens.entitlements - App capabilities
```

Note: The project uses Xcode's file system synchronization (objectVersion 77), so folders are automatically detected without manual .pbxproj updates.
