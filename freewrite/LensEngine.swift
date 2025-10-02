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
    let description = "Colors nouns, verbs, adjectives, adverbs, pronouns, and prepositions"
    let category = "Grammar"
    let requiresAI = false

    func colorMap(for scheme: ColorScheme) -> [NLTag: NSColor] {
        return [
            .noun: FlexokiColors.NS.blue(for: scheme),
            .verb: FlexokiColors.NS.green(for: scheme),
            .adjective: FlexokiColors.NS.purple(for: scheme),
            .adverb: FlexokiColors.NS.orange(for: scheme),
            .pronoun: FlexokiColors.NS.magenta(for: scheme),
            .preposition: FlexokiColors.NS.cyan(for: scheme)
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
        "very", "really", "just", "actually", "basically",
        "literally", "definitely", "probably", "somewhat"
    ]

    func analyze(document: TextDocument, colorScheme: ColorScheme) async -> [Highlight] {
        document.tokens.compactMap { token in
            guard fillers.contains(token.text.lowercased()) else { return nil }
            return Highlight(range: token.range,
                           color: FlexokiColors.NS.red(for: colorScheme),
                           category: "filler",
                           priority: 3)
        }
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
                           color: color.withAlphaComponent(0.15),
                           category: "sentence-\(sentence.length)",
                           priority: 0)
        }
    }
}

struct RepetitionLens: WritingLens {
    let id = "repetition"
    let name = "Word Repetition"
    let description = "Highlights words used 3+ times to vary vocabulary"
    let category = "Style"
    let requiresAI = false
    let threshold = 3

    func analyze(document: TextDocument, colorScheme: ColorScheme) async -> [Highlight] {
        document.tokensByLemma
            .filter { $0.value.count >= threshold }
            .flatMap { _, tokens in
                tokens.map { token in
                    Highlight(range: token.range,
                            color: FlexokiColors.NS.purple(for: colorScheme),
                            category: "repetition",
                            priority: 2)
                }
            }
    }
}

// MARK: - Lens Engine

@MainActor
class LensEngine: ObservableObject {
    private let tokenizer = Tokenizer()

    let availableLenses: [WritingLens] = [
        PartsOfSpeechLens(),
        AdverbLens(),
        FillerLens(),
        SentenceLengthLens(),
        RepetitionLens()
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
