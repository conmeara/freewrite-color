//
//  AdjectiveHighlightTestView.swift
//  freewrite
//
//  Simple test view for adjective highlighting
//

import SwiftUI
import AppKit

@available(macOS 26.0, *)
struct AdjectiveHighlightTestView: View {
    @State private var text = "This is a beautiful sunny day. I feel happy and excited about the amazing possibilities."
    @State private var highlightRanges: [(range: NSRange, color: NSColor)] = []
    @State private var highlighter = AdjectiveHighlighter()
    @State private var isAnalyzing = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Adjective Highlighter Test")
                .font(.title)

            ColoredTextEditor(
                text: $text,
                highlightRanges: $highlightRanges,
                font: NSFont(name: "Lato-Regular", size: 18) ?? .systemFont(ofSize: 18),
                textColor: .black,
                backgroundColor: .white,
                lineSpacing: 8
            )
            .frame(height: 300)
            .border(Color.gray)

            HStack {
                Button("Highlight Adjectives") {
                    Task {
                        await analyzeText()
                    }
                }
                .disabled(isAnalyzing)

                Button("Clear Highlights") {
                    highlightRanges = []
                }

                if isAnalyzing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if let error = highlighter.error {
                Text("Error: \(error.localizedDescription)")
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Spacer()
        }
        .padding()
        .frame(width: 700, height: 500)
    }

    private func analyzeText() async {
        isAnalyzing = true
        highlightRanges = []

        do {
            let adjectives = try await highlighter.findAdjectives(in: text)

            // Convert adjective positions to NSRange and apply yellow color
            var ranges: [(range: NSRange, color: NSColor)] = []

            for adj in adjectives {
                let nsRange = NSRange(location: adj.startIndex, length: adj.word.count)
                ranges.append((range: nsRange, color: .yellow))
            }

            highlightRanges = ranges
            isAnalyzing = false
        } catch {
            highlighter.error = error
            isAnalyzing = false
        }
    }
}

#Preview {
    if #available(macOS 26.0, *) {
        AdjectiveHighlightTestView()
    }
}
