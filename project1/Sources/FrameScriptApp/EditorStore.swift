import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers
import FrameScriptCore

struct SceneSummary: Identifiable {
    let id: UUID
    let number: Int
    let heading: String
    let preview: String
}

enum NavigatorSection: Equatable {
    case scenes
    case characters

    var title: String {
        switch self {
        case .scenes: "Scenes"
        case .characters: "Cast"
        }
    }
}

@MainActor
final class EditorStore: ObservableObject {
    @Published var title: String {
        didSet { scheduleAutosave() }
    }
    @Published var author: String {
        didSet { scheduleAutosave() }
    }
    @Published var contact: String {
        didSet { scheduleAutosave() }
    }
    @Published var elements: [ScriptElement] {
        didSet { scheduleAutosave() }
    }
    @Published var selectedID: UUID?
    @Published var alertMessage: String?
    @Published var documentName = "Untitled Screenplay"
    @Published var lastSavedLabel = "Autosave ready"
    @Published var searchText = ""
    @Published var searchMatchID: UUID?
    @Published var activeSection: NavigatorSection = .scenes

    private(set) var currentFileURL: URL?
    private var autosaveWorkItem: DispatchWorkItem?

    init() {
        let showcaseMode = Int(ProcessInfo.processInfo.environment["FRAMESCRIPT_SCREENSHOT_MODE"] ?? "") ?? 0
        if showcaseMode > 0 {
            let snapshot = Self.showcaseSnapshot(showcaseMode)
            title = snapshot.title
            author = snapshot.author
            contact = snapshot.contact
            elements = snapshot.elements
            selectedID = snapshot.elements.first?.id
            documentName = snapshot.title
            switch showcaseMode {
            case 2:
                selectedID = snapshot.elements.first(where: { $0.type == .character })?.id
            case 3:
                activeSection = .characters
                selectedID = snapshot.elements.first(where: { $0.type == .character })?.id
            case 4:
                searchText = "MARA"
                selectedID = snapshot.elements.first(where: { $0.type == .character })?.id
            case 5:
                selectedID = snapshot.elements.last(where: { $0.type == .sceneHeading })?.id
            case 6, 10:
                selectedID = snapshot.elements.last?.id
            case 9:
                selectedID = snapshot.elements.last(where: { $0.type == .sceneHeading })?.id
            default:
                break
            }
        } else if let snapshot = Self.readAutosave() {
            title = snapshot.title
            author = snapshot.author
            contact = snapshot.contact
            elements = snapshot.elements
            selectedID = snapshot.elements.first?.id
            documentName = snapshot.title.isEmpty ? "Untitled Screenplay" : snapshot.title
        } else {
            let snapshot = ScreenplaySnapshot.sample
            title = snapshot.title
            author = snapshot.author
            contact = snapshot.contact
            elements = snapshot.elements
            selectedID = snapshot.elements.first?.id
            documentName = snapshot.title
        }
    }

    var snapshot: ScreenplaySnapshot {
        ScreenplaySnapshot(title: title, author: author, contact: contact, elements: elements)
    }

    var wordCount: Int {
        elements
            .map(\.text)
            .joined(separator: " ")
            .split(whereSeparator: \.isWhitespace)
            .count
    }

    var pageCount: Int {
        max(1, Int(ceil(Double(elements.reduce(0) { $0 + $1.estimatedLines + $1.type.spacingBefore }) / 44.0)))
    }

    var sceneSummaries: [SceneSummary] {
        let headings = elements.indices.filter { elements[$0].type == .sceneHeading }
        return headings.enumerated().map { number, index in
            let next = elements.indices.dropFirst(index + 1).first(where: { elements[$0].type == .sceneHeading })
            let limit = next ?? elements.endIndex
            let preview = elements[(index + 1)..<limit]
                .first(where: { $0.type == .action })?
                .text ?? "No action description yet"
            return SceneSummary(
                id: elements[index].id,
                number: number + 1,
                heading: elements[index].text,
                preview: preview
            )
        }
    }

    var characters: [String] {
        var seen = Set<String>()
        return elements
            .filter { $0.type == .character }
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.uppercased()).inserted }
    }

    func element(for id: UUID) -> ScriptElement? {
        elements.first(where: { $0.id == id })
    }

    func select(_ id: UUID) {
        selectedID = id
    }

    func updateText(id: UUID, text: String) {
        guard let index = elements.firstIndex(where: { $0.id == id }) else { return }
        elements[index].text = text
    }

    func setType(id: UUID, type: ScriptElementType) {
        guard let index = elements.firstIndex(where: { $0.id == id }) else { return }
        elements[index].type = type
    }

    func cycleType(id: UUID) {
        guard let element = element(for: id) else { return }
        setType(id: id, type: element.type.nextByTab())
    }

    func continueAfterReturn(id: UUID) {
        guard let index = elements.firstIndex(where: { $0.id == id }) else { return }
        let current = elements[index]
        let newElement = ScriptElement(
            type: current.type.nextAfterReturn(isEmpty: current.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        )
        elements.insert(newElement, at: index + 1)
        selectedID = newElement.id
    }

    func removeEmptyElement(id: UUID) {
        guard let index = elements.firstIndex(where: { $0.id == id }),
              elements[index].text.isEmpty,
              elements.count > 1 else { return }
        let previousIndex = max(0, index - 1)
        elements.remove(at: index)
        selectedID = elements[previousIndex].id
    }

    func addScene() {
        let newElement = ScriptElement(type: .sceneHeading, text: "INT. NEW SCENE — DAY")
        let index = selectedID.flatMap { id in elements.firstIndex(where: { $0.id == id }) }
        if let index {
            elements.insert(newElement, at: index + 1)
        } else {
            elements.append(newElement)
        }
        selectedID = newElement.id
    }

    func jumpToCharacter(_ name: String) {
        if let element = elements.first(where: {
            $0.type == .character && $0.text.caseInsensitiveCompare(name) == .orderedSame
        }) {
            selectedID = element.id
        }
    }

    func findNextMatch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, !elements.isEmpty else { return }
        let start = selectedID.flatMap { id in elements.firstIndex(where: { $0.id == id }) }.map { $0 + 1 } ?? 0
        let indices = Array(start..<elements.count) + Array(0..<min(start, elements.count))
        if let index = indices.first(where: { elements[$0].text.localizedCaseInsensitiveContains(query) }) {
            selectedID = elements[index].id
            searchMatchID = elements[index].id
        } else {
            searchMatchID = nil
            alertMessage = "No match for “\(query)”."
        }
    }

    func newScreenplay() {
        title = "Untitled Screenplay"
        author = ""
        contact = ""
        let heading = ScriptElement(type: .sceneHeading, text: "INT. NEW SCENE — DAY")
        elements = [heading, ScriptElement(type: .action)]
        selectedID = heading.id
        currentFileURL = nil
        documentName = title
        lastSavedLabel = "New screenplay"
    }

    func open() {
        let panel = NSOpenPanel()
        panel.title = "Open Screenplay"
        panel.allowedContentTypes = [
            UTType(filenameExtension: "fountain") ?? .plainText,
            UTType(filenameExtension: "fdx") ?? .xml,
            .plainText
        ]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            let imported: ScreenplaySnapshot
            if url.pathExtension.lowercased() == "fdx" {
                imported = try FDXCodec.decode(data)
            } else {
                let source = String(decoding: data, as: UTF8.self)
                imported = FountainCodec.decode(source)
            }
            title = imported.title.isEmpty ? url.deletingPathExtension().lastPathComponent : imported.title
            author = imported.author
            contact = imported.contact
            elements = imported.elements
            selectedID = imported.elements.first?.id
            currentFileURL = url
            documentName = url.deletingPathExtension().lastPathComponent
            lastSavedLabel = "Opened"
        } catch {
            alertMessage = "The screenplay could not be opened. \(error.localizedDescription)"
        }
    }

    func save() {
        guard let url = currentFileURL else {
            saveAsFountain()
            return
        }
        do {
            try write(snapshot: snapshot, to: url)
            documentName = url.deletingPathExtension().lastPathComponent
            lastSavedLabel = "Saved just now"
        } catch {
            alertMessage = "The screenplay could not be saved. \(error.localizedDescription)"
        }
    }

    func saveAsFountain() {
        let panel = NSSavePanel()
        panel.title = "Save Screenplay"
        panel.allowedContentTypes = [UTType(filenameExtension: "fountain") ?? .plainText]
        panel.nameFieldStringValue = safeFileName(title) + ".fountain"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try write(snapshot: snapshot, to: url)
            currentFileURL = url
            documentName = url.deletingPathExtension().lastPathComponent
            lastSavedLabel = "Saved just now"
        } catch {
            alertMessage = "The screenplay could not be saved. \(error.localizedDescription)"
        }
    }

    func exportFDX() {
        let panel = NSSavePanel()
        panel.title = "Export Final Draft XML"
        panel.allowedContentTypes = [UTType(filenameExtension: "fdx") ?? .xml]
        panel.nameFieldStringValue = safeFileName(title) + ".fdx"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try FDXCodec.encode(snapshot).write(to: url, options: .atomic)
            lastSavedLabel = "FDX exported"
        } catch {
            alertMessage = "The FDX file could not be exported. \(error.localizedDescription)"
        }
    }

    func exportPDF() {
        let panel = NSSavePanel()
        panel.title = "Export Screenplay PDF"
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = safeFileName(title) + ".pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try PDFExporter.write(snapshot: snapshot, to: url)
            lastSavedLabel = "PDF exported"
        } catch {
            alertMessage = "The PDF could not be exported. \(error.localizedDescription)"
        }
    }

    private func write(snapshot: ScreenplaySnapshot, to url: URL) throws {
        if url.pathExtension.lowercased() == "fdx" {
            try FDXCodec.encode(snapshot).write(to: url, options: .atomic)
        } else {
            let fountain = FountainCodec.serialize(snapshot.elements, title: snapshot.title, author: snapshot.author)
            try Data(fountain.utf8).write(to: url, options: .atomic)
        }
    }

    private func scheduleAutosave() {
        autosaveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.writeAutosave()
        }
        autosaveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: work)
    }

    private func writeAutosave() {
        let url = Self.autosaveURL
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: url, options: .atomic)
            lastSavedLabel = "Autosaved"
        } catch {
            lastSavedLabel = "Autosave unavailable"
        }
    }

    private static var autosaveURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FrameScript", isDirectory: true)
            .appendingPathComponent("Autosave.json")
    }

    private static func readAutosave() -> ScreenplaySnapshot? {
        guard let data = try? Data(contentsOf: autosaveURL) else { return nil }
        return try? JSONDecoder().decode(ScreenplaySnapshot.self, from: data)
    }

    private static func showcaseSnapshot(_ mode: Int) -> ScreenplaySnapshot {
        func e(_ type: ScriptElementType, _ text: String = "") -> ScriptElement {
            ScriptElement(type: type, text: text)
        }

        switch mode {
        case 5:
            return ScreenplaySnapshot(title: "The Glass Harbor", author: "Nadia Rahimi", contact: "nadia@example.com", elements: [
                e(.sceneHeading, "EXT. GLASS HARBOR — DAWN"),
                e(.action, "Fog lifts from the water. A ferry horn rolls through the sleeping port."),
                e(.character, "ELI"), e(.dialogue, "You said the harbor was empty."),
                e(.character, "NORA"), e(.dialogue, "It was. Before the lights came on."),
                e(.sceneHeading, "INT. HARBOR OFFICE — MORNING"),
                e(.action, "A wall of tide charts. Nora marks a red line across the bay."),
                e(.character, "NORA"), e(.parenthetical, "(quietly)"), e(.dialogue, "We leave before sunrise."),
                e(.sceneHeading, "EXT. PIER 6 — NIGHT"),
                e(.action, "A lone skiff drifts in, its lantern glowing beneath the fog.")
            ])
        case 6, 10:
            var elements: [ScriptElement] = [
                e(.sceneHeading, mode == 10 ? "INT. NIGHT TRAIN — MOVING — NIGHT" : "INT. OBSERVATORY — NIGHT"),
                e(.action, mode == 10 ? "Rain threads the glass. The city slips away behind them." : "The dome turns above a mountain of snow. A red warning light pulses."),
                e(.character, mode == 10 ? "MARA" : "DR. VALE"),
                e(.dialogue, mode == 10 ? "How long until the next stop?" : "The signal is coming from below us."),
                e(.character, mode == 10 ? "JONAH" : "IMANI"),
                e(.dialogue, mode == 10 ? "Long enough to decide what we tell them." : "There is nothing below us for a hundred miles."),
                e(.action, "A low vibration travels through the room. The instruments answer with a sharp, steady pulse."),
                e(.character, mode == 10 ? "MARA" : "DR. VALE"),
                e(.dialogue, "Then we keep listening."),
                e(.action, "Outside, the horizon brightens. One by one, the stars disappear.")
            ]
            for beat in 1...18 {
                elements.append(e(.action, "Beat \(beat): The pattern repeats, closer now, as the room falls silent."))
                if beat.isMultiple(of: 3) {
                    elements.append(e(.character, mode == 10 ? "JONAH" : "IMANI"))
                    elements.append(e(.dialogue, beat == 18 ? "We have to answer." : "Did you hear that?"))
                }
            }
            if mode == 10 {
                elements.append(e(.sceneHeading, "EXT. LAST STOP — PRE-DAWN"))
                elements.append(e(.action, "The train idles beside a platform buried in fresh snow."))
            }
            return ScreenplaySnapshot(title: mode == 10 ? "Northbound" : "The Observatory", author: mode == 10 ? "M. Cole" : "R. Okafor", contact: "studio@example.com", elements: elements)
        case 7:
            return ScreenplaySnapshot(title: "A Map of Small Fires", author: "Jules Chen", contact: "jules.chen@example.com", elements: [
                e(.sceneHeading, "INT. APARTMENT KITCHEN — MORNING"),
                e(.action, "Sunlight lands on a folded city map. Jules circles a tiny blue dot."),
                e(.character, "JULES"), e(.parenthetical, "(to the kettle)"),
                e(.dialogue, "One street at a time."),
                e(.character, "MICAH"), e(.dialogue, "You always say that before you get lost."),
                e(.action, "The kettle clicks off. Neither of them moves."),
                e(.character, "JULES"), e(.dialogue, "Then come with me."),
                e(.transition, "FADE OUT.")
            ])
        case 8:
            return ScreenplaySnapshot(title: "Ash & Meridian", author: "Samira Wells", contact: "samira@storyhouse.test", elements: [
                e(.sceneHeading, "EXT. DESERT ROAD — DAY"),
                e(.shot, "WIDE ON — a ribbon of asphalt cutting through the heat."),
                e(.action, "An old bus waits at the shoulder. Every window is open."),
                e(.character, "TOMAS"), e(.dialogue, "This is where the map ends."),
                e(.character, "LEILA"), e(.parenthetical, "(checking her compass)"), e(.dialogue, "No. It is where it starts."),
                e(.transition, "SMASH CUT TO:"),
                e(.sceneHeading, "INT. BUS — CONTINUOUS"),
                e(.action, "Dust swirls through an empty aisle. A small bell rings at the back."),
                e(.character, "TOMAS"), e(.dialogue, "Did you bring the key?"),
                e(.character, "LEILA"), e(.dialogue, "I brought the door."),
                e(.transition, "CUT TO BLACK.")
            ])
        case 9:
            return ScreenplaySnapshot(title: "Northbound", author: "M. Cole", contact: "mcole@northbound.test", elements: [
                e(.sceneHeading, "INT. NIGHT TRAIN — MOVING — NIGHT"),
                e(.action, "Rain threads the glass. The city slips away behind them."),
                e(.character, "MARA"), e(.dialogue, "How long until the next stop?"),
                e(.character, "JONAH"), e(.dialogue, "Long enough to decide what we tell them."),
                e(.action, "Mara watches the reflection in the dark window. A third passenger appears behind them."),
                e(.character, "MARA"), e(.parenthetical, "(without turning)"), e(.dialogue, "We are not alone."),
                e(.sceneHeading, "EXT. LAST STOP — PRE-DAWN"),
                e(.action, "The train idles beside a platform buried in fresh snow."),
                e(.character, "JONAH"), e(.dialogue, "There is no station on this line."),
                e(.transition, "CUT TO BLACK.")
            ])
        default:
            return ScreenplaySnapshot.sample
        }
    }

    private func safeFileName(_ value: String) -> String {
        let cleaned = value
            .components(separatedBy: CharacterSet(charactersIn: "/:\\?%*|\"<>"))
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Untitled Screenplay" : cleaned
    }
}
