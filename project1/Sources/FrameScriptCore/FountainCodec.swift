import Foundation

public enum FountainCodec {
    public static func decode(_ source: String) -> ScreenplaySnapshot {
        let normalized = source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.components(separatedBy: "\n")
        var title = ""
        var author = ""
        var headerEnd: Int?
        for (index, rawLine) in lines.enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                if !title.isEmpty || !author.isEmpty {
                    headerEnd = index + 1
                }
                break
            }
            guard let colon = line.firstIndex(of: ":") else { break }
            let key = line[..<colon].lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            switch key {
            case "title": title = value
            case "author", "credit": author = value
            default: break
            }
        }
        let scriptSource: String
        if let headerEnd {
            scriptSource = lines.dropFirst(headerEnd).joined(separator: "\n")
        } else {
            scriptSource = normalized
        }
        return ScreenplaySnapshot(
            title: title,
            author: author,
            elements: parse(scriptSource)
        )
    }

    public static func parse(_ source: String) -> [ScriptElement] {
        let normalized = source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var elements: [ScriptElement] = []
        var previousType: ScriptElementType?

        for rawLine in normalized.components(separatedBy: "\n") {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else {
                previousType = nil
                continue
            }

            var line = trimmed
            var type: ScriptElementType
            if line.hasPrefix(".") && isSceneHeading(String(line.dropFirst())) {
                line.removeFirst()
                type = .sceneHeading
            } else if isSceneHeading(line) {
                type = .sceneHeading
            } else if line.hasPrefix(">") {
                line = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
                type = .transition
            } else if isTransition(line) {
                type = .transition
            } else if line.hasPrefix("@") {
                line.removeFirst()
                type = .character
            } else if isParenthetical(line), previousType == .character || previousType == .dialogue || previousType == .parenthetical {
                type = .parenthetical
            } else if isCharacterCue(line), previousType != .dialogue, previousType != .parenthetical {
                type = .character
            } else if previousType == .character || previousType == .dialogue || previousType == .parenthetical {
                type = .dialogue
            } else {
                type = .action
            }

            elements.append(ScriptElement(type: type, text: line))
            previousType = type
        }

        return elements.isEmpty ? [ScriptElement(type: .sceneHeading, text: "INT. NEW SCENE — DAY")] : elements
    }

    public static func serialize(_ elements: [ScriptElement], title: String = "", author: String = "") -> String {
        var output: [String] = []
        if !title.isEmpty {
            output.append("Title: \(title)")
            if !author.isEmpty { output.append("Author: \(author)") }
            output.append("")
        }

        var previousType: ScriptElementType?
        for element in elements {
            let line: String
            switch element.type {
            case .sceneHeading:
                line = ".\(element.text.uppercased())"
            case .transition:
                line = "> \(element.text)"
            case .character:
                line = "@\(element.text.uppercased())"
            default:
                line = element.text
            }
            let dialogueContinuation = previousType == .character || previousType == .parenthetical
            if !output.isEmpty && !dialogueContinuation { output.append("") }
            output.append(line)
            previousType = element.type
        }
        return output.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    private static func isSceneHeading(_ line: String) -> Bool {
        let upper = line.uppercased()
        return ["INT.", "EXT.", "INT./EXT.", "EXT./INT.", "I/E.", "EST."].contains { upper.hasPrefix($0) }
    }

    private static func isParenthetical(_ line: String) -> Bool {
        line.hasPrefix("(") && line.hasSuffix(")")
    }

    private static func isTransition(_ line: String) -> Bool {
        let upper = line.uppercased()
        return ["CUT TO:", "SMASH CUT TO:", "MATCH CUT TO:", "DISSOLVE TO:", "FADE IN:", "FADE OUT.", "FADE TO BLACK."]
            .contains(upper)
    }

    private static func isCharacterCue(_ line: String) -> Bool {
        guard line.count <= 36, line == line.uppercased(), line.rangeOfCharacter(from: .letters) != nil else {
            return false
        }
        if line.hasSuffix(":") || line.hasPrefix("INT.") || line.hasPrefix("EXT.") { return false }
        let allowed = CharacterSet.uppercaseLetters
            .union(.decimalDigits)
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: ".'()/-’&"))
        return line.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}
