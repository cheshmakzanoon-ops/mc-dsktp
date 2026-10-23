import AppKit
import SwiftUI
import FrameScriptCore

struct MainWindow: View {
    @ObservedObject var store: EditorStore

    var body: some View {
        VStack(spacing: 0) {
            TopBar(store: store)
            HStack(spacing: 0) {
                SidebarView(store: store)
                    .frame(width: 276)
                Rectangle()
                    .fill(Color(hex: 0xD9DEE5))
                    .frame(width: 1)
                EditorWorkspace(store: store)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            StatusBar(store: store)
        }
        .background(Color(hex: 0xEEF1F5))
        .onAppear {
            if ProcessInfo.processInfo.environment["FRAMESCRIPT_SCREENSHOT_MODE"] != nil {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        .alert("FrameScript", isPresented: Binding(
            get: { store.alertMessage != nil },
            set: { if !$0 { store.alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { store.alertMessage = nil }
        } message: {
            Text(store.alertMessage ?? "")
        }
    }
}

private struct TopBar: View {
    @ObservedObject var store: EditorStore

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color(hex: 0x193B46))
                        .frame(width: 34, height: 34)
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xF3C577))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("FRAME")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(1.8)
                        .foregroundStyle(Color(hex: 0x193B46))
                    Text("SCRIPT")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .tracking(2.1)
                        .foregroundStyle(Color(hex: 0x71808B))
                }
            }
            .padding(.trailing, 8)

            Rectangle().fill(Color(hex: 0xD9DEE5)).frame(width: 1, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                TextField("Screenplay title", text: $store.title)
                    .font(.system(size: 14, weight: .semibold))
                    .textFieldStyle(.plain)
                    .frame(maxWidth: 310)
                Text(store.documentName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(hex: 0x84909A))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: 0x87939D))
                TextField("Find in screenplay", text: $store.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .frame(width: 148)
                    .onSubmit { store.findNextMatch() }
                Button(action: store.findNextMatch) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x53636E))
                }
                .buttonStyle(.plain)
                .help("Find next")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(hex: 0xF4F6F8), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: 0xE0E4E9), lineWidth: 1))

            Button(action: store.newScreenplay) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(QuietToolbarButtonStyle())
            .help("New screenplay")

            Button(action: store.open) {
                Image(systemName: "folder")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(QuietToolbarButtonStyle())
            .help("Open screenplay")

            Button(action: store.save) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(QuietToolbarButtonStyle())
            .help("Save screenplay")

            Menu {
                Button(action: store.exportPDF) {
                    Label("Export PDF…", systemImage: "doc.richtext")
                }
                Button(action: store.exportFDX) {
                    Label("Export Final Draft XML…", systemImage: "curlybraces")
                }
                Button(action: store.saveAsFountain) {
                    Label("Save Fountain File…", systemImage: "text.alignleft")
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Export")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(Color(hex: 0x193B46), in: RoundedRectangle(cornerRadius: 8))
            }
            .menuStyle(.borderlessButton)
            .help("Export screenplay")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.white)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(hex: 0xD9DEE5)).frame(height: 1)
        }
    }
}

private struct StatusBar: View {
    @ObservedObject var store: EditorStore

    var body: some View {
        HStack(spacing: 18) {
            Label("\(store.pageCount) pages", systemImage: "doc.text")
            Label("\(store.wordCount) words", systemImage: "character.cursor.ibeam")
            if let selected = store.selectedID, let element = store.element(for: selected) {
                Text(element.type.displayName.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Color(hex: 0x647783))
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color(hex: 0x4D8A76))
            Text(store.lastSavedLabel)
                .foregroundStyle(Color(hex: 0x71808B))
        }
        .font(.system(size: 10, weight: .medium))
        .padding(.horizontal, 18)
        .frame(height: 30)
        .background(Color.white)
        .overlay(alignment: .top) {
            Rectangle().fill(Color(hex: 0xD9DEE5)).frame(height: 1)
        }
    }
}

private struct QuietToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color(hex: 0x52636D))
            .background(configuration.isPressed ? Color(hex: 0xE8EDF0) : Color.clear, in: RoundedRectangle(cornerRadius: 7))
            .contentShape(RoundedRectangle(cornerRadius: 7))
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
