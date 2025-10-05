//
//  ColoredTextEditor.swift
//  freewrite
//
//  Custom text editor that supports attributed text coloring
//

import SwiftUI
import AppKit

struct ColoredTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var highlightRanges: [(range: NSRange, color: NSColor)]

    var font: NSFont
    var textColor: NSColor
    var backgroundColor: NSColor
    var lineSpacing: CGFloat
    var maxWidth: CGFloat = 650

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        // Configure text view
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.font = font
        textView.textColor = textColor
        textView.backgroundColor = backgroundColor
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.drawsBackground = true

        // Set up text container for centered 650px width
        if let textContainer = textView.textContainer {
            textContainer.widthTracksTextView = false
            textContainer.containerSize = NSSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude)
            textContainer.lineFragmentPadding = 0

            // Apply line spacing
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = lineSpacing
            textView.defaultParagraphStyle = paragraphStyle
        }

        // Configure text view insets
        textView.textContainerInset = NSSize(width: 0, height: 0)

        // Hide scrollers
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear

        // Center the text view horizontally
        scrollView.contentView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { _ in
            centerTextView(scrollView: scrollView, textView: textView, maxWidth: maxWidth)
        }

        // Set initial cursor position after the leading "\n\n"
        DispatchQueue.main.async {
            if textView.string.hasPrefix("\n\n") {
                textView.setSelectedRange(NSRange(location: 2, length: 0))
            }
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Update font, color, background if changed
        context.coordinator.font = font
        context.coordinator.textColor = textColor
        context.coordinator.lineSpacing = lineSpacing
        textView.font = font
        textView.textColor = textColor
        textView.backgroundColor = backgroundColor

        // Center the text view
        centerTextView(scrollView: scrollView, textView: textView, maxWidth: maxWidth)

        // Only update if text changed (avoid cursor jump)
        if textView.string != text {
            // Save cursor position
            let selectedRange = textView.selectedRange()

            // Update text
            textView.string = text

            // Restore cursor position
            if selectedRange.location <= text.count {
                textView.setSelectedRange(selectedRange)
            }
        }

        // Apply base styling
        let fullRange = NSRange(location: 0, length: text.count)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing

        textView.textStorage?.setAttributes([
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ], range: fullRange)

        // Apply highlight colors
        for (range, color) in highlightRanges {
            // Validate range
            if range.location >= 0 && range.location + range.length <= text.count {
                textView.textStorage?.addAttribute(.foregroundColor, value: color, range: range)
            }
        }
    }

    private func centerTextView(scrollView: NSScrollView, textView: NSTextView, maxWidth: CGFloat) {
        let scrollViewWidth = scrollView.contentView.bounds.width
        if scrollViewWidth > maxWidth {
            let leftInset = (scrollViewWidth - maxWidth) / 2
            textView.textContainerInset = NSSize(width: leftInset, height: 0)
        } else {
            textView.textContainerInset = NSSize(width: 0, height: 0)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, font: font, textColor: textColor, lineSpacing: lineSpacing)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var font: NSFont
        var textColor: NSColor
        var lineSpacing: CGFloat

        init(text: Binding<String>, font: NSFont, textColor: NSColor, lineSpacing: CGFloat) {
            self.text = text
            self.font = font
            self.textColor = textColor
            self.lineSpacing = lineSpacing
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }

            // Apply styling to new text immediately
            let fullRange = NSRange(location: 0, length: textView.string.count)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = lineSpacing

            textView.textStorage?.setAttributes([
                .font: font,
                .foregroundColor: textColor,
                .paragraphStyle: paragraphStyle
            ], range: fullRange)

            text.wrappedValue = textView.string
        }
    }
}
