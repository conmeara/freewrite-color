//
//  SentenceLengthLens.swift
//  WritersLens
//
//  Shows sentence variety through color coding
//

import Foundation
import AppKit
import NaturalLanguage
import SwiftUI

struct SentenceLengthLens: WritingLens {
    let id = "sentence-length"
    let name = "Sentence Length"
    let description = "Shows sentence variety: green (short), yellow (medium), red (long)"
    let category = "Readability"

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
