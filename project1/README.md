# FrameScript

FrameScript is a native macOS screenplay editor prototype built with SwiftUI and AppKit. It uses screenplay element blocks and page styling, with keyboard-first formatting controls.

## Included

- Scene headings, action, character cues, dialogue, parentheticals, transitions, and shot blocks
- Tab to change the current block type; Return to continue with the next screenplay element
- Scene and cast navigator, title-page fields, word and page estimates, search, and autosave
- Open and save Fountain files
- Import and export Final Draft XML (.fdx)
- Export a screenplay PDF with a title page and screenplay-style margins
- A GitHub Actions workflow that tests the core codecs and packages a universal Apple Silicon and Intel DMG

## Build and test on macOS

~~~sh
swift test --package-path project1
project1/scripts/make-dmg.sh
~~~

The generated installer is project1/build/FrameScript-macOS.dmg. It contains an ad-hoc signed app bundle for local testing. A Developer ID signature and Apple notarization are needed for a Gatekeeper-trusted public release.

## Keyboard behavior

- Command-N: New screenplay
- Command-O: Open
- Command-S: Save
- Shift-Command-E: Export PDF
- Tab: Cycle the selected screenplay block type
- Return: Insert the next block type
- Shift-Return: Insert a new line inside the current block

FrameScript has its own name, interface, and code. It is not affiliated with or endorsed by Final Draft.
