//
//  RhythmLens.swift
//  WritersLens
//
//  Analyzes sentence length patterns and variety
//

import Foundation
import AppKit
import NaturalLanguage
import SwiftUI

struct RhythmLens: WritingLens {
    let id = "rhythm"
    let name = "Rhythm"
    let description = "Shows writing rhythm - cool colors indicate variety, warm colors indicate monotony"
    let category = "Style"

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
