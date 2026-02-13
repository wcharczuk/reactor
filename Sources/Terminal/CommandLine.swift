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

    // MARK: - Reverse Incremental Search (C-r)

    /// Whether we're currently in reverse-i-search mode.
    private(set) var isSearching: Bool = false

    /// The current search query string.
    private(set) var searchQuery: String = ""

    /// The index of the current match in history (nil = no match).
    private var searchMatchIndex: Int? = nil

    /// The matched command text, or nil if no match.
    var searchMatch: String? {
        guard let idx = searchMatchIndex else { return nil }
        return history[idx]
    }

    /// Enter reverse-i-search mode.
    func beginSearch() {
        guard !isSearching else {
            // Already searching — C-r again means find next
            searchNext()
            return
        }
        isSearching = true
        searchQuery = ""
        searchMatchIndex = nil
        savedInput = currentText
    }

    /// Add a character to the search query and find a match.
    func searchInsertCharacter(_ char: Character) {
        searchQuery.append(char)
        // Search from current match position backward
        let startIndex = searchMatchIndex ?? history.count
        findMatch(from: startIndex - 1)
    }

    /// Remove last character from search query.
    func searchDeleteBackward() {
        guard !searchQuery.isEmpty else { return }
        searchQuery.removeLast()
        if searchQuery.isEmpty {
            searchMatchIndex = nil
        } else {
            // Re-search from the end
            findMatch(from: history.count - 1)
        }
    }

    /// Find the next (older) match for the current query.
    func searchNext() {
        guard !searchQuery.isEmpty else { return }
        let startIndex = (searchMatchIndex ?? history.count) - 1
        findMatch(from: startIndex)
    }

    /// Accept the current match and exit search mode.
    func acceptSearch() {
        if let match = searchMatch {
            setBuffer(match)
        }
        exitSearchMode()
    }

    /// Cancel search and restore original input.
    func cancelSearch() {
        setBuffer(savedInput ?? "")
        savedInput = nil
        exitSearchMode()
    }

    private func exitSearchMode() {
        isSearching = false
        searchQuery = ""
        searchMatchIndex = nil
    }

    private func findMatch(from startIndex: Int) {
        let query = searchQuery.lowercased()
        guard !query.isEmpty, startIndex >= 0 else {
            searchMatchIndex = nil
            return
        }
        for i in stride(from: min(startIndex, history.count - 1), through: 0, by: -1) {
            if history[i].lowercased().contains(query) {
                searchMatchIndex = i
                setBuffer(history[i])
                return
            }
        }
        searchMatchIndex = nil
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
