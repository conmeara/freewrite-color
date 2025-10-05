//
//  DataModels.swift
//  WritersLens
//
//  Shared data models for the lens system
//

import Foundation
import AppKit
import NaturalLanguage
import SwiftUI

// MARK: - Token & Document Models

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

// MARK: - Highlight Models

struct Highlight {
    let range: NSRange
    let color: NSColor
    let category: String
    let priority: Int  // 0=background, 1=low, 2=medium, 3=high
}

struct RelativeHighlight: Codable, Equatable {
    let offsetFromSentenceStart: Int
    let length: Int
    let color: CodableColor
    let matchText: String
}

struct CodableColor: Codable, Equatable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    init(_ nsColor: NSColor) {
        // Convert to RGB color space if needed
        let rgbColor = nsColor.usingColorSpace(.deviceRGB) ?? nsColor
        self.red = rgbColor.redComponent
        self.green = rgbColor.greenComponent
        self.blue = rgbColor.blueComponent
        self.alpha = rgbColor.alphaComponent
    }

    var nsColor: NSColor {
        NSColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}
