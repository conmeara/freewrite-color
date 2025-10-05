//
//  WritingLens.swift
//  WritersLens
//
//  Protocol for writing analysis lenses
//

import Foundation
import SwiftUI

protocol WritingLens {
    var id: String { get }
    var name: String { get }
    var description: String { get }
    var category: String { get }

    func analyze(document: TextDocument, colorScheme: ColorScheme) async -> [Highlight]
}
