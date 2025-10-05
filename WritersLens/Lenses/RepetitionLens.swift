//
//  RepetitionLens.swift
//  WritersLens
//
//  Highlights repeated words to encourage vocabulary variation
//

import Foundation
import AppKit
import NaturalLanguage
import SwiftUI

struct RepetitionLens: WritingLens {
    let id = "repetition"
    let name = "Word Repetition"
    let description = "Highlights words used 3+ times to vary vocabulary"
    let category = "Style"
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
