//
//  LensEngine.swift
//  freewrite
//
//  Tokenization-based writing lens system for multi-layer text highlighting
//

import Foundation
import AppKit
import NaturalLanguage
import SwiftUI

// MARK: - Data Models

struct Token {
    let text: String
    let range: NSRange
    let lexicalClass: NLTag?
    let lemma: String?
}

enum SentenceLength {
    case short, medium, long
}

struct Sentence {
    let text: String
    let range: NSRange
    let tokens: [Token]

    var length: SentenceLength {
        let count = tokens.count
        if count < 10 { return .short }
        if count < 20 { return .medium }
        return .long
    }
}

struct TextDocument {
    let text: String
    let tokens: [Token]
    let sentences: [Sentence]
    let tokensByLemma: [String: [Token]]
    let wordFrequency: [String: Int]
}

struct Highlight {
    let range: NSRange
    let color: NSColor
    let category: String
    let priority: Int  // 0=background, 1=low, 2=medium, 3=high
}

// MARK: - Tokenizer

class Tokenizer {
    func tokenize(_ text: String) -> TextDocument {
        var tokens: [Token] = []
        var sentences: [Sentence] = []

        // Setup NaturalLanguage framework
        let sentenceTokenizer = NLTokenizer(unit: .sentence)
        let wordTokenizer = NLTokenizer(unit: .word)
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])

        sentenceTokenizer.string = text
        tagger.string = text

        // Enumerate sentences
        sentenceTokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { sentenceRange, _ in
            var sentenceTokens: [Token] = []
            wordTokenizer.string = text

            // Enumerate words in sentence
            wordTokenizer.enumerateTokens(in: sentenceRange) { tokenRange, _ in
                let tokenText = String(text[tokenRange])
                let nsRange = NSRange(tokenRange, in: text)

                let lexicalClass = tagger.tag(at: tokenRange.lowerBound,
                                             unit: .word,
                                             scheme: .lexicalClass).0
                let lemma = tagger.tag(at: tokenRange.lowerBound,
                                      unit: .word,
                                      scheme: .lemma).0?.rawValue

                let token = Token(text: tokenText,
                                range: nsRange,
                                lexicalClass: lexicalClass,
                                lemma: lemma)
                sentenceTokens.append(token)
                tokens.append(token)
                return true
            }

            let sentenceText = String(text[sentenceRange])
            let sentenceNSRange = NSRange(sentenceRange, in: text)
            sentences.append(Sentence(text: sentenceText,
                                    range: sentenceNSRange,
                                    tokens: sentenceTokens))
            return true
        }

        // Build lookup caches
        var lemmaMap: [String: [Token]] = [:]
        var freqMap: [String: Int] = [:]

        for token in tokens {
            if let lemma = token.lemma?.lowercased() {
                lemmaMap[lemma, default: []].append(token)
            }
            freqMap[token.text.lowercased(), default: 0] += 1
        }

        return TextDocument(text: text,
                           tokens: tokens,
                           sentences: sentences,
                           tokensByLemma: lemmaMap,
                           wordFrequency: freqMap)
    }
}

// MARK: - Lens Protocol

protocol WritingLens {
    var id: String { get }
    var name: String { get }
    var description: String { get }
    var category: String { get }
    var requiresAI: Bool { get }

    func analyze(document: TextDocument, colorScheme: ColorScheme) async -> [Highlight]
}

// MARK: - Fast Lenses

struct PartsOfSpeechLens: WritingLens {
    let id = "pos"
    let name = "Parts of Speech"
    let description = "Colors nouns (blue), verbs (orange), adjectives (yellow)"
    let category = "Grammar"
    let requiresAI = false

    func colorMap(for scheme: ColorScheme) -> [NLTag: NSColor] {
        return [
            .noun: FlexokiColors.NS.blue(for: scheme),
            .verb: FlexokiColors.NS.orange(for: scheme),
            .adjective: FlexokiColors.NS.yellow(for: scheme)
        ]
    }

    func analyze(document: TextDocument, colorScheme: ColorScheme) async -> [Highlight] {
        let colors = colorMap(for: colorScheme)
        return document.tokens.compactMap { token in
            guard let tag = token.lexicalClass,
                  let color = colors[tag] else { return nil }
            return Highlight(range: token.range,
                           color: color,
                           category: tag.rawValue,
                           priority: 1)
        }
    }
}

struct AdverbLens: WritingLens {
    let id = "adverbs"
    let name = "Adverb Overuse"
    let description = "Highlights adverbs and -ly words for concise writing"
    let category = "Style"
    let requiresAI = false

    func analyze(document: TextDocument, colorScheme: ColorScheme) async -> [Highlight] {
        document.tokens.compactMap { token in
            let isAdverb = token.lexicalClass == .adverb || token.text.hasSuffix("ly")
            guard isAdverb else { return nil }
            return Highlight(range: token.range,
                           color: FlexokiColors.NS.orange(for: colorScheme),
                           category: "adverb",
                           priority: 2)
        }
    }
}

struct FillerLens: WritingLens {
    let id = "filler"
    let name = "Filler Words"
    let description = "Identifies unnecessary words like 'very', 'really', 'just', 'actually'"
    let category = "Clarity"
    let requiresAI = false

    let fillers: Set<String> = [
        // Original core fillers
        "very", "really", "just", "actually", "basically",
        "literally", "definitely", "probably", "somewhat",

        // Hedging words
        "kind", "sort", "rather", "quite", "fairly", "pretty",

        // Intensifiers
        "extremely", "incredibly", "absolutely", "totally",
        "completely", "utterly", "entirely",

        // Vague qualifiers
        "thing", "stuff", "something", "somehow", "someplace",

        // Discourse markers
        "well", "so", "now", "then", "like", "mean",

        // Redundant adverbs
        "simply", "merely", "only", "essentially",
        "fundamentally", "particularly",

        // Opinion softeners
        "perhaps", "possibly", "maybe", "seemingly", "apparently",

        // Time fillers
        "currently", "presently"
    ]

    func colorPool(for scheme: ColorScheme) -> [NSColor] {
        return [
            FlexokiColors.NS.red(for: scheme),
            FlexokiColors.NS.orange(for: scheme),
            FlexokiColors.NS.yellow(for: scheme),
            FlexokiColors.NS.green(for: scheme),
            FlexokiColors.NS.cyan(for: scheme),
            FlexokiColors.NS.blue(for: scheme),
            FlexokiColors.NS.purple(for: scheme),
            FlexokiColors.NS.magenta(for: scheme)
        ]
    }

    func analyze(document: TextDocument, colorScheme: ColorScheme) async -> [Highlight] {
        let colors = colorPool(for: colorScheme)
        let opacities: [CGFloat] = [1.0, 0.7, 0.5]

        // Group tokens by filler word (lowercased)
        var fillerGroups: [String: [Token]] = [:]
        for token in document.tokens {
            let lowercased = token.text.lowercased()
            if fillers.contains(lowercased) {
                fillerGroups[lowercased, default: []].append(token)
            }
        }

        // Sort for consistent color assignment
        let sortedFillers = fillerGroups.sorted { $0.key < $1.key }
        var highlights: [Highlight] = []

        for (index, (filler, tokens)) in sortedFillers.enumerated() {
            let colorIndex = index % colors.count
            let opacityIndex = (index / colors.count) % opacities.count
            let color = colors[colorIndex].withAlphaComponent(opacities[opacityIndex])

            for token in tokens {
                highlights.append(Highlight(range: token.range,
                                          color: color,
                                          category: "filler-\(filler)",
                                          priority: 3))
            }
        }

        return highlights
    }
}

struct SentenceLengthLens: WritingLens {
    let id = "sentence-length"
    let name = "Sentence Length"
    let description = "Shows sentence variety: green (short), yellow (medium), red (long)"
    let category = "Readability"
    let requiresAI = false

    func analyze(document: TextDocument, colorScheme: ColorScheme) async -> [Highlight] {
        document.sentences.map { sentence in
            let color: NSColor = switch sentence.length {
                case .short: FlexokiColors.NS.green(for: colorScheme)
                case .medium: FlexokiColors.NS.yellow(for: colorScheme)
                case .long: FlexokiColors.NS.red(for: colorScheme)
            }
            return Highlight(range: sentence.range,
                           color: color,
                           category: "sentence-\(sentence.length)",
                           priority: 0)
        }
    }
}

struct PassiveVoiceLens: WritingLens {
    let id = "passive"
    let name = "Passive Voice"
    let description = "Highlights passive constructions to encourage active voice"
    let category = "Style"
    let requiresAI = false

    let beVerbs: Set<String> = [
        "am", "is", "are", "was", "were", "be", "been", "being"
    ]

    func analyze(document: TextDocument, colorScheme: ColorScheme) async -> [Highlight] {
        var highlights: [Highlight] = []
        let tokens = document.tokens

        for i in 0..<tokens.count {
            let token = tokens[i]

            // Check if current token is a "be" verb
            guard beVerbs.contains(token.text.lowercased()) else { continue }

            // Look ahead for past participle (skip adverbs like "being carefully written")
            var lookAhead = 1
            while i + lookAhead < tokens.count && lookAhead <= 3 {
                let nextToken = tokens[i + lookAhead]

                // Skip adverbs and other modifiers
                if nextToken.lexicalClass == .adverb {
                    lookAhead += 1
                    continue
                }

                // Check if next content word is a verb (likely past participle in this context)
                if nextToken.lexicalClass == .verb {
                    // Highlight the entire passive construction
                    let startRange = token.range
                    let endRange = nextToken.range
                    let combinedRange = NSRange(
                        location: startRange.location,
                        length: (endRange.location + endRange.length) - startRange.location
                    )

                    highlights.append(Highlight(
                        range: combinedRange,
                        color: FlexokiColors.NS.blue(for: colorScheme),
                        category: "passive-voice",
                        priority: 2
                    ))
                    break
                }

                // If we hit a noun or other non-verb, not passive
                break
            }
        }

        return highlights
    }
}

struct RepetitionLens: WritingLens {
    let id = "repetition"
    let name = "Word Repetition"
    let description = "Highlights words used 3+ times to vary vocabulary"
    let category = "Style"
    let requiresAI = false
    let threshold = 3

    func colorPool(for scheme: ColorScheme) -> [NSColor] {
        return [
            FlexokiColors.NS.red(for: scheme),
            FlexokiColors.NS.orange(for: scheme),
            FlexokiColors.NS.yellow(for: scheme),
            FlexokiColors.NS.green(for: scheme),
            FlexokiColors.NS.cyan(for: scheme),
            FlexokiColors.NS.blue(for: scheme),
            FlexokiColors.NS.purple(for: scheme),
            FlexokiColors.NS.magenta(for: scheme)
        ]
    }

    func analyze(document: TextDocument, colorScheme: ColorScheme) async -> [Highlight] {
        let colors = colorPool(for: colorScheme)
        let opacities: [CGFloat] = [1.0, 0.7, 0.5]

        // Get repeated lemmas sorted for consistent color assignment
        let repeatedLemmas = document.tokensByLemma
            .filter { $0.value.count >= threshold }
            .sorted { $0.key < $1.key }

        var highlights: [Highlight] = []

        for (index, (lemma, tokens)) in repeatedLemmas.enumerated() {
            let colorIndex = index % colors.count
            let opacityIndex = (index / colors.count) % opacities.count
            let color = colors[colorIndex].withAlphaComponent(opacities[opacityIndex])

            for token in tokens {
                highlights.append(Highlight(range: token.range,
                                          color: color,
                                          category: "repetition-\(lemma)",
                                          priority: 2))
            }
        }

        return highlights
    }
}

struct RhythmLens: WritingLens {
    let id = "rhythm"
    let name = "Rhythm"
    let description = "Shows writing rhythm - cool colors indicate variety, warm colors indicate monotony"
    let category = "Style"
    let requiresAI = false

    enum RhythmCategory: String {
        case veryShort = "very-short"
        case short = "short"
        case medium = "medium"
        case long = "long"

        init(wordCount: Int) {
            switch wordCount {
            case 0...5: self = .veryShort
            case 6...10: self = .short
            case 11...20: self = .medium
            default: self = .long
            }
        }
    }

    func colorForSentence(category: RhythmCategory, entropy: Double, scheme: ColorScheme) -> NSColor {
        // Entropy ranges from 0 (monotonous) to log2(4) ≈ 2.0 (perfectly varied)
        // Normalize to 0-1 range
        let maxEntropy = log2(4.0)
        let normalizedEntropy = min(entropy / maxEntropy, 1.0)

        // High entropy (varied/rhythmic) = cool colors (blues, greens, purples)
        // Low entropy (monotonous) = warm colors (reds, oranges, yellows)

        if normalizedEntropy > 0.6 {
            // Rhythmic - use cool colors
            switch category {
            case .veryShort: return FlexokiColors.NS.purple(for: scheme)
            case .short: return FlexokiColors.NS.blue(for: scheme)
            case .medium: return FlexokiColors.NS.cyan(for: scheme)
            case .long: return FlexokiColors.NS.green(for: scheme)
            }
        } else if normalizedEntropy < 0.3 {
            // Monotonous - use warm colors
            switch category {
            case .veryShort: return FlexokiColors.NS.red(for: scheme)
            case .short: return FlexokiColors.NS.orange(for: scheme)
            case .medium: return FlexokiColors.NS.yellow(for: scheme)
            case .long: return FlexokiColors.NS.magenta(for: scheme)
            }
        } else {
            // Transitional - blend between warm and cool
            let warmColor: NSColor
            let coolColor: NSColor

            switch category {
            case .veryShort:
                warmColor = FlexokiColors.NS.red(for: scheme)
                coolColor = FlexokiColors.NS.purple(for: scheme)
            case .short:
                warmColor = FlexokiColors.NS.orange(for: scheme)
                coolColor = FlexokiColors.NS.blue(for: scheme)
            case .medium:
                warmColor = FlexokiColors.NS.yellow(for: scheme)
                coolColor = FlexokiColors.NS.cyan(for: scheme)
            case .long:
                warmColor = FlexokiColors.NS.magenta(for: scheme)
                coolColor = FlexokiColors.NS.green(for: scheme)
            }

            // Blend based on entropy (normalize to 0.3-0.6 range)
            let blendFactor = CGFloat((normalizedEntropy - 0.3) / 0.3)
            return warmColor.blended(withFraction: blendFactor, of: coolColor) ?? warmColor
        }
    }

    func calculateEntropy(categories: [RhythmCategory]) -> Double {
        guard !categories.isEmpty else { return 0 }

        // Count frequency of each category
        var frequencies: [RhythmCategory: Int] = [:]
        for category in categories {
            frequencies[category, default: 0] += 1
        }

        // Calculate Shannon entropy: H = -Σ(p(x) * log2(p(x)))
        let total = Double(categories.count)
        var entropy: Double = 0

        for (_, count) in frequencies {
            let probability = Double(count) / total
            if probability > 0 {
                entropy -= probability * log2(probability)
            }
        }

        return entropy
    }

    func analyze(document: TextDocument, colorScheme: ColorScheme) async -> [Highlight] {
        guard !document.sentences.isEmpty else { return [] }

        let windowSize = 5
        var highlights: [Highlight] = []

        // Categorize all sentences
        let categories = document.sentences.map { sentence in
            RhythmCategory(wordCount: sentence.tokens.count)
        }

        // Calculate entropy for each sentence using sliding window
        for (index, sentence) in document.sentences.enumerated() {
            let category = categories[index]

            // Define window bounds
            let windowStart = max(0, index - windowSize / 2)
            let windowEnd = min(categories.count, index + windowSize / 2 + 1)
            let window = Array(categories[windowStart..<windowEnd])

            // Calculate entropy for this window
            let entropy = calculateEntropy(categories: window)

            // Get color based on entropy and category
            let color = colorForSentence(category: category, entropy: entropy, scheme: colorScheme)

            highlights.append(Highlight(range: sentence.range,
                                       color: color,
                                       category: "rhythm-\(category.rawValue)",
                                       priority: 0))
        }

        return highlights
    }
}

// MARK: - Lens Engine

@MainActor
class LensEngine: ObservableObject {
    private let tokenizer = Tokenizer()

    let availableLenses: [WritingLens] = [
        PartsOfSpeechLens(),
        AdverbLens(),
        PassiveVoiceLens(),
        FillerLens(),
        SentenceLengthLens(),
        RepetitionLens(),
        RhythmLens()
    ]

    func analyze(text: String, enabledLensIds: Set<String>, colorScheme: ColorScheme) async -> [Highlight] {
        let activeLenses = availableLenses.filter { enabledLensIds.contains($0.id) }
        let fastLenses = activeLenses.filter { !$0.requiresAI }

        // Tokenize once
        let document = tokenizer.tokenize(text)

        // Run fast lenses in parallel
        return await withTaskGroup(of: [Highlight].self) { group in
            for lens in fastLenses {
                group.addTask { await lens.analyze(document: document, colorScheme: colorScheme) }
            }

            var allHighlights: [Highlight] = []
            for await highlights in group {
                allHighlights.append(contentsOf: highlights)
            }
            return allHighlights
        }
    }

    func analyzeWithAI(text: String, enabledLensIds: Set<String>, colorScheme: ColorScheme) async -> [Highlight] {
        let aiLenses = availableLenses.filter {
            $0.requiresAI && enabledLensIds.contains($0.id)
        }

        var highlights: [Highlight] = []

        // Run AI lenses sequentially to avoid concurrent LanguageModelSession calls
        for lens in aiLenses {
            let document = tokenizer.tokenize(text)
            highlights.append(contentsOf: await lens.analyze(document: document, colorScheme: colorScheme))
        }

        return highlights
    }
}
