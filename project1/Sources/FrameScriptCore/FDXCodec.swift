import Foundation

public enum FDXCodec {
    public static func encode(_ snapshot: ScreenplaySnapshot) -> Data {
        let scriptParagraphs = snapshot.elements.map { element in
            let text: String
            switch element.type {
            case .sceneHeading, .character, .transition:
                text = element.text.uppercased()
            default:
                text = element.text
            }
            return "<Paragraph Type=\"\(element.type.fdxName)\"><Text>\(xmlEscape(text))</Text></Paragraph>"
        }.joined(separator: "\n")
        let title = snapshot.title.isEmpty ? "" : "<Paragraph Type=\"Title\"><Text>\(xmlEscape(snapshot.title))</Text></Paragraph>"
        let author = snapshot.author.isEmpty ? "" : "<Paragraph Type=\"Author\"><Text>\(xmlEscape(snapshot.author))</Text></Paragraph>"
        let contact = snapshot.contact.isEmpty ? "" : "<Paragraph Type=\"Contact\"><Text>\(xmlEscape(snapshot.contact))</Text></Paragraph>"
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="no" ?>
        <FinalDraft DocumentType="Script" Template="No" Version="5">
          <Content>
        \(scriptParagraphs)
          </Content>
          <TitlePage>
            <Content>
        \(title)
        \(author)
        \(contact)
            </Content>
          </TitlePage>
        </FinalDraft>
        """
        return Data(xml.utf8)
    }

    public static func decode(_ data: Data) throws -> ScreenplaySnapshot {
        let delegate = FDXParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            throw parser.parserError ?? FDXError.invalidDocument
        }
        return ScreenplaySnapshot(
            title: delegate.title,
            author: delegate.author,
            contact: delegate.contact,
            elements: delegate.elements.isEmpty
                ? [ScriptElement(type: .sceneHeading, text: "INT. NEW SCENE — DAY")]
                : delegate.elements
        )
    }

    private static func xmlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private enum FDXError: Error {
        case invalidDocument
    }
}

private final class FDXParserDelegate: NSObject, XMLParserDelegate {
    var elements: [ScriptElement] = []
    var title = ""
    var author = ""
    var contact = ""

    private var inTitlePage = false
    private var inText = false
    private var paragraphType = "Action"
    private var text = ""

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case "TitlePage":
            inTitlePage = true
        case "Paragraph":
            paragraphType = attributeDict["Type"] ?? "Action"
            text = ""
        case "Text":
            inText = true
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inText { text += string }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch elementName {
        case "Text":
            inText = false
        case "Paragraph":
            if inTitlePage {
                switch paragraphType.lowercased() {
                case "title": title = text
                case "author", "by": author = text
                case "contact": contact = text
                default: break
                }
            } else {
                elements.append(ScriptElement(type: .fromFDX(paragraphType), text: text))
            }
        case "TitlePage":
            inTitlePage = false
        default:
            break
        }
    }
}
