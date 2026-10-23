import SwiftUI
import FrameScriptCore

struct EditorWorkspace: View {
    @ObservedObject var store: EditorStore

    private var pages: [[ScriptElement]] {
        var result: [[ScriptElement]] = []
        var current: [ScriptElement] = []
        var lineCount = 0
        for element in store.elements {
            let lines = element.estimatedLines + element.type.spacingBefore
            if lineCount + lines > 44, !current.isEmpty {
                result.append(current)
                current = []
                lineCount = 0
            }
            current.append(element)
            lineCount += lines
        }
        if !current.isEmpty { result.append(current) }
        return result.isEmpty ? [[]] : result
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 26) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { page in
                        screenplayPage(page.element, number: page.offset + 1)
                    }
                }
                .padding(.vertical, 30)
                .frame(maxWidth: .infinity)
            }
            .background(Color(hex: 0xE9EDF1))
            .onChange(of: store.selectedID) { id in
                guard let id else { return }
                withAnimation(.easeInOut(duration: 0.22)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }

    private func screenplayPage(_ elements: [ScriptElement], number: Int) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(Color.white)
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Text("\(number).")
                        .font(.custom("Courier New", size: 12))
                        .foregroundStyle(Color(hex: 0x253039))
                }
                .padding(.top, 37)
                .padding(.trailing, 58)

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(elements) { element in
                        ElementRow(element: element, store: store)
                            .id(element.id)
                            .padding(.top, CGFloat(element.type.spacingBefore) * 7)
                    }
                }
                .frame(width: 468, alignment: .leading)
                .padding(.leading, 72)
                .padding(.top, 34)
                Spacer(minLength: 30)
            }
            .frame(width: 612, height: 792, alignment: .topLeading)
        }
        .frame(width: 612, height: 792)
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.13), radius: 14, x: 0, y: 5)
        .overlay(Rectangle().stroke(Color(hex: 0xD7DDE2), lineWidth: 0.7))
    }
}

private struct ElementRow: View {
    let element: ScriptElement
    @ObservedObject var store: EditorStore

    private var isSelected: Bool { store.selectedID == element.id }
    private var height: CGFloat { CGFloat(element.estimatedLines) * 15.5 + 2 }

    var body: some View {
        let binding = Binding<String>(
            get: { store.element(for: element.id)?.text ?? "" },
            set: { store.updateText(id: element.id, text: $0) }
        )
        HStack(alignment: .top, spacing: 0) {
            if element.type.pageIndent > 0 {
                Spacer().frame(width: element.type.pageIndent * 72)
            }
            ScreenplayTextEditor(
                text: binding,
                isActive: isSelected,
                type: element.type,
                onFocus: { store.select(element.id) },
                onReturn: { store.continueAfterReturn(id: element.id) },
                onTab: { store.cycleType(id: element.id) },
                onDeleteEmpty: { store.removeEmptyElement(id: element.id) }
            )
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
            if element.type == .transition {
                Spacer(minLength: 0)
            } else if element.type.pageTrailingIndent > 0 {
                Spacer().frame(width: element.type.pageTrailingIndent * 72)
            }
        }
        .frame(maxWidth: .infinity, alignment: element.type == .transition ? .trailing : .leading)
        .padding(.horizontal, 1)
        .background(isSelected ? Color(hex: 0xF5F5F0) : Color.clear)
        .overlay(alignment: .leading) {
            if isSelected {
                Rectangle().fill(Color(hex: 0xD3A75E)).frame(width: 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { store.select(element.id) }
    }
}
