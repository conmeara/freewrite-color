//
//  Tokenizer.swift
//  WritersLens
//
//  Tokenization and text parsing using Natural Language framework
//

import Foundation
import NaturalLanguage

class Tokenizer {
    func tokenize(_ text: String) -> TextDocument {
        var tokens: [Token] = []
        var sentences: [Sentence] = []

        // Setup NaturalLanguage framework
        let sentenceTokenizer = NLTokenizer(unit: .sentence)
        let wordTokenizer = NLTokenizer(unit: .word)
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])

        sentenceTokenizer.string = text
        tagger.string = text

        // Enumerate sentences
        sentenceTokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { sentenceRange, _ in
            var sentenceTokens: [Token] = []
            wordTokenizer.string = text

            // Enumerate words in sentence
            wordTokenizer.enumerateTokens(in: sentenceRange) { tokenRange, _ in
                let tokenText = String(text[tokenRange])
                let nsRange = NSRange(tokenRange, in: text)

                let lexicalClass = tagger.tag(at: tokenRange.lowerBound,
                                             unit: .word,
                                             scheme: .lexicalClass).0
                let lemma = tagger.tag(at: tokenRange.lowerBound,
                                      unit: .word,
                                      scheme: .lemma).0?.rawValue

                let token = Token(text: tokenText,
                                range: nsRange,
                                lexicalClass: lexicalClass,
                                lemma: lemma)
                sentenceTokens.append(token)
                tokens.append(token)
                return true
            }

            let sentenceText = String(text[sentenceRange])
            let sentenceNSRange = NSRange(sentenceRange, in: text)
            sentences.append(Sentence(text: sentenceText,
                                    range: sentenceNSRange,
                                    tokens: sentenceTokens))
            return true
        }

        // Build lookup caches
        var lemmaMap: [String: [Token]] = [:]
        var freqMap: [String: Int] = [:]

        for token in tokens {
            if let lemma = token.lemma?.lowercased() {
                lemmaMap[lemma, default: []].append(token)
            }
            freqMap[token.text.lowercased(), default: 0] += 1
        }

        return TextDocument(text: text,
                           tokens: tokens,
                           sentences: sentences,
                           tokensByLemma: lemmaMap,
                           wordFrequency: freqMap)
    }
}
