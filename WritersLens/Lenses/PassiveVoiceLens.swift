//
//  PassiveVoiceLens.swift
//  WritersLens
//
//  Highlights passive voice constructions
//

import Foundation
import AppKit
import NaturalLanguage
import SwiftUI

struct PassiveVoiceLens: WritingLens {
    let id = "passive"
    let name = "Passive Voice"
    let description = "Highlights passive constructions to encourage active voice"
    let category = "Style"

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
