import AppKit
import CoreGraphics
import FrameScriptCore

enum PDFExporter {
    private static let paperSize = CGSize(width: 612, height: 792)

    static func write(snapshot: ScreenplaySnapshot, to url: URL) throws {
        var mediaBox = CGRect(origin: .zero, size: paperSize)
        guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }

        let groups = paginate(snapshot.elements)
        let oldContext = NSGraphicsContext.current
        let graphics = NSGraphicsContext(cgContext: context, flipped: true)
        NSGraphicsContext.current = graphics

        drawTitlePage(snapshot, in: context)
        for (index, elements) in groups.enumerated() {
            context.beginPDFPage(nil)
            drawPageNumber(index + 1, in: context)
            var y: CGFloat = 82
            for element in elements {
                y += CGFloat(element.type.spacingBefore) * 6
                let text = formattedText(for: element)
                let paragraph = NSMutableParagraphStyle()
                paragraph.lineBreakMode = .byWordWrapping
                paragraph.alignment = element.type == .transition ? .right : .left
                paragraph.firstLineHeadIndent = element.type.pageIndent * 72
                paragraph.headIndent = element.type.pageIndent * 72
                paragraph.tailIndent = -(element.type.pageTrailingIndent * 72)
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont(name: "Courier New", size: 12) ?? .monospacedSystemFont(ofSize: 12, weight: .regular),
                    .foregroundColor: NSColor(calibratedWhite: 0.08, alpha: 1),
                    .paragraphStyle: paragraph
                ]
                let attributed = NSAttributedString(string: text, attributes: attributes)
                let size = attributed.boundingRect(
                    with: CGSize(width: 468, height: 2000),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                )
                let height = max(15, ceil(size.height))
                attributed.draw(in: CGRect(x: 72, y: y, width: 468, height: height + 2))
                y += height
            }
            context.endPDFPage()
        }

        NSGraphicsContext.current = oldContext
        context.closePDF()
    }

    private static func drawTitlePage(_ snapshot: ScreenplaySnapshot, in context: CGContext) {
        context.beginPDFPage(nil)
        let titleStyle = NSMutableParagraphStyle()
        titleStyle.alignment = .center
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "Courier New", size: 16) ?? .monospacedSystemFont(ofSize: 16, weight: .medium),
            .foregroundColor: NSColor.black,
            .paragraphStyle: titleStyle
        ]
        let title = NSAttributedString(string: snapshot.title.uppercased(), attributes: titleAttributes)
        title.draw(in: CGRect(x: 70, y: 345, width: 472, height: 42))

        let bylineAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "Courier New", size: 12) ?? .monospacedSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.black,
            .paragraphStyle: titleStyle
        ]
        if !snapshot.author.isEmpty {
            NSAttributedString(string: "Written by\n\(snapshot.author)", attributes: bylineAttributes)
                .draw(in: CGRect(x: 120, y: 410, width: 372, height: 52))
        }
        if !snapshot.contact.isEmpty {
            let leftStyle = NSMutableParagraphStyle()
            leftStyle.alignment = .left
            let contactAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont(name: "Courier New", size: 10) ?? .monospacedSystemFont(ofSize: 10, weight: .regular),
                .foregroundColor: NSColor.black,
                .paragraphStyle: leftStyle
            ]
            NSAttributedString(string: snapshot.contact, attributes: contactAttributes)
                .draw(in: CGRect(x: 72, y: 690, width: 300, height: 35))
        }
        context.endPDFPage()
    }

    private static func drawPageNumber(_ pageNumber: Int, in context: CGContext) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "Courier New", size: 12) ?? .monospacedSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraph
        ]
        NSAttributedString(string: "\(pageNumber).", attributes: attributes)
            .draw(in: CGRect(x: 470, y: 38, width: 72, height: 20))
    }

    private static func formattedText(for element: ScriptElement) -> String {
        switch element.type {
        case .sceneHeading, .character, .transition:
            element.text.uppercased()
        default:
            element.text
        }
    }

    private static func paginate(_ elements: [ScriptElement]) -> [[ScriptElement]] {
        var pages: [[ScriptElement]] = []
        var page: [ScriptElement] = []
        var lines = 0
        for element in elements {
            let estimate = element.estimatedLines + element.type.spacingBefore
            if lines + estimate > 44, !page.isEmpty {
                pages.append(page)
                page = []
                lines = 0
            }
            page.append(element)
            lines += estimate
        }
        if !page.isEmpty { pages.append(page) }
        return pages.isEmpty ? [[]] : pages
    }
}
