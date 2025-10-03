// Swift 5.0
//
//  ContentView.swift
//  Writers Lens
//
//  Created by thorfinn on 2/14/25.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import PDFKit
import NaturalLanguage

struct HumanEntry: Identifiable {
    let id: UUID
    let date: String
    let filename: String
    var previewText: String

    static func createNew() -> HumanEntry {
        let id = UUID()
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let dateString = dateFormatter.string(from: now)

        // For display
        dateFormatter.dateFormat = "MMM d"
        let displayDate = dateFormatter.string(from: now)

        return HumanEntry(
            id: id,
            date: displayDate,
            filename: "[\(id)]-[\(dateString)].md",
            previewText: ""
        )
    }
}

struct DocumentMetadata: Codable {
    let sentenceCaches: [String: [String: [RelativeHighlight]]]  // [lensId: [sentence: highlights]]
    let lensVersion: Int

    static let currentVersion = 2  // Bumped to 2 for multi-lens support
}

struct HeartEmoji: Identifiable {
    let id = UUID()
    var position: CGPoint
    var offset: CGFloat = 0
}

struct ContentView: View {
    private let headerString = "\n\n"
    @State private var entries: [HumanEntry] = []
    @State private var text: String = ""  // Remove initial welcome text since we'll handle it in createNewEntry

    @State private var isFullscreen = false
    @State private var selectedFont: String = "Lato-Regular"
    @State private var currentRandomFont: String = ""
    @State private var timeRemaining: Int = 900  // Changed to 900 seconds (15 minutes)
    @State private var timerIsRunning = false
    @State private var isHoveringTimer = false
    @State private var isHoveringFullscreen = false
    @State private var hoveredFont: String? = nil
    @State private var isHoveringSize = false
    @State private var fontSize: CGFloat = 18
    @State private var blinkCount = 0
    @State private var isBlinking = false
    @State private var opacity: Double = 1.0
    @State private var shouldShowGray = true // New state to control color
    @State private var lastClickTime: Date? = nil
    @State private var bottomNavOpacity: Double = 1.0
    @State private var isHoveringBottomNav = false
    @State private var selectedEntryIndex: Int = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var selectedEntryId: UUID? = nil
    @State private var hoveredEntryId: UUID? = nil
    @State private var isHoveringChat = false  // Add this state variable
    @State private var showingChatMenu = false
    @State private var chatMenuAnchor: CGPoint = .zero
    @State private var showingSidebar = false  // Add this state variable
    @State private var hoveredTrashId: UUID? = nil
    @State private var hoveredExportId: UUID? = nil
    @State private var placeholderText: String = ""  // Add this line
    @State private var isHoveringNewEntry = false
    @State private var isHoveringClock = false
    @State private var isHoveringHistory = false
    @State private var isHoveringHistoryText = false
    @State private var isHoveringHistoryPath = false
    @State private var isHoveringHistoryArrow = false
    @State private var colorScheme: ColorScheme = .light // Add state for color scheme
    @State private var isHoveringThemeToggle = false // Add state for theme toggle hover
    @State private var isHoveringLensMenu = false // Add state for lens menu hover
    @State private var didCopyPrompt: Bool = false // Add state for copy prompt feedback

    // Lens engine state
    @State private var lensEngine = LensEngine()
    @State private var selectedLensId: String? = nil // Single lens selection, nil = no lens
    @State private var highlightRanges: [(range: NSRange, color: NSColor)] = []
    @State private var fastAnalysisTask: Task<Void, Never>?
    @State private var aiAnalysisTask: Task<Void, Never>?
    @State private var showingLensSidebar = false // Left sidebar for lens selection

    // Sentence-based caching state (NEW ARCHITECTURE)
    // Per-lens caches: [lensId: [sentence: highlights]]
    @State private var sentenceCaches: [String: [String: [RelativeHighlight]]] = [:]
    @State private var editDebounceTask: Task<Void, Never>?
    @State private var analysisQueue = SentenceAnalysisQueue()

    // DEPRECATED: Will be removed after migration
    @State private var lastAnalyzedText: String = ""
    @State private var accumulatedAIHighlights: [Highlight] = []

    // Legacy adjective highlighting (keep for AI lens migration)
    @State private var adjectiveHighlighter: Any?
    @State private var isHighlighting = false

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    let entryHeight: CGFloat = 40
    
    let availableFonts = NSFontManager.shared.availableFontFamilies
    let standardFonts = ["Lato-Regular", "Arial", ".AppleSystemUIFont", "Times New Roman"]
    let fontSizes: [CGFloat] = [16, 18, 20, 22, 24, 26]
    let placeholderOptions = [
        "Begin writing",
        "Pick a thought and go",
        "Start typing",
        "What's on your mind",
        "Just start",
        "Type your first thought",
        "Start with one sentence",
        "Just say it"
    ]
    
    // Add file manager and save timer
    private let fileManager = FileManager.default
    private let saveTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    // Add cached documents directory
    private let documentsDirectory: URL = {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("WritersLens")

        // Create WritersLens directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: directory.path) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                print("Successfully created WritersLens directory")
            } catch {
                print("Error creating directory: \(error)")
            }
        }
        
        return directory
    }()
    
    // Add shared prompt constant
    private let aiChatPrompt = """
    below is my journal entry. wyt? talk through it with me like a friend. don't therpaize me and give me a whole breakdown, don't repeat my thoughts with headings. really take all of this, and tell me back stuff truly as if you're an old homie.
    
    Keep it casual, dont say yo, help me make new connections i don't see, comfort, validate, challenge, all of it. dont be afraid to say a lot. format with markdown headings if needed.

    do not just go through every single thing i say, and say it back to me. you need to proccess everythikng is say, make connections i don't see it, and deliver it all back to me as a story that makes me feel what you think i wanna feel. thats what the best therapists do.

    ideally, you're style/tone should sound like the user themselves. it's as if the user is hearing their own tone but it should still feel different, because you have different things to say and don't just repeat back they say.

    else, start by saying, "hey, thanks for showing me this. my thoughts:"
        
    my entry:
    """
    
    private let claudePrompt = """
    Take a look at my journal entry below. I'd like you to analyze it and respond with deep insight that feels personal, not clinical.
    Imagine you're not just a friend, but a mentor who truly gets both my tech background and my psychological patterns. I want you to uncover the deeper meaning and emotional undercurrents behind my scattered thoughts.
    Keep it casual, dont say yo, help me make new connections i don't see, comfort, validate, challenge, all of it. dont be afraid to say a lot. format with markdown headings if needed.
    Use vivid metaphors and powerful imagery to help me see what I'm really building. Organize your thoughts with meaningful headings that create a narrative journey through my ideas.
    Don't just validate my thoughts - reframe them in a way that shows me what I'm really seeking beneath the surface. Go beyond the product concepts to the emotional core of what I'm trying to solve.
    Be willing to be profound and philosophical without sounding like you're giving therapy. I want someone who can see the patterns I can't see myself and articulate them in a way that feels like an epiphany.
    Start with 'hey, thanks for showing me this. my thoughts:' and then use markdown headings to structure your response.

    Here's my journal entry:
    """
    
    // Initialize with saved theme preference if available
    init() {
        // Load saved color scheme preference
        let savedScheme = UserDefaults.standard.string(forKey: "colorScheme") ?? "light"
        _colorScheme = State(initialValue: savedScheme == "dark" ? .dark : .light)
    }
    
    // Modify getDocumentsDirectory to use cached value
    private func getDocumentsDirectory() -> URL {
        return documentsDirectory
    }
    
    // Add function to save text
    private func saveText() {
        let documentsDirectory = getDocumentsDirectory()
        let fileURL = documentsDirectory.appendingPathComponent("entry.md")
        
        print("Attempting to save file to: \(fileURL.path)")
        
        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            print("Successfully saved file")
        } catch {
            print("Error saving file: \(error)")
            print("Error details: \(error.localizedDescription)")
        }
    }
    
    // Add function to load text
    private func loadText() {
        let documentsDirectory = getDocumentsDirectory()
        let fileURL = documentsDirectory.appendingPathComponent("entry.md")
        
        print("Attempting to load file from: \(fileURL.path)")
        
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                text = try String(contentsOf: fileURL, encoding: .utf8)
                print("Successfully loaded file")
            } else {
                print("File does not exist yet")
            }
        } catch {
            print("Error loading file: \(error)")
            print("Error details: \(error.localizedDescription)")
        }
    }
    
    // Add function to load existing entries
    private func loadExistingEntries() {
        let documentsDirectory = getDocumentsDirectory()
        print("Looking for entries in: \(documentsDirectory.path)")
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            let mdFiles = fileURLs.filter { $0.pathExtension == "md" }
            
            print("Found \(mdFiles.count) .md files")
            
            // Process each file
            let entriesWithDates = mdFiles.compactMap { fileURL -> (entry: HumanEntry, date: Date, content: String)? in
                let filename = fileURL.lastPathComponent
                print("Processing: \(filename)")
                
                // Extract UUID and date from filename - pattern [uuid]-[yyyy-MM-dd-HH-mm-ss].md
                guard let uuidMatch = filename.range(of: "\\[(.*?)\\]", options: .regularExpression),
                      let dateMatch = filename.range(of: "\\[(\\d{4}-\\d{2}-\\d{2}-\\d{2}-\\d{2}-\\d{2})\\]", options: .regularExpression),
                      let uuid = UUID(uuidString: String(filename[uuidMatch].dropFirst().dropLast())) else {
                    print("Failed to extract UUID or date from filename: \(filename)")
                    return nil
                }
                
                // Parse the date string
                let dateString = String(filename[dateMatch].dropFirst().dropLast())
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
                
                guard let fileDate = dateFormatter.date(from: dateString) else {
                    print("Failed to parse date from filename: \(filename)")
                    return nil
                }
                
                // Read file contents for preview
                do {
                    let content = try String(contentsOf: fileURL, encoding: .utf8)
                    let preview = content
                        .replacingOccurrences(of: "\n", with: " ")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let truncated = preview.isEmpty ? "" : (preview.count > 30 ? String(preview.prefix(30)) + "..." : preview)
                    
                    // Format display date
                    dateFormatter.dateFormat = "MMM d"
                    let displayDate = dateFormatter.string(from: fileDate)
                    
                    return (
                        entry: HumanEntry(
                            id: uuid,
                            date: displayDate,
                            filename: filename,
                            previewText: truncated
                        ),
                        date: fileDate,
                        content: content  // Store the full content to check for welcome message
                    )
                } catch {
                    print("Error reading file: \(error)")
                    return nil
                }
            }
            
            // Sort and extract entries
            entries = entriesWithDates
                .sorted { $0.date > $1.date }  // Sort by actual date from filename
                .map { $0.entry }
            
            print("Successfully loaded and sorted \(entries.count) entries")
            
            // Check if we need to create a new entry
            let calendar = Calendar.current
            let today = Date()
            let todayStart = calendar.startOfDay(for: today)
            
            // Check if there's an empty entry from today
            let hasEmptyEntryToday = entries.contains { entry in
                // Convert the display date (e.g. "Mar 14") to a Date object
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMM d"
                if let entryDate = dateFormatter.date(from: entry.date) {
                    // Set year component to current year since our stored dates don't include year
                    var components = calendar.dateComponents([.year, .month, .day], from: entryDate)
                    components.year = calendar.component(.year, from: today)
                    
                    // Get start of day for the entry date
                    if let entryDateWithYear = calendar.date(from: components) {
                        let entryDayStart = calendar.startOfDay(for: entryDateWithYear)
                        return calendar.isDate(entryDayStart, inSameDayAs: todayStart) && entry.previewText.isEmpty
                    }
                }
                return false
            }
            
            // Check if we have only one entry and it's the welcome message
            let hasOnlyWelcomeEntry = entries.count == 1 && entriesWithDates.first?.content.contains("Welcome to Writers Lens") == true
            
            if entries.isEmpty {
                // First time user - create entry with welcome message
                print("First time user, creating welcome entry")
                createNewEntry()
            } else if !hasEmptyEntryToday && !hasOnlyWelcomeEntry {
                // No empty entry for today and not just the welcome entry - create new entry
                print("No empty entry for today, creating new entry")
                createNewEntry()
            } else {
                // Select the most recent empty entry from today or the welcome entry
                if let todayEntry = entries.first(where: { entry in
                    // Convert the display date (e.g. "Mar 14") to a Date object
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "MMM d"
                    if let entryDate = dateFormatter.date(from: entry.date) {
                        // Set year component to current year since our stored dates don't include year
                        var components = calendar.dateComponents([.year, .month, .day], from: entryDate)
                        components.year = calendar.component(.year, from: today)
                        
                        // Get start of day for the entry date
                        if let entryDateWithYear = calendar.date(from: components) {
                            let entryDayStart = calendar.startOfDay(for: entryDateWithYear)
                            return calendar.isDate(entryDayStart, inSameDayAs: todayStart) && entry.previewText.isEmpty
                        }
                    }
                    return false
                }) {
                    selectedEntryId = todayEntry.id
                    loadEntry(entry: todayEntry)
                } else if hasOnlyWelcomeEntry {
                    // If we only have the welcome entry, select it
                    selectedEntryId = entries[0].id
                    loadEntry(entry: entries[0])
                }
            }
            
        } catch {
            print("Error loading directory contents: \(error)")
            print("Creating default entry after error")
            createNewEntry()
        }
    }
    
    var randomButtonTitle: String {
        return currentRandomFont.isEmpty ? "Random" : "Random [\(currentRandomFont)]"
    }
    
    var timerButtonTitle: String {
        if !timerIsRunning && timeRemaining == 900 {
            return "15:00"
        }
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var timerColor: Color {
        if timerIsRunning {
            return isHoveringTimer ? (colorScheme == .light ? .black : .white) : .gray.opacity(0.8)
        } else {
            return isHoveringTimer ? (colorScheme == .light ? .black : .white) : (colorScheme == .light ? .gray : .gray.opacity(0.8))
        }
    }
    
    var lineHeight: CGFloat {
        let font = NSFont(name: selectedFont, size: fontSize) ?? .systemFont(ofSize: fontSize)
        let defaultLineHeight = getLineHeight(font: font)
        return (fontSize * 1.5) - defaultLineHeight
    }
    
    var fontSizeButtonTitle: String {
        return "\(Int(fontSize))px"
    }
    
    var placeholderOffset: CGFloat {
        // Offset to position after the leading "\n\n"
        // Each line is approximately fontSize * 1.5 tall
        return fontSize * 1.5 * 2
    }
    
    // Add a color utility computed property
    var popoverBackgroundColor: Color {
        return FlexokiColors.bg2(for: colorScheme)
    }

    var popoverTextColor: Color {
        return FlexokiColors.tx(for: colorScheme)
    }
    
    @State private var viewHeight: CGFloat = 0
    
    var body: some View {
        let navHeight: CGFloat = 68
        let textColor = FlexokiColors.tx2(for: colorScheme)
        let textHoverColor = FlexokiColors.tx(for: colorScheme)
        
        HStack(spacing: 0) {
            // Left sidebar - Lens selector
            if showingLensSidebar {
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Lenses")
                                .font(.system(size: 13))
                                .foregroundColor(textColor)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    Divider()

                    // Lens list
                    ScrollView {
                        VStack(spacing: 0) {
                            // "No Lens" option
                            Button(action: {
                                selectedLensId = nil
                                highlightRanges = []
                                lastAnalyzedText = ""
                                accumulatedAIHighlights = []
                            }) {
                                HStack(alignment: .top, spacing: 12) {
                                    // Radio button
                                    Image(systemName: selectedLensId == nil ? "circle.fill" : "circle")
                                        .font(.system(size: 12))
                                        .foregroundColor(selectedLensId == nil ? FlexokiColors.blue(for: colorScheme) : .secondary)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("No Lens")
                                            .font(.system(size: 13))
                                            .foregroundColor(.primary)
                                        Text("Clear all highlighting")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }

                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(selectedLensId == nil ? FlexokiColors.ui(for: colorScheme) : Color.clear)
                            }
                            .buttonStyle(.plain)

                            Divider()

                            // Lenses grouped by category
                            ForEach(["Grammar", "Style", "Clarity", "Readability", "AI Analysis"], id: \.self) { category in
                                let categoryLenses = lensEngine.availableLenses.filter { $0.category == category }
                                if !categoryLenses.isEmpty {
                                    // Category header
                                    HStack {
                                        Text(category)
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                            .textCase(.uppercase)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.top, 12)
                                    .padding(.bottom, 6)

                                    // Lenses in this category
                                    ForEach(categoryLenses, id: \.id) { lens in
                                        Button(action: {
                                            selectedLensId = lens.id

                                            // Cancel pending tasks
                                            analysisQueue.clear()
                                            editDebounceTask?.cancel()

                                            print("🔄 Switched to lens: \(lens.name)")

                                            if lens.requiresAI {
                                                // AI lens: check cache first, then queue missing sentences
                                                if !text.isEmpty {
                                                    let sentences = extractAllSentences(from: text)

                                                    // Initialize cache for this lens if needed
                                                    if sentenceCaches[lens.id] == nil {
                                                        sentenceCaches[lens.id] = [:]
                                                    }

                                                    // Rebuild from existing cache first
                                                    rebuildHighlightsFromCache(sentences: sentences, lensId: lens.id)

                                                    // Queue only uncached COMPLETE sentences
                                                    var uncachedCount = 0
                                                    for sentence in sentences {
                                                        // Only queue complete sentences
                                                        guard sentence.isComplete else { continue }

                                                        if sentenceCaches[lens.id]?[sentence.text] == nil {
                                                            analysisQueue.enqueue(
                                                                sentence: sentence.text,
                                                                range: sentence.range,
                                                                lensId: lens.id,
                                                                priority: 1
                                                            )
                                                            uncachedCount += 1
                                                        }
                                                    }

                                                    if uncachedCount > 0 {
                                                        print("📋 Queued \(uncachedCount)/\(sentences.count) sentences for analysis")
                                                    } else {
                                                        print("✅ All sentences cached, instant display!")
                                                    }
                                                }
                                            } else {
                                                // Fast lens: analyze immediately
                                                fastAnalysisTask?.cancel()
                                                fastAnalysisTask = Task { @MainActor in
                                                    let highlights = await lensEngine.analyze(
                                                        text: text,
                                                        enabledLensIds: [lens.id],
                                                        colorScheme: colorScheme
                                                    )
                                                    highlightRanges = highlights.map { ($0.range, $0.color) }
                                                }
                                            }
                                        }) {
                                            HStack(alignment: .top, spacing: 12) {
                                                // Radio button
                                                Image(systemName: selectedLensId == lens.id ? "circle.fill" : "circle")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(selectedLensId == lens.id ? FlexokiColors.blue(for: colorScheme) : .secondary)

                                                VStack(alignment: .leading, spacing: 4) {
                                                    HStack {
                                                        Text(lens.name)
                                                            .font(.system(size: 13))
                                                            .foregroundColor(.primary)
                                                        if lens.requiresAI {
                                                            Image(systemName: "sparkles")
                                                                .font(.system(size: 10))
                                                                .foregroundColor(.secondary)
                                                        }
                                                    }
                                                    Text(lens.description)
                                                        .font(.system(size: 11))
                                                        .foregroundColor(.secondary)
                                                        .fixedSize(horizontal: false, vertical: true)
                                                }

                                                Spacer()
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                            .background(selectedLensId == lens.id ? FlexokiColors.ui(for: colorScheme) : Color.clear)
                                        }
                                        .buttonStyle(.plain)

                                        if lens.id != categoryLenses.last?.id {
                                            Divider()
                                                .padding(.leading, 16)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .scrollIndicators(.never)
                }
                .frame(width: 280)
                .background(FlexokiColors.bg(for: colorScheme))

                Divider()
            }

            // Main content
            ZStack {
                FlexokiColors.bg(for: colorScheme)
                    .ignoresSafeArea()


                ColoredTextEditor(
                    text: Binding(
                        get: { text },
                        set: { newValue in
                            // Ensure the text always starts with two newlines
                            if !newValue.hasPrefix("\n\n") {
                                text = "\n\n" + newValue.trimmingCharacters(in: .newlines)
                            } else {
                                text = newValue
                            }
                        }
                    ),
                    highlightRanges: $highlightRanges,
                    font: NSFont(name: selectedFont, size: fontSize) ?? .systemFont(ofSize: fontSize),
                    textColor: FlexokiColors.NS.tx(for: colorScheme),
                    backgroundColor: FlexokiColors.NS.bg(for: colorScheme),
                    lineSpacing: lineHeight,
                    maxWidth: 650
                )
                .id("\(selectedFont)-\(fontSize)-\(colorScheme)")
                .padding(.bottom, bottomNavOpacity > 0 ? navHeight : 0)
                .ignoresSafeArea()
                .colorScheme(colorScheme)
                    .onGeometryChange(for: CGFloat.self) { proxy in
                                    proxy.size.height
                                } action: { height in
                                    viewHeight = height
                                }
                                .contentMargins(.bottom, viewHeight / 4)
                    
                
                VStack {
                    Spacer()
                    HStack {
                        // Lens selector (left side)
                        HStack(spacing: 8) {
                            // Glasses icon - opens sidebar
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showingLensSidebar.toggle()
                                }
                            }) {
                                Image(systemName: "eyeglasses")
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(isHoveringLensMenu ? textHoverColor : textColor)
                            .onHover { hovering in
                                isHoveringLensMenu = hovering
                                isHoveringBottomNav = hovering
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }

                            // Current lens name - opens sidebar (only show if lens is selected and panel is closed)
                            if let lensId = selectedLensId, !showingLensSidebar {
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showingLensSidebar.toggle()
                                    }
                                }) {
                                    Text(lensEngine.availableLenses.first(where: { $0.id == lensId })?.name ?? "")
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(textColor)
                                .onHover { hovering in
                                    isHoveringBottomNav = hovering
                                    if hovering {
                                        NSCursor.pointingHand.push()
                                    } else {
                                        NSCursor.pop()
                                    }
                                }
                            }

                            // Cycle arrow - cycles to next lens (hide when panel is open)
                            if !showingLensSidebar {
                                Button(action: {
                                    cycleLens()
                                }) {
                                    Image(systemName: "chevron.right")
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(textColor)
                                .onHover { hovering in
                                    isHoveringBottomNav = hovering
                                    if hovering {
                                        NSCursor.pointingHand.push()
                                    } else {
                                        NSCursor.pop()
                                    }
                                }
                            }
                        }
                        .padding(8)
                        .cornerRadius(6)
                        .onHover { hovering in
                            isHoveringBottomNav = hovering
                        }
                        
                        Spacer()
                        
                        // Utility buttons (moved to right)
                        HStack(spacing: 8) {
                            Button(timerButtonTitle) {
                                let now = Date()
                                if let lastClick = lastClickTime,
                                   now.timeIntervalSince(lastClick) < 0.3 {
                                    timeRemaining = 900
                                    timerIsRunning = false
                                    lastClickTime = nil
                                } else {
                                    timerIsRunning.toggle()
                                    lastClickTime = now
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(timerColor)
                            .onHover { hovering in
                                isHoveringTimer = hovering
                                isHoveringBottomNav = hovering
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                            .onAppear {
                                NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                                    if isHoveringTimer {
                                        let scrollBuffer = event.deltaY * 0.25
                                        
                                        if abs(scrollBuffer) >= 0.1 {
                                            let currentMinutes = timeRemaining / 60
                                            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                                            let direction = -scrollBuffer > 0 ? 5 : -5
                                            let newMinutes = currentMinutes + direction
                                            let roundedMinutes = (newMinutes / 5) * 5
                                            let newTime = roundedMinutes * 60
                                            timeRemaining = min(max(newTime, 0), 2700)
                                        }
                                    }
                                    return event
                                }
                            }
                            
                            Text("•")
                                .foregroundColor(.gray)
                            
                            Button("Chat") {
                                showingChatMenu = true
                                // Ensure didCopyPrompt is reset when opening the menu
                                didCopyPrompt = false
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(isHoveringChat ? textHoverColor : textColor)
                            .onHover { hovering in
                                isHoveringChat = hovering
                                isHoveringBottomNav = hovering
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                            .popover(isPresented: $showingChatMenu, attachmentAnchor: .point(UnitPoint(x: 0.5, y: 0)), arrowEdge: .top) {
                                VStack(spacing: 0) { // Wrap everything in a VStack for consistent styling and onChange
                                    let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                                    
                                    // Calculate potential URL lengths
                                    let gptFullText = aiChatPrompt + "\n\n" + trimmedText
                                    let claudeFullText = claudePrompt + "\n\n" + trimmedText
                                    let encodedGptText = gptFullText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                                    let encodedClaudeText = claudeFullText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                                    
                                    let gptUrlLength = "https://chat.openai.com/?m=".count + encodedGptText.count
                                    let claudeUrlLength = "https://claude.ai/new?q=".count + encodedClaudeText.count
                                    let isUrlTooLong = gptUrlLength > 6000 || claudeUrlLength > 6000
                                    
                                    if isUrlTooLong {
                                        // View for long text (URL too long)
                                        Text("Hey, your entry is long. It'll break the URL. Instead, copy prompt by clicking below and paste into AI of your choice!")
                                            .font(.system(size: 14))
                                            .foregroundColor(popoverTextColor)
                                            .lineLimit(nil)
                                            .multilineTextAlignment(.leading)
                                            .frame(width: 200, alignment: .leading)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                        
                                        Divider()
                                        
                                        Button(action: {
                                            copyPromptToClipboard()
                                            didCopyPrompt = true
                                        }) {
                                            Text(didCopyPrompt ? "Copied!" : "Copy Prompt")
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundColor(popoverTextColor)
                                        .onHover { hovering in
                                            if hovering {
                                                NSCursor.pointingHand.push()
                                            } else {
                                                NSCursor.pop()
                                            }
                                        }
                                        
                                    } else if text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("hi. my name is farza.") {
                                        Text("Yo. Sorry, you can't chat with the guide lol. Please write your own entry.")
                                            .font(.system(size: 14))
                                            .foregroundColor(popoverTextColor)
                                            .frame(width: 250)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                    } else if text.count < 350 {
                                        Text("Please free write for at minimum 5 minutes first. Then click this. Trust.")
                                            .font(.system(size: 14))
                                            .foregroundColor(popoverTextColor)
                                            .frame(width: 250)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                    } else {
                                        // View for normal text length
                                        Button(action: {
                                            showingChatMenu = false
                                            openChatGPT()
                                        }) {
                                            Text("ChatGPT")
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundColor(popoverTextColor)
                                        .onHover { hovering in
                                            if hovering {
                                                NSCursor.pointingHand.push()
                                            } else {
                                                NSCursor.pop()
                                            }
                                        }
                                        
                                        Divider()
                                        
                                        Button(action: {
                                            showingChatMenu = false
                                            openClaude()
                                        }) {
                                            Text("Claude")
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundColor(popoverTextColor)
                                        .onHover { hovering in
                                            if hovering {
                                                NSCursor.pointingHand.push()
                                            } else {
                                                NSCursor.pop()
                                            }
                                        }
                                        
                                        Divider()
                                        
                                        Button(action: {
                                            // Don't dismiss menu, just copy and update state
                                            copyPromptToClipboard()
                                            didCopyPrompt = true
                                        }) {
                                            Text(didCopyPrompt ? "Copied!" : "Copy Prompt")
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundColor(popoverTextColor)
                                        .onHover { hovering in
                                            if hovering {
                                                NSCursor.pointingHand.push()
                                            } else {
                                                NSCursor.pop()
                                            }
                                        }
                                    }
                                }
                                .frame(minWidth: 120, maxWidth: 250) // Allow width to adjust
                                .background(popoverBackgroundColor)
                                .cornerRadius(8)
                                .shadow(color: FlexokiColors.black.opacity(0.1), radius: 4, y: 2)
                                // Reset copied state when popover dismisses
                                .onChange(of: showingChatMenu) { _, newValue in
                                    if !newValue {
                                        didCopyPrompt = false
                                    }
                                }
                            }
                            
                            Text("•")
                                .foregroundColor(.gray)
                            
                            Button(isFullscreen ? "Minimize" : "Fullscreen") {
                                if let window = NSApplication.shared.windows.first {
                                    window.toggleFullScreen(nil)
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(isHoveringFullscreen ? textHoverColor : textColor)
                            .onHover { hovering in
                                isHoveringFullscreen = hovering
                                isHoveringBottomNav = hovering
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                            
                            Text("•")
                                .foregroundColor(.gray)
                            
                            Button(action: {
                                createNewEntry()
                            }) {
                                Text("New Entry")
                                    .font(.system(size: 13))
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(isHoveringNewEntry ? textHoverColor : textColor)
                            .onHover { hovering in
                                isHoveringNewEntry = hovering
                                isHoveringBottomNav = hovering
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                            
                            Text("•")
                                .foregroundColor(.gray)

                            // Theme toggle button
                            Button(action: {
                                colorScheme = colorScheme == .light ? .dark : .light
                                // Save preference
                                UserDefaults.standard.set(colorScheme == .light ? "light" : "dark", forKey: "colorScheme")
                            }) {
                                Image(systemName: colorScheme == .light ? "moon.fill" : "sun.max.fill")
                                    .foregroundColor(isHoveringThemeToggle ? textHoverColor : textColor)
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in
                                isHoveringThemeToggle = hovering
                                isHoveringBottomNav = hovering
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }

                            Text("•")
                                .foregroundColor(.gray)
                            
                            // Version history button
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showingSidebar.toggle()
                                }
                            }) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(isHoveringClock ? textHoverColor : textColor)
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in
                                isHoveringClock = hovering
                                isHoveringBottomNav = hovering
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                        }
                        .padding(8)
                        .cornerRadius(6)
                        .onHover { hovering in
                            isHoveringBottomNav = hovering
                        }
                    }
                    .padding()
                    .background(FlexokiColors.bg(for: colorScheme))
                    .opacity(bottomNavOpacity)
                    .onHover { hovering in
                        isHoveringBottomNav = hovering
                        if hovering {
                            withAnimation(.easeOut(duration: 0.2)) {
                                bottomNavOpacity = 1.0
                            }
                        } else if timerIsRunning {
                            withAnimation(.easeIn(duration: 1.0)) {
                                bottomNavOpacity = 0.0
                            }
                        }
                    }
                }
            }
            
            // Right sidebar
            if showingSidebar {
                Divider()
                
                VStack(spacing: 0) {
                    // Header
                    Button(action: {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: getDocumentsDirectory().path)
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Text("History")
                                        .font(.system(size: 13))
                                        .foregroundColor(isHoveringHistory ? textHoverColor : textColor)
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 10))
                                        .foregroundColor(isHoveringHistory ? textHoverColor : textColor)
                                }
                                Text(getDocumentsDirectory().path)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .onHover { hovering in
                        isHoveringHistory = hovering
                    }
                    
                    Divider()
                    
                    // Entries List
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(entries) { entry in
                                Button(action: {
                                    if selectedEntryId != entry.id {
                                        // Save current entry before switching
                                        if let currentId = selectedEntryId,
                                           let currentEntry = entries.first(where: { $0.id == currentId }) {
                                            saveEntry(entry: currentEntry)
                                        }
                                        
                                        selectedEntryId = entry.id
                                        loadEntry(entry: entry)
                                    }
                                }) {
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text(entry.previewText)
                                                    .font(.system(size: 13))
                                                    .lineLimit(1)
                                                    .foregroundColor(.primary)
                                                
                                                Spacer()
                                                
                                                // Export/Trash icons that appear on hover
                                                if hoveredEntryId == entry.id {
                                                    HStack(spacing: 8) {
                                                        // Export PDF button
                                                        Button(action: {
                                                            exportEntryAsPDF(entry: entry)
                                                        }) {
                                                            Image(systemName: "arrow.down.circle")
                                                                .font(.system(size: 11))
                                                                .foregroundColor(hoveredExportId == entry.id ? 
                                                                    (colorScheme == .light ? .black : .white) : 
                                                                    (colorScheme == .light ? .gray : .gray.opacity(0.8)))
                                                        }
                                                        .buttonStyle(.plain)
                                                        .help("Export entry as PDF")
                                                        .onHover { hovering in
                                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                                hoveredExportId = hovering ? entry.id : nil
                                                            }
                                                            if hovering {
                                                                NSCursor.pointingHand.push()
                                                            } else {
                                                                NSCursor.pop()
                                                            }
                                                        }
                                                        
                                                        // Trash icon
                                                        Button(action: {
                                                            deleteEntry(entry: entry)
                                                        }) {
                                                            Image(systemName: "trash")
                                                                .font(.system(size: 11))
                                                                .foregroundColor(hoveredTrashId == entry.id ? .red : .gray)
                                                        }
                                                        .buttonStyle(.plain)
                                                        .onHover { hovering in
                                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                                hoveredTrashId = hovering ? entry.id : nil
                                                            }
                                                            if hovering {
                                                                NSCursor.pointingHand.push()
                                                            } else {
                                                                NSCursor.pop()
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                            
                                            Text(entry.date)
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(backgroundColor(for: entry))
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .contentShape(Rectangle())
                                .onHover { hovering in
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        hoveredEntryId = hovering ? entry.id : nil
                                    }
                                }
                                .onAppear {
                                    NSCursor.pop()  // Reset cursor when button appears
                                }
                                .help("Click to select this entry")  // Add tooltip
                                
                                if entry.id != entries.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                    .scrollIndicators(.never)
                }
                .frame(width: 200)
                .background(FlexokiColors.bg(for: colorScheme))
            }
        }
        .frame(minWidth: 1100, minHeight: 600)
        .animation(.easeInOut(duration: 0.2), value: showingSidebar)
        .animation(.easeInOut(duration: 0.2), value: showingLensSidebar)
        .preferredColorScheme(colorScheme)
        .onAppear {
            showingSidebar = false  // Hide sidebar by default
            loadExistingEntries()

            // Configure analysis queue
            analysisQueue.configure(lensEngine: lensEngine) { [self] sentence, relativeHighlights in
                // Update cache with completed analysis for current lens
                guard let lensId = selectedLensId else { return }

                if sentenceCaches[lensId] == nil {
                    sentenceCaches[lensId] = [:]
                }
                sentenceCaches[lensId]?[sentence] = relativeHighlights

                // Rebuild highlights from updated cache
                let sentences = extractAllSentences(from: text)
                rebuildHighlightsFromCache(sentences: sentences, lensId: lensId)

                print("✅ Cached highlights for [\(lensId)]: '\(sentence.prefix(50))...'")
            }

            // Initialize adjective highlighter if available
            if #available(macOS 26.0, *) {
                adjectiveHighlighter = AdjectiveHighlighter()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .fontChanged)) { notification in
            if let fontName = notification.object as? String {
                if fontName == "random" {
                    if let randomFont = availableFonts.randomElement() {
                        selectedFont = randomFont
                        currentRandomFont = randomFont
                    }
                } else {
                    selectedFont = fontName
                    currentRandomFont = ""
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .fontSizeChanged)) { notification in
            if let size = notification.object as? CGFloat {
                fontSize = size
            }
        }
        .onChange(of: text) { oldValue, newValue in
            // Save current entry when text changes
            if let currentId = selectedEntryId,
               let currentEntry = entries.first(where: { $0.id == currentId }) {
                saveEntry(entry: currentEntry)
            }

            guard let lensId = selectedLensId else {
                highlightRanges = []
                return
            }

            // Get selected lens
            let selectedLens = lensEngine.availableLenses.first { $0.id == lensId }

            // Fast lenses: run immediately
            if selectedLens?.requiresAI == false {
                fastAnalysisTask?.cancel()
                fastAnalysisTask = Task { @MainActor in
                    let highlights = await lensEngine.analyze(
                        text: newValue,
                        enabledLensIds: [lensId],
                        colorScheme: colorScheme
                    )
                    highlightRanges = highlights.map { ($0.range, $0.color) }
                }
                return
            }

            // AI lenses: use sentence caching
            // Extract sentences from old and new text
            let oldSentences = extractAllSentences(from: oldValue)
            let newSentences = extractAllSentences(from: newValue)

            // Detect edited sentence
            if let editedSentence = findEditedSentence(oldSentences: oldSentences, newSentences: newSentences) {
                // Skip whitespace-only sentences
                let trimmed = editedSentence.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    print("⏭️ Skipping whitespace-only sentence")
                    rebuildHighlightsFromCache(sentences: newSentences, lensId: lensId)
                    return
                }

                print("✏️ Sentence edited: '\(editedSentence.text.prefix(50))...'")

                // Clear cache for edited sentence immediately (for this lens)
                sentenceCaches[lensId]?[editedSentence.text] = nil

                // Rebuild highlights (edited sentence will disappear)
                rebuildHighlightsFromCache(sentences: newSentences, lensId: lensId)

                // Debounce re-analysis (500ms after user stops editing)
                editDebounceTask?.cancel()
                editDebounceTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500))
                    guard !Task.isCancelled else { return }

                    print("🔄 Re-analyzing edited sentence: '\(editedSentence.text.prefix(50))...'")

                    // Check if lens requires AI
                    let selectedLens = lensEngine.availableLenses.first { $0.id == lensId }
                    if selectedLens?.requiresAI == true {
                        // Queue for AI analysis with high priority (0 = highest)
                        analysisQueue.enqueue(
                            sentence: editedSentence.text,
                            range: editedSentence.range,
                            lensId: lensId,
                            priority: 0
                        )
                    }
                }
                return
            }

            // Queue new COMPLETE sentences (not in cache for this lens)
            for sentence in newSentences {
                // Skip incomplete sentences - wait until they're finished
                guard sentence.isComplete else {
                    continue
                }

                // Check if already cached for this lens
                if sentenceCaches[lensId]?[sentence.text] != nil {
                    continue
                }

                // Skip whitespace-only sentences
                let trimmed = sentence.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    print("⏭️ Skipping whitespace-only sentence")
                    continue
                }

                print("📝 Complete sentence detected: '\(sentence.text.prefix(50))...'")

                // Check if lens requires AI
                let selectedLens = lensEngine.availableLenses.first { $0.id == lensId }
                if selectedLens?.requiresAI == true {
                    // Determine priority based on sentence ending
                    let isPaste = (newSentences.count - oldSentences.count) > 1
                    let priority = isPaste ? 2 : 1

                    analysisQueue.enqueue(
                        sentence: sentence.text,
                        range: sentence.range,
                        lensId: lensId,
                        priority: priority
                    )
                }
            }

            // Rebuild highlights from cache
            rebuildHighlightsFromCache(sentences: newSentences, lensId: lensId)
        }
        .onReceive(timer) { _ in
            if timerIsRunning && timeRemaining > 0 {
                timeRemaining -= 1
            } else if timeRemaining == 0 {
                timerIsRunning = false
                if !isHoveringBottomNav {
                    withAnimation(.easeOut(duration: 1.0)) {
                        bottomNavOpacity = 1.0
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willEnterFullScreenNotification)) { _ in
            isFullscreen = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willExitFullScreenNotification)) { _ in
            isFullscreen = false
        }
    }
    
    private func backgroundColor(for entry: HumanEntry) -> Color {
        if entry.id == selectedEntryId {
            return FlexokiColors.ui2(for: colorScheme)
        } else if entry.id == hoveredEntryId {
            return FlexokiColors.ui(for: colorScheme)
        } else {
            return Color.clear
        }
    }

    // MARK: - Incremental Sentence Analysis Helpers

    private func extractNewSentences(from text: String, since lastAnalyzed: String) -> [String] {
        // Get only the new text
        guard text.count > lastAnalyzed.count else { return [] }
        let newText = String(text.dropFirst(lastAnalyzed.count))

        // Split into sentences using Natural Language framework
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = newText

        var sentences: [String] = []
        tokenizer.enumerateTokens(in: newText.startIndex..<newText.endIndex) { range, _ in
            let sentence = String(newText[range])
            sentences.append(sentence)
            return true
        }

        return sentences
    }

    private func endsWithSentence(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        return trimmed.hasSuffix(".") || trimmed.hasSuffix("!") || trimmed.hasSuffix("?")
    }

    private func handleDeletionOrEdit(newText: String) -> Bool {
        // Deletion detected
        if newText.count < lastAnalyzedText.count {
            print("🔄 Deletion detected, clearing AI highlights")
            accumulatedAIHighlights = []
            lastAnalyzedText = ""
            return true
        }

        // Mid-document edit detected (user editing earlier text)
        if !newText.hasPrefix(lastAnalyzedText) {
            print("🔄 Mid-document edit detected, clearing AI highlights")
            accumulatedAIHighlights = []
            lastAnalyzedText = ""
            return true
        }

        return false
    }

    // Merge highlights with priority-based conflict resolution
    private func mergeHighlights(_ highlights: [Highlight]) -> [(NSRange, NSColor)] {
        // Sort by priority (high to low), then by position
        let sorted = highlights.sorted {
            $0.priority > $1.priority || ($0.priority == $1.priority && $0.range.location < $1.range.location)
        }

        // For overlapping ranges, higher priority wins
        var merged: [(NSRange, NSColor)] = []
        var covered: IndexSet = IndexSet()

        for highlight in sorted {
            let range = highlight.range
            let rangeIndices = range.location..<(range.location + range.length)

            // Only add if this range isn't already covered
            if !covered.contains(integersIn: rangeIndices) {
                merged.append((range, highlight.color))
                covered.insert(integersIn: rangeIndices)
            }
        }

        return merged
    }

    // MARK: - Sentence-Based Caching Helpers (NEW)

    struct SentenceInfo {
        let text: String
        let range: NSRange
        var isComplete: Bool {
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            return trimmed.hasSuffix(".") || trimmed.hasSuffix("!") || trimmed.hasSuffix("?")
        }
    }

    private func extractAllSentences(from text: String) -> [SentenceInfo] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text

        var sentences: [SentenceInfo] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentenceText = String(text[range])
            let nsRange = NSRange(range, in: text)
            sentences.append(SentenceInfo(text: sentenceText, range: nsRange))
            return true
        }

        return sentences
    }

    private func findEditedSentence(oldSentences: [SentenceInfo], newSentences: [SentenceInfo]) -> SentenceInfo? {
        // Find first COMPLETE sentence that differs
        let minCount = min(oldSentences.count, newSentences.count)

        for i in 0..<minCount {
            if oldSentences[i].text != newSentences[i].text {
                let edited = newSentences[i]
                // Only return if the edited sentence is complete
                // Incomplete sentences should be ignored until finished
                return edited.isComplete ? edited : nil
            }
        }

        // If new complete sentence was added at the end, return it
        if newSentences.count > oldSentences.count,
           let lastSentence = newSentences.last,
           lastSentence.isComplete {
            return lastSentence
        }

        return nil
    }

    private func rebuildHighlightsFromCache(sentences: [SentenceInfo], lensId: String) {
        highlightRanges = sentences.flatMap { sentence -> [(NSRange, NSColor)] in
            guard let cachedHighlights = sentenceCaches[lensId]?[sentence.text] else { return [] }

            return cachedHighlights.map { h in
                let absoluteRange = NSRange(
                    location: sentence.range.location + h.offsetFromSentenceStart,
                    length: h.length
                )
                return (absoluteRange, h.color.nsColor)
            }
        }
    }

    private func updatePreviewText(for entry: HumanEntry) {
        let documentsDirectory = getDocumentsDirectory()
        let fileURL = documentsDirectory.appendingPathComponent(entry.filename)
        
        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let preview = content
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let truncated = preview.isEmpty ? "" : (preview.count > 30 ? String(preview.prefix(30)) + "..." : preview)
            
            // Find and update the entry in the entries array
            if let index = entries.firstIndex(where: { $0.id == entry.id }) {
                entries[index].previewText = truncated
            }
        } catch {
            print("Error updating preview text: \(error)")
        }
    }
    
    private func saveEntry(entry: HumanEntry) {
        let documentsDirectory = getDocumentsDirectory()
        let fileURL = documentsDirectory.appendingPathComponent(entry.filename)

        do {
            // Save text content
            try text.write(to: fileURL, atomically: true, encoding: .utf8)

            // Save metadata with all lens caches
            let metadata = DocumentMetadata(
                sentenceCaches: sentenceCaches,
                lensVersion: DocumentMetadata.currentVersion
            )

            let metadataURL = documentsDirectory.appendingPathComponent(entry.filename.replacingOccurrences(of: ".md", with: ".meta.json"))
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let metadataData = try encoder.encode(metadata)
            try metadataData.write(to: metadataURL, options: .atomic)

            print("Successfully saved entry and metadata: \(entry.filename)")
            updatePreviewText(for: entry)  // Update preview after saving
        } catch {
            print("Error saving entry: \(error)")
        }
    }
    
    private func loadEntry(entry: HumanEntry) {
        let documentsDirectory = getDocumentsDirectory()
        let fileURL = documentsDirectory.appendingPathComponent(entry.filename)

        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                // Load text content
                text = try String(contentsOf: fileURL, encoding: .utf8)

                // Load metadata if it exists
                let metadataURL = documentsDirectory.appendingPathComponent(entry.filename.replacingOccurrences(of: ".md", with: ".meta.json"))

                if fileManager.fileExists(atPath: metadataURL.path) {
                    let metadataData = try Data(contentsOf: metadataURL)
                    let decoder = JSONDecoder()
                    let metadata = try decoder.decode(DocumentMetadata.self, from: metadataData)

                    // Only restore cache if version matches
                    if metadata.lensVersion == DocumentMetadata.currentVersion {
                        sentenceCaches = metadata.sentenceCaches

                        // Rebuild highlights for current lens if one is selected
                        if let lensId = selectedLensId {
                            let sentences = extractAllSentences(from: text)
                            rebuildHighlightsFromCache(sentences: sentences, lensId: lensId)
                        }

                        let totalCached = sentenceCaches.values.map { $0.count }.reduce(0, +)
                        print("✅ Restored \(sentenceCaches.count) lens caches with \(totalCached) total sentences")
                    } else {
                        print("⚠️ Metadata version mismatch (v\(metadata.lensVersion) vs v\(DocumentMetadata.currentVersion)), clearing cache")
                        sentenceCaches = [:]
                    }
                } else {
                    print("ℹ️ No metadata file found, starting fresh")
                    sentenceCaches = [:]
                }

                print("Successfully loaded entry: \(entry.filename)")
            }
        } catch {
            print("Error loading entry: \(error)")
        }
    }
    
    private func cycleLens() {
        let allLenses = lensEngine.availableLenses

        if let currentId = selectedLensId,
           let currentIndex = allLenses.firstIndex(where: { $0.id == currentId }) {
            // Move to next lens
            let nextIndex = (currentIndex + 1) % (allLenses.count + 1) // +1 for "No Lens"
            if nextIndex == allLenses.count {
                selectedLensId = nil // Back to "No Lens"
            } else {
                selectedLensId = allLenses[nextIndex].id
            }
        } else {
            // No lens selected, select first lens
            selectedLensId = allLenses.first?.id
        }

        // Cancel pending tasks
        analysisQueue.clear()
        editDebounceTask?.cancel()

        // Trigger analysis based on lens type
        if let lensId = selectedLensId,
           let lens = allLenses.first(where: { $0.id == lensId }) {

            if lens.requiresAI {
                // AI lens: check cache first, then queue missing sentences
                if !text.isEmpty {
                    let sentences = extractAllSentences(from: text)

                    // Initialize cache for this lens if needed
                    if sentenceCaches[lensId] == nil {
                        sentenceCaches[lensId] = [:]
                    }

                    // Rebuild from existing cache first
                    rebuildHighlightsFromCache(sentences: sentences, lensId: lensId)

                    // Queue only uncached COMPLETE sentences
                    for sentence in sentences {
                        // Only queue complete sentences
                        guard sentence.isComplete else { continue }

                        if sentenceCaches[lensId]?[sentence.text] == nil {
                            analysisQueue.enqueue(
                                sentence: sentence.text,
                                range: sentence.range,
                                lensId: lensId,
                                priority: 1
                            )
                        }
                    }
                }
            } else {
                // Fast lens: analyze immediately
                fastAnalysisTask?.cancel()
                fastAnalysisTask = Task { @MainActor in
                    let highlights = await lensEngine.analyze(
                        text: text,
                        enabledLensIds: [lensId],
                        colorScheme: colorScheme
                    )
                    highlightRanges = highlights.map { ($0.range, $0.color) }
                }
            }
        } else {
            // No lens selected
            highlightRanges = []
        }
    }

    private func createNewEntry() {
        let newEntry = HumanEntry.createNew()
        entries.insert(newEntry, at: 0) // Add to the beginning
        selectedEntryId = newEntry.id

        // If this is the first entry (entries was empty before adding this one)
        if entries.count == 1 {
            // Read welcome message from default.md
            if let defaultMessageURL = Bundle.main.url(forResource: "default", withExtension: "md"),
               let defaultMessage = try? String(contentsOf: defaultMessageURL, encoding: .utf8) {
                text = "\n\n" + defaultMessage
            }
            // Save the welcome message immediately
            saveEntry(entry: newEntry)
            // Update the preview text
            updatePreviewText(for: newEntry)
        } else {
            // Regular new entry starts with newlines
            text = "\n\n"
            // Randomize placeholder text for new entry
            placeholderText = placeholderOptions.randomElement() ?? "Begin writing"
            // Save the empty entry
            saveEntry(entry: newEntry)
        }
    }
    
    private func openChatGPT() {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let fullText = aiChatPrompt + "\n\n" + trimmedText
        
        if let encodedText = fullText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://chat.openai.com/?m=" + encodedText) {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openClaude() {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let fullText = claudePrompt + "\n\n" + trimmedText
        
        if let encodedText = fullText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://claude.ai/new?q=" + encodedText) {
            NSWorkspace.shared.open(url)
        }
    }

    private func copyPromptToClipboard() {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let fullText = aiChatPrompt + "\n\n" + trimmedText

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(fullText, forType: .string)
        print("Prompt copied to clipboard")
    }
    
    private func deleteEntry(entry: HumanEntry) {
        // Delete the file from the filesystem
        let documentsDirectory = getDocumentsDirectory()
        let fileURL = documentsDirectory.appendingPathComponent(entry.filename)
        
        do {
            try fileManager.removeItem(at: fileURL)
            print("Successfully deleted file: \(entry.filename)")
            
            // Remove the entry from the entries array
            if let index = entries.firstIndex(where: { $0.id == entry.id }) {
                entries.remove(at: index)
                
                // If the deleted entry was selected, select the first entry or create a new one
                if selectedEntryId == entry.id {
                    if let firstEntry = entries.first {
                        selectedEntryId = firstEntry.id
                        loadEntry(entry: firstEntry)
                    } else {
                        createNewEntry()
                    }
                }
            }
        } catch {
            print("Error deleting file: \(error)")
        }
    }
    
    // Extract a title from entry content for PDF export
    private func extractTitleFromContent(_ content: String, date: String) -> String {
        // Clean up content by removing leading/trailing whitespace and newlines
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If content is empty, just use the date
        if trimmedContent.isEmpty {
            return "Entry \(date)"
        }
        
        // Split content into words, ignoring newlines and removing punctuation
        let words = trimmedContent
            .replacingOccurrences(of: "\n", with: " ")
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .map { word in
                word.trimmingCharacters(in: CharacterSet(charactersIn: ".,!?;:\"'()[]{}<>"))
                    .lowercased()
            }
            .filter { !$0.isEmpty }
        
        // If we have at least 4 words, use them
        if words.count >= 4 {
            return "\(words[0])-\(words[1])-\(words[2])-\(words[3])"
        }
        
        // If we have fewer than 4 words, use what we have
        if !words.isEmpty {
            return words.joined(separator: "-")
        }
        
        // Fallback to date if no words found
        return "Entry \(date)"
    }
    
    private func exportEntryAsPDF(entry: HumanEntry) {
        // First make sure the current entry is saved
        if selectedEntryId == entry.id {
            saveEntry(entry: entry)
        }
        
        // Get entry content
        let documentsDirectory = getDocumentsDirectory()
        let fileURL = documentsDirectory.appendingPathComponent(entry.filename)
        
        do {
            // Read the content of the entry
            let entryContent = try String(contentsOf: fileURL, encoding: .utf8)
            
            // Extract a title from the entry content and add .pdf extension
            let suggestedFilename = extractTitleFromContent(entryContent, date: entry.date) + ".pdf"
            
            // Create save panel
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [UTType.pdf]
            savePanel.nameFieldStringValue = suggestedFilename
            savePanel.isExtensionHidden = false  // Make sure extension is visible
            
            // Show save dialog
            if savePanel.runModal() == .OK, let url = savePanel.url {
                // Create PDF data
                if let pdfData = createPDFFromText(text: entryContent) {
                    try pdfData.write(to: url)
                    print("Successfully exported PDF to: \(url.path)")
                }
            }
        } catch {
            print("Error in PDF export: \(error)")
        }
    }
    
    @available(macOS 26.0, *)
    private func highlightAdjectives() async {
        guard let highlighter = adjectiveHighlighter as? AdjectiveHighlighter else { return }

        // Skip if already highlighting
        guard !isHighlighting else { return }

        // Skip if text is too short
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedText.count < 10 {
            await MainActor.run {
                highlightRanges = []
            }
            return
        }

        // Set highlighting flag
        await MainActor.run {
            isHighlighting = true
        }

        do {
            let adjectives = try await highlighter.findAdjectives(in: text)

            // Convert adjective positions to NSRange and apply yellow color
            var ranges: [(range: NSRange, color: NSColor)] = []

            for adj in adjectives {
                let nsRange = NSRange(location: adj.startIndex, length: adj.word.count)
                ranges.append((range: nsRange, color: .yellow))
            }

            await MainActor.run {
                highlightRanges = ranges
                isHighlighting = false
            }
        } catch {
            print("Error highlighting adjectives: \(error)")
            await MainActor.run {
                isHighlighting = false
            }
        }
    }

    private func createPDFFromText(text: String) -> Data? {
        // Letter size page dimensions
        let pageWidth: CGFloat = 612.0  // 8.5 x 72
        let pageHeight: CGFloat = 792.0 // 11 x 72
        let margin: CGFloat = 72.0      // 1-inch margins
        
        // Calculate content area
        let contentRect = CGRect(
            x: margin,
            y: margin,
            width: pageWidth - (margin * 2),
            height: pageHeight - (margin * 2)
        )
        
        // Create PDF data container
        let pdfData = NSMutableData()
        
        // Configure text formatting attributes
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineHeight
        
        let font = NSFont(name: selectedFont, size: fontSize) ?? .systemFont(ofSize: fontSize)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: FlexokiColors.NS.base950,
            .paragraphStyle: paragraphStyle
        ]
        
        // Trim the initial newlines before creating the PDF
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Create the attributed string with formatting
        let attributedString = NSAttributedString(string: trimmedText, attributes: textAttributes)
        
        // Create a Core Text framesetter for text layout
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        
        // Create a PDF context with the data consumer
        guard let pdfContext = CGContext(consumer: CGDataConsumer(data: pdfData as CFMutableData)!, mediaBox: nil, nil) else {
            print("Failed to create PDF context")
            return nil
        }
        
        // Track position within text
        var currentRange = CFRange(location: 0, length: 0)
        var pageIndex = 0
        
        // Create a path for the text frame
        let framePath = CGMutablePath()
        framePath.addRect(contentRect)
        
        // Continue creating pages until all text is processed
        while currentRange.location < attributedString.length {
            // Begin a new PDF page
            pdfContext.beginPage(mediaBox: nil)
            
            // Fill the page with paper background
            pdfContext.setFillColor(FlexokiColors.NS.paper.cgColor)
            pdfContext.fill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
            
            // Create a frame for this page's text
            let frame = CTFramesetterCreateFrame(
                framesetter, 
                currentRange, 
                framePath, 
                nil
            )
            
            // Draw the text frame
            CTFrameDraw(frame, pdfContext)
            
            // Get the range of text that was actually displayed in this frame
            let visibleRange = CTFrameGetVisibleStringRange(frame)
            
            // Move to the next block of text for the next page
            currentRange.location += visibleRange.length
            
            // Finish the page
            pdfContext.endPage()
            pageIndex += 1
            
            // Safety check - don't allow infinite loops
            if pageIndex > 1000 {
                print("Safety limit reached - stopping PDF generation")
                break
            }
        }
        
        // Finalize the PDF document
        pdfContext.closePDF()
        
        return pdfData as Data
    }
}

// MARK: - Sentence Analysis Queue

@MainActor
class SentenceAnalysisQueue: ObservableObject {
    private var pending: [AnalysisRequest] = []
    private var isProcessing = false
    private var lensEngine: LensEngine?
    private var onComplete: ((String, [RelativeHighlight]) -> Void)?

    struct AnalysisRequest: Identifiable {
        let id = UUID()
        let sentence: String
        let sentenceRange: NSRange
        let lensId: String
        let priority: Int // 0=edit, 1=typing, 2=paste
    }

    func configure(lensEngine: LensEngine, onComplete: @escaping (String, [RelativeHighlight]) -> Void) {
        self.lensEngine = lensEngine
        self.onComplete = onComplete
    }

    func enqueue(sentence: String, range: NSRange, lensId: String, priority: Int = 1) {
        // Dedupe: same sentence + lens already pending
        pending.removeAll {
            $0.sentence == sentence && $0.lensId == lensId
        }

        pending.append(AnalysisRequest(
            sentence: sentence,
            sentenceRange: range,
            lensId: lensId,
            priority: priority
        ))

        if !isProcessing {
            Task {
                await processQueue()
            }
        }
    }

    func clear() {
        pending.removeAll()
    }

    private func processQueue() async {
        guard !isProcessing else { return }
        isProcessing = true

        while !pending.isEmpty {
            // Sort by priority (0 = highest)
            pending.sort { $0.priority < $1.priority }
            let request = pending.removeFirst()

            // Analyze this sentence
            guard let engine = lensEngine else { continue }

            let highlights = await engine.analyzeWithAI(
                text: request.sentence,
                enabledLensIds: [request.lensId],
                colorScheme: .light // TODO: Pass actual color scheme
            )

            // Convert to relative highlights
            // NOTE: highlights are already relative to sentence start (position 0)
            // since we analyzed just the sentence text, not the full document
            let relativeHighlights = highlights.map { h in
                RelativeHighlight(
                    offsetFromSentenceStart: h.range.location,
                    length: h.range.length,
                    color: CodableColor(h.color),
                    matchText: (request.sentence as NSString).substring(with: h.range)
                )
            }

            // Notify completion
            onComplete?(request.sentence, relativeHighlights)
        }

        isProcessing = false
    }
}

// Helper function to calculate line height
func getLineHeight(font: NSFont) -> CGFloat {
    return font.ascender - font.descender + font.leading
}

// Add helper extension to find NSTextView
extension NSView {
    func findTextView() -> NSView? {
        if self is NSTextView {
            return self
        }
        for subview in subviews {
            if let textView = subview.findTextView() {
                return textView
            }
        }
        return nil
    }
}

// Add helper extension for finding subviews of a specific type
extension NSView {
    func findSubview<T: NSView>(ofType type: T.Type) -> T? {
        if let typedSelf = self as? T {
            return typedSelf
        }
        for subview in subviews {
            if let found = subview.findSubview(ofType: type) {
                return found
            }
        }
        return nil
    }
}

#Preview {
    ContentView()
}
