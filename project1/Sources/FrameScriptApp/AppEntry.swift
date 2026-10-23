import AppKit
import SwiftUI
import FrameScriptCore

@main
struct FrameScriptApp: App {
    @StateObject private var store = EditorStore()

    var body: some Scene {
        WindowGroup {
            MainWindow(store: store)
                .frame(minWidth: 1160, minHeight: 760)
                .preferredColorScheme(.light)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Screenplay") { store.newScreenplay() }
                    .keyboardShortcut("n", modifiers: .command)
                Button("Open…") { store.open() }
                    .keyboardShortcut("o", modifiers: .command)
            }
            CommandGroup(after: .saveItem) {
                Button("Save Screenplay") { store.save() }
                    .keyboardShortcut("s", modifiers: .command)
                Button("Export as PDF…") { store.exportPDF() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }
    }
}
