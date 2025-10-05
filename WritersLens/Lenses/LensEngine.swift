//
//  LensEngine.swift
//  WritersLens
//
//  Coordinates all writing lenses for text analysis
//

import Foundation
import SwiftUI

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

        // Tokenize once
        let document = tokenizer.tokenize(text)

        // Run all lenses in parallel
        return await withTaskGroup(of: [Highlight].self) { group in
            for lens in activeLenses {
                group.addTask { await lens.analyze(document: document, colorScheme: colorScheme) }
            }

            var allHighlights: [Highlight] = []
            for await highlights in group {
                allHighlights.append(contentsOf: highlights)
            }
            return allHighlights
        }
    }
}
