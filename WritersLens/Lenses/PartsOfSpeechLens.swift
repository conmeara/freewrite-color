//
//  PartsOfSpeechLens.swift
//  WritersLens
//
//  Colors nouns, verbs, and adjectives by grammatical role
//

import Foundation
import AppKit
import NaturalLanguage
import SwiftUI

struct PartsOfSpeechLens: WritingLens {
    let id = "pos"
    let name = "Parts of Speech"
    let description = "Colors nouns (blue), verbs (orange), adjectives (yellow)"
    let category = "Grammar"

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
