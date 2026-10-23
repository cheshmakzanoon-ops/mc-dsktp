import Foundation

public enum ScriptElementType: String, CaseIterable, Codable, Sendable {
    case sceneHeading
    case action
    case character
    case dialogue
    case parenthetical
    case transition
    case shot

    public var displayName: String {
        switch self {
        case .sceneHeading: "Scene Heading"
        case .action: "Action"
        case .character: "Character"
        case .dialogue: "Dialogue"
        case .parenthetical: "Parenthetical"
        case .transition: "Transition"
        case .shot: "Shot"
        }
    }

    public var fdxName: String { displayName }

    public static func fromFDX(_ name: String) -> ScriptElementType {
        switch name.lowercased() {
        case "scene heading", "sceneheading": .sceneHeading
        case "character": .character
        case "dialogue": .dialogue
        case "parenthetical": .parenthetical
        case "transition": .transition
        case "shot": .shot
        default: .action
        }
    }

    public var maxCharactersPerLine: Int {
        switch self {
        case .sceneHeading, .action: 62
        case .character: 30
        case .dialogue: 34
        case .parenthetical: 30
        case .transition: 48
        case .shot: 58
        }
    }

    public var pageIndent: CGFloat {
        switch self {
        case .character: 2.15
        case .dialogue: 1.0
        case .parenthetical: 1.48
        case .transition: 0
        case .sceneHeading, .action, .shot: 0
        }
    }

    public var pageTrailingIndent: CGFloat {
        switch self {
        case .dialogue, .parenthetical: 1.0
        default: 0
        }
    }

    public var spacingBefore: Int {
        switch self {
        case .sceneHeading: 2
        case .action, .shot: 1
        case .character, .transition: 1
        case .dialogue, .parenthetical: 0
        }
    }

    public func nextByTab() -> ScriptElementType {
        switch self {
        case .sceneHeading, .transition: .action
        case .action, .shot: .character
        case .character: .dialogue
        case .dialogue: .character
        case .parenthetical: .dialogue
        }
    }

    public func nextAfterReturn(isEmpty: Bool) -> ScriptElementType {
        if isEmpty, self == .action { return .sceneHeading }
        switch self {
        case .sceneHeading: return .action
        case .action, .shot: return .action
        case .character: return .dialogue
        case .dialogue: return .character
        case .parenthetical: return .dialogue
        case .transition: return .sceneHeading
        }
    }
}

public struct ScriptElement: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var type: ScriptElementType
    public var text: String

    public init(id: UUID = UUID(), type: ScriptElementType, text: String = "") {
        self.id = id
        self.type = type
        self.text = text
    }

    public var estimatedLines: Int {
        let paragraphs = text.components(separatedBy: .newlines)
        let count = paragraphs.reduce(0) { partial, line in
            partial + max(1, Int(ceil(Double(line.count) / Double(type.maxCharactersPerLine))))
        }
        return max(1, count)
    }
}

public struct ScreenplaySnapshot: Codable, Equatable, Sendable {
    public var title: String
    public var author: String
    public var contact: String
    public var elements: [ScriptElement]

    public init(
        title: String,
        author: String,
        contact: String = "",
        elements: [ScriptElement]
    ) {
        self.title = title
        self.author = author
        self.contact = contact
        self.elements = elements
    }

    public static var sample: ScreenplaySnapshot {
        ScreenplaySnapshot(
            title: "The Last Signal",
            author: "A. Writer",
            contact: "writer@example.com",
            elements: [
                ScriptElement(type: .sceneHeading, text: "EXT. NORTH ATLANTIC — NIGHT"),
                ScriptElement(type: .action, text: "A lighthouse cuts through the rain. Its beam sweeps an empty ocean, then stops."),
                ScriptElement(type: .action, text: "A radio crackles inside the keeper's cottage."),
                ScriptElement(type: .sceneHeading, text: "INT. LIGHTHOUSE — RADIO ROOM — NIGHT"),
                ScriptElement(type: .action, text: "MARA, 30s, listens with one hand on the receiver. A string of numbers repeats beneath the static."),
                ScriptElement(type: .character, text: "MARA"),
                ScriptElement(type: .parenthetical, text: "(into the radio)"),
                ScriptElement(type: .dialogue, text: "This is North Point. Identify yourself."),
                ScriptElement(type: .action, text: "The signal drops. Mara looks to the window. Far out at sea, a light blinks twice."),
                ScriptElement(type: .character, text: "MARA"),
                ScriptElement(type: .dialogue, text: "I see you."),
                ScriptElement(type: .transition, text: "CUT TO:")
            ]
        )
    }
}
