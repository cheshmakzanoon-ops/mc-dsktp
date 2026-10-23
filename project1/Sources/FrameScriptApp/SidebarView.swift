import SwiftUI
import FrameScriptCore

struct SidebarView: View {
    @ObservedObject var store: EditorStore
    @State private var activeSection: SidebarSection = .scenes

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("NAVIGATOR")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Color(hex: 0x687984))
                Spacer()
                Button(action: store.addScene) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x55717A))
                        .frame(width: 26, height: 26)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 7))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color(hex: 0xDCE2E7), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help("Add scene")
            }
            .padding(.horizontal, 17)
            .padding(.top, 18)
            .padding(.bottom, 13)

            HStack(spacing: 4) {
                sectionButton(.scenes, icon: "rectangle.stack")
                sectionButton(.characters, icon: "person.2")
            }
            .padding(4)
            .background(Color(hex: 0xE4E9ED), in: RoundedRectangle(cornerRadius: 9))
            .padding(.horizontal, 15)
            .padding(.bottom, 12)

            if activeSection == .scenes {
                scenesList
            } else {
                charactersList
            }

            Spacer(minLength: 8)

            titlePagePanel
        }
        .background(Color(hex: 0xF7F8FA))
    }

    private var scenesList: some View {
        ScrollView {
            LazyVStack(spacing: 5) {
                if store.sceneSummaries.isEmpty {
                    emptyState(icon: "rectangle.stack", title: "No scenes yet", subtitle: "Add a scene heading to start.")
                } else {
                    ForEach(store.sceneSummaries) { scene in
                        Button {
                            store.select(scene.id)
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Text(String(format: "%02d", scene.number))
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Color(hex: 0x8A989F))
                                    .frame(width: 24, alignment: .leading)
                                    .padding(.top, 2)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(scene.heading.isEmpty ? "UNTITLED SCENE" : scene.heading)
                                        .font(.system(size: 10, weight: .bold))
                                        .tracking(0.25)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                        .foregroundStyle(Color(hex: 0x263943))
                                    Text(scene.preview)
                                        .font(.system(size: 10))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                        .foregroundStyle(Color(hex: 0x86939C))
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(store.selectedID == scene.id ? Color(hex: 0xE7EFF0) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(alignment: .leading) {
                                if store.selectedID == scene.id {
                                    Capsule().fill(Color(hex: 0xD1974B)).frame(width: 3).padding(.vertical, 8)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 11)
            .padding(.top, 2)
        }
    }

    private var charactersList: some View {
        ScrollView {
            LazyVStack(spacing: 5) {
                if store.characters.isEmpty {
                    emptyState(icon: "person.2", title: "No characters yet", subtitle: "Character cues appear here.")
                } else {
                    ForEach(Array(store.characters.enumerated()), id: \.element) { index, character in
                        Button {
                            store.jumpToCharacter(character)
                        } label: {
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle().fill(Color(hex: 0xE5ECEB)).frame(width: 28, height: 28)
                                    Text(String(character.prefix(1)))
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color(hex: 0x35636B))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(character)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(Color(hex: 0x263943))
                                    Text("Character \(index + 1)")
                                        .font(.system(size: 9))
                                        .foregroundStyle(Color(hex: 0x86939C))
                                }
                                Spacer()
                                Image(systemName: "arrow.up.left")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(Color(hex: 0xA2ADB4))
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 8)
                            .background(Color.clear, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 11)
        }
    }

    private var titlePagePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "text.page")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xA87632))
                Text("TITLE PAGE")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Color(hex: 0x71808B))
            }
            TextField("Screenplay title", text: $store.title)
                .font(.system(size: 11, weight: .semibold))
                .textFieldStyle(.plain)
            TextField("Written by", text: $store.author)
                .font(.system(size: 10))
                .textFieldStyle(.plain)
            TextField("Contact", text: $store.contact)
                .font(.system(size: 10))
                .textFieldStyle(.plain)
        }
        .padding(13)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color(hex: 0xE2E6EA), lineWidth: 1))
        .padding(.horizontal, 14)
        .padding(.bottom, 15)
    }

    private func sectionButton(_ section: SidebarSection, icon: String) -> some View {
        Button {
            activeSection = section
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(section.title)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(activeSection == section ? Color(hex: 0x294A53) : Color(hex: 0x74838D))
            .frame(maxWidth: .infinity)
            .frame(height: 27)
            .background(activeSection == section ? Color.white : Color.clear, in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
    }

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color(hex: 0xA7B2B8))
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(hex: 0x687984))
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(Color(hex: 0x98A3AA))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
}

private enum SidebarSection {
    case scenes
    case characters

    var title: String {
        switch self {
        case .scenes: "Scenes"
        case .characters: "Cast"
        }
    }
}
