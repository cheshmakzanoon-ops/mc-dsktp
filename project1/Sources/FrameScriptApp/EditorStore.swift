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

    private(set) var currentFileURL: URL?
    private var autosaveWorkItem: DispatchWorkItem?

    init() {
        if let snapshot = Self.readAutosave() {
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

    private func safeFileName(_ value: String) -> String {
        let cleaned = value
            .components(separatedBy: CharacterSet(charactersIn: "/:\\?%*|\"<>"))
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Untitled Screenplay" : cleaned
    }
}
