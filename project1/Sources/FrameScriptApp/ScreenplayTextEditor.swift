import AppKit
import SwiftUI

struct ScreenplayTextEditor: NSViewRepresentable {
    @Binding var text: String
    var isActive: Bool
    var type: ScriptElementType
    var onFocus: () -> Void
    var onReturn: () -> Void
    var onTab: () -> Void
    var onDeleteEmpty: () -> Void

    func makeNSView(context: Context) -> ScreenplayTextView {
        let view = ScreenplayTextView()
        view.delegate = context.coordinator
        view.font = NSFont(name: "Courier New", size: 12) ?? .monospacedSystemFont(ofSize: 12, weight: .regular)
        view.textColor = NSColor(calibratedWhite: 0.12, alpha: 1)
        view.backgroundColor = .clear
        view.drawsBackground = false
        view.isRichText = false
        view.isAutomaticQuoteSubstitutionEnabled = false
        view.isAutomaticDashSubstitutionEnabled = false
        view.isAutomaticTextReplacementEnabled = false
        view.isVerticallyResizable = false
        view.isHorizontallyResizable = false
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.widthTracksTextView = true
        view.onReturn = onReturn
        view.onTab = onTab
        view.onDeleteEmpty = onDeleteEmpty
        view.onFocus = onFocus
        view.textAlignment = type == .transition ? .right : .left
        view.string = text
        return view
    }

    func updateNSView(_ view: ScreenplayTextView, context: Context) {
        context.coordinator.parent = self
        view.onReturn = onReturn
        view.onTab = onTab
        view.onDeleteEmpty = onDeleteEmpty
        view.onFocus = onFocus
        view.textAlignment = type == .transition ? .right : .left
        if view.string != text {
            let oldSelection = view.selectedRange()
            view.string = text
            let end = (view.string as NSString).length
            view.setSelectedRange(NSRange(location: min(oldSelection.location, end), length: 0))
        }
        if isActive && view.window?.firstResponder !== view {
            DispatchQueue.main.async {
                guard let window = view.window else { return }
                window.makeFirstResponder(view)
                view.setSelectedRange(NSRange(location: (view.string as NSString).length, length: 0))
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ScreenplayTextEditor

        init(_ parent: ScreenplayTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else { return }
            parent.text = view.string
        }

        func textDidBeginEditing(_ notification: Notification) {
            parent.onFocus()
        }
    }
}

final class ScreenplayTextView: NSTextView {
    var onReturn: (() -> Void)?
    var onTab: (() -> Void)?
    var onDeleteEmpty: (() -> Void)?
    var onFocus: (() -> Void)?

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became { onFocus?() }
        return became
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 48, event.modifierFlags.intersection([.command, .control, .option]).isEmpty {
            onTab?()
            return
        }
        if event.keyCode == 36 || event.keyCode == 76 {
            if event.modifierFlags.contains(.shift) {
                super.keyDown(with: event)
            } else {
                onReturn?()
            }
            return
        }
        if event.keyCode == 51, string.isEmpty {
            onDeleteEmpty?()
            return
        }
        super.keyDown(with: event)
    }
}
