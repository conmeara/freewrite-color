
import SwiftUI

@main
struct WritersLensApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("colorScheme") private var colorSchemeString: String = "light"
    
    init() {
        // Register Lato font
        if let fontURL = Bundle.main.url(forResource: "Lato-Regular", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
        }
    }
     
    var body: some Scene {
        WindowGroup {
            ContentView()
                .toolbar(.hidden, for: .windowToolbar)
                .preferredColorScheme(colorSchemeString == "dark" ? .dark : .light)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 600)
        .windowToolbarStyle(.unifiedCompact)
        .windowResizability(.contentSize)
        .commands {
            CommandMenu("Format") {
                Menu("Font") {
                    Button("Lato") {
                        NotificationCenter.default.post(name: .fontChanged, object: "Lato-Regular")
                    }
                    .keyboardShortcut("1", modifiers: [.command])

                    Button("Arial") {
                        NotificationCenter.default.post(name: .fontChanged, object: "Arial")
                    }
                    .keyboardShortcut("2", modifiers: [.command])

                    Button("System") {
                        NotificationCenter.default.post(name: .fontChanged, object: ".AppleSystemUIFont")
                    }
                    .keyboardShortcut("3", modifiers: [.command])

                    Button("Serif") {
                        NotificationCenter.default.post(name: .fontChanged, object: "Times New Roman")
                    }
                    .keyboardShortcut("4", modifiers: [.command])

                    Divider()

                    Button("Random") {
                        NotificationCenter.default.post(name: .fontChanged, object: "random")
                    }
                    .keyboardShortcut("5", modifiers: [.command])
                }

                Menu("Size") {
                    ForEach([16, 18, 20, 22, 24, 26], id: \.self) { size in
                        Button("\(size)px") {
                            NotificationCenter.default.post(name: .fontSizeChanged, object: size)
                        }
                    }
                }
            }

            CommandGroup(replacing: .appInfo) {
                Button("About Writers Lens") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            .applicationName: "Writers Lens",
                            .applicationVersion: "1.0",
                            .credits: NSAttributedString(string: "Based on Freewrite by Farza\ngithub.com/farzaa/freewrite\n\nWriters Lens adds real-time writing analysis with multiple lenses for improving your prose.")
                        ]
                    )
                }
            }
        }
    }
}

// Add AppDelegate to handle window configuration
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let window = NSApplication.shared.windows.first {
            // Ensure window starts in windowed mode
            if window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
            }

            // Center the window on the screen
            window.center()
        }
    }
}

// Notification extensions for menu commands
extension Notification.Name {
    static let fontChanged = Notification.Name("fontChanged")
    static let fontSizeChanged = Notification.Name("fontSizeChanged")
}
