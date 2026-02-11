import Foundation

/// Manages the command input line for the terminal, including editing, cursor
/// movement, command history, and tab completion.
final class TerminalCommandLine {

    // MARK: - Constants

    private static let maxHistory = 100

    // MARK: - Properties

    /// The characters currently being edited.
    private var buffer: [Character] = []

    /// Current cursor position (0 = before first character, buffer.count = after last).
    private(set) var cursorPosition: Int = 0

    /// Array of previously submitted commands (most recent last).
    private(set) var history: [String] = []

    /// Index into history for up/down navigation.
    /// When nil, we are editing a new command (not browsing history).
    private var historyIndex: Int? = nil

    /// Saved in-progress input when the user starts navigating history.
    private var savedInput: String? = nil

    // MARK: - Computed

    /// The current input text as a String.
    var currentText: String {
        return String(buffer)
    }

    /// Whether the input is empty.
    var isEmpty: Bool {
        return buffer.isEmpty
    }

    // MARK: - Editing

    /// Insert a character at the current cursor position.
    func insertCharacter(_ char: Character) {
        buffer.insert(char, at: cursorPosition)
        cursorPosition += 1
    }

    /// Delete the character before the cursor (backspace).
    func deleteBackward() {
        guard cursorPosition > 0 else { return }
        cursorPosition -= 1
        buffer.remove(at: cursorPosition)
    }

    /// Delete the character at the cursor position (forward delete).
    func deleteForward() {
        guard cursorPosition < buffer.count else { return }
        buffer.remove(at: cursorPosition)
    }

    // MARK: - Cursor Movement

    /// Move the cursor one position to the left.
    func moveCursorLeft() {
        if cursorPosition > 0 {
            cursorPosition -= 1
        }
    }

    /// Move the cursor one position to the right.
    func moveCursorRight() {
        if cursorPosition < buffer.count {
            cursorPosition += 1
        }
    }

    /// Move the cursor to the beginning of the input.
    func moveCursorToStart() {
        cursorPosition = 0
    }

    /// Move the cursor to the end of the input.
    func moveCursorToEnd() {
        cursorPosition = buffer.count
    }

    // MARK: - Readline Kill / Yank

    /// Kill ring buffer for C-y (yank).
    private(set) var killBuffer: String = ""

    /// Kill from cursor to end of line (C-k).
    func killToEnd() {
        guard cursorPosition < buffer.count else { return }
        killBuffer = String(buffer[cursorPosition...])
        buffer.removeSubrange(cursorPosition..<buffer.count)
    }

    /// Kill from beginning of line to cursor (C-u).
    func killToStart() {
        guard cursorPosition > 0 else { return }
        killBuffer = String(buffer[0..<cursorPosition])
        buffer.removeSubrange(0..<cursorPosition)
        cursorPosition = 0
    }

    /// Kill the word behind the cursor (C-w).
    func killWordBackward() {
        guard cursorPosition > 0 else { return }
        var pos = cursorPosition
        // Skip trailing whitespace
        while pos > 0 && buffer[pos - 1] == " " { pos -= 1 }
        // Skip the word
        while pos > 0 && buffer[pos - 1] != " " { pos -= 1 }
        killBuffer = String(buffer[pos..<cursorPosition])
        buffer.removeSubrange(pos..<cursorPosition)
        cursorPosition = pos
    }

    /// Transpose the two characters before the cursor (C-t).
    func transposeChars() {
        guard buffer.count >= 2 else { return }
        // If at end, swap the last two characters
        let swapPos = cursorPosition == buffer.count ? cursorPosition - 1 : cursorPosition
        guard swapPos > 0, swapPos < buffer.count else { return }
        buffer.swapAt(swapPos - 1, swapPos)
        cursorPosition = min(swapPos + 1, buffer.count)
    }

    /// Yank (paste) the kill buffer at cursor (C-y).
    func yank() {
        guard !killBuffer.isEmpty else { return }
        let chars = Array(killBuffer)
        buffer.insert(contentsOf: chars, at: cursorPosition)
        cursorPosition += chars.count
    }

    // MARK: - History

    /// Navigate to the previous (older) command in history.
    func historyUp() {
        guard !history.isEmpty else { return }

        if historyIndex == nil {
            // Starting history navigation: save current input
            savedInput = currentText
            historyIndex = history.count - 1
        } else if let idx = historyIndex, idx > 0 {
            historyIndex = idx - 1
        } else {
            // Already at the oldest entry
            return
        }

        if let idx = historyIndex {
            setBuffer(history[idx])
        }
    }

    /// Navigate to the next (newer) command in history, or back to the saved input.
    func historyDown() {
        guard let idx = historyIndex else { return }

        if idx < history.count - 1 {
            historyIndex = idx + 1
            setBuffer(history[idx + 1])
        } else {
            // Return to saved input
            historyIndex = nil
            setBuffer(savedInput ?? "")
            savedInput = nil
        }
    }

    // MARK: - Submit

    /// Submit the current input. Returns the trimmed text if non-empty, adds it
    /// to history, and clears the input line. Returns nil if the input is empty.
    func submit() -> String? {
        let text = currentText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }

        // Add to history (avoid consecutive duplicates)
        if history.last != text {
            history.append(text)
            if history.count > TerminalCommandLine.maxHistory {
                history.removeFirst()
            }
        }

        // Reset state
        buffer.removeAll()
        cursorPosition = 0
        historyIndex = nil
        savedInput = nil

        return text
    }

    // MARK: - Tab Completion

    /// Perform tab completion given a list of possible completions.
    /// - If one completion: fill it in (replacing current input).
    /// - If multiple: complete the longest common prefix.
    /// - If none: do nothing.
    func tabComplete(completions: [String]) {
        guard !completions.isEmpty else { return }

        if completions.count == 1 {
            // Single match: fill it in with a trailing space
            let completed = completions[0] + " "
            setBuffer(completed)
        } else {
            // Multiple matches: complete common prefix
            let prefix = longestCommonPrefix(completions)
            if prefix.count > currentText.count {
                setBuffer(prefix)
            }
        }
    }

    // MARK: - Private Helpers

    /// Replace the buffer contents and move cursor to end.
    private func setBuffer(_ text: String) {
        buffer = Array(text)
        cursorPosition = buffer.count
    }

    /// Find the longest common prefix among an array of strings.
    private func longestCommonPrefix(_ strings: [String]) -> String {
        guard let first = strings.first else { return "" }
        var prefix = first
        for s in strings.dropFirst() {
            while !s.hasPrefix(prefix) {
                prefix = String(prefix.dropLast())
                if prefix.isEmpty { return "" }
            }
        }
        return prefix
    }
}
