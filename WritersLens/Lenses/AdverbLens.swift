//
//  AdverbLens.swift
//  WritersLens
//
//  Highlights adverbs and -ly words for concise writing
//

import Foundation
import AppKit
import NaturalLanguage
import SwiftUI

struct AdverbLens: WritingLens {
    let id = "adverbs"
    let name = "Adverb Overuse"
    let description = "Highlights adverbs and -ly words for concise writing"
    let category = "Style"

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
