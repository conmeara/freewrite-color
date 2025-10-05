//
//  FillerLens.swift
//  WritersLens
//
//  Identifies unnecessary filler words
//

import Foundation
import AppKit
import NaturalLanguage
import SwiftUI

struct FillerLens: WritingLens {
    let id = "filler"
    let name = "Filler Words"
    let description = "Identifies unnecessary words like 'very', 'really', 'just', 'actually'"
    let category = "Clarity"

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
