//
//  FlexokiColors.swift
//  freewrite
//
//  Flexoki color palette - an inky color scheme for prose and code
//  https://github.com/kepano/flexoki
//

import SwiftUI
import AppKit

/// Flexoki color palette with semantic color roles
struct FlexokiColors {

    // MARK: - Base Colors (Grayscale)

    /// Off-white paper background
    static let paper = Color(hex: "FFFCF0")

    /// Deepest black
    static let black = Color(hex: "100F0F")

    // Base palette from lightest to darkest
    static let base50 = Color(hex: "F2F0E5")
    static let base100 = Color(hex: "E6E4D9")
    static let base150 = Color(hex: "DAD8CE")
    static let base200 = Color(hex: "CECDC3")
    static let base300 = Color(hex: "B7B5AC")
    static let base400 = Color(hex: "9F9D96")
    static let base500 = Color(hex: "878580")
    static let base600 = Color(hex: "6F6E69")
    static let base700 = Color(hex: "575653")
    static let base800 = Color(hex: "403E3C")
    static let base850 = Color(hex: "343331")
    static let base900 = Color(hex: "282726")
    static let base950 = Color(hex: "1C1B1A")

    // MARK: - Accent Colors (Light Mode - 600 values)

    struct Light {
        static let red = Color(hex: "AF3029")
        static let orange = Color(hex: "BC5215")
        static let yellow = Color(hex: "AD8301")
        static let green = Color(hex: "66800B")
        static let cyan = Color(hex: "24837B")
        static let blue = Color(hex: "205EA6")
        static let purple = Color(hex: "5E409D")
        static let magenta = Color(hex: "A02F6F")
    }

    // MARK: - Accent Colors (Dark Mode - 400 values)

    struct Dark {
        static let red = Color(hex: "D14D41")
        static let orange = Color(hex: "DA702C")
        static let yellow = Color(hex: "D0A215")
        static let green = Color(hex: "879A39")
        static let cyan = Color(hex: "3AA99F")
        static let blue = Color(hex: "4385BE")
        static let purple = Color(hex: "8B7EC8")
        static let magenta = Color(hex: "CE5D97")
    }

    // MARK: - Semantic Color Roles

    /// Primary text color
    static func tx(for scheme: ColorScheme) -> Color {
        scheme == .light ? base950 : base100
    }

    /// Secondary text color (muted)
    static func tx2(for scheme: ColorScheme) -> Color {
        scheme == .light ? base700 : base300
    }

    /// Tertiary text color (faint)
    static func tx3(for scheme: ColorScheme) -> Color {
        scheme == .light ? base500 : base500
    }

    /// Primary background color
    static func bg(for scheme: ColorScheme) -> Color {
        scheme == .light ? paper : black
    }

    /// Secondary background color
    static func bg2(for scheme: ColorScheme) -> Color {
        scheme == .light ? base50 : base950
    }

    /// UI element background (normal)
    static func ui(for scheme: ColorScheme) -> Color {
        scheme == .light ? base100 : base850
    }

    /// UI element background (hover)
    static func ui2(for scheme: ColorScheme) -> Color {
        scheme == .light ? base200 : base800
    }

    /// UI element background (active)
    static func ui3(for scheme: ColorScheme) -> Color {
        scheme == .light ? base300 : base700
    }

    // MARK: - Accent Color Helpers

    /// Get accent color for current color scheme
    static func red(for scheme: ColorScheme) -> Color {
        scheme == .light ? Light.red : Dark.red
    }

    static func orange(for scheme: ColorScheme) -> Color {
        scheme == .light ? Light.orange : Dark.orange
    }

    static func yellow(for scheme: ColorScheme) -> Color {
        scheme == .light ? Light.yellow : Dark.yellow
    }

    static func green(for scheme: ColorScheme) -> Color {
        scheme == .light ? Light.green : Dark.green
    }

    static func cyan(for scheme: ColorScheme) -> Color {
        scheme == .light ? Light.cyan : Dark.cyan
    }

    static func blue(for scheme: ColorScheme) -> Color {
        scheme == .light ? Light.blue : Dark.blue
    }

    static func purple(for scheme: ColorScheme) -> Color {
        scheme == .light ? Light.purple : Dark.purple
    }

    static func magenta(for scheme: ColorScheme) -> Color {
        scheme == .light ? Light.magenta : Dark.magenta
    }

    // MARK: - NSColor Variants (for AppKit components)

    struct NS {
        static let paper = NSColor(hex: "FFFCF0")
        static let black = NSColor(hex: "100F0F")

        static let base50 = NSColor(hex: "F2F0E5")
        static let base100 = NSColor(hex: "E6E4D9")
        static let base150 = NSColor(hex: "DAD8CE")
        static let base200 = NSColor(hex: "CECDC3")
        static let base300 = NSColor(hex: "B7B5AC")
        static let base400 = NSColor(hex: "9F9D96")
        static let base500 = NSColor(hex: "878580")
        static let base600 = NSColor(hex: "6F6E69")
        static let base700 = NSColor(hex: "575653")
        static let base800 = NSColor(hex: "403E3C")
        static let base850 = NSColor(hex: "343331")
        static let base900 = NSColor(hex: "282726")
        static let base950 = NSColor(hex: "1C1B1A")

        struct Light {
            static let red = NSColor(hex: "AF3029")
            static let orange = NSColor(hex: "BC5215")
            static let yellow = NSColor(hex: "AD8301")
            static let green = NSColor(hex: "66800B")
            static let cyan = NSColor(hex: "24837B")
            static let blue = NSColor(hex: "205EA6")
            static let purple = NSColor(hex: "5E409D")
            static let magenta = NSColor(hex: "A02F6F")
        }

        struct Dark {
            static let red = NSColor(hex: "D14D41")
            static let orange = NSColor(hex: "DA702C")
            static let yellow = NSColor(hex: "D0A215")
            static let green = NSColor(hex: "879A39")
            static let cyan = NSColor(hex: "3AA99F")
            static let blue = NSColor(hex: "4385BE")
            static let purple = NSColor(hex: "8B7EC8")
            static let magenta = NSColor(hex: "CE5D97")
        }

        static func tx(for scheme: ColorScheme) -> NSColor {
            scheme == .light ? base950 : base100
        }

        static func tx2(for scheme: ColorScheme) -> NSColor {
            scheme == .light ? base700 : base300
        }

        static func bg(for scheme: ColorScheme) -> NSColor {
            scheme == .light ? paper : black
        }

        static func red(for scheme: ColorScheme) -> NSColor {
            scheme == .light ? Light.red : Dark.red
        }

        static func orange(for scheme: ColorScheme) -> NSColor {
            scheme == .light ? Light.orange : Dark.orange
        }

        static func yellow(for scheme: ColorScheme) -> NSColor {
            scheme == .light ? Light.yellow : Dark.yellow
        }

        static func green(for scheme: ColorScheme) -> NSColor {
            scheme == .light ? Light.green : Dark.green
        }

        static func cyan(for scheme: ColorScheme) -> NSColor {
            scheme == .light ? Light.cyan : Dark.cyan
        }

        static func blue(for scheme: ColorScheme) -> NSColor {
            scheme == .light ? Light.blue : Dark.blue
        }

        static func purple(for scheme: ColorScheme) -> NSColor {
            scheme == .light ? Light.purple : Dark.purple
        }

        static func magenta(for scheme: ColorScheme) -> NSColor {
            scheme == .light ? Light.magenta : Dark.magenta
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - NSColor Extension

extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}
