//
//  TextAnalysisTest.swift
//  freewrite
//
//  Simple MVP test of FoundationModels for text sentiment coloring
//

import SwiftUI
import FoundationModels
import Observation

// Define what we want the AI to extract from text
@available(macOS 26.0, *)
@Generable
struct TextAnalysis: Equatable {
    @Guide(description: "A list of text segments with their emotional tone")
    let segments: [TextSegment]
}

@available(macOS 26.0, *)
@Generable
struct TextSegment: Equatable {
    @Guide(description: "The exact text content of this segment")
    let text: String

    @Guide(description: "The emotional tone: positive, negative, or neutral")
    @Guide(.anyOf(["positive", "negative", "neutral"]))
    let sentiment: String

    @Guide(description: "The primary emotion: joy, sadness, anger, fear, or calm")
    @Guide(.anyOf(["joy", "sadness", "anger", "fear", "calm"]))
    let emotion: String
}

@available(macOS 26.0, *)
@Observable
@MainActor
class TextAnalyzer {
    private(set) var analysis: TextAnalysis.PartiallyGenerated?
    private var session: LanguageModelSession
    var error: Error?

    init() {
        self.session = LanguageModelSession(
            instructions: Instructions {
                """
                Your job is to analyze the emotional tone of text.
                Break the text into logical segments (sentences or phrases) and identify:
                1. The sentiment (positive, negative, or neutral)
                2. The primary emotion (joy, sadness, anger, fear, or calm)

                Be specific about which parts of the text express different emotions.
                """
            }
        )
    }

    func analyze(text: String) async throws {
        let stream = session.streamResponse(
            generating: TextAnalysis.self,
            includeSchemaInPrompt: false,
            options: GenerationOptions(sampling: .greedy)
        ) {
            "Analyze the emotional content of this text:"
            text
        }

        for try await partialResponse in stream {
            analysis = partialResponse.content
        }
    }
}

// Simple test view
@available(macOS 26.0, *)
struct TextAnalysisTestView: View {
    @State private var analyzer = TextAnalyzer()
    @State private var inputText = "I'm so excited about this project! But I'm also worried it might be too complex. Still, I'm determined to make it work."
    @State private var isAnalyzing = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Text Analysis MVP Test")
                .font(.title)

            TextEditor(text: $inputText)
                .frame(height: 100)
                .border(Color.gray)
                .padding()

            Button("Analyze Text") {
                isAnalyzing = true
                Task {
                    do {
                        try await analyzer.analyze(text: inputText)
                        isAnalyzing = false
                    } catch {
                        analyzer.error = error
                        isAnalyzing = false
                    }
                }
            }
            .disabled(isAnalyzing)

            if isAnalyzing {
                ProgressView("Analyzing...")
            }

            // Display results
            if let analysis = analyzer.analysis {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Analysis Results:")
                        .font(.headline)

                    ForEach(analysis.segments?.indices ?? 0..<0, id: \.self) { index in
                        if let segment = analysis.segments?[index] {
                            HStack {
                                Text(segment.text ?? "")
                                    .foregroundColor(colorForSentiment(segment.sentiment ?? "neutral"))
                                    .padding(8)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(4)

                                Text("[\(segment.emotion ?? "unknown")]")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()
            }

            if let error = analyzer.error {
                Text("Error: \(error.localizedDescription)")
                    .foregroundColor(.red)
            }

            Spacer()
        }
        .padding()
        .frame(width: 600, height: 500)
    }

    private func colorForSentiment(_ sentiment: String) -> Color {
        switch sentiment.lowercased() {
        case "positive":
            return .green
        case "negative":
            return .red
        default:
            return .primary
        }
    }
}

#Preview {
    if #available(macOS 26.0, *) {
        TextAnalysisTestView()
    }
}
