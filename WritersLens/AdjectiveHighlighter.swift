//
//  AdjectiveHighlighter.swift
//  freewrite
//
//  Simple adjective highlighter using FoundationModels
//

import Foundation
import FoundationModels
import Observation

@available(macOS 26.0, *)
@Generable
struct AdjectiveAnalysis: Equatable {
    @Guide(description: "A list of adjectives found in the text with their positions")
    let adjectives: [AdjectiveMatch]
}

@available(macOS 26.0, *)
@Generable
struct AdjectiveMatch: Equatable {
    @Guide(description: "The exact adjective word")
    let word: String

    @Guide(description: "The position of the first character of this word in the original text (0-indexed)")
    let startIndex: Int
}

@available(macOS 26.0, *)
@Observable
@MainActor
class AdjectiveHighlighter {
    private(set) var analysis: AdjectiveAnalysis.PartiallyGenerated?
    private var session: LanguageModelSession
    var error: Error?

    init() {
        self.session = LanguageModelSession(
            instructions: Instructions {
                """
                Your job is to find all adjectives in the provided text.

                Return each adjective with its exact starting position in the text.
                The position should be 0-indexed (first character is position 0).

                Only identify true adjectives (descriptive words that modify nouns).
                Be precise about the position - count characters from the beginning.
                """
            }
        )
    }

    func findAdjectives(in text: String) async throws -> [AdjectiveMatch] {
        let stream = session.streamResponse(
            generating: AdjectiveAnalysis.self,
            includeSchemaInPrompt: false,
            options: GenerationOptions(sampling: .greedy)
        ) {
            "Find all adjectives in this text and their positions:"
            text
        }

        var result: [AdjectiveMatch] = []
        for try await partialResponse in stream {
            analysis = partialResponse.content

            // Extract completed adjectives from partially generated array
            if let partialAdjectives = partialResponse.content.adjectives {
                result = []
                for i in 0..<partialAdjectives.count {
                    if let word = partialAdjectives[i].word,
                       let startIndex = partialAdjectives[i].startIndex {
                        result.append(AdjectiveMatch(word: word, startIndex: startIndex))
                    }
                }
            }
        }

        return result
    }
}
